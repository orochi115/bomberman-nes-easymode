#!/bin/bash
# Regenerate bank*.asm, macros.asm, vars.asm from the ROMs + coverage + db/.
cd "$(dirname "$0")" && python3 merge.py
