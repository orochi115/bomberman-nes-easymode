; ===========================================================================
; Pause screen: the status bar shows "暂停" plus hints, and left / right
; scroll round the map. Called from PAUSED once START has been released.
; ===========================================================================

PAUSE_SCROLL_STEP = 2   ; Pixels per frame
PAUSE_SCROLL_MAX = &F0  ; Same limit as DRAW_BOMBERMAN

HUD_ROW1 = &20 ; Low byte of the PPU address of status bar rows 1 and 2
HUD_ROW2 = &40

.PAUSE_SCREEN
{
  LDA #YES:STA PAUSE_SHOWN ; Stops the NMI drawing the score, time and lives

  ; Status bar message, one row per frame
  LDA #lo(ZH_PAUSE_HINT):STA ZH_PTR
  LDA #hi(ZH_PAUSE_HINT):STA ZH_PTR+1
  LDA #HUD_ROW1
  JSR hud_row_blank
  LDA #0
  JSR hud_row_record
  JSR VBUF_SEND

  LDA #HUD_ROW2
  JSR hud_row_blank
  LDA #1
  JSR hud_row_record
  JSR VBUF_SEND

  LDA H_SCROLL:STA PAUSE_SCROLL

.loop
  JSR NEXTFRAME

  ; SELECT quits to the title screen
  LDA JOYPAD1
  AND #PAD_SELECT
  BEQ not_quit
  JMP QUIT_TO_MENU

.not_quit
  ; START resumes
  LDA JOYPAD1
  AND #PAD_START
  BNE resume

  ; Left / right scroll the view
  LDA JOYPAD1
  AND #PAD_LEFT
  BEQ not_left

  LDA PAUSE_SCROLL
  SEC:SBC #PAUSE_SCROLL_STEP
  BCS left_ok
  LDA #0

.left_ok
  STA PAUSE_SCROLL

.not_left
  LDA JOYPAD1
  AND #PAD_RIGHT
  BEQ not_right

  LDA PAUSE_SCROLL
  CLC:ADC #PAUSE_SCROLL_STEP
  CMP #PAUSE_SCROLL_MAX+1
  BCC right_ok
  LDA #PAUSE_SCROLL_MAX

.right_ok
  STA PAUSE_SCROLL

.not_right
  JSR PAUSE_VIEW
  JMP loop

.resume
  JSR RESTORE_HUD

  LDA #NO:STA PAUSE_SHOWN
  RTS
}

; =============== S U B R O U T I N E =======================================
; Draw the sprites for the paused view at PAUSE_SCROLL
.PAUSE_VIEW
{
  LDA #1:STA SPR_TAB_INDEX
  JSR SPRD

  LDA PAUSE_SCROLL:STA H_SCROLL

  JSR DRAW_BOMBERMAN_VIEW
  JSR DRAW_ENEMIES

  ; Extra bonus item, if showing (as in CHECK_BONUSES)
  LDA BONUS_STATUS
  BEQ done
  CMP #BONUS_COLLECTED
  BEQ done
  JMP sub_CFED

.done
  RTS
}

; =============== S U B R O U T I N E =======================================
; Draw bomberman relative to H_SCROLL without changing it (DRAW_BOMBERMAN
; sets the scroll to follow bomberman). Not drawn when off screen.
.DRAW_BOMBERMAN_VIEW
{
  LDA BOMBMAN_FRAME
  CMP #19
  BCS done

  LDA SPR_ATTR_TEMP:STA SPR_ATTR
  LDY #0:STY SPR_COL

  ; X position in pixels (9 bits), minus 8 for the sprite centre and the scroll
  STY ZH_TEMP2
  LDA BOMBMAN_X
  ASL A:ASL A:ASL A:ASL A ; A = A * 16
  ROL ZH_TEMP2
  CLC:ADC BOMBMAN_U
  BCC no_carry
  INC ZH_TEMP2

.no_carry
  SEC:SBC #8
  BCS no_borrow
  DEC ZH_TEMP2

.no_borrow
  SEC:SBC H_SCROLL
  BCS no_borrow2
  DEC ZH_TEMP2

.no_borrow2
  LDY ZH_TEMP2
  BNE done ; Off screen
  CMP #&F8
  BCS done ; Off the right edge
  STA SPR_X

  LDA BOMBMAN_Y
  ASL A:ASL A:ASL A:ASL A ; A = A * 16
  CLC:ADC BOMBMAN_V
  ADC #23
  STA SPR_Y

  LDX BOMBMAN_FRAME
  LDA BOMBER_ANIM,X
  JMP SPR_DRAW

.done
  RTS
}

; =============== S U B R O U T I N E =======================================
; Put back the normal status bar after the pause message (the NMI draws the
; numbers once PAUSE_SHOWN is cleared)
.RESTORE_HUD
{
  LDX #0 ; Row 1, then row 2

.row_loop
  STX ZH_ADDR ; Row number (0 or 1)
  LDA HUD_ROWS,X
  JSR hud_row_blank

  ; "时间", unless the time is unlimited (bonus stages always have a limit)
  LDA GAME_TIME
  ORA INVULNERABLE
  BEQ no_time

  LDA #lo(ZH_HUD_TIME):STA ZH_PTR
  LDA #hi(ZH_HUD_TIME):STA ZH_PTR+1
  LDA ZH_ADDR
  JSR hud_row_record

.no_time
  ; "剩余", unless lives are unlimited
  LDA GAME_INF_LIVES
  BNE no_lives

  LDA #lo(ZH_HUD_LEFT):STA ZH_PTR
  LDA #hi(ZH_HUD_LEFT):STA ZH_PTR+1
  LDA ZH_ADDR
  JSR hud_row_record

.no_lives
  ; The score always ends in "00" (as TIME_AND_LIFE)
  LDA ZH_ADDR
  BEQ send

  LDA #'0'
  STA VBUF+3+18
  STA VBUF+3+19

.send
  JSR VBUF_SEND

  LDX ZH_ADDR
  INX
  CPX #2
  BNE row_loop

  RTS

.HUD_ROWS
  EQUB HUD_ROW1, HUD_ROW2
}

; =============== S U B R O U T I N E =======================================
; Start VBUF as one status bar row of blank tiles. A = low byte of the PPU
; address of the row (in nametable $2000).
.hud_row_blank
{
  STA VBUF+1
  LDA #&20:STA VBUF
  LDA #32:STA VBUF+2
  LDA #0:STA VBUF+3+32 ; End of buffer

  LDX #31
  LDA #':' ; Filled with the status bar colour

.loop
  STA VBUF+3,X
  DEX
  BPL loop

  RTS
}

; Copy one row of the string record at ZH_PTR (A = 0 top, 1 bottom) into the
; VBUF row at the record's own column
.hud_row_record
{
  STA ZH_TEMP2

  ; Column from the record's PPU address
  LDY #1
  LDA (ZH_PTR),Y
  AND #31
  TAX

  ; Width
  INY
  LDA (ZH_PTR),Y
  STA ZH_TEMP

  ; Top row tiles start at offset 3, bottom row ones follow
  LDA #3
  LDY ZH_TEMP2
  BEQ top_row
  CLC:ADC ZH_TEMP

.top_row
  TAY

.loop
  LDA (ZH_PTR),Y:STA VBUF+3,X
  INY
  INX
  DEC ZH_TEMP
  BNE loop

  RTS
}
