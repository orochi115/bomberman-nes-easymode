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
  JSR MOD_TIME_FLASH
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

; Last 10 seconds of a story stage: the HUD flashes in the flame palette
; (BG palette 1) for 10 frames after each of the clock's warning beeps
; (CLOCK_FRAME 3Bh and 1Dh). Attributes of HUD rows 0-3 are $23C0-$23C7.
.MOD_TIME_FLASH
  LDX #0
  LDA GAME_MODE
  BNE mod_flash_set
  LDA CLOCK_DIG2
  ORA CLOCK_DIG1
  BNE mod_flash_set
  LDA CLOCK_FRAME
  BMI mod_flash_set         ; the clock has stopped
  CMP #&32
  BCS mod_flash_on
  CMP #&14
  BCC mod_flash_set
  CMP #&1E
  BCS mod_flash_set
.mod_flash_on
  INX
.mod_flash_set
  CPX TIME_FLASH_ON
  BEQ mod_flash_done
  STX TIME_FLASH_ON
  LDA #LO(MOD_HUD_ATTR_OFF)
  LDY #HI(MOD_HUD_ATTR_OFF)
  CPX #0
  BEQ mod_flash_queue
  LDA #LO(MOD_HUD_ATTR_ON)
  LDY #HI(MOD_HUD_ATTR_ON)
.mod_flash_queue
  STA DATA_PTR
  STY DATA_PTR_HI
  LDA #&23
  STA DEST_PTR_HI
  LDA #&C0
  STA DEST_PTR
  LDA #&00
  STA PPU_RUN_CTRL
  LDX #&08
  JMP QUEUE_PPU_RUN
.mod_flash_done
  RTS

.MOD_HUD_ATTR_ON
  EQUB &55, &55, &55, &55, &55, &55, &55, &55
.MOD_HUD_ATTR_OFF
  EQUB &00, &00, &00, &00, &00, &00, &00, &00

; DRAW_LIVES_HUD (story mode and the bonus stage)
.MOD_LIVES_HUD
  LDA #0
  STA TIME_FLASH_ON         ; the attributes were cleared with the screen
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
