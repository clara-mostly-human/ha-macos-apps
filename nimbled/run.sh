#!/bin/bash
# Run nimbled and announce its socket to Home Assistant (discovery "nimbled"),
# so the nimbled integration sets itself up.
set -u
HERE=$(cd "$(dirname "$0")/.." && pwd)
NIMBLED=$HERE/out/bin/nimbled
SOCK=$APP_DATA/nimbled.sock      # macOS limits socket paths to 104 bytes
STORE=$APP_DATA/bonds.bin        # bonds (link keys), mode 0600

opt() { plutil -extract "$1" raw -o - "$APP_DATA/options.json" 2>/dev/null; }
HCI_PORT=$(opt hci_port)

echo "nimbled app: $(cat "$HERE/out/COMMIT" 2>/dev/null), controller 127.0.0.1:${HCI_PORT:-14433}"
rm -f "$SOCK"
PID=
trap '[ -n "$PID" ] && kill "$PID" 2>/dev/null && wait "$PID"; exit' TERM INT
"$NIMBLED" --hci-port "${HCI_PORT:-14433}" --socket "$SOCK" --store "$STORE" &
PID=$!

# nimbled opens its socket once it reaches the controller, which can take a
# while if the radio's app starts later. Announce it then, once per start.
(
  until [ -S "$SOCK" ]; do
    kill -0 "$PID" 2>/dev/null || exit 0
    sleep 1
  done
  sleep 2   # let the host sync with the controller
  # The token goes to curl on stdin (printf is a shell builtin): a command
  # line is visible to every account on the Mac through ps.
  printf 'Authorization: Bearer %s\n' "$SUPERVISOR_TOKEN" |
  curl -s -o /dev/null -w "discovery sent: %{http_code}\n" -X POST \
    -H @- -H "Content-Type: application/json" \
    -d "{\"service\":\"nimbled\",\"config\":{\"socket\":\"$SOCK\"}}" \
    "http://$SUPERVISOR/discovery"
) &

wait "$PID"
