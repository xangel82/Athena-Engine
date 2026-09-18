#!/usr/bin/env bash
# Athena's Engine installer: makes sure a model's files are on this machine
# and writes the environment that starts the engine with them.
#
#   ./install.sh                             ask which model, download into ./models
#   ./install.sh --model qwen --dir /data/models
#   ./install.sh --model qwen --from /mnt/ggufs      use files already here
#   ./install.sh --model deepseek --verify           check what is already there
#
# Files already on the machine are never downloaded again. Without --from the
# usual places are searched — your home, /models, /data/models and the like,
# or whatever ATHENA_MODEL_PATH lists — and a file found there is used where
# it lies; --from searches one directory of your choosing instead. Only what
# is missing is fetched, and every download resumes: stop it whenever you
# like, run the same command again, and it carries on from where it stopped.
set -uo pipefail

MODELS_DIR="${ATHENA_MODELS_DIR:-$PWD/models}"
FROM_DIR=""
CHOICE=""
ASSUME_YES=0
VERIFY=0

die() { printf 'install: %s\n' "$*" >&2; exit 1; }
say() { printf '%s\n' "$*"; }

# Where model files tend to live on a machine that already has some.  Nothing
# here is this project's own layout: it is the caller's home and the usual
# mount points, and a path that does not exist costs nothing to skip.  --from
# replaces the list; ATHENA_MODEL_PATH adds to the front of it.
default_places() {
  local place
  for place in ${ATHENA_MODEL_PATH:+${ATHENA_MODEL_PATH//:/ }} \
               "$MODELS_DIR" "$HOME/models" "$HOME/gguf" "$HOME/ds4" \
               "$HOME/.cache/athena-engine" "$HOME" \
               /models /data/models /mnt/models /srv/models; do
    [ -n "$place" ] && [ -d "$place" ] && printf '%s\n' "$place"
  done
}

while [ $# -gt 0 ]; do
  case "$1" in
    --model) CHOICE="${2:-}"; shift 2 ;;
    --dir) MODELS_DIR="${2:-}"; shift 2 ;;
    --from) FROM_DIR="${2:-}"; shift 2 ;;
    --verify) VERIFY=1; shift ;;
    --yes|-y) ASSUME_YES=1; shift ;;
    -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

# ---------------------------------------------------------------- manifests
# <path under the model directory>|<url>|<size>|<role>
# The role names what the file is to the engine and decides the variable it
# is given to in athena.env.
HF="https://huggingface.co"
QWEN_REPO="$HF/unsloth/Qwen3.8-Flash-Next-GGUF/resolve/main"
DEEPSEEK_REPO="$HF/antirez/deepseek-v4-gguf/resolve/main"
DSPARK_REPO="$HF/deepseek-ai/DeepSeek-V4-Flash-DSpark/resolve/main"
QWEN_PARTS="Qwen3.8-Flash-Next-UD-IQ4_XS"
DEEPSEEK_MODEL="DeepSeek-V4-Flash-IQ2XXS-w2Q2K-AProjQ8-SExpQ8-OutQ8-chat-v2-imatrix-0731.gguf"
DSPARK_FILE="DeepSeek-V4-Flash-DSpark-IQ2XXS-Q2K-Q8.gguf"

qwen_files() {
  cat <<EOF
UD-IQ4_XS/$QWEN_PARTS-00001-of-00003.gguf|$QWEN_REPO/UD-IQ4_XS/$QWEN_PARTS-00001-of-00003.gguf|11 MB|model
UD-IQ4_XS/$QWEN_PARTS-00002-of-00003.gguf|$QWEN_REPO/UD-IQ4_XS/$QWEN_PARTS-00002-of-00003.gguf|50 GB|part
UD-IQ4_XS/$QWEN_PARTS-00003-of-00003.gguf|$QWEN_REPO/UD-IQ4_XS/$QWEN_PARTS-00003-of-00003.gguf|47 GB|part
MTP/mtp-Qwen3.8-Flash-Next-shared-Q8_0.gguf|$QWEN_REPO/MTP/mtp-Qwen3.8-Flash-Next-shared-Q8_0.gguf|2.6 GB|draft
MMPROJ/mmproj-F16.gguf|$QWEN_REPO/mmproj-F16.gguf|0.9 GB|mmproj
EOF
}

deepseek_files() {
  cat <<EOF
$DEEPSEEK_MODEL|$DEEPSEEK_REPO/$DEEPSEEK_MODEL|87 GB|model
EOF
}

# The DSpark sidecar is not published as a GGUF: it lives beside the model it
# drafts for, and when it is not there yet it is built out of the three
# official weight shards that hold the draft layers, exactly as the reference
# installer does.  The build is the last step, so an interrupted run resumes
# the downloads and then builds.
dspark_shards() {
  cat <<EOF
dspark-hf/config.json|$DSPARK_REPO/config.json|2 KB|none
dspark-hf/model.safetensors.index.json|$DSPARK_REPO/model.safetensors.index.json|5.6 MB|none
dspark-hf/model-00046-of-00048.safetensors|$DSPARK_REPO/model-00046-of-00048.safetensors|3.4 GB|none
dspark-hf/model-00047-of-00048.safetensors|$DSPARK_REPO/model-00047-of-00048.safetensors|3.3 GB|none
dspark-hf/model-00048-of-00048.safetensors|$DSPARK_REPO/model-00048-of-00048.safetensors|3.4 GB|none
EOF
}

