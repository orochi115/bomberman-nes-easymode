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

; Chinese / options mod (build.sh builds it): 256K PRG, the original fixed
; bank becomes bank 15, mod code and text data live in banks 7-14.
MOD =? 0
LANG_ZH =? 0            ; build.sh -l zh: Chinese text (MOD builds only)
ZH = MOD AND LANG_ZH    ; Chinese screens replace the original text
