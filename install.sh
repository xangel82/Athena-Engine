#!/usr/bin/env bash
# Athena's Engine installer: makes sure a model's files are on this machine
# and writes the environment that starts the engine with them.
#
#   ./install.sh                             ask which model, download into ./models
#   ./install.sh --model both                Qwen and DeepSeek; %switch picks in chat
#   ./install.sh --model all                 Qwen, DeepSeek and DeepSeek Vision-Exp
#   ./install.sh --model deepseek,visio      any list; the first is the one that starts
#   ./install.sh --model qwen,deepseek4.1    DeepSeek V4.1 Flash, 366 GB, only when named
#   ./install.sh --model qwen --dir /data/models
#   ./install.sh --model qwen --from /mnt/ggufs      use files already here
#   ./install.sh --model deepseek --verify           check what is already there
#   ./install.sh --model qwen --voice        and the voice: speech in and out
#   ./install.sh --model qwen --rag          and retrieval: embeddings and rerank
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
VOICE=""
RAG=""

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
    --voice) VOICE=1; shift ;;
    --rag) RAG=1; shift ;;
    --yes|-y) ASSUME_YES=1; shift ;;
    -h|--help) sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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
VISION_MODEL="DeepSeek-V4-Flash-Vision-Exp-IQ2XXS-w2Q2K-AProjQ8-SExpQ8-OutQ8.gguf"
VISION_DRAFT="DeepSeek-V4-Flash-Vision-Exp-DSpark-support.gguf"
VISION_ENCODER="DeepSeek-V4-Flash-Vision-Encoder.gguf"
DEEPSEEK41_REPO="$HF/antirez/deepseek-v4.1-flash-gguf/resolve/main"
DEEPSEEK41_MODEL="DeepSeek-V4.1-Flash-Q2.gguf"

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

# DeepSeek V4 Flash Vision-Exp: the checkpoint that reads images, published
# with its drafter and its image encoder, so nothing is built here.
vision_files() {
  cat <<EOF
$VISION_MODEL|$DEEPSEEK_REPO/$VISION_MODEL|87 GB|model
$VISION_DRAFT|$DEEPSEEK_REPO/$VISION_DRAFT|6.0 GB|draft
$VISION_ENCODER|$DEEPSEEK_REPO/$VISION_ENCODER|0.9 GB|mmproj
EOF
}

# DeepSeek V4.1 Flash: one file, larger than the machine's memory, so the
# engine reads its experts from the disk as it runs.  It has no draft head and
# no image encoder.  Nothing installs it unless it is named.
deepseek41_files() {
  cat <<EOF
$DEEPSEEK41_MODEL|$DEEPSEEK41_REPO/$DEEPSEEK41_MODEL|366 GB|model
EOF
}

# The voice: the Qwen Team's speech models as they publish them, at the
# revisions the engine was validated with, converted here into the files the
# engine reads by the converter the release ships (qwen3-voice-convert) —
# as the DSpark sidecar is built.  Each line: <path in the repository>|<bytes>.
QWEN_HF="$HF/Qwen"
TTS_REPO="Qwen3-TTS-12Hz-1.7B-Base"
TTS_REV="fd4b254389122332181a7c3db7f27e918eec64e3"
ASR_REPO="Qwen3-ASR-1.7B"
ASR_REV="7278e1e70fe206f11671096ffdd38061171dd6e5"
TTS_GGUF="Qwen3-TTS-12Hz-1.7B-Base-Q8_0.gguf"
TTS_PREDICTOR="Qwen3-TTS-12Hz-1.7B-Base-Q8_0-predictor.gguf"
ASR_GGUF="Qwen3-ASR-1.7B-Q8_0.gguf"
# What the converter writes from these revisions on a GB10.  Another result
# means another build of the converter or other weights; it is said, and the
# file is kept.
TTS_GGUF_SHA="5463ba6b4ff81b0fbccd4d632e305f3d88a32755abe0fd8b85432d9486fc7cfa"
TTS_PREDICTOR_SHA="08a41d0cc245c8e6bc66e70917bf1d6ce216d57832aacf72fa52380c5462a914"
ASR_GGUF_SHA="b57a2debe948404be75361e67a15b5a90598170f800cad08bfc7e3efec2f6292"

