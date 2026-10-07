#!/bin/bash
# Build the Chinese / options mod (256K PRG).
# Usage: build.sh [-r us|jp] [-l zh|en] [-c config/NAME.asm] [-H 1|2]
#   -r  region of the base ROM (default us)
#   -l  language (default zh)
#   -c  rules of NORMAL MODE and options defaults (default config/default.asm)
#   -H  header: 2 = NES 2.0 like the originals (default; it also tells
#       emulators to plug in the Four Score / Famicom 4-player adapter),
#       1 = iNES 1.0 for old emulators and loaders
# Output: build/bomberman2_cn_REGION_LANG.nes
# (make.sh still builds the unmodified originals and compares them.)
cd "$(dirname "$0")"
BEEBASM=${BEEBASM:-../../beebasm/beebasm}
region=us
lang=zh
config=config/default.asm
header=2
while getopts "r:l:c:H:" opt; do
  case $opt in
    r) region=$OPTARG ;;
    l) lang=$OPTARG ;;
    c) config=$OPTARG ;;
    H) header=$OPTARG ;;
    *) echo "Usage: $0 [-r us|jp] [-l zh|en] [-c config/NAME.asm] [-H 1|2]"; exit 1 ;;
  esac
done
case $region in
  us) defs="-D REGION_JP=0" ;;
  jp) defs="-D REGION_JP=1" ;;
  *) echo "region must be us or jp"; exit 1 ;;
esac
case $lang in
  zh|en) ;;
  *) echo "language must be zh or en"; exit 1 ;;
esac

case $lang in
  zh) defs="${defs} -D LANG_ZH=1" ;;
esac
case $header in
  1) defs="${defs} -D INES1=1" ;;
  2) ;;
  *) echo "header must be 1 or 2"; exit 1 ;;
esac

mkdir -p build
rm -f build/*.bin
python3 tools/build_text.py --lang ${lang} --region ${region} || exit 1
[ -f "${config}" ] || { echo "no such config: ${config}"; exit 1; }
echo "INCLUDE \"${config}\"" > build/build_config.asm
${BEEBASM} ${defs} -D MOD=1 -i nes_header.asm || exit 1
${BEEBASM} ${defs} -D MOD=1 -i bman2.asm || exit 1
out=build/bomberman2_cn_${region}_${lang}.nes
cat build/nes_header.bin build/bank{0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15}.bin > ${out}
echo "${out}"
