; ===========================================================================
; Extension code and data, assembled at $8000-$BFFF
;
;  - CHR bank switching (CNROM)
;  - Chinese text printing (strings are generated into zh_text.asm)
;  - Options screen
;  - Revive mode (respawn in place)
;  - Slow mode helpers (game time only passes while moving / pressing B)
; ===========================================================================

; ---------------------------------------------------------------------------
; CNROM CHR bank switching. The board has bus conflicts, so the value
; written must match the ROM byte at the target address.
.CHR_BANK_TBL
  EQUB 0, 1, 2, 3

; Select 8KB CHR bank in A (0-3)
.SET_CHR_BANK
{
  TAX
  STA CHR_BANK_TBL,X
  RTS
}

; =============== S U B R O U T I N E =======================================
; Print a Chinese string record (A = lo, X = hi of the record address).
; The string is two tiles high; the record holds the PPU address.
.PRINT_ZH
{
  STA ZH_PTR:STX ZH_PTR+1

  LDY #0
  LDA (ZH_PTR),Y:STA ZH_ADDR
  INY
  LDA (ZH_PTR),Y:STA ZH_ADDR+1

; Print the string record at ZH_PTR at the PPU address in ZH_ADDR
.^PRINT_ZH_AT
  LDY #2
  LDA (ZH_PTR),Y:STA ZH_TEMP ; Width in tiles
  INY

  ; Top row
  LDA ZH_ADDR:STA PPU_ADDRESS
  LDA ZH_ADDR+1:STA PPU_ADDRESS

  LDX ZH_TEMP
.top_loop
  LDA (ZH_PTR),Y:STA PPU_DATA
  INY
  DEX
  BNE top_loop

  ; Bottom row, one tile row (32 bytes) further on
  LDA ZH_ADDR+1
  CLC:ADC #32
  TAX
  LDA ZH_ADDR
  ADC #0
  STA PPU_ADDRESS
  STX PPU_ADDRESS

  LDX ZH_TEMP
.bottom_loop
  LDA (ZH_PTR),Y:STA PPU_DATA
  INY
  DEX
  BNE bottom_loop

  RTS
}

; =============== S U B R O U T I N E =======================================
; Draw the title menu cursor next to "开始游戏" or "选项" (called from NMI)
MENU_CURSOR_START = &2267 ; Row 19, column 7
MENU_CURSOR_OPTS = &2272  ; Row 19, column 18

.DRAW_MENU_CURSOR
{
  LDX #0 ; Menu item

.loop
  ; Top tile
  LDA MENU_CURSOR_HI,X:STA PPU_ADDRESS
  LDA MENU_CURSOR_LO,X:STA PPU_ADDRESS

  LDA #BLANK_TILE
  CPX CURSOR
  BNE top_blank
  LDA ZH_CURSOR+3

.top_blank
  STA PPU_DATA

  ; Bottom tile
  LDA MENU_CURSOR_HI,X:STA PPU_ADDRESS
  LDA MENU_CURSOR_LO,X
  CLC:ADC #32
  STA PPU_ADDRESS

  LDA #BLANK_TILE
  CPX CURSOR
  BNE bottom_blank
  LDA ZH_CURSOR+4

.bottom_blank
  STA PPU_DATA

  INX
  CPX #2
  BNE loop

  RTS

.MENU_CURSOR_HI
  EQUB hi(MENU_CURSOR_START), hi(MENU_CURSOR_OPTS)
.MENU_CURSOR_LO
  EQUB lo(MENU_CURSOR_START), lo(MENU_CURSOR_OPTS)
}

; =============== S U B R O U T I N E =======================================
; Gamepad state for GET_INPUT (not in demo). In slow mode SELECT only makes
; time pass, so it's left out here: holding it must not stop the remote
; detonator from seeing B released (LAST_INPUT).
.READ_PADS
{
  ; Only LDA/ORA/AND here: the carry flag must be left alone, as the
  ; original code didn't touch it (enemy AI random numbers depend on it)
  LDA GAME_SLOW
  BNE slow

  LDA JOYPAD1
  ORA JOYPAD2
  RTS

.slow
  LDA JOYPAD1
  ORA JOYPAD2
  AND #&FF-(PAD_SELECT + PAD_START)
  RTS
}

