# athena-sentinel: the system companion

`athena-sentinel` comes with the engine and runs beside it. It reports how
the machine is doing: memory, GPUs, disks, and the state of the engine's
and the proxy's units. It shows those units' logs, restarts, stops and
starts the engine, lists every model the engine holds, switches its chat
model and shows how the engine uses its memory. Athena's "System" page,
for administrators, reads it.

It does a fixed list of things and nothing else: it runs no command it is
sent and needs no administrator rights. It is a systemd user unit, like
the engine's, running as the same user. It asks for its own token on
every route; that token is not the engine's API key, because one uses the
model and the other looks at and commands the machine. It sends no CORS
headers and refuses any request that carries an `Origin` header, which
only a browser page sends: only Athena's server calls it.

It works on any Linux machine with systemd, with any NVIDIA GPU or none.
On a GB10 (DGX Spark, ASUS Ascent GX10) the GPU has no memory of its own,
and the companion says so (`unified: true`, GPU memory `null`) instead of
reporting zero.

## Install

From the folder the release was unpacked in:

```bash
./install-sentinel.sh
```

The first time, it makes the companion's token in
`~/.config/athena-engine/sentinel.token` (readable by you only) and
prints it once. It then installs `~/.config/systemd/user/athena-sentinel.service`
and starts it on `127.0.0.1:30010`. Run it again with other options and it
rewrites the unit, keeping the token. `./install-sentinel.sh --uninstall`
removes it.

| Option | Default | |
|---|---|---|
| `--port N` | 30010 | its port on this machine |
| `--proxy-unit UNIT` | none | the HTTPS proxy's unit, shown and logged (e.g. `athena-https.service`) |
| `--proxy-system` | | that unit is a system unit: read, never acted on |
| `--engine-unit UNIT` | `athena-engine.service` | the engine's user unit |
| `--engine-url URL` | `http://127.0.0.1:30007` | the engine |
| `--engine-key-file F` | `$ATHENA_API_KEY_FILE` | the engine's API key file, to show the model it serves |
| `--models-dir DIR` | `~/models` | the models' folder, shown with the disks |
| `--listen HOST` | `127.0.0.1` | its address |

User services start with the machine only when lingering is enabled
(`loginctl enable-linger`). If the engine already starts with the machine
as a user service, it is.

## In the container

In the image, the companion is what starts: it runs the engine's launcher
as its child, so there is no systemd to ask. It passes the engine's output
on to `docker logs` and keeps its last 1000 lines for `/system/logs`. On
request it stops the engine (SIGTERM, then SIGKILL after 3 minutes) and
starts it again; a stop leaves it stopped until a start, and the companion
goes on. When the engine ends by itself, the companion ends with the same
status, and the container's restart policy applies as before.
Arguments given to the container still reach the engine.

The companion's token is made in `/state/sentinel.token` the first time and
is never printed:

```bash
docker compose -f docker/docker-compose.yml exec athena-engine cat /state/sentinel.token
```

`docker/docker-compose.yml` publishes its port on the host's `127.0.0.1`
only, for an HTTPS proxy on the host. There, `services` lists the engine as
`athena-engine.sh (process)` and no proxy, and `logs` takes `engine` and
`sentinel`. To run the engine without the companion, start the container
with `--entrypoint /opt/athena-engine/athena-engine.sh`.

## Reaching it

It listens on this machine only. Behind the HTTPS proxy
([docs/https.md](https.md)) it is published at the engine's address,
under `/system/`, with the same certificate and no new port. In the
Caddyfile, the engine's site becomes:

```caddyfile
https://athena:30443, https://athena.local:30443, https://192.168.1.50:30443 {
	tls internal

	request_body {
		max_size 40MB
	}

	handle /system/* {
		reverse_proxy 127.0.0.1:30010
	}

	handle {
		reverse_proxy 127.0.0.1:30007 {
			flush_interval -1
			transport http {
				keepalive 4s
			}
		}
	}
}
```

