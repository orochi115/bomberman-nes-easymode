; Options screen (MOD builds, bank 7). It replaces the password screen
; (CONTINUE in the mode menu); the password words became options or the two
; actions at the bottom (sound room, bonus stage).
;
; 18 positions in two columns of 9: rows 0-7 are settings, row 8 the
; actions. Up/Down go through both columns, SELECT jumps to the other one. An item is two rows of OPT_W tiles:
;   0 cursor, 1-6 label, 7 left arrow, 8-12 value, 13 right arrow
; (cursor and arrows only on the selected item).

NUM_OPTS = 16           ; settings, in the order of OPT_VALS
OPT_W = 14
OPT_ROWS = 9            ; positions per column
OPT_SIGNATURE = &B2C7

OPT_REPEAT_DELAY = 20
OPT_REPEAT_RATE = 4

; Kinds of value
K_NUM1 = 0              ; digit, value + 1
K_NUM = 1               ; digit
K_LIVES = 2             ; digit, 10 = unlimited
K_LIST = 3              ; string from a list
K_ACTION = 4            ; no value (sound room, bonus stage)

; Index of each setting in OPT_VALS (the order of config/default.asm)
O_AREA = 0 : O_STAGE = 1 : O_LIVES = 2 : O_FIRE = 3 : O_BOMBS = 4
O_SPEED = 5 : O_TIME = 6 : O_REVIVE = 7 : O_SLOW = 8 : O_REMOTE = 9
O_WPASS = 10 : O_BPASS = 11 : O_FPASS = 12 : O_XRAY = 13 : O_INVINC = 14
O_FUSE = 15
I_SOUND = 16 : I_BONUS = 17

; Values as stored (0-based where the screen shows 1-based numbers)
.OPT_DEFAULTS
  EQUB CFG_AREA - 1, CFG_STAGE - 1, CFG_LIVES, CFG_FIRE - 1, CFG_BOMBS - 1
  EQUB CFG_SPEED, CFG_TIME, CFG_REVIVE, CFG_SLOW, CFG_REMOTE
  EQUB CFG_WPASS, CFG_BPASS, CFG_FPASS, CFG_XRAY, CFG_INVINC, CFG_FUSE

.OPT_MIN
  EQUB 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
.OPT_MAX
  EQUB 5, 7, 10, 4, 7, 4, 1, 1, 1, 2, 1, 1, 1, 1, 1, 2

ASSERT CFG_AREA >= 1 AND CFG_AREA <= 6 AND CFG_STAGE >= 1 AND CFG_STAGE <= 8
ASSERT CFG_LIVES >= 1 AND CFG_LIVES <= 10 AND CFG_FIRE >= 1 AND CFG_FIRE <= 5
ASSERT CFG_BOMBS >= 1 AND CFG_BOMBS <= 8 AND CFG_SPEED >= 0 AND CFG_SPEED <= 4
ASSERT CFG_TIME <= 1 AND CFG_REVIVE <= 1 AND CFG_SLOW <= 1 AND CFG_REMOTE <= 2
ASSERT CFG_WPASS <= 1 AND CFG_BPASS <= 1 AND CFG_FPASS <= 1 AND CFG_XRAY <= 1
ASSERT CFG_INVINC <= 1 AND CFG_FUSE <= 2

.OPT_KIND
  EQUB K_NUM1, K_NUM1, K_LIVES, K_NUM1, K_NUM1, K_NUM, K_LIST, K_LIST
  EQUB K_LIST, K_LIST, K_LIST, K_LIST, K_LIST, K_LIST, K_LIST, K_LIST
  EQUB K_ACTION, K_ACTION

.OPT_LABEL
  EQUB ZH_OPT_AREA, ZH_OPT_STAGE, ZH_OPT_LIVES, ZH_OPT_FIRE, ZH_OPT_BOMBS
  EQUB ZH_OPT_SPEED, ZH_OPT_TIME, ZH_OPT_REVIVE, ZH_OPT_SLOW, ZH_OPT_REMOTE
  EQUB ZH_OPT_WPASS, ZH_OPT_BPASS, ZH_OPT_FPASS, ZH_OPT_XRAY, ZH_OPT_INVINC
  EQUB ZH_OPT_FUSE, ZH_OPT_SOUND, ZH_OPT_BONUS

