#!/bin/bash
# Build bomberman.nes (see build.sh). The optional argument is the source
# directory, kept for compatibility with the original script.

workdir=${1:-$(dirname "$0")}
exec "${workdir}/build.sh"
