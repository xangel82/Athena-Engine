# Requirements

Validated configuration for release 1.0.2.

## Hardware

- NVIDIA GB10 (DGX Spark, ASUS Ascent GX10) with 128 GB unified memory.
- Disk for the model you run (see below), plus the durable KV cache budget
  (16 GB by default).
- For DeepSeek V4.1 Flash, a fast local NVMe SSD: the engine reads the model
  from it as it runs, and the drive sets how fast it answers.

## Software

| Component | Validated version |
|---|---|
| Operating system | DGX OS (Ubuntu 24.04, arm64) |
| NVIDIA driver | 580.159.03 |
| CUDA runtime | 13.0.3 |
| cuBLAS | 13.1.1.3 |
| Docker (container release) | 29.2.1 |
| NVIDIA Container Toolkit | 1.19.1 |
| FFmpeg (video, compressed audio) | 6.1.1, the Ubuntu 24.04 package |

FFmpeg is needed only for video (`/v1/videos`) and to embed a video or a
compressed recording: the engine runs `ffmpeg` and `ffprobe` as programs.
Without them everything else works, and those requests say what is missing.

Copied out of the image and run without a container, the engine uses the CUDA
libraries installed on the host. A different cuBLAS version can change speed
and numerical results; the container itself pins the validated one.

## Models

The engine runs one model at a time. Model weights are published by their
authors and are not distributed with the engine; the installer that comes
with it fetches them, resuming if it is interrupted, and checks each file
against the checksum its repository publishes.

### DeepSeek V4 Flash — about 93 GB

