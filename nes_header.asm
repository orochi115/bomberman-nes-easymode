; iNES header (make.sh ... 1, the default) or NES 2.0 header (make.sh ... 2,
; the same bytes as the No-Intro dumps)
NES2 =? 0

ORG &0000
.HEADERSTART
EQUS "NES", &1a ; Magic string that always begins an iNES header
EQUB &01        ; Number of 16KB PRG-ROM banks
EQUB &01        ; Number of 8KB CHR-ROM banks (0 means use CHR-RAM)
EQUB %00000001  ; Flags  6 - Vertical mirroring, no save NVRAM, no mapper
IF NES2
EQUB %00001000  ; Flags  7 - NES 2.0, no mapper
ELSE
EQUB %00000000  ; Flags  7 - No special-case flags set, no mapper
ENDIF
EQUB &00        ; Flags  8 - PRG-RAM size in 8KB units (NES 2.0: mapper high bits)
EQUB %00000000  ; Flags  9 - TV system is NTSC (NES 2.0: ROM size high bits)

.PADDING
  FOR n, 1, 5
    EQUB &00
  NEXT
IF NES2
EQUB &01        ; NES 2.0 byte 15 - default expansion device: standard controllers
ELSE
EQUB &00
ENDIF
.HEADEREND

SAVE "nes_header.bin", HEADERSTART, HEADEREND
