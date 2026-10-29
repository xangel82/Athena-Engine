# Athena's Engine container image for NVIDIA GB10 (linux/arm64).
#
# Build context: the directory holding the release tarball and the FFmpeg
# archive.
#   docker build -f docker/Dockerfile \
#     --build-arg ATHENA_PACKAGE=athena-engine-<version>-linux-arm64-gb10.tar.gz \
#     --build-arg ATHENA_FFMPEG=athena-ffmpeg-lgpl-7.1.1-linux-arm64.tar.gz \
#     -t ghcr.io/xangel82/athena-engine:<version> <dist-dir>
#
# The CUDA runtime is pinned to the version the release is validated on.
#
# FFmpeg (video, compressed audio) is built once, LGPL 2.1 or later only, with
# the GPU's NVENC for H.264, and its archive carries the license, how it was
# built and its exact source (/opt/ffmpeg/README).  It is not part of the
# engine and not under the engine's license; the engine runs it as a program.

ARG CUDA_IMAGE=nvidia/cuda:13.0.3-runtime-ubuntu24.04
FROM ${CUDA_IMAGE}

ARG ATHENA_PACKAGE
ARG ATHENA_FFMPEG
ARG ATHENA_CUBLAS_VERSION=13.1.1.3

LABEL org.opencontainers.image.title="Athena's Engine" \
      org.opencontainers.image.vendor="Marco Palaferri" \
      org.opencontainers.image.source="https://github.com/xangel82/Athena-Engine" \
      org.opencontainers.image.licenses="PolyForm-Strict-1.0.0"

# Refuse an image whose cuBLAS differs from the validated one.
RUN version="$(dpkg-query -W -f='${Version}' 'libcublas-13-*' 2>/dev/null | head -n1)" && \
    case "$version" in \
      "${ATHENA_CUBLAS_VERSION}"*) ;; \
      *) echo "cuBLAS '$version' is not the validated ${ATHENA_CUBLAS_VERSION}" >&2; exit 1 ;; \
    esac

ADD ${ATHENA_PACKAGE} /opt/
ADD ${ATHENA_FFMPEG} /opt/
RUN mv /opt/athena-ffmpeg-lgpl-* /opt/ffmpeg && \
    ln -s /opt/ffmpeg/bin/ffmpeg /opt/ffmpeg/bin/ffprobe /usr/local/bin/ && \
    if ffmpeg -hide_banner -buildconf | grep -Eq -- "--enable-(gpl|nonfree)"; then \
      echo "the FFmpeg archive is not the LGPL build" >&2; exit 1; \
    fi

# NVENC, the GPU's video encoder, is reached through the driver's "video"
# capability.
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility,video

# Defaults for DeepSeek V4 Flash.  For Qwen3.8 Flash Next, override them at
# run time (docker run -e, or compose environment:):
#   ATHENA_MODEL=/models/Athena-Logos/Qwen3.8-Flash-Next-NVFP4-Athena-Logos-00001-of-00003.gguf
#   ATHENA_DRAFT=/models/MTP/mtp-Qwen3.8-Flash-Next-shared-Q8_0.gguf
#   ATHENA_MMPROJ=/models/MMPROJ/mmproj-F16.gguf       (to answer about images)
# For DeepSeek V4 Flash Vision-Exp, the DeepSeek that reads images:
#   ATHENA_MODEL=/models/DeepSeek-V4-Flash-Vision-Exp-IQ2XXS-w2Q2K-AProjQ8-SExpQ8-OutQ8.gguf
#   ATHENA_DRAFT=/models/DeepSeek-V4-Flash-Vision-Exp-DSpark-support.gguf
#   ATHENA_MMPROJ=/models/DeepSeek-V4-Flash-Vision-Encoder.gguf
# For DeepSeek V4.1 Flash (the 1017 checkpoint), larger than the machine and
# read from the SSD the models folder is on:
#   ATHENA_MODEL=/models/DeepSeek-V4.1-Flash-1017-IQ2_XXS-Q2_K-imatrix.gguf
# Naming more models as well — ATHENA_MODEL_2 to ATHENA_MODEL_4, each with
# its ATHENA_DRAFT_ and ATHENA_MMPROJ_ — makes the container switchable: a
# conversation writes "%switch qwen", "%switch deepseek", "%switch visio" or
# "%switch deepseek4.1" and the engine loads that one.
# Voice beside any of them (/v1/audio/speech and /v1/audio/transcriptions),
# with the speech models install.sh converts; the voice and the lexicon come
# with the image:
#   ATHENA_TTS_MODEL=/models/voice/Qwen3-TTS-12Hz-1.7B-Base-Q8_0.gguf
#   ATHENA_ASR_MODEL=/models/voice/Qwen3-ASR-1.7B-Q8_0.gguf
# Search (/v1/embeddings, /v1/rerank), the first embedding model the default:
#   ATHENA_EMBEDDING_MODEL=/models/retrieval/embeddinggemma-2-mm-BF16.gguf:/models/retrieval/Qwen3-Embedding-0.6B-Q8_0.gguf
#   ATHENA_RERANK_MODEL=/models/retrieval/Qwen3-Reranker-0.6B-Q8_0.gguf
# Video (/v1/videos), LTX 2.5's five GGUFs in one folder:
#   ATHENA_VIDEO_MODEL_DIR=/models/video
ENV ATHENA_MODEL=/models/DeepSeek-V4-Flash-IQ2XXS-w2Q2K-AProjQ8-SExpQ8-OutQ8-chat-v2-imatrix-0731.gguf \
    ATHENA_DRAFT=/models/DeepSeek-V4-Flash-DSpark-IQ2XXS-Q2K-Q8.gguf \
    ATHENA_KV_DIR=/kv \
    ATHENA_STATE_DIR=/state \
    ATHENA_PORT=30007

VOLUME ["/kv", "/state"]
EXPOSE 30007 30010
WORKDIR /opt/athena-engine
# The system companion (docs/sentinel.md) is what the image starts: it starts
# the engine's launcher as its child, passes the engine's output on, restarts
# it when asked, and ends with it, so the container's restart policy works
# as before.  Arguments given to the container still reach the engine.  The
# companion's token is made in /state the first time and never printed:
#   docker compose exec athena-engine cat /state/sentinel.token
# Publish 30010 on the host's 127.0.0.1 only (docker/docker-compose.yml).  To
# run the engine alone: --entrypoint /opt/athena-engine/athena-engine.sh
ENTRYPOINT ["/opt/athena-engine/bin/athena-sentinel", "--container", \
            "--listen", "0.0.0.0", "--port", "30010", \
            "--token-file", "/state/sentinel.token", "--token-if-missing", \
            "--engine-key-env", "ATHENA_API_KEY", "--models-dir", "/models", \
            "--", "/opt/athena-engine/athena-engine.sh"]
