#!/bin/sh
# Build bomberman.nes: iNES header + 32KB PRG + 32KB CHR (CNROM).
set -eu

SRC="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$SRC")"
BEEBASM="${BEEBASM:-$ROOT/beebasm/beebasm}"
if [ ! -x "$BEEBASM" ]; then
  BEEBASM="$(command -v beebasm)"
fi

cd "$SRC"

# Generate the CHR banks and the Chinese text data
python3 tools/build_zh.py

"$BEEBASM" -i nes_header.asm
"$BEEBASM" -i bman.asm
cat nes_header.bin bomberman bomber_zh.chr > bomberman.nes

echo "ROM: $SRC/bomberman.nes ($(wc -c < bomberman.nes | tr -d ' ') bytes)"