; K_LIST items: offset of their list in OPT_LISTS
.OPT_LIST
  EQUB 0, 0, 0, 0, 0, 0, L_TIME, L_BOOL
  EQUB L_BOOL, L_REMOTE, L_BOOL, L_BOOL, L_BOOL, L_BOOL, L_BOOL, L_FUSE

.OPT_LISTS
L_BOOL = P% - OPT_LISTS
  EQUB ZH_VAL_NO, ZH_VAL_YES
L_TIME = P% - OPT_LISTS
  EQUB ZH_VAL_NORM, ZH_VAL_INF
L_REMOTE = P% - OPT_LISTS
  EQUB ZH_VAL_NO, ZH_VAL_YES, ZH_VAL_TIMED
L_FUSE = P% - OPT_LISTS
  EQUB ZH_VAL_SHORT, ZH_VAL_NORM, ZH_VAL_LONG

; Position (column * 9 + row) -> item
; Left: rules of the game. Right: the power-ups of the original game.
.OPT_POS_ITEM
  EQUB O_AREA, O_STAGE, O_LIVES, O_TIME, O_REVIVE, O_SLOW, O_XRAY, O_FUSE, I_SOUND
  EQUB O_FIRE, O_BOMBS, O_SPEED, O_REMOTE, O_WPASS, O_BPASS, O_FPASS, O_INVINC, I_BONUS

; PPU address of each position (top left of the item)
MACRO OPT_ADDR row, col
  EQUW &2000 + row * 32 + col
ENDMACRO
.OPT_POS_ADDR
  FOR r, 0, OPT_ROWS - 1
    OPT_ADDR 2 + r * 3, 1
  NEXT
  FOR r, 0, OPT_ROWS - 1
    OPT_ADDR 2 + r * 3, 17
  NEXT

; Fuse lengths (FUSE_INIT) for short, normal, long: the BOMBACE, BOMBMAN and
; BOMBOLD password words
.OPT_FUSE_TAB
  EQUB &2D, &4B, &69

; ---------------------------------------------------------------------------
; Power on: valid options survive a reset, otherwise take the defaults
.OPTS_INIT
  LDA OPT_SIG
  CMP #LO(OPT_SIGNATURE)
  BNE opts_defaults
  LDA OPT_SIG+1
  CMP #HI(OPT_SIGNATURE)
  BNE opts_defaults
  LDX #NUM_OPTS - 1
.opts_check
  LDA OPT_VALS,X
  CMP OPT_MIN,X
  BCC opts_defaults
  LDA OPT_MAX,X
  CMP OPT_VALS,X
  BCC opts_defaults
  DEX
  BPL opts_check
  LDA OPT_CURSOR
  CMP #OPT_ROWS * 2
  BCS opts_defaults
  RTS
.opts_defaults
  LDX #NUM_OPTS - 1
.opts_copy
  LDA OPT_DEFAULTS,X
  STA OPT_VALS,X
  DEX
  BPL opts_copy
  LDA #0
  STA OPT_CURSOR
  LDA #LO(OPT_SIGNATURE)
  STA OPT_SIG
  LDA #HI(OPT_SIGNATURE)
  STA OPT_SIG+1
  RTS

; ---------------------------------------------------------------------------
; Rules of a game from NUM_OPTS values at (ZH_SRC): OPTS_APPLY uses the
; options, OPTS_APPLY_DEFAULTS the build configuration (NORMAL MODE).
.OPTS_APPLY_DEFAULTS
  LDA #LO(OPT_DEFAULTS)
  STA ZH_SRC
  LDA #HI(OPT_DEFAULTS)
  STA ZH_SRC_HI
  JMP opts_apply

.OPTS_APPLY
  LDA #LO(OPT_VALS)
  STA ZH_SRC
  LDA #HI(OPT_VALS)
  STA ZH_SRC_HI
