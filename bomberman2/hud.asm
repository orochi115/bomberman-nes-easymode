; HUD of the mod (fixed bank): unlimited time / lives hide their counts,
; Chinese puts 时间 and 剩余 above the HUD row. Called from bank 5.

.MOD_CLOCK_COL              ; = CLOCK_HUD_COL (bank 5), by GAME_MODE
  EQUB &0E, &0D, &18

; DRAW_STAGE_CLOCK
.MOD_DRAW_CLOCK
  JSR MOD_TIME_FROZEN
  BEQ mod_clock
  RTS                       ; unlimited time: no clock
.mod_clock
IF ZH
  ; 时间 is drawn once by ZH_TIME_LABEL, only the digits here, at
  ; MOD_CLOCK_COL + 4 (the label takes the columns from MOD_CLOCK_COL - 1)
  LDA CLOCK_DIG2
  ORA #&30
  STA W_052A
  LDA CLOCK_DIG1
  ORA #&30
  STA W_052B
  LDA W_055B
  ORA #&30
  STA W_052C
  LDY GAME_MODE
  LDA MOD_CLOCK_COL,Y
  CLC
  ADC #&04
  TAX
  LDY #&02
  JSR XY_TO_NT_ADDR
  LDA #LO(W_052A)
  STA DATA_PTR
  LDA #HI(W_052A)
  STA DATA_PTR_HI
  LDA #&00
  STA PPU_RUN_CTRL
  LDX #&03
  JMP QUEUE_PPU_RUN
ELSE
  JMP clock_original
ENDIF

; DRAW_LIVES_HUD (story mode and the bonus stage)
.MOD_LIVES_HUD
IF ZH
  JSR ZH_TIME_LABEL
ENDIF
  LDA GAME_INF_LIVES
  BEQ mod_lives
  RTS                       ; unlimited lives: no count
.mod_lives
IF ZH
  LDA #ZH_HUD_LEFT
  JSR ZH_QUEUE
  LDA LIVES
  ORA #&30
  STA W_052A
  LDX #&1B
  LDY #&02
  JSR XY_TO_NT_ADDR
  LDA #LO(W_052A)
  STA DATA_PTR
  LDA #HI(W_052A)
  STA DATA_PTR_HI
  LDA #&00
  STA PPU_RUN_CTRL
  LDX #&01
  JMP QUEUE_PPU_RUN
ELSE
  JMP lives_original
ENDIF

IF ZH
; DRAW_MODE_HUD: 时间 in VS and battle
.MOD_MODE_HUD
  LDA GAME_MODE
  BNE ZH_TIME_LABEL
  RTS

; Queue 时间 (two rows) at MOD_CLOCK_COL - 1, rows 1-2
.ZH_TIME_LABEL
  JSR MOD_TIME_FROZEN
  BEQ zh_time_label
  RTS
.zh_time_label
  LDY GAME_MODE
  LDX MOD_CLOCK_COL,Y
  DEX
  LDY #&01
  JSR XY_TO_NT_ADDR
  LDA DEST_PTR
  STA ZH_ADDR
  LDA DEST_PTR_HI
  STA ZH_ADDR_HI
  LDA #ZH_HUD_TIME
  JMP ZH_QUEUE
ENDIF
