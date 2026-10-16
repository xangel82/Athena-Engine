#!/usr/bin/env bash
# athena-sentinel, the engine's system companion, as a systemd user unit
# beside the engine's: it says how the machine is doing (memory, GPUs,
# disks, the engine's and the proxy's units), shows their logs and restarts
# the engine, for Athena's "System" page.  It never asks for root.
#
#   ./install-sentinel.sh [options]
#     --port N              its port on this machine (default 30010)
#     --proxy-unit UNIT     the HTTPS proxy's unit in front of the engine
#                           (e.g. athena-https.service), shown and logged
#     --proxy-system        that unit is a system unit: read, never acted on
#     --engine-unit UNIT    the engine's user unit (default athena-engine.service)
#     --engine-url URL      the engine (default http://127.0.0.1:30007)
#     --engine-key-file F   the engine's API key file, to show the model it
#                           serves (default: $ATHENA_API_KEY_FILE when set)
#     --models-dir DIR      the models' folder, shown with the disks
#                           (default ~/models)
#     --listen HOST         its address (default 127.0.0.1: only this machine
#                           and a proxy on it reach it)
#     --uninstall           stop it and remove its unit; the token is kept
#
# The first time, it makes the companion's token
# (~/.config/athena-engine/sentinel.token, readable by you only) and prints
# it once.  Run again, it rewrites the unit with the options given and keeps
# the token.
set -euo pipefail

root="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
bin="$root/bin/athena-sentinel"
fail() { echo "install-sentinel: $*" >&2; exit 2; }

token="$HOME/.config/athena-engine/sentinel.token"
unit_dir="$HOME/.config/systemd/user"
unit="$unit_dir/athena-sentinel.service"
port=30010
key_given=0
args=(--token-file "$token")
while [ $# -gt 0 ]; do
  case "$1" in
    --port|--proxy-unit|--engine-unit|--engine-url|--engine-key-file|--models-dir|--listen)
      [ $# -ge 2 ] || fail "$1 needs a value"
      [ "$1" = --port ] && port="$2"
      [ "$1" = --engine-key-file ] && key_given=1
      args+=("$1" "$2"); shift 2 ;;
    --proxy-system) args+=("$1"); shift ;;
    --uninstall)
      systemctl --user disable --now athena-sentinel.service 2>/dev/null || true
      rm -f "$unit"
      systemctl --user daemon-reload
      echo "athena-sentinel removed; its token stays in $token"
      exit 0 ;;
    -h|--help) sed -n '2,25p' "$0"; exit 0 ;;
    *) fail "unknown option $1" ;;
  esac
done
[ -x "$bin" ] || fail "athena-sentinel is not next to this script: $bin"
command -v systemctl >/dev/null || fail "systemd is needed"
if [ $key_given = 0 ] && [ -n "${ATHENA_API_KEY_FILE:-}" ]; then
  args+=(--engine-key-file "$ATHENA_API_KEY_FILE")
fi

made=0
if [ ! -s "$token" ]; then
  "$bin" --make-token "$token" >/dev/null || fail "the token cannot be made in $token"
  made=1
fi

# One argument a word, quoted for systemd; % and $ would be expanded by it.
line="\"$bin\""
for a in "${args[@]}"; do
  a="${a//%/%%}"
  a="${a//\$/\$\$}"
  line+=" \"$a\""
done
mkdir -p "$unit_dir"
cat > "$unit" <<EOF
[Unit]
Description=Athena's Engine system companion (athena-sentinel)
After=network-online.target

[Service]
ExecStart=$line
Restart=on-failure
RestartSec=10
NoNewPrivileges=yes

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable athena-sentinel.service >/dev/null
systemctl --user restart athena-sentinel.service
sleep 1
if ! systemctl --user is-active --quiet athena-sentinel.service; then
  journalctl --user -u athena-sentinel.service -n 15 --no-pager >&2 || true
  fail "athena-sentinel did not start"
fi
if [ "$(loginctl show-user "$USER" -p Linger --value 2>/dev/null || true)" != yes ]; then
  echo "note: it starts with the machine only with lingering on: loginctl enable-linger $USER"
fi

echo "athena-sentinel is running on port $port."
if [ $made = 1 ]; then
  echo "Its token, shown this once (it stays in $token):"
  echo "  $(cat "$token")"
else
  echo "Its token is in $token."
fi
echo "Give Athena the address http://127.0.0.1:$port/system on this machine, or"
echo "https://HOST:30443/system behind the HTTPS proxy (docs/sentinel.md)."
