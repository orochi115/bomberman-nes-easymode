; ===========================================================================
; Options screen (replaces the password entry screen)
;
; 14 items in two columns of 7. Each item is drawn as two rows of 14 tiles:
;   column 0         cursor
;   OPT_LABEL_W      label (from text_data.asm: 4 for Chinese, 6 for English)
;   then a blank, the left arrow, OPT_VALUE_GAP blanks, the value (2 to 4
;   tiles), OPT_VALUE_GAP blanks and the right arrow (arrows and cursor only
;   on the selected item)
; Items follow the order of the OPT_* variables (OPT_STAGE .. OPT_INVINC).
; ===========================================================================

OPT_ROWS = 7     ; Items per column
OPT_ITEM_W = 14  ; Tiles per item row
OPT_BOTTOM = 3 + OPT_ITEM_W ; Offset of the bottom row entry in VBUF

; VBUF offsets of the parts of an item (top row)
OPT_POS_CURSOR = 3
OPT_POS_LABEL = 4
OPT_POS_LARROW = OPT_POS_LABEL + OPT_LABEL_W + 1
OPT_POS_VALUE = OPT_POS_LARROW + 1 + OPT_VALUE_GAP

OPT_REPEAT_DELAY = 20 ; Frames before a held direction repeats
OPT_REPEAT_RATE = 4   ; Frames between repeats

; PPU address of each item (top left)
MACRO OPT_ADDR row, col
  EQUW &2000 + row * 32 + col
ENDMACRO

.OPT_ITEM_ADDR
  OPT_ADDR 5, 2:OPT_ADDR 8, 2:OPT_ADDR 11, 2:OPT_ADDR 14, 2
  OPT_ADDR 17, 2:OPT_ADDR 20, 2:OPT_ADDR 23, 2
  OPT_ADDR 5, 17:OPT_ADDR 8, 17:OPT_ADDR 11, 17:OPT_ADDR 14, 17
  OPT_ADDR 17, 17:OPT_ADDR 20, 17:OPT_ADDR 23, 17

.OPT_LABEL
  EQUW ZH_OPT_STAGE, ZH_OPT_LIVES, ZH_OPT_POWER, ZH_OPT_BOMBS
  EQUW ZH_OPT_TIME, ZH_OPT_REVIVE, ZH_OPT_SLOW
  EQUW ZH_OPT_SPEED, ZH_OPT_REMOTE, ZH_OPT_NOCLIP, ZH_OPT_BOMBWALK
  EQUW ZH_OPT_FIRESUIT, ZH_OPT_DEBUG, ZH_OPT_INVINC