Then give Athena the address `https://athena:30443/system` and the token.

Without the proxy, `--listen 0.0.0.0` makes it reachable from the network.
The token is still required, but it then crosses the network as plain
text, and the companion says so in its log.

## The API (contract 2)

Every request carries `Authorization: Bearer TOKEN`. Units are always
bytes, milliseconds since the epoch, °C, W and percentages from 0 to 100.
`null` means not known: never 0.

Contract 2 keeps every route and answer of contract 1 and adds the stop
and the start of the engine, its models, a switch of its chat model and
its memory map. `contract` in the status says which one a companion
speaks. The models and the memory are the engine's: the companion asks
them with the engine's key (`--engine-key-file`), so they need it.

### `GET /system/status`

```json
{
  "contract": 2,
  "companion": { "name": "athena-sentinel", "version": "0.2.0" },
  "at": 1760627069000,
  "host": { "name": "athena", "os": "Linux 6.17.0-1026-nvidia", "uptimeMs": 177909260, "cpus": 20, "load": [0.27, 0.25, 0.2] },
  "memory": { "totalBytes": 130595991552, "availableBytes": 101755412480,
              "swapTotalBytes": 17179865088, "swapUsedBytes": 839819264, "unified": true,
              "engineMappedBytes": 92837748736, "freeBytes": 8917663744,
              "engineMappedFiles": [ { "name": "Qwen3.8-Flash-Next-UD-IQ4_XS-00002-of-00003.gguf", "bytes": 48020000000 },
                                     { "name": "mtp-Qwen3.8-Flash-Next-shared-Q8_0.gguf", "bytes": 2790000000 } ] },
  "gpus": [ { "index": 0, "name": "NVIDIA GB10", "temperatureC": 42, "utilizationPct": 0, "powerW": 10.3,
              "memoryTotalBytes": null, "memoryUsedBytes": null } ],
  "disks": [ { "mount": "/", "totalBytes": 982819848192, "freeBytes": 95622586368 } ],
  "services": [
    { "id": "engine", "unit": "athena-engine.service", "state": "active", "sinceMs": 1760620000000, "restarts": 0 },
    { "id": "proxy", "unit": "athena-https.service", "state": "active", "sinceMs": 1760600000000, "restarts": 0 }
  ],
  "engine": { "reachable": true, "model": "Athena", "activeRequests": null }
}
```

