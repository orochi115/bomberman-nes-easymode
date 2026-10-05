; iNES header
ORG &0000
.HEADERSTART
EQUS "NES", &1a ; Magic string that always begins an iNES header
EQUB &02        ; Number of 16KB PRG-ROM banks (32KB, NROM-256 style)
EQUB &04        ; Number of 8KB CHR-ROM banks (CNROM, 4 x 8KB)
EQUB %00110001  ; Flags  6 - Vertical mirroring, no save NVRAM, mapper 3 (CNROM) low nibble
EQUB %00000000  ; Flags  7 - No special-case flags set, mapper high nibble 0
EQUB &00        ; Flags  8 - PRG-RAM size in 8KB units
EQUB %00000000  ; Flags  9 - TV system is NTSC

.PADDING
  FOR n, 1, 6
    EQUB &00
  NEXT
.HEADEREND

SAVE "nes_header.bin", HEADERSTART, HEADEREND
