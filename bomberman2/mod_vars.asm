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


; Rules of the game in progress (cleared on the title screen, set by
; OPTS_APPLY for NORMAL MODE and the options screen)
GAME_REVIVE     = &E2   ; revive where you died
GAME_SLOW       = &E3   ; slow mode
GAME_INVINC     = &E4   ; nothing hurts
GAME_FIREPROOF  = &E5   ; flames do not hurt
GAME_INF_TIME   = &E6   ; the stage clock does not run
GAME_INF_LIVES  = &E7   ; lives are not lost
GAME_XRAY       = &E8   ; buried item and exit are visible
GAME_WPASS      = &E9   ; walk through soft blocks (sets ACT_PASSWALL)
GAME_BPASS      = &EA   ; walk through bombs (sets ACT_PASSBOMB)
GAME_SPEED      = &EB   ; speed gear at the start of every life
GAME_LIVES      = &EC   ; lives at the start of a game (1-10), 0 = the original 3
GAME_TICK       = &ED   ; slow mode game clock
TICK_NOW        = &EE   ; slow mode: 1 if the game moves this frame
TIME_FLASH_ON   = &EF   ; 1 while the HUD shows the last-10-seconds palette

; Options (WRAM is not cleared by a reset: the options stay until power off)
OPT_SIG         = &6600 ; 2 bytes, OPT_SIGNATURE when the values below are valid
OPT_VALS        = &6602 ; NUM_OPTS values, in the order of config/default.asm
OPT_CURSOR      = &6620 ; cursor position (column * 9 + row)
OPT_RESULT      = &6621 ; how the options screen was left (see OPTIONS_SCREEN)
OPT_REPEAT      = &6622 ; auto repeat counter
OPT_LIVE        = &6623 ; 1 while the screen is on (items are queued)
OPT_SEL         = &6624 ; 1 while composing the selected item
OPT_TMP         = &6625
OPT_BUF         = &6640 ; 64 bytes: two rows of an item (top, top + 32)
SNAP_SCORE      = &6680 ; 8 bytes: score when the stage was entered (revive mode)
SNAP_FIRE       = &6688
SNAP_BOMBS      = &6689
XRAY_CELLS      = &668A ; x-ray: item, exit: column, row (FF = none), tile
FROZEN_ANIM     = &6690 ; slow mode: frame counter of the bomb animation
REVIVE_TIMER    = &6691 ; revive mode: frames of invulnerability left