; =============== S U B R O U T I N E =======================================
; Show the options screen. Returns when START is pressed (the caller then
; starts a game with OPTS_APPLY); B returns to the title screen.
.OPTIONS_SCREEN
{
  JSR PPUD
  JSR VBLD
  JSR SETSTAGEPAL
  LDA #CHR_BANK_OPTS:JSR SET_CHR_BANK

  LDA #0
  STA STAGE_STARTED
  STA INMENU
  STA VBUF_READY

  ; Heading and hint
  LDA #lo(ZH_OPT_TITLE):LDX #hi(ZH_OPT_TITLE)
  JSR PRINT_ZH
  LDA #lo(ZH_OPT_HINT):LDX #hi(ZH_OPT_HINT)
  JSR PRINT_ZH

  ; All of the items (rendering is off, so write them directly)
  LDX #0

.draw_loop
  JSR OPT_COMPOSE
  JSR VBUF_FLUSH
  LDX OPT_ITEM
  INX
  CPX #NUM_OPTS
  BNE draw_loop

  JSR PPU_RESTORE
  JSR VBLE
  JSR PPUE

  JSR WAITUNPRESS
  LDA #0:STA OPT_PREV

.loop
  JSR NEXTFRAME

  ; Work out which buttons have just been pressed
  LDA JOYPAD1:STA OPT_PAD
  EOR OPT_PREV
  AND OPT_PAD
  STA OPT_NEW
  LDA OPT_PAD:STA OPT_PREV

  ; Auto repeat for held directions
  AND #(PAD_UP + PAD_DOWN + PAD_LEFT + PAD_RIGHT)
  BEQ handle

  LDA OPT_NEW
  AND #(PAD_UP + PAD_DOWN + PAD_LEFT + PAD_RIGHT)
  BEQ held

  LDA #OPT_REPEAT_DELAY:STA OPT_REPEAT
  BNE handle

.held
  DEC OPT_REPEAT
  BNE handle

  LDA #OPT_REPEAT_RATE:STA OPT_REPEAT
  LDA OPT_PAD
  AND #(PAD_UP + PAD_DOWN + PAD_LEFT + PAD_RIGHT)
  ORA OPT_NEW
  STA OPT_NEW

.handle
  LDA OPT_NEW
  AND #PAD_START
  BNE start

  LDA OPT_NEW
  AND #PAD_B
  BNE back

  LDA OPT_NEW
  AND #PAD_UP
  BNE up

  LDA OPT_NEW
  AND #PAD_DOWN
  BNE down

  LDA OPT_NEW
  AND #PAD_SELECT
  BNE other_column

  LDA OPT_NEW
  AND #PAD_LEFT
  BNE decrease

  LDA OPT_NEW
  AND #(PAD_RIGHT + PAD_A)
  BNE increase

  JMP loop

.start
  RTS

.back
  JSR WAITUNPRESS
  JMP TITLE_SCREEN

.up
  LDX OPT_CURSOR
  DEX
  BPL move_cursor
  LDX #NUM_OPTS-1
  BNE move_cursor

.down
  LDX OPT_CURSOR
  INX
  CPX #NUM_OPTS
  BNE move_cursor
  LDX #0
  BEQ move_cursor

.other_column
  LDA OPT_CURSOR
  CLC:ADC #OPT_ROWS
  CMP #NUM_OPTS
  BCC column_ok
  SBC #NUM_OPTS

.column_ok
  TAX

.move_cursor
  ; Make a sound (low tone)
  LDA #&12:STA APU_SQUARE1_REG+3

  LDA OPT_CURSOR:PHA
  STX OPT_CURSOR

  ; Redraw the old and new items
  PLA:TAX
  JSR OPT_REDRAW
  LDX OPT_CURSOR
  JSR OPT_REDRAW
  JMP loop

.decrease
  LDX OPT_CURSOR
  LDA OPT_STAGE,X
  CMP OPT_MIN,X
  BNE dec_ok
  LDA OPT_MAX,X ; Wrap round to the largest value
  CLC:ADC #1

.dec_ok
  SEC:SBC #1
  JMP value_changed

.increase
  LDX OPT_CURSOR
  LDA OPT_STAGE,X
  CMP OPT_MAX,X
  BNE inc_ok
  LDA OPT_MIN,X ; Wrap round to the smallest value
  SEC:SBC #1

.inc_ok
  CLC:ADC #1

.value_changed
  STA OPT_STAGE,X

  ; Make a sound (high tone)
  LDA #&11:STA APU_SQUARE1_REG+3

  JSR OPT_REDRAW
  JMP loop
}

; =============== S U B R O U T I N E =======================================
; Redraw item X while the screen is on (the NMI copies VBUF)
.OPT_REDRAW
{
  JSR OPT_COMPOSE
  JMP VBUF_SEND
}

