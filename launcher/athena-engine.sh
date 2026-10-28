#!/usr/bin/env bash
# Athena's Engine launcher.
#
# Required:
#   ATHENA_MODEL          model GGUF; for a model split in parts, the first
#                         part (...-00001-of-0000N.gguf)
# Optional:
#   ATHENA_DRAFT          speculative decoding head: the DSpark sidecar for
#                         DeepSeek V4 Flash, the MTP head for Qwen3.8 Flash Next
#   ATHENA_MMPROJ         vision encoder: Qwen3.8 Flash Next's, or the one of
#                         DeepSeek V4 Flash Vision-Exp; without it the model
#                         answers text only
#   ATHENA_IMAGE_TOKENS   budget per image        (default 1024)
#   ATHENA_MODEL_2        a second model the engine can be told to load
#                         while it runs, by writing "%switch <name>" in a
#                         conversation: qwen, deepseek, visio for DeepSeek
#                         with its vision encoder, or deepseek4.1 for
#                         DeepSeek V4.1 Flash, which is larger than the
#                         machine and streams its experts from the SSD
#   ATHENA_DRAFT_2        its speculative decoding head
#   ATHENA_MMPROJ_2       its vision encoder, if it has one
#   ATHENA_MODEL_3        a third one, with ATHENA_DRAFT_3 and ATHENA_MMPROJ_3
#   ATHENA_MODEL_4        a fourth one, with ATHENA_DRAFT_4 and ATHENA_MMPROJ_4
#                         (install.sh fills them in the order it is given)
#   ATHENA_API_MODEL      athena (default): serve the model as "Athena";
#                         model: serve it by its family name
#   ATHENA_MODEL_NAME     serve this exact name instead of either
#   ATHENA_MODEL_FAMILY   deepseek-v4-flash, deepseek-v4-flash-vision,
#                         deepseek-v4.1-flash or qwen3.8-flash-next
#                         (default: read from the model file)
#   ATHENA_BIND           listen address          (default 0.0.0.0)
#   ATHENA_API_KEY        a key every client must send, as
#                         "Authorization: Bearer KEY" or "x-api-key: KEY";
#                         several separated by commas, one per client.  At
#                         least 16 characters (openssl rand -hex 32).  Unset
#                         or empty (default): no key is asked.  GET /health
#                         stays open either way
#   ATHENA_API_KEY_FILE   the same, the keys in a file only its owner may
#                         read (chmod 600), one per line
#   ATHENA_PORT           listen port             (default 30007)
#   ATHENA_CONTEXT        context length          (default 262144)
#   ATHENA_MAX_TOKENS     max generated tokens    (default 16384)
#   ATHENA_KV_CAPACITY    live KV capacity        (DeepSeek default 8192)
#   ATHENA_RESIDENCY      device or mapped        (DeepSeek default device,
#                                                  Qwen default mapped)
#   ATHENA_ROW_TABLE      resident or disk        (default resident).  disk:
#                         Qwen's n-gram table (the PLE, 29 GB of an NVFP4
#                         model) is read from the file a step at a time
#                         instead of locked in memory, which leaves room
#                         for voice beside it; the system may take its pages
#                         back, and the steps then read them from the SSD.
#                         Mapped residency only
#   ATHENA_KV_DIR         durable KV cache dir    (default ~/.cache/athena-engine/kv,
#                                                  empty string disables it)
#   ATHENA_KV_SPACE_MB    durable KV budget in MB (default 16384)
#   ATHENA_STATE_DIR      runtime state dir       (default ~/.local/state)
#   ATHENA_MAX_LANES      at most this many conversations generate at once;
#                         the others wait in the queue (default: as many as
#                         the machine holds)
# Voice, beside whichever model answers (OpenAI's audio routes); each speech
# model is loaded at its first request and unloaded after a while without one:
#   ATHENA_TTS_MODEL      speech synthesizer, the Qwen3-TTS GGUF converted
#                         from the authors' weights (its -predictor.gguf lies
#                         beside it): the engine then answers /v1/audio/speech
#   ATHENA_TTS_VOICE      the voice it speaks with, with ATHENA_TTS_VOICE_2 to
#                         _4 for more (default: the voices in voices/)
#   ATHENA_TTS_DEFAULT_VOICE  the voice a request that names none gets
#   ATHENA_TTS_LEXICON    how words are said (default profiles/speech-lexicon.tsv,
#                         empty string disables it)
#   ATHENA_ASR_MODEL      speech recognizer, the Qwen3-ASR GGUF converted from
#                         the authors' weights: the engine then answers
#                         /v1/audio/transcriptions
#   ATHENA_ASR_PROMPT     names and terms a transcription without a prompt is
#                         given, spelled as they should come out (default
#                         Athena, empty string disables it)
#   ATHENA_VOICE_IDLE     seconds a speech model stays loaded without a
#                         request (default 300; 0 keeps it once loaded)
# Retrieval, beside whichever model answers, on the same terms:
#   ATHENA_EMBEDDING_MODEL  embedding models, GGUFs converted from the
#                         authors' weights (EmbeddingGemma 2, Qwen3-Embedding),
#                         apart by ':': the engine then answers /v1/embeddings,
#                         the first model every request, each further one the
#                         requests that name it ("model": "qwen3-embedding")
#   ATHENA_RERANK_MODEL   reranker, the Qwen3-Reranker GGUF converted from the
#                         authors' weights: the engine then answers /v1/rerank
#   ATHENA_RETRIEVAL_MAX_TOKENS  longest text either reads (default 8192)
#   ATHENA_RETRIEVAL_IDLE seconds a retrieval model stays loaded without a
#                         request (default 300; 0 keeps it once loaded)
# Video, beside whichever model answers, with the memory it can give:
#   ATHENA_VIDEO_MODEL_DIR  LTX 2.5's GGUFs converted from the authors'
#                         weights (ltx25-text-bf16.gguf, ltx25-transformer-
#                         bf16.gguf, ltx25-video-vae-bf16.gguf, and for two
#                         stages and sound ltx25-latent-upsampler-bf16.gguf
#                         and ltx25-audio-vae-bf16.gguf): the engine then
#                         answers /v1/videos.  LTX 2.5 is under its own
#                         licence (LTX-2.x Community License): its terms are
#                         the user's to meet
#   ATHENA_VIDEO_OUTPUT_DIR  where the clips are kept (default: the state
#                         directory's athena-engine/videos)
# Extra arguments are passed to the server unchanged.
set -euo pipefail

