; Text engine of the mod (fixed bank). The data is made by tools/build_text.py:
; build/text_index.asm (tables below), build/text_bankN.asm (sets, records).
;
; A set holds the glyph tiles of one screen and the list of strings that
; ZH_SCREEN prints there. A string record is: PPU address hi, lo (0 = use
; ZH_ADDR), width, top row tiles, bottom row tiles.
;
; ZH_LOAD_SET   A = set     upload the set's tiles (rendering off)
; ZH_SCREEN     A = set     upload the tiles and print the set's strings
; ZH_QUEUE_SCREEN A = set   queue the set's strings (tiles already loaded)
; ZH_PRINT      A = string  write a record to the nametable (rendering off)
; ZH_QUEUE      A = string  queue a record as two PPU runs (rendering on)
; ZH_SPRITE     A = string  copy a sprite record to ZH_SPR_BUF (RAM), for
;                           DRAW_METASPRITE
; The caller's bank is mapped again before returning. X and Y are not kept.

; RAM: mod_vars.asm

; Map bank A, remembering the caller's bank
.ZH_ENTER
  STA ZH_BANK
  LDA CUR_BANK
  STA ZH_SAVED
  LDX ZH_BANK
  JMP BANK_SWITCH

.ZH_LEAVE
  LDX ZH_SAVED
  JMP BANK_SWITCH

; Point ZH_PTR at set A and map its bank
.ZH_SET_PTR
  TAX
  LDA ZH_SET_LO,X
  STA ZH_PTR
  LDA ZH_SET_HI,X
  STA ZH_PTR_HI
  LDA ZH_SET_BANK,X
  JMP ZH_ENTER

.ZH_QUEUE_SCREEN
  LDX #&01
  BNE zh_screen_strings

.ZH_SCREEN
  PHA
  JSR ZH_LOAD_SET
  PLA
  LDX #&00
.zh_screen_strings
  STX ZH_MODE
  JSR ZH_SET_PTR
  JSR ZH_SKIP_RUNS
  LDA (ZH_PTR),Y            ; number of strings
  STA ZH_CNT2
.zh_screen_loop
  LDA ZH_CNT2
  BEQ ZH_LEAVE
  INY
  LDA (ZH_PTR),Y
  STY ZH_TMP
  JSR zh_print_mapped
  ; zh_print_mapped may have used ZH_PTR: point it at the set again
  LDY ZH_TMP
  DEC ZH_CNT2
  JMP zh_screen_loop

; Y = offset of the print list in the set at ZH_PTR
.ZH_SKIP_RUNS
  LDY #&00
  LDA (ZH_PTR),Y
  STA ZH_CNT
  INY
.zh_skip
  LDA ZH_CNT
  BEQ zh_skip_done
  TYA
  CLC
  ADC #&05
  TAY
  DEC ZH_CNT
  JMP zh_skip
.zh_skip_done
  RTS

.ZH_LOAD_SET
  JSR ZH_SET_PTR
  LDY #&00
  LDA (ZH_PTR),Y
  STA ZH_CNT2
  INY
.zh_run
  LDA ZH_CNT2
  BEQ zh_load_done
  LDA PPU_STATUS
  LDA (ZH_PTR),Y
  STA PPU_ADDRESS
  INY
  LDA (ZH_PTR),Y
  STA PPU_ADDRESS
  INY
  LDA (ZH_PTR),Y            ; tiles
  STA ZH_CNT
  INY
  LDA (ZH_PTR),Y
  STA ZH_SRC
  INY
  LDA (ZH_PTR),Y
  STA ZH_SRC_HI
  INY
  STY ZH_TMP
.zh_tile
  LDY #&00
.zh_byte
  LDA (ZH_SRC),Y
  STA PPU_DATA
  INY
  CPY #&10
  BNE zh_byte
  LDA ZH_SRC
  CLC
  ADC #&10
  STA ZH_SRC
  BCC zh_tile_next
  INC ZH_SRC_HI
.zh_tile_next
  DEC ZH_CNT
  BNE zh_tile
  LDY ZH_TMP
  DEC ZH_CNT2
  JMP zh_run
.zh_load_done
  JMP ZH_LEAVE

; Point ZH_PTR at string A and map its bank
.ZH_STR_PTR
  TAX
  LDA ZH_STR_LO,X
  STA ZH_PTR
  LDA ZH_STR_HI,X
  STA ZH_PTR_HI
  LDA ZH_STR_BANK,X
  JMP ZH_ENTER

; Address of the record at ZH_PTR into DEST_PTR (ZH_ADDR when it is 0)
.ZH_REC_ADDR
  LDY #&00
  LDA (ZH_PTR),Y
  BNE zh_fixed
  LDA ZH_ADDR_HI
  STA DEST_PTR_HI
  LDA ZH_ADDR
  STA DEST_PTR
  JMP zh_width
