; Build region, override with: beebasm -D REGION=0|1|2
;   0 USA, 1 Japan, 2 Europe (Dynablaster, PAL)
REGION =? 0
REGION_JP = REGION = 1
REGION_EU = REGION = 2

; Relocation test: insert SHIFT padding bytes at the start of every bank
; (and after every relocatable anchor). make.sh shift N builds this.
SHIFT =? 0

; make.sh ... 1: iNES 1.0 header instead of NES 2.0 (the dumps' header)
INES1 =? 0