; =============== S U B R O U T I N E =======================================
; Called each time the level timer goes down: flash the status bar red for
; the last 10 seconds
TIME_FLASH_FRAMES = 10
HUD_ATTR = &23C0  ; Attribute bytes for the status bar (tile rows 0-3)
HUD_ATTR_RED = %01010101 ; Background palette 1 (reds) for the whole bar

.TIME_TICKED
{
  LDA TIMELEFT
  CMP #10
  BCS done

  LDA #TIME_FLASH_FRAMES:STA TIME_FLASH

.done
  RTS
}

; Called from NMI during vblank: switch the status bar attributes to the red
; palette while TIME_FLASH runs, and back to palette 0 afterwards
.NMI_TIME_FLASH
{
  LDA STAGE_STARTED
  BEQ done

  LDA TIME_FLASH
  BEQ flash_off

  DEC TIME_FLASH

  LDA TIME_FLASH_ON
  BNE done ; Already red

  LDA #YES:STA TIME_FLASH_ON
  LDA #HUD_ATTR_RED
  BNE write_attr

.flash_off
  LDA TIME_FLASH_ON
  BEQ done ; Already normal

  LDA #NO:STA TIME_FLASH_ON
  ; A = 0, palette 0

.write_attr
  LDX #hi(HUD_ATTR):STX PPU_ADDRESS
  LDX #lo(HUD_ATTR):STX PPU_ADDRESS

  LDX #8 ; One row of attribute bytes

.attr_loop
  STA PPU_DATA
  DEX
  BNE attr_loop

.done
  RTS
}

; =============== S U B R O U T I N E =======================================
; VRAM update buffer, written by the NMI when VBUF_READY is set.
; Entries are: PPU address hi, lo, count, bytes. A hi byte of 0 ends it.

; Called from NMI
.NMI_VBUF
{
  LDA VBUF_READY
  BEQ done

  JSR VBUF_FLUSH

  LDA #0:STA VBUF_READY

.done
  RTS
}

; Have the NMI write VBUF and wait until it has (screen on)
.VBUF_SEND
{
  LDA #YES:STA VBUF_READY

.wait
  LDA VBUF_READY
  BNE wait

  RTS
}

; Copy VBUF to the PPU (rendering must be off, or in vblank)
.VBUF_FLUSH
{
  LDY #0

.entry
  LDA VBUF,Y
  BEQ done

  STA PPU_ADDRESS
  INY
  LDA VBUF,Y:STA PPU_ADDRESS
  INY
  LDX VBUF,Y
  INY

.copy
  LDA VBUF,Y:STA PPU_DATA
  INY
  DEX
  BNE copy
  BEQ entry

.done
  RTS
}

; =============== S U B R O U T I N E =======================================
; Default settings for the options screen (on reset)
.OPTS_INIT
{
  LDX #NUM_OPTS-1

.loop
  LDA OPT_DEFAULTS,X:STA OPT_STAGE,X
  DEX
  BPL loop

  LDA #0:STA OPT_CURSOR
  STA VBUF_READY
}

; Set the rules for a normal game ("开始游戏" and the demo)
.CLEAR_GAME_RULES
{
  LDA #NO
  STA GAME_REVIVE
  STA GAME_SLOW
  STA GAME_INVINC
  STA GAME_INF_LIVES

  LDA #SECONDSPERLEVEL:STA GAME_TIME

  LDA #YES:STA TICK_NOW

  RTS
}

; Values in the order of OPT_STAGE .. OPT_INVINC
.OPT_DEFAULTS
  EQUB 1, LIVESATSTART, 1, 1, 1, NO, NO, NO, NO, NO, NO, NO, NO, NO
.OPT_MIN
  EQUB 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
.OPT_MAX
  EQUB MAP_LEVELS, OPT_LIVES_INF, MAX_BOMB_RANGE, MAX_BOMB, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1

; How each option value is shown
OPT_KIND_NUMBER = 0
OPT_KIND_LIVES = 1 ; Number, or unlimited
OPT_KIND_TIME = 2
OPT_KIND_BOOL = 3
.OPT_KIND
  EQUB 0, 1, 0, 0, 2, 3, 3, 3, 3, 3, 3, 3, 3, 3

OPT_LIVES_INF = 10 ; OPT_LIVES value for unlimited lives

; Seconds per level for each OPT_TIME value (0 = unlimited)
.OPT_TIME_TAB
  EQUB 100, 200, 250, 0

