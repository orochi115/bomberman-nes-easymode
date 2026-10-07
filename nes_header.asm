; NES 2.0 header (build.sh -H 2, the default) or iNES 1.0 header (-H 1)
INES1 =? 0

ORG &0000
.HEADERSTART
EQUS "NES", &1a ; Magic string that always begins an iNES header
EQUB &02        ; Number of 16KB PRG-ROM banks (32KB, NROM-256 style)
EQUB &04        ; Number of 8KB CHR-ROM banks (CNROM, 4 x 8KB)
EQUB %00110001  ; Flags  6 - Vertical mirroring, no save NVRAM, mapper 3 (CNROM) low nibble
IF INES1
EQUB %00000000  ; Flags  7 - No special-case flags set, mapper high nibble 0
ELSE
EQUB %00001000  ; Flags  7 - NES 2.0, mapper high nibble 0
ENDIF
EQUB &00        ; Flags  8 - PRG-RAM size in 8KB units (NES 2.0: mapper high bits)
EQUB %00000000  ; Flags  9 - TV system is NTSC (NES 2.0: ROM size high bits)

.PADDING
  FOR n, 1, 5   ; NES 2.0: no PRG-RAM, no CHR-RAM, NTSC, no Vs., no misc ROMs
    EQUB &00
  NEXT
IF INES1
EQUB &00
ELSE
EQUB &01        ; NES 2.0 byte 15 - default expansion device: standard controllers
ENDIF
.HEADEREND

SAVE "nes_header.bin", HEADERSTART, HEADEREND