tts_sources() {
  cat <<EOF
config.json|4494
generation_config.json|245
merges.txt|1671839
preprocessor_config.json|127
tokenizer_config.json|7344
vocab.json|2776833
speech_tokenizer/config.json|2336
speech_tokenizer/configuration.json|76
speech_tokenizer/preprocessor_config.json|234
speech_tokenizer/model.safetensors|682293092
model.safetensors|3857413744
EOF
}

asr_sources() {
  cat <<EOF
chat_template.json|1161
config.json|6194
generation_config.json|142
merges.txt|1671853
model.safetensors.index.json|64821
preprocessor_config.json|330
tokenizer_config.json|12487
vocab.json|2776833
model-00002-of-00002.safetensors|478200688
model-00001-of-00002.safetensors|4220320824
EOF
}

# Retrieval: the Qwen Team's embedding model and reranker, the same way —
# their published weights at the validated revisions, converted here.
EMBED_REPO="Qwen3-Embedding-0.6B"
EMBED_REV="97b0c614be4d77ee51c0cef4e5f07c00f9eb65b3"
RERANK_REPO="Qwen3-Reranker-0.6B"
RERANK_REV="e61197ed45024b0ed8a2d74b80b4d909f1255473"
EMBED_GGUF="Qwen3-Embedding-0.6B-Q8_0.gguf"
RERANK_GGUF="Qwen3-Reranker-0.6B-Q8_0.gguf"
# What the converter writes from these revisions on a GB10 (empty until the
# reference conversion is recorded).
EMBED_GGUF_SHA="a2e52aa6b1f4563050030a6a2317e145162cafb9f4b9efab705581722977a4a5"
RERANK_GGUF_SHA="31748103da0a0c6d64cf6e2a772a6da4649636eebae95dc86ab2cd851aaa9f01"

embed_sources() {
  cat <<EOF
config.json|727
config_sentence_transformers.json|215
generation_config.json|117
modules.json|349
1_Pooling/config.json|313
merges.txt|1671853
tokenizer_config.json|9706
vocab.json|2776833
tokenizer.json|11423705
model.safetensors|1191586416
EOF
}

rerank_sources() {
  cat <<EOF
config.json|727
config_sentence_transformers.json|325
generation_config.json|214
chat_template.jinja|741
merges.txt|1671853
tokenizer_config.json|9706
vocab.json|2776833
tokenizer.json|11422654
model.safetensors|1191588280
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
dspark-hf/model.safetensors.index.json|$DSPARK_REPO/model.safetensors.index.json|5.6 MB|shards
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
  local current="$ROLE_model"
  [ "$SLOT" = 2 ] && current="$ROLE_model2"
  [ "$SLOT" = 3 ] && current="$ROLE_model3"
  [ "$SLOT" = 4 ] && current="$ROLE_model4"
  [ -n "$current" ] && dirname "$current" || printf '%s' "$fallback"
}

