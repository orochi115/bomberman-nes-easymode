#!/bin/sh
# Build the Bomberman II mod and launch it in ares (macOS).
# Arguments are passed to build.sh, e.g. run-ares.sh -r jp -l zh -c config/casual.asm
set -eu

SRC="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
ROOT="$(CDPATH= cd -- "$SRC/../.." && pwd)"
BEEBASM="$ROOT/beebasm/beebasm"
ARES_APP="/Applications/ares.app"

if [ ! -x "$BEEBASM" ]; then
  echo "Building BeebAsm..."
  make -C "$ROOT/beebasm/src" code
fi

# build.sh prints the ROM it wrote on its last line
ROM="$SRC/$(BEEBASM="$BEEBASM" "$SRC/build.sh" "$@" | tail -1)"

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

open -a "$ARES_APP" --args "$ROM"