# The sidecar belongs next to the model it drafts for, wherever that turned
# out to be: the folder the download went to, or the folder --from found the
# model in.
model_dir() {
  local fallback="$1"
  [ -n "$ROLE_model" ] && dirname "$ROLE_model" || printf '%s' "$fallback"
}

build_dspark() {
  local downloads="$1"
  local dir; dir="$(model_dir "$downloads")"
  local out="$dir/$DSPARK_FILE"
  local tool="$PWD/athena-engine/bin/deepseek4-quantize"
  [ -x "$tool" ] || tool="$(command -v deepseek4-quantize 2>/dev/null)"
  if [ -f "$out" ]; then
    say "  have  $DSPARK_FILE"
    remember draft "$out"
    return 0
  fi
  if [ -z "$tool" ] || [ ! -x "$tool" ]; then
    say "  the sidecar builder (deepseek4-quantize) is not in this release;"
    say "  DeepSeek will run without speculative decoding."
    return 0
  fi
  say ""
  say "  building $DSPARK_FILE into $dir (about 5.6 GB) — a few minutes"
  if [ ! -w "$dir" ]; then
    say "  $dir is not writable; leaving DeepSeek without speculative decoding."
    return 1
  fi
  if "$tool" --hf "$downloads/dspark-hf" --dspark-sidecar \
       --routed-w1 iq2_xxs --routed-w2 q2_k --routed-w3 iq2_xxs \
       --out "$out.partial" --overwrite; then
    mv -f "$out.partial" "$out"
    remember draft "$out"
    say "  built $DSPARK_FILE"
    return 0
  fi
  rm -f "$out.partial"
  say "  the sidecar could not be built; DeepSeek will run without"
  say "  speculative decoding."
  return 1
}

# ------------------------------------------------------------------ machine
preflight() {
  [ "$(uname -m)" = aarch64 ] || say "note: this machine is $(uname -m); the engine runs on GB10 (aarch64)."
  command -v curl >/dev/null || die "curl is needed and was not found"
  if command -v nvidia-smi >/dev/null; then
    say "GPU: $(nvidia-smi --query-gpu=name,driver_version --format=csv,noheader | head -1)"
  else
    say "note: nvidia-smi was not found; the engine needs an NVIDIA GB10 to run."
  fi
}

free_gb() { df -P -BG "$1" 2>/dev/null | awk 'NR==2 {gsub("G","",$4); print $4}'; }

# HuggingFace publishes the sha256 of each file in x-linked-etag, so a
# damaged download is caught here rather than by the engine hours later.
published_sha() {
  [ -n "${1:-}" ] || return 0
  curl -sIL --max-time 30 "$1" 2>/dev/null | tr -d '\r' |
    awk 'tolower($1) == "x-linked-etag:" { gsub(/"/, "", $2); print $2 }' | tail -1
}

verify_file() {
  local path="$1" url="${2:-}" want
  command -v sha256sum >/dev/null || return 0
  want="$(published_sha "$url")"
  [ -n "$want" ] || return 0
  say "  check $(basename "$path")"
  [ "$(sha256sum "$path" | cut -d' ' -f1)" = "$want" ] && return 0
  say "  checksum does not match what the repository publishes"
  return 1
}

# ----------------------------------------------------------------- download
# A file is fetched into <name>.part and moved into place only once curl is
# happy with it, so an interrupted download can never look finished.
fetch() {
  local dest="$1" url="$2" size="$3" tries=0
  mkdir -p "$(dirname "$dest")"
  say "  get   $(basename "$dest")  ($size)"
  until curl -fL --retry 5 --retry-delay 5 --retry-connrefused \
             -C - -o "$dest.part" "$url"; do
    tries=$((tries + 1))
    if [ $tries -ge 3 ]; then
      say "  gave up after $tries attempts; run the command again to resume"
      return 1
    fi
    say "  interrupted, resuming (attempt $((tries + 1)))"
    sleep 3
  done
  mv "$dest.part" "$dest"
  if ! verify_file "$dest" "$url"; then
    mv "$dest" "$dest.bad"
    say "  kept as $(basename "$dest").bad; delete it and run again to retry"
    return 1
  fi
  return 0
}

# What the engine will be pointed at, filled in as files are resolved.
ROLE_model=""
ROLE_draft=""
ROLE_mmproj=""

remember() {
  case "$1" in
    model) ROLE_model="$2" ;;
    draft) ROLE_draft="$2" ;;
    mmproj) ROLE_mmproj="$2" ;;
  esac
}