build_dspark() {
  local downloads="$1"
  local dir; dir="$(model_dir "$downloads")"
  # The shards may have been downloaded, or found somewhere else entirely;
  # the converter is given the folder they turned out to be in.
  local hf="${ROLE_shards:-$downloads/dspark-hf}"
  local out="$dir/$DSPARK_FILE"
  # The converter ships in the release archive.  It is looked for beside an
  # archive extracted here, beside one extracted next to this script, and
  # under this script itself — which is where it is when the installer is
  # run from inside the archive it came in.
  local tool="" here candidate
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for candidate in "$PWD/athena-engine/bin/deepseek4-quantize" \
                   "$here/athena-engine/bin/deepseek4-quantize" \
                   "$here/bin/deepseek4-quantize"; do
    [ -x "$candidate" ] && { tool="$candidate"; break; }
  done
  [ -n "$tool" ] || tool="$(command -v deepseek4-quantize 2>/dev/null)"
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
  if "$tool" --hf "$hf" --dspark-sidecar \
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

# ------------------------------------------------------------------- voice
# A tool the release ships, looked for where deepseek4-quantize is.
release_tool() {
  local name="$1" here candidate
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for candidate in "$PWD/athena-engine/bin/$name" "$here/athena-engine/bin/$name" "$here/bin/$name"; do
    [ -x "$candidate" ] && { printf '%s\n' "$candidate"; return 0; }
  done
  command -v "$name" 2>/dev/null || true
}

human_size() {
  awk -v b="$1" 'BEGIN { if (b >= 1e9) printf "%.1f GB", b / 1e9; else if (b >= 1e6) printf "%.1f MB", b / 1e6;
                         else printf "%d KB", (b + 999) / 1000 }'
}

# A repository's files in one folder, as the converter reads them: a folder of
# that name already on the machine with every file at its size, or else the
# one under the models directory, where what is missing is downloaded.  The
# folder is left in VOICE_SOURCE.
VOICE_SOURCE=""
voice_repository() {  # repository, revision, list[, folder under the models directory]
  local repo="$1" rev="$2" list="$3" area="${4:-voice}" places place candidate path bytes ok dir failed=0
  VOICE_SOURCE=""
  if [ -n "$FROM_DIR" ]; then places="$FROM_DIR"; else places="$(default_places)"; fi
  while IFS= read -r place; do
    [ -n "$place" ] || continue
    while IFS= read -r candidate; do
      [ -n "$candidate" ] || continue
      ok=1
      while IFS='|' read -r path bytes; do
        [ -n "$path" ] || continue
        if [ ! -f "$candidate/$path" ] || [ "$(wc -c < "$candidate/$path" | tr -d ' ')" != "$bytes" ]; then
          ok=0
          break
        fi
      done <<< "$list"
      if [ "$ok" = 1 ]; then VOICE_SOURCE="$candidate"; break 2; fi
    done < <(find "$place" -maxdepth 4 -type d -name "$repo" 2>/dev/null)
  done <<< "$places"
  if [ -n "$VOICE_SOURCE" ]; then
    say "  found $repo in $(dirname "$VOICE_SOURCE")"
    if [ "$VERIFY" = 1 ]; then
      while IFS='|' read -r path bytes; do
        [ -n "$path" ] || continue
        verify_file "$VOICE_SOURCE/$path" "$QWEN_HF/$repo/resolve/$rev/$path" || failed=1
      done <<< "$list"
    fi
    return $failed
  fi
  dir="$MODELS_DIR/$area/$repo"
  while IFS='|' read -r path bytes; do
    [ -n "$path" ] || continue
    if [ -f "$dir/$path" ] && [ "$(wc -c < "$dir/$path" | tr -d ' ')" = "$bytes" ]; then
      continue
    fi
    fetch "$dir/$path" "$QWEN_HF/$repo/resolve/$rev/$path" "$(human_size "$bytes")" || failed=1
  done <<< "$list"
  [ "$failed" = 0 ] && VOICE_SOURCE="$dir"
  return $failed
}

