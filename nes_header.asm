; Original: make.sh [dir] [us|jp] [1|2], iNES 1.0 by default.
; Mod: build.sh -H 1|2, NES 2.0 by default.
INCLUDE "consts.asm"
IF MOD
  INES1 =? 0
  NES2 = 1 - INES1
ELSE
  NES2 =? 0
ENDIF

ORG &0000
.HEADERSTART
EQUS "NES", &1a ; Magic string that always begins an iNES header
IF MOD
EQUB &02        ; Number of 16KB PRG-ROM banks (32KB, NROM-256 style)
EQUB &04        ; Number of 8KB CHR-ROM banks (CNROM, 4 x 8KB)
EQUB %00110001  ; Flags  6 - Vertical mirroring, no save NVRAM, mapper 3 (CNROM) low nibble
ELSE
EQUB &01        ; Number of 16KB PRG-ROM banks
EQUB &01        ; Number of 8KB CHR-ROM banks
EQUB %00000001  ; Vertical mirroring, mapper 0 (NROM)
ENDIF
IF NES2
EQUB %00001000  ; Flags  7 - NES 2.0, mapper high nibble 0
ELSE
EQUB %00000000  ; Flags  7 - iNES 1.0, mapper high nibble 0
ENDIF
EQUB &00        ; Flags  8 - PRG-RAM size in 8KB units (NES 2.0: mapper high bits)
EQUB %00000000  ; Flags  9 - TV system is NTSC (NES 2.0: ROM size high bits)

.PADDING
  FOR n, 1, 5   ; NES 2.0: no PRG-RAM, no CHR-RAM, NTSC, no Vs., no misc ROMs
    EQUB &00
  NEXT
IF NES2
EQUB &01        ; NES 2.0 byte 15 - default expansion device: standard controllers
ELSE
EQUB &00
ENDIF
.HEADEREND

SAVE "nes_header.bin", HEADERSTART, HEADEREND
