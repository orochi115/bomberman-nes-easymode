; Build region, override with: beebasm -D REGION_JP=1 ...
REGION_JP =? FALSE ; FALSE = USA, TRUE = Japan

; Relocation test: insert SHIFT padding bytes at the start of every bank
; (and after every relocatable anchor). make.sh shift N builds this.
SHIFT =? 0

; make.sh ... 1: iNES 1.0 header instead of NES 2.0 (the dumps' header)
INES1 =? 0