; =============== S U B R O U T I N E =======================================
; Build the tiles for item X in VBUF
.OPT_COMPOSE
{
  STX OPT_ITEM

  ; Top row entry
  TXA:ASL A:TAY
  LDA OPT_ITEM_ADDR+1,Y:STA VBUF
  LDA OPT_ITEM_ADDR,Y:STA VBUF+1

  ; Bottom row entry, 32 bytes further on
  CLC:ADC #32
  STA VBUF+OPT_BOTTOM+1
  LDA VBUF
  ADC #0
  STA VBUF+OPT_BOTTOM

  LDA #OPT_ITEM_W
  STA VBUF+2
  STA VBUF+OPT_BOTTOM+2

  ; End of buffer
  LDA #0:STA VBUF+OPT_BOTTOM*2

  ; Start with all blank tiles
  LDX #OPT_ITEM_W-1
  LDA #BLANK_TILE

.blank_loop
  STA VBUF+3,X
  STA VBUF+OPT_BOTTOM+3,X
  DEX
  BPL blank_loop

  ; Label
  LDA OPT_LABEL,Y:STA ZH_PTR
  LDA OPT_LABEL+1,Y:STA ZH_PTR+1
  LDX #OPT_POS_LABEL
  JSR copy_record

  ; Value, sets OPT_W to its width in tiles
  JSR compose_value

  ; Cursor and arrows for the selected item
  LDA OPT_ITEM
  CMP OPT_CURSOR
  BNE done

  LDA #lo(ZH_OPT_CURSOR):STA ZH_PTR
  LDA #hi(ZH_OPT_CURSOR):STA ZH_PTR+1
  LDX #OPT_POS_CURSOR
  JSR copy_record

  LDA #lo(ZH_ARROW_R):STA ZH_PTR
  LDA #hi(ZH_ARROW_R):STA ZH_PTR+1
  LDA OPT_W
  CLC:ADC #OPT_POS_VALUE+OPT_VALUE_GAP
  TAX
  JSR copy_record

  LDA #lo(ZH_ARROW_L):STA ZH_PTR
  LDA #hi(ZH_ARROW_L):STA ZH_PTR+1
  LDX #OPT_POS_LARROW
  JMP copy_record

.done
  RTS

.compose_value
  LDX OPT_ITEM
  LDA OPT_KIND,X
  CMP #OPT_KIND_TIME
  BEQ time_value
  BCS bool_value
  CMP #OPT_KIND_LIVES
  BNE number_value

  ; Lives, a number or unlimited
  LDA OPT_STAGE,X
  CMP #OPT_LIVES_INF
  BEQ unlimited

.number_value
  ; Number, two digits with a leading blank
  LDA #2:STA OPT_W
  LDA OPT_STAGE,X
  JSR split_tens
  CPX #0
  BEQ no_tens
  TXA
  CLC:ADC #'0'
  STA VBUF+OPT_BOTTOM+OPT_POS_VALUE

.no_tens
  TYA
  CLC:ADC #'0'
  STA VBUF+OPT_BOTTOM+OPT_POS_VALUE+1

  RTS

.time_value
  LDX OPT_TIME
  LDA OPT_TIME_TAB,X
  BEQ unlimited

  ; Three digits (100 .. 250)
  LDX #3:STX OPT_W
  LDX #'0'-1
  SEC

.hundreds_loop
  INX
  SBC #100
  BCS hundreds_loop
  ADC #100
  STX VBUF+OPT_BOTTOM+OPT_POS_VALUE

  JSR split_tens
  TXA
  CLC:ADC #'0'
  STA VBUF+OPT_BOTTOM+OPT_POS_VALUE+1
  TYA
  CLC:ADC #'0'
  STA VBUF+OPT_BOTTOM+OPT_POS_VALUE+2

  RTS

.unlimited
  LDA #lo(ZH_VAL_INF):STA ZH_PTR
  LDA #hi(ZH_VAL_INF):STA ZH_PTR+1
  BNE value_record

.bool_value
  LDA OPT_STAGE,X
  BEQ no

  LDA #lo(ZH_VAL_YES):STA ZH_PTR
  LDA #hi(ZH_VAL_YES):STA ZH_PTR+1
  BNE value_record

.no
  LDA #lo(ZH_VAL_NO):STA ZH_PTR
  LDA #hi(ZH_VAL_NO):STA ZH_PTR+1

.value_record
  LDY #2
  LDA (ZH_PTR),Y:STA OPT_W
  LDX #OPT_POS_VALUE
  ; Fall through

; Copy the string record at ZH_PTR into VBUF at offset X (top row) and
; X + OPT_BOTTOM (bottom row)
.copy_record
  STX ZH_TEMP2
  STY ZH_TEMP

  ; Width, used as the counter for both rows
  LDY #2
  LDA (ZH_PTR),Y
  STA ZH_ADDR
  STA ZH_ADDR+1

  ; Top row tiles start at record offset 3
  LDY #3

.top_loop
  LDA (ZH_PTR),Y:STA VBUF,X
  INY
  INX
  DEC ZH_ADDR
  BNE top_loop

  ; Bottom row tiles follow straight on in the record
  LDA ZH_TEMP2
  CLC:ADC #OPT_BOTTOM
  TAX

.bottom_loop
  LDA (ZH_PTR),Y:STA VBUF,X
  INY
  INX
  DEC ZH_ADDR+1
  BNE bottom_loop

  LDY ZH_TEMP
  RTS

; A = value 0..99, returns X = tens, Y = units
.split_tens
  LDX #0
  SEC

.tens_loop
  SBC #10
  BCC tens_done
  INX
  BNE tens_loop

.tens_done
  ADC #10
  TAY
  RTS
}
