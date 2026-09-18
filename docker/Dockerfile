# Athena's Engine container image for NVIDIA GB10 (linux/arm64).
#
# Build context: the directory holding the release tarball.
#   docker build -f docker/Dockerfile \
#     --build-arg ATHENA_PACKAGE=athena-engine-<version>-linux-arm64-gb10.tar.gz \
#     -t ghcr.io/xangel82/athena-engine:<version> <dist-dir>
#
# The CUDA runtime is pinned to the version the release is validated on.

ARG CUDA_IMAGE=nvidia/cuda:13.0.3-runtime-ubuntu24.04
FROM ${CUDA_IMAGE}

ARG ATHENA_PACKAGE
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

# Defaults for DeepSeek V4 Flash.  For Qwen3.8 Flash Next, override them at
# run time (docker run -e, or compose environment:):
#   ATHENA_MODEL=/models/UD-IQ4_XS/Qwen3.8-Flash-Next-UD-IQ4_XS-00001-of-00003.gguf
#   ATHENA_DRAFT=/models/MTP/mtp-Qwen3.8-Flash-Next-shared-Q8_0.gguf
#   ATHENA_MMPROJ=/models/MMPROJ/mmproj-F16.gguf       (to answer about images)
ENV ATHENA_MODEL=/models/DeepSeek-V4-Flash-IQ2XXS-w2Q2K-AProjQ8-SExpQ8-OutQ8-chat-v2-imatrix-0731.gguf \
    ATHENA_DRAFT=/models/DeepSeek-V4-Flash-DSpark-IQ2XXS-Q2K-Q8.gguf \
    ATHENA_KV_DIR=/kv \
    ATHENA_STATE_DIR=/state \
    ATHENA_PORT=30007

VOLUME ["/kv", "/state"]
EXPOSE 30007
WORKDIR /opt/athena-engine
ENTRYPOINT ["/opt/athena-engine/athena-engine.sh"]