; =============== S U B R O U T I N E =======================================
; Start a game using the options screen settings
.OPTS_APPLY
{
  LDA OPT_STAGE:STA STAGE

  ; Clear the score
  LDX #SCORE_DIGITS-1
  LDA #0

.score_loop
  STA SCORE,X
  DEX
  BPL score_loop

  STA INVULNERABLE_TIMER

  ; Lives (unlimited lives start with the normal number, which never drops)
  LDX OPT_LIVES
  CPX #OPT_LIVES_INF
  BNE limited_lives
  LDA #YES:STA GAME_INF_LIVES
  LDX #LIVESATSTART

.limited_lives
  DEX:STX LIFELEFT

  ; Bomb range in multiples of 16
  LDA OPT_POWER
  ASL A:ASL A:ASL A:ASL A
  STA BONUS_POWER

  LDX OPT_BOMBS:DEX:STX BONUS_BOMBS

  LDA OPT_SPEED:STA BONUS_SPEED
  LDA OPT_REMOTE:STA BONUS_REMOTE
  LDA OPT_NOCLIP:STA BONUS_NOCLIP
  LDA OPT_BOMBWALK:STA BONUS_BOMBWALK
  LDA OPT_FIRESUIT:STA BONUS_FIRESUIT
  LDA OPT_DEBUG:STA DEBUG

  LDA OPT_REVIVE:STA GAME_REVIVE
  LDA OPT_SLOW:STA GAME_SLOW
  LDA OPT_INVINC:STA GAME_INVINC

  LDX OPT_TIME
  LDA OPT_TIME_TAB,X:STA GAME_TIME

  RTS
}

; =============== S U B R O U T I N E =======================================
; Seconds for a new level (unlimited time keeps a fixed value)
.GET_LEVEL_TIME
{
  LDA GAME_TIME
  BNE done

  LDA #SECONDSPERLEVEL

.done
  RTS
}

; =============== S U B R O U T I N E =======================================
; Called at the start of each stage: remember the score and power-ups so the
; stage can be restarted in revive mode, and the stage for the options screen
.STAGE_ENTER
{
  LDA DEMOPLAY
  BNE done

  LDA STAGE:STA OPT_STAGE

  LDX #SCORE_DIGITS-1

.score_loop
  LDA SCORE,X:STA SNAP_SCORE,X
  DEX
  BPL score_loop

  LDA BONUS_POWER:STA SNAP_POWER
  LDA BONUS_BOMBS:STA SNAP_BOMBS
  LDA BONUS_SPEED:STA SNAP_SPEED
  LDA BONUS_NOCLIP:STA SNAP_NOCLIP
  LDA BONUS_REMOTE:STA SNAP_REMOTE
  LDA BONUS_BOMBWALK:STA SNAP_BOMBWALK
  LDA BONUS_FIRESUIT:STA SNAP_FIRESUIT

.done
  RTS
}

; =============== S U B R O U T I N E =======================================
; Revive mode: lose a life without resetting the stage (jumped to from
; LOOSE_LIFE). When all lives are gone the stage is restarted.
.REVIVE
{
  ; Play melody 8 to the end
  LDA #8:STA APU_MUSIC
  JSR WAITTUNE

  ; Loose a life (unless lives are unlimited)
  LDA GAME_INF_LIVES
  BNE respawn
  DEC LIFELEFT
  BPL respawn

  ; Out of lives - restart this stage with the score and power-ups it was
  ; entered with
  LDX #SCORE_DIGITS-1

.score_loop
  LDA SNAP_SCORE,X:STA SCORE,X
  DEX
  BPL score_loop

  LDA SNAP_POWER:STA BONUS_POWER
  LDA SNAP_BOMBS:STA BONUS_BOMBS
  LDA SNAP_SPEED:STA BONUS_SPEED
  LDA SNAP_NOCLIP:STA BONUS_NOCLIP
  LDA SNAP_REMOTE:STA BONUS_REMOTE
  LDA SNAP_BOMBWALK:STA BONUS_BOMBWALK
  LDA SNAP_FIRESUIT:STA BONUS_FIRESUIT

  LDA #0:STA INVULNERABLE_TIMER

  LDX OPT_LIVES:DEX:STX LIFELEFT

  JMP START_STAGE

.respawn
  JSR CLEAR_BOMBS_AND_FIRE

  ; Refill the timer, unless it already ran out (so Pontans don't appear
  ; a second time)
  LDA TIMELEFT
  BEQ time_done
  CMP #255
  BEQ time_done

  JSR GET_LEVEL_TIME:STA TIMELEFT

.time_done
  JSR FIND_SAFE_SPOT

  LDA #SPR_HALFSIZE
  STA BOMBMAN_U
  STA BOMBMAN_V

  LDA #0
  STA BOMBMAN_FRAME
  STA KILLED
  STA DYING

  ; A few seconds of protection
  LDA #REVIVE_INVULNERABLE:STA INVULNERABLE_TIMER

  ; Play melody 3 (normal stage melody)
  LDA #3:STA APU_MUSIC

  JMP STAGE_LOOP
}

