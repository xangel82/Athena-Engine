# Changelog

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

DeepSeek V4.1 Flash, from the internal NVMe drive of the same machine,
reads an 8,400-token Italian text at 194 tokens/s and writes 4.0 tokens/s;
a 4,900-token conversation is answered in 9.9 seconds from its disk
checkpoint after a restart, where reading it again takes 54. In the
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
