; RAM used by the mod (MOD builds). Zero page $E0-$FB is unused by the
; game in both regions, WRAM from $6495 too.

; Text engine (text.asm)
ZH_PTR      = &F0       ; data pointer in the text bank
ZH_PTR_HI   = &F1
ZH_SRC      = &F2       ; tile data pointer
ZH_SRC_HI   = &F3
ZH_ADDR     = &F4       ; PPU address for records without one
ZH_ADDR_HI  = &F5
ZH_CNT      = &F6
ZH_CNT2     = &F7
ZH_BANK     = &F8       ; bank of the current set
ZH_SAVED    = &F9       ; caller's bank
ZH_W        = &FA       ; record width
ZH_TMP      = &FB
ZH_MODE     = &E0       ; ZH_SCREEN / ZH_QUEUE_SCREEN: 0 print, 1 queue
ZH_ROWS     = &E1       ; rows of the current record (width bit 7 = one row)

ZH_SPR_BUF  = &6500     ; WRAM, free in both regions: title sprite text
ZH_ROUND_SPR = &6540    ; 5 x 40h: round result sprites (VS / battle)

