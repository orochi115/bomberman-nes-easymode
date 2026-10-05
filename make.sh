#!/bin/sh
# Usage: ./make.sh [us|jp]   (default: us)
set -e
cd "$(dirname "$0")"

case "${1:-us}" in
    us) DEF="";             OUT=BOMBER;    CHR=BOMBER.CHR ;;
    jp) DEF="-DREGION_JP";  OUT=BOMBER_JP; CHR=BOMBER_JP.CHR ;;
    *)  echo "Usage: $0 [us|jp]"; exit 1 ;;
esac

rm -f $OUT.NES $OUT.PRG ${OUT}00?.prg
python3 breakasm.py $DEF BMAN.NAS $OUT.PRG > out.txt || { cat out.txt; exit 1; }
python3 split.py $OUT.PRG
cat NES_Header.bin ${OUT}003.prg $CHR > $OUT.NES
echo "$OUT.NES"
echo "PRG CRC32: $(python3 crc32.py ${OUT}003.prg)"
echo "CHR CRC32: $(python3 crc32.py $CHR)"