REVIVE_INVULNERABLE = 24 ; In units of 8 ticks (about 3 seconds)

; =============== S U B R O U T I N E =======================================
; Remove all bombs and flames from the stage (revive mode)
.CLEAR_BOMBS_AND_FIRE
{
  ; Bombs
  LDX #MAX_BOMB-1

.bomb_loop
  LDA BOMB_ACTIVE,X
  BEQ bomb_next

  LDA #NO:STA BOMB_ACTIVE,X

  LDA BOMB_X,X:STA CACHE_X
  LDA BOMB_Y,X:STA CACHE_Y
  JSR clear_cell

.bomb_next
  DEX
  BPL bomb_loop

  ; Flames, including bricks which are still burning
  LDX #MAX_FIRE-1

.fire_loop
  LDA FIRE_ACTIVE,X
  BEQ fire_next

  LDA #NO:STA FIRE_ACTIVE,X

  LDA FIRE_X,X:STA CACHE_X
  LDA FIRE_Y,X:STA CACHE_Y

  JSR map_cell
  LDA (ZH_PTR),Y
  BEQ clear_it           ; Flame over empty floor
  CMP #MAP_BRICK
  BEQ clear_it           ; Brick being blown up
  CMP #&10
  BCC fire_next          ; Exit, bonus etc. are left alone

.clear_it
  JSR clear_cell

.fire_next
  DEX
  BPL fire_loop

  RTS

; Set ZH_PTR to the map row of CACHE_Y, Y = CACHE_X
.map_cell
  LDY CACHE_Y
  LDA MULT_TABY,Y:STA ZH_PTR
  LDA MULT_TABX,Y:STA ZH_PTR+1
  LDY CACHE_X
  RTS

; Make the map cell at CACHE_X, CACHE_Y empty and redraw it
.clear_cell
  JSR map_cell
  LDA #MAP_EMPTY:STA (ZH_PTR),Y
  JMP DRAW_TILE ; Tile 0 is the empty floor
}

; =============== S U B R O U T I N E =======================================
; Choose where to respawn: an empty cell with no monster close by.
; The three cells in the top left corner are tried first, then the whole map.
SAFE_DISTANCE = 4 ; Minimum distance (x + y) to a monster

.FIND_SAFE_SPOT
{
  LDX #0

.corner_loop
  LDA CORNER_X,X:STA CACHE_X
  LDA CORNER_Y,X:STA CACHE_Y
  STX TEMP_X
  JSR is_safe
  LDX TEMP_X
  BCS found

  INX
  CPX #3
  BNE corner_loop

  ; Scan the map row by row
  LDA #1:STA CACHE_Y

.row_loop
  LDA #1:STA CACHE_X

.col_loop
  JSR is_safe
  BCS found

  INC CACHE_X
  LDA CACHE_X
  CMP #MAP_WIDTH-1
  BNE col_loop

  INC CACHE_Y
  LDA CACHE_Y
  CMP #MAP_HEIGHT-1
  BNE row_loop

  ; Nowhere safe, so use the top left corner anyway
  LDA #1
  STA CACHE_X
  STA CACHE_Y

.found
  LDA CACHE_X:STA BOMBMAN_X
  LDA CACHE_Y:STA BOMBMAN_Y

  RTS

.CORNER_X
  EQUB 1, 2, 1
.CORNER_Y
  EQUB 1, 1, 2

; Carry set if CACHE_X, CACHE_Y is safe
.is_safe
  LDY CACHE_Y
  LDA MULT_TABY,Y:STA ZH_PTR
  LDA MULT_TABX,Y:STA ZH_PTR+1
  LDY CACHE_X
  LDA (ZH_PTR),Y
  BNE unsafe ; Not empty floor

  LDX #MAX_ENEMY-1

.enemy_loop
  LDA ENEMY_TYPE,X
  BEQ enemy_next
  CMP #9
  BCS enemy_next ; Dying monster or score

  ; Distance in X
  LDA ENEMY_X,X
  SEC:SBC CACHE_X
  BCS dx_positive
  EOR #&FF:ADC #1

.dx_positive
  STA ZH_TEMP2

  ; Distance in Y
  LDA ENEMY_Y,X
  SEC:SBC CACHE_Y
  BCS dy_positive
  EOR #&FF:ADC #1

.dy_positive
  CLC:ADC ZH_TEMP2
  CMP #SAFE_DISTANCE
  BCC unsafe

.enemy_next
  DEX
  BPL enemy_loop

  SEC
  RTS

.unsafe
  CLC
  RTS
}

