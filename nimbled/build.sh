#!/bin/bash
# Build nimbled for macOS from a pinned ha-macos-bluetooth commit (NimBLE and
# mbedTLS come in as its submodules). Run by the Supervisor (as the user) with
# OUT, SRC_DIR, CACHE, VERSION set. Needs the Xcode command line tools.
set -euo pipefail

# nimbled 0.4.2: the public ha-macos-bluetooth history. Bump with the app version.
COMMIT=79dd9d5626fa8938dfe009cce9c0147ae8552ad9
REPO=https://github.com/clara-mostly-human/ha-macos-bluetooth

SRC=$CACHE/ha-macos-bluetooth

for tool in git make clang; do
  command -v "$tool" >/dev/null || { echo "missing $tool (xcode-select --install)" >&2; exit 1; }
done

if [ ! -d "$SRC/.git" ]; then
  git clone --quiet "$REPO" "$SRC"
fi
git -C "$SRC" remote set-url origin "$REPO"
git -C "$SRC" fetch --quiet origin
git -C "$SRC" checkout --quiet --force "$COMMIT"
git -C "$SRC" submodule --quiet sync
git -C "$SRC" submodule --quiet update --init --force --depth 1 third_party/mbedtls
git -C "$SRC" submodule --quiet update --init --force nimble
echo "source: $(git -C "$SRC" log --oneline -1)"

# Objects don't track NimBLE's headers: build each commit from clean.
make -C "$SRC/nimbled" clean >/dev/null
make -C "$SRC/nimbled" -j"$(sysctl -n hw.ncpu)" >"$CACHE/build.log" 2>&1 \
  || { grep -B2 -A4 'error' "$CACHE/build.log" | head -30; exit 1; }

mkdir -p "$OUT/bin"
cp "$SRC/nimbled/build/nimbled" "$OUT/bin/"
echo "$COMMIT" >"$OUT/COMMIT"
echo "built: $("$OUT/bin/nimbled" --version)"
