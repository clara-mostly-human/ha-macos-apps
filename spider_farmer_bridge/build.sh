#!/bin/bash
# Fetch the bridge server from a pinned commit of our spider_farmer_bridge fork
# (the integration's proxy plus bridge/server.py). Run by the Supervisor with
# OUT, SRC_DIR, CACHE, VERSION set; the app's venv is next to OUT.
set -euo pipefail

# clara-mostly-human/spider_farmer_bridge v3.19.388.1 (upstream v3.19.388 plus
# the proxy as its own process). Bump with the app version.
COMMIT=6b49ff572ae4
# SF_BRIDGE_REPO points a dev Supervisor at a local clone.
REPO=${SF_BRIDGE_REPO:-https://github.com/clara-mostly-human/spider_farmer_bridge.git}

SRC=$CACHE/spider_farmer_bridge
if [ ! -d "$SRC/.git" ]; then
  git clone --quiet "$REPO" "$SRC"
fi
git -C "$SRC" fetch --quiet origin
git -C "$SRC" checkout --quiet --force "$COMMIT"
echo "source: $(git -C "$SRC" log --oneline -1)"

mkdir -p "$OUT/src/custom_components"
rm -rf "$OUT/src/bridge" "$OUT/src/custom_components/sf"
cp -R "$SRC/bridge" "$OUT/src/bridge"
cp -R "$SRC/custom_components/sf" "$OUT/src/custom_components/sf"
echo "$COMMIT" >"$OUT/COMMIT"

# The server must load the proxy without Home Assistant.
cd "$OUT/src"
"$OUT/../venv/bin/python" -c '
from bridge.server import load_core
core = load_core()
print("built: bridge", core.version, "protocol", core.protocol.PROTOCOL_VERSION)
'
