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

; Lives at the start of a game (STAGE_BOOT): GAME_LIVES - 1, or the original
; 2 when it is 0. Unlimited lives (10) start with 2 and never lose one.
.MOD_START_LIVES
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

; Every life of a story stage (end of INIT_PLAYERS' round flags): the pass
; and speed options. ACT_PASSBOMB lets the player through soft blocks and
; ACT_PASSWALL through bombs (CELL_BLOCKS_MOVE), whatever their names say.
.MOD_STAGE_POWERS
  LDA GAME_MODE
  BNE mod_powers_done
  LDA GAME_WPASS
  BEQ mod_no_wpass
  STA ACT_PASSBOMB
.mod_no_wpass
  LDA GAME_BPASS
  BEQ mod_no_bpass
  STA ACT_PASSWALL
.mod_no_bpass
  LDA GAME_SPEED
  CMP ACT_SPEED
  BCC mod_powers_done
  STA ACT_SPEED
.mod_powers_done
  RTS
