#!/usr/bin/env bash
# Athena's Engine launcher.
#
# Required:
#   ATHENA_MODEL          model GGUF; for a model split in parts, the first
#                         part (...-00001-of-0000N.gguf)
# Optional:
#   ATHENA_DRAFT          speculative decoding head: the DSpark sidecar for
#                         DeepSeek V4 Flash, the MTP head for Qwen3.8 Flash Next
#   ATHENA_MMPROJ         vision encoder for Qwen3.8 Flash Next; without it
#                         the model answers text only
#   ATHENA_IMAGE_TOKENS   budget per image        (default 1024)
#   ATHENA_MODEL_2        a second model the engine can be told to load
#                         while it runs, with "%switch qwen" or
#                         "%switch deepseek" written in a conversation
#   ATHENA_DRAFT_2        its speculative decoding head
#   ATHENA_MMPROJ_2       its vision encoder, if it has one
#   ATHENA_API_MODEL      athena (default): serve the model as "Athena";
#                         model: serve it by its family name
#   ATHENA_MODEL_NAME     serve this exact name instead of either
#   ATHENA_MODEL_FAMILY   deepseek-v4-flash or qwen3.8-flash-next
#                         (default: read from the model file)
#   ATHENA_BIND           listen address          (default 0.0.0.0)
#   ATHENA_PORT           listen port             (default 30007)
#   ATHENA_CONTEXT        context length          (default 262144)
#   ATHENA_MAX_TOKENS     max generated tokens    (default 16384)
#   ATHENA_KV_CAPACITY    live KV capacity        (DeepSeek default 8192)
#   ATHENA_RESIDENCY      device or mapped        (DeepSeek default device,
#                                                  Qwen default mapped)
#   ATHENA_KV_DIR         durable KV cache dir    (default ~/.cache/athena-engine/kv,
#                                                  empty string disables it)
#   ATHENA_KV_SPACE_MB    durable KV budget in MB (default 16384)
#   ATHENA_STATE_DIR      runtime state dir       (default ~/.local/state)
# Extra arguments are passed to the server unchanged.
set -euo pipefail

root="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
fail() { echo "athena-engine: $*" >&2; exit 2; }

model="${ATHENA_MODEL:-}"
[ -n "$model" ] || fail "set ATHENA_MODEL to the model GGUF (its first part if it is split)"
[ -r "$model" ] || fail "model is not readable: $model"

# The family decides the defaults below; the server refuses a file of another
# family, so a wrong guess cannot run the wrong model.
family="${ATHENA_MODEL_FAMILY:-}"
if [ -z "$family" ]; then
  # general.architecture is the first key of the GGUF header.
  arch="$(head -c 65536 "$model" | LC_ALL=C grep -a -o -E 'deepseek4|qwen4exp' | head -n 1 || true)"
  case "$arch" in
    deepseek4) family=deepseek-v4-flash ;;
    qwen4exp)  family=qwen3.8-flash-next ;;
    *) fail "cannot tell the model family of $model; set ATHENA_MODEL_FAMILY" ;;
  esac
fi

case "$family" in
  deepseek-v4-flash)
    draft_flag=--sidecar
    residency="${ATHENA_RESIDENCY:-device}"
    kv_capacity="${ATHENA_KV_CAPACITY:-8192}"
    ;;
  qwen3.8-flash-next)
    draft_flag=--mtp
    residency="${ATHENA_RESIDENCY:-mapped}"
    kv_capacity="${ATHENA_KV_CAPACITY:-}"
    ;;
  *) fail "unsupported model family: $family (deepseek-v4-flash or qwen3.8-flash-next)" ;;
esac

args=(--model "$model"
      --model-family "$family"
      --bind "${ATHENA_BIND:-0.0.0.0}"
      --port "${ATHENA_PORT:-30007}"
      --context "${ATHENA_CONTEXT:-262144}"
      --tokens "${ATHENA_MAX_TOKENS:-16384}"
      --model-residency "$residency"
      --warm-weights "$(test "$residency" = mapped && echo on || echo off)")