# One speech model converted beside the others.  The talker of the synthesizer
# names its predictor's file, so both are written under their final names in
# a folder of their own and moved into place together once whole.
convert_voice() {  # tool, --tts|--asr, source, revision, folder, file, sha256[, second file, its sha256]
  local tool="$1" kind="$2" src="$3" rev="$4" dir="$5" file="$6" want="$7" second="${8:-}" want2="${9:-}"
  local work="$dir/.converting" f have
  rm -rf "$work" && mkdir -p "$work" || return 1
  say "  converting $file — a minute or two"
  if ! "$tool" "$kind" "$src" --out "$work/$file" --type q8_0 --revision "$rev" > "$work/convert.log" 2>&1; then
    tail -3 "$work/convert.log" | sed 's/^/  /'
    rm -rf "$work"
    say "  $file could not be converted"
    return 1
  fi
  for f in "$file" ${second:+"$second"}; do
    [ -f "$work/$f" ] || { say "  the converter wrote no $f"; rm -rf "$work"; return 1; }
  done
  if command -v sha256sum >/dev/null; then
    have="$(sha256sum "$work/$file" | cut -d' ' -f1)"
    [ "$have" = "$want" ] || say "  note: $file is not byte for byte the reference conversion"
    if [ -n "$second" ]; then
      have="$(sha256sum "$work/$second" | cut -d' ' -f1)"
      [ "$have" = "$want2" ] || say "  note: $second is not byte for byte the reference conversion"
    fi
  fi
  for f in "$file" ${second:+"$second"}; do mv -f "$work/$f" "$dir/$f"; done
  rm -rf "$work"
  say "  converted $file"
  return 0
}

install_voice() {
  local dir="$MODELS_DIR/voice" tool free found failed=0
  say ""
  say "Voice: Qwen3-TTS-12Hz-1.7B-Base speaks, Qwen3-ASR-1.7B listens"
  mkdir -p "$dir" || return 1
  # Converted already, here or wherever models are searched for.
  found="$dir/$TTS_GGUF"; [ -f "$found" ] || found="$(locate_file "$TTS_GGUF")"
  if [ -n "$found" ] && [ -f "$(dirname "$found")/$TTS_PREDICTOR" ]; then
    say "  have  $TTS_GGUF"
    ROLE_tts="$found"
  fi
  found="$dir/$ASR_GGUF"; [ -f "$found" ] || found="$(locate_file "$ASR_GGUF")"
  if [ -n "$found" ]; then
    say "  have  $ASR_GGUF"
    ROLE_asr="$found"
  fi
  [ -n "$ROLE_tts" ] && [ -n "$ROLE_asr" ] && return 0
  tool="$(release_tool qwen3-voice-convert)"
  if [ -z "$tool" ]; then
    say "  the speech converter (qwen3-voice-convert) is not in this release;"
    say "  the engine will run without a voice."
    return 1
  fi
  free="$(free_gb "$dir")"
  [ -n "$free" ] && say "  room on $dir: ${free} GB free (the voice takes about 14 GB)"
  if [ -z "$ROLE_tts" ]; then
    if voice_repository "$TTS_REPO" "$TTS_REV" "$(tts_sources)" &&
       convert_voice "$tool" --tts "$VOICE_SOURCE" "$TTS_REV" "$dir" "$TTS_GGUF" "$TTS_GGUF_SHA" \
                     "$TTS_PREDICTOR" "$TTS_PREDICTOR_SHA"; then
      ROLE_tts="$dir/$TTS_GGUF"
    else
      failed=1
    fi
  fi
  if [ -z "$ROLE_asr" ]; then
    if voice_repository "$ASR_REPO" "$ASR_REV" "$(asr_sources)" &&
       convert_voice "$tool" --asr "$VOICE_SOURCE" "$ASR_REV" "$dir" "$ASR_GGUF" "$ASR_GGUF_SHA"; then
      ROLE_asr="$dir/$ASR_GGUF"
    else
      failed=1
    fi
  fi
  return $failed
}

