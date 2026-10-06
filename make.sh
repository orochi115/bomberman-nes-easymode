#!/bin/bash
# Build bomberman.nes (see build.sh). The optional arguments are the source
# directory, kept for compatibility with the original script, and the region.
#
# Usage: make.sh [workdir] [us|jp]

workdir=${1:-$(dirname "$0")}
region=${2:-us}
exec "${workdir}/build.sh" -r "${region}"