.opts_apply
  ; Another stage or other power-ups: start like a password does
  ; (KEEP_STAGE), otherwise the normal way
  LDY #O_AREA
  LDA (ZH_SRC),Y
  LDY #O_STAGE
  ORA (ZH_SRC),Y
  LDY #O_FIRE
  ORA (ZH_SRC),Y
  LDY #O_BOMBS
  ORA (ZH_SRC),Y
  BEQ apply_rules
  LDA #1
  STA KEEP_STAGE
  LDY #O_AREA
  LDA (ZH_SRC),Y
  STA AREA_NUM
  LDY #O_STAGE
  LDA (ZH_SRC),Y
  STA STAGE_NUM
  ; The names are swapped: ACTOR_BOMBS is the flame length (DETONATE_BOMB),
  ; ACTOR_FIRE the number of bombs (ALLOC_BOMB_SLOT)
  LDY #O_FIRE
  LDA (ZH_SRC),Y
  STA ACTOR_BOMBS
  LDY #O_BOMBS
  LDA (ZH_SRC),Y
  STA ACTOR_FIRE
.apply_rules
  LDY #O_LIVES
  LDA (ZH_SRC),Y
  STA GAME_LIVES
  LDX #0
  CMP #10
  BNE apply_lives
  INX
.apply_lives
  STX GAME_INF_LIVES
  LDY #O_SPEED
  LDA (ZH_SRC),Y
  STA GAME_SPEED
  LDY #O_TIME
  LDA (ZH_SRC),Y
  STA GAME_INF_TIME
  LDY #O_REVIVE
  LDA (ZH_SRC),Y
  STA GAME_REVIVE
  LDY #O_SLOW
  LDA (ZH_SRC),Y
  STA GAME_SLOW
  LDY #O_REMOTE
  LDA (ZH_SRC),Y
  STA PASS_MARK             ; ACT_REMOTE at the start of every stage
  LDY #O_WPASS
  LDA (ZH_SRC),Y
  STA GAME_WPASS
  LDY #O_BPASS
  LDA (ZH_SRC),Y
  STA GAME_BPASS
  LDY #O_FPASS
  LDA (ZH_SRC),Y
  STA GAME_FIREPROOF
  LDY #O_XRAY
  LDA (ZH_SRC),Y
  STA GAME_XRAY
  LDY #O_INVINC
  LDA (ZH_SRC),Y
  STA GAME_INVINC
  LDY #O_FUSE
  LDA (ZH_SRC),Y
  TAX
  LDA OPT_FUSE_TAB,X
  STA FUSE_INIT
  RTS

; ---------------------------------------------------------------------------
; Show the options screen. OPT_RESULT: 0 back to the mode menu (B), 1 start a
; game with the options (START), 2 sound room, 3 bonus stage (A on them).
.OPTIONS_SCREEN
  JSR PPU_OFF
  JSR NMI_OFF
  JSR CLEAR_SCROLL
  LDA #&13
  JSR FILL_NAMETABLE
  JSR CLEAR_ATTRS
  FARCALL 5, LOAD_MENU_CHR
  FARCALL 5, LOAD_MODE_PAL
  LDA #ZH_SET_OPTS
  JSR ZH_SCREEN
  LDA #0
  STA OPT_LIVE
  STA OPT_REPEAT
  LDX #OPT_ROWS * 2 - 1
.opt_draw_all
  TXA
  PHA
  JSR OPT_DRAW
  PLA
  TAX
  DEX
  BPL opt_draw_all
  LDA #1
  STA OPT_LIVE
  JSR NMI_ON
  JSR PPU_ON
  JSR MARK_PALETTE

.opt_loop
  JSR WAIT_NMI
  ; New presses, plus auto repeat for held directions
  LDA JOY_HELD
  AND #&0F
  BEQ opt_input
  LDA JOY_NEW
  AND #&0F
  BEQ opt_held
  LDA #OPT_REPEAT_DELAY
  STA OPT_REPEAT
  BNE opt_input
.opt_held
  DEC OPT_REPEAT
  BNE opt_input
  LDA #OPT_REPEAT_RATE
  STA OPT_REPEAT
  LDA JOY_HELD
  AND #&0F
  ORA JOY_NEW
  STA JOY_NEW
