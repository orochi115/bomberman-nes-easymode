#!/bin/bash
# Build the unmodified ROM (MOD = 0) and compare it with the original dump.
# The Chinese / options ROM is ./build.sh, which passes -D MOD=1 and writes
# the same filenames (bomberman.nes / bomberman_jp.nes), so the later build
# replaces the earlier one.
#
# Usage: make.sh [us|jp] [1|2]
#        make.sh [workdir] [us|jp]    # workdir is accepted for old callers
#   1|2  header: 2 = NES 2.0 as in the dumps (default), 1 = iNES 1.0
#        (then only PRG and CHR are compared)
set -eu
cd "$(dirname "$0")"

region=us
header=2
if [ "${1:-}" = "us" ] || [ "${1:-}" = "jp" ]; then
  region=$1
  shift || true
elif [ -n "${1:-}" ] && [ -d "$1" ]; then
  shift
  region=${1:-us}
  shift || true
fi
if [ "${1:-}" = "1" ] || [ "${1:-}" = "2" ]; then
  header=$1
fi

BEEBASM=${BEEBASM:-$(dirname "$PWD")/beebasm/beebasm}
if [ ! -x "$BEEBASM" ]; then
  BEEBASM=$(command -v beebasm)
fi
ROMDIR=${BM1_ROMDIR:-$(dirname "$PWD")}

case "$region" in
  us) defs=""; prg=bomberman; chr=bomber.chr; want="Bomberman (USA).nes" ;;
  jp) defs="-D REGION_JP"; prg=bomberman_jp; chr=bomber_jp.chr; want="Bomberman (Japan).nes" ;;
  *) echo "Usage: $0 [us|jp] [1|2]"; exit 1 ;;
esac
case "$header" in
  1) hdefs="-D INES1=1" ;;
  2) hdefs="" ;;
  *) echo "header must be 1 or 2"; exit 1 ;;
esac

"$BEEBASM" $hdefs -i nes_header.asm
"$BEEBASM" $defs -i bman.asm
cat nes_header.bin "$prg" "$chr" > "$prg.nes"
echo "$prg.nes"

if [ "$header" = "1" ]; then
  if cmp -s <(tail -c +17 "$prg.nes") <(tail -c +17 "$ROMDIR/$want"); then
    echo "OK: PRG+CHR identical to $want (iNES 1.0 header)"
  else
    echo "MISMATCH with $want"
    exit 1
  fi
else
  if cmp -s "$prg.nes" "$ROMDIR/$want"; then
    echo "OK: identical to $want"
  else
    echo "MISMATCH with $want"
    cmp -l "$prg.nes" "$ROMDIR/$want" | head
    exit 1
  fi
fi
