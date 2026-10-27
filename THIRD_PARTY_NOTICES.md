# Third-party notices

Athena's Engine is distributed as binaries under the PolyForm Strict License
1.0.0 (see `LICENSE.md`). It includes or is derived in part from the open-source
components below, which remain under their own licenses. The notices are
reproduced as their licenses require.

## ds4 (DwarfStar)

Parts of the engine derive from ds4 by Salvatore Sanfilippo, now DwarfStar
(https://github.com/antirez/ds4). Its notice, as published in that
repository:

```
MIT License

Copyright (c) 2026 The ds4.c authors
Copyright (c) 2023-2026 The ggml authors
Copyright (c) 2023 DeepSeek

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## ggml (llama.cpp)

The quantized matrix-multiplication (MMQ) kernels used by the
mixture-of-experts path are taken from the ggml CUDA backend of llama.cpp
(https://github.com/ggml-org/llama.cpp).

```
MIT License

Copyright (c) 2023-2026 The ggml authors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## miniz

Image and document input reads DOCX files with miniz
(https://github.com/richgel999/miniz).

```
Copyright 2013-2014 RAD Game Tools and Valve Software
Copyright 2010-2014 Rich Geldreich and Tenacious Software LLC

All Rights Reserved.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
```

## stb_image

Image input decodes pictures with stb_image 2.30 by Sean Barrett
(https://github.com/nothings/stb), which its author offers under either of
two licenses:

```
------------------------------------------------------------------------------
This software is available under 2 licenses -- choose whichever you prefer.
------------------------------------------------------------------------------
ALTERNATIVE A - MIT License
Copyright (c) 2017 Sean Barrett
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
------------------------------------------------------------------------------
ALTERNATIVE B - Public Domain (www.unlicense.org)
This is free and unencumbered software released into the public domain.
Anyone is free to copy, modify, publish, use, compile, sell, or distribute this
software, either in source code form or as a compiled binary, for any purpose,
commercial or non-commercial, and by any means.
In jurisdictions that recognize copyright laws, the author or authors of this
software dedicate any and all copyright interest in the software to the public
domain. We make this dedication for the benefit of the public at large and to
the detriment of our heirs and successors. We intend this dedication to be an
overt act of relinquishment in perpetuity of all present and future rights to
this software under copyright law.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
------------------------------------------------------------------------------
```

## NVIDIA CUDA runtime (container images only)

The container images are built on `nvidia/cuda` runtime images and include the
NVIDIA CUDA runtime, cuBLAS and cuBLASLt libraries. These components are
distributed under the NVIDIA CUDA Toolkit End User License Agreement
(https://docs.nvidia.com/cuda/eula/) and the license terms of the base image.
The binary release archive does not include them.

## FFmpeg

To read video and compressed audio (an embedding of a clip or a recording)
and to write the clips it makes, the engine runs the `ffmpeg` and `ffprobe`
programs installed on the machine, as separate processes. FFmpeg is not
linked into the engine and is not part of the binary release archive; it is
licensed by its authors under the GNU LGPL 2.1 or later, or the GNU GPL
depending on how it was built (https://ffmpeg.org/legal.html).

The container image carries FFmpeg 7.1.1 in `/opt/ffmpeg`, built for it
without `--enable-gpl` and without `--enable-nonfree`, so under the GNU LGPL
2.1 or later only, with NVIDIA's nv-codec-headers (MIT) for the GPU's video
encoder. It is unmodified; `/opt/ffmpeg` holds its license, the exact
configuration it was built with and its complete source
(`/opt/ffmpeg/source`). It is not covered by the license of Athena's Engine.
The engine writes H.264 with libx264 where the installed FFmpeg has it and
with NVENC otherwise.

## Model weights

Model weights are not part of Athena's Engine and are not distributed with it:
the installer fetches them from their authors, and they are subject to the
license of their respective publishers.

| Model | Publisher | License |
|---|---|---|
| DeepSeek V4 Flash (and its DSpark draft layers) | DeepSeek | MIT |
| Qwen3.8 Flash Next (Unsloth's GGUF of it, the vision encoder and MTP head) | Qwen Team, Alibaba | Qwen Community License 1.0 |
| Qwen3.8-Flash-Next-FP4-Local, converted on your machine | NVIDIA, from the Qwen Team's model | NVIDIA Open Model Agreement; its base under the Qwen Community License 1.0 |
| Qwen3-TTS-12Hz-1.7B-Base, Qwen3-ASR-1.7B | Qwen Team, Alibaba | Apache License 2.0 |
| Qwen3-Embedding-0.6B, Qwen3-Reranker-0.6B | Qwen Team, Alibaba | Apache License 2.0 |
| EmbeddingGemma 2 | Google | Apache License 2.0, with the Gemma Prohibited Use Policy |
| LTX 2.5 | Lightricks | LTX-2.x Community License Agreement |

LTX 2.5 is free under its license for individuals and for organisations below
the revenue it sets (10 million USD a year at the time of writing); above it,
Lightricks asks for a commercial license. Its weights are published behind an
agreement on Hugging Face that you accept with your own account before the
installer can fetch them. See `CONTRIBUTIONS.md`.

The voice file in `voices/` holds no model weights: the speech codes of a
synthetic reference recording and its speaker vector, made with the Qwen
Team's Qwen3-TTS models, which are published under the Apache License 2.0.

## Credits

The people and projects this engine builds on are credited in
`CONTRIBUTIONS.md`.