; =============== S U B R O U T I N E =======================================
; Decide if game time advances this frame (called once per game loop).
; In slow mode time only passes while a direction, B or SELECT is held.
.UPDATE_TICK
{
  LDA GAME_SLOW
  BEQ real_time

  LDA JOYPAD1
  ORA JOYPAD2
  AND #(PAD_UP + PAD_DOWN + PAD_LEFT + PAD_RIGHT + PAD_B + PAD_SELECT)
  BEQ frozen

  INC GAME_TICK
  LDA #YES:STA TICK_NOW

  ; Multi-kill score window (done by the NMI in real time mode)
  LDA IS_SECOND_PASSED
  BEQ store_fps

  INC FPS
  LDA FPS
  CMP #HW_FPS
  BCC store_fps

  LDA #0:STA IS_SECOND_PASSED

.store_fps
  STA FPS

  RTS

.frozen
  LDA #NO:STA TICK_NOW
  INC COSMETIC_CNT

  RTS

.real_time
  LDA FRAME_CNT:STA GAME_TICK
  LDA #YES:STA TICK_NOW

  RTS
}

; =============== S U B R O U T I N E =======================================
; Draw the enemies without moving them (slow mode, frozen frames)
.DRAW_ENEMIES
{
  ; Count the enemies like THINK does, otherwise CHECK_BONUSES sees 0 left
  ; at the start of a stage and plays the "all enemies defeated" sound
  LDA #0:STA ENEMIES_LEFT
  LDA #&C0:STA byte_6B

  LDX #MAX_ENEMY-1

.loop
  LDA ENEMY_TYPE,X
  BEQ next

  CMP #9
  BCS counted ; Dying monster or score
  INC ENEMIES_LEFT

.counted
  ; Not visible until its AI timer has run out
  LDA ENEMY_AI_TIMER,X
  BNE next

  JSR ENEMY_SAVE
  JSR loc_D006
  LDX M_ID

.next
  DEX
  BPL loop

  RTS
}

; =============== S U B R O U T I N E =======================================
; Keep bombs flashing while game time is frozen (slow mode)
.BOMB_ANIMATE_IDLE
{
  LDA COSMETIC_CNT
  AND #&F
  BNE done

  LDA COSMETIC_CNT
  LSR A:LSR A:LSR A:LSR A
  AND #3
  TAY
  LDA BOMB_ANIM_FRAMES,Y:STA ZH_TEMP

  LDX #MAX_BOMB-1

.loop
  LDA BOMB_ACTIVE,X
  BEQ next

  LDA BOMB_X,X:STA CACHE_X
  LDA BOMB_Y,X:STA CACHE_Y

  ; Only if the bomb is still on the map (not caught in a flame)
  LDY CACHE_Y
  LDA MULT_TABY,Y:STA ZH_PTR
  LDA MULT_TABX,Y:STA ZH_PTR+1
  LDY CACHE_X
  LDA (ZH_PTR),Y
  CMP #MAP_BOMB
  BNE next

  LDA ZH_TEMP
  JSR DRAW_TILE

.next
  DEX
  BPL loop

.done
  RTS

.BOMB_ANIM_FRAMES
  EQUB 9, &A, 9, 8 ; Same as BOMB_ANIM
}

INCLUDE "options.asm"
INCLUDE "pause.asm"
INCLUDE "zh_text.asm"
