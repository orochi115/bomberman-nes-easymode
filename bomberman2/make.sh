#!/bin/bash
# Usage: make.sh [us|jp] [1|2] [shift N]
#   us|jp     region (default us)
#   1|2       header: 2 = NES 2.0 as in the No-Intro dumps (default), 1 = iNES
#             1.0 (then only the PRG is compared with the dump)
#   shift N   relocation test build: N padding bytes at the start of every bank
#             (output build/bomberman2_REGION_shiftN.nes, no checksum compare)
cd "$(dirname "$0")"
BEEBASM=${BEEBASM:-../../beebasm/beebasm}
ROMDIR=${BM2_ROMDIR:-../..}
region=${1:-us}
header=2
if [ "$2" == "1" ] || [ "$2" == "2" ]; then
  header=$2
  shift
fi
shift_n=0
[ "$2" == "shift" ] && shift_n=${3:-1}

case "${region}" in
  us) defs="-D REGION_JP=0"; want="Bomberman II (USA).nes" ;;
  jp) defs="-D REGION_JP=1"; want="Bomberman II (Japan).nes" ;;
  *) echo "Usage: $0 [us|jp] [1|2] [shift N]"; exit 1 ;;
esac
[ "${header}" == "1" ] && defs="${defs} -D INES1=1"

mkdir -p build
rm -f build/*.bin
${BEEBASM} ${defs} -i nes_header.asm || exit 1
${BEEBASM} ${defs} -D SHIFT=${shift_n} -i bman2.asm || exit 1

if [ ${shift_n} -gt 0 ]; then
  out=build/bomberman2_${region}_shift${shift_n}.nes
else
  out=build/bomberman2_${region}.nes
fi
cat build/nes_header.bin build/bank{0,1,2,3,4,5,6,7}.bin > ${out}
echo "${out}"

if [ ${shift_n} -eq 0 ] && [ "${header}" == "1" ]; then
  if cmp -s <(tail -c +17 "${out}") <(tail -c +17 "${ROMDIR}/${want}"); then
    echo "OK: PRG identical to ${want} (iNES 1.0 header)"
  else
    echo "MISMATCH with ${want}"
    exit 1
  fi
elif [ ${shift_n} -eq 0 ]; then
  if cmp -s "${out}" "${ROMDIR}/${want}"; then
    echo "OK: identical to ${want}"
  else
    echo "MISMATCH with ${want}:"
    cmp -l "${out}" "${ROMDIR}/${want}" | head
    exit 1
  fi
fi