.opt_input
  LDA JOY_NEW
  AND #&10
  BNE opt_start
  LDA JOY_NEW
  AND #&40
  BNE opt_back
  LDA JOY_NEW
  AND #&08
  BNE opt_up
  LDA JOY_NEW
  AND #&04
  BNE opt_down
  LDA JOY_NEW
  AND #&20
  BNE opt_column
  LDA JOY_NEW
  AND #&02
  BNE opt_dec
  LDA JOY_NEW
  AND #&81
  BNE opt_inc
  JMP opt_loop

.opt_start
  LDA #1
  BNE opt_exit
.opt_back
  LDA #0
.opt_exit
  STA OPT_RESULT
  JSR FADE_PALETTE
  JMP PPU_OFF

; Up / Down run through both columns: past the bottom of the left column
; is the top of the right one, and the ends wrap round
.opt_up
  LDX OPT_CURSOR
  DEX
  BPL opt_move
  LDX #OPT_ROWS * 2 - 1
  JMP opt_move

.opt_down
  LDX OPT_CURSOR
  INX
  CPX #OPT_ROWS * 2
  BCC opt_move
  LDX #0
  JMP opt_move

.opt_column
  LDA OPT_CURSOR
  CLC
  ADC #OPT_ROWS
  CMP #OPT_ROWS * 2
  BCC opt_column_ok
  SBC #OPT_ROWS * 2
.opt_column_ok
  TAX

; Cursor to position X: redraw the old and the new item
.opt_move
  LDA OPT_CURSOR
  STX OPT_CURSOR
  TAX
  JSR OPT_DRAW
  LDX OPT_CURSOR
  JSR OPT_DRAW
  LDA #&07
  JSR AUDIO_CALL
  JMP opt_loop

.opt_dec
  LDX OPT_CURSOR
  LDY OPT_POS_ITEM,X
  CPY #NUM_OPTS
  BCS opt_done
  LDA OPT_VALS,Y
  CMP OPT_MIN,Y
  BNE opt_dec_ok
  LDA OPT_MAX,Y             ; wrap round to the largest value
  CLC
  ADC #1
.opt_dec_ok
  SEC
  SBC #1
  JMP opt_changed

.opt_inc
  LDX OPT_CURSOR
  LDY OPT_POS_ITEM,X
  CPY #NUM_OPTS
  BCS opt_action
  LDA OPT_VALS,Y
  CMP OPT_MAX,Y
  BNE opt_inc_ok
  LDA OPT_MIN,Y             ; wrap round to the smallest value
  SEC
  SBC #1
.opt_inc_ok
  CLC
  ADC #1
.opt_changed
  STA OPT_VALS,Y
  JSR OPT_DRAW
  LDA #&07
  JSR AUDIO_CALL
.opt_done
  JMP opt_loop

; A on the sound room or the bonus stage (Right does nothing there)
.opt_action
  LDA JOY_NEW
  AND #&80
  BEQ opt_done
  TYA
  SEC
  SBC #I_SOUND - 2          ; 2 sound room, 3 bonus stage
  JMP opt_exit

; ---------------------------------------------------------------------------
; Draw the item at position X: compose it in OPT_BUF, then write it to the
; PPU (rendering off) or queue it (OPT_LIVE)
.OPT_DRAW
  STX OPT_TMP
  LDA #0
  CPX OPT_CURSOR
  BNE opt_sel
  LDA #1
.opt_sel
  STA OPT_SEL
  ; Blank both rows
  LDA #&13
  LDY #OPT_W - 1
.opt_blank
  STA OPT_BUF,Y
  STA OPT_BUF + 32,Y
  DEY
  BPL opt_blank
  ; Cursor
  LDA OPT_SEL
  BEQ opt_label
  LDY #0
  LDA #ZH_OPT_CURSOR
  JSR opt_put
.opt_label
  LDX OPT_TMP
  LDY OPT_POS_ITEM,X
  LDA OPT_LABEL,Y
  LDY #1
  JSR opt_put
  ; Value and arrows
  LDX OPT_TMP
  LDY OPT_POS_ITEM,X
  LDA OPT_KIND,Y
  CMP #K_ACTION
  BEQ opt_out
  LDA OPT_SEL
  BEQ opt_value
  LDY #7
  LDA #ZH_OPT_LARROW
  JSR opt_put
  LDY #13
  LDA #ZH_OPT_RARROW
  JSR opt_put
