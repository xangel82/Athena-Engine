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

**Qwen Team, Alibaba** — [Qwen3.8 Flash Next](https://huggingface.co/Qwen/Qwen3.8-Flash-Next).

**Unsloth** — the [GGUF quantization of Qwen3.8 Flash Next](https://huggingface.co/unsloth/Qwen3.8-Flash-Next-GGUF)
the engine runs, and its MTP head.

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
