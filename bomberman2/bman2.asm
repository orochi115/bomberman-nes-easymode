; Bomberman II (Hudson Soft, 1991/1992) - NES, MMC1
; Build with make.sh

INCLUDE "consts.asm"
INCLUDE "nesregs.asm"
INCLUDE "vars.asm"
INCLUDE "macros.asm"
IF MOD
INCLUDE "build/text_consts.asm"
INCLUDE "mod_vars.asm"
ENDIF

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

IF MOD
; Mod banks 7-14 (bank 15 is the original fixed bank)
CLEAR &8000, &C000
ORG &8000
INCLUDE "mod_bank7.asm"
SAVE "build/bank7.bin", &8000, &C000

CLEAR &8000, &C000
ORG &8000
INCLUDE "mod_bank8.asm"
SAVE "build/bank8.bin", &8000, &C000

CLEAR &8000, &C000
ORG &8000
INCLUDE "build/text_bank9.asm"
FILLTO &BFBC
RESET_STUB
SAVE "build/bank9.bin", &8000, &C000

CLEAR &8000, &C000
ORG &8000
INCLUDE "build/text_bank10.asm"
FILLTO &BFBC
RESET_STUB
SAVE "build/bank10.bin", &8000, &C000

CLEAR &8000, &C000
ORG &8000
INCLUDE "build/text_bank11.asm"
FILLTO &BFBC
RESET_STUB
SAVE "build/bank11.bin", &8000, &C000

CLEAR &8000, &C000
ORG &8000
INCLUDE "build/text_bank12.asm"
FILLTO &BFBC
RESET_STUB
SAVE "build/bank12.bin", &8000, &C000

CLEAR &8000, &C000
ORG &8000
INCLUDE "build/text_bank13.asm"
FILLTO &BFBC
RESET_STUB
SAVE "build/bank13.bin", &8000, &C000

CLEAR &8000, &C000
ORG &8000
INCLUDE "build/text_bank14.asm"
FILLTO &BFBC
RESET_STUB
SAVE "build/bank14.bin", &8000, &C000


ORG &C000
INCLUDE "bank7.asm"
SAVE "build/bank15.bin", &C000, &10000
ELSE
ORG &C000
INCLUDE "bank7.asm"
SAVE "build/bank7.bin", &C000, &10000
ENDIF
