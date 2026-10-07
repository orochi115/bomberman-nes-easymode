#!/bin/bash

# Usage: make.sh [workdir] [us|jp] [1|2]   (default: current directory, us, 1)
#   1 = iNES 1.0 header, 2 = NES 2.0 header (the whole ROM is then the same as
#   the No-Intro dump)
workdir=${1:-.}
region=${2:-us}
header=${3:-1}

BEEBASM=${BEEBASM:-beebasm}

case "${region}" in
  us)
    defs=""
    prg=bomberman
    chr=bomber.chr
    md5="97ddb647""898b0106""5f395eb6""4c3d131f""  Bomberman (USA)"
    md5_2="775f664b""177e561b""34615614""d160dfb7""  Bomberman (USA)"
    ;;
  jp)
    defs="-D REGION_JP"
    prg=bomberman_jp
    chr=bomber_jp.chr
    md5="6e456b88""a3181563""64066d19""7a8a43d4""  Bomberman (Japan)"
    md5_2="64c39032""24298ca9""972991ea""6a2b22a4""  Bomberman (Japan)"
    ;;
  *)
    echo "Usage: $0 [workdir] [us|jp] [1|2]"
    exit 1
    ;;
esac

case "${header}" in
  1) hdefs="" ;;
  2) hdefs="-D NES2=1"; md5="${md5_2}" ;;
  *) echo "Usage: $0 [workdir] [us|jp] [1|2]"; exit 1 ;;
esac

cd "${workdir}"

# Modification time, GNU or BSD stat
mtime()
{
  stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null
}

# The header is tiny: always build it (it depends on the header option)
rm nes_header.bin >/dev/null 2>&1
${BEEBASM} -v ${hdefs} -i nes_header.asm >/dev/null

# Check code has changed before rebuilding
bincode=`mtime ${prg}`
latestsrc=`ls -larth *.asm ${chr} | tail -1 | awk '{ print $NF }'`
srccode=`mtime ${latestsrc}`

# No bin found so force build
if [ "${bincode}" == "" ]
then
  bincode=0
fi

# Source is newer than bin so build
if [ ${srccode} -gt ${bincode} ]
then
  ${BEEBASM} -v ${defs} -i bman.asm
fi
rm ${prg}.nes >/dev/null 2>&1
cat nes_header.bin ${prg} ${chr} > ${prg}.nes

if command -v md5sum >/dev/null 2>&1
then
  md5sum ${prg}.nes
else
  md5 -r ${prg}.nes
fi
echo "${md5}"