root="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
fail() { echo "athena-engine: $*" >&2; exit 2; }

model="${ATHENA_MODEL:-}"
[ -n "$model" ] || fail "set ATHENA_MODEL to the model GGUF (its first part if it is split)"
[ -r "$model" ] || fail "model is not readable: $model"

# The family of a model file.  general.architecture is the first key of the
# GGUF header; a DeepSeek checkpoint variant (Vision-Exp) is named further
# on, after the tokenizer, so the first 16 MiB are read with the binary
# lengths blanked out.
model_family() {
  local path="$1" arch variant
  arch="$(head -c 65536 "$path" | LC_ALL=C grep -a -o -E 'deepseek41|deepseek4|qwen4exp' | head -n 1 || true)"
  case "$arch" in
    deepseek41) echo deepseek-v4.1-flash ;;
    deepseek4)
      variant="$(head -c 16777216 "$path" | LC_ALL=C tr '\000-\037' ' ' |
                 LC_ALL=C grep -a -o -E 'deepseek4\.checkpoint_variant +[a-z0-9-]+' |
                 head -n 1 || true)"
      case "$variant" in
        *" vision-exp") echo deepseek-v4-flash-vision ;;
        *) echo deepseek-v4-flash ;;
      esac
      ;;
    qwen4exp) echo qwen3.8-flash-next ;;
  esac
}

# The family decides the defaults below; the server refuses a file of another
# family, so a wrong guess cannot run the wrong model.
family="${ATHENA_MODEL_FAMILY:-}"
if [ -z "$family" ]; then
  family="$(model_family "$model")"
  [ -n "$family" ] || fail "cannot tell the model family of $model; set ATHENA_MODEL_FAMILY"
