# Requirements

Validated configuration for release 0.2.0.

## Hardware

- NVIDIA GB10 (DGX Spark, ASUS Ascent GX10) with 128 GB unified memory.
- Disk for the model you run (see below), plus the durable KV cache budget
  (16 GB by default).

## Software

| Component | Validated version |
|---|---|
| Operating system | DGX OS (Ubuntu 24.04, arm64) |
| NVIDIA driver | 580.159.03 |
| CUDA runtime | 13.0.3 |
| cuBLAS | 13.1.1.3 |
| Docker (container release) | 29.2.1 |
| NVIDIA Container Toolkit | 1.19.1 |

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

### Qwen3.8 Flash Next — about 97 GB

From [unsloth/Qwen3.8-Flash-Next-GGUF](https://huggingface.co/unsloth/Qwen3.8-Flash-Next-GGUF):

| File | Role |
|---|---|
| `UD-IQ4_XS/Qwen3.8-Flash-Next-UD-IQ4_XS-00001-of-00003.gguf` and the two parts that follow it | target model |
| `MTP/mtp-Qwen3.8-Flash-Next-shared-Q8_0.gguf` | MTP head (speculative decoding) |
| `mmproj-F16.gguf` | vision encoder — without it the model answers text only |

The engine reads the model family from the file, so the launcher needs no
flag to tell the three apart.
