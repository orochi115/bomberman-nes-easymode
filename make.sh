#!/bin/bash

# Usage: make.sh [workdir] [us|jp]   (default: current directory, us)
workdir=${1:-.}
region=${2:-us}

BEEBASM=${BEEBASM:-beebasm}

case "${region}" in
  us)
    defs=""
    prg=bomberman
    chr=bomber.chr
    md5="97ddb647""898b0106""5f395eb6""4c3d131f""  Bomberman (USA)"
    ;;
  jp)
    defs="-D REGION_JP"
    prg=bomberman_jp
    chr=bomber_jp.chr
    md5="6e456b88""a3181563""64066d19""7a8a43d4""  Bomberman (Japan)"
    ;;
  *)
    echo "Usage: $0 [workdir] [us|jp]"
    exit 1
    ;;
esac

cd "${workdir}"

# Modification time, GNU or BSD stat
mtime()
{
  stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null
}

# Check header has changed before rebuilding
binhdr=`mtime nes_header.bin`
srchdr=`mtime nes_header.asm`

# No bin found so force build
if [ "${binhdr}" == "" ]
then
  binhdr=0
fi

# Source is newer than bin so build
if [ ${srchdr} -gt ${binhdr} ]
then
  rm nes_header.bin >/dev/null 2>&1
  ${BEEBASM} -v -i nes_header.asm
fi

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
  rm ${prg}.nes >/dev/null 2>&1
  ${BEEBASM} -v ${defs} -i bman.asm
  cat nes_header.bin ${prg} ${chr} > ${prg}.nes
fi

if command -v md5sum >/dev/null 2>&1
then
  md5sum ${prg}.nes
else
  md5 -r ${prg}.nes
fi
echo "${md5}"