.opt_value
  LDX OPT_TMP
  LDY OPT_POS_ITEM,X
  LDA OPT_KIND,Y
  CMP #K_LIST
  BEQ opt_list
  LDA OPT_VALS,Y
  CMP #10
  BEQ opt_inf               ; K_LIVES 10: unlimited
  LDX OPT_KIND,Y
  BNE opt_digit             ; K_NUM, K_LIVES: the value itself
  CLC
  ADC #1                    ; K_NUM1
.opt_digit
  ORA #&30
  STA OPT_BUF + 32 + 10
  JMP opt_out
.opt_inf
  LDA #ZH_VAL_INF
  JMP opt_centre
.opt_list
  LDA OPT_LIST,Y
  CLC
  ADC OPT_VALS,Y
  TAX
  LDA OPT_LISTS,X
; String A centred in the 5 value columns 8-12
.opt_centre
  PHA
  JSR ZH_WIDTH
  STA ZH_TMP
  LDA #5
  SEC
  SBC ZH_TMP
  LSR A
  CLC
  ADC #8
  TAY
  PLA
  JSR opt_put

; Write or queue the two rows
.opt_out
  LDA OPT_TMP
  ASL A
  TAX
  LDA OPT_POS_ADDR,X
  STA DEST_PTR
  LDA OPT_POS_ADDR+1,X
  STA DEST_PTR_HI
  LDA OPT_LIVE
  BNE opt_queue
  LDX #0
.opt_row
  LDA PPU_STATUS
  LDA DEST_PTR_HI
  STA PPU_ADDRESS
  LDA DEST_PTR
  STA PPU_ADDRESS
  LDY #0
.opt_col
  LDA OPT_BUF,X
  STA PPU_DATA
  INX
  INY
  CPY #OPT_W
  BNE opt_col
  CPX #32 + OPT_W
  BCS opt_written
  LDA DEST_PTR
  CLC
  ADC #32
  STA DEST_PTR
  LDA DEST_PTR_HI
  ADC #0
  STA DEST_PTR_HI
  LDX #32
  JMP opt_row
.opt_written
  RTS
.opt_queue
  LDA #0
  STA PPU_RUN_CTRL
  LDA #LO(OPT_BUF)
  STA DATA_PTR
  LDA #HI(OPT_BUF)
  STA DATA_PTR_HI
  LDX #OPT_W
  JSR QUEUE_PPU_RUN
  LDA DEST_PTR
  CLC
  ADC #32
  STA DEST_PTR
  LDA DEST_PTR_HI
  ADC #0
  STA DEST_PTR_HI
  LDA #LO(OPT_BUF + 32)
  STA DATA_PTR
  LDA #HI(OPT_BUF + 32)
  STA DATA_PTR_HI
  LDX #OPT_W
  JMP QUEUE_PPU_RUN

; Copy string A to OPT_BUF column Y
.opt_put
  PHA
  TYA
  CLC
  ADC #LO(OPT_BUF)
  STA ZH_ADDR
  LDA #HI(OPT_BUF)
  ADC #0
  STA ZH_ADDR_HI
  PLA
  JMP ZH_COPY

; ---------------------------------------------------------------------------
; Pause (UPDATE_PAUSE after the pause sound): the HUD slides to the hint,
; START resumes, SELECT goes back to the title, Left / Right look round a
; wide map (the player and the enemies are drawn at the view).
.MOD_PAUSE
IF ZH
  LDA #ZH_HUD_PAUSE
  JSR ZH_QUEUE
  LDA LAYOUT_VAR
  BEQ pause_narrow
  LDA #ZH_HUD_PAUSE_MAP
  JSR ZH_QUEUE
.pause_narrow
  LDA #ZH_HUD_PAUSE_QUIT
  JSR ZH_QUEUE
