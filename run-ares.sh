#!/bin/sh
# Build bomberman-nes with BeebAsm and launch it in ares (macOS).
# Arguments are passed to build.sh, e.g. run-ares.sh -l en -c config/casual.asm
set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/bomberman-nes"
BEEBASM="$ROOT/beebasm/beebasm"
ARES_APP="/Applications/ares.app"

if [ ! -x "$BEEBASM" ]; then
  echo "Building BeebAsm..."
  make -C "$ROOT/beebasm/src" code
fi

BEEBASM="$BEEBASM" "$SRC/build.sh" "$@"

echo "ROM: $SRC/bomberman.nes"
if [ ! -d "$ARES_APP" ]; then
  echo "ares not found at $ARES_APP" >&2
  exit 1
fi

# open detaches ares from this shell so the emulator stays up.
# Quit a running copy first, otherwise ares keeps the previous ROM.
if pgrep -x ares >/dev/null 2>&1; then
  osascript -e 'tell application "ares" to quit' || true
  sleep 0.4
fi

open -a "$ARES_APP" --args "$SRC/bomberman.nes"
