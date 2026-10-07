#!/bin/bash
# Regenerate bank*.asm, macros.asm, vars.asm from the ROMs + coverage + db/.
# Refused on branch bomberman2-cn, where the source is edited by hand.
cd "$(dirname "$0")"
if [ -f ../mod.asm ]; then
  echo "frozen source (bomberman2-cn): regenerating would overwrite the mod" >&2
  exit 1
fi
python3 merge.py