fi

# A model larger than the machine streams its experts from the SSD: the
# server is started with --ssd-streaming whenever one of its models is one,
# and every model that fits still loads as it always has (the engine decides
# per model, at each load).
streams=0
# The context every model is served with, but V4.1's: it stops at what its
# candidate layer covers (16384 tokens) until that layer's block selection
# exists, and the engine refuses more rather than answer from rows the model
# never sees.  Each model registered for "%switch" carries its own.
server_context="${ATHENA_CONTEXT:-262144}"
v41_context="${ATHENA_V41_CONTEXT:-16384}"
context="$server_context"
case "$family" in
  deepseek-v4-flash|deepseek-v4-flash-vision)
    draft_flag=--sidecar
    residency="${ATHENA_RESIDENCY:-device}"
    kv_capacity="${ATHENA_KV_CAPACITY:-8192}"
    ;;
  deepseek-v4.1-flash)
    # No draft head: V4.1 ships neither a DSpark sidecar nor an MTP layer.
    draft_flag=
    residency="${ATHENA_RESIDENCY:-mapped}"
    context="$v41_context"
    kv_capacity="$v41_context"
    streams=1
    ;;
  qwen3.8-flash-next)
    draft_flag=--mtp
    residency="${ATHENA_RESIDENCY:-mapped}"
    kv_capacity="${ATHENA_KV_CAPACITY:-}"
    ;;
  *) fail "unsupported model family: $family (deepseek-v4-flash, deepseek-v4-flash-vision, deepseek-v4.1-flash or qwen3.8-flash-next)" ;;
esac

args=(--model "$model"
      --model-family "$family"
      --bind "${ATHENA_BIND:-0.0.0.0}"
      --port "${ATHENA_PORT:-30007}"
      --context "$context"
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
  [ -n "$draft_flag" ] || fail "ATHENA_DRAFT: $family takes no draft head"
  [ -r "$ATHENA_DRAFT" ] || fail "draft head is not readable: $ATHENA_DRAFT"
  args+=("$draft_flag" "$ATHENA_DRAFT")
fi

if [ -n "${ATHENA_MMPROJ:-}" ]; then
  [ "$family" != deepseek-v4-flash ] || fail "ATHENA_MMPROJ: this DeepSeek checkpoint reads no images; Vision-Exp does"
  [ -r "$ATHENA_MMPROJ" ] || fail "vision encoder is not readable: $ATHENA_MMPROJ"
  args+=(--mmproj "$ATHENA_MMPROJ")
fi

# The image budget sizes Qwen's encoder; DeepSeek's encoder file fixes its own
# and takes any budget at or above it.  It is one setting for the server and
# a switch keeps it, so it goes in whenever any of the models has an encoder.
if [ -n "${ATHENA_MMPROJ:-}${ATHENA_MMPROJ_2:-}${ATHENA_MMPROJ_3:-}${ATHENA_MMPROJ_4:-}" ]; then
  args+=(--image-max-tokens "${ATHENA_IMAGE_TOKENS:-1024}")
fi

# More than one model makes the engine switchable: all of them are
# registered, and a conversation can ask for any with "%switch <name>".  The
# name says which checkpoint answers: qwen, deepseek, visio for DeepSeek V4
# Flash Vision-Exp, or deepseek4.1 for DeepSeek V4.1 Flash.  Each family
# keeps the deployment it wants — DeepSeek V4 device-resident with its small
# KV ring, Qwen mapped with the whole context, V4.1 mapped and streamed from
# the SSD — because a switch changes the model, not the machine it runs on.
registered=" "
register_model() {  # model, draft, mmproj
  local path="$1" draft="${2:-}" mmproj="${3:-}"
  local fam name entry
  fam="$(model_family "$path")"
  case "$fam" in
    deepseek-v4-flash) name=deepseek ;;
    deepseek-v4-flash-vision) name=visio ;;
    deepseek-v4.1-flash) name=deepseek4.1 ;;
    qwen3.8-flash-next) name=qwen ;;
    *) fail "cannot tell the model family of $path" ;;
  esac
  [ "$fam" != deepseek-v4-flash ] || [ -z "$mmproj" ] ||
    fail "$path reads no images; its vision encoder belongs to Vision-Exp"
  if [ "$fam" = deepseek-v4.1-flash ]; then
    [ -z "$draft" ] || fail "$path takes no draft head"
    [ -z "$mmproj" ] || fail "$path reads no images"
    streams=1
  fi
  case "$registered" in
    *" $name "*) fail "two models would both answer to \"%switch $name\"" ;;
  esac
  registered="$registered$name "
  [ -z "$draft" ] || [ -r "$draft" ] || fail "draft head is not readable: $draft"
  [ -z "$mmproj" ] || [ -r "$mmproj" ] || fail "vision encoder is not readable: $mmproj"
  entry="$name=$path,family=$fam"
  if [ "$fam" = deepseek-v4.1-flash ]; then
    entry="$entry,residency=mapped,kv=$v41_context,context=$v41_context"
  elif [ "$fam" != qwen3.8-flash-next ]; then
    entry="$entry,residency=device,kv=${ATHENA_KV_CAPACITY:-8192},context=$server_context"
    [ -n "$draft" ] && entry="$entry,draft=$draft"
  else
    entry="$entry,residency=mapped,context=$server_context"
    [ -n "$draft" ] && entry="$entry,mtp=$draft"
  fi
  [ -n "$mmproj" ] && entry="$entry,mmproj=$mmproj"
  args+=(--alt-model "$entry")
}