From [antirez/deepseek-v4-gguf](https://huggingface.co/antirez/deepseek-v4-gguf):

| File | Role |
|---|---|
| `DeepSeek-V4-Flash-IQ2XXS-w2Q2K-AProjQ8-SExpQ8-OutQ8-chat-v2-imatrix-0731.gguf` | target model |
| `DeepSeek-V4-Flash-DSpark-IQ2XXS-Q2K-Q8.gguf` | DSpark sidecar (speculative decoding) |

The DSpark sidecar is not published as a GGUF. It belongs beside the model
it drafts for, and the installer puts it there: if the file is already next
to the model — or anywhere under the directory given to `--from` — it is
used as it lies, and otherwise it is built from the three official weight
shards that carry the draft layers, published by DeepSeek at
[deepseek-ai/DeepSeek-V4-Flash-DSpark](https://huggingface.co/deepseek-ai/DeepSeek-V4-Flash-DSpark)
(about 10 GB, downloaded once and quantised to 5.6 GB). Without the sidecar
DeepSeek V4 Flash runs perfectly well, only without speculative decoding.

### DeepSeek V4 Flash Vision-Exp — about 94 GB

DeepSeek's experimental checkpoint that reads images,
[deepseek-ai/DeepSeek-V4-Flash-Vision-Exp](https://huggingface.co/deepseek-ai/DeepSeek-V4-Flash-Vision-Exp),
quantised the same way as the model above. From
[antirez/deepseek-v4-gguf](https://huggingface.co/antirez/deepseek-v4-gguf):

| File | Role |
|---|---|
| `DeepSeek-V4-Flash-Vision-Exp-IQ2XXS-w2Q2K-AProjQ8-SExpQ8-OutQ8.gguf` | target model |
| `DeepSeek-V4-Flash-Vision-Exp-DSpark-support.gguf` | DSpark drafter (speculative decoding) |
| `DeepSeek-V4-Flash-Vision-Encoder.gguf` | vision encoder — without it the model answers text only |

All three are published as files, so nothing is built on the machine. The
encoder belongs to this checkpoint only; the launcher refuses it beside the
model above.

### Qwen3.8 Flash Next FP4-Local — about 103 GB, converted to 106 GB

NVIDIA's quantization-aware distillation of the model, from
[nvidia/Qwen3.8-Flash-Next-FP4-Local](https://huggingface.co/nvidia/Qwen3.8-Flash-Next-FP4-Local)
at revision `b9ce18a6887e18c089fdea8509a33e63429a3300`, published as
safetensors (102 GB). The installer converts it on the machine with the
release's `qwen38-nvfp4-convert`, taking the tokenizer and the chat template
from a few megabytes of
[unsloth/Qwen3.8-Flash-Next-GGUF](https://huggingface.co/unsloth/Qwen3.8-Flash-Next-GGUF)
(revision `766911a6b7369840a91dbcd95f9f997acaab6cd6`), and checks the result:

| File | Role | SHA-256 |
|---|---|---|
| `qwen-fp4/Qwen3.8-Flash-Next-FP4-Local.gguf` | target model | `cc8dbc37be6d2605f292ceb6c7ccb4d3bfc377d384be3a4ac4497ebe48dc406a` |
| `qwen-fp4/Qwen3.8-Flash-Next-FP4-Local-MTP.gguf` | its own MTP head (speculative decoding) | `dd34893eeebec65a34e5da65a88cd2c006bf8d2bbc88750810ac64186d850108` |
| `qwen/MMPROJ/mmproj-F16.gguf`, from Unsloth's repository | vision encoder — without it the model answers text only | |

The conversion reads 102 GB and writes 106 GB, about eight minutes on a GB10;
the installer then offers to delete NVIDIA's checkpoint, which the engine no
longer needs. The model is NVIDIA's, licensed by NVIDIA Corporation under the
NVIDIA Open Model Agreement, and its base, Qwen3.8-Flash-Next, is governed by
the Qwen Community License 1.0; the installer writes both notices beside the
converted files.

### Qwen3.8 Flash Next IQ4_XS — about 97 GB

From [unsloth/Qwen3.8-Flash-Next-GGUF](https://huggingface.co/unsloth/Qwen3.8-Flash-Next-GGUF),
installed with `install.sh --model qwen-iq4`:

| File | Role |
|---|---|
| `UD-IQ4_XS/Qwen3.8-Flash-Next-UD-IQ4_XS-00001-of-00003.gguf` and the two parts that follow it | target model |
| `MTP/mtp-Qwen3.8-Flash-Next-shared-Q8_0.gguf` | MTP head (speculative decoding) |
| `mmproj-F16.gguf` | vision encoder — without it the model answers text only |

### DeepSeek V4.1 Flash — about 366 GB

From [antirez/deepseek-v4.1-flash-gguf](https://huggingface.co/antirez/deepseek-v4.1-flash-gguf),
quantised from
[deepseek-ai/DeepSeek-V4.1-Flash-1017](https://huggingface.co/deepseek-ai/DeepSeek-V4.1-Flash-1017):

| File | Role |
|---|---|
| `DeepSeek-V4.1-Flash-1017-IQ2_XXS-Q2_K-imatrix.gguf` | target model |

One file of 340 GiB (sha256 `5296e85f…`): about 152 GiB of weights — IQ2_XXS
gate/up and Q2_K down experts with imatrix, Q8 attention, shared experts and
head — and 189 GiB of FP8 Engram tables. It is larger than the machine, so the engine keeps in memory what
every token reads and fetches the experts and Engram rows a token needs from
the SSD. There is no draft head and no image encoder for it, and its context
is 16,384 tokens. The installer fetches it only when it is named
(`--model deepseek4.1`, or its own entry in the menu).

The engine reads the model family from the file, so the launcher needs no
flag to tell the four apart.

## Beside the language model

The engine serves these beside whichever language model answers, each
loaded when it is first asked for. The installer fetches the authors'
weights at the revisions the release is validated with and converts them on
the machine with the converters that come with the engine.

| Install with | Model | From | On disk |
|---|---|---|---|
| `--voice` | Qwen3-TTS-12Hz-1.7B-Base, speech | [Qwen/Qwen3-TTS-12Hz-1.7B-Base](https://huggingface.co/Qwen/Qwen3-TTS-12Hz-1.7B-Base) | 2.4 GB |
| `--voice` | Qwen3-ASR-1.7B, transcription | [Qwen/Qwen3-ASR-1.7B](https://huggingface.co/Qwen/Qwen3-ASR-1.7B) | 2.2 GB |
| `--rag` | EmbeddingGemma 2, multimodal embeddings (the default) | [google/embeddinggemma-2](https://huggingface.co/google/embeddinggemma-2) | 1.5 GB |
| `--rag` | Qwen3-Embedding-0.6B, text embeddings (by name) | [Qwen/Qwen3-Embedding-0.6B](https://huggingface.co/Qwen/Qwen3-Embedding-0.6B) | 0.6 GB |
| `--rag` | Qwen3-Reranker-0.6B | [Qwen/Qwen3-Reranker-0.6B](https://huggingface.co/Qwen/Qwen3-Reranker-0.6B) | 0.6 GB |
| `--video` | LTX 2.5, video with sound | [Lightricks/LTX-2.5](https://huggingface.co/Lightricks/LTX-2.5) (accept its license first) | 71 GB |

Video takes memory the conversations hold: up to 720p it fits beside any
model; Full HD needs the chat model's weights lent while it rests, which
Qwen3.8 Flash Next can do and DeepSeek V4 Flash cannot yet.