- `memory.availableBytes` is the kernel's `MemAvailable`. It counts as
  available the files the engine keeps mapped: a model it reads in place
  (`mapped` residency, Qwen's default) sits in the page cache, which the
  kernel may reclaim; but a program that took it would send the engine
  back to the disk at every step.
- `memory.engineMappedBytes`: those files, as much of them as is in memory
  (the engine process's `RssFile`; 0 when no engine runs).
- `memory.freeBytes`: what is left for other programs, `availableBytes`
  minus `engineMappedBytes` (never below 0). On unified memory, that is
  the number to watch.
- `memory.engineMappedFiles`: which files, by name, the largest first
  (those with at least 64 MiB in memory). It is read again when the engine
  or its mapped memory changes, at most once a minute.
- `memory.unified`: `true` when the GPUs have no memory of their own,
  `false` when they do, `null` without a GPU.
- `gpus`: empty on a machine without an NVIDIA GPU.
- `disks`: the root, then the models' folder unless it is on the same
  file system.
- `services[].state`: `active`, `activating`, `deactivating`,
  `inactive`, `failed` or `unknown`. `proxy` appears only when a proxy
  unit is configured.
- `engine.reachable` comes from the engine's `/health`. `model` needs
  the engine's key file. The engine does not report how many requests it
  is serving: `activeRequests` is `null`.

The GPUs, the units and the engine are read in the background every 2
seconds, so a status answers in a few milliseconds, during a generation
too. If those readings stop, a status older than 10 seconds is not passed
off as current: the units become `unknown` and the GPU figures `null`.

### `GET /system/logs?unit=engine&lines=200`

```json
{ "unit": "engine", "lines": [ { "at": 1760627000123, "text": "…" } ] }
```

- `unit`: `engine`, `proxy` (when configured) or `sentinel`. Anything else
  is `400 unknown_unit`.
- `lines`: from 1 to 1000, 200 by default. A larger number gives 1000.
- The lines come from the journal of that unit, oldest first. The engine
  is built not to write keys or the text of conversations to its log;
  even so, logs are for administrators only.

### `POST /system/services/engine/restart`, `/stop`, `/start`

- `202 {"ok": true, "unit": "engine", "at": …, "action": "restart"}`: the
  action goes on in the background. `status` shows the engine going down
  and coming back, and the companion's log records when it is stopped or
  answers again, or that it did not.
- `200 {…, "already": true}`: a stop of an engine that is not running, or
  a start of one that is.
- Each action once a minute at most: otherwise `429 too_soon`, with
  `retryAfterMs` in the error and a `Retry-After` header. A restart, a
  stop and a start each have their own minute.
- `409 busy` while an action is under way, or while the engine is starting
  or stopping.
- Only the engine, and nothing that would need more rights than the
  user's. A stopped engine stays stopped until a start: through the
  companion, `systemctl --user start athena-engine`, or a reboot when the
  unit is enabled.

### `GET /system/models`

Every model the engine was started with, of every kind, as its launcher
configured them: the chat models it can switch between (`ATHENA_MODEL`
and the alternatives), the embedding and reranking models, the voice, the
transcription and the video model. Nothing here is a fixed list: a model
added to the launcher appears by itself.

```json
{
  "contract": 2,
  "engine": { "reachable": true },
  "at": 1792530000000,
  "loaded": { "chat": "qwen" },
  "switching": null,
  "last_switch": null,
  "models": [
    { "id": "qwen", "kind": "chat", "name": "Qwen3.8 Flash Next", "family": "qwen3.8-flash-next",
      "file": "Qwen3.8-Flash-Next-UD-IQ4_XS-00001-of-00003.gguf", "bytes": 97373156480,
      "parts": [ { "role": "draft", "file": "mtp-Qwen3.8-Flash-Next-shared-Q8_0.gguf", "bytes": 2786568256 },
                 { "role": "image-encoder", "file": "mmproj-F16.gguf", "bytes": 904004000 } ],
      "loaded": true, "switchable": true, "default": true, "load_s": 25,
      "inputs": ["text", "image"], "streaming": false, "fits": null, "idle_unload_s": null },
    { "id": "embeddinggemma-2", "kind": "embedding", "name": "EmbeddingGemma 2", "family": "embeddinggemma2",
      "file": "embeddinggemma-2-mm-BF16.gguf", "bytes": 1498918496, "parts": [],
      "loaded": false, "switchable": false, "default": true, "load_s": null,
      "inputs": ["text", "image", "video", "audio"], "streaming": false, "fits": null, "idle_unload_s": 300 }
  ]
}
```

- `id`: the name a request sends. For a chat model, the name it has in
  the launcher (`qwen`, `deepseek`); for the others, the name the engine
  serves it by (`embeddinggemma-2`, `qwen3-embedding`, `qwen3-reranker`,
  `qwen3-tts`, `qwen3-asr`, `ltx-2.5`).
- `kind`: `chat`, `embedding`, `rerank`, `tts`, `asr`, `video`. Kinds may
  be added; a client shows the ones it knows.
- `bytes`: the whole model on disk, its `parts` included. `parts` are the
  files that belong to a model and have no entry of their own: drafts
  (MTP head, DSpark sidecar), image encoder, voices, the pieces of the
  video pipeline.
- `loaded`: in memory now. The models beside the chat model load at their
  first request and unload after `idle_unload_s` of rest (or when the
  engine needs their memory), so `false` is their usual state, not a
  fault. The video model holds memory only while a clip is made.
- `default`: for each kind, the one a request that names none gets; for
  chat, the one the engine starts with.
- `switchable`: `true` for the chat models only.
- `load_s`: the seconds a switch to it takes, for the chat models: the
  last load the engine measured, or an estimate from its size.
- `fits` is `null` in this contract.
- `loaded.chat`: the chat model serving now, `null` while one loads.
- `switching`: `null`, or `{"from", "to", "since", "phase"}` with `phase`
  `waiting_requests` (the answers in flight are finishing: at most 120 s)
  or `loading` (the old model is gone, the new one loads). Requests that
  arrive meanwhile wait for the new model; none is cut short.
- `last_switch`: `null`, or how the last switch ended:
  `{"to", "at", "ok", "reason"}`, `reason` `null` when it worked, else
  `requests_running` (an answer was still running after 120 s: the old
  model stays), `load_failed` (the new one did not load: the old one is
  back, or, if it did not load either, nothing is loaded and the engine
  needs a restart) or `memory_still_held`.
- When the engine does not answer, `engine.reachable` is `false` and the
  models are the last list it gave, none loaded (`[]` if it never
  answered).
- `/v1/models` keeps saying `Athena`, whichever chat model is loaded.

### `POST /system/models/switch`

`{"model": "deepseek"}`, an `id` of a chat model.

- `202 {"ok": true, "from": "qwen", "to": "deepseek", "at": …}`: the
  switch goes on in the engine; `GET /system/models` follows it.
- `200 {"ok": true, "already": true, "model": "qwen"}`: it is the one
  loaded.
- `400 not_switchable`: the id is a model of another kind.
- `404 unknown_model`: no model has that id.
- `409 busy`: a switch, or an action on the engine, is under way.
- `429 too_soon`: one switch every 30 seconds at most.
- `503 engine_unreachable`: the engine does not answer.

### `GET /system/memory`

The engine's memory map as it gives it (`version` 1): the machine
(`total`, `available`, `obtainable`, `guard`: what the engine may still
take is `obtainable − guard`), the engine's own budget by category, every
service that holds memory (`tenants`, with `bytes` and `parts`), and what
the memory guardian has lent or taken back (`residency.cessions`, with
`made`, `for` and `returning`; `residency.grants`, with `asker`). `409
busy` while the engine switches models, `503 engine_unreachable` when it
does not answer.

Video jobs (the engine's `/v1/videos`, not the companion's) keep their
OpenAI `status` while they wait for the user and say why in `waiting`:
`null`, or `{"reason": "chat"|"voice"|"memory", "since": <Unix seconds>}`.

### Errors

```json
{ "error": { "code": "bad_token", "message": "the token is missing or wrong" } }
```

| HTTP | `code` | when |
|---|---|---|
| 401 | `bad_token` | the token is missing or wrong |
| 403 | `browser_origin` | the request carries an `Origin` header |
| 404 | `not_found` | no such route, or not with that method |
| 400 | `unknown_unit` | a log unit not in the list |
| 400 | `bad_request` | a parameter out of range, or a body longer than 1 KB |
| 400 | `not_switchable` | a switch to a model that is not a chat model |
| 404 | `unknown_model` | a switch to a model the engine does not have |
| 409 | `busy` | an action or a switch is under way, or the engine is changing |
| 429 | `too_soon` | an action within a minute of the last of its kind, a switch within 30 s |
| 500 | `internal` | the companion failed (no detail in the message) |
| 501 | `not_supported` | an engine older than contract 2 |
| 502 | `engine_error` | the engine gave an answer the companion does not know |
| 503 | `engine_unreachable` | the engine does not answer |

The `message` is in English and is meant for whoever reads a log. A client
shows the user its own text for each `code`.