.zh_fixed
  STA DEST_PTR_HI
  INY
  LDA (ZH_PTR),Y
  STA DEST_PTR
.zh_width
  LDY #&02
  LDA (ZH_PTR),Y
  AND #&7F
  STA ZH_W
  LDA (ZH_PTR),Y
  ASL A                     ; bit 7: a one-row record (attributes)
  LDA #&02
  BCC zh_rows
  LDA #&01
.zh_rows
  STA ZH_ROWS
  RTS

.ZH_PRINT
  JSR ZH_STR_PTR
  JSR zh_print_rec
  JMP ZH_LEAVE

; Print string A while some text bank is already mapped (ZH_SCREEN)
.zh_print_mapped
  PHA
  LDA ZH_PTR
  PHA
  LDA ZH_PTR_HI
  PHA
  LDA ZH_SAVED
  PHA
  LDA ZH_BANK
  PHA
  TSX
  LDA &0105,X
  JSR ZH_STR_PTR
  LDA ZH_MODE
  BNE zh_mapped_queue
  JSR zh_print_rec
  JMP zh_mapped_done
.zh_mapped_queue
  JSR zh_queue_rec
.zh_mapped_done
  PLA
  STA ZH_BANK
  TAX
  JSR BANK_SWITCH
  PLA
  STA ZH_SAVED
  PLA
  STA ZH_PTR_HI
  PLA
  STA ZH_PTR
  PLA
  RTS

.zh_print_rec
  JSR ZH_REC_ADDR
  LDY #&03
  LDX #&00                  ; row
.zh_row
  LDA PPU_STATUS
  LDA DEST_PTR_HI
  STA PPU_ADDRESS
  LDA DEST_PTR
  STA PPU_ADDRESS
  LDA ZH_W
  STA ZH_CNT
  BEQ zh_print_done
.zh_col
  LDA (ZH_PTR),Y
  STA PPU_DATA
  INY
  DEC ZH_CNT
  BNE zh_col
  INX
  CPX ZH_ROWS
  BCS zh_print_done
  LDA DEST_PTR
  CLC
  ADC #&20
  STA DEST_PTR
  BCC zh_row
  INC DEST_PTR_HI
  JMP zh_row
.zh_print_done
  RTS

; Queue string A as two PPU runs (QUEUE_PPU_RUN copies the bytes at once)
.ZH_QUEUE
  JSR ZH_STR_PTR
  JSR zh_queue_rec
  JMP ZH_LEAVE

.zh_queue_rec
  JSR ZH_REC_ADDR
  LDA #&00
  STA PPU_RUN_CTRL
  LDA ZH_W
  BEQ zh_queue_done
  CLC
  LDA ZH_PTR
  ADC #&03
  STA DATA_PTR
  LDA ZH_PTR_HI
  ADC #&00
  STA DATA_PTR_HI
  LDX ZH_W
  JSR QUEUE_PPU_RUN
  LDA ZH_ROWS
  LSR A
  BEQ zh_queue_done
  LDA DEST_PTR
  CLC
  ADC #&20
  STA DEST_PTR
  BCC zh_queue_bottom
  INC DEST_PTR_HI
.zh_queue_bottom
  LDA DATA_PTR
  CLC
  ADC ZH_W
  STA DATA_PTR
  BCC zh_queue_run
  INC DATA_PTR_HI
.zh_queue_run
  LDX ZH_W
  JMP QUEUE_PPU_RUN
.zh_queue_done
  RTS

; Copy sprite string A (count, then 4 bytes per sprite) to ZH_SPR_BUF, or
; to the RAM at ZH_SRC (ZH_SPRITE_TO)
.ZH_SPRITE
  LDX #LO(ZH_SPR_BUF)
  STX ZH_SRC
  LDX #HI(ZH_SPR_BUF)
  STX ZH_SRC_HI
.ZH_SPRITE_TO
  JSR ZH_STR_PTR
  LDY #&00
  LDA (ZH_PTR),Y
  ASL A
  ASL A
  TAX                       ; bytes after the count
  INX
.zh_spr_copy
  LDA (ZH_PTR),Y
  STA (ZH_SRC),Y
  INY
  DEX
  BNE zh_spr_copy
  JMP ZH_LEAVE

; WRAM copies of the round result sprites: player 1-3 win, draw, time out
.ZH_ROUND_PTRS
  FOR i, 0, 4
    EQUW ZH_ROUND_SPR + i * &40
  NEXT

INCLUDE "build/text_index.asm"
