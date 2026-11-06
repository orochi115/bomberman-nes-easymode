#!/bin/sh
# Build the unmodified original. Usage: make.sh [workdir] [us|jp] [1|2]
# Header 1 (iNES 1.0) is the default; header 2 matches the No-Intro dumps.
set -eu

SRC="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
REPO="$(CDPATH= cd -- "$SRC/.." && pwd)"
BEEBASM="${BEEBASM:-$REPO/third_party/beebasm/beebasm}"
if [ ! -x "$BEEBASM" ] && [ -f "$REPO/third_party/beebasm/src/Makefile" ]; then
  make -C "$REPO/third_party/beebasm/src" code
fi
if [ ! -x "$BEEBASM" ]; then
  BEEBASM="$(command -v beebasm)"
fi

workdir=${1:-$SRC}
region=${2:-us}
header=${3:-1}

case "$region" in
  us) DEFS=""; PRG=bomberman; CHR=bomber.chr ;;
  jp) DEFS="-D REGION_JP"; PRG=bomberman_jp; CHR=bomber_jp.chr ;;
  *) echo "Usage: $0 [workdir] [us|jp] [1|2]" >&2; exit 1 ;;
esac
case "$header" in
  1) HDEFS="" ;;
  2) HDEFS="-D NES2=1" ;;
  *) echo "Usage: $0 [workdir] [us|jp] [1|2]" >&2; exit 1 ;;
esac

cd "$workdir"
# Always assemble: the same output names are also used by build.sh.
"$BEEBASM" -D MOD=0 $HDEFS -i nes_header.asm
"$BEEBASM" -D MOD=0 $DEFS -i bman.asm
cat nes_header.bin "$PRG" "$CHR" > "$PRG.nes"
echo "ROM: $PWD/$PRG.nes (original, $region, header $header)"