# Where this file already is on this machine, if it is anywhere.  --from is
# searched whole; without it the usual places are tried in turn, each only a
# few levels deep, and the search stops at the first match.  -xtype f so a
# file kept as a symlink counts too.
locate_file() {
  local name="$1" place found
  if [ -n "$FROM_DIR" ]; then
    find "$FROM_DIR" -name "$name" -xtype f -print -quit 2>/dev/null
    return 0
  fi
  while IFS= read -r place; do
    [ -n "$place" ] || continue
    found="$(find "$place" -maxdepth 4 -name "$name" -xtype f -print -quit 2>/dev/null)"
    if [ -n "$found" ]; then
      printf '%s\n' "$found"
      return 0
    fi
  done <<< "$(default_places)"
  return 0
}

# Is this file already on the machine?  Says nothing either way; the caller
# reports what it finds.
have_file() {
  local dir="$1" name="$2" role="$3" found
  if [ -f "$dir/$name" ]; then
    remember "$role" "$dir/$name"
    return 0
  fi
  found="$(locate_file "$name")"
  if [ -n "$found" ]; then
    remember "$role" "$found"
    return 0
  fi
  return 1
}

# A file already on the machine is used where it lies; only what is missing
# is downloaded.
resolve() {
  local dir="$1" dest="$2" url="$3" size="$4" role="$5"
  local name path found
  name="$(basename "$dest")"
  path="$dir/$dest"
  if [ -f "$path" ]; then
    say "  have  $name"
    if [ "$VERIFY" = 1 ]; then verify_file "$path" "$url" || return 1; fi
    remember "$role" "$path"
    return 0
  fi
  found="$(locate_file "$name")"
  if [ -n "$found" ]; then
    say "  found $name in $(dirname "$found")"
    if [ "$VERIFY" = 1 ]; then verify_file "$found" "$url" || return 1; fi
    remember "$role" "$found"
    return 0
  fi
  if [ -z "$url" ]; then
    say "  missing $name — no published address for it; put the file on this"
    say "          machine and pass --from <its directory>"
    return 1
  fi
  fetch "$path" "$url" "$size" || return 1
  remember "$role" "$path"
  return 0
}

install_model() {
  local name="$1" list="$2" dir="$MODELS_DIR/$3"
  local free failed=0 dest url size role
  say ""
  say "$name"
  mkdir -p "$dir"
  free="$(free_gb "$dir")"
  [ -n "$free" ] && say "  room on $dir: ${free} GB free"
  while IFS='|' read -r dest url size role; do
    [ -n "${dest:-}" ] || continue
    resolve "$dir" "$dest" "$url" "$size" "$role" || failed=1
  done <<< "$list"
  return $failed
}

env_file() {
  local out="$MODELS_DIR/athena.env"
  {
    say "# Written by install.sh — source this before starting the engine."
    [ -n "$ROLE_model" ] && say "export ATHENA_MODEL=$ROLE_model"
    [ -n "$ROLE_draft" ] && say "export ATHENA_DRAFT=$ROLE_draft"
    [ -n "$ROLE_mmproj" ] && say "export ATHENA_MMPROJ=$ROLE_mmproj"
  } > "$out"
  if [ -z "$ROLE_model" ]; then
    say ""
    say "No model file is in place, so $out names none."
    return 1
  fi
  say ""
  say "Wrote $out"
  [ -n "$ROLE_draft" ] || say "  (no draft head: the engine runs without speculative decoding)"
  return 0
}

main() {
  local failed=0 answer
  preflight
  if [ -z "$CHOICE" ]; then
    say ""
    say "Which model would you like to install?"
    say "  1) Qwen3.8 Flash Next   — 97 GB, reads images, the faster of the two"
    say "  2) DeepSeek V4 Flash    — 87 GB"
    if [ "$ASSUME_YES" = 1 ]; then
      CHOICE=qwen
    else
      printf 'Choice [1]: '
      read -r answer
      case "${answer:-1}" in
        1) CHOICE=qwen ;;
        2) CHOICE=deepseek ;;
        *) die "choose 1 or 2" ;;
      esac
    fi
  fi

  mkdir -p "$MODELS_DIR" || die "cannot create $MODELS_DIR"
  case "$CHOICE" in
    qwen) install_model "Qwen3.8 Flash Next" "$(qwen_files)" qwen || failed=1 ;;
    deepseek)
      install_model "DeepSeek V4 Flash" "$(deepseek_files)" deepseek || failed=1
      # The sidecar sits beside the model: if it is already there — or
      # anywhere under --from — the shards and the build are spared.
      if have_file "$(model_dir "$MODELS_DIR/deepseek")" "$DSPARK_FILE" draft; then
        say "  have  $DSPARK_FILE"
      elif install_model "DSpark draft layers" "$(dspark_shards)" deepseek; then
        build_dspark "$MODELS_DIR/deepseek" || true
      else
        failed=1
      fi
      ;;
    *) die "--model must be qwen or deepseek" ;;
  esac

  env_file || failed=1
  if [ "$failed" != 0 ]; then
    say ""
    say "Not everything is in place yet. Run the same command again: what is"
    say "already there is kept, and a half-finished download carries on."
    exit 1
  fi
  say ""
  say "Done. To start the engine:"
  say "  source $MODELS_DIR/athena.env"
  say "  ./athena-engine/athena-engine.sh"
}

main "$@"