install_rag() {
  local dir="$MODELS_DIR/retrieval" tool free found failed=0
  say ""
  say "Retrieval: Qwen3-Embedding-0.6B writes vectors, Qwen3-Reranker-0.6B scores passages"
  mkdir -p "$dir" || return 1
  found="$dir/$EMBED_GGUF"; [ -f "$found" ] || found="$(locate_file "$EMBED_GGUF")"
  if [ -n "$found" ]; then
    say "  have  $EMBED_GGUF"
    ROLE_embedding="$found"
  fi
  found="$dir/$RERANK_GGUF"; [ -f "$found" ] || found="$(locate_file "$RERANK_GGUF")"
  if [ -n "$found" ]; then
    say "  have  $RERANK_GGUF"
    ROLE_rerank="$found"
  fi
  [ -n "$ROLE_embedding" ] && [ -n "$ROLE_rerank" ] && return 0
  tool="$(release_tool qwen3-voice-convert)"
  if [ -z "$tool" ]; then
    say "  the converter (qwen3-voice-convert) is not in this release;"
    say "  the engine will run without retrieval."
    return 1
  fi
  free="$(free_gb "$dir")"
  [ -n "$free" ] && say "  room on $dir: ${free} GB free (retrieval takes about 4 GB)"
  if [ -z "$ROLE_embedding" ]; then
    if voice_repository "$EMBED_REPO" "$EMBED_REV" "$(embed_sources)" retrieval &&
       convert_voice "$tool" --embedding "$VOICE_SOURCE" "$EMBED_REV" "$dir" "$EMBED_GGUF" "$EMBED_GGUF_SHA"; then
      ROLE_embedding="$dir/$EMBED_GGUF"
    else
      failed=1
    fi
  fi
  if [ -z "$ROLE_rerank" ]; then
    if voice_repository "$RERANK_REPO" "$RERANK_REV" "$(rerank_sources)" retrieval &&
       convert_voice "$tool" --reranker "$VOICE_SOURCE" "$RERANK_REV" "$dir" "$RERANK_GGUF" "$RERANK_GGUF_SHA"; then
      ROLE_rerank="$dir/$RERANK_GGUF"
    else
      failed=1
    fi
  fi
  return $failed
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

# HuggingFace publishes a digest of each file in x-linked-etag, so a damaged
# download is caught here rather than by the engine hours later.  What the
# digest is depends on where the file is kept: a large file in LFS storage
# gets the sha256 of its bytes (64 hex digits), a small one kept in git gets
# the sha1 of its git blob (40 hex digits) — config.json and the tensor index
# are of the second kind.  Each is checked against the digest it is given.
#
# One request gives both facts: the digest, and the size — "x-linked-size"
# for a file in LFS storage, the length of the final response for one kept in
# git.  Printed as "<digest>|<size>"; either may be empty when the repository
# cannot be reached.
published_facts() {
  [ -n "${1:-}" ] || return 0
  curl -sIL --max-time 30 "$1" 2>/dev/null | tr -d '\r' | awk '
    tolower($1) == "x-linked-etag:"  { d = $2; gsub(/"/, "", d) }
    tolower($1) == "x-linked-size:"  { s = $2 }
    tolower($1) == "content-length:" { n = $2 }
    END { print d "|" (s != "" ? s : n) }'
}

published_sha() { published_facts "${1:-}" | cut -d'|' -f1; }

# What `git hash-object` prints, without needing git: the sha1 of a
# "blob <size>" header, a NUL, and the bytes.
git_blob_sha1() {
  local size
  size="$(wc -c < "$1" | tr -d ' ')"
  { printf 'blob %s\0' "$size"; cat "$1"; } | sha1sum | cut -d' ' -f1
}

# Is this file, found on the machine by its name, the one the repository
# publishes?  The name alone proves nothing: config.json, the tensor index,
# the weight shards and mmproj-F16.gguf are called the same in almost every
# model repository.  The size must match, and a small file kept in git is
# checked against its digest too, which costs nothing at that size.  When the
# repository cannot be reached there is nothing to compare against, and the
# file is taken on trust.
same_file() {
  local path="$1" facts="${2:-}" want_sha want_size
  want_sha="${facts%%|*}"
  want_size="${facts#*|}"
  [ -n "$want_size" ] || return 0
  [ "$(wc -c < "$path" | tr -d ' ')" = "$want_size" ] || return 1
  if [ "${#want_sha}" = 40 ] && command -v sha1sum >/dev/null; then
    [ "$(git_blob_sha1 "$path")" = "$want_sha" ] || return 1
  fi
  return 0
}

verify_file() {
  local path="$1" url="${2:-}" want have
  want="$(published_sha "$url")"
  case "${#want}" in
    64) command -v sha256sum >/dev/null || return 0
        have="$(sha256sum "$path" | cut -d' ' -f1)" ;;
    40) command -v sha1sum >/dev/null || return 0
        have="$(git_blob_sha1 "$path")" ;;
    *)  return 0 ;;
  esac
  say "  check $(basename "$path")"
  [ "$have" = "$want" ] && return 0
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
# The second, third and fourth models, when more than one is installed: the
# engine takes them as ATHENA_MODEL_2 to ATHENA_MODEL_4, and a conversation can
# then call any of them in with "%switch".
ROLE_model2=""
ROLE_draft2=""
ROLE_mmproj2=""
ROLE_model3=""
ROLE_draft3=""
ROLE_mmproj3=""
ROLE_model4=""
ROLE_draft4=""
ROLE_mmproj4=""
SLOT=1
# What a conversation writes after %switch to call each slot in.
SLOT_NAMES=()
# Not a model file: the folder the DSpark weight shards were found in, which
# the sidecar is built from and which belongs to neither slot.
ROLE_shards=""
# The speech models, which belong to no slot either: the engine serves them
# beside whichever model answers.
ROLE_tts=""
ROLE_asr=""
ROLE_embedding=""
ROLE_rerank=""

remember() {
  if [ "$1" = shards ]; then
    ROLE_shards="$(dirname "$2")"
    return 0
  fi
  if [ "$SLOT" = 2 ]; then
    case "$1" in
      model) ROLE_model2="$2" ;;
      draft) ROLE_draft2="$2" ;;
      mmproj) ROLE_mmproj2="$2" ;;
    esac
    return 0
  fi
  if [ "$SLOT" = 3 ]; then
    case "$1" in
      model) ROLE_model3="$2" ;;
      draft) ROLE_draft3="$2" ;;
      mmproj) ROLE_mmproj3="$2" ;;
    esac
    return 0
  fi
  if [ "$SLOT" = 4 ]; then
    case "$1" in
      model) ROLE_model4="$2" ;;
      draft) ROLE_draft4="$2" ;;
      mmproj) ROLE_mmproj4="$2" ;;
    esac
    return 0
  fi
  case "$1" in
    model) ROLE_model="$2" ;;
    draft) ROLE_draft="$2" ;;
    mmproj) ROLE_mmproj="$2" ;;
  esac
}

