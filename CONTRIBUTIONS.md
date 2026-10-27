# Contributions and credits

Athena's Engine is designed, written and maintained by **Marco Palaferri**.
It stands on the open work of others, and this page says whose.

## Where it comes from

**Salvatore Sanfilippo (antirez) — [ds4, now DwarfStar](https://github.com/antirez/ds4).**
The spark for this project. ds4 showed that an excellent large language model
can run well on hardware a person can own, with a small native engine written
for that one purpose. It was the starting point — engine, model loader, API
server and session-oriented execution — and Athena's Engine derives in part
from that code.

**Marco Palaferri — [DS4-GB10-GX10-DSpark-CUDA](https://github.com/xangel82/DS4-GB10-GX10-DSpark-CUDA).**
The fork of ds4 that brought DeepSeek V4 Flash to a single NVIDIA GB10 and the
direct predecessor of Athena's Engine. Its original work includes:

- the DSpark GGUF sidecar integration and its lossless verifier;
- HybridLC;
- the native MXFP4 indexer scorer for GB10;
- the single-pass fused gate/up projection with token-bound streams;
- the fused HC, RMS, RoPE and MoE epilogues and their self-tests;
- the direct-F16 long-context path;
- KV and frontier handling, GB10 launch profiles, profiling and packaging.

## Also built on

**The ggml authors — [llama.cpp](https://github.com/ggml-org/llama.cpp).**
The quantized matrix-multiplication (MMQ) kernels of the mixture-of-experts
path come from the ggml CUDA backend.

**Rich Geldreich and contributors — [miniz](https://github.com/richgel999/miniz).**
Reads DOCX documents for document input.

**Sean Barrett — [stb_image](https://github.com/nothings/stb).**
Decodes pictures for image input.

**Entrpi — [Entrpi/ds4](https://github.com/Entrpi/ds4).**
Part of the CUDA prefill stack reached the fork from this fork of ds4: the
routed mixture-of-experts D2R/MMQ tiers, the aligned-SoA weight repacking,
token-tile HMMA attention and the ds4 MMQ adapters. Those components remain
attributable to Entrpi/ds4 under the MIT License.

## Models

**DeepSeek** — DeepSeek V4 Flash and its reference implementation.

**Qwen Team, Alibaba** — [Qwen3.8 Flash Next](https://huggingface.co/Qwen/Qwen3.8-Flash-Next),
and the speech models the engine converts from their published weights:
[Qwen3-TTS-12Hz-1.7B-Base](https://huggingface.co/Qwen/Qwen3-TTS-12Hz-1.7B-Base) and
[Qwen3-ASR-1.7B](https://huggingface.co/Qwen/Qwen3-ASR-1.7B) (Apache-2.0). The voice the
release ships, f-elegante, was designed from a text description with
Qwen3-TTS-12Hz-1.7B-VoiceDesign: a synthetic voice, with no real speaker behind it.

**NVIDIA** — [Qwen3.8-Flash-Next-FP4-Local](https://huggingface.co/nvidia/Qwen3.8-Flash-Next-FP4-Local),
the quantization-aware distillation of Qwen3.8 Flash Next to NVFP4 experts and MXFP8
layers, with its own MTP head, which the engine converts from the published checkpoint
and runs by default. Licensed by NVIDIA Corporation under the NVIDIA Open Model
Agreement; its base model is governed by the Qwen Community License 1.0.

**Unsloth** — the [GGUF quantization of Qwen3.8 Flash Next](https://huggingface.co/unsloth/Qwen3.8-Flash-Next-GGUF)
the engine runs as an alternative, its MTP head, and the vision encoder, tokenizer and
chat template the FP4 conversion takes from it.

**Lightricks** — [LTX 2.5](https://huggingface.co/Lightricks/LTX-2.5), the audio-video
model behind `/v1/videos`: its diffusion transformer, video and audio VAEs, latent
upsampler and text encoder (built on Google's Gemma 4 12B), which the engine converts
from the published weights and runs with its own implementation. LTX 2.5 is published
under the [LTX-2.x Community License Agreement](https://huggingface.co/Lightricks/LTX-2.5):
royalty-free for any purpose, within the use restrictions of its Attachment A, except
that entities with annual revenues of at least USD 10 million need a paid license from
Lightricks for any use other than non-commercial testing, evaluation and research.
Meeting those terms is up to whoever downloads and runs the weights.

Model weights are published by their authors under their own licenses and are
not distributed with the engine.

## Licenses

- Athena's Engine: [PolyForm Strict License 1.0.0](LICENSE.md), with an additional
  permission for internal use by small companies.
- Open-source components and their notices: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Contributing

The engine's source is not public, so code contributions are not accepted.
Bug reports, benchmark results on your own GB10 and feedback are very welcome:
open an issue in this repository.
