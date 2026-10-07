; Fixed-bank part of the mod: rules of the game in progress, options entry.

; Title screen: back to the original rules (demo, VS and battle use them)
.MOD_CLEAR_RULES
  LDA #0
  LDX #GAME_SPEED - GAME_REVIVE
.mod_clear
  STA GAME_REVIVE,X
  DEX
  BPL mod_clear
  STA GAME_LIVES
  STA PASS_MARK
  LDA #&4B                  ; normal fuse (RESET_MARKS)
  STA FUSE_INIT
  RTS

; After the mode menu. NORMAL MODE: the rules of the build configuration.
; Options (GAME_MODE 3, was CONTINUE): run the options screen.
.MOD_MODE_CHOSEN
  LDA GAME_MODE
  BNE mod_not_normal
  FARCALL 7, OPTS_APPLY_DEFAULTS
  RTS
.mod_not_normal
  CMP #&03
  BEQ MOD_OPTIONS
  RTS

.MOD_OPTIONS
  FARCALL 7, OPTIONS_SCREEN
  LDA #0
  STA GAME_MODE
  STA START_AREA
  LDA OPT_RESULT
  BNE mod_opt_go
  JMP RUN_MODE_MENU         ; B: back to the mode menu
.mod_opt_go
  CMP #2
  BCS mod_opt_action
  FARCALL 7, OPTS_APPLY     ; START: a game with the options
  RTS
.mod_opt_action
  BNE mod_opt_bonus
  LDA #1
  STA MENU_MODE1            ; sound room
  RTS
.mod_opt_bonus
  LDA #1
  STA MENU_BONUS            ; bonus stage
  RTS

; After the sound room or the bonus stage (both entered from the options
; screen): the options screen again, then on as after the mode menu
.MOD_BACK_TO_OPTIONS
  LDA #0
  STA MENU_MODE1
  STA MENU_BONUS
  STA MENU_REDRAW
  JSR MOD_OPTIONS
  JMP mode_menu_done

; Lives at the start of a game (STAGE_BOOT): GAME_LIVES - 1, or the original
; 2 when it is 0. Unlimited lives (10) start with 2 and never lose one.
.MOD_START_LIVES
  JSR MOD_GAME_POWERS
  LDA GAME_LIVES
  BEQ mod_lives_2
  CMP #10
  BEQ mod_lives_2
  SEC
  SBC #1
  RTS
.mod_lives_2
  LDA #&02
  RTS

; Start of a game (STAGE_BOOT): the round flags of CLEAR_ROUND_FLAGS (it is
; not called when a game starts on another stage, KEEP_STAGE, like the
; options do), then the options' powers
.MOD_GAME_POWERS
  LDA DEMO_MODE
  BNE mod_powers_done       ; the demo sets up its own flags
  LDA #0
  STA ACT_PASSBOMB
  STA ACT_PASSWALL
  STA ITEM_KIND
  STA ACT_SPEED
  STA ACT_REMOTE
  LDA GAME_MODE
  BNE mod_powers_done
  LDA PASS_MARK
  STA ACT_REMOTE
  ; fall into MOD_STAGE_POWERS

; Every life of a story stage (end of INIT_PLAYERS' round flags): the pass
; and speed options.
.MOD_STAGE_POWERS
  LDA GAME_MODE
  BNE mod_powers_done
  LDA GAME_WPASS
  BEQ mod_no_wpass
  STA ACT_PASSWALL
.mod_no_wpass
  LDA GAME_BPASS
  BEQ mod_no_bpass
  STA ACT_PASSBOMB
.mod_no_bpass
  LDA GAME_SPEED
  CMP ACT_SPEED
  BCC mod_powers_done
  STA ACT_SPEED
.mod_powers_done
  RTS

; Unlimited time (not on the bonus stage): Z clear = the clock is frozen
.MOD_TIME_FROZEN
  LDA SPECIAL_STAGE
  BNE mod_time_runs
  LDA GAME_INF_TIME
  RTS
.mod_time_runs
  LDA #0
  RTS

; A soft block that hides an item (A = TILESET) or the exit (A = 0Ch) at
; column X, row Y is being placed (PLACE_ONE_PICKUP, PLACE_STORY_BOMB).
; Remember it for x-ray (MOD_XRAY_BLINK). Out: A = the soft block tile 39h.
; X, Y are kept.
.MOD_XRAY_TILE
  STY ZH_TMP
  LDY #0                    ; slot 0: item
  CMP #&0C
  BNE mod_xray_slot
  LDY #3                    ; slot 1: exit
.mod_xray_slot
  STX ZH_W
  TAX
  LDA MOD_REVEAL_TILE,X
  STA XRAY_CELLS+2,Y
  LDA ZH_W
  STA XRAY_CELLS,Y
  TAX
  LDA ZH_TMP
  STA XRAY_CELLS+1,Y
  TAY
  LDA #&39
  RTS

; Stage entry: nothing to show yet
.MOD_XRAY_CLEAR
  LDA #&FF
  STA XRAY_CELLS
  STA XRAY_CELLS+3
  RTS

.MOD_REVEAL_TILE            ; = BURIED_REVEAL_TILE (bank 5)
  EQUB &20,&21,&22,&22,&22,&22,&22,&22,&22,&22,&22,&2C,&29

; Revive mode: remember the score and power-ups when a stage is entered
.MOD_SNAPSHOT
  JSR MOD_XRAY_CLEAR
  LDA GAME_REVIVE
  BEQ mod_snap_done
  LDX #7
.mod_snap
  LDA SCORE_NOW,X
  STA SNAP_SCORE,X
  DEX
  BPL mod_snap
  LDA ACTOR_BOMBS
  STA SNAP_FIRE
  LDA ACTOR_FIRE
  STA SNAP_BOMBS
.mod_snap_done
  RTS

; ... and put them back, with the lives of a new game
.MOD_RESTORE
  LDX #7
.mod_restore
  LDA SNAP_SCORE,X
  STA SCORE_NOW,X
  DEX
  BPL mod_restore
  LDA SNAP_FIRE
  STA ACTOR_BOMBS
  LDA SNAP_BOMBS
  STA ACTOR_FIRE
  JSR MOD_START_LIVES
  STA LIVES
  RTS

; Slow mode (STAGE_LOOP): the game only moves while the player holds the
; d-pad or B. A (drop a bomb) works on frozen frames. Dying, the end of a
; stage and the time after a death always move. TICK_NOW is 0 only between
; here and the end of UPDATE_PLAYERS on a frozen frame.
.MOD_SLOW_TICK
  LDA #1
  STA TICK_NOW
  LDA GAME_SLOW
  BEQ mod_tick_done
  LDA CLEAR_PHASE
  ORA STAGE_PHASE
  ORA ACTOR_DEATH
  BNE mod_tick_done
  LDA ACTOR_FLAG
  BEQ mod_tick_done
  LDA JOY_HELD
  AND #&4F                  ; B and the d-pad
  BNE mod_tick_done
  LDA #0
  STA TICK_NOW
.mod_tick_done
  RTS

; Frozen frame: enemies are drawn where they are (the NMI clears the
; sprites every frame), bombs keep pulsing
.MOD_FROZEN_ENEMIES
  LDA GAME_MODE
  BNE mod_frozen_done
  LDA CUR_BANK
  PHA
  LDX #&00
  JSR BANK_SWITCH
  JSR DRAW_ALL_ENEMIES
  LDX #&05
  JSR BANK_SWITCH
  JSR MOD_FROZEN_BOMBS
  PLA
  TAX
  JMP BANK_SWITCH
.mod_frozen_done
  RTS
