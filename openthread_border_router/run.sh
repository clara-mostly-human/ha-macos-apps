#!/bin/bash
# Run otbr-agent as root (started by the Supervisor's root helper).
# PATH is system folders only; the binaries are in this root-owned app copy.
set -u
HERE=$(cd "$(dirname "$0")/.." && pwd)
AGENT=$HERE/out/bin/otbr-agent
OTCTL=$HERE/out/bin/ot-ctl
SOCK_DIR=/var/run
ANCHOR=otbr

opt() { plutil -extract "$1" raw -o - "$APP_DATA/options.json" 2>/dev/null; }
DEVICE=$(opt device)
BAUD=$(opt baudrate)
BACKBONE=$(opt backbone_interface)
TXPOWER=$(opt txpower)
case "$(opt otbr_log_level)" in
  debug) LEVEL=7 ;; info) LEVEL=6 ;; notice) LEVEL=5 ;;
  warning) LEVEL=4 ;; error) LEVEL=3 ;; *) LEVEL=2 ;;
esac
PORT=${PORT_8081_TCP:-8081}
[ -n "$DEVICE" ] || { echo "no radio device configured (option: device)" >&2; exit 1; }

echo "otbr app: $(cat "$HERE/out/COMMIT" 2>/dev/null), radio $DEVICE @ $BAUD, backbone $BACKBONE"
sysctl -w net.inet6.ip6.forwarding=1

# A crash can leave a stale daemon socket; the agent is not running now.
rm -f "$SOCK_DIR"/openthread-utun*.sock

"$AGENT" -B "$BACKBONE" -d"$LEVEL" -s \
  --data-path "$APP_DATA" \
  --rest-listen-port "$PORT" \
  --vendor-name "$(opt vendor_name)" \
  --model-name "$(opt model_name)" \
  "spinel+hdlc+uart://$DEVICE?uart-baudrate=$BAUD" &
AGENT_PID=$!

cleanup() {
  trap - TERM INT EXIT
  kill "$AGENT_PID" 2>/dev/null
  wait "$AGENT_PID" 2>/dev/null
  # The agent flushes its pf anchor on a clean exit; make sure of it.
  pfctl -a "$ANCHOR" -F all >/dev/null 2>&1
}
trap cleanup TERM INT EXIT

# The daemon socket's name reveals the utun interface the agent claimed.
IFACE=""
for _ in $(seq 1 30); do
  sock=$(ls "$SOCK_DIR"/openthread-utun*.sock 2>/dev/null | head -1)
  if [ -n "$sock" ]; then IFACE=$(basename "$sock" .sock); IFACE=${IFACE#openthread-}; break; fi
  sleep 1
done

if [ -n "$IFACE" ] && [ "${TXPOWER:-0}" -gt 0 ]; then
  "$OTCTL" -I "$IFACE" txpower "$TXPOWER" >/dev/null 2>&1 \
    && echo "txpower set to $("$OTCTL" -I "$IFACE" txpower | sed -n 1p)" \
    || echo "WARNING: failed to set txpower" >&2
fi
[ -n "$IFACE" ] || echo "WARNING: Thread interface not discovered" >&2

# Tell Home Assistant where the REST API is, as the official app does.
for _ in $(seq 1 30); do
  curl -s -o /dev/null "http://127.0.0.1:$PORT/node" && break
  sleep 1
done
curl -s -o /dev/null -w "discovery sent: %{http_code}\n" -X POST \
  -H "Authorization: Bearer $SUPERVISOR_TOKEN" -H "Content-Type: application/json" \
  -d "{\"service\":\"otbr\",\"config\":{\"host\":\"127.0.0.1\",\"port\":$PORT}}" \
  "http://$SUPERVISOR/discovery"

wait "$AGENT_PID"
