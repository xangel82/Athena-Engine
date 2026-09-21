# Changelog

## 0.1.0 - unreleased

First binary release for NVIDIA GB10.

### Models

- DeepSeek V4 Flash with context up to 262,144 tokens and DSpark speculative
  decoding.
- Qwen3.8 Flash Next (Unsloth UD-IQ4_XS) with context up to 262,144 tokens and
  speculative decoding through its MTP head. It reads images and PDF pages
  when a projector is given to it.
- DeepSeek V4 Flash Vision-Exp, the DeepSeek checkpoint that reads images,
  with the DSpark drafter and the image encoder published beside it.
- Any of the three, or several. With more than one in place a conversation
  replaces the one that is running by writing `%switch qwen`,
  `%switch deepseek` or `%switch visio`: the engine drains what it is
  serving, releases the model, loads the other and answers from it, reporting
  each step as it happens. The engine never stops, and if the new model
  cannot be loaded the previous one comes back. `install.sh --model all`
  puts all three in place.

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
