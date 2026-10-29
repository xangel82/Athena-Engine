# Changelog

## 1.0.5 - 2026-10-29

Qwen3.8 Flash Next is now Athena Logos, our own four-bit quantization of
the Qwen Team's weights, and a long prompt no longer stops the
conversations that are answering. 1.0.4 was not published; what it
brought is here too.

### Qwen3.8 Flash Next as Athena Logos

- `install.sh --model qwen` fetches Athena Logos from
  [xangel82/Qwen3.8-Flash-Next-NVFP4-Athena-Logos-GGUF](https://huggingface.co/xangel82/Qwen3.8-Flash-Next-NVFP4-Athena-Logos-GGUF):
  the Qwen Team's own BF16 weights quantized for the tensor cores of the
  GB10, the routed experts and the per-layer n-gram table in NVFP4 —
  weighted by an importance matrix the engine collected while serving about
  800,000 tokens of calibration prompts, tool calls included — and the
  dense projections in MXFP8. Against the 4-bit IQ4_XS earlier releases
  ran, with the same binary on one GB10: an 8k-token prompt is read at
  1,762 tokens/s instead of 1,277, the answer after it written at 39.6
  tokens/s instead of 37.9; a short chat answer comes at 46.6 instead of
  41.6. tool-eval-bench 2.7 (temperature 1.0, seed 42, `--parallel 4`)
  scores it 88; the IQ4_XS scored 86 to 88 with the same settings.
- The MTP head and the vision encoder come from the same repository and
  are the files earlier releases fetched: a machine that installed 1.0.3
  keeps them and downloads the three parts of the model, 104 GB. The
  `UD-IQ4_XS` folder it leaves behind is no longer used and can be
  deleted.
- Athena Logos runs on Athena's Engine 1.0.5 or later only: its experts
  and n-gram table are stored in tensor types the engine defines for its
  GB10 kernels.
- The n-gram table, 28.8 GB of Athena Logos, is read from the disk
  instead of locked in memory: each step reads the rows it needs from the
  file, and the machine keeps the pages it uses in its cache. With the
  voice loaded, 24.5 GiB are left for the conversations instead of 2; the
  speed is that of the table in memory within a few per cent.
  `ATHENA_ROW_TABLE=resident` locks it in memory as before.
- A turn cut by its length limit in the middle of a multi-byte character
  no longer publishes half of it: the client got a 500 instead of the
  answer.
- A conversation no longer pauses for up to a second every seven seconds
  to capture the graphs of its steps again: they now hold for an eighth of
  the context window.
- `ATHENA_IMATRIX=FILE` has the engine collect the routed experts'
  importance matrix while it serves, in llama.cpp's layout: it is how
  Athena Logos was calibrated.

### Several conversations at once

- A long prompt gives the machine to the conversations that are answering
  between its chunks. While a 30k-token prompt was read, a chat's longest
  pause went from 17.1 to 4.7 seconds, with or without an image; the
  prompt took 21.9 seconds instead of 21.0, and every answer is the same
  bytes as before.
- When several conversations verify their drafts together, the step is
  captured as a CUDA graph once and replayed: two conversations went from
  52.1 to 53.9 tokens a second together, three from 54.4 to 55.5.
- A new prompt no longer takes the place of a long conversation another
  lane could give up: it goes to a lane holding little, then to the
  smallest. On a 31k-token chat with an image, the next message after
  twelve short requests answered from its cache in 3.1 seconds instead of
  21.3.

### Coming back to a conversation

- A conversation with images is saved to disk too, keyed by its pictures:
  after a restart, a 31k-token chat with an image came back in 4.7 seconds
  instead of 21.5 and gave the same answer as before the restart.
- A save to disk waiting on a point that rewinding the conversation takes
  back is written first: a session back from a restart restored 35,946
  tokens instead of the 47,861 its lane had saved.

## 1.0.3 - 2026-10-27

Several conversations served at once now share each step of the model, and
Qwen3.8 Flash Next is Unsloth's UD-IQ4_XS GGUF again.

### Several conversations at once

- Conversations with and without images now verify and draft their tokens in
  one pass of the model instead of taking turns. Three at once on a GB10 — a
  long answer, a chat about an image and an agent writing JSON through a tool
  — went from 34.0 to 55.4 tokens/s together, every answer the same bytes as
  when each runs alone.
- A shared step the engine cannot take keeps the drafts it already made, so
  the conversations that go on one by one do not compute them twice, and the
  log says why the step was taken apart (`TRUNK_LANE_APART`).

### Qwen3.8 Flash Next

- Unsloth's UD-IQ4_XS GGUF is again the Qwen that `install.sh --model qwen`
  fetches and the launcher runs, with its MTP head. The FP4-Local checkpoint
  and its conversion are no longer part of the installer, the launcher or
  the package. A machine that installed 1.0.2 finds the files it already has
  with `install.sh --model qwen --from ./models`.
- The thinking block ends at the model's own closing token: the same
  characters written as text inside a thought stay in the thought.
- A tool result that carries images is written inside the result, as the
  model's chat template writes it; such a request used to fail.
- For every turn that thinks, the log says how likely the model was to close
  its thought at the very first token (`THOUGHT_FIRST`), and
  `ATHENA_THOUGHT_NOT_EMPTY=1` has the engine draw that first token again
  without the closing one. It is off by default.

## 1.0.2 - 2026-10-27

Qwen3.8 Flash Next now runs as NVIDIA made it for four-bit hardware, faster
in both directions, and the engine shares the machine more safely: what it
serves beside the conversations no longer stops them, and a request short of
memory waits for it instead of being refused.

### Qwen3.8 Flash Next in NVIDIA's FP4

- The default Qwen is NVIDIA's **Qwen3.8-Flash-Next-FP4-Local**: the model
  distilled by NVIDIA to four-bit floating-point experts (NVFP4) and eight-bit
  dense layers (MXFP8), with its own MTP head as the draft. It has kernels of
  its own: the experts on the GB10's block-scale tensor cores, grouped for a
  prompt and row by row for an answer.
- NVIDIA publishes it as safetensors. `install.sh --model qwen` downloads the
  checkpoint (102 GB) and converts it on the machine with the converter that
  comes with the engine (`qwen38-nvfp4-convert`): about eight minutes on a
  GB10, 106 GB written, byte for byte the file the release is validated with,
  and then it offers to delete the checkpoint. `install.sh --convert DIR`
  converts a checkpoint already on the machine, and the launcher converts it
  by itself when `ATHENA_MODEL` names NVIDIA's folder. Beside the converted
  files the installer writes NVIDIA's and Qwen's licence notices.
- Against the IQ4_XS GGUF, on the same binary: a prompt of 8,192 tokens is
  read at 1,795 tokens/s instead of 1,279 and answered at 43.4 tokens/s
  instead of 37.7; 32,768 tokens at 1,769 and 41.1 instead of 1,275 and 36.5.
  A 196k prompt is read at 1,646 tokens/s and a 256k one at 1,588.
  tool-eval-bench 2.7 (`--parallel 4`, seed 42) gives it 88, where the IQ4_XS
  GGUF scored 86 to 88 with the same settings.
- Unsloth's UD-IQ4_XS GGUF stays available: `install.sh --model qwen-iq4`.
  With both installed, the first answers to `%switch qwen` and the other by
  its weights, `%switch qwen-fp4` or `%switch qwen-iq4`.

### Sharing the machine

- A search model loading and another asking for memory at the same moment
  could stop the engine: each waited for the other, and every conversation
  after them stopped too. Fixed; the memory guardian never waits for a
  search model's lock.
- A search or speech model coming up while a conversation was capturing its
  next step could slip its own work into that step: the new model's state was
  never cleared and the conversation's later steps wrote into it, and once
  the model was unloaded the conversation failed (`trunk verification
  failed`) and its lane stayed unusable until a restart. Fixed: a model comes
  up only between the steps of the others. 1.0.0 had it too, rarely.
- The model's weights are locked in memory. Mapping them for the GPU does
  not keep them on a GB10, and under memory pressure the system could take
  pages back while the GPU was reading them. The engine needs `memlock`
  unlimited for it (the systemd unit and `docker/docker-compose.yml` set it);
  without it the engine says so once and serves as before.
- A conversation whose state grows in the middle of an answer and finds the
  machine full asks the memory guardian before failing: first what the less
  important services hold and are not using (search unloaded, a video pausing
  at its next step), then the conversations at rest.
- Speech, transcription, embeddings and rerank wait for memory when the
  guardian finds nothing to give at once, up to 90 seconds from the request's
  arrival — the same for every service — and only then answer `503`, with
  `Retry-After: 30`. In a stress run beside two growing conversations and
  video, failed searches went from about 115 to 2 every ten minutes.
- A turn refused for memory no longer leaves its lane refusing the next
  conversation (`reset prompt proof does not match staged input`).
- A client that closes a stream in the middle of a speculative block keeps
  its lane: the next request continues the conversation instead of reading it
  again from the start.
- A regenerated answer no longer leaves the conversation's disk checkpoint
  behind: the save it replaced is still written.

## 1.0.0 - 2026-10-25

The engine now does more than chat. Beside whichever language model it
serves, it speaks, listens, searches and makes video, and it shares one
machine between all of them without running out of memory.

### Athena speaks and listens

- Two of OpenAI's audio routes, served beside whichever model answers:
  `POST /v1/audio/speech` speaks a text, `POST /v1/audio/transcriptions`
  writes down what is said. The models are the Qwen Team's
  Qwen3-TTS-12Hz-1.7B-Base and Qwen3-ASR-1.7B, converted on your machine
  from the weights their authors publish (`install.sh --voice`, with the
  release's own `qwen3-voice-convert`).
- Speech comes as WAV or raw PCM, whole or as it is made: chunked PCM, or
  `stream_format: "sse"` events. The first audio of a stream leaves the
  engine in 0.06 s, and a 12-second sentence is ready whole in 2.7 s. A
  stream is the same audio as the whole answer, and the same seed gives the
  same bytes.
- The release ships a voice, f-elegante: Italian, synthetic, designed from a
  text description, with no real speaker behind it. Another voice made for
  the same model can be named with `ATHENA_TTS_VOICE`.
- A lexicon says how words are said (`profiles/speech-lexicon.tsv`): the
  Italian voice says "Athena" as Italian says it. A transcription that
  brings no `prompt` is given "Athena" as its context (`ATHENA_ASR_PROMPT`),
  so the name comes back spelled right. Twelve seconds of speech are
  transcribed in 0.6 s.
- A client that stops reading a long stream no longer holds the voice for
  everyone else: a send that makes no progress for five seconds ends it.

### Search: embeddings and rerank

- `POST /v1/embeddings` (OpenAI's shape, with Jina's and vLLM's ways of
  sending parts) and `POST /v1/rerank` (Jina's and Cohere's shape, also at
  `/v2/rerank`).
- The default embedding model is Google's **EmbeddingGemma 2**, multimodal:
  text, pictures, video and sound go into the same vector space, so a search
  in words finds a photograph, a clip or a recording. Video is read as
  frames and its sound; compressed audio is decoded by an `ffmpeg` the
  engine runs as a separate program (it is not linked into the engine).
- **Qwen3-Embedding-0.6B** stays available by name
  (`"model": "qwen3-embedding"`, 1024 dimensions), a little better on text
  alone, and **Qwen3-Reranker-0.6B** scores passages against a question.
- The vectors are the authors' within 3e-5 of cosine distance; 32 passages of
  250 tokens are embedded in 0.2 s, a short query in 4.5 ms.
- Each model is loaded the first time it is asked for and goes away after
  five minutes without a request. When memory is short it reads its weights
  from the file instead of copying them, rather than refusing.

### Video

- `POST /v1/videos`, OpenAI's video API: a clip with its sound, from a
  description or from a picture (`input_reference`), made by Lightricks'
  **LTX 2.5**, converted on your machine from the authors' weights. Jobs are
  queued, followed with `GET /v1/videos/{id}` and downloaded from
  `/v1/videos/{id}/content`.
- Any even size from 64 pixels a side up to 1920: the clip is made on the
  model's 64-pixel grid and cut at its centre, so 1280x720 and 1080x1920
  come out exact. 1024x576 by default.
- Four seconds take about 100 s at 1024x576, 140 s at 720p and 5 to 6 minutes
  in Full HD, beside a running Qwen. Full HD needs the chat model's weights
  lent while it rests (below); beside a model that cannot lend them the
  engine refuses it at once and says 720p is the largest size.
- A job that waits says why (`waiting`: chat, voice or memory), keeping
  OpenAI's `status`.
- The clip is written in H.264 by the FFmpeg installed: with libx264 where
  that FFmpeg has it, otherwise with the GPU's own encoder (NVENC), set to the
  same quality (SSIM 0.9770 against libx264's 0.9761 on a Full HD clip).
  `ATHENA_VIDEO_ENCODER` names one.
- The container image carries an FFmpeg built for it under the LGPL, with
  NVENC, its license and its source (`/opt/ffmpeg`).

### DeepSeek V4.1 Flash: the 1017 checkpoint

- `install.sh --model deepseek4.1` installs DeepSeek's 1017 checkpoint,
  antirez's IQ2_XXS/Q2_K GGUF with imatrix (366 GB); the earlier Q2 file is
  no longer published. Warm, on its internal NVMe drive: 14.8 tokens/s, a
  6,361-token prompt read at 513 tokens/s (the earlier checkpoint: 12 and
  505).

### One machine, many services: the memory guardian

- Every service the engine runs (the conversations, the voice, search, video)
  asks one guardian for memory, by priority: the voice first, then the
  conversations, then search, then video. Nothing is taken from a
  conversation that is working; a video gives its memory back at its next
  step when someone more important needs it, and resumes where it was.
- While the conversations rest, the guardian may lend what they hold to a
  job that needs it: their idle lanes, the prefill's wider workspace, Qwen's
  mapped weights (read again from the disk before the next turn, about a
  minute). Each loan comes back before a conversation works again, and the
  answers are the same, bit for bit.
- `GET /internal/memory` shows the map: the machine, the engine's budget by
  category, every service and what it holds, and every loan.

### The system companion, contract 2

- `athena-sentinel` stops and starts the engine as well as restarting it,
  lists every model the engine was started with, of every kind, switches the
  chat model over HTTP, and passes on the memory map
  ([docs/sentinel.md](docs/sentinel.md)). The engine behind it answers
  `GET /internal/models` and `POST /internal/models/switch`.
- In a container the companion is what starts, and it starts the engine.

### Conversations

- Sampling follows what each model's authors recommend when a request does
  not say: Qwen with thinking T=1.0, without T=0.7 and a presence penalty of
  1.5; `presence_penalty` is honoured. A request without a seed gets a new
  one, so asking again gives another answer.
- Choosing among the k most likely tokens takes one pass over the vocabulary
  instead of a sort: 0.16 ms a token instead of 13.7.
- `script_guard` keeps a Chinese, Japanese or Korean letter from being glued
  into a text in another script (`auto`, `cjk` or `off`); a model's own
  protocol tokens are never refused, whatever they are spelled with.
- A phrase guard (`phrase_guard`, streaming) keeps the reply free of the
  machine's tics a client names: the colon that builds suspense, the long
  dash.
- A tool call reaches a stream only once the model has closed it: its
  start, name and arguments arrive together, in order, and a call the
  generation leaves unfinished never reaches the client (OpenAI and
  Anthropic streams alike). The arguments no longer arrive piece by piece.
- Qwen's `reasoning_effort: "auto"` is an ordinary thinking turn: the engine
  no longer asks Qwen to name a thinking budget, which it read wrongly.

### Access

- An optional API key: `ATHENA_API_KEY` or `ATHENA_API_KEY_FILE`, sent as
  `Authorization: Bearer KEY` or `x-api-key: KEY`; off unless you set it.
- [docs/https.md](docs/https.md) puts an HTTPS proxy in front of the engine.

### Fixed

- A DeepSeek answer could repeat its greeting forever when `script_guard` was
  on: its end-of-sentence token, spelled with a full-width bar, was taken for
  a Chinese letter.
- Ranges of a model file the engine had read were not given back to the
  system (`posix_madvise(DONTNEED)` does nothing on Linux).
- A turn closed with `tool_choice: "none"` — what an agent does when its tool
  rounds run out — was rendered without the tools, so Qwen's prompt changed
  from its first token: the whole conversation was read again (41,000 tokens
  in one case), and Qwen, shown calls with no tools declared, could write a
  raw `<tool_call>` block into the answer. The prompt now keeps the tools and
  the engine refuses the token that opens a call; the close reuses the
  conversation's cache.
- A conversation holding a tool call whose arguments are not a JSON object
  is answered `400 invalid_request` with the reason and what to do, instead
  of failing every later turn with a bare "native generation failed"; the
  server's log says what the template could not write.

## 0.3.4 - 2026-10-13

### Qwen reads and writes faster

- Qwen3.8 Flash Next reads a prompt 3.4 to 3.6 per cent faster: 1,226 to
  1,235 tokens/s at 8k, from 1,186 to 1,188, and 1,210 to 1,215 at 32k,
  from 1,171 to 1,172. The routed experts of a prompt chunk are now
  multiplied over as many column tiles as the busiest expert needs, instead
  of one for every token of the chunk: on an 8k prompt nearly all of the
  156,160 thread blocks launched for each expert projection found nothing
  to do. Every tile computed is the one 0.3.3 computed, bit for bit.
- Qwen3.8 Flash Next writes faster when one conversation has the machine to
  itself: its MTP head drafts three tokens instead of two, and goes back to
  two as soon as another conversation is generating, where a third draft
  costs the others more than it returns. A draft is computed only while the
  chain before it has at least a 60 per cent chance of being kept (30 in
  0.3.3). Alone, code and JSON come 7 per cent faster, an explanation 5, a
  summary after an 8k or a 32k prompt 6 and 4; free prose, where few drafts
  survive, is unchanged. Two and four conversations at once gain 1.4 and
  1.6 per cent.
- The answers are the model's: every draft is checked by the whole model,
  and a single prompt gets the same text as in 0.3.3, byte for byte, alone
  or next to other conversations. Over a long session of many turns the
  text can part at a near tie, because a token at the end of a turn may now
  be computed while reading the next prompt instead of while writing, as it
  already could after a conversation came back from disk. tool-eval-bench
  with four agents at once (seed 42) scores 92, against 91 for 0.3.3 on the
  same copy of the tool: the same scenarios, one more passed in full, none
  worse.
- DeepSeek V4 Flash and DeepSeek V4.1 Flash are unchanged: the same hashes
  as 0.3.3.

## 0.3.3 - 2026-10-12

### DeepSeek's saves leave the turn too

- DeepSeek V4 Flash no longer stops for 12 to 13 s in an agent session
  that never pauses. A disk checkpoint waits for the engine to fall quiet,
  and in 0.3.2 the next save queued behind it inside the turn: the turns
  that saved, at 21k and 32k tokens, took up to 17.6 s instead of 4.4. In
  0.3.3 a save is handed over in under 20 ms and every turn of the same
  session takes 4.0 to 4.6 s. A newer save of a conversation replaces one
  still waiting, and when two other conversations already wait, the save
  moves to a later turn.
- Same answers and same speed as 0.3.2: the DeepSeek V4 hashes are
  unchanged, and prefill and decode at 8k and 32k match 0.3.2 run for run,
  for both models. A checkpoint written while an answer is still being
  generated costs DeepSeek V4 Flash about 0.2 s, once (160 MB written in
  0.4 s), and Qwen3.8 Flash Next 0.04 s (a 124k-token checkpoint, about
  3.7 GB, written in 4.2 s).
- DeepSeek V4.1 Flash fills its arena of experts from the SSD while the
  engine waits, and 0.3.2's stalls gave it that time inside the turns.
  Requests sent back to back right after a start now run with part of the
  arena still empty until the engine pauses; after a two-minute pause a
  resumed turn takes 2.1 s, as in 0.3.2.

## 0.3.2 - 2026-10-11

### Conversations come back from disk, and saves leave the turn

- A long conversation comes back from its disk checkpoint a piece at a
  time, and needs the memory of the conversation and little else. 0.3.1
  read the whole file first and asked for twice that: right after a start,
  a 166k-token agent session was refused and read again from its first
  token, in 169 s. 0.3.2 restores 142k of it from disk in 4.6 s and answers
  the 178k-token prompt in 40 s, with the answer it gives without a
  restart.
- Qwen3.8 Flash Next writes its disk checkpoints off the turn, from the
  rewind point it has just kept: once the engine falls quiet, or alongside
  the next turn when it does not. A long agent session no longer stops for
  2 to 5 s every 10,000 tokens: with 12k-token tool results at 166k a turn
  takes 11.4 to 13.2 s, from 14 to 21 s, and a changed last answer comes in
  12.6 s, from 18 to 20. DeepSeek V4 Flash still writes its checkpoints in
  the turn.
- A chat's first answer regenerated resumes from memory too, once its
  prompt reaches 512 tokens: the prompt goes back to the lane that holds
  it, instead of the lane used longest ago, and is not read again.
- A Qwen rewind point takes 4 to 5 ms when it replaces the one before it
  (50 to 80 ms in 0.3.1), and a conversation shorter than 512 tokens keeps
  none: it is read again faster than a point is taken.

## 0.3.1 - 2026-10-11

### Agents and chats keep their place

- A conversation whose client sends its last answer back a little
  differently — an agent harness re-rendering the tool call it made, an
  edited last message — or asks the same prompt again resumes from the end
  of its last prompt instead of reading the conversation again. Qwen3.8
  Flash Next keeps that point in memory at every turn: about 166 MiB a
  conversation, whatever its length, taken in 50 to 80 ms. On a
  166k-token agent session the same prompt again answers in 1.3 s, and a
  changed last answer followed by a 12k-token tool result in 18 to 20 s,
  12 of them reading the tool result; 0.3.0 read all 166k tokens again, in
  153 s. The answer is the one the model gives reading the whole
  conversation from its start.
- A chat asked the same prompt again, as Open WebUI's Regenerate does,
  resumes from memory as well once the prompt holds an earlier answer,
  instead of being read again or restored from its disk checkpoint. Qwen
  keeps the point at every turn; DeepSeek V4 Flash only at the first long
  prompt it read, the one checkpoint it keeps with the logits to draw from.
  A prompt with no answer in its history still goes to the lane used
  longest ago, as before.

### Fixes

- A tool call left a token in the model's memory twice. When the draft
  head (Qwen's MTP, DeepSeek's DSpark) had already written the end of the
  turn that follows a call, the next turn wrote it again: one row more for
  every call of an agent session. The model read a conversation the client
  never sent, and none of its checkpoints held: Qwen's save every 10,000
  tokens failed each time, DeepSeek's were written one row long and refused
  at restore. A restarted server, or a turn the client changed, read the
  whole conversation again. DeepSeek's answers in tool sessions now differ
  slightly from 0.3.0's: they read the conversation as it is.
- A DeepSeek conversation that went back to one of those checkpoints
  answered HTTP 500. It now reads its prompt again.

## 0.3.0 - 2026-10-10

### DeepSeek V4.1 Flash, a model larger than the machine

- DeepSeek V4.1 Flash runs on one GB10. Its file is 340 GiB, on a machine
  with 128 GB: 152 GiB of weights, and 189 GiB of tables for Engram, the
  hashed n-gram memory V4.1 adds to some of its layers. The engine keeps in
  memory what every token reads, and fetches from the SSD, as it runs, the
  experts a token is routed to and the Engram rows it looks up. A prompt
  reads each layer's experts while the layer before it computes.
- Only a model that does not fit is read from the SSD, and the engine
  decides it at every load, model by model. Qwen3.8 Flash Next and DeepSeek
  V4 Flash load and run as they did, in the same engine that streams V4.1
  after a `%switch deepseek4.1`.
- V4.1 speaks its own chat template, and the tool calls it writes in its own
  syntax reach the client as tool calls, on the OpenAI and the Anthropic
  API alike. A request that forces its `tool_choice` — `required` (`any` on
  the Anthropic API) or a named tool — tells V4.1 so in its prompt, and
  `none` offers it no tools. It thinks at `high` unless asked for `none` or
  `max`.
- Its context is 16,384 tokens for now. V4.1's candidate layer covers that
  much until its block selection exists, and the engine refuses a longer
  prompt rather than answer from rows the model never sees.
  `ATHENA_V41_CONTEXT` sets a smaller one.
- Its conversations are checkpointed and restored like any other's. It has
  no draft head and no image encoder.
- `install.sh --model deepseek4.1`, or 6 in its menu, fetches the 366 GB
  file. Nothing else does: `all` stays the three models it was, and the menu
  now takes several numbers, as in `1,6`. The installer, the launcher and
  the container take up to four models.

### Engine

- Qwen3.8 Flash Next reads prompts faster. Three steps of its prefill kept
  the GPU waiting on work done one token at a time: grouping a batch's
  tokens by the experts they are routed to (8 ms a layer on an 8k chunk,
  now 0.12), the scan of its linear-attention state (1.94 µs a token, now
  1.14, and the check of the MTP head's drafts 57 µs a layer, now 10), and
  a separate pass that rounded a norm to half precision. The answers do not
  change.
- The engine no longer behaves as if the machine were its own. On a GB10
  the CPU and the GPU share memory, and an allocation the driver cannot
  back does not fail: it freezes the whole machine. The engine sized itself
  from the total memory, so one started while another process still held
  tens of gigabytes could freeze it. It now asks how much the machine can
  still back before every allocation that grows, and while a model loads
  it waits up to four minutes for memory another process is still
  returning; then it refuses, and says why. One engine loads at a time.
  A long prompt that finds the memory held by conversations nobody is
  waiting on asks their lanes to give it back, and runs: their
  conversations come back from their disk checkpoints when they are next
  asked for.
- Text a client sends is read as text. A file a tool returns, a message, a
  tool's description or a call's argument can spell a chat template's own
  markers: with Qwen, a file holding `<|im_end|><|im_start|>system` opened a
  real system turn inside the tool result, and with DeepSeek an argument
  spelling `<｜User｜>` opened a turn on the next request. The engine now
  recognises no control token inside what the client wrote. A prompt that
  spells none tokenizes as before, so every cached prefix still matches.
- Agents keep their place in two more cases. A DeepSeek conversation
  answered without thinking was replayed from its first prompt on every
  turn — 38% of the prompt reused over six turns, now 85%. An agent that
  sends its own ids back for the calls it replays, as Reasonix does, left
  its lane on every request and lost the reasoning it had written; it now
  stays, with 94% of the prompt reused and every earlier reasoning block
  read.
- A turn that stopped at `max_tokens` left a token in the model's memory
  that the conversation does not have, and every checkpoint taken after it
  was refused at restore: a restarted server read that conversation again
  from its first prompt. It no longer does.

### API

- `/v1/messages` answers the way Anthropic's clients read it: errors in its
  own shape, with the type the status carries and a `request-id` header on
  every answer; `stop_reason: "stop_sequence"` when a stop sequence ended
  the turn; no `data: [DONE]` at the end of a stream, a line its clients
  cannot read; `msg_` ids; all four `thinking.type` values;
  `thinking.budget_tokens` and `output_config.format` honoured.
- `/v1/messages` takes images and documents, read and limited exactly as
  on the OpenAI API, and the same request now behaves the same with and
  without `stream`.
- `POST /v1/messages/count_tokens` counts a prompt as the model would read
  it, without running it. `GET /v1/models` answers in a shape both
  protocols read, and `GET /v1/models/{id}` describes the model served.
- `reasoning_effort: "auto"`, experimental, on both APIs: the engine asks
  the model how much the question needs — 19 tokens added to the prompt,
  never shown — and stops its thought there. A request that names an
  effort keeps it.

### Measured on one GB10

Qwen3.8 Flash Next reads a prompt **10% faster**: 1,187 tokens/s instead of
1,074 on an 8,000-token prompt, 1,171 instead of 1,062 at 32,000 and 1,161
instead of 1,052 at 64,000. It writes 33.6 tokens/s instead of 32.6 after an
8,000-token prompt, with the MTP head as it is served. DeepSeek V4 Flash
reads and writes as it did: 1,090 tokens/s instead of 1,078 at 8,000 tokens,
and 23 tokens/s either way. Each pair was measured the same day, with the
same launcher and the same prompts, against 0.2.4.

From 8,000 tokens to 241,000, Qwen3.8 Flash Next now reads at 1,201 to 1,091
tokens/s and writes at 31 to 35, in one engine that holds fifteen
conversations side by side, as 0.2.4 did; the 241,000-token prompt was read
right after a 190,000-token one, and the lane that held it gave its memory
back.

The answers do not change. At temperature 0 Qwen3.8 Flash Next and DeepSeek
V4 Flash write the same text as 0.2.4, bit for bit, and DeepSeek V4 Flash,
with and without its DSpark sidecar, keeps the hashes every release is
checked against. Vision-Exp runs on DeepSeek V4's code and was not measured
for this release. Four agents at once on tool-eval-bench with `--seed 42
--parallel 4` score 91 out of 100 on 0.3.0, twice, and 91 on 0.2.4 run the
same night with the same copy of the tool, on the same scenarios; the 93
published with 0.2.4 was taken with tool-eval-bench 2.7.0. Raw data in
`docs/benchmarks/data/tooleval-qwen-parallel4-0.3.0.json`.

DeepSeek V4.1 Flash, from the internal NVMe drive of the same machine and
with the experts of its usual work in memory, reads a 6,400-token prompt in
12.6 seconds (505 tokens/s) and writes 12 tokens/s — 10.8 over the 52,000
tokens of its tool-eval run. A 4,900-token conversation is answered in 9.9
seconds from its disk checkpoint right after a restart, where reading it
again takes 54. In the
container, `%switch` takes 45 seconds to DeepSeek V4 Flash, 55 to V4.1 and
75 back to Qwen. On tool-eval-bench, run as the other models were but with
1,800 seconds a request, it scores 87 out of 100 (★★★★ Good): 56 passed,
8 half-passed, 5 failed. Raw data in
`docs/benchmarks/data/tooleval-deepseek-v41.json`. Like every published
score it is taken at temperature 0, the strictest setting: there V4.1 fails
TC-05 by thinking in circles until it runs out of tokens, and at 0.6 it
passes it three times out of three.

## 0.2.4 - 2026-09-27

Not published as an image: everything below ships in 0.3.0.

### Engine

- Qwen3.8 Flash Next writes faster. A token used to reach the GPU as some
  2,250 separate launches, and on the many that finish in a few microseconds
  the GPU sat idle waiting for the next one. A decoding step, and the check
  of the tokens the MTP head proposes, is now recorded once as a CUDA graph
  and replayed whole.
- The layers every token reads in full now live in the GPU's own memory. The
  engine maps the model file and lets the GPU read it in place, which on a
  GB10 costs about a quarter of the memory bandwidth. Qwen's dense layers,
  4.7 GB of the 94, are moved into memory the GPU owns; the experts, of
  which a token touches two per cent, stay where they are. Moved, not
  copied: the engine holds the memory it held before, keeps the same number
  of conversations side by side and still reads a full 262,144-token
  context. The first token of a short prompt arrives a third sooner,
  because reading a prompt goes through the same layers.

DeepSeek V4 Flash and Vision-Exp are unchanged.

### Measured on one GB10

Qwen3.8 Flash Next on a short prompt, with the MTP head as it is served:
**36.0 tokens/s instead of 32.4**, first token in 543 ms instead of 816.
Without the MTP head, 25.5 instead of 20.6. After an 8,000-token prompt,
33.8 instead of 30.3. Each pair measured the same day, with the same
launcher, against 0.2.3.

Reading a prompt is as fast as it was: 985 tokens/s at 249,000 tokens,
and fifteen conversations side by side, as in 0.2.3.

The answers do not change. Qwen3.8 Flash Next writes the same text as
0.2.3, bit for bit, with and without the MTP head, and DeepSeek V4 Flash
and Vision-Exp keep the hashes every release is checked against. Four
agents at once on the tool-eval-bench 2.7.0 run with `--seed 42
--parallel 4` score **93 out of 100** in 15 minutes; 0.2.2 scored 94, and
the two runs differ by a single scenario, TC-62, half-passed here. Raw
data in `docs/benchmarks/data/tooleval-qwen-parallel4-0.2.4.json`.

## 0.2.3 - 2026-09-23

### Engine

- An agent that asks for a longer answer than the engine will generate now
  gets an answer. Several agent harnesses derive `max_tokens` from the
  context window a model advertises and send it whole, so a request for
  256,000 tokens arrives with a 10,000-token prompt; the engine used to
  refuse every one of them, and a tool like the DeepSeek Harness could not
  hold a single conversation. It now serves what fits, as the OpenAI API
  does: the smaller of what was asked for, what the engine generates per
  request, and the room the prompt leaves. A request that asks for less than
  that still gets exactly what it asked for.

  Three things are still refused, because none can be made to fit: asking
  for no tokens at all, a prompt longer than the context, and a prompt that
  fills the context to its last token and leaves no answer to shorten.

## 0.2.2 - 2026-09-23

### Engine

- More conversations at once, and each of them faster. How many the engine
  holds side by side is no longer three numbers written by hand: the engine
  asks its own memory ledger what a lane costs and how much is left. On a
  GB10 that is fifteen lanes where it was three.
- Nobody waits behind anybody. Eight conversations arriving together used to
  be served three at a time, five of them queued for twenty-four to
  fifty-nine seconds; they now all start within nine seconds and decode at
  the same rate instead of one racing while the others wait.
- A shared pass carries every conversation the engine's tables hold — eight
  lanes, forty-eight rows — so the conversations that used to spill out into
  a pass of their own ride along instead.
- Conversations waiting for a turn now leave a shared pass together and wait
  the same window, so they meet in one pass rather than splitting into two
  sets that alternate.
- The engine asks its draft head for two tokens instead of four: the drafts
  it throws away cost more than the ones it keeps. `ATHENA_LANE_DRAFTS`
  sweeps that choice again on another machine.
- A lane the machine refuses to open, for want of memory that instant, no
  longer costs the pool a place for the life of the process.
- When more conversations ask for a turn than the model verifies in one
  pass, the ones that do not fit are carried in the pass that follows. They
  used to be turned away together, and a conversation turned away finished
  its answer on the slower path.

### Measured on one GB10

Eight conversations at once on Qwen3.8 Flash Next: **27.8 to 39.9 tokens/s**
together, and every one of the eight decodes at 5.0 to 5.4 tokens/s instead
of one racing at 25.8 while another crawls at 10.6.

Four agents at once, the same tool-eval-bench 2.7.0 run with `--seed 42
--parallel 4` that 0.2.1 published, finishes in **15 minutes instead of 82**
and scores **94 out of 100** against 95. The two runs differ by a single
scenario, and the same unchanged binary has scored 94 and 95 on different
runs. Raw data in
`docs/benchmarks/data/tooleval-qwen-parallel4-0.2.2.json`.

The answers do not change: a 19,053-token conversation hashes
7ec778311d103a80 before and after every change here, two conversations at
temperature 0 give the same text together as alone, and DeepSeek V4 Flash
and Vision-Exp write the same text, bit for bit, with and without DSpark.

## 0.2.1 - 2026-09-22

### Engine

- Several agents at once. With more conversations than the engine keeps in
  memory side by side, the turn after a tool result could come back empty:
  another conversation had taken the worker lane in the meantime, and the
  engine refilled it but still looked for the tool call it had just lost.
  It now resumes the conversation from its full history and answers.
- A client that forces the first call with `tool_choice: "required"` and then
  switches to `"auto"`, as agents commonly do, gets its answer instead of a
  409 error. This applies to every model.
- When a generation is refused, the server log says why.

### Measured on one GB10

Four agents at once on Qwen3.8 Flash Next, 69 tool-calling scenarios
(tool-eval-bench 2.7.0, `--parallel 4`): **95 out of 100** (64 passed, 3
partial, 2 failed), against 83 with 0.2.0, with no turn lost to the engine.
Raw data in `docs/benchmarks/data/tooleval-qwen-parallel4.json`. A single
conversation is served as in 0.2.0: DeepSeek V4 Flash and Vision-Exp write
the same text, bit for bit, with and without DSpark.

## 0.2.0 - 2026-09-22

### Models

- DeepSeek V4 Flash Vision-Exp, the DeepSeek checkpoint that reads images,
  with the DSpark drafter and the image encoder published beside it. On text
  it scores a little below DeepSeek V4 Flash, so the two are best installed
  side by side.
- Any of the three models, or several. With more than one in place a
  conversation replaces the one that is running by writing `%switch qwen`,
  `%switch deepseek` or `%switch visio`; each name is the checkpoint it loads.
  `install.sh --model all` puts all three in place, and `--model` also takes
  a list such as `deepseek,visio`, the first being the one that starts.

### Engine

- Pictures in DeepSeek conversations the way the model was trained on them:
  image tokens are routed to the experts with their own router biases and
  attend to each other across the whole picture.
- A conversation with pictures is not read twice: the text before the first
  picture is resumed from the cache, and so is everything past a picture the
  request carries again, byte for byte. Both models that read images do this.
- The image encoder's attention runs as one fused kernel: a picture adds
  about 0.7 seconds to the first token with Vision-Exp and 0.9 to 1.3
  seconds with Qwen3.8 Flash Next, a full-size screenshot included.
- DeepSeek V4 Flash generates 6 to 7% faster with the same output, bit for
  bit: the hyper-connection projection and the one-token Q8 projections read
  their weights at close to the memory's speed.
- The weights of a model start on a 4096-byte boundary on the device,
  whatever the layout of its file: Vision-Exp generates as fast as DeepSeek
  V4 Flash, where it was 8% slower.

### Measured on one GB10

One request at a time, each model in the configuration the launcher ships:
the full 262,144-token context, KV checkpoints on disk, and the model's own
draft. Raw data in `docs/benchmarks/data`.

| Workload | DeepSeek V4 Flash | DeepSeek V4 Flash Vision-Exp | Qwen3.8 Flash Next |
|---|---|---|---|
| Prefill, 8k-token prompt | 1,171 tokens/s | 1,127 tokens/s | 1,086 tokens/s |
| Prefill, 128k-token prompt | 1,075 tokens/s | 1,044 tokens/s | 1,018 tokens/s |
| Prefill, 256k-token prompt | 995 tokens/s | 919 tokens/s | 962 tokens/s |
| Decode, 8k context | 22.5 tokens/s | 16.6 tokens/s | 32.4 tokens/s |
| Decode, 128k context | 21.4 tokens/s | 24.3 tokens/s | 31.0 tokens/s |
| Decode, 256k context | 19.6 tokens/s | 21.1 tokens/s | 32.2 tokens/s |
| Restoring a 141,519-token conversation from disk | 1.7 s | | |
| Tool calling, 69 scenarios | 91 / 100 | 88 / 100 | 92 / 100 |

## 0.1.0 - 2026-09-19

First binary release for NVIDIA GB10.

### Models

- DeepSeek V4 Flash with context up to 262,144 tokens and DSpark speculative
  decoding.
- Qwen3.8 Flash Next (Unsloth UD-IQ4_XS) with context up to 262,144 tokens and
  speculative decoding through its MTP head. It reads images and PDF pages
  when a projector is given to it.
- Either model, or both. With both in place a conversation replaces the one
  that is running by writing `%switch deepseek`: the engine drains what it is
  serving, releases the model, loads the other and answers from it, reporting
  each step as it happens. The engine never stops, and if the new model
  cannot be loaded the previous one comes back.

### Engine

- DSpark speculative decoding with exact verification: the output is identical
  to ordinary decoding.
- Durable KV cache on disk. Checkpoints are saved at the end of a prompt, at
  the stable opening of a conversation (everything before the question it
  asks) and at regular intervals while a conversation grows, so a new
  question on a known context, a long agent session and a restarted server
  all resume from the saved state instead of prefilling again.
- Tool-calling conversations resume from the cached prefix even when the
  client rewrites call identifiers or omits the model's hidden reasoning.
- Tool calls of any practical size, such as an agent writing a whole file.
- A request that fails mid-turn no longer takes its worker lane down: the
  next complete prompt recovers it.

### API

- OpenAI- and Anthropic-compatible HTTP API: `/v1/chat/completions`,
  `/v1/completions`, `/v1/responses`, `/v1/messages`, `/v1/models`, `/health`,
  with streaming and tool calls.
- Request fields that belong to other servers' extensions are ignored instead
  of rejected, and the first streamed event carries the first token.
- Every model is served under the name `Athena` by default, so clients are
  configured once; `--api-model model` serves the model's own name and
  `--model-name` any chosen name. The name does not change when the model
  behind it does.
- `tool_choice` as `auto`, `none`, `required` or a named function;
  `parallel_tool_calls`; and `response_format` as `json_object` or
  `json_schema`. All of them on both models.

### Installing and running

- The installer, which comes in the release archive, puts one model or both
  on the machine: it uses files already there, downloads only what is
  missing, checks each file against the checksum the repository publishes,
  and resumes an interrupted download rather than starting it again.
- DeepSeek's DSpark draft head is built on the machine that installs it, out
  of the three official weight shards, with a converter that ships in the
  archive. Nothing has to be compiled by hand.
- A container image that carries the compiled engine and nothing else; the
  weights stay on the host and are mounted read-only.

### License

- Free for noncommercial use under the PolyForm Strict License 1.0.0, and —
  by an additional permission — free for internal use at work by developers
  and companies with fewer than 30 people and less than 500,000 USD in
  yearly revenue. The permission covers every version released, this one
  included. Redistribution, modified versions and offering the engine to
  others as a product or service are not allowed.

### Measured on one GB10

One request at a time, each model in the configuration the launcher ships:
the full 262,144-token context, KV checkpoints on disk, and the model's own
draft. Raw data in `docs/benchmarks/data`.

| Workload | DeepSeek V4 Flash | Qwen3.8 Flash Next |
|---|---|---|
| Prefill, 8k-token prompt | 1,126 tokens/s | 1,071 tokens/s |
| Prefill, 128k-token prompt | 1,005 tokens/s | 1,016 tokens/s |
| Prefill, 256k-token prompt | 948 tokens/s | 961 tokens/s |
| Decode, 8k context | 21.4 tokens/s | 29.9 tokens/s |
| Decode, 128k context | 19.9 tokens/s | 30.9 tokens/s |
| Decode, 256k context | 19.4 tokens/s | 32.1 tokens/s |
| New 2,048-token question on a cached 8k / 128k / 250k context | first token in 2.7 / 6.7 / 11.0 s | |
| Restoring a 141,519-token conversation from disk | 2.1 s | |

Following instructions — 69 tool-calling scenarios covering forced calls,
parallel calls, schema-bound answers, recovery from tool failures and refusals:
**91 out of 100 for both models** (58 passed, 10 and 9 partial, 1 and 2
failed). Raw transcripts in `docs/benchmarks/data`.
