#!/bin/bash
# Fetch the zigbee-ble host bridge from a pinned thread-rcp-firmware commit.
# Run by the Supervisor (as the user) with OUT, SRC_DIR, CACHE, VERSION set.
# Only zigbee-ble/host is checked out (the repository also holds firmware).
set -euo pipefail

# 2026-11-17: the public thread-rcp-firmware history (same bridge as 29ece21).
# Bump with the app version.
COMMIT=77294637bce79474199c74b98c93448cfb3acf2f
REPO=https://github.com/clara-mostly-human/thread-rcp-firmware

SRC=$CACHE/thread-rcp-firmware

command -v git >/dev/null || { echo "missing git (xcode-select --install)" >&2; exit 1; }

if [ ! -d "$SRC/.git" ]; then
  git clone --quiet --filter=blob:none --no-checkout "$REPO" "$SRC"
fi
git -C "$SRC" sparse-checkout set zigbee-ble/host
git -C "$SRC" remote set-url origin "$REPO"
git -C "$SRC" fetch --quiet --filter=blob:none origin
git -C "$SRC" checkout --quiet --force "$COMMIT"
echo "source: $(git -C "$SRC" log --oneline -1)"

mkdir -p "$OUT/host"
cp "$SRC"/zigbee-ble/host/{ash_bridge,cpc,hci_tcp}.py "$OUT/host/"
echo "$COMMIT" >"$OUT/COMMIT"
