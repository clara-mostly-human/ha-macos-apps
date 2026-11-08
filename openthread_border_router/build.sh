#!/bin/bash
# Build otbr-agent and ot-ctl for macOS from a pinned ot-br-posix commit.
# Run by the Supervisor (as the user) with OUT, SRC_DIR, CACHE, VERSION set.
set -euo pipefail

# ot-br-posix upstream main, 2026-11-07 ("[telemetry] add child CSL period and
# sync state to topo entries", #3684). Bump with the app version.
COMMIT=f8785798
REPO=https://github.com/openthread/ot-br-posix.git

SRC=$CACHE/ot-br-posix
BUILD=$CACHE/build-$COMMIT

for tool in git cmake ninja; do
  command -v "$tool" >/dev/null || { echo "missing $tool (brew install cmake ninja)" >&2; exit 1; }
done

if [ ! -d "$SRC/.git" ]; then
  git clone --quiet "$REPO" "$SRC"
fi
git -C "$SRC" fetch --quiet origin
git -C "$SRC" checkout --quiet --force "$COMMIT"
git -C "$SRC" submodule --quiet update --init --recursive --force
echo "source: $(git -C "$SRC" log --oneline -1)"

ARGS=()
while IFS= read -r line; do
  case "$line" in ''|'#'*) ;; *) ARGS+=("-D${line//@SRC@/$SRC}") ;; esac
done <"$SRC_DIR/build-options.txt"
if command -v ccache >/dev/null; then
  ARGS+=(-DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache)
fi

if [ ! -f "$BUILD/build.ninja" ]; then
  cmake -S "$SRC" -B "$BUILD" -G Ninja "${ARGS[@]}" >"$BUILD.configure.log" 2>&1 \
    || { tail -30 "$BUILD.configure.log"; exit 1; }
fi
cmake --build "$BUILD" --target otbr-agent ot-ctl >"$BUILD.build.log" 2>&1 \
  || { grep -A4 'error' "$BUILD.build.log" | head -30; exit 1; }

# The production-relevant options must have made it into the build.
grep -q 'OT_RCP_RESTORATION_MAX_COUNT:STRING=2' "$BUILD/CMakeCache.txt"
grep -q 'OT_FIREWALL:STRING=OFF' "$BUILD/CMakeCache.txt"

mkdir -p "$OUT/bin"
cp "$BUILD/src/agent/otbr-agent" "$OUT/bin/"
cp "$BUILD/third_party/openthread/repo/src/posix/ot-ctl" "$OUT/bin/"
echo "$COMMIT" >"$OUT/COMMIT"
echo "built: $("$OUT/bin/otbr-agent" --version 2>&1 | head -1)"