# Every file on this machine with this name, nearest first.  --from is
# searched whole; without it the usual places are tried in turn, each only a
# few levels deep.  -xtype f so a file kept as a symlink counts too.
candidates() {
  local name="$1" place
  if [ -n "$FROM_DIR" ]; then
    find "$FROM_DIR" -name "$name" -xtype f -print 2>/dev/null
    return 0
  fi
  while IFS= read -r place; do
    [ -n "$place" ] || continue
    find "$place" -maxdepth 4 -name "$name" -xtype f -print 2>/dev/null
  done <<< "$(default_places)"
}

# Where this file already is on this machine, if it is anywhere.  Given the
# address it is published at, a file that only shares its name is passed
# over and the search goes on; the first that is the same file is the one
# used.
locate_file() {
  local name="$1" url="${2:-}" facts="" candidate
  if [ -n "$url" ]; then facts="$(published_facts "$url")"; fi
  while IFS= read -r candidate; do
    [ -n "$candidate" ] || continue
    if same_file "$candidate" "$facts"; then
      printf '%s\n' "$candidate"
      return 0
    fi
    printf '  skip  %s — same name, not the same file\n' "$candidate" >&2
  done < <(candidates "$name")
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
  found="$(locate_file "$name" "$url")"
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
  # An API key written there by hand outlives a new install: losing it would
  # leave the engine open without a word.
  local keep=""
  [ -r "$out" ] && keep=$(grep -E '^export ATHENA_API_KEY(_FILE)?=' "$out" || true)
  {
    say "# Written by install.sh — source this before starting the engine."
    [ -n "$ROLE_model" ] && say "export ATHENA_MODEL=$ROLE_model"
    [ -n "$ROLE_draft" ] && say "export ATHENA_DRAFT=$ROLE_draft"
    [ -n "$ROLE_mmproj" ] && say "export ATHENA_MMPROJ=$ROLE_mmproj"
    [ -n "$ROLE_model2" ] && say "export ATHENA_MODEL_2=$ROLE_model2"
    [ -n "$ROLE_draft2" ] && say "export ATHENA_DRAFT_2=$ROLE_draft2"
    [ -n "$ROLE_mmproj2" ] && say "export ATHENA_MMPROJ_2=$ROLE_mmproj2"
    [ -n "$ROLE_model3" ] && say "export ATHENA_MODEL_3=$ROLE_model3"
    [ -n "$ROLE_draft3" ] && say "export ATHENA_DRAFT_3=$ROLE_draft3"
    [ -n "$ROLE_mmproj3" ] && say "export ATHENA_MMPROJ_3=$ROLE_mmproj3"
    [ -n "$ROLE_model4" ] && say "export ATHENA_MODEL_4=$ROLE_model4"
    [ -n "$ROLE_draft4" ] && say "export ATHENA_DRAFT_4=$ROLE_draft4"
    [ -n "$ROLE_mmproj4" ] && say "export ATHENA_MMPROJ_4=$ROLE_mmproj4"
    [ -n "$ROLE_tts" ] && say "export ATHENA_TTS_MODEL=$ROLE_tts"
    [ -n "$ROLE_asr" ] && say "export ATHENA_ASR_MODEL=$ROLE_asr"
    [ -n "$ROLE_embedding" ] && say "export ATHENA_EMBEDDING_MODEL=$ROLE_embedding"
    [ -n "$ROLE_rerank" ] && say "export ATHENA_RERANK_MODEL=$ROLE_rerank"
    [ -n "$keep" ] && say "$keep"
  } > "$out"
  [ -z "$keep" ] || chmod 600 "$out"
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

# One model into whichever slot is open.  Several models is the same work
# done again, each time into the next slot.
install_one() {
  case "$1" in
    qwen)
      install_model "Qwen3.8 Flash Next" "$(qwen_files)" qwen || return 1
      ;;
    visio|vision)
      install_model "DeepSeek V4 Flash Vision-Exp" "$(vision_files)" deepseek-vision || return 1
      ;;
    deepseek4.1)
      install_model "DeepSeek V4.1 Flash" "$(deepseek41_files)" deepseek-v41 || return 1
      ;;
    deepseek)
      local failed=0
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
      return $failed
      ;;
    *) die "--model must be qwen, deepseek, visio, deepseek4.1, both, all or a list of them" ;;
  esac
}

