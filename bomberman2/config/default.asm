; Build configuration: the rules of "普通模式" (NORMAL MODE) and the initial
; values of the options screen. These values are the original game.
; build.sh -c config/NAME.asm picks another file.

CFG_AREA    = 1     ; 1-6
CFG_STAGE   = 1     ; 1-8
CFG_LIVES   = 3     ; 1-9, 10 = unlimited
CFG_FIRE    = 1     ; 1-8
CFG_BOMBS   = 1     ; 1-5
CFG_SPEED   = 0     ; 0-4
CFG_TIME    = 0     ; 0 normal, 1 unlimited
CFG_REVIVE  = 0     ; 1: revive where you died
CFG_SLOW    = 0     ; 1: the game only moves while you move
CFG_REMOTE  = 0     ; 0 no, 1 remote control, 2 remote control and fuse
CFG_WPASS   = 0     ; 1: walk through soft blocks
CFG_BPASS   = 0     ; 1: walk through bombs
CFG_FPASS   = 0     ; 1: flames do not hurt
CFG_XRAY    = 0     ; 1: see the item and the exit under the blocks
CFG_INVINC  = 0     ; 1: nothing hurts
CFG_FUSE    = 1     ; 0 short, 1 normal, 2 long
