# HTTPS in front of the engine

The engine speaks plain HTTP. On a machine only you can reach, that is
enough. When its port is open to a network you do not fully trust, the
API key, the conversations and the audio cross it as plain text, and a
page served over HTTPS cannot call the engine from the browser at all
(browsers block plain-HTTP requests from secure pages). If you want
HTTPS, put a proxy in front of the engine: it terminates TLS and hands
each request to the engine unchanged. It is optional, and the engine
needs no change for it.

```
client ──HTTPS──▶ Caddy :30443 ──HTTP──▶ engine 127.0.0.1:30007
```

This page shows how to do it with [Caddy](https://caddyserver.com), a
free, open-source web server (Apache 2.0). It renews its certificates by
itself and needs a short configuration. The setup below was tested on a
GB10 with Caddy 2.11.7. Any other proxy works too, if it does what the
last section of this page asks.

What it costs: about 0.2 ms per request. Streamed answers arrive event by
event, as without the proxy. The first streamed event came within a few
milliseconds of the time it takes on a direct connection, and the first
audio of a speech stream just as fast.

## 1. Get Caddy

Take the official release from GitHub and check it against the
checksums published with it. The commands use 2.11.7, the version tested
here; take the newest 2.x release when you install, since it carries the
latest security fixes.

```bash
V=2.11.7
mkdir -p ~/caddy/download && cd ~/caddy/download
curl -fLO https://github.com/caddyserver/caddy/releases/download/v$V/caddy_${V}_linux_arm64.tar.gz
curl -fLO https://github.com/caddyserver/caddy/releases/download/v$V/caddy_${V}_checksums.txt
grep " caddy_${V}_linux_arm64.tar.gz$" caddy_${V}_checksums.txt | sha512sum -c -
tar xzf caddy_${V}_linux_arm64.tar.gz -C ~/caddy caddy
~/caddy/caddy version
```

Caddy also publishes packages for Debian and Ubuntu
([caddyserver.com/docs/install](https://caddyserver.com/docs/install)),
which the system then keeps up to date. The steps below use the binary
in `~/caddy`, run as your own user, with no administrator rights.

## 2. The configuration

Save this as `~/caddy/Caddyfile`. Replace the three addresses on the site
line with the names and the IP address your clients use to reach the
machine, and `/home/you` with your home directory.

```caddyfile
{
	# No admin endpoint (a web page could use it to rewrite this
	# configuration), no copy of the configuration written elsewhere,
	# nothing added to the system's trusted certificates.
	admin off
	persist_config off
	skip_install_trust
	auto_https disable_redirects
	storage file_system /home/you/caddy/data
	servers {
		protocols h1 h2
	}
}

https://athena:30443, https://athena.local:30443, https://192.168.1.50:30443 {
	tls internal

	# The engine takes 32 MB at most (a transcription); a little more here,
	# so that the engine, not the proxy, says what is too large.
	request_body {
		max_size 40MB
	}

	reverse_proxy 127.0.0.1:30007 {
		# Streams (chat events, speech) go out as the engine writes them.
		flush_interval -1
		transport http {
			# The engine closes a connection idle for 5 s: never reuse
			# one idle longer than 4.
			keepalive 4s
		}
	}
}
```

What each part does:

- `tls internal`: Caddy makes its own certificate authority in
  `~/caddy/data` and issues certificates for the names on the site line
  from it. Your devices trust them once you install that authority's
  certificate on them (step 5). For certificates every device already
  trusts, see the alternatives at the end of this page.
- `admin off`: Caddy otherwise listens on a local admin port (2019) that
  can replace its whole configuration. A proxy that only forwards
  requests has no use for it.
- No access log. Caddy writes none unless asked to, and that keeps the
  `Authorization` and `x-api-key` headers out of any log file.
- `flush_interval -1`: without it, a streamed answer would reach the
  client in bursts or all at the end.
- `keepalive 4s`: the engine closes a connection that has been idle for
  5 seconds. A proxy that reused such a connection would answer a request
  with an error 502.

Check it before you start it:

```bash
~/caddy/caddy validate --config ~/caddy/Caddyfile --adapter caddyfile
```

## 3. Start it

To try it, run it in a terminal; Ctrl-C stops it:

```bash
~/caddy/caddy run --config ~/caddy/Caddyfile --adapter caddyfile
```

To keep it running and have it start with the machine, make it a user
service, like the engine's own unit. Save this as
`~/.config/systemd/user/athena-https.service`:

```ini
[Unit]
Description=HTTPS in front of Athena's Engine
After=network-online.target

[Service]
ExecStart=%h/caddy/caddy run --config %h/caddy/Caddyfile --adapter caddyfile
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
```

```bash
systemctl --user daemon-reload
systemctl --user enable --now athena-https
```

User services start at boot only if lingering is enabled for your user
(`loginctl enable-linger`). If the engine already runs as a user service
that starts with the machine, it is.

Port 30443 needs no privileges. To serve on 443, the standard HTTPS port,
Caddy needs the right to bind it. Caddy's Debian and Ubuntu package runs
it as a system service that has that right.

## 4. Close the plain port

As long as the engine listens on every address, a client can still go
around the proxy in plain HTTP. Once HTTPS works, have the engine listen
on the machine only. Add this to `athena.env`, then restart the engine:

```bash
export ATHENA_BIND=127.0.0.1
```

In the container, leave `ATHENA_BIND` alone: inside the container the
engine must keep listening on every address, or Docker cannot reach it.
Publish the port on the machine only instead: `"127.0.0.1:30007:30007"`
under `ports:` in `docker/docker-compose.yml`. The container's health
check talks to the engine from inside the container, so it keeps working.

Turn on the API key too (see "An API key" in the README). HTTPS hides the
key on the way; the key decides who may ask.

## 5. Trust the certificate on each device

The certificate to install is
`~/caddy/data/pki/authorities/local/root.crt`. It is public: copy it
anywhere. Never copy `root.key` next to it: it is the authority's private
key, and whoever has it can issue certificates your devices will trust.

- **iPhone and iPad.** Send the file to the device (AirDrop, Files, Mail)
  and open it. Install the profile in Settings › General › VPN & Device
  Management. Then turn on full trust for "Caddy Local Authority" in
  Settings › General › About › Certificate Trust Settings.
- **macOS.** Open the file in Keychain Access and add it to the System
  keychain. Then open the certificate and set "When using this
  certificate" to "Always Trust".
- **Windows.** Double-click the file › Install Certificate › Current User
  › "Trusted Root Certification Authorities". The `curl` that comes with
  Windows also needs `--ssl-no-revoke`, because there is no revocation
  service to ask about a private authority's certificates.
- **Linux.** Copy it to `/usr/local/share/ca-certificates/athena-caddy.crt`
  and run `sudo update-ca-certificates`.
- **Android.** On most versions: Settings › Security › Encryption &
  credentials › Install a certificate › CA certificate. Browsers then
  trust it. Most apps trust only the certificates the system came with,
  and ignore it.
- **Programs.** Python's own `ssl` and `urllib` read `SSL_CERT_FILE`.
  OpenAI's and Anthropic's Python SDKs take an HTTP client of your own:
  `http_client=httpx.Client(verify=ssl.create_default_context(cafile="root.crt"))`.
  Node reads `NODE_EXTRA_CA_CERTS`. curl takes `--cacert root.crt`.
  `SSL_CERT_FILE` replaces the default list of trusted authorities for
  that program, it does not add to it: a program that also talks to other
  HTTPS sites needs a file holding both.

The authority's certificate is valid for ten years. Caddy renews the
certificates issued from it by itself, and devices notice nothing.

## 6. Check it

From a device that trusts the certificate, with your key in `$KEY`:

```bash
curl https://athena:30443/health                          # 200: open, for health checks
curl -s -o /dev/null -w '%{http_code}\n' https://athena:30443/v1/models   # 401 without the key
curl -H "Authorization: Bearer $KEY" https://athena:30443/v1/models       # the model list
curl -N -H "Authorization: Bearer $KEY" -H 'Content-Type: application/json' \
     -d '{"model":"Athena","stream":true,"messages":[{"role":"user","content":"Count to ten."}]}' \
     https://athena:30443/v1/chat/completions             # events as they are made, not all at the end
curl http://athena:30443/health                           # refused: plain HTTP on the HTTPS port
```

Then point the clients at `https://athena:30443/v1` instead of
`http://athena:30007/v1`.

To go back: stop Caddy (`systemctl --user disable --now athena-https`),
remove the `ATHENA_BIND` line, and restart the engine.

## Certificates every device already trusts

`tls internal` needs nothing outside your network, but every device must
be told to trust it. Two ways avoid that:

- **A domain you own.** Point a name (`athena.example.com`) at the
  machine's local address and have Caddy prove the name through your DNS
  provider (the ACME DNS challenge). The machine then gets a certificate
  every device trusts, even though nothing on the internet can reach it.
  Caddy needs the module for your DNS provider for this; see Caddy's
  documentation on the DNS challenge.
- **Tailscale.** On a tailnet with HTTPS enabled, each machine gets a
  trusted certificate for its `*.ts.net` name, and the devices can reach
  it from outside the house as well.

## Any other proxy

nginx, Traefik or any other reverse proxy can sit in front of the engine
instead, if it:

- **Does not buffer responses.** Streamed chat answers
  (`text/event-stream`) and speech (`audio/pcm`) must go out as they
  come.
- **Waits long enough.** An answer that is not streamed can take minutes
  before its first byte, and a speech request up to ten minutes. Streamed
  chat answers send a comment line every 15 seconds while the model
  thinks; speech does not.
- **Takes request bodies up to 32 MB.** That is the size of a
  transcription. nginx takes 1 MB unless told otherwise.
- **Drops idle connections to the engine within 4 seconds.** The engine
  closes them after 5.
- **Closes the connection to the engine when the client leaves.** The
  engine then stops generating at once, instead of finishing an answer
  nobody reads.
- **Passes `Authorization` and `x-api-key` through unchanged** and keeps
  them out of its logs.