[ -z "$kv_capacity" ] || args+=(--kv-capacity "$kv_capacity")

if [ -n "${ATHENA_MODEL_NAME:-}" ]; then
  args+=(--model-name "$ATHENA_MODEL_NAME")
else
  case "${ATHENA_API_MODEL:-athena}" in
    athena|model) args+=(--api-model "${ATHENA_API_MODEL:-athena}") ;;
    *) fail "ATHENA_API_MODEL must be athena or model" ;;
  esac
fi

if [ -n "${ATHENA_DRAFT:-}" ]; then
  [ -r "$ATHENA_DRAFT" ] || fail "draft head is not readable: $ATHENA_DRAFT"
  args+=("$draft_flag" "$ATHENA_DRAFT")
fi

if [ -n "${ATHENA_MMPROJ:-}" ]; then
  [ "$family" = qwen3.8-flash-next ] || fail "ATHENA_MMPROJ needs qwen3.8-flash-next; $family has no vision encoder"
  [ -r "$ATHENA_MMPROJ" ] || fail "vision encoder is not readable: $ATHENA_MMPROJ"
  args+=(--mmproj "$ATHENA_MMPROJ" --image-max-tokens "${ATHENA_IMAGE_TOKENS:-1024}")
fi

# A second model makes the engine switchable: both are registered, and a
# conversation can ask for either with "%switch <name>".  Each family keeps
# the deployment it wants — DeepSeek device-resident with its small KV ring,
# Qwen mapped with the whole context — because a switch changes the model,
# not the machine it runs on.
register_model() {  # name, model, draft, mmproj
  local name="$1" path="$2" draft="${3:-}" mmproj="${4:-}"
  local fam arch entry
  arch="$(head -c 65536 "$path" | LC_ALL=C grep -a -o -E 'deepseek4|qwen4exp' | head -n 1 || true)"
  case "$arch" in
    deepseek4) fam=deepseek-v4-flash ;;
    qwen4exp)  fam=qwen3.8-flash-next ;;
    *) fail "cannot tell the model family of $path" ;;
  esac
  entry="$name=$path,family=$fam"
  if [ "$fam" = deepseek-v4-flash ]; then
    entry="$entry,residency=device,kv=${ATHENA_KV_CAPACITY:-8192}"
    [ -n "$draft" ] && entry="$entry,draft=$draft"
  else
    entry="$entry,residency=mapped"
    [ -n "$draft" ] && entry="$entry,mtp=$draft"
    [ -n "$mmproj" ] && entry="$entry,mmproj=$mmproj"
  fi
  args+=(--alt-model "$entry")
}

if [ -n "${ATHENA_MODEL_2:-}" ]; then
  [ -r "$ATHENA_MODEL_2" ] || fail "second model is not readable: $ATHENA_MODEL_2"
  case "$family" in
    deepseek-v4-flash) first=deepseek ;;
    *) first=qwen ;;
  esac
  case "$first" in
    deepseek) second=qwen ;;
    *) second=deepseek ;;
  esac
  register_model "$first" "$model" "${ATHENA_DRAFT:-}" "${ATHENA_MMPROJ:-}"
  register_model "$second" "$ATHENA_MODEL_2" "${ATHENA_DRAFT_2:-}" "${ATHENA_MMPROJ_2:-}"
fi

kv_dir="${ATHENA_KV_DIR-$HOME/.cache/athena-engine/kv}"
if [ -n "$kv_dir" ]; then
  mkdir -p "$kv_dir"
  args+=(--kv-disk-dir "$kv_dir" --kv-disk-space-mb "${ATHENA_KV_SPACE_MB:-16384}")
fi

export XDG_STATE_HOME="${ATHENA_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}}"
mkdir -p "$XDG_STATE_HOME"

echo "athena-engine: $family, residency $residency, serving on port ${ATHENA_PORT:-30007}" >&2

# The DSpark scheduler profile shipped in profiles/ is resolved from the
# working directory.
cd "$root"
exec "$root/bin/athena-engine" "${args[@]}" "$@"
