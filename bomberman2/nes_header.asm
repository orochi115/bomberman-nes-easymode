; NES 2.0 header, same bytes as the No-Intro dumps
; Mapper 1 (MMC1), 8 x 16K PRG, 8K PRG-RAM (no battery), 8K CHR-RAM.
; The mirroring bit is 0, but MMC1 sets the mirroring itself.

INCLUDE "consts.asm"

ORG &0000

.HEADERSTART
IF INES1
  ; iNES 1.0 (make.sh ... 1): for emulators and loaders that only know iNES
  EQUS "NES", &1A
  EQUB 8                ; 8 x 16K PRG-ROM
  EQUB 0                ; CHR-RAM
  EQUB &10              ; Mapper 1, no battery
  EQUB &00              ; mapper high nibble 0, iNES 1.0
  EQUB 0                ; PRG-RAM: 0 = the usual 8K
  IF REGION_EU
    EQUB 1              ; PAL
  ELSE
    EQUB 0              ; NTSC
  ENDIF
  EQUB 0, 0, 0, 0, 0, 0
ELSE
  EQUS "NES", &1A
  EQUB 8                ; 8 x 16K PRG-ROM
  EQUB 0                ; CHR-RAM
  EQUB &10              ; Mapper 1
  EQUB &08              ; NES 2.0
  EQUB 0, 0             ; mapper / submapper, ROM size high bits
  EQUB &07              ; PRG-RAM: 64 << 7 = 8K, no battery-backed RAM
  EQUB &07              ; CHR-RAM: 64 << 7 = 8K
  IF REGION_EU
    EQUB 1              ; PAL
  ELSE
    EQUB 0              ; NTSC
  ENDIF
  EQUB 0, 0             ; no Vs. System, no misc ROMs
; Default expansion device: Four Score (US/EU) / Famicom four-player adapter (JP)
IF REGION_JP
  EQUB &03
ELSE
  EQUB &02
ENDIF
ENDIF
.HEADEREND

SAVE "build/nes_header.bin", HEADERSTART, HEADEREND
