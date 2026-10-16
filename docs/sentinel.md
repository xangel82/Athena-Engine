# athena-sentinel: the system companion

`athena-sentinel` comes with the engine and runs beside it. It reports how
the machine is doing: memory, GPUs, disks, and the state of the engine's
and the proxy's units. It shows those units' logs and can restart the
engine. Athena's "System" page, for administrators, reads it.

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
starts it again. When the engine ends by itself, the companion ends with
the same status, and the container's restart policy applies as before.
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

## The API (contract 1)

Every request carries `Authorization: Bearer TOKEN`. Units are always
bytes, milliseconds since the epoch, °C, W and percentages from 0 to 100.
`null` means not known: never 0.

### `GET /system/status`

```json
{
  "contract": 1,
  "companion": { "name": "athena-sentinel", "version": "0.1.0" },
  "at": 1760627069000,
  "host": { "name": "athena", "os": "Linux 6.17.0-1026-nvidia", "uptimeMs": 177909260, "cpus": 20, "load": [0.27, 0.25, 0.2] },
  "memory": { "totalBytes": 130595991552, "availableBytes": 104240357376,
              "swapTotalBytes": 17179865088, "swapUsedBytes": 839819264, "unified": true },
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

- `memory.availableBytes` is the kernel's `MemAvailable`. On unified
  memory, that is the number to watch.
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

### `POST /system/services/engine/restart`

- `202 {"ok": true, "unit": "engine", "at": …}`: the restart goes on in
  the background. `status` shows the engine going down and coming back,
  and the companion's log records when it answers again, or that it did
  not.
- Once a minute at most: otherwise `429 too_soon`, with `retryAfterMs` in
  the error and a `Retry-After` header.
- `409 busy` while a restart is under way, or while the engine is starting
  or stopping.
- Only the engine, and only a restart: there is no stop, and nothing that
  would need more rights than the user's.

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
| 409 | `busy` | a restart is under way |
| 429 | `too_soon` | a restart within a minute of the last |
| 500 | `internal` | the companion failed (no detail in the message) |

The `message` is in English and is meant for whoever reads a log. A client
shows the user its own text for each `code`.
