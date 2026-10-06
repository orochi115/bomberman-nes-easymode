; iNES (NES 2.0) header, same bytes as the No-Intro dumps
; Mapper 1 (MMC1), 8 x 16K PRG, 8K CHR-RAM, horizontal mirroring

INCLUDE "consts.asm"

ORG &0000

.HEADERSTART
  EQUS "NES", &1A
  EQUB 8                ; 8 x 16K PRG-ROM
  EQUB 0                ; CHR-RAM
  EQUB &10              ; Mapper 1
  EQUB &08              ; NES 2.0
  EQUB 0, 0
  EQUB &07              ; 8K CHR-RAM
  EQUB &07
  EQUB 0, 0, 0
IF REGION_JP
  EQUB &03
ELSE
  EQUB &02
ENDIF
.HEADEREND

SAVE "build/nes_header.bin", HEADERSTART, HEADEREND