main() {
  local failed=0 answer
  preflight
  if [ -z "$CHOICE" ]; then
    say ""
    say "Which model would you like to install?"
    say "  1) Qwen3.8 Flash Next            — 97 GB, reads images, the fastest"
    say "  2) DeepSeek V4 Flash             — 87 GB"
    say "  3) DeepSeek V4 Flash Vision-Exp  — 94 GB, reads images"
    say "  4) Qwen and DeepSeek             — 184 GB; one runs, and a conversation"
    say "                                     calls the other in with %switch"
    say "  5) all three                     — 278 GB"
    say "  6) DeepSeek V4.1 Flash           — 366 GB, more than memory holds: the"
    say "                                     engine reads it from the disk as it runs"
    say "Several numbers, as in 1,6, install each; the first is the one that starts."
    if [ "$ASSUME_YES" = 1 ]; then
      CHOICE=qwen
    else
      printf 'Choice [1]: '
      read -r answer
      local number picked=""
      for number in ${answer//,/ }; do
        case "$number" in
          1) picked="$picked,qwen" ;;
          2) picked="$picked,deepseek" ;;
          3) picked="$picked,visio" ;;
          4) picked="$picked,qwen,deepseek" ;;
          5) picked="$picked,qwen,deepseek,visio" ;;
          6) picked="$picked,deepseek4.1" ;;
          *) die "choose 1, 2, 3, 4, 5 or 6, or several of them" ;;
        esac
      done
      CHOICE="${picked#,}"
      [ -n "$CHOICE" ] || CHOICE=qwen
    fi
  fi
  if [ -z "$VOICE" ]; then
    VOICE=0
    if [ "$ASSUME_YES" != 1 ]; then
      say ""
      say "Also the voice? The engine then speaks and listens (OpenAI's audio routes):"
      say "the Qwen Team's speech models, 9.3 GB to download and converted here."
      printf 'Voice [y/N]: '
      read -r answer
      case "$answer" in y|Y|yes|si|sì) VOICE=1 ;; esac
    fi
  fi
  if [ -z "$RAG" ]; then
    RAG=0
    if [ "$ASSUME_YES" != 1 ]; then
      say ""
      say "Also retrieval? The engine then writes embeddings and reranks passages"
      say "(/v1/embeddings, /v1/rerank): 2.4 GB to download and converted here."
      printf 'Retrieval [y/N]: '
      read -r answer
      case "$answer" in y|Y|yes|si|sì) RAG=1 ;; esac
    fi
  fi

  # Qwen first in both and all: it is the one the engine starts with, and
  # the one a %switch comes back to.  A list is taken in its own order.
  # DeepSeek V4.1 is in neither: at 366 GB it is installed only when named.
  local list one seen=" "
  case "$CHOICE" in
    both) list="qwen deepseek" ;;
    all) list="qwen deepseek visio" ;;
    *) list="${CHOICE//,/ }" ;;
  esac
  for one in $list; do
    [ "$one" = vision ] && one=visio
    case "$one" in
      qwen|deepseek|visio|deepseek4.1) ;;
      *) die "--model must be qwen, deepseek, visio, deepseek4.1, both, all or a list of them" ;;
    esac
    case "$seen" in *" $one "*) die "$one is in the list twice" ;; esac
    seen="$seen$one "
    SLOT_NAMES+=("$one")
  done
  [ "${#SLOT_NAMES[@]}" -ge 1 ] || die "no model named"
  [ "${#SLOT_NAMES[@]}" -le 4 ] || die "at most four models"

  mkdir -p "$MODELS_DIR" || die "cannot create $MODELS_DIR"
  for one in "${SLOT_NAMES[@]}"; do
    install_one "$one" || failed=1
    SLOT=$((SLOT + 1))
  done
  SLOT=1
  if [ "$VOICE" = 1 ]; then
    install_voice || failed=1
  fi
  if [ "$RAG" = 1 ]; then
    install_rag || failed=1
  fi

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
  if [ "${#SLOT_NAMES[@]}" -gt 1 ]; then
    say ""
    say "The models are in place. The engine starts with ${SLOT_NAMES[0]} and a"
    say "conversation calls another in by writing, as a message:"
    for one in "${SLOT_NAMES[@]:1}"; do say "  %switch $one"; done
  fi
  if [ -n "$ROLE_tts$ROLE_asr" ]; then
    say ""
    say "The voice is in place: the engine speaks at /v1/audio/speech and listens at"
    say "/v1/audio/transcriptions, loading each the first time it is asked."
  fi
  if [ -n "$ROLE_embedding$ROLE_rerank" ]; then
    say ""
    say "Retrieval is in place: the engine writes embeddings at /v1/embeddings and"
    say "scores passages at /v1/rerank, loading each the first time it is asked."
  fi
}

main "$@"