if [ -n "${ATHENA_MODEL_2:-}${ATHENA_MODEL_3:-}${ATHENA_MODEL_4:-}" ]; then
  register_model "$model" "${ATHENA_DRAFT:-}" "${ATHENA_MMPROJ:-}"
  for slot in 2 3 4; do
    var="ATHENA_MODEL_$slot"; path="${!var:-}"
    [ -n "$path" ] || continue
    [ -r "$path" ] || fail "model $slot is not readable: $path"
    draft_var="ATHENA_DRAFT_$slot"; mmproj_var="ATHENA_MMPROJ_$slot"
    register_model "$path" "${!draft_var:-}" "${!mmproj_var:-}"
  done
fi

[ "$streams" = 0 ] || args+=(--ssd-streaming)
[ -z "${ATHENA_MAX_LANES:-}" ] || args+=(--max-lanes "$ATHENA_MAX_LANES")

kv_dir="${ATHENA_KV_DIR-$HOME/.cache/athena-engine/kv}"
if [ -n "$kv_dir" ]; then
  mkdir -p "$kv_dir"
  args+=(--kv-disk-dir "$kv_dir" --kv-disk-space-mb "${ATHENA_KV_SPACE_MB:-16384}")
fi

# The speech models are the server's, beside whichever model answers: a
# %switch keeps them.  A voice belongs to the synthesizer it was made for; the
# release's own are in voices/.
if [ -n "${ATHENA_TTS_MODEL:-}" ]; then
  [ -r "$ATHENA_TTS_MODEL" ] || fail "speech synthesizer is not readable: $ATHENA_TTS_MODEL"
  args+=(--tts-model "$ATHENA_TTS_MODEL" --tts-idle-seconds "${ATHENA_VOICE_IDLE:-300}")
  voices=0
  for var in ATHENA_TTS_VOICE ATHENA_TTS_VOICE_2 ATHENA_TTS_VOICE_3 ATHENA_TTS_VOICE_4; do
    voice="${!var:-}"
    [ -n "$voice" ] || continue
    [ -r "$voice" ] || fail "voice is not readable: $voice"
    args+=(--tts-voice "$voice")
    voices=$((voices + 1))
  done
  if [ "$voices" = 0 ]; then
    for voice in "$root"/voices/*.gguf; do
      [ -r "$voice" ] || continue
      args+=(--tts-voice "$voice")
      voices=$((voices + 1))
    done
  fi
  [ "$voices" -gt 0 ] || fail "ATHENA_TTS_MODEL needs a voice: set ATHENA_TTS_VOICE"
  [ -z "${ATHENA_TTS_DEFAULT_VOICE:-}" ] || args+=(--tts-default-voice "$ATHENA_TTS_DEFAULT_VOICE")
  lexicon="${ATHENA_TTS_LEXICON-$root/profiles/speech-lexicon.tsv}"
  if [ -n "$lexicon" ]; then
    [ -r "$lexicon" ] || fail "speech lexicon is not readable: $lexicon"
    args+=(--tts-lexicon "$lexicon")
  fi
fi
if [ -n "${ATHENA_ASR_MODEL:-}" ]; then
  [ -r "$ATHENA_ASR_MODEL" ] || fail "speech recognizer is not readable: $ATHENA_ASR_MODEL"
  args+=(--asr-model "$ATHENA_ASR_MODEL" --asr-idle-seconds "${ATHENA_VOICE_IDLE:-300}")
  asr_prompt="${ATHENA_ASR_PROMPT-Athena}"
  [ -z "$asr_prompt" ] || args+=(--asr-prompt "$asr_prompt")
fi
# The retrieval models, the same way.
if [ -n "${ATHENA_EMBEDDING_MODEL:-}" ]; then
  IFS=: read -r -a embedding_models <<< "$ATHENA_EMBEDDING_MODEL"
  for embedding_model in "${embedding_models[@]}"; do
    [ -n "$embedding_model" ] || continue
    [ -r "$embedding_model" ] || fail "embedding model is not readable: $embedding_model"
    args+=(--embedding-model "$embedding_model")
  done
  args+=(--embedding-idle-seconds "${ATHENA_RETRIEVAL_IDLE:-300}"
         --embedding-max-tokens "${ATHENA_RETRIEVAL_MAX_TOKENS:-8192}")
fi
if [ -n "${ATHENA_RERANK_MODEL:-}" ]; then
  [ -r "$ATHENA_RERANK_MODEL" ] || fail "reranker is not readable: $ATHENA_RERANK_MODEL"
  args+=(--rerank-model "$ATHENA_RERANK_MODEL"
         --rerank-idle-seconds "${ATHENA_RETRIEVAL_IDLE:-300}"
         --rerank-max-tokens "${ATHENA_RETRIEVAL_MAX_TOKENS:-8192}")
fi

# The video model, the same way.
if [ -n "${ATHENA_VIDEO_MODEL_DIR:-}" ]; then
  for part in ltx25-text-bf16.gguf ltx25-transformer-bf16.gguf ltx25-video-vae-bf16.gguf; do
    [ -r "$ATHENA_VIDEO_MODEL_DIR/$part" ] || fail "video model is not readable: $ATHENA_VIDEO_MODEL_DIR/$part"
  done
  args+=(--video-model-dir "$ATHENA_VIDEO_MODEL_DIR")
  [ -z "${ATHENA_VIDEO_OUTPUT_DIR:-}" ] || args+=(--video-output-dir "$ATHENA_VIDEO_OUTPUT_DIR")
fi

# The API key: handed to the engine in its environment, never on its
# command line, which every user of the machine can read.
if [ -n "${ATHENA_API_KEY:-}" ]; then
  export ATHENA_API_KEY
  args+=(--api-key-env ATHENA_API_KEY)
fi
if [ -n "${ATHENA_API_KEY_FILE:-}" ]; then
  [ -r "$ATHENA_API_KEY_FILE" ] || fail "API key file is not readable: $ATHENA_API_KEY_FILE"
  args+=(--api-key-file "$ATHENA_API_KEY_FILE")
fi

export XDG_STATE_HOME="${ATHENA_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}}"
mkdir -p "$XDG_STATE_HOME"

echo "athena-engine: $family, residency $residency, serving on port ${ATHENA_PORT:-30007}" >&2

# The DSpark scheduler profile shipped in profiles/ is resolved from the
# working directory.
cd "$root"
exec "$root/bin/athena-engine" "${args[@]}" "$@"