ELSE
  LDX #&2D
  LDY #&02
  JSR XY_TO_NT_ADDR
  LDA #LO(PAUSE_TEXT)
  STA DATA_PTR
  LDA #HI(PAUSE_TEXT)
  STA DATA_PTR_HI
  LDA #&00
  STA PPU_RUN_CTRL
  LDX #&05
  JSR QUEUE_PPU_RUN
ENDIF
.pause_loop
  JSR WAIT_NMI
  LDA JOY_NEW
  AND #&10
  BNE pause_done
  LDA JOY_NEW
  AND #&20
  BNE pause_quit
  ; Slide the HUD to the hint (as the original)
  LDA SPLIT_SCROLL_X
  CMP #&FC
  BCS pause_view
  CLC
  ADC #&08
  BCC pause_slide
  LDA #&FC
.pause_slide
  STA SPLIT_SCROLL_X
.pause_view
  LDA LAYOUT_VAR
  BEQ pause_loop
  LDA JOY_HELD
  AND #&03
  BEQ pause_loop
  ; Scroll by 4 between -8 and F8h (FOLLOW_ACTOR_SCROLL's limits)
  AND #&01
  BEQ pause_left
  LDA SCROLL_X
  CLC
  ADC #&04
  TAX
  LDA SCROLL_NT
  ADC #&00
  BMI pause_scroll
  CPX #&F9
  BCC pause_scroll
  LDX #&F8
  LDA #&00
  BEQ pause_scroll
.pause_left
  LDA SCROLL_X
  SEC
  SBC #&04
  TAX
  LDA SCROLL_NT
  SBC #&00
  BPL pause_scroll
  CPX #&F8
  BCS pause_scroll
  LDX #&F8
  LDA #&FF
.pause_scroll
  STX SCROLL_X
  STA SCROLL_NT
  FARCALL 5, MOD_DRAW_PLAYER
  LDA GAME_MODE
  BNE pause_drawn
  FARCALL 0, DRAW_ALL_ENEMIES
.pause_drawn
  JSR MARK_OAM
  JMP pause_loop
.pause_done
  RTS

.pause_quit
  LDA #&06
  JSR AUDIO_CALL
  LDX PAUSE_X
  LDA #&83
  JSR AUDIO_CALL            ; undo the audio pause
  LDA #&80
  JSR AUDIO_CALL            ; and stop the music
  JSR FADE_PALETTE
  JSR PPU_OFF
  LDA #&00
  STA SPLIT_SCROLL_X
  STA SPLIT_CTRL_BIT
  LDX #&FF
  TXS
  JMP MENU_LOOP

; ---------------------------------------------------------------------------
; X-ray (STAGE_LOOP, story mode): the soft blocks that still hide the item
; or the exit blink between the block and what it hides, half a second
; each. The map byte stays a soft block, so they still have to be bombed.
.MOD_XRAY_BLINK
  LDA GAME_XRAY
  BEQ mod_blink_done
  LDA GAME_MODE
  BNE mod_blink_done
  LDA FRAME_CNT
  AND #&1F
  BNE mod_blink_done
  LDY #0
  JSR mod_blink_cell
  LDY #3
.mod_blink_cell             ; Y = 0 (item) or 3 (exit)
  STY ZH_W
  LDA XRAY_CELLS,Y
  BMI mod_blink_done
  LDA XRAY_CELLS+1,Y
  TAY
  JSR MAP_ROW_PTR
  LDX ZH_W
  LDY XRAY_CELLS,X
  LDA (MAP_PTR),Y
  AND #&FC
  CMP #&20                  ; still an intact soft block (21h / 22h)?
  BNE mod_blink_gone
  LDA FRAME_CNT
  AND #&20
  BEQ mod_blink_block
  LDA XRAY_CELLS+2,X        ; what it hides
  BNE mod_blink_queue
.mod_blink_block
  LDA #&39
.mod_blink_queue
  PHA
  LDA XRAY_CELLS+1,X
  TAY
  LDA XRAY_CELLS,X
  TAX
  PLA
  JMP QUEUE_TILE_Y2
.mod_blink_gone
  LDA #&FF
  STA XRAY_CELLS,X
.mod_blink_done
  RTS

