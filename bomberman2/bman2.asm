; Bomberman II (Hudson Soft, 1991/1992) - NES, MMC1
; Build with make.sh

INCLUDE "consts.asm"
INCLUDE "nesregs.asm"
INCLUDE "vars.asm"
INCLUDE "macros.asm"

; Banks 0-6 are switched in at $8000, bank 7 is fixed at $C000.

CLEAR &8000, &C000
ORG &8000
INCLUDE "bank0.asm"
SAVE "build/bank0.bin", &8000, &C000

CLEAR &8000, &C000
ORG &8000
INCLUDE "bank1.asm"
SAVE "build/bank1.bin", &8000, &C000

CLEAR &8000, &C000
ORG &8000
INCLUDE "bank2.asm"
SAVE "build/bank2.bin", &8000, &C000

CLEAR &8000, &C000
ORG &8000
INCLUDE "bank3.asm"
SAVE "build/bank3.bin", &8000, &C000

CLEAR &8000, &C000
ORG &8000
INCLUDE "bank4.asm"
SAVE "build/bank4.bin", &8000, &C000

CLEAR &8000, &C000
ORG &8000
INCLUDE "bank5.asm"
SAVE "build/bank5.bin", &8000, &C000

CLEAR &8000, &C000
ORG &8000
INCLUDE "bank6.asm"
SAVE "build/bank6.bin", &8000, &C000

ORG &C000
INCLUDE "bank7.asm"
SAVE "build/bank7.bin", &C000, &10000
