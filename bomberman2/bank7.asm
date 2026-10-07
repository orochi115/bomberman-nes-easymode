; ---------------------------------------------------------------------------
; PRG bank 7 ($C000-$FFFF)
; ---------------------------------------------------------------------------

  PAD SHIFT                               ; relocation test, see make.sh

; Switch to PRG bank X on the NMI-safe path, then return.
; In: X = bank. Updates CUR_BANK and the MMC1 PRG register.
.SWITCH_BANK
  JMP BANK_SWITCH_NMI

; Power-on entry. Disable IRQ, clear decimal, set the stack, then warm up the PPU,
; black the palette, reset MMC1, clear RAM, reset video and enter GAME_LOOP.
.RESET
  SEI
  CLD
  LDX #&FF
  TXS
  JSR PPU_WARMUP
  JSR FILL_PAL_BLACK
  JSR INIT_MAPPER
  JSR CLEAR_LOW_RAM
IF MOD
  FARCALL 7, OPTS_INIT
ENDIF
  JSR RESET_VIDEO
  JSR NMI_ON
  JMP GAME_LOOP

; Increment NMI_CNT. If OAM_READY, DMA sprites. Upload the palette or else drain the PPU queue.
; When SPLIT_MODE is set, wait for sprite 0 and apply the split scroll; 80h also sets the PPU address to 2660h.
; Then the normal scroll. If OAM_READY, clear the sprite buffer. On the first NMI after a clear of NMI_CNT, read the pads.
; Once per frame, if SND_NMI_LOCK is 0, tick the bank-2 sound routine. Increments FRAME_CNT.
.NMI
  PHA
  TXA
  PHA
  TYA
  PHA
  LDA NMI_CNT
  INC NMI_CNT
  LDA OAM_READY
  BEQ L7_C02D
  JSR OAM_DMA
.L7_C02D
  JSR UPLOAD_PALETTE
  BCS L7_C035
  JSR DRAIN_PPU_Q
.L7_C035
  JSR PPU_BUS_FIX
  LDA SPLIT_MODE
  BEQ L7_C06F
  LDA PPU_CTRL_BUF
  AND #&FE
  ORA SPLIT_CTRL_BIT
  STA PPU_CTRL_REG1
  LDA SPLIT_SCROLL_X
  STA PPU_SCROLL_REG
  LDA SCROLL_Y
  STA PPU_SCROLL_REG
.L7_C052
  BIT PPU_STATUS
  BVS L7_C052
.L7_C057
  BIT PPU_STATUS
  BVC L7_C057
  LDX #&80
.L7_C05E
  DEX
  BNE L7_C05E
  LDA SPLIT_MODE
  BPL L7_C06F
  LDA #&26
  STA PPU_ADDRESS
  LDA #&60
  STA PPU_ADDRESS
.L7_C06F
  JSR APPLY_SCROLL
  LDA OAM_READY
  BEQ L7_C079
  JSR CLEAR_OAM
.L7_C079
  LDA NMI_CNT
  CMP #&01
  BNE L7_C082
  JSR READ_JOYPADS
.L7_C082
  INC FRAME_CNT
  LDA SND_NMI_LOCK
  BNE L7_C0A5
  INC SND_NMI_LOCK
  LDA CUR_BANK
  PHA
  LDX #&02
  JSR BANK_SWITCH_NMI
  JSR SND_FRAME_ENTRY
  PLA
  TAX
  JSR BANK_SWITCH_NMI
  LDA #&00
  STA SND_NMI_LOCK
  JMP L7_C0A6

; (not seen executing during the coverage runs)
.L7_C0A5
  NOP
.L7_C0A6
  PLA
  TAY
  PLA
  TAX
  PLA

.IRQ
  RTI

; Wait for two vblanks, then store PPU CTRL 10h and mask 0 in the shadows and the registers.
; NMI is left disabled. Called from RESET.
.PPU_WARMUP
  LDA #&10
  STA PPU_CTRL_REG1
  STA PPU_CTRL_BUF
  LDA #&00
  STA PPU_CTRL_REG2
  STA PPU_MASK_BUF
  LDX #&02
.L7_C0BC
  BIT PPU_STATUS
  BPL L7_C0BC
.L7_C0C1
  LDA PPU_STATUS
  BMI L7_C0C1
  DEX
  BNE L7_C0BC
  RTS

; Call bank 5 at AC8A and AC54, then zero 00h-FBh and pages 0200h-0700h.
; FC-FF on the zero page are left alone.
.CLEAR_LOW_RAM
  FARCALL 5, CLEAR_STAGE_SCORE
  FARCALL 5, SEED_DEFAULT_SCORE
  LDA #&00
  LDX #&00
.L7_C0DA
  CPX #&FC
  BCS L7_C0E0
  STA WORK_PTR,X
.L7_C0E0
  STA W_0200,X
  STA PAL_BUF,X
  STA W_0500,X
  STA PPU_QUEUE,X
  STA OAM_Y,X
  INX
  BNE L7_C0DA
  RTS

; Reset MMC1, clear the saved bank and CUR_BANK, and map bank 0 at SPAWN_STAGE_ENEMIES.
.INIT_MAPPER
  LDA #&00
  STA MMC1_GUARD
  JSR MMC1_RESET
  LDX #&00
  STX CUR_BANK
  STX SAVED_BANK
  JMP BANK_SWITCH

; Write the MMC1 reset sequence: control 0Eh (16K PRG at 8000h, fixed SWITCH_BANK), CHR banks 0.
; Does not select the PRG bank.
.MMC1_RESET
  LDA #&FF
  STA MMC1_CONTROL
  LDA #&0E
  STA MMC1_CONTROL
  LSR A
  STA MMC1_CONTROL
  LSR A
  STA MMC1_CONTROL
  LSR A
  STA MMC1_CONTROL
  LSR A
  STA MMC1_CONTROL
  LDA #&00
  STA MMC1_CHR0
  LSR A
  STA MMC1_CHR0
  LSR A
  STA MMC1_CHR0
  LSR A
  STA MMC1_CHR0
  LSR A
  STA MMC1_CHR0
  LDA #&00
  STA MMC1_CHR1
  LSR A
  STA MMC1_CHR1
  LSR A
  STA MMC1_CHR1
  LSR A
  STA MMC1_CHR1
  LSR A
  STA MMC1_CHR1
  RTS
.BANK_SAVE_SWITCH
  EQUB &AD,&00,&01,&85,&1A

.BANK_SWITCH
  STX CUR_BANK
.L7_C151
  LDA #&01
  STA MMC1_GUARD
  TXA
  STA MMC1_PRG
  LSR A
  STA MMC1_PRG
  LSR A
  STA MMC1_PRG
  LSR A
  STA MMC1_PRG
  LSR A
  STA MMC1_PRG
  LDA MMC1_GUARD
  CMP #&01
  BEQ L7_C1B6
  LDA #&FF
  STA MMC1_CONTROL
  LDA #&0E
  STA MMC1_CONTROL
  LSR A
  STA MMC1_CONTROL
  LSR A
  STA MMC1_CONTROL
  LSR A
  STA MMC1_CONTROL
  LSR A
  STA MMC1_CONTROL
  LDA #&00
  STA MMC1_CHR0
  LSR A
  STA MMC1_CHR0
  LSR A
  STA MMC1_CHR0
  LSR A
  STA MMC1_CHR0
  LSR A
  STA MMC1_CHR0
  LDA #&00
  STA MMC1_CHR1
  LSR A
  STA MMC1_CHR1
  LSR A
  STA MMC1_CHR1
  LSR A
  STA MMC1_CHR1
  LSR A
  STA MMC1_CHR1
  JMP L7_C151
.L7_C1B6
  DEC MMC1_GUARD
  RTS

.BANK_SWITCH_NMI
  STX CUR_BANK
  LDA MMC1_GUARD
  BEQ L7_C206
  INC MMC1_GUARD
  LDA #&FF
  STA MMC1_CONTROL
  LDA #&0E
  STA MMC1_CONTROL
  LSR A
  STA MMC1_CONTROL
  LSR A
  STA MMC1_CONTROL
  LSR A
  STA MMC1_CONTROL
  LSR A
  STA MMC1_CONTROL
  LDA #&00
  STA MMC1_CHR0
  LSR A
  STA MMC1_CHR0
  LSR A
  STA MMC1_CHR0
  LSR A
  STA MMC1_CHR0
  LSR A
  STA MMC1_CHR0
  LDA #&00
  STA MMC1_CHR1
  LSR A
  STA MMC1_CHR1
  LSR A
  STA MMC1_CHR1
  LSR A
  STA MMC1_CHR1
  LSR A
  STA MMC1_CHR1
.L7_C206
  TXA
  STA MMC1_PRG
  LSR A
  STA MMC1_PRG
  LSR A
  STA MMC1_PRG
  LSR A
  STA MMC1_PRG
  LSR A
  STA MMC1_PRG
  RTS
.BANK_RESTORE
  EQUB &A6,&1A,&4C
  EQUW BANK_SWITCH

; Clear scroll, split mode and the NMI counter. PPU CTRL shadow 10h, mask shadow 1Eh.
; Clear OAM, mark it ready, clear the palette-dirty flag, and jump to START_AUDIO.
.RESET_VIDEO
  LDA #&00
  STA SPLIT_SCROLL_X
  STA SPLIT_CTRL_BIT
  STA SCROLL_X
  STA SCROLL_NT
  STA SCROLL_Y
  LDA #&10
  STA PPU_CTRL_BUF
  LDA #&1E
  STA PPU_MASK_BUF
  LDA #&00
  STA OAM_READY
  STA PPU_ENABLED
  STA NMI_CNT
  STA PPU_Q_WR
  STA PPU_Q_RD
  LDA #&00
  STA SPLIT_MODE
  JSR CLEAR_OAM
  LDA #&01
  STA OAM_READY
  LDA #&00
  STA PAL_DIRTY
  JSR START_AUDIO
  RTS

; Zero SPLIT_SCROLL_X, SPLIT_CTRL_BIT, SCROLL_X, SCROLL_NT and SCROLL_Y.
.CLEAR_SCROLL
  LDA #&00
  STA SCROLL_X
  STA SCROLL_NT
  STA SCROLL_Y
  STA SPLIT_SCROLL_X
  STA SPLIT_CTRL_BIT
  RTS

; Wait until PPUSTATUS leaves vblank, then until it enters vblank again.
.WAIT_VBLANK
  LDA PPU_STATUS
  BMI WAIT_VBLANK
.L7_C271
  LDA PPU_STATUS
  BPL L7_C271
  RTS

; Clear NMI_CNT and return after the next NMI increments it.
.WAIT_NMI
  LDA #&00
  STA NMI_CNT
.L7_C27B
  LDA NMI_CNT
  BEQ L7_C27B
  RTS

; Return after FRAME_CNT changes. Spins, so it must be called with NMI enabled.
.WAIT_FRAME
  LDA FRAME_CNT
.L7_C282
  CMP FRAME_CNT
  BEQ L7_C282
  RTS

; Write SCROLL_X, SCROLL_Y and PPU CTRL (shadow ORed with bit 0 of SCROLL_NT) to the PPU.
.APPLY_SCROLL
  LDA SCROLL_X
  STA PPU_SCROLL_REG
  LDA SCROLL_Y
  STA PPU_SCROLL_REG
  LDA SCROLL_NT
  AND #&01
  ORA PPU_CTRL_BUF
  STA PPU_CTRL_REG1
  RTS

; Wait until the PPU queue is empty, then in vblank DMA sprites, upload PAL_BUF,
; apply scroll, set the mask to 1Eh and enable NMI. Sets PPU_ENABLED.
.PPU_ON
  JSR WAIT_PPU_Q
  JSR NMI_OFF
  JSR WAIT_VBLANK
  JSR OAM_DMA
  JSR PPU_BUS_FIX
  JSR APPLY_SCROLL
  LDA #&1E
  STA PPU_CTRL_REG2
  STA PPU_MASK_BUF
  LDA #&01
  STA PPU_ENABLED
  JMP NMI_ON

; Set bit 7 of the PPU CTRL shadow and write it to the register.
.NMI_ON
  LDA PPU_CTRL_BUF
  ORA #&80
  STA PPU_CTRL_REG1
  STA PPU_CTRL_BUF
  RTS

; Wait for an empty PPU queue, clear the split and the OAM buffer, then blank the mask.
; Clears PPU_ENABLED and calls AUDIO_CMD_80. Waits one frame on either side.
.PPU_OFF
  JSR WAIT_PPU_Q
  LDA #&00
  STA SPLIT_MODE
  JSR CLEAR_OAM
  JSR WAIT_FRAME
  LDA #&00
  STA PPU_CTRL_REG2
  STA PPU_MASK_BUF
  LDA #&00
  STA PPU_ENABLED
  JSR AUDIO_CMD_80
  JSR WAIT_FRAME
  RTS

; Clear bit 7 of the PPU CTRL shadow and write it to the register.
.NMI_OFF
  LDA PPU_CTRL_BUF
  AND #&7F
  STA PPU_CTRL_REG1
  STA PPU_CTRL_BUF
  RTS

; Enable the sprite-0 split with sprite 0 at Y=10h (SPLIT_MODE=1).
; Turns NMI off, waits a frame, turns NMI on. Out: A=0.
.SET_TOP_SPLIT
  LDA #&01
  STA SPLIT_MODE
  LDA #&10
  STA SPRITE0_Y
.L7_C2F9
  JSR NMI_OFF
  JSR WAIT_VBLANK
  JSR CLEAR_OAM
  JSR OAM_DMA
  JSR WAIT_VBLANK
  JMP NMI_ON

; Enable the sprite-0 split with sprite 0 at Y=90h (SPLIT_MODE=80h).
; Same NMI off/on bracket as SET_TOP_SPLIT.
.SET_LOW_SPLIT
  LDA #&80
  STA SPLIT_MODE
  LDA #&90
  STA SPRITE0_Y
  JMP L7_C2F9

; DMA the page-7 OAM buffer to the PPU. Clobbers A.
.OAM_DMA
  LDA #&00
  STA PPU_SPR_ADDR
  LDA #&07
  STA PPU_SPR_DMA
  RTS

; Hide every sprite (Y=F8h) and clear OAM_READY. If SPLIT_MODE is set, sprite 0 is
; rewritten from SPRITE0_Y with tile 3F and attribute 20h. OAM_INDEX becomes 0 or 4.
.CLEAR_OAM
  LDA #&00
  STA OAM_INDEX
  STA OAM_READY
  LDX #&3C
  LDA #&F8
.L7_C32B
  STA OAM_Y,X
  STA OAM_PAGE1,X
  STA OAM_PAGE2,X
  STA OAM_PAGE3,X
  DEX
  DEX
  DEX
  DEX
  BPL L7_C32B
  LDA SPLIT_MODE
  BEQ L7_C359
  LDA SPRITE0_Y
  STA OAM_Y
  LDA #&01
  STA OAM_TILE
  LDA #&23
  STA OAM_ATTR
  LDA #&00
  STA OAM_X
  LDA #&04
  STA OAM_INDEX
.L7_C359
  RTS

; Set OAM_READY so the next NMI will DMA the sprite buffer and then clear it.
.MARK_OAM
  LDA #&01
  STA OAM_READY
  RTS

; Point the PPU address at 3F00h and then at 0000h so a later render does not show a palette glitch.
.PPU_BUS_FIX
  LDA #&3F
  STA PPU_ADDRESS
  LDA #&00
  STA PPU_ADDRESS
  STA PPU_ADDRESS
  STA PPU_ADDRESS
  RTS

; Read the controllers once per NMI.
; US: probe for signature 10h/20h. On a match use READ_JOY_ALT and set JOY_SIG_OK, else READ_JOY_STD.
; A second sample that differs is discarded and the previous frame is kept.
; Fills JOYPAD1-3, the _NEW and _OLD bytes, JOY_HELD and JOY_NEW.

; JP: strobe with 01 and fall into READ_JOY_STD / US: clear JOY_SIG_OK, probe for 10h and 20h, then READ_JOY_ALT or READ_JOY_STD. US READ_JOY_STD returns before the _NEW merge. JP merges inside the same routine.
.READ_JOYPADS
  LDA JOYPAD1
  STA JOYPAD1_OLD
  LDA JOYPAD2
  STA JOYPAD2_OLD
  LDA JOYPAD3
  STA JOYPAD3_OLD
IF REGION = 2
  JSR READ_JOY_PROBE
  BNE L7_C393
  JSR READ_JOY_ALT
  JMP L7_C3DC
.L7_C393
  JSR READ_JOY_STD
  JMP L7_C3DC

.READ_JOY_STD
  LDA #&01
ELIF REGION_JP
  LDA #&01
ELSE
  LDA #&00
  STA JOY_SIG_OK
  JSR READ_JOY_PROBE
  BNE L7_C393

; (not seen executing during the coverage runs)
  INC JOY_SIG_OK
  JSR READ_JOY_ALT
  JMP L7_C3DC
.L7_C393
  JSR READ_JOY_STD
  JMP L7_C3DC

; Strobe the pads and shift in 8 bits twice.
; First pass: port1 bit0 -> JOYPAD1, port1 bit1 -> JOYPAD3, port2 bit0 -> JOYPAD2.
; Second pass: the same bits into JOYPAD1_2ND, JOYPAD3_2ND, JOYPAD2_2ND.
; On US this is the fallback when the probe misses. On JP it is the whole read, and it also builds the _NEW and OR bytes.
.READ_JOY_STD
  LDA #&01
ENDIF
  STA JOYPAD_PORT1
  LDA #&00
  STA JOYPAD_PORT1
  LDX #&08
.L7_C3A5
  LDA JOYPAD_PORT1
  LSR A
  ROL JOYPAD1
  LSR A
  ROL JOYPAD3
  LDA JOYPAD_PORT2
  LSR A
  ROL JOYPAD2
  DEX
  BNE L7_C3A5
  LDA #&01
  STA JOYPAD_PORT1
  LDA #&00
  STA JOYPAD_PORT1
  LDX #&08
.L7_C3C6
  LDA JOYPAD_PORT1
  LSR A
  ROL JOYPAD1_2ND
  LSR A
  ROL JOYPAD3_2ND
  LDA JOYPAD_PORT2
  LSR A
  ROL JOYPAD2_2ND
  DEX
  BNE L7_C3C6
IF REGION_JP
ELSE
  RTS
ENDIF
.L7_C3DC
  LDA JOYPAD1
  CMP JOYPAD1_2ND
  BEQ L7_C3EA

; (not seen executing during the coverage runs)
  LDX JOYPAD1_OLD
  STX JOYPAD1
.L7_C3EA
  LDA JOYPAD2
  CMP JOYPAD2_2ND
  BEQ L7_C3F8

; (not seen executing during the coverage runs)
  LDX JOYPAD2_OLD
  STX JOYPAD2
.L7_C3F8
  LDA JOYPAD3
  CMP JOYPAD3_2ND
  BEQ L7_C406

; (not seen executing during the coverage runs)
  LDX JOYPAD3_OLD
  STX JOYPAD3
.L7_C406
  LDX #&02
.L7_C408
  LDA JOYPAD1,X
  EOR JOYPAD1_OLD,X
  AND JOYPAD1,X
  STA JOYPAD1_NEW,X
  DEX
  BPL L7_C408
  LDA JOYPAD1
  ORA JOYPAD2
  ORA JOYPAD3
  STA JOY_HELD
  LDA JOYPAD1_NEW
  ORA JOYPAD2_NEW
  ORA JOYPAD3_NEW
  STA JOY_NEW
  RTS
IF REGION = 2

.READ_JOY_PROBE
  LDX #&01
  STX JOYPAD_PORT1
  DEX
  STX JOYPAD_PORT1
  LDY #&08
.L7_C43B
  LDA JOYPAD_PORT1
  AND #&03
  CMP #&01
  ROL JOYPAD1
  LDA JOYPAD_PORT2
  AND #&03
  CMP #&01
  ROL JOYPAD2
  DEY
  BNE L7_C43B
  LDY #&08
.L7_C454
  LDA JOYPAD_PORT1
  LSR A
  ROL JOYPAD3
  LDA JOYPAD_PORT2
  DEY
  BNE L7_C454
  LDY #&08
.L7_C463
  LDA JOYPAD_PORT1
  LSR A
  ROL JOY_PROBE_1
  LDA JOYPAD_PORT2
  LSR A
  ROL JOY_PROBE_2
  DEY
  BNE L7_C463
  LDA JOY_PROBE_1
  CMP #&10
  BNE L7_C47C
  LDA JOY_PROBE_2
  CMP #&20
.L7_C47C
  RTS

.READ_JOY_ALT
  LDX #&01
  STX JOYPAD_PORT1
  DEX
  STX JOYPAD_PORT1
  LDY #&08
.L7_C488
  LDA JOYPAD_PORT1
  AND #&03
  CMP #&01
  ROL JOYPAD1_2ND
  LDA JOYPAD_PORT2
  AND #&03
  CMP #&01
  ROL JOYPAD2_2ND
  DEY
  BNE L7_C488
  LDY #&08
.L7_C4A1
  LDA JOYPAD_PORT1
  LSR A
  ROL JOYPAD3_2ND
  DEY
  BNE L7_C4A1
  RTS
ELIF REGION_JP
ELSE

; US only. Read pads with the AND-3 CMP-1 test, then shift 8 more bits into JOY_PROBE_1 and JOY_PROBE_2.
; Returns Z set when the probe bytes are 10h and 20h. The mode menu rejects GAME_MODE=2 while JOY_SIG_OK stays 0.
.READ_JOY_PROBE
  LDX #&01
  STX JOYPAD_PORT1
  DEX
  STX JOYPAD_PORT1
  LDY #&08
.L7_C43B
  LDA JOYPAD_PORT1
  AND #&03
  CMP #&01
  ROL JOYPAD1
  LDA JOYPAD_PORT2
  AND #&03
  CMP #&01
  ROL JOYPAD2
  DEY
  BNE L7_C43B
  LDY #&08
.L7_C454
  LDA JOYPAD_PORT1
  LSR A
  ROL JOYPAD3
  LDA JOYPAD_PORT2
  DEY
  BNE L7_C454
  LDY #&08
.L7_C463
  LDA JOYPAD_PORT1
  LSR A
  ROL JOY_PROBE_1
  LDA JOYPAD_PORT2
  LSR A
  ROL JOY_PROBE_2
  DEY
  BNE L7_C463
  LDA JOY_PROBE_1
  CMP #&10
  BNE L7_C47C

; (not seen executing during the coverage runs)
  LDA JOY_PROBE_2
  CMP #&20
.L7_C47C
  RTS

; (not seen executing during the coverage runs)

; US only. Second pad read, used when READ_JOY_PROBE matches.
; Same AND-3 test into the _2ND bytes, then 8 bits of port1 bit0 into JOYPAD3_2ND.
.READ_JOY_ALT
  LDX #&01
  STX JOYPAD_PORT1
  DEX
  STX JOYPAD_PORT1
  LDY #&08
.L7_C488
  LDA JOYPAD_PORT1
  AND #&03
  CMP #&01
  ROL JOYPAD1_2ND
  LDA JOYPAD_PORT2
  AND #&03
  CMP #&01
  ROL JOYPAD2_2ND
  DEY
  BNE L7_C488
  LDY #&08
.L7_C4A1
  LDA JOYPAD_PORT1
  LSR A
  ROL JOYPAD3_2ND
  DEY
  BNE L7_C4A1
  RTS
ENDIF

; Fill nametable 2000h with A (8 pages), then zero the 128 bytes at 0420h (ATTR_BUF).
; In: A = tile. Clobbers X and Y.
.FILL_NAMETABLE
  PHA
  LDA #&20
  STA PPU_ADDRESS
  LDA #&00
  STA PPU_ADDRESS
  PLA
  LDY #&08
  LDX #&00
.L7_C4BC
  STA PPU_DATA
  DEX
  BNE L7_C4BC
  DEY
  BNE L7_C4BC
  JMP L7_C514

; Write 40h zeros to attribute tables 23C0h and 27C0h.
.CLEAR_ATTRS
  LDA #&C0
  LDX #&23
  JSR SET_PPU_ADDR
  LDA #&00
  LDX #&40
  JSR PPU_FILL
  LDA #&C0
  LDX #&27
  JSR SET_PPU_ADDR
  LDA #&00
  LDX #&40

; Write A to PPUDATA, X times. In: A = byte, X = count (1-256, 0 means 256).
.PPU_FILL
  STA PPU_DATA
  DEX
  BNE PPU_FILL
  RTS

; Copy X groups of 4 bytes from (16h) into PAL_BUF at index A*4.
; In: A = palette row, X = row count, 16h/17h = source.
.COPY_PAL_ROWS
  ASL A
  ASL A
  CLC
  ADC #&00
  STA DATA_PTR
  LDA #&04
  ADC #&00
  STA DATA_PTR_HI
  LDY #&00
.L7_C4F7
  LDA (PAL_SRC),Y
  STA (DATA_PTR),Y
  INY
  LDA (PAL_SRC),Y
  STA (DATA_PTR),Y
  INY
  LDA (PAL_SRC),Y
  STA (DATA_PTR),Y
  INY
  LDA (PAL_SRC),Y
  STA (DATA_PTR),Y
  INY
  DEX
  BNE L7_C4F7
  RTS

; Set PAL_DIRTY so the next NMI uploads PAL_BUF.
.MARK_PALETTE
  LDA #&01
  STA PAL_DIRTY
  RTS
.L7_C514
  LDX #&7F
  LDA #&00
.L7_C518
  STA ATTR_BUF,X
  DEX
  BPL L7_C518
  RTS

; Play sound command 85h, then darken PAL_BUF one step at a time.
; Each non-0F byte loses 10h from its high nibble, otherwise it becomes 0Fh.
; Marks the palette dirty and waits 5 NMIs per step until every byte is 0Fh.
.FADE_PALETTE
  JSR AUDIO_CMD_85
.L7_C522
  LDX #&00
  STX TEMP1
.L7_C526
  LDA PAL_BUF,X
  CMP #&0F
  BEQ L7_C540
  TAY
  AND #&30
  BNE L7_C537
  LDA #&0F
  JMP L7_C53B
.L7_C537
  TYA
  SEC
  SBC #&10
.L7_C53B
  STA PAL_BUF,X
  INC TEMP1
.L7_C540
  INX
  CPX #&20
  BCC L7_C526
  LDA #&01
  STA PAL_DIRTY
  LDX #&05
.L7_C54B
  JSR WAIT_NMI
  DEX
  BNE L7_C54B
  LDA TEMP1
  BNE L7_C522
  RTS

; Fill all 32 palette bytes with 0Fh and upload them to 3F00h immediately.
.FILL_PAL_BLACK
  LDA #&0F
  LDX #&00
.L7_C55A
  STA PAL_BUF,X
  INX
  CPX #&20
  BCC L7_C55A
  BCS L7_C568

; If PAL_DIRTY is set, write PAL_BUF to PPU 3F00h and clear the flag.
; Out: C=1 if an upload ran (NMI then skips the PPU queue), C=0 if it did not.
.UPLOAD_PALETTE
  LDA PAL_DIRTY
  BEQ L7_C581
.L7_C568
  LDA #&3F
  STA PPU_ADDRESS
  LDA #&00
  STA PPU_ADDRESS
  STA PAL_DIRTY
  TAY
.L7_C575
  LDA PAL_BUF,Y
  STA PPU_DATA
  INY
  CPY #&20
  BCC L7_C575
  RTS
.L7_C581
  CLC
  RTS

; Set the PPU address to X*100h+A. In: X = high, A = low.
.SET_PPU_ADDR
  STX PPU_ADDRESS
  STA PPU_ADDRESS
  RTS

; Switch to bank X and decode Y tiles of 16 bytes to the PPU address in 22h/23h.
; Source is (20h). Each tile is two calls to DECODE_CHR. Restores the previous bank.
; In: X = bank, Y = tile count, 20h = source, 22h = PPU address.
.UPLOAD_CHR_RLE
  LDA CUR_BANK
  PHA
.L7_C58E
  JSR BANK_SWITCH
  STY TEMP3
  LDA DEST_PTR_HI
  STA PPU_ADDRESS
  LDA DEST_PTR
  STA PPU_ADDRESS
.L7_C59D
  JSR DECODE_CHR
  JSR DECODE_CHR
  DEC TEMP3
  BNE L7_C59D
  PLA
  TAX
  JMP BANK_SWITCH

; Switch to bank X and copy Y*16 raw bytes from (20h) to PPU address 22h/23h.
; Restores the previous bank. Used by the bank-5 tile upload at UPLOAD_LEVEL_CHR.
.UPLOAD_CHR_RAW
  LDA CUR_BANK
  PHA
  JSR BANK_SWITCH
  STY TEMP3
  LDA DEST_PTR_HI
  STA PPU_ADDRESS
  LDA DEST_PTR
  STA PPU_ADDRESS
.L7_C5BF
  LDY #&00
.L7_C5C1
  LDA (DATA_PTR),Y
  STA PPU_DATA
  INY
  CPY #&10
  BCC L7_C5C1
  TYA
  CLC
  ADC DATA_PTR
  STA DATA_PTR
  LDA DATA_PTR_HI
  ADC #&00
  STA DATA_PTR_HI
  DEC TEMP3
  BNE L7_C5BF
  PLA
  TAX
  JMP BANK_SWITCH

; Decode 8 pixels of one CHR bitplane from (20h) into 1Eh.
; A 0 bit repeats the previous byte; a 1 bit reads a new byte. Bits live in 1Dh.
; The upload that starts at bank 1 ENDING_SPR_CHR reads past that bank into SWITCH_BANK-S7_C122 of this fixed bank. That is original behavior (see shift_ignore).
.DECODE_CHR
  LDX #&08
  LDY #&00
  LDA (DATA_PTR),Y
  INY
  STA TEMP2
  LDA #&00
  STA TEMP1
.L7_C5ED
  ASL TEMP2
  BCC L7_C5F6
  LDA (DATA_PTR),Y
  INY
  STA TEMP1
.L7_C5F6
  STA PPU_DATA
  DEX
  BNE L7_C5ED
  TYA
  CLC
  ADC DATA_PTR
  STA DATA_PTR
  LDA DATA_PTR_HI
  ADC #&00
  STA DATA_PTR_HI
  RTS

; Drain up to 8 records from PPU_QUEUE.
; A record whose first byte is nonzero is [flags][hi][lo][count][bytes]. Bit 7 of flags sets the PPU increment-32 mode.
; A record whose first byte is 0 is a 2x2 tile plus one attribute byte (9 bytes total).
.DRAIN_PPU_Q
  LDA #&08
  STA PPU_Q_LEFT
  JMP L7_C6AE
.L7_C611
  LDA PPU_QUEUE,X
  AND #&7F
  BEQ L7_C64D
  LDA PPU_CTRL_BUF
  AND #&FB
  TAY
.L7_C61D
  LDA PPU_QUEUE,X
  BPL L7_C626

; (not seen executing during the coverage runs)
  INY
  INY
  INY
  INY
.L7_C626
  STY PPU_CTRL_REG1
  INX
  LDA PPU_QUEUE,X
  STA PPU_ADDRESS
  INX
  LDA PPU_QUEUE,X
  STA PPU_ADDRESS
  INX
  LDA PPU_QUEUE,X
  TAY
.L7_C63C
  INX
  LDA PPU_QUEUE,X
  STA PPU_DATA
  DEY
  BNE L7_C63C
  INX
  STX PPU_Q_RD
  JMP L7_C6A9
.L7_C64D
  LDA PPU_CTRL_BUF
  AND #&FB
  STA PPU_CTRL_REG1
  INX
  LDA PPU_QUEUE,X
  STA PPU_ADDRESS
  STA PPU_Q_HI
  INX
  LDA PPU_QUEUE,X
  STA PPU_ADDRESS
  PHA
  INX
  LDA PPU_QUEUE,X
  STA PPU_DATA
  INX
  LDA PPU_QUEUE,X
  STA PPU_DATA
  LDA PPU_Q_HI
  STA PPU_ADDRESS
  PLA
  CLC
  ADC #&20
  STA PPU_ADDRESS
  INX
  LDA PPU_QUEUE,X
  STA PPU_DATA
  INX
  LDA PPU_QUEUE,X
  STA PPU_DATA
  LDA PPU_Q_HI
  ORA #&03
  STA PPU_ADDRESS
  INX
  LDA PPU_QUEUE,X
  STA PPU_ADDRESS
  INX
  LDA PPU_QUEUE,X
  STA PPU_DATA
  INX
  STX PPU_Q_RD
.L7_C6A9
  DEC PPU_Q_LEFT
  BEQ L7_C6B9
.L7_C6AE
  LDX PPU_Q_RD
  CPX PPU_Q_WR
  BEQ L7_C6B9
  JMP L7_C611
.L7_C6B9
  RTS

; Queue one 2x2 tile and its attribute nibble. Spins until 10 queue bytes are free.
; Uses 04A9h-04B4h as the address, tiles and masks. Updates ATTR_BUF.
; In: those work bytes already filled by QUEUE_MAP_TILE.
.QUEUE_TILE
  LDA #&0A
  JSR PPU_Q_HAS_ROOM
  BCC QUEUE_TILE
  LDX PPU_Q_WR
  LDY TILE_PAL
  LDA ATTR_PAL_BYTE,Y
  STA TILE_PAL
  LDY #&20
  LDA TILE_COL
  CMP #&10
  BCC L7_C6DD
  AND #&0F
  STA TILE_COL
  LDY #&24
.L7_C6DD
  STY NT_ADDR_HI
  TYA
  ASL A
  ASL A
  ASL A
  ASL A
  STA PPU_WORK
  LDA TILE_ROW
  AND #&0F
  STA TILE_ROW
  LSR A
  ROR A
  PHA
  AND #&03
  ORA NT_ADDR_HI
  STA NT_ADDR_HI
  PLA
  ROR A
  AND #&C0
  CLC
  ADC TILE_COL
  ADC TILE_COL
  STA NT_ADDR_LO
  LDA TILE_ROW
  ASL A
  ASL A
  AND #&38
  ORA PPU_WORK
  STA PPU_WORK
  LDA TILE_COL
  LSR A
  ROL TILE_ROW
  AND #&07
  ORA PPU_WORK
  STA PPU_WORK
  LDA TILE_ROW
  AND #&03
  TAY
  LDA ATTR_QUAD_MASK,Y
  STA ATTR_KEEP
  EOR #&FF
  STA ATTR_NEW
  LDA #&00
  STA PPU_QUEUE,X
  LDA NT_ADDR_HI
  INX
  STA PPU_QUEUE,X
  LDA NT_ADDR_LO
  INX
  STA PPU_QUEUE,X
  LDA TILE_CHR0
  INX
  STA PPU_QUEUE,X
  LDA TILE_CHR1
  INX
  STA PPU_QUEUE,X
  LDA TILE_CHR2
  INX
  STA PPU_QUEUE,X
  LDA TILE_CHR3
  INX
  STA PPU_QUEUE,X
  LDA PPU_WORK
  TAY
  ORA #&C0
  INX
  STA PPU_QUEUE,X
  LDA ATTR_BUF,Y
  AND ATTR_KEEP
  STA ATTR_KEEP
  LDA TILE_PAL
  AND ATTR_NEW
  ORA ATTR_KEEP
  INX
  STA PPU_QUEUE,X
  STA ATTR_BUF,Y
  INX
  STX PPU_Q_WR
  RTS

; Four attribute masks, one per 2x2 quadrant inside an attribute byte: FC F3 CF 3F.
.ATTR_QUAD_MASK
  EQUB &FC,&F3,&CF,&3F

; Palette index 0-3 expanded to a full attribute byte: 00 55 AA FF.
; QUEUE_TILE indexes this with the map nibble, which is therefore 0-3.
.ATTR_PAL_BYTE
  EQUB &00,&55,&AA,&FF

; Tile column X and row Y to a nametable address in 22h/23h.
; X below 20h uses nametable 2000h; otherwise the column wraps and the base is 2400h.
; In: X, Y. Out: 22h = address. Clobbers A.
.XY_TO_NT_ADDR
  LDA #&20
  CPX #&20
  BCC L7_C7A2
  TXA
  SEC
  SBC #&20
  TAX
  LDA #&24
.L7_C7A2
  STA DEST_PTR_HI
  LDA #&00
  STA DEST_PTR
  TYA
  LSR A
  ROR DEST_PTR
  LSR A
  ROR DEST_PTR
  LSR A
  ROR DEST_PTR
  CLC
  ADC DEST_PTR_HI
  STA DEST_PTR_HI
  TXA
  CLC
  ADC DEST_PTR
  STA DEST_PTR
  LDA DEST_PTR_HI
  ADC #&00
  STA DEST_PTR_HI
  RTS

; Tile column X and row Y to an attribute address.
; Out: 23h = high (23h or 27h), 22h = low ORed with C0h, 1Ch = offset inside the attribute byte group.
; Wraps X at 20h and Y at 1Eh onto the second screen.
.XY_TO_ATTR
  LDA #&23
  STA DEST_PTR_HI
  LDA #&00
  STA TEMP1
  CPX #&20
  BCC L7_C7DC
  TXA
  AND #&1F
  TAX
  LDA #&27
  STA DEST_PTR_HI
  LDA #&40
  STA TEMP1
.L7_C7DC
  CPY #&1E
  BCC L7_C7ED

; (not seen executing during the coverage runs)
  TYA
  SEC
  SBC #&1E
  TAY
  LDA #&27
  STA DEST_PTR_HI
  LDA #&40
  STA TEMP1
.L7_C7ED
  TYA
  AND #&FC
  ASL A
  STA TEMP2
  TXA
  LSR A
  LSR A
  CLC
  ADC TEMP2
  ORA TEMP1
  STA TEMP1
  ORA #&C0
  STA DEST_PTR
  RTS

; Queue a raw PPU run. Spins until 25h bytes are free, then writes
; [2Eh ORed with 01h][23h][22h][count][count bytes from (20h)].
; In: X = count, 22h/23h = PPU address, 20h = source, 2Eh = flag byte (bit 7 selects vertical increment).
.QUEUE_PPU_RUN
  LDA #&25
  JSR PPU_Q_HAS_ROOM
  BCC QUEUE_PPU_RUN
  STX TEMP1
  LDX PPU_Q_WR
  LDA PPU_RUN_CTRL
  ORA #&01
  STA PPU_QUEUE,X
  INX
  LDA DEST_PTR_HI
  STA PPU_QUEUE,X
  INX
  LDA DEST_PTR
  STA PPU_QUEUE,X
  INX
  LDA TEMP1
  STA PPU_QUEUE,X
  INX
  LDY #&00
.L7_C82A
  LDA (DATA_PTR),Y
  STA PPU_QUEUE,X
  INY
  INX
  DEC TEMP1
  BNE L7_C82A
  STX PPU_Q_WR
  RTS

; Test whether the PPU queue can take A more bytes.
; Out: C=1 if the gap from PPU_Q_WR to PPU_Q_RD is large enough. A gap of 0 is treated as empty, so C=1.
.PPU_Q_HAS_ROOM
  STA PPU_WORK
  LDA PPU_Q_RD
  SEC
  SBC PPU_Q_WR
  BEQ L7_C848
  CMP PPU_WORK
.L7_C848
  RTS

; Spin until PPU_Q_WR equals PPU_Q_RD. NMI must be enabled.
.WAIT_PPU_Q
  LDA PPU_Q_WR
  CMP PPU_Q_RD
  BNE WAIT_PPU_Q
  RTS

.FAR_CALL
  STA FAR_A
  STX FAR_X
  STY FAR_Y
  PLA
  STA FAR_RET
  PLA
  STA FAR_RET_HI
  TAX
  LDA FAR_RET
  CLC
  ADC #&03
  STA FAR_TMP
  BCC L7_C869

; (not seen executing during the coverage runs)
  INX
.L7_C869
  TXA
  PHA
  LDA FAR_TMP
  PHA
  LDA CUR_BANK
  PHA
  LDY #&03
  LDA (FAR_RET),Y
  STA FAR_TMP_HI
  DEY
  LDA (FAR_RET),Y
  STA FAR_TMP
  DEY
  LDA (FAR_RET),Y
  TAX
  JSR BANK_SWITCH
  LDA #HI(L7_C897-1)
  PHA
  LDA #LO(L7_C897-1)
  PHA
  LDA FAR_TMP_HI
  PHA
  LDA FAR_TMP
  PHA
  LDA FAR_A
  LDX FAR_X
  LDY FAR_Y
  RTS
.L7_C897
  STX FAR_X2
  PLA
  TAX
  JSR BANK_SWITCH
  LDX FAR_X2
  RTS

; Step the 3-byte RNG in RNG_1..RNG_3.
; Out: A = RNG_3. The bytes after the RTS are never executed.
.NEXT_RNG
  INC RNG_1
  DEC RNG_2
  BNE L7_C8AE
  LDA #&75
  STA RNG_2
.L7_C8AE
  LDA RNG_1
  CMP #&77
  BNE L7_C8BA
  LDA #&01
  STA RNG_1
.L7_C8BA
  EOR RNG_2
  ASL A
  PHP
  LSR A
  PLP
  ROL A
  ASL A
  PHP
  LSR A
  PLP
  ROL A
  EOR RNG_3
  SEC
  SBC RNG_2
  CLC
  ADC RNG_1
  CLC
  ADC RNG_1
  STA RNG_3
  RTS

; (not seen executing during the coverage runs)
  LDA #&00
  STA RNG_1
  STA RNG_2
  STA RNG_3
  RTS

; Clear SND_NMI_LOCK, map bank 2, and jump to SND_INIT. Does not return.
.START_AUDIO
  LDA #&00
  STA SND_NMI_LOCK
  LDX #&02
  JSR BANK_SWITCH
  JMP SND_RESET_ENTRY

; Load A with 80h and fall into AUDIO_CALL. Used when the PPU is turned off.
.AUDIO_CMD_80
  LDA #&80

; Call the bank-2 sound routine at SND_REQUEST_ENTRY (which jumps to L2_806Dh).
; In: A = command, X = argument. Out: A and X from that routine. Restores the previous bank.
.AUDIO_CALL
  STA SND_RET_A
  STX SND_RET_X
  LDA CUR_BANK
  PHA
  LDX #&02
  JSR BANK_SWITCH
  LDA SND_RET_A
  LDX SND_RET_X
  JSR SND_REQUEST_ENTRY
  STA SND_RET_A
  STX SND_RET_X
  PLA
  TAX
  JSR BANK_SWITCH
  LDA SND_RET_A
  LDX SND_RET_X
  RTS

; AUDIO_CALL with A=85h and X=80h. Called once at the start of FADE_PALETTE.
.AUDIO_CMD_85
  LDA #&85
  LDX #&80
  FARCALL 2, SND_REQUEST_ENTRY
  RTS

; (not seen executing during the coverage runs)
  LDA CUR_BANK
  PHA
  LDX #&02
  JSR BANK_SWITCH
  LDA #&86
  JSR SND_REQUEST_ENTRY
  STX SND_RET_A
  PLA
  TAX
  JSR BANK_SWITCH
  LDX SND_RET_A
  CPX #&0C
  RTS

; Reset entry after the cold init. Clears the demo flag, runs the opening, then the menu.
; From here the loop boots a stage, plays STAGE_LOOP, and branches on clear, death, demo or bonus.
.GAME_LOOP
  JSR CLEAR_DEMO_FLAG
  JSR RUN_OPENING

; Front end. SHOW_FRONT, then if the demo flag is set jump into STAGE_BOOT.
; Otherwise RUN_MODE_MENU. MENU_REDRAW repeats this loop. MENU_MODE1 goes to ENTER_Z49_1.
; MENU_BONUS goes to ENTER_W0550.
.MENU_LOOP
IF MOD
  JSR MOD_CLEAR_RULES
ENDIF
  JSR SHOW_FRONT
  LDA DEMO_MODE
  BNE STAGE_BOOT
.L7_C954
  JSR RUN_MODE_MENU
  LDA MENU_REDRAW
  BNE MENU_LOOP
  LDA MENU_MODE1
  BEQ L7_C964

; (not seen executing during the coverage runs)
  JMP ENTER_Z49_1
.L7_C964
  LDA MENU_BONUS
  BEQ L7_C96C

; (not seen executing during the coverage runs)
  JMP ENTER_W0550
.L7_C96C
  LDA #&FF
  STA INTRO_AREA

; Re-enter a mode without the title. Clears 8 bytes at 03D0h, calls SET_WIN_COUNT, then STAGE_BOOT.
; Reached when KEEP_STAGE is set after a versus result or the game-over screen.
.RESUME_MODE
  FARCALL 5, CLEAR_STAGE_SCORE
  JSR SET_WIN_COUNT

; Blank the screen and set lives (04E5h) to 2. If KEEP_STAGE is set, keep the current area and stage.
; If START_AREA is negative, all areas are done. Otherwise it becomes the area and the stage is 0.
.STAGE_BOOT
  JSR PPU_OFF
  JSR WAIT_FRAME
IF MOD
  JSR MOD_START_LIVES
ELSE
  LDA #&02
ENDIF
  STA LIVES
  LDA KEEP_STAGE
  BNE STAGE_SETUP
  LDA START_AREA
  BPL NEW_AREA

; (not seen executing during the coverage runs)
  JMP ALL_CLEAR

; Copy START_AREA into the area, zero the stage, call bank 5 at CLEAR_SCORE_RAM (zeros 055Eh-0560h) and RESET_PLAYERS.
.NEW_AREA
  STA AREA_NUM
  LDA #&00
  STA STAGE_NUM
  FARCALL 5, CLEAR_SCORE_RAM
  JSR RESET_PLAYERS
  LDA #&FF
  STA VS_PICTURE

; Build one stage: area card, mode setup, clear nametables, CHR, palettes, enemies.
; Enables the PPU, the top split and the area BGM, then falls into STAGE_LOOP.
.STAGE_SETUP
IF MOD
  JSR MOD_SNAPSHOT
.stage_setup_body
ENDIF
  JSR MAYBE_AREA_CARD
  JSR SETUP_BY_MODE
  JSR NMI_OFF
  JSR CLEAR_BOMB_RAM
  LDA #&00
  JSR FILL_NAMETABLE
  JSR CLEAR_ATTRS
  JSR CLEAR_BLAST_RAM
  JSR FILL_MAP_FF
  JSR INIT_PLAYERS
  JSR RESET_ENEMY_RAM
  JSR LOAD_STAGE_GFX
  JSR WAIT_VBLANK
  JSR NMI_ON
  JSR BIND_AREA_PTRS
  JSR LOAD_STAGE_META
  FARCALL 5, INIT_STAGE_CLOCK
  FARCALL 5, DRAW_STAGE_CLOCK
  FARCALL 5, DRAW_MODE_HUD
  LDA #&00
  ABS_STA CLEAR_PHASE
  STA STAGE_PHASE
  JSR PPU_ON
  JSR SET_TOP_SPLIT
  JSR MARK_PALETTE
  JSR PLAY_AREA_BGM

; One in-stage frame: wait for NMI, pause, players, blasts, enemies, then several bank-5 calls.
; CLEAR_PHASE at or above F0h leaves the stage. STAGE_PHASE counts up to F0h and then takes the death path.
; Otherwise MARK_OAM and repeat.
.STAGE_LOOP
  JSR WAIT_NMI
  JSR UPDATE_PAUSE
  JSR UPDATE_PLAYERS
  JSR UPDATE_BLASTS
  JSR UPDATE_ENEMIES
  FARCALL 5, TICK_STAGE_CLOCK
  FARCALL 5, DRAW_LIVES
  FARCALL 5, DRAW_HUD_SCORE
  ABS_LDA CLEAR_PHASE
  CMP #&F0
  BCS STAGE_WON
  LDX STAGE_PHASE
  BEQ L7_CA2B
  INX
  STX STAGE_PHASE
  CPX #&F0
  BCS STAGE_LOST
.L7_CA2B
  JSR MARK_OAM
  JMP STAGE_LOOP

; Stage exit after a fade. Demo returns through DEMO_EXIT. Nonzero EXIT_OPEN goes to PREP_STAGE_B4.
; Otherwise advance the stage, and the area after stage 8. Area 6 goes to ALL_CLEAR.
.STAGE_WON
  JSR FADE_PALETTE
  JSR PPU_OFF
  LDA DEMO_MODE
  BEQ L7_CA3F
  JMP DEMO_EXIT

; (not seen executing during the coverage runs)
.L7_CA3F
  ABS_LDA EXIT_OPEN
  BEQ L7_CA47
  JMP PREP_STAGE_B4
.L7_CA47
  INC STAGE_NUM
  LDA STAGE_NUM
  CMP #&08
  BCC L7_CA61
  LDA #&00
  STA STAGE_NUM
  INC AREA_NUM
  LDA AREA_NUM
  CMP #&06
  BCC L7_CA61

; Area index reached 6. Call RUN_ENDING and then RESET.
.ALL_CLEAR
  JSR RUN_ENDING
  JMP RESET
.L7_CA61
  JMP STAGE_SETUP

; Fade out after STAGE_PHASE hit F0h. In a versus mode, score the round and maybe show the result.
; In story mode, decrement lives. Negative lives run the game-over screen. Otherwise reload the stage.
.STAGE_LOST
  JSR FADE_PALETTE
  JSR PPU_OFF
  LDA DEMO_MODE
  BNE DEMO_EXIT
  LDX GAME_MODE
  BEQ L7_CAC4
  LDY #&FF
.L7_CA75
  LDA ACTOR_FLAG,X
  BEQ L7_CA7F

; (not seen executing during the coverage runs)
  LDA ACTOR_DEATH,X
  BNE L7_CA7F
  TXA
  TAY
.L7_CA7F
  DEX
  BPL L7_CA75
  STY VS_PICTURE
  CPY #&FF
  BEQ L7_CAC1

; (not seen executing during the coverage runs)
  LDA MATCH_0,Y
  CLC
  ADC #&01
  STA MATCH_0,Y
  CMP #&0A
  BCS L7_CAB0
  CMP WINS_GOAL
  BCC L7_CAC1
  LDA GAME_MODE
  CMP #&02
  BEQ L7_CAB0
  TYA
  EOR #&01
  TAX
  LDA MATCH_0,Y
  SEC
  SBC MATCH_0,X
  CMP #&02
  BCC L7_CAC1
.L7_CAB0
  JSR SHOW_VS_RESULT
  LDA KEEP_STAGE
  BNE L7_CABA
  JMP GAME_LOOP
.L7_CABA
  LDA #&00
  STA KEEP_STAGE
  JMP RESUME_MODE
.L7_CAC1
  JMP STAGE_SETUP
.L7_CAC4
IF MOD
  LDA GAME_INF_LIVES
  BEQ lives_count
  JMP STAGE_SETUP           ; unlimited lives
.lives_count
ENDIF
  DEC LIVES
  BMI L7_CACC
  JMP STAGE_SETUP
.L7_CACC
IF MOD
  LDA GAME_REVIVE
  BEQ game_over
  JSR MOD_RESTORE           ; revive mode: the stage again, as it was entered
  JMP stage_setup_body
.game_over
ENDIF
  JSR RUN_GAME_OVER
  LDA KEEP_STAGE
  BNE L7_CAD6
  JMP GAME_LOOP
.L7_CAD6
  JMP RESUME_MODE

; Return from a demo stage. If the demo flag is negative, go back to the menu path at S7_C954.
; If the demo index is 3, restart at GAME_LOOP. Otherwise repeat MENU_LOOP.
.DEMO_EXIT
  LDA DEMO_MODE
  BPL L7_CAE1

; (not seen executing during the coverage runs)
  JMP L7_C954
.L7_CAE1
  LDA DEMO_SLOT
  CMP #&03
  BNE L7_CAEB

; (not seen executing during the coverage runs)
  JMP GAME_LOOP
.L7_CAEB
  JMP MENU_LOOP

; If GAME_MODE is 0, play AREA_BGM_ID indexed by the area. Otherwise play sound 14h.
.PLAY_AREA_BGM
  LDA GAME_MODE
  BNE L7_CAFA
  LDX AREA_NUM
  LDA AREA_BGM_ID,X
  JMP AUDIO_CALL
.L7_CAFA
  LDA #&14
  JMP AUDIO_CALL

; Six sound ids, one per area 0-5: 0E 0F 0E 0F 0E 10. Read by PLAY_AREA_BGM.
.AREA_BGM_ID
  EQUB &0E,&0F,&0E,&0F,&0E,&10

; (not seen executing during the coverage runs)

; EXIT_OPEN was nonzero after a clear. FARCALL bank 5 at RUN_BONUS_STAGE, which saves the area and stage,
; forces stage 7, ACTOR_BOMBS=8, ACTOR_FIRE=5 and SPECIAL_STAGE=1, then returns to STAGE_WON.
.PREP_STAGE_B4
  FARCALL 5, RUN_BONUS_STAGE
  JMP STAGE_WON

; Load area CHR and the sprite palettes, then return from the tail at S7_CB14.
; CB14h also copies 16 bytes of area palette data from bank 4 and mirrors the background color.
.LOAD_STAGE_GFX
  JSR LOAD_AREA_CHR
IF ZH
  LDA #ZH_SET_HUD
  JSR ZH_LOAD_SET
  LDA GAME_MODE
  BEQ zh_gfx_done
  ; VS / battle: round result sprites, copied to WRAM for UPDATE_ROUND
  LDA #ZH_SET_ROUND
  JSR ZH_LOAD_SET
  LDY #&00
.zh_round_copy
  LDA ZH_ROUND_PTRS,Y
  STA ZH_SRC
  LDA ZH_ROUND_PTRS+1,Y
  STA ZH_SRC_HI
  TYA
  PHA
  LSR A
  CLC
  ADC #ZH_RD_WIN1
  JSR ZH_SPRITE_TO
  PLA
  TAY
  INY
  INY
  CPY #&0A
  BCC zh_round_copy
.zh_gfx_done
ENDIF
  JMP L7_CB14
.L7_CB14
  LDA CUR_BANK
  PHA
  LDX #&04
  JSR BANK_SWITCH
  LDA AREA_NUM
  ASL A
  ASL A
  ASL A
  ASL A
  CLC
  ADC #LO(AREA_BG_PAL)
  STA PAL_SRC
  LDA #&00
  ADC #HI(AREA_BG_PAL)
  STA PAL_SRC_HI
  LDA #&00
  LDX #&04
  JSR COPY_PAL_ROWS
  LDA #LO(SPR_PAL_STORY)
  STA PAL_SRC
  LDA #HI(SPR_PAL_STORY)
  STA PAL_SRC_HI
  LDA GAME_MODE
  BEQ L7_CB49
  LDA #LO(SPR_PAL_OTHER)
  STA PAL_SRC
  LDA #HI(SPR_PAL_OTHER)
  STA PAL_SRC_HI
.L7_CB49
  LDA #&04
  LDX #&04
  JSR COPY_PAL_ROWS
  JSR MIRROR_BG_COLOR
  PLA
  TAX
  JSR BANK_SWITCH
  RTS

; Copy PAL_BUF byte 0 onto the background color of the other seven 4-byte rows.
.MIRROR_BG_COLOR
  LDA PAL_BUF
  STA PAL_BG1
  STA PAL_BG2
  STA PAL_BG3
  STA PAL_BG4
  STA PAL_BG5
  STA PAL_BG6
  STA PAL_BG7
  RTS

; 16 sprite-palette bytes (4 rows) copied to PAL_BUF row 4 when GAME_MODE is 0.
.SPR_PAL_STORY
  EQUB &0F,&20,&01,&06,&0F,&0D,&26,&20,&0F,&0F,&2A,&20,&0F,&0F,&21,&20

; 16 sprite-palette bytes copied to PAL_BUF row 4 when GAME_MODE is not 0.
.SPR_PAL_OTHER
  EQUB &0F,&0F,&27,&11,&0F,&0F,&26,&30,&0F,&0F,&26,&16,&0F,&0F,&21,&20

; Upload fixed CHR from bank 6 at PLAY_SPR_CHR (80h tiles to PPU 1000h),
; area CHR from AREA_CHR_PTR (60h tiles to 1A00h), and enemy CHR from bank 1.
; Area 5 picks the enemy set with AREA5_CHR_IDX[stage]; other areas use the area index.
; Enemy tiles go to PPU 0C00h, 40h tiles. Does not restore the bank itself; the caller does.
.LOAD_AREA_CHR
  LDA #LO(PLAY_SPR_CHR)
  STA DATA_PTR
  LDA #HI(PLAY_SPR_CHR)
  STA DATA_PTR_HI
  LDA #&00
  STA DEST_PTR
  LDA #&10
  STA DEST_PTR_HI
  LDX #&06
  LDY #&80
  JSR UPLOAD_CHR_RLE
  JSR LOAD_4_TILES
  LDA AREA_NUM
  ASL A
  TAX
  LDA AREA_CHR_PTR,X
  STA DATA_PTR
  LDA D7_CC0F,X
  STA DATA_PTR_HI
  LDA #&00
  STA DEST_PTR
  LDA #&1A
  STA DEST_PTR_HI
  LDX #&06
  LDY #&60
  JSR UPLOAD_CHR_RLE
  LDA #LO(PLAY_BG_CHR)
  STA DATA_PTR
  LDA #HI(PLAY_BG_CHR)
  STA DATA_PTR_HI
  LDA #&00
  STA DEST_PTR
  LDA #&00
  STA DEST_PTR_HI
  LDX #&01
  LDY #&C0
  JSR UPLOAD_CHR_RLE
  LDA AREA_NUM
  CMP #&05
  BNE L7_CBEB
  LDX STAGE_NUM
  LDA AREA5_CHR_IDX,X
.L7_CBEB
  ASL A
  TAX
  LDA ENEMY_CHR_PTR,X
  STA DATA_PTR
  LDA D7_CC1D,X
  STA DATA_PTR_HI
  LDA #&00
  STA DEST_PTR
  LDA #&0C
  STA DEST_PTR_HI
  LDX #&01
  LDY #&40
  JMP UPLOAD_CHR_RLE

; Eight indexes, one per stage, selecting an ENEMY_CHR_PTR entry when the area is 5.
.AREA5_CHR_IDX
  EQUB &00,&01,&02,&03,&04,&00,&03,&00

; Six pointers to area CHR in bank 6. First pointer is split lo/hi; the rest are words.
; LOAD_AREA_CHR uploads 60h tiles from the selected pointer.
.AREA_CHR_PTR
  EQUB LO(AREA0_SPR_CHR)
.D7_CC0F
  EQUB HI(AREA0_SPR_CHR)
  EQUW AREA1_SPR_CHR
  EQUW AREA2_SPR_CHR
  EQUW AREA3_SPR_CHR
  EQUW AREA4_SPR_CHR
  EQUW AREA5_SPR_CHR
  EQUW VS_BATTLE_SPR_CHR

; Seven pointers to enemy CHR in bank 1. Indexed by area, or by AREA5_CHR_IDX in area 5.
; 40h tiles are uploaded to PPU 0C00h. Entry 5 is the same address as entry 4.
.ENEMY_CHR_PTR
  EQUB LO(ENEMY_AREA0_CHR)
.D7_CC1D
  EQUB HI(ENEMY_AREA0_CHR)
  EQUW ENEMY_AREA1_CHR
  EQUW ENEMY_AREA2_CHR
  EQUW ENEMY_AREA3_CHR
  EQUW ENEMY_AREA4_CHR
  EQUW ENEMY_AREA4_CHR
  EQUW ENEMY_VS_CHR

; If Start is newly pressed and no death or clear is running, slide SPLIT_SCROLL_X by 8 until FCh
; and draw PAUSE_TEXT. Start again restores the scroll and returns.
; While the demo flag is set, Start or A sets that flag to FFh and STAGE_PHASE to F0h so the demo exits.
.UPDATE_PAUSE
  LDA DEMO_MODE
  BNE L7_CCA1
  ABS_LDA CLEAR_PHASE
  ORA STAGE_PHASE
  ORA ROUND_RES
  BNE L7_CCA0
  LDA JOY_NEW
  AND #&10
  BEQ L7_CCA0

; (not seen executing during the coverage runs)
  LDA #&06
  JSR AUDIO_CALL
  LDA #&83
  LDX #&00
  JSR AUDIO_CALL
  STX PAUSE_X
IF ZH
  LDA #ZH_HUD_PAUSE
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
.L7_CC67
  JSR WAIT_NMI
  LDA JOY_NEW
  AND #&10
  BNE L7_CC8B
  LDA SPLIT_SCROLL_X
  CMP #&FC
  BCS L7_CC67
  LDA SPLIT_SCROLL_X
  CLC
  ADC #&08
  STA SPLIT_SCROLL_X
  BNE L7_CC67
  LDA #&FC
  STA SPLIT_SCROLL_X
  JMP L7_CC67
.L7_CC8B
  LDA #&06
  JSR AUDIO_CALL
  LDX PAUSE_X
  LDA #&83
  JSR AUDIO_CALL
  LDA #&00
  STA SPLIT_SCROLL_X
  STA SPLIT_CTRL_BIT
.L7_CCA0
  RTS
.L7_CCA1
  LDA JOY_NEW
  AND #&90
  BEQ L7_CCA0

; (not seen executing during the coverage runs)
  LDA #&FF
  STA DEMO_MODE
  LDA #&F0
  STA STAGE_PHASE
  RTS

; Five ASCII bytes "PAUSE", queued by UPDATE_PAUSE. The US pointer is PAUSE_TEXT; the JP build uses the same bytes at its own address.
.PAUSE_TEXT
  EQUB &50,&41,&55,&53,&45

; (not seen executing during the coverage runs)

; MENU_MODE1 was nonzero. FARCALL bank 5 at RUN_MODE1_MENU, which sets GAME_MODE to 1 and runs its own frame loop.
; That call does not return; the following jump back to GAME_LOOP is not reached.
.ENTER_Z49_1
  FARCALL 5, RUN_MODE1_MENU
IF MOD
  JMP L7_C954               ; SELECT + START leave the sound room
ELSE
  JMP GAME_LOOP
ENDIF

; MENU_BONUS was nonzero. Set lives to 1, clear 8 bytes at 03D0h, FARCALL bank 5 at RUN_BONUS_STAGE,
; fade out, blank the PPU and jump to GAME_LOOP.
.ENTER_W0550
  LDA #&01
  STA LIVES
  FARCALL 5, CLEAR_STAGE_SCORE
  FARCALL 5, RUN_BONUS_STAGE
  JSR FADE_PALETTE
  JSR PPU_OFF
IF MOD
  JMP L7_C954               ; back to the mode menu
ELSE
  JMP GAME_LOOP
ENDIF

; Draw a metasprite into the OAM buffer at OAM_INDEX.
; 54h/55h = data. First byte is the number of 4-byte groups (tile, dx, dy, attr), then FF-terminated runs.
; 56h/57h = X, 58h/59h = Y, 5Ah = flip bits. X is reduced by SCROLL_X and Y by SCROLL_Y before the draw.
.DRAW_METASPRITE
  DEC SPR_Y
  LDA SPR_Y
  CMP #&FF
  BNE L7_CCE4

; (not seen executing during the coverage runs)
  DEC SPR_Y_HI
.L7_CCE4
  LDY #&00
  LDA (SPR_PTR),Y
  STA SPR_COUNT
.L7_CCEA
  INY
  LDA (SPR_PTR),Y
  STA SPR_TILE
  LDA SPR_FLIP
  AND #&40
  BEQ L7_CD00
  INY
  LDA (SPR_PTR),Y
  EOR #&FF
  SEC
  SBC #&07
  JMP L7_CD03
.L7_CD00
  INY
  LDA (SPR_PTR),Y
.L7_CD03
  BPL L7_CD13
  CLC
  ADC SPR_X
  STA SPR_DX
  LDA #&FF
  ADC SPR_X_HI
  STA SPR_DX_HI
  JMP L7_CD1E
.L7_CD13
  CLC
  ADC SPR_X
  STA SPR_DX
  LDA SPR_X_HI
  ADC #&00
  STA SPR_DX_HI
.L7_CD1E
  LDA SPR_FLIP
  AND #&80
  BEQ L7_CD2F

; (not seen executing during the coverage runs)
  INY
  LDA (SPR_PTR),Y
  EOR #&FF
  SEC
  SBC #&07
  JMP L7_CD32
.L7_CD2F
  INY
  LDA (SPR_PTR),Y
.L7_CD32
  BPL L7_CD42
  CLC
  ADC SPR_Y
  STA SPR_DY
  LDA #&FF
  ADC SPR_Y_HI
  STA SPR_DY_HI
  JMP L7_CD4D
.L7_CD42
  CLC
  ADC SPR_Y
  STA SPR_DY
  LDA SPR_Y_HI
  ADC #&00
  STA SPR_DY_HI
.L7_CD4D
  INY
  LDA (SPR_PTR),Y
  EOR SPR_FLIP
  STA SPR_ATTR
  LDA SPR_DX
  SEC
  SBC SCROLL_X
  STA SPR_DX
  LDA SPR_DX_HI
  SBC SCROLL_NT
  BNE L7_CD81
  LDA OAM_INDEX
  TAX
  CLC
  ADC #&04
  BEQ L7_CD88
  STA OAM_INDEX
  LDA SPR_DX
  STA OAM_X,X
  LDA SPR_DY
  STA OAM_Y,X
  LDA SPR_TILE
  STA OAM_TILE,X
  LDA SPR_ATTR
  STA OAM_ATTR,X
.L7_CD81
  DEC SPR_COUNT
  BEQ L7_CD88
  JMP L7_CCEA
.L7_CD88
  RTS
.L7_CD89
  FARCALL 4, DECODE_LAYOUT
  RTS

; FARCALL bank 4 at LOAD_AREA_LAYOUT. That routine sets 62h/64h/66h from tables indexed by the area.
.BIND_AREA_PTRS
  FARCALL 4, LOAD_AREA_LAYOUT
  RTS

; FARCALL bank 4 at PLACE_SOFT_AND_BOMBS. That routine loads a per-stage byte into TEMP4 and 04E2h (32h if GAME_MODE is not 0) and then scatters objects with NEXT_RNG.
.LOAD_STAGE_META
  FARCALL 4, PLACE_SOFT_AND_BOMBS
  RTS

; FARCALL bank 5 at UPLOAD_LEVEL_CHR, which uploads 4 raw tiles to PPU 1800h from a bank-6 table selected by 04E3h.
.LOAD_4_TILES
  FARCALL 5, UPLOAD_LEVEL_CHR
  RTS

; Zero A9h and AAh, clear the round flags, then fall into INIT_PLAYERS.
.RESET_PLAYERS
  LDA #&00
  STA ACT_W_BOMBS
  STA ACT_W_FIRE
  JSR CLEAR_ROUND_FLAGS

; Set up three actor slots. Each ACTOR_FLAG entry is 1. X and Y come from PLAYER_SPAWN_X/Y.
; Clears the per-slot bytes at 75h, 7Eh, 81h, 84h, 87h, 96h, 99h and 7Bh.
; If STAGE_PHASE is nonzero, also clears several work bytes and copies 10 bytes from 0404h into 04D0h.
.INIT_PLAYERS
  LDX #&02
  LDA #&00
.L7_CDB2
  STA ACTOR_FLAG,X
  DEX
  BPL L7_CDB2
  LDX #&02
.L7_CDB9
  LDA #&01
  STA ACTOR_FLAG,X
  LDA PLAYER_SPAWN_X,X
  STA ACTOR_X,X
  LDA PLAYER_SPAWN_Y,X
  STA ACTOR_Y,X
  LDA #&00
  STA ACTOR_XSUB,X
  STA ACTOR_FRAME,X
  STA ACTOR_FTIMER,X
  STA ACTOR_DEATH,X
  STA ACTOR_TIMED,X
  STA ACTOR_SPDLO,X
  STA ACTOR_SPDHI,X
  LDA #&00
  STA ACTOR_DIR,X
  DEX
  BPL L7_CDB9
  LDA #&00
  STA ROUND_RES
  STA ROUND_WAIT
  STA POWER_TIME
  STA ITEM_KIND
  ABS_LDA STAGE_PHASE
  BNE L7_CDF7
  RTS

; Three starting X positions, one per actor slot: 18h, D8h, 78h. Read by INIT_PLAYERS.
.PLAYER_SPAWN_X
  EQUB &18,&D8,&78

; Three starting Y positions, one per actor slot: 18h, B8h, 78h. Read by INIT_PLAYERS.
.PLAYER_SPAWN_Y
  EQUB &18,&B8,&78
.L7_CDF7
  LDA #&00
  STA ACT_PASSBOMB
  STA ACT_PASSWALL
  STA ITEM_KIND
  STA EXIT_OPEN
  STA KNOCK_DIR
  STA ACT_SPEED
  STA ACT_REMOTE
  ABS_LDA GAME_MODE
  BNE L7_CE11
  LDA PASS_MARK
  STA ACT_REMOTE
.L7_CE11
  LDA ACT_SPEED
  BEQ L7_CE17

; (not seen executing during the coverage runs)
  DEC ACT_SPEED
.L7_CE17
  ABS_LDY GAME_MODE
  BEQ L7_CE2B
  LDX #&02
.L7_CE1E
  LDA MODE_BYTE_90,Y
  STA ACTOR_BOMBS,X
  LDA MODE_BYTE_93,Y
  STA ACTOR_FIRE,X
  DEX
  BPL L7_CE1E
.L7_CE2B
IF MOD
  JMP MOD_STAGE_POWERS
ELSE
  RTS
ENDIF

; Zero AE AE-adjacent round bytes AD, B0, B3, B4, B5, AF (AF is replaced by 03EEh when GAME_MODE is 0).
; Then copy MODE_BYTE_90/93, indexed by GAME_MODE, into ACTOR_BOMBS and ACTOR_FIRE.
.CLEAR_ROUND_FLAGS
  LDA #&00
  STA ACT_PASSBOMB
  STA ACT_PASSWALL
  STA ITEM_KIND
  STA ACT_SPEED
  STA EXIT_OPEN
  STA KNOCK_DIR
  STA ACT_REMOTE
  ABS_LDA GAME_MODE
  BNE L7_CE46
  LDA PASS_MARK
  STA ACT_REMOTE
.L7_CE46
  ABS_LDY GAME_MODE
  LDX #&02
.L7_CE4B
  LDA MODE_BYTE_90,Y
  STA ACTOR_BOMBS,X
  LDA MODE_BYTE_93,Y
  STA ACTOR_FIRE,X
  DEX
  BPL L7_CE4B
IF MOD
  JMP MOD_STAGE_POWERS
ELSE
  RTS
ENDIF

; Three bytes indexed by GAME_MODE and stored in ACTOR_BOMBS: 00, 01, 00. Also used by the demo setup path.
.MODE_BYTE_90
  EQUB &00,&01,&00

; Three bytes indexed by GAME_MODE and stored in ACTOR_FIRE: 00, 02, 01.
.MODE_BYTE_93
  EQUB &00,&02,&01

; FARCALL bank 5 at UPDATE_ACTORS. That routine advances CLEAR_PHASE when it is nonzero, otherwise walks the ACTOR_FLAG slots.
.UPDATE_PLAYERS
  FARCALL 5, UPDATE_ACTORS
  RTS

; If KNOCK_DIR is positive, ITEM_KIND is 1, and the WRAM cell at 611Eh/615Ah matches 9Dh/9Eh,
; set KNOCK_LEFT from 61D2h and KNOCK_DIR from BLAST_TYPE_TAB indexed by the low nibble of 60E2h.
; In: Y = index into those WRAM arrays.
.NOTE_BLAST_TYPE
  LDA KNOCK_DIR
  BMI L7_CE93
  LDA ITEM_KIND
  CMP #&01
  BNE L7_CE93

; (not seen executing during the coverage runs)
  LDA FLAME_COL,Y
  CMP ACT_W_COL
  BNE L7_CE93
  LDA FLAME_ROW,Y
  CMP ACT_W_ROW
  BNE L7_CE93
  LDA FLAME_RADIUS,Y
  CLC
  ADC #&01
  ASL A
  ASL A
  STA KNOCK_LEFT
  LDA FLAME_FLAG,Y
  AND #&0F
  TAY
  LDA BLAST_TYPE_TAB,Y
  STA KNOCK_DIR
.L7_CE93
  RTS

; 16 bytes. NOTE_BLAST_TYPE stores entry [low nibble of FLAME_FLAG] into KNOCK_DIR.
; Entries 9-15 are 00. ? what the 80h-83h values select.
.BLAST_TYPE_TAB
  EQUB &82,&80,&80,&81,&81,&82,&82,&83,&83,&00,&00,&00,&00,&00,&00,&00
.L7_CEA4
IF MOD
  LDA GAME_INVINC
  ORA GAME_FIREPROOF
  BNE L7_CEC3
ENDIF
  LDA POWER_TIME
  BNE L7_CEC3
  LDA ACT_W_FLAG
  BEQ L7_CEC3
  ABS_LDA SPECIAL_STAGE
  BNE L7_CEC3
  LDA #&08
  STA ACT_W_FTMR
  LDA #&00
  STA ACT_W_FRAME
  LDA #&01
  STA ACT_W_DEATH
  LDA #&04
  JSR AUDIO_CALL
.L7_CEC3
  RTS
.L7_CEC4
IF MOD
  LDA GAME_INVINC
  BNE L7_CEC3
ENDIF
  LDA POWER_TIME
  BNE L7_CEC3
  LDA ACTOR_FLAG
  BEQ L7_CEC3
  ABS_LDA SPECIAL_STAGE
  BNE L7_CEC3
  LDA #&08
  STA ACTOR_FTIMER
  LDA #&00
  STA ACTOR_FRAME
  LDA #&01
  STA ACTOR_DEATH
  LDA #&04
  JSR AUDIO_CALL
  RTS

; (not seen executing during the coverage runs)

; If SPECIAL_STAGE is set, increment CLEAR_PHASE and play sound 16h.
; Otherwise mark every live slot (ACTOR_FLAG set, ACTOR_DEATH clear) with ACTOR_FTIMER=8, ACTOR_FRAME=0, ACTOR_DEATH=1 and play sound 04h if any slot changed.
.KILL_PLAYERS
  ABS_LDA SPECIAL_STAGE
  BEQ L7_CEF1
  INC CLEAR_PHASE
  LDA #&16
  JSR AUDIO_CALL
  RTS
.L7_CEF1
  LDX #&02
  LDY #&00
.L7_CEF5
  LDA ACTOR_FLAG,X
  BEQ L7_CF0A
  LDA ACTOR_DEATH,X
  BNE L7_CF0A
  LDA #&08
  STA ACTOR_FTIMER,X
  LDA #&00
  STA ACTOR_FRAME,X
  LDA #&01
  STA ACTOR_DEATH,X
  INY
.L7_CF0A
  DEX
  BPL L7_CEF5
  TYA
  BEQ L7_CF15
  LDA #&04
  JSR AUDIO_CALL
.L7_CF15
  RTS

; Add 2 to Y and fall into QUEUE_MAP_TILE. In: A = tile id, X = column, Y = row before the add.
.QUEUE_TILE_Y2
  INY
  INY

; Queue the 2x2 tile A at column X, row Y.
; Four tile bytes come from (62h) at A*4. The attribute nibble comes from (66h), one nibble per tile id.
; Switches to bank 4 for the read, then calls QUEUE_TILE and restores the bank.
.QUEUE_MAP_TILE
  STX TILE_COL
  STY TILE_ROW
  TAY
  LDX #&00
  STX DATA_PTR_HI
  ASL A
  ROL DATA_PTR_HI
  ASL A
  ROL DATA_PTR_HI
  CLC
  ADC TILE_GFX
  STA DATA_PTR
  LDA TILE_GFX_HI
  ADC DATA_PTR_HI
  STA DATA_PTR_HI
  LDA CUR_BANK
  PHA
  LDX #&04
  JSR BANK_SWITCH
  TYA
  LSR A
  TAY
  LDA (TILE_ATTR),Y
  BCC L7_CF48
  LSR A
  LSR A
  LSR A
  LSR A
.L7_CF48
  AND #&0F
  STA TILE_PAL
  LDY #&00
  LDA (DATA_PTR),Y
  STA TILE_CHR0
  INY
  LDA (DATA_PTR),Y
  STA TILE_CHR1
  INY
  LDA (DATA_PTR),Y
  STA TILE_CHR2
  INY
  LDA (DATA_PTR),Y
  STA TILE_CHR3
  JSR QUEUE_TILE
  PLA
  TAX
  JSR BANK_SWITCH
  RTS
.L7_CF6F
  FARCALL 5, FOLLOW_ACTOR_SCROLL
  RTS

; Zero 0518h and the 15 bytes at 04EBh.
.CLEAR_BOMB_RAM
  LDA #&00
  STA BURIED_HIT
  LDX #&0E
.L7_CF7D
  STA BURIED_FLAG,X
  DEX
  BPL L7_CF7D
  RTS

; Map bank 5 and call STEP_BLASTS, which walks the 24 slots at BOMB_FLAG on alternate frames. Restores the bank.
.UPDATE_BLASTS
  LDA CUR_BANK
  PHA
  LDX #&05
  JSR BANK_SWITCH
  JSR STEP_BLASTS
  PLA
  TAX
  JSR BANK_SWITCH
  RTS
.L7_CF96
  LDA CUR_BANK
  PHA
  LDX #&05
  JSR BANK_SWITCH
  JSR PLACE_BOMB
  PLA
  TAX
  JSR BANK_SWITCH
  RTS

; Zero 24 bytes at 6001h, 60 bytes at 60E2h, 32 bytes at 60C1h, and 60E1h, 6000h, 624Dh-624Fh.
.CLEAR_BLAST_RAM
  LDX #&17
  LDA #&00
.L7_CFAC
  STA BOMB_FLAG,X
  DEX
  BPL L7_CFAC
  LDX #&3B
  LDA #&00
.L7_CFB6
  STA FLAME_FLAG,X
  DEX
  BPL L7_CFB6
  LDX #&1F
.L7_CFBE
  STA RING_SLOT,X
  DEX
  BPL L7_CFBE
  STA RING_INDEX
  STA FUSE_LOCK
  STA BLAST_TOG
  STA BLAST_ANIM_A
  STA BLAST_ANIM_B
  RTS
.L7_CFD4
  LDA CUR_BANK
  PHA
  LDX #&05
  JSR BANK_SWITCH
  JSR DETONATE_REMOTE
  PLA
  TAX
  JSR BANK_SWITCH
  RTS

; Search 24 slots at BOMB_FLAG for a flag that is positive and whose BOMB_COL/BOMB_ROW cell equals CELL_COL/CELL_ROW.
; Out: C=1 and Y=slot if found, C=0 if not.
.FIND_BLAST
  LDY #&17
.L7_CFE8
  LDA BOMB_FLAG,Y
  BEQ L7_CFFD
  BMI L7_CFFD
  LDA BOMB_COL,Y
  CMP CELL_COL
  BNE L7_CFFD
  LDA BOMB_ROW,Y
  CMP CELL_ROW
  BEQ L7_D002
.L7_CFFD
  DEY
  BPL L7_CFE8

; (not seen executing during the coverage runs)
  CLC
  RTS
.L7_D002
  SEC
  RTS

; Zero RING_SLOT at index RING_INDEX, then advance that index modulo 32.
.FREE_RING_SLOT
  LDA #&00
  LDY RING_INDEX
  STA RING_SLOT,Y
  TYA
  INY
  CPY #&20
  BCC L7_D014

; (not seen executing during the coverage runs)
  LDY #&00
.L7_D014
  STY RING_INDEX
  RTS
.L7_D018
  STA FLAME_DIR
  LDA CUR_BANK
  PHA
  LDX #&05
  JSR BANK_SWITCH
  JSR SPREAD_FLAME
  LDA #&27
  JSR AUDIO_CALL
  PLA
  TAX
  JSR BANK_SWITCH
  RTS

; Search 60 slots at FLAME_FLAG (index 3Bh down). Skip a flag of 0.
; Out: Y = slot whose FLAME_COL/FLAME_ROW cell equals CELL_COL/CELL_ROW, or FFh if none.
.FIND_ACTOR_CELL
  LDY #&3B
.L7_D033
  LDA FLAME_FLAG,Y
  BEQ L7_D047
  LDA FLAME_COL,Y
  CMP CELL_COL
  BNE L7_D047
  LDA FLAME_ROW,Y
  CMP CELL_ROW
  BNE L7_D047
  RTS
.L7_D047
  DEY
  BPL L7_D033

; (not seen executing during the coverage runs)
  RTS

; Find a zero flag in the 15 bytes at 04EBh.
; Out: C=1 and X=slot if one is free, C=0 if all 15 are in use.
.FIND_FREE_BOMB
  LDX #&0E
.L7_D04D
  LDA BURIED_FLAG,X
  BEQ L7_D057
  DEX
  BPL L7_D04D

; (not seen executing during the coverage runs)
  CLC
  RTS
.L7_D057
  SEC
  RTS

; Search the 15 slots at 04EBh for a nonzero flag whose 04FAh/0509h cell equals CELL_COL/CELL_ROW.
; Out: C=1 and X=slot if found, C=0 if not.
.FIND_BOMB_CELL
  LDX #&0E
.L7_D05B
  LDA BURIED_FLAG,X
  BEQ L7_D070
  LDA BURIED_COL,X
  CMP CELL_COL
  BNE L7_D070
  LDA BURIED_ROW,X
  CMP CELL_ROW
  BNE L7_D070
  SEC
  RTS
.L7_D070
  DEX
  BPL L7_D05B

; (not seen executing during the coverage runs)
  CLC
  RTS

; FARCALL bank 5 at RUN_TITLE. That routine blanks the PPU, sets SCROLL_Y to 60h and SCROLL_NT to 1, and fills the nametable with tile 0 before drawing the rest of the screen.
.SHOW_FRONT
  FARCALL 5, RUN_TITLE
  RTS

; FARCALL bank 5 at GAME_OVER_LOOP. Called when lives go negative. That routine draws a screen, sets KEEP_STAGE to 1, plays sound 19h and waits on its own NMI loop.
.RUN_GAME_OVER
  FARCALL 5, GAME_OVER_LOOP
  RTS

; FARCALL bank 5 at MODE_MENU_LOOP. That routine clears MENU_REDRAW, MENU_MODE1 and MENU_BONUS, fills the nametable with tile 13h, and zeros GAME_MODE and START_AREA before its own input loop.
.RUN_MODE_MENU
  FARCALL 5, MODE_MENU_LOOP
IF MOD
  JMP MOD_MODE_CHOSEN
ENDIF
  ABS_LDA GAME_MODE
  CMP #&03
  BNE L7_D093
  JMP L7_D1BE
.L7_D093
  RTS

; FARCALL bank 5 at PPU_WRITE_TEXT. The caller points 20h at a record: column, row, count, then bytes written straight to the PPU.
.DRAW_INLINE_STR
  FARCALL 5, PPU_WRITE_TEXT
  RTS

; Zero the 10 bytes at ENEMY_FLAGS and set ENEMY_ORDER and ENEMY_REACT to 1.
.RESET_ENEMY_RAM
  LDX #&09
.L7_D09D
  LDA #&00
  STA ENEMY_FLAGS,X
  DEX
  BPL L7_D09D
  STA BURST_TIME
  STA TYPE4_TIME
  LDA #&01
  STA ENEMY_ORDER
  STA ENEMY_REACT
  LDA #&00
  STA ENEMIES_GONE
  STA PARADE_IDX
  RTS

; If GAME_MODE is 0, map bank 0 and call DISPATCH_ENEMY_AI and ENEMY_BLAST_OR_PLAYER for each of the 10 ENEMY_FLAGS slots that is nonzero, then DRAW_ALL_ENEMIES, SPAWN_BURST, SPAWN_TYPE_4 and NOTE_ENEMIES_CLEARED.
; Always increments ENEMY_REACT. Restores the bank.
.UPDATE_ENEMIES
  ABS_LDA GAME_MODE
  BNE L7_D0F1
  LDA CUR_BANK
  PHA
  LDX #&00
  JSR BANK_SWITCH
  LDX #&09
.L7_D0CC
  STX ENEMY_INDEX
  LDA ENEMY_FLAGS,X
  BEQ L7_D0DA
  JSR DISPATCH_ENEMY_AI
  JSR ENEMY_BLAST_OR_PLAYER
.L7_D0DA
  LDX ENEMY_INDEX
  DEX
  BPL L7_D0CC
  JSR DRAW_ALL_ENEMIES
  JSR SPAWN_BURST
  JSR SPAWN_TYPE_4
  JSR NOTE_ENEMIES_CLEARED
  PLA
  TAX
  JSR BANK_SWITCH
.L7_D0F1
  INC ENEMY_REACT
  RTS

; FARCALL bank 0 at SPAWN_STAGE_ENEMIES. That routine walks a list and places entries when SPECIAL_STAGE and GAME_MODE are both 0.
.LOAD_ENEMIES
  FARCALL 0, SPAWN_STAGE_ENEMIES
  RTS

; (not seen executing during the coverage runs)

; FARCALL bank 0 at SPAWN_PARADE. That routine uses FRAME_CNT and steps an index in PARADE_IDX.
.STEP_ENEMY_GEN
  FARCALL 0, SPAWN_PARADE
  RTS
.L7_D103
  LDA BURST_TIME
  ABS_ORA CLEAR_PHASE
  BNE L7_D11A
  LDA #&28
  STA BURST_TIME
  LDA CELL_COL
  STA BURST_COL
  LDA CELL_ROW
  STA BURST_ROW
.L7_D11A
  RTS
.L7_D11B
  ABS_LDA GAME_MODE
  BNE L7_D137
  LDA TYPE4_TIME
  ABS_ORA CLEAR_PHASE
  BNE L7_D137
  LDA #&28
  STA TYPE4_TIME
  LDA CELL_COL
  STA TYPE4_COL
  LDA CELL_ROW
  STA TYPE4_ROW
.L7_D137
  RTS

; FARCALL bank 5 at FILL_MAP_RAM, which fills 1A0h bytes at 62F3h with FFh.
.FILL_MAP_FF
  FARCALL 5, FILL_MAP_RAM
  RTS

; Copy one layout byte into the live map. Returns if Y is 13 or more.
; In: Y = map row, X = column, A = index along (64h). Switches to bank 4 for the read. Out: the byte is stored through the row pointer.
.COPY_LAYOUT_CELL
  CPY #&0D
  BCS L7_D164
  STA MAP_TMP_A
  JSR MAP_ROW_PTR
  STX MAP_TMP_X
  LDA CUR_BANK
  PHA
  LDX #&04
  JSR BANK_SWITCH
  LDY MAP_TMP_A
  LDA (TILE_MAP),Y
  LDY MAP_TMP_X
  STA (MAP_PTR),Y
  PLA
  TAX
  JSR BANK_SWITCH
.L7_D164
  RTS

; Point 2Fh/30h at map row Y. Rows are 20h bytes apart starting at 62F3h. 13 rows.
; In: Y = row 0-12. Out: 2Fh = address from MAP_ROW_LO/HI.
.MAP_ROW_PTR
  LDA MAP_ROW_LO,Y
  STA MAP_PTR
  LDA MAP_ROW_HI,Y
  STA MAP_PTR_HI
  RTS

; 13 low bytes of the live map row addresses. High bytes are MAP_ROW_HI.
; Rows are 62F3h, 6313h, ... 6473h (stride 20h). Not PRG pointers.
.MAP_ROW_LO
  EQUB &F3,&13,&33,&53,&73,&93,&B3,&D3,&F3,&13,&33,&53,&73
.MAP_ROW_HI
  EQUB &62,&63,&63,&63,&63,&63,&63,&63,&63,&64,&64,&64,&64

; Read one live map byte. In: X = column, Y = row. Out: A = byte at that cell. Uses MAP_ROW_PTR.
.PEEK_MAP_BYTE
  JSR MAP_ROW_PTR
  TXA
  TAY
  LDA (MAP_PTR),Y
  RTS
.L7_D192
  STY TEMP1
.L7_D194
  FARCALL 0, ADD_SCORE
  RTS

; FARCALL bank 5 at SHOW_AREA_INTRO. That routine returns immediately unless the demo flag is clear, GAME_MODE and the stage are 0, and the area differs from INTRO_AREA. It then shows a screen and plays sound 11h.
.MAYBE_AREA_CARD
  FARCALL 5, SHOW_AREA_INTRO
  RTS

; (not seen executing during the coverage runs)

; FARCALL bank 5 at ENDING_LOOP. Called when the area reaches 6. That routine blanks the PPU, forces area 6 stage 0 and calls LOAD_MODE_GFX.
.RUN_ENDING
  FARCALL 5, ENDING_LOOP
  RTS

; FARCALL bank 5 at OPENING_LOOP. Called once from GAME_LOOP. Zeros GAME_MODE, SPECIAL_STAGE and EXIT_OPEN, then sets area 6 stage 1 and calls into bank 0.
.RUN_OPENING
  FARCALL 5, OPENING_LOOP
  RTS

; (not seen executing during the coverage runs)
.L7_D1B0
  FARCALL 0, SHOW_CREDITS
  RTS

; FARCALL bank 5 at INIT_PASS_BYTES. Fills 9 bytes at 03DBh with FFh, sets 03EDh to 4Bh and 03EEh to 0.
.RESET_MARKS
  FARCALL 5, INIT_PASS_BYTES
  RTS
.L7_D1BE
IF MOD
  JMP MOD_OPTIONS
ENDIF
  FARCALL 5, RUN_PASS_SCREEN

; (not seen executing during the coverage runs)
  RTS

; FARCALL bank 5 at MAKE_STAGE_CODE. Stores a nonzero RNG nibble, the area, the stage and ACTOR_BOMBS into PASS_EDIT and the following bytes.
.MIX_STAGE_BYTES
  FARCALL 5, MAKE_STAGE_CODE
  RTS

; (not seen executing during the coverage runs)

; FARCALL bank 5 at VS_RESULT_LOOP. Called from the versus round-end path. Sets KEEP_STAGE to 1 and plays sound 1Ch around a screen of its own.
.SHOW_VS_RESULT
  FARCALL 5, VS_RESULT_LOOP
  RTS

; FARCALL bank 5 at BATTLE_WIN_MENU. If GAME_MODE is not 2, store 5 in WINS_GOAL. If GAME_MODE is 2, that routine draws a screen instead.
.SET_WIN_COUNT
  FARCALL 5, BATTLE_WIN_MENU
  RTS

; Dispatch the pre-stage screen by GAME_MODE.
; 0 calls bank 5 at SHOW_STAGE_CARD, 2 calls SHOW_BATTLE_CARD, anything else calls SHOW_VS_CARD.
; Each of those turns NMI off, calls LOAD_MODE_GFX, draws, and plays sound 1Dh.
.SETUP_BY_MODE
  ABS_LDA GAME_MODE
  BEQ L7_D1EA
  CMP #&02
  BEQ L7_D1F1
  FARCALL 5, SHOW_VS_CARD
  RTS
.L7_D1EA
  FARCALL 5, SHOW_STAGE_CARD
  RTS

; (not seen executing during the coverage runs)
.L7_D1F1
  FARCALL 5, SHOW_BATTLE_CARD
  RTS

; Upload the mode CHR and palettes. Uses bank 1 for one CHR block and bank 4 for palettes selected by MODE_PAL_PTR[GAME_MODE].
; Then copies 16 more palette bytes from bank 4 at MODE_SPR_PAL and mirrors the background color.
.LOAD_MODE_GFX
  LDA CUR_BANK
  PHA
  LDA #LO(UI_SPR_CHR)
  STA DATA_PTR
  LDA #HI(UI_SPR_CHR)
  STA DATA_PTR_HI
  LDA #&00
  STA DEST_PTR
  LDA #&10
  STA DEST_PTR_HI
  LDX #&06
  LDY #&FF
  JSR UPLOAD_CHR_RLE
  LDA #LO(MODE_BG_CHR)
  STA DATA_PTR
  LDA #HI(MODE_BG_CHR)
  STA DATA_PTR_HI
  LDA #&00
  STA DEST_PTR
  LDA #&00
  STA DEST_PTR_HI
  LDX #&01
  LDY #&FF
  JSR UPLOAD_CHR_RLE
  LDX #&04
  JSR BANK_SWITCH
  ABS_LDA GAME_MODE
  ASL A
  TAX
  LDA MODE_PAL_PTR,X
  STA PAL_SRC
  LDA D7_D25E,X
  STA PAL_SRC_HI
  LDA #&00
  LDX #&04
  JSR COPY_PAL_ROWS
  LDA #LO(MODE_SPR_PAL)
  STA PAL_SRC
  LDA #HI(MODE_SPR_PAL)
  STA PAL_SRC_HI
  LDA #&04
  LDX #&04
  JSR COPY_PAL_ROWS
  JSR MIRROR_BG_COLOR
  PLA
  TAX
  JSR BANK_SWITCH
  RTS

; Three pointers, indexed by GAME_MODE, to 16-byte palette rows in bank 4.
; Entry 0 is STORY_MODE_PAL. Entries 1 and 2 are both UI_BG_PAL. LOAD_MODE_GFX copies the selected row to PAL_BUF.
.MODE_PAL_PTR
  EQUB LO(STORY_MODE_PAL)
.D7_D25E
  EQUB HI(STORY_MODE_PAL)
  EQUW UI_BG_PAL
  EQUW UI_BG_PAL

; Zero DEMO_SLOT, the demo record index.
.RESET_DEMO_IDX
  LDA #&00
  STA DEMO_SLOT
  RTS

; Zero DEMO_MODE. STAGE_LOOP and STAGE_WON treat a nonzero value as a demo, and a negative value as "leave the demo".
.CLEAR_DEMO_FLAG
  LDA #&00
  STA DEMO_MODE
  RTS

; Load demo record DEMO_SLOT (0-3) and set the demo flag.
; Each record is 8 bytes: area, stage, ACTOR_BOMBS, ACTOR_FIRE, RNG_1, RNG_2, RNG_3, and one unused byte.
; Also sets KEEP_STAGE, ACT_REMOTE and DEMO_MODE to 1, clears STAGE_PHASE and FRAME_CNT, and advances the stored index modulo 4.
.START_DEMO
  JSR CLEAR_ROUND_FLAGS
  LDA DEMO_SLOT
  CLC
  ADC #&01
  AND #&03
  STA DEMO_SLOT
  LDA #&01
  STA DEMO_MODE
  LDA #&00
  STA DEMO_HOLD
  STA DEMO_POS
  STA DEMO_BTN
  STA DEMO_PREV
.L7_D290
  STA DEMO_EDGE
.L7_D293
  ABS_STA GAME_MODE
  LDA DEMO_SLOT
  ASL A
  ASL A
  ASL A
  TAX
  LDA DEMO_AREA,X
  ABS_STA AREA_NUM
  LDA DEMO_STAGE,X
  ABS_STA STAGE_NUM
  LDA DEMO_BYTE_90,X
  ABS_STA ACTOR_BOMBS
  LDA DEMO_BYTE_93,X
  ABS_STA ACTOR_FIRE
  LDA DEMO_RNG_1,X
  STA RNG_1
  LDA DEMO_RNG_2,X
  STA RNG_2
  LDA DEMO_RNG_3,X
  STA RNG_3
  LDA #&01
  ABS_STA KEEP_STAGE
  ABS_STA ACT_REMOTE
  LDA #&00
  STA FRAME_CNT
  ABS_STA STAGE_PHASE
  RTS

; Four demo records of 8 bytes, indexed by DEMO_SLOT*8.
; Bytes at this label and the next six labels are area, stage, ACTOR_BOMBS, ACTOR_FIRE, RNG_1, RNG_2, RNG_3.
; The eighth byte of each record is not read by START_DEMO.
.DEMO_AREA
  EQUB &00
.DEMO_STAGE
  EQUB &00
.DEMO_BYTE_90
  EQUB &02
.DEMO_BYTE_93
  EQUB &02
.DEMO_RNG_1
  EQUB &00
.DEMO_RNG_2
  EQUB &03
.DEMO_RNG_3
  EQUB &06,&00,&01,&00,&02,&02,&12,&54,&D4,&00,&02,&00,&02,&02,&55,&56
  EQUB &A3,&00,&03,&00,&02,&02,&00,&00,&00,&00

; One byte, value 01h. Bank 5 at SERVICE_DEMO_PAD skips copying JOYPAD1 into the demo slots when this byte is nonzero.
.DEMO_PAD_LOCK
  EQUB &01
IF MOD
INCLUDE "text.asm"
INCLUDE "mod.asm"
ENDIF
  FILLTO &D800 + SHIFT

; Fixed-bank entry. JMP SND_INIT with bank 2 mapped.
.SND_RESET_ENTRY
  JMP SND_INIT

; Fixed-bank entry. JMP SND_REQUEST with bank 2 mapped.
.SND_REQUEST_ENTRY
  JMP SND_REQUEST

; NMI entry. JMP SND_FRAME with bank 2 mapped.
.SND_FRAME_ENTRY
  JMP SND_FRAME

; Shared RTS for an idle channel stream.
.SND_STREAM_DONE
  RTS

; Fetch one stream event for channel SND_CH. Maps the BGM bank in SND_BANK around the read.
.SND_TICK_CHANNEL
  LDX SND_BANK
  JSR SWITCH_BANK
  LDX SND_CH
  JSR SND_STEP_STREAM
  LDX #&02
  JSR SWITCH_BANK
  LDX SND_CH
  RTS

; Advance the music stream of channel SND_CH by one tick (BGM bank mapped by SND_TICK_CHANNEL).
; While SND_NOTE_LEN,X is running, count it down at L7_D8E8. Otherwise clear the legato flag,
; quiet the channel, read the next stream byte: D0 and up is a command (SND_EXEC_CMD), else a note.
.SND_STEP_STREAM
  LDX SND_CH
  LDA SND_NOTE_LEN,X
  BEQ L7_D82A
  JMP L7_D8E8
.L7_D82A
  LDA #&00
  STA SND_LEGATO,X
  TXA
  JSR SND_QUIET_CHANNEL
.L7_D833
  LDA WORK_PTR
  ORA WORK_PTR_HI
  BEQ SND_STREAM_DONE
  LDY #&00
  LDA (WORK_PTR),Y
  STA SND_BYTE
  JSR SND_STREAM_ADVANCE
  CMP #&D0
  BCC L7_D84A
  JMP SND_EXEC_CMD
.L7_D84A
  LDA SND_BYTE
  STA W_021D,X
  JSR SND_LOAD_DURATION
  LDA SND_BYTE
  AND #&F0
  BNE L7_D85D
  JMP L7_D8E4
.L7_D85D
  CPX #&03
  BEQ L7_D8B4
  CPX #&04
  BEQ L7_D877
  JSR SND_NOTE_PERIOD
  LDA SND_PERIOD_LO,Y
  STA W_034C
  LDA SND_PERIOD_HI,Y
  STA W_034D
  JMP L7_D8C8
.L7_D877
  LDA SND_MASTER
  CMP #&08
  BCC L7_D8C8
  LDX #&02
  JSR SWITCH_BANK
  LDX SND_CH
  LDA SND_BYTE
  LSR A
  LSR A
  LSR A
  AND #&1E
  TAY
  LDA SND_DMC_PTRS,Y
  STA WORK_PTR2
  LDA D2_8EAD,Y
  STA WORK_PTR2_HI
  LDY #&03
.L7_D89B
  LDA (WORK_PTR2),Y
  STA W_033E,Y
  DEY
  BPL L7_D89B
  LDX SND_BANK
  JSR SWITCH_BANK
  LDX SND_CH
  LDA #&01
  STA SND_DIRTY,X
  JMP L7_D8C8
.L7_D8B4
  LDX #&02
  JSR SWITCH_BANK
  LDX SND_CH
  JSR SND_START_NOISE
  LDX SND_BANK
  JSR SWITCH_BANK
  LDX SND_CH
.L7_D8C8
  LDX #&02
  JSR SWITCH_BANK
  LDX SND_CH
  JSR SND_COMMIT_NOTE
  LDX SND_BANK
  JSR SWITCH_BANK
  LDX SND_CH
  LDA #&00
  STA SND_LEGATO,X
  JMP L7_D8E8
.L7_D8E4
  TXA
  JSR SND_QUIET_CHANNEL
.L7_D8E8
  LDX SND_CH
  LDA SND_GATE,X
  BEQ L7_D8F3
  DEC SND_GATE,X
.L7_D8F3
  LDX #&02
  JSR SWITCH_BANK
  LDX SND_CH
  JSR SND_UPDATE_VOLUME
  JSR SND_APPLY_PITCH_MOD
  LDX SND_BANK
  JSR SWITCH_BANK
  LDX SND_CH
  DEC SND_NOTE_LEN,X
  RTS

; Force a silent period on channel A.
.SND_QUIET_CHANNEL
  ASL A
  ASL A
  TAY
  CPY #&08
  BEQ L7_D931
  CPY #&10
  BEQ L7_D930
  LDA #&30
  STA SND_APU_BUF,Y
  LDA #&01
  STA W_0330,Y
  LDA #&00
  STA W_0331,Y
  LDA SND_DIRTY,X
  ORA #&0D
  STA SND_DIRTY,X
.L7_D930
  RTS
.L7_D931
  LDA #&80
  STA SND_APU_BUF,Y
  LDA SND_DIRTY,X
  ORA #&01
  STA SND_DIRTY,X
  RTS

; Dispatch a stream byte >= D0 through SND_STREAM_CMDS. Index is byte-D0.
.SND_EXEC_CMD
  LDA SND_BYTE
  SEC
  SBC #&D0
  ASL A
  TAY
  LDA SND_STREAM_CMDS,Y
  STA WORK_PTR2
  LDA D7_D958,Y
  STA WORK_PTR2_HI
  JSR SND_JUMP_Z04
  JMP L7_D833

; Handlers for stream bytes D0-EB. Index is byte-D0. Below D0 is a note: high nibble pitch, low nibble length.
.SND_STREAM_CMDS
  EQUB LO(SND_CMD_END)
.D7_D958
  EQUB HI(SND_CMD_END)
  EQUW SND_CMD_OCTAVE_UP
  EQUW SND_CMD_OCTAVE_DOWN
  EQUW SND_CMD_SET_OCTAVE
  EQUW SND_CMD_SET_DURATION
  EQUW SND_CMD_SET_TRANSPOSE
  EQUW SND_CMD_REST
  EQUW SND_CMD_LOOP_PUSH
  EQUW SND_CMD_LOOP_POP
  EQUW SND_CMD_RESTART
  EQUW SND_CMD_SET_DUTY
  EQUW SND_CMD_SET_PITCH_ENV
  EQUW SND_CMD_SET_TEMPO
  EQUW SND_CMD_DD
  EQUW SND_CMD_JUMP
  EQUW SND_CMD_CALL
  EQUW SND_CMD_RETURN
  EQUW SND_CMD_E1
  EQUW SND_CMD_E2
  EQUW SND_CMD_SET_VOLUME
  EQUW SND_CMD_SET_VIBRATO
  EQUW SND_CMD_SET_VIB_LEN
  EQUW SND_CMD_SET_DETUNE
  EQUW SND_CMD_SET_DETUNE_TBL
  EQUW SND_CMD_VOLUME_REL
  EQUW SND_CMD_SET_LOOP
  EQUW SND_CMD_GOTO_LOOP
  EQUW SND_CMD_TRANSPOSE_REL

; Command D0. Set this channel stream pointer to 0000.
.SND_CMD_END
  TXA
  ASL A
  TAY
  LDA #&00
  STA WORK_PTR
  STA WORK_PTR_HI
  RTS

; Command D1. Increment octave SND_OCTAVE,X.
.SND_CMD_OCTAVE_UP
  INC SND_OCTAVE,X
  RTS

; Command D2. Decrement octave SND_OCTAVE,X.
.SND_CMD_OCTAVE_DOWN
  DEC SND_OCTAVE,X
  RTS

; Command D3. Set octave SND_OCTAVE,X from the next byte.
.SND_CMD_SET_OCTAVE
  LDY #&00
  LDA (WORK_PTR),Y
  STA SND_OCTAVE,X

; Increment the stream pointer WORK_PTR.
.SND_STREAM_ADVANCE
  INC WORK_PTR
  BNE L7_D9AE
  INC WORK_PTR_HI
.L7_D9AE
  RTS

; Command D4. Set duration unit SND_DUR_UNIT,X from the next byte.
.SND_CMD_SET_DURATION
  LDY #&00
  LDA (WORK_PTR),Y
  STA SND_DUR_UNIT,X
  JMP SND_STREAM_ADVANCE

; Command D5. Set transpose SND_TRANSPOSE,X from the next byte.
.SND_CMD_SET_TRANSPOSE
  LDY #&00
  LDA (WORK_PTR),Y
  STA SND_TRANSPOSE,X
  JMP SND_STREAM_ADVANCE

; Command D6. Set SND_LEGATO,X so the next note does not retrigger.
.SND_CMD_REST
  LDA #&01
  STA SND_LEGATO,X
  RTS

; Command D7. Push a loop count and the address that follows. Depth 4.
.SND_CMD_LOOP_PUSH
  LDY #&00
  LDA (WORK_PTR),Y
  PHA
  TXA
  ASL A
  ASL A
  CLC
  ADC W_0254,X
  TAY
  PLA
  STA W_0281,Y
  JSR SND_STREAM_ADVANCE
  LDA WORK_PTR
  STA W_0259,Y
  LDA WORK_PTR_HI
  STA W_026D,Y
  LDY W_0254,X
  INY
  TYA
  AND #&03
  STA W_0254,X
  RTS

; Command D8. Decrement the loop count and jump back, or drop the frame.
.SND_CMD_LOOP_POP
  LDY W_0254,X
  DEY
  TYA
  AND #&03
  STA SND_ARG
  TXA
  ASL A
  ASL A
  CLC
  ADC SND_ARG
  TAY
  LDX W_0281,Y
  DEX
  TXA
  STA W_0281,Y
  BEQ L7_DA1A
  LDA W_0259,Y
  STA WORK_PTR
  LDA W_026D,Y
  STA WORK_PTR_HI
  LDX SND_CH
  RTS
.L7_DA1A
  LDX SND_CH
  LDA SND_ARG
  STA W_0254,X
  RTS

; (not seen executing during the coverage runs)

; Command D9. Reload the stream pointer of channel X from the channel table of the current BGM (SND_BGM_TABLE entry SND_BGM_LATCH-0C), i.e. restart the track.
.SND_CMD_RESTART
  LDA SND_BGM_LATCH
  SEC
  SBC #&0C
  STA WORK_PTR2
  ASL A
  CLC
  ADC WORK_PTR2
  TAY
  LDA D2_9003,Y
  STA WORK_PTR2
  LDA D2_9004,Y
  STA WORK_PTR2_HI
  TXA
  ASL A
  TAY
  LDA (WORK_PTR2),Y
  STA WORK_PTR
  INY
  LDA (WORK_PTR2),Y
  STA WORK_PTR_HI
  RTS

; Command DA. Set duty mask SND_DUTY,X from the next byte.
.SND_CMD_SET_DUTY
  LDY #&00
  LDA (WORK_PTR),Y
  STA SND_DUTY,X
  JMP SND_STREAM_ADVANCE

; Command DB. Select pitch envelope SND_PENV,X from SND_PITCH_ENVS.
.SND_CMD_SET_PITCH_ENV
  LDY #&00
  LDA (WORK_PTR),Y
  STA SND_PENV,X
  JMP SND_STREAM_ADVANCE

; Command DC. Set the gate-time scale SND_GATE_SCL,X.
.SND_CMD_SET_TEMPO
  LDY #&00
  LDA (WORK_PTR),Y
  STA SND_GATE_SCL,X
  JMP SND_STREAM_ADVANCE

; (not seen executing during the coverage runs)

; Command DD. Store the next stream byte in W_020B (meaning not traced; no coverage run used it).
.SND_CMD_DD
  LDY #&00
  LDA (WORK_PTR),Y
  STA W_020B
  JMP SND_STREAM_ADVANCE

; Command DE. Continue the stream at the address in the next two bytes.
.SND_CMD_JUMP
  LDY #&00
  LDA (WORK_PTR),Y
  PHA
  INY
  LDA (WORK_PTR),Y
  STA WORK_PTR_HI
  PLA
  STA WORK_PTR
  RTS

; Command DF. Push the return address and jump to the next word. Depth 4.
.SND_CMD_CALL
  LDY #&00
  LDA (WORK_PTR),Y
  PHA
  INY
  LDA (WORK_PTR),Y
  PHA
  TXA
  ASL A
  ASL A
  ASL A
  STA SND_ARG
  LDA W_029A,X
  ASL A
  CLC
  ADC SND_ARG
  TAY
  LDA WORK_PTR
  CLC
  ADC #&02
  STA W_029F,Y
  LDA WORK_PTR_HI
.L7_DA9E
  ADC #&00
  STA W_02A0,Y
  LDY W_029A,X
  INY
  TYA
  AND #&03
  STA W_029A,X
  PLA
  STA WORK_PTR_HI
  PLA
  STA WORK_PTR
  RTS

; Command E0. Return to the address pushed by command DF.
.SND_CMD_RETURN
  LDY W_029A,X
  DEY
  TYA
  AND #&03
  STA W_029A,X
  ASL A
  STA SND_ARG
  TXA
  ASL A
  ASL A
  ASL A
  CLC
  ADC SND_ARG
  TAY
  LDA W_029F,Y
  STA WORK_PTR
  LDA W_02A0,Y
  STA WORK_PTR_HI
  RTS

; (not seen executing during the coverage runs)

; Command E1. Store the next stream byte in W_0210 (meaning not traced).
.SND_CMD_E1
  LDY #&00
  LDA (WORK_PTR),Y
  STA W_0210
  JMP SND_STREAM_ADVANCE

; Command E2. Store the next stream byte in W_02C7,X for this channel (meaning not traced).
.SND_CMD_E2
  LDY #&00
  LDA (WORK_PTR),Y
  STA W_02C7,X
  JMP SND_STREAM_ADVANCE

; Command E3. Set volume offset SND_VOLUME,X (00-1F).
.SND_CMD_SET_VOLUME
  LDY #&00
  LDA (WORK_PTR),Y
  STA SND_VOLUME,X
  JMP SND_STREAM_ADVANCE

; Command E4. Select vibrato waveform SND_VIB_ID,X. Squares only.
.SND_CMD_SET_VIBRATO
  CPX #&03
  BCS L7_DAFD
  LDY #&00
  LDA (WORK_PTR),Y
  STA SND_VIB_ID,X
.L7_DAFD
  JMP SND_STREAM_ADVANCE

; Command E5. Set vibrato restart count SND_VIB_LEN,X. Squares only.
.SND_CMD_SET_VIB_LEN
  CPX #&03
.L7_DB02
  BCS L7_DAFD
.L7_DB04
  LDY #&00
  LDA (WORK_PTR),Y
  STA SND_VIB_LEN,X
  JMP SND_STREAM_ADVANCE

; Command E6. Set constant detune SND_DETUNE,X. Squares only.
.SND_CMD_SET_DETUNE
  CPX #&03
  BCS L7_DB19
  LDY #&00
  LDA (WORK_PTR),Y
  STA SND_DETUNE,X
.L7_DB19
  JMP SND_STREAM_ADVANCE

; Command E7. Select detune stream SND_DETUNE_ID,X. Squares only.
.SND_CMD_SET_DETUNE_TBL
  CPX #&03
.L7_DB1E
  BCS L7_DB27
  LDY #&00
  LDA (WORK_PTR),Y
  STA SND_DETUNE_ID,X
.L7_DB27
  JMP SND_STREAM_ADVANCE

; Command E8. Add the negated next byte to SND_VOLUME,X, clamped to 00-1F.
.SND_CMD_VOLUME_REL
  LDY #&00
  LDA (WORK_PTR),Y
  EOR #&FF
  TAY
  INY
  TYA
  CLC
  ADC SND_VOLUME,X
  BMI L7_DB41
  CMP #&20
  BCC L7_DB43

; (not seen executing during the coverage runs)
  LDA #&1F
  BNE L7_DB43
.L7_DB41
  LDA #&00
.L7_DB43
  STA SND_VOLUME,X
  JMP SND_STREAM_ADVANCE

; Command E9. Remember the stream pointer as this channel loop point.
.SND_CMD_SET_LOOP
  LDA WORK_PTR
  STA W_02F2,X
  LDA WORK_PTR_HI
  STA W_02F7,X
  RTS

; Command EA. Jump to the pointer stored by command E9.
.SND_CMD_GOTO_LOOP
  LDA W_02F2,X
  STA WORK_PTR
  LDA W_02F7,X
  STA WORK_PTR_HI
  RTS

; (not seen executing during the coverage runs)

; Command EB. Add the next stream byte to SND_TRANSPOSE,X.
.SND_CMD_TRANSPOSE_REL
  LDY #&00
  LDA (WORK_PTR),Y
  CLC
  ADC SND_TRANSPOSE,X
  STA SND_TRANSPOSE,X
  JMP SND_STREAM_ADVANCE

; Read the note length for channel X. Low nibble, or the next byte when no unit is set. D6 ties lengths.
.SND_LOAD_DURATION
  LDA SND_DUR_UNIT,X
  BEQ L7_DB7D
  LDA SND_BYTE
  AND #&0F
  JSR SND_MUL_DURATION
  JMP L7_DB84

; (not seen executing during the coverage runs)
.L7_DB7D
  LDY #&00
  LDA (WORK_PTR),Y
  JSR SND_STREAM_ADVANCE
.L7_DB84
  STA SND_NOTE_LEN,X
  STA SND_GATE,X
  LDY #&00
  LDA (WORK_PTR),Y
  CMP #&D6
  BEQ L7_DBD9
  LDA SND_NOTE_LEN,X
  STA SND_GATE,X
  LDA SND_GATE_SCL,X
  BEQ L7_DBD8
  LDA SND_NOTE_LEN,X

; Scale a duration by SND_GATE_SCL,X into the gate counter SND_GATE,X.
.SND_SCALE_GATE
  STA WORK_PTR2_HI
  LDA #&00
  STA SND_TMP0
  STA SND_TMP1
  STA WORK_PTR2
  LDA SND_GATE_SCL,X
  ASL A
  ASL A
  ASL A
  ASL A
  ASL A
  STA SND_ARG
  LDY #&02
.L7_DBB6
  LSR WORK_PTR2
  ROR WORK_PTR2_HI
  ASL SND_ARG
  BCC L7_DBCB
  LDA SND_TMP0
  CLC
  ADC WORK_PTR2
  STA SND_TMP0
  LDA SND_TMP1
  ADC WORK_PTR2_HI
  STA SND_TMP1
.L7_DBCB
  DEY
  BPL L7_DBB6
  STA SND_GATE,X
  BNE L7_DBD8

; (not seen executing during the coverage runs)
  LDA #&01
  STA SND_GATE,X
.L7_DBD8
  RTS
.L7_DBD9
  LDA #&00
  STA SND_ARG
  STA WORK_PTR2_HI
  TAY
.L7_DBE0
  TYA
  PHA
  LDA (WORK_PTR),Y
  CMP #&D0
  BCC L7_DBF4
  CMP #&D6
  BNE L7_DBEE
  INC SND_ARG
.L7_DBEE
  PLA
  TAY
  INY
  BNE L7_DBE0

; (not seen executing during the coverage runs)
  RTS
.L7_DBF4
  LDA SND_ARG
  BEQ L7_DC20
  LDA SND_DUR_UNIT,X
  BEQ L7_DC07
  LDA SND_ARG
  AND #&0F
  JSR SND_MUL_DURATION
  JMP L7_DC12

; (not seen executing during the coverage runs)
.L7_DC07
  PLA
  TAY
  INY
.L7_DC0A
  LDA (WORK_PTR),Y
  STA SND_ARG_HI
  TYA
  PHA
  LDA SND_ARG_HI
.L7_DC12
  STA WORK_PTR2
  CLC
  ADC WORK_PTR2_HI
  STA WORK_PTR2_HI
  LDA #&00
  STA SND_ARG
  JMP L7_DBEE
.L7_DC20
  PLA
  LDA WORK_PTR2_HI
  CLC
  ADC SND_NOTE_LEN,X
  PHA
  LDA WORK_PTR2
  PHA
  JSR SND_SCALE_GATE
  PLA
  SEC
  SBC SND_GATE,X
  STA SND_ARG
  PLA
  STA WORK_PTR2_HI
  SEC
  SBC SND_ARG
  STA SND_GATE,X
  RTS

; Return A = SND_DUR_UNIT,X * (A+1).
.SND_MUL_DURATION
  STA SND_ARG
  INC SND_ARG
  LDA SND_DUR_UNIT,X
  STA SND_TMP2
  LDA #&00
  STA SND_ARG_HI
  LDY #&05
.L7_DC4E
  LSR SND_ARG
  BCC L7_DC59
  LDA SND_ARG_HI
  CLC
  ADC SND_TMP2
  STA SND_ARG_HI
.L7_DC59
  ASL SND_TMP2
  DEY
  BNE L7_DC4E
  LDA SND_ARG_HI
  RTS

; Map the note nibble through octave SND_OCTAVE,X and transpose SND_TRANSPOSE,X. Y indexes the period tables.
.SND_NOTE_PERIOD
  LDA SND_BYTE
  LSR A
  LSR A
  LSR A
  LSR A
  STA SND_ARG
  DEC SND_ARG
  LDY SND_OCTAVE,X
  DEY
  LDA SND_OCTAVE_BASE,Y
  CLC
  ADC SND_ARG
  CLC
  ADC SND_TRANSPOSE,X
  TAY
  RTS

; Eight row bases into the period tables. Octave SND_OCTAVE,X is 1-based.
.SND_OCTAVE_BASE
  EQUB &00,&0C,&18,&24,&30,&3C,&48,&54

; Jump through the pointer in WORK_PTR2.
.SND_JUMP_Z04
  JMP (WORK_PTR2)

; Jump through the pointer in SND_VECTOR.
.SND_JUMP_Z0A
  JMP (SND_VECTOR)

; APU timer low bytes. 96 entries, 8 octaves of 12 notes. Index comes from SND_NOTE_PERIOD.
.SND_PERIOD_LO
  EQUB &F0,&F0,&F0,&F0,&F0,&F0,&F0,&F0,&F0,&F0,&7E,&12,&AE,&4E,&F3,&9F
  EQUB &4D,&01,&B9,&75,&35,&F8,&BF,&89,&57,&27,&F9,&CF,&A6,&80,&5C,&3A
  EQUB &1A,&FC,&DF,&C4,&AB,&93,&7C,&67,&53,&40,&2E,&1D,&0D,&FE,&EF,&E2
  EQUB &D5,&C9,&BE,&B3,&A9,&A0,&97,&8E,&86,&7F,&77,&71,&6A,&64,&5F,&59
  EQUB &54,&50,&4B,&47,&43,&3F,&3B,&38,&35,&32,&2F,&2D,&2A,&28,&25,&23
  EQUB &21,&1F,&1D,&1C,&1B,&19,&18,&16,&15,&14,&13,&12,&11,&10,&0F,&0E

; APU timer high bytes, paired with SND_PERIOD_LO.
.SND_PERIOD_HI
  EQUB &07,&07,&07,&07,&07,&07,&07,&07,&07,&07,&07,&07,&06,&06,&05,&05
  EQUB &05,&05,&04,&04,&04,&03,&03,&03,&03,&03,&02,&02,&02,&02,&02,&02
  EQUB &02,&01,&01,&01,&01,&01,&01,&01,&01,&01,&01,&01,&01,&00,&00,&00
  EQUB &00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00
  EQUB &00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00
  EQUB &00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00

; Clear the DMC-busy flag and queue silent DMC id 1E.
.SND_DMC_IDLE
  LDA #&00
  STA W_034B
  LDA #&1E
  STA SND_DMC_ID
  RTS

; Start DMC id SND_DMC_ID when bit 7 is clear. Id-1E indexes SND_DMC_PTRS and SND_DMC_FRAMES.
.SND_DMC_SERVICE
  LDA SND_DMC_ID
  BPL L7_DD6A
  LDA W_034B
  BEQ L7_DD69
  DEC W_034B
  BNE L7_DD69
  LDA #&9E
  STA SND_DMC_ID
.L7_DD69
  RTS
.L7_DD6A
  SEC
  SBC #&1E
  PHA
  ASL A
  TAX
  LDA SND_DMC_PTRS,X
  STA WORK_PTR2
  LDA D2_8EAD,X
  STA WORK_PTR2_HI
  LDY #&00
.L7_DD7C
  LDA (WORK_PTR2),Y
  STA W_036B,Y
  INY
  CPY #&04
  BCC L7_DD7C
  PLA
  TAX
  LDA SND_DMC_FRAMES,X
  STA W_034B
  LDA #&01
  STA W_0373
  LDA SND_DMC_ID
  ORA #&80
  STA SND_DMC_ID
  RTS

; 13 frame counts, DMC ids 1E-2A.
.SND_DMC_FRAMES
  EQUB &00,&06,&01,&14,&14,&14,&14,&14,&28,&3C,&0A,&07,&0A
IF MOD
INCLUDE "hud.asm"
ENDIF
  FILLTO &E000                            ; DPCM samples must stay put

; DPCM sample bits from E000 up to the vector area. Not code.
.DPCM_SAMPLES
  EQUB &01,&FF,&FF,&FF,&FF,&FE
.D7_E006
  EQUB &00,&00,&00,&00,&1F,&FF,&FF,&FF,&FF,&80,&00,&00,&00,&07,&FF,&FF
  EQUB &FF,&FF,&FF,&00,&00,&00,&00,&00,&7F,&FF,&FF,&FC,&60,&F8,&07,&FF
  EQUB &FF,&E0,&00,&00,&0F,&FF,&C0,&00,&00,&00,&3F,&FF,&FF,&FF,&F0,&7F
  EQUB &FF,&F8,&00,&00,&00,&00,&00,&00,&00,&0F,&FF,&FF,&FF,&FF,&FF,&FF
  EQUB &FE,&00,&00,&00,&00,&00,&1F,&FF,&F3,&FF,&FF,&FF,&00,&00,&00,&00
  EQUB &FF,&F8,&00,&FF,&FF,&FF,&FF,&FC,&00,&00,&00,&00,&0F,&FF,&FF,&FF
  EQUB &E0,&00,&1F,&FF,&E0,&00,&00,&00,&00,&00,&7F,&40,&03,&FF,&FF,&FF
  EQUB &FF,&FF,&E0,&00,&00,&00,&00,&03,&FF,&FF,&FF,&FF,&00,&FF,&FF,&00
  EQUB &00,&00,&1F,&FF,&C0,&00,&00,&00,&07,&FF,&FF,&FF,&FF,&FF,&FF,&FF
  EQUB &FE,&00,&00,&00,&00,&00,&7F,&FE,&00,&00,&00,&00,&00,&00,&07,&FF
  EQUB &FF,&FF,&FF,&FF,&FF,&FF,&FF,&80,&00,&00,&00,&00,&00,&00,&7F,&FF
  EQUB &FF,&FF,&FF,&FF,&FF,&FE,&00,&7F,&FF,&F8,&00,&00,&00,&00,&00,&00
  EQUB &00,&7F,&FF,&FF,&FF,&FF,&FC,&00,&00,&3F,&FF,&FE,&0E,&10,&00,&00
  EQUB &7F,&FF,&80,&00,&00,&00,&00,&00,&3F,&FF
.D7_E0E0
  EQUB &80,&01,&FF,&FF,&FF,&00,&00,&01
.D7_E0E8
  EQUB &FF,&F0,&00,&3D,&FF,&FF,&FF,&FF,&FF,&FF,&FF,&FF,&E0,&00,&00,&00
  EQUB &00,&03,&FF,&FF,&FF,&FF,&F0,&00,&00,&00,&00,&00,&03,&FF,&FF,&FF
  EQUB &F8,&00,&00,&00,&00,&00,&00,&FF,&FF,&FF,&FF,&80,&00,&3F,&FF,&FF
  EQUB &FF,&FF,&FF,&FF,&F8,&00,&00,&00,&00,&00,&01,&FF,&E3,&EF,&DF,&FF
  EQUB &FF,&FF,&FF,&C0,&00,&00,&00,&00,&00,&00,&00,&00,&00,&F8,&00,&3F
  EQUB &FF,&FF,&FF,&FF,&F8,&63,&FF,&80,&0F,&FF,&FF,&F8,&00,&0F,&FF,&E0
  EQUB &00,&01,&FF,&FF,&C0,&00,&3F,&00,&01,&FF,&FF,&C3,&FF,&FF,&E0,&00
  EQUB &0F,&FF,&00,&00,&00,&00,&00,&00,&00,&3F,&FF,&FE,&FF,&FF,&FF,&FE
  EQUB &00,&00,&00,&1F,&FF,&FF,&F8,&00,&00,&00,&00,&30,&00,&FF,&FF,&FF
  EQUB &FF,&FF,&FF,&FF,&FF,&FF,&E0,&00,&00,&00,&00,&00,&00,&00,&00,&00
  EQUB &7F,&FF,&FF,&FF,&FF,&FF,&FF,&F8,&00,&00,&00,&00,&00,&07,&FF,&8F
  EQUB &FE,&00,&00,&00,&00,&00,&03,&FF,&FF,&FF,&FF,&FF,&FF,&FF,&FF,&FF
  EQUB &FF,&FF,&E0,&00,&00,&7F,&00,&00,&00,&00,&3F,&F8,&00,&00,&00,&00
  EQUB &00,&00,&3F,&FF,&FF,&FF,&FF,&FF,&FF,&FF,&E0,&00,&00,&00,&00,&00
  EQUB &1F,&FF,&FF,&FF,&FF,&FF,&FF,&FF,&FF,&FF,&F0,&00,&00,&00,&00,&00
  EQUB &00,&00,&01,&FF,&8F,&02,&1E,&00,&00,&00,&FF,&FF,&82,&7F,&FF,&FF
  EQUB &FF,&FF,&FF,&C1,&FF,&EF,&FF,&FF,&FF,&F8,&00,&00,&00,&00,&00,&00
  EQUB &00,&00,&00,&00,&00,&00,&03,&FF,&FF,&FF,&FF,&FF,&FF,&FF,&E0,&00
  EQUB &00,&00,&00,&1F,&E1,&57,&FF,&FF,&FF,&87,&FF,&FF,&FF,&C0,&00,&00
  EQUB &00,&00,&00,&00,&00,&7F,&FF,&FF,&81,&FF,&FF,&FF,&E0,&00,&00,&FF
  EQUB &FE,&01,&FF,&00,&0F,&FF,&FC,&00,&00,&00,&00,&FF,&FF,&FF,&80,&00
  EQUB &00,&00,&00,&00,&FF,&FF,&FF,&FF,&FE,&00,&7A,&80,&00,&1F,&FF,&FF
  EQUB &FD,&FF,&E0,&1F,&FF,&E0,&00,&00,&07,&C2,&87,&7B,&FE,&00,&00,&00
  EQUB &00,&1E,&3F,&FF,&FF,&F0,&0F,&FF,&FF,&80,&00,&00,&00,&00,&FF,&FF
  EQUB &FF,&FF,&FF,&80,&00,&3F,&FC,&3F,&E0,&00,&F8,&00,&00,&68,&00,&00
  EQUB &3F,&FE,&00,&00,&07,&FF,&FF,&FF,&FF,&FF,&FF,&C0,&00,&10,&00,&1F
  EQUB &FF,&FF,&FF,&E0,&00,&00,&55,&8A,&7F,&B2,&E7,&FF,&80,&00,&00,&00
  EQUB &1D,&FF,&E0,&00,&01,&FF,&F9,&FF,&FF,&F0,&00,&07,&FF,&FF,&FF,&E0
  EQUB &00,&00,&00,&01,&FF,&FF,&FF,&C0,&00,&00,&00,&FF,&FF,&FF,&FF,&FC
  EQUB &00,&00,&00,&00,&00,&0F,&FF,&FF,&FF,&FF,&E0,&1F,&FF,&00,&00,&00
  EQUB &07,&FF,&FF,&FF,&80,&00,&00,&03,&FE,&3E,&C0,&00,&7F,&FF,&FF,&FF
  EQUB &F0,&40,&00,&01,&D0,&00,&7F,&FF,&FF,&FF,&C0,&00,&00,&00,&00,&0F
  EQUB &FF,&FF,&00,&0F,&F0,&00,&07,&FF,&FF,&FF,&F0,&00,&03,&FE,&D0,&03
  EQUB &FF,&FF,&FF,&FF,&FF,&E0,&00,&00,&03,&C0,&00,&00,&03,&FF,&FF,&FF
  EQUB &FF,&FF,&FF,&80,&00,&00,&00,&00,&00,&07,&FF,&FF,&FF,&FF,&FF,&00
  EQUB &00,&00,&00,&01,&FF,&80,&00,&FF,&FF,&FF,&FF,&FF,&00,&00,&00,&00
  EQUB &02,&FF,&FF,&FF,&FF,&1F,&C0,&00,&02,&5F,&E2,&0F,&FF,&FF,&FF,&E0
  EQUB &00,&00,&00,&00,&00,&FF,&FF,&E0,&00,&0F,&FF,&FF,&FF,&C0,&00,&18
  EQUB &01,&E0,&00,&0F,&C0,&00,&71,&FF,&FF,&FF,&FF,&FF,&FF,&FF,&C0,&00
  EQUB &00,&00,&00,&07,&FF,&80,&1F,&FF,&FF,&FF,&80,&00,&07,&FF,&FF,&FF
  EQUB &80,&00,&FF,&FF,&BF,&F8,&00,&00,&00,&00,&1F,&FF,&C0,&00,&00,&00
  EQUB &07,&FF,&FF,&FF,&FF,&F8,&00,&00,&03,&FF,&F8,&00,&FF,&FF,&E0,&00
  EQUB &01,&00,&01,&FF,&FF,&FF,&E0,&80,&00,&00,&01,&E0,&1C,&3F,&FF,&FF
  EQUB &FF,&FF,&FF,&FF,&FC,&00,&00,&00,&00,&00,&00,&FF,&FF,&FC,&00,&00
  EQUB &1F,&FF,&FF,&FF,&FF,&FF,&FF,&00,&00,&00,&00,&00,&00,&1F,&FF,&FF
  EQUB &FF,&FF,&C0,&00,&3E,&00,&00,&7F,&FF,&FF,&C0,&FF,&F0,&00,&00,&00
  EQUB &00,&00,&00,&1F,&FF,&FF,&FF,&D0,&7F,&FF,&FF,&8F,&FF,&F0,&00,&08
  EQUB &D0,&00,&00,&00,&00,&00,&01,&FF,&FF,&FF,&FF,&FF,&FF,&F8,&00,&00
  EQUB &07,&FF
.D7_E3EA
  EQUB &00,&07,&FF,&FF,&00,&1F,&C6,&00,&09,&3F,&FF,&00,&00,&00,&07,&FF
  EQUB &FF,&FF,&F0,&1F,&FF,&B0,&00,&78,&00,&00,&07,&FF,&E0,&00,&1F,&FF
  EQUB &FF,&F0,&00,&07,&00,&17,&AF,&FC,&00,&07,&80,&BF,&FF,&FF,&FF,&FF
  EQUB &FF,&FC,&00,&30,&00,&00,&00,&00,&00,&FF,&FF,&E0,&00,&3F,&FF,&FF
  EQUB &FF,&FF,&FF,&FF,&00,&00,&00,&00,&00,&00,&00,&3F,&E0,&00,&00,&00
  EQUB &02,&81,&FF,&FF,&FF,&D9,&FF,&FF,&FF,&FF,&FF,&FF,&F0,&00,&00,&00
  EQUB &00,&0E,&FF,&FF,&FF,&E0,&00,&00,&00,&00,&00,&07,&FF,&FF,&FF,&FF
  EQUB &FF,&FF,&EB,&FF,&FF,&FF,&F0,&00,&00,&0C,&00,&00,&00,&FF,&FF,&80
  EQUB &00,&00,&00,&00,&00,&00,&00,&FF,&FF,&FF,&FF,&FF,&FF,&FF,&FE,&00
  EQUB &00,&00,&00,&07,&F0,&00,&1F,&FF,&FF,&FF,&FF,&FF,&FF,&EE,&00,&00
  EQUB &00,&00,&03,&FF,&FF,&00,&00,&00,&0F,&FF,&FF,&FF,&FF,&FF,&80,&00
  EQUB &00,&00,&03,&FF,&FF,&FF,&FF,&FF,&E0,&00,&00,&1F,&F8,&00,&00,&1E
  EQUB &00,&0F,&FF,&E0,&03,&FF,&80,&00,&7F,&F8,&00,&03,&FF,&FF,&EF,&FF
  EQUB &FF,&E0,&00,&00,&00,&08,&FF,&FF,&FF,&C0,&03,&FF,&FF,&00,&0F,&FF
  EQUB &80,&00,&00,&04,&FF,&FF,&F9,&5F,&80,&08,&00,&40,&00,&01,&FF,&C0
  EQUB &3F,&FF,&FF,&24,&00,&00,&7F,&FF,&FF,&FF,&FF,&80,&00,&0F,&FC,&00
  EQUB &3F,&FF,&FF,&FC,&00,&00,&00,&00,&00,&00,&FF,&FF,&FF,&FF,&FF,&FF
  EQUB &00,&03,&FE,&00,&00,&00,&1F,&FF,&FF
.D7_E503
  EQUB &C0,&00,&00,&00,&1F,&FF,&FF,&E0,&BF,&FF,&FC,&00,&00,&C0,&00,&00
  EQUB &1F,&F9,&7D,&FF,&FF,&FF,&00,&38,&80,&00,&00,&FF,&FF,&FF,&FF,&FF
  EQUB &FE,&00,&00,&00,&00,&3D,&68,&00,&00,&00,&FF,&FF,&FF,&FE,&07,&FF
  EQUB &FF,&FF,&F0,&00,&00,&00,&00,&00,&07,&FF,&0F,&F6,&80,&7F,&FF,&00
  EQUB &00,&38,&3F,&FF,&FF,&FB,&FF,&20,&01,&EF,&03,&F9,&40,&10,&00,&00
  EQUB &00,&FF,&FF,&FF,&C0,&00,&00,&03,&FF,&FF,&FF,&FF,&FF,&FF,&E0,&00
  EQUB &00,&00,&00,&01,&FF,&FF,&FF,&E0,&00,&00,&00,&3F,&FF,&FF,&FF,&FC
  EQUB &00,&00,&03,&FF,&0B,&C0,&1F,&F0,&21,&3C,&FF,&FF,&E0,&00,&00,&00
  EQUB &00,&01,&FF,&FF,&FF,&FF,&F8,&07,&E8,&05,&5F,&FF,&FF,&82,&F5,&F0
  EQUB &3C,&50,&00,&01,&F5,&00,&00,&00,&FE,&02,&00,&03,&FF,&FF,&FF,&FF
  EQUB &FF,&FF,&00,&00,&00,&00,&03,&FF,&FC,&3F,&FF,&C8,&88,&B1,&05,&6F
  EQUB &2E,&C0,&7F,&FF,&88,&00,&01,&FF,&F8,&00,&1F,&FF,&FF,&FF,&F0,&00
  EQUB &00,&00,&7F,&FE,&00,&0B,&E0,&01,&25,&FF,&FE,&00,&01,&FF,&C0,&04
  EQUB &3F,&FF,&F8,&07,&8F,&CF,&FF,&FF,&FF,&F4,&02,&28,&00,&00,&00,&00
  EQUB &00,&1F,&FF,&FF,&FF,&FF,&F8,&00,&00,&03,&40,&4F,&FF,&FF,&80,&00
  EQUB &1F,&FF,&EB,&FF,&80,&00,&00,&00,&0B,&40,&7F,&FF,&FF,&D3,&00,&7F
  EQUB &F0,&7F,&FF,&FF,&F0,&01,&54,&C0,&00,&00,&00,&00,&2F,&FF,&FF,&FF
  EQUB &FF,&FC,&10,&30,&90,&00,&04,&07,&FE,&01,&3F,&FF,&FF,&FE,&08,&AF
  EQUB &80,&07,&F8,&4F,&D3,&FF,&C5,&00,&00,&00,&00,&00,&07,&FF,&FF,&FF
  EQUB &C0,&FF,&FF,&E1,&C9,&C4,&00,&00,&1F,&FF,&FF,&FC,&00,&06,&90,&00
  EQUB &FF,&FF,&A0,&00,&01,&FF,&F3,&FF,&00,&00,&7F,&FF,&FE,&00,&03,&FF
  EQUB &FC,&00,&00,&3D,&FD,&E7,&00,&00,&7D,&C3,&85,&5F,&FF,&FE,&05,&7F
  EQUB &10,&00,&00,&00,&0F,&FF,&DF,&E2,&9D,&F5,&00,&00,&7F,&FF,&C6,&B9
  EQUB &5F,&FF,&FF,&00,&00,&32,&90,&02,&17,&F5,&80,&74,&00,&04,&82,&FF
  EQUB &FC,&14,&7F,&FF,&FF,&C2,&7F,&F5,&37,&FF,&80,&00,&00,&19,&7A,&BB
  EQUB &60,&00,&28,&00,&19,&E6,&F6,&BF,&FF,&F7,&42,&92,&FA,&11,&00,&12
  EQUB &FF,&F4,&00,&0F,&FF,&FF,&FF,&00,&4F,&01,&00,&1F,&C9,&24,&A9,&5E
  EQUB &FF,&F1,&50,&7F,&F8,&00,&2B,&4A,&C0,&29,&B2,&10,&C9,&BF,&FF,&D9
  EQUB &FF,&FF,&FE,&00,&00,&00,&00,&00,&1B,&67,&FF,&FA,&0B,&FF,&C0,&4D
  EQUB &F5,&80,&02,&6F,&57,&66,&00,&0F,&FF,&F0,&FF,&A9,&49,&11,&2A,&DF
  EQUB &FF,&E0,&00,&03,&D8,&01,&2E,&5B,&F1,&1F,&D7,&EE,&44,&80,&25,&FF
  EQUB &FB,&48,&07,&FF,&FE,&20,&00,&00,&06,&FF,&6E,&48,&6A,&9B,&20,&94
  EQUB &7F,&11,&1B,&FF,&7F,&FF,&F8,&05,&10,&81,&29,&6D,&60,&00,&77,&DA
  EQUB &5B,&24,&ED,&B3,&56,&CA,&A4,&00,&B7,&FF,&FD,&25,&DF,&EA,&10,&00
  EQUB &12,&55,&90,&2A,&FE,&D2,&DE,&AB,&6A,&53,&BD,&2D,&CD,&20,&AE,&B4
  EQUB &91,&45,&53,&4E,&D8,&04,&9E,&DA,&D2,&4D,&EF,&FD,&CD,&B2,&90,&00
  EQUB &05,&48,&00,&9F,&FA,&AD,&FD,&A9,&BF,&FF,&80,&00,&27,&6B,&54,&DF
  EQUB &AB,&6D,&C9,&B9,&92,&04,&40,&00,&09,&FF,&DB,&52,&B3,&EF,&B0,&05
  EQUB &4F,&B6,&DE,&41,&4A,&90,&05,&FF,&FF,&FF,&E0,&00,&11,&04,&52,&A5
  EQUB &BF,&6B,&48,&92,&7B,&6E,&DB,&05,&4A,&BF,&FC,&00,&00,&7D,&BD,&D4
  EQUB &88,&25,&FF,&FF,&00,&00,&36,&94,&DF,&6B,&42,&2A
.D7_E78F
  EQUB &4F,&FF,&D4,&09,&69,&55,&4A,&D9,&21,&7F,&66,&47,&FF,&90,&00,&1B
  EQUB &01,&54,&49,&DF,&FA,&A6,&4B,&5F,&FF,&F0,&00,&01,&77,&FE,&00,&06
  EQUB &B5,&D0,&12,&AD,&FE,&DA,&90,&17,&DD,&D9,&14,&AA,&95,&76,&92,&6E
  EQUB &D5,&14,&00,&01,&7F,&FF,&5A,&97,&7A,&7D,&ED,&80,&00,&01,&7F,&FF
  EQUB &FF,&C0,&14,&B1,&AF,&C8,&00,&00,&00,&0F,&FF,&F8,&20,&00,&7F,&FF
  EQUB &FF,&FF,&01,&12,&FF,&FF,&F0,&40,&03,&94,&80,&02,&AF,&FF,&FF,&A0
  EQUB &00,&00,&1F,&FF,&94,&00,&4A,&BB,&FF,&FF,&92,&AD,&D4,&00,&12,&57
  EQUB &D9
.D7_E800
  EQUB &21,&00,&2F,&FF,&FE
.D7_E805
  EQUB &02,&6F,&FF,&B4,&00,&16,&92,&01,&09,&5F,&FF,&E1,&24,&94,&3F,&FF
  EQUB &FF,&00,&00,&01,&FF,&FA,&00,&00,&B6,&FF,&6C,&85,&3B,&77,&24,&A5
  EQUB &AA,&FE,&A2,&14,&09,&AF,&ED,&DD,&56,&80,&01,&FA,&AC,&D0,&29,&2E
  EQUB &FB,&71,&01,&1F,&FF,&FF,&F8,&20,&00,&03,&FB,&80,&00,&00,&0F,&FF
  EQUB &EA,&EF,&F7,&FF,&F8,&00,&0F,&FB,&54,&A2,&55,&10,&22,&2B,&BB,&D8
  EQUB &40,&00,&1A,&ED,&FF,&B2,&96,&D3,&BF,&FF,&D0,&82,&05,&7D,&5A,&40
  EQUB &40,&00,&FF,&FF,&E2,&10,&0A,&FE,&FF,&B2,&00,&00,&00,&3F,&FF,&FA
  EQUB &D2,&56,&DD,&BB,&D8,&00,&00,&7F,&FE,&89,&24,&EF,&F5,&64,&4F,&77
  EQUB &24,&94,&4C,&80,&00,&00,&7F,&FF,&FF,&E0,&45,&6A,&ED,&E4,&91,&00
  EQUB &05
.D7_E896
  EQUB &FF,&FE,&E9,&04,&96,&AB,&BA,&A5,&15,&28,&96,&DF,&B6,&88,&49,&12
  EQUB &9A,&9D,&6D,&DD,&82,&02,&24,&B7,&7F,&7F,&FA,&20,&05,&65,&A7,&FD
  EQUB &A0,&04,&76,&D2,&02,&15,&B7,&BB,&5B,&AD,&68,&00,&0D,&FF,&FF,&DE
  EQUB &40,&00,&03,&EF,&57,&6B,&59,&08,&01,&FF,&BA,&A2,&00,&1F,&FF,&B2
  EQUB &41,&2D,&DF,&FF,&E0,&02,&66,&88,&A8,&80,&48,&BF,&FF,&7E,&C4,&00
  EQUB &13,&2D,&33,&FF,&ED,&24,&46,&EE,&4B,&59,&B4,&44,&94,&CB,&59,&6A
  EQUB &B5,&24,&76,&AB,&74,&91,&0A,&D2,&6E,&E9,&BB,&69,&9D,&CD,&29,&11
  EQUB &37,&B8,&12,&75,&20,&8A,&7E,&FF,&6A,&40,&09,&67,&ED,&B1,&28,&11
  EQUB &27,&FF,&D9,&92,&4A,&55,&FE,&ED,&40,&10,&13,&7B,&BF,&59,&68,&25
  EQUB &2A,&B5,&A9,&5E,&D6,&81,&00,&8A,&57,&FE,&B4,&41,&2A,&77,&EF,&6A
  EQUB &94,&B5,&B0,&54,&BF,&E5,&4A,&62,&51,&4B,&2D,&B6,&20,&40,&12,&FB
  EQUB &BB,&B6,&56,&B7,&FD,&4A,&B5,&58,&95,&10,&42,&92,&BA,&64,&11,&37
  EQUB &FD,&B6,&52,&95,&6D,&51,&BD,&F4,&86,&EF,&6A,&80,&10,&01,&77,&7E
  EQUB &FB,&20,&00,&9B,&7F,&BB,&20,&25,&2A,&57,&FF,&FC,&00,&FF,&FE,&08
  EQUB &84,&11,&24,&F6,&D9,&24,&14,&DD,&DA,&92,&B2,&A3,&48,&04,&BF,&FF
  EQUB &65,&4A,&95,&5A,&ED,&DD,&20,&4A,&DA,&22,&4F,&7E,&B1,&12,&56,&DA
  EQUB &93,&72,&94,&A2,&25,&4D,&B5,&36,&D6,&CA,&01,&0F,&FD,&B6,&4A,&6F
  EQUB &D5,&80,&89,&75,&C9,&A5,&A9,&59,&66,&AA,&AA,&DA,&B4,&92,&4E,&B2
  EQUB &25,&DA,&5A,&AE,&B4,&B4,&AB,&EE,&80,&01,&2F,&EF,&6A,&02,&4A,&6F
  EQUB &6A,&B6,&D2,&52,&DB,&14,&95,&AC,&AA,&AA,&AB,&51,&14,&82,&57,&FF
  EQUB &B6,&EE,&A2,&57,&AC,&80,&92,&6B,&65,&20,&25,&35,&92,&DD,&DF,&DB
  EQUB &41,&49,&6F,&7D,&6A,&D9,&04,&14,&AB,&2A,&BB,&5A,&C2,&48,&89,&37
  EQUB &4D,&B6,&55,&21,&29,&DE,&E9,&AB,&77,&76,&88,&93,&4C,&91,&1B,&BE
  EQUB &B4,&82,&05,&B6,&EB,&6A,&48,&49,&2E,&77,&6A,&A6,&F7,&D6,&08,&AB
  EQUB &55,&44,&96,&AB,&64,&12,&77,&AD,&AB,&25,&53,&29,&09,&5D,&B6,&EE
  EQUB &F6,&91,&54,&84,&92,&91,&57,&76,&C9,&29,&B6,&5A,&B6,&D5,&6E,&F4
  EQUB &40,&44,&59,&4D,&B7,&6D,&69,&49,&2A,&A9,&11,&25,&5A,&E5,&36,&DD
  EQUB &EE,&22,&5B,&B8,&8A,&56,&A9,&26,&5D,&AD,&A6,&EF,&5A,&C4,&49,&08
  EQUB &92,&59,&22,&4E,&FB,&D5,&AD,&AD,&12,&8A,&DD,&ED,&01,&00,&95,&4F
  EQUB &FB,&CA,&52,&BD,&DB,&6D,&64,&00,&02,&FE,&B5,&B5,&91,&00,&92,&94
  EQUB &DF,&FB,&DD,&29,&49,&52,&A6,&AA,&D2,&B7,&F7,&E8,&00,&90,&92,&5D
  EQUB &EF,&56,&91,&44,&25,&F6,&AA,&49,&46,&AD,&B4,&AD,&6D,&22,&4B,&77
  EQUB &75,&92,&93,&5A,&AA,&CA,&52,&49,&B5,&EA,&49,&4D,&4A,&12,&4B,&FF
  EQUB &F7,&55,&82,&04,&4D,&DB,&A4,&89,&55,&6D,&6A,&A0,&82,&95,&6F,&F6
  EQUB &ED,&94,&9A,&CC,&4A,&97,&77,&5A,&24,&A9,&52,&CA,&22,&49,&6E,&F7
  EQUB &6C,&B5,&B5,&08,&8A,&8D,&48,&02,&2F,&76,&F6,&DC,&B7,&FF,&FE,&DB
  EQUB &20,&00,&00,&2A,&2D,&B6,&DB,&90,&00,&8A,&C9,&AE,&1F,&FF,&E8,&80
  EQUB &09,&2A,&54,&95,&55,&55,&55,&55,&55,&40,&01,&0A,&7F,&FF,&FA,&AA
  EQUB &AD,&69,&55,&55,&2A,&AA,&AA,&A5,&55,&56,&AA,&AF,&F0,&DE,&0A,&F0
  EQUB &AB,&21,&7C,&22,&52,&55,&55,&55,&55,&52,&AA,&AA,&B5,&55,&55,&56
  EQUB &AA,&A5,&55,&55,&55,&55,&55,&55,&62,&4C,&1A,&B4,&3E,&4B,&59,&68
  EQUB &3F,&75,&75,&55,&55,&55,&55,&55,&55,&AA,&AA,&A5,&55,&55,&54,&AA
  EQUB &AA,&95,&55,&55,&55,&55,&55,&56,&D5,&BA,&CA,&BA,&91,&A8,&AA,&D1
  EQUB &24,&A9,&45,&55,&55,&55,&55,&55,&56,&AA,&AA,&AA,&AA,&AA,&AA,&AA
  EQUB &AD,&55,&55,&55,&55,&55,&55,&40,&84,&AA,&AA,&AC,&AF,&F7,&56,&AA
  EQUB &AD,&55,&55,&55,&55,&55,&55,&4B,&AC,&D6,&AE,&90,&B6,&AA,&16,&A9
  EQUB &59,&54,&9B,&45,&4C,&D3,&35,&24,&E3,&13,&AA,&84,&DA,&AA,&2A,&AD
  EQUB &59,&5D,&5B,&D5,&55,&55,&59,&9A,&AA,&AA,&AA,&AA,&AA,&AA,&AA,&A5
  EQUB &56,&ED,&55,&55,&D2,&75,&34,&4B,&64,&AA,&4C,&2A,&A4,&AA,&AB,&55
  EQUB &55,&55,&55,&55,&55,&55,&55,&A4,&A9,&A8,&BA,&AA,&AA,&AA,&AD,&2D
  EQUB &2D,&55,&55,&52,&D5,&55,&4E,&AA,&AA,&AA,&AA,&AD,&AA,&6A,&A9,&B5
  EQUB &55,&55,&FF,&FF,&FF,&FF,&FF,&80,&00,&00,&00,&00,&00,&00,&00,&00
  EQUB &C6,&7F,&EF,&FF,&1F,&BF,&C6,&7F,&FD,&EF,&FF,&FF,&FF,&FC,&00,&00
  EQUB &00,&00,&00,&00,&00,&00,&00,&FF,&87,&FF,&FF,&FF,&7F,&CE,&CF,&CF
  EQUB &C6,&7F,&1D,&39,&19,&0F,&00,&40,&00,&00,&00,&00,&00,&34,&78,&7B
  EQUB &EF,&FF,&FF,&EF,&FF,&FF,&FF,&FD,&0C,&60,&60,&70,&00,&08,&00,&00
  EQUB &C0,&00,&11,&1C,&3E,&77,&F7,&FF,&FF,&FF,&FF,&FE,&FF,&8F,&F8,&00
  EQUB &18,&10,&08,&01,&80,&00,&18,&03,&80,&71,&F8,&7F,&E3,&FF,&EF,&FB
  EQUB &FF,&FF,&DF,&E3,&F0,&37,&01,&04,&00,&00,&00,&80,&18,&1B,&E0,&E1
  EQUB &F8,&FE,&67,&FE,&7E,&FC,&FD,&FC,&7C,&FF,&F8,&22,&08,&02,&08,&00
  EQUB &10,&34,&0E,&0F,&07,&D8,&FC,&F3,&7F,&C7,&9F,&FC,&79,&F3,&EE,&31
  EQUB &B3,&07,&D0,&40,&21,&8C,&00,&00,&B8,&70,&3F,&83,&EE,&F8,&FF,&C7
  EQUB &3F,&F6,&71,&F8,&69,&F1,&70,&E0,&8F,&10,&18,&10,&41,&91,&B0,&F1
  EQUB &2C,&CE,&C7,&FF,&31,&F0,&F4,&F9,&CF,&EE,&0E,&F0,&1D,&4C,&07,&02
  EQUB &C1,&E0,&33,&81,&88,&F8,&7E,&E1,&C7,&E6,&73,&9C,&7B,&3F,&19,&87
  EQUB &E3,&40,&FC,&C0,&9A,&8A,&71,&0C,&7C,&1E,&21,&A3,&EA,&C1,&FC,&70
  EQUB &FA,&B1,&72,&E3,&E1,&FC,&03,&FC,&0C,&D8,&38,&1E,&13,&C1,&C7,&C0
  EQUB &78,&73,&8F,&46,&70,&FC,&AC,&E5,&E0,&CF,&F0,&C3,&5A,&70,&71,&AA
  EQUB &E1,&19,&70,&3C,&39,&C2,&67,&E2,&3E,&19,&E1,&CE,&71,&75,&55,&C3
  EQUB &97,&28,&F8,&65,&C3,&6A,&62,&74,&C3,&C3,&29,&F0,&79,&83,&CE,&4C
  EQUB &EA,&6C,&9D,&C3,&68,&F8,&78,&B5,&C1,&CE,&2A,&A7,&2B,&2A,&37,&07
  EQUB &8E,&1A,&DA,&34,&E3,&A1,&BA,&97,&2A,&AA,&AD,&55,&8D,&65,&C3,&59
  EQUB &53,&54,&72,&B1,&5D,&2A,&63,&2E,&39,&2C,&D8,&BC,&33,&8E,&AB,&2C
  EQUB &3C,&A9,&B1,&D2,&B2,&AC,&B2,&CD,&2A,&AC,&AC,&AC,&6C,&AA,&AB,&16
  EQUB &A5,&A5,&A9,&AB,&2A,&CA,&6B,&4C,&AD,&54,&D3,&4C,&B5,&55,&2A,&CD
  EQUB &2B,&4C,&D3,&1B,&4B,&2A,&CA,&B2,&B4,&AD,&DB,&33,&97,&01,&82,&04
  EQUB &00,&87,&0E,&BF,&F9,&FF,&FF,&FF,&EF,&D9,&F8,&30,&03,&00,&E2,&05
  EQUB &0F,&1C,&33,&8C,&00,&31,&81,&80,&C3,&85,&3F,&EF,&FB,&FF,&9F,&3F
  EQUB &F7,&E3,&87,&98,&01,&C0,&46,&10,&1E,&18,&66,&20,&70,&73,&81,&C7
  EQUB &CF,&CD,&C1,&FF,&7C,&FF,&1F,&3F,&DF,&38,&0F,&87,&06,&08,&00,&30
  EQUB &18,&40,&B3,&88,&6B,&38,&E7,&CF,&97,&DF,&79,&E7,&7C,&67,&9F,&F1
  EQUB &DC,&70,&31,&81,&00,&30,&00,&78,&18,&D0,&07,&9C,&7D,&FE,&7E,&7E
  EQUB &3C,&F3,&FC,&5E,&3E,&E1,&E6,&30,&1E,&00,&70,&21,&E0,&18,&61,&81
  EQUB &C1,&7C,&3F,&99,&F9,&F7,&9F,&3D,&FC,&78,&E7,&84,&1E,&1E,&07,&81
  EQUB &CC,&0D,&81,&83,&87,&0E,&C1,&C2,&93,&E6,&F9,&F2,&F1,&F9,&E3,&E5
  EQUB &F8,&78,&3E,&05,&E0,&C1,&98,&66,&1C,&00,&78,&E1,&C3,&38,&EE,&CF
  EQUB &83,&F3,&9D,&C7,&3F,&C3,&AA,&3C,&7E,&03,&D0,&CC,&18,&68,&E3,&02
  EQUB &3E,&38,&1E,&3C,&38,&3E,&3C,&E3,&CF,&8F,&2F,&1C,&7C,&CE,&0E,&73
  EQUB &31,&C8,&15,&67,&0E,&07,&43,&1C,&32,&79,&27,&F0,&59,&F0,&F9,&8F
  EQUB &0F,&B6,&1F,&1A,&E1,&C3,&83,&8F,&17,&31,&8C,&70,&E8,&2C,&E7,&0B
  EQUB &8E,&E1,&73,&CA,&9A,&AC,&DE,&38,&3E,&1C,&E3,&E0,&C9,&F0,&3C,&70
  EQUB &D4,&70,&F4,&70,&F0,&5E,&70,&9F,&46,&1F,&1D,&47,&A9,&3A,&63,&75
  EQUB &4D,&1C,&71,&71,&9B,&0A,&AA,&AC,&3C,&A8,&CF,&1C,&65,&47,&8F,&2C
  EQUB &5E,&35,&37,&25,&E3,&87,&33,&16,&71,&39,&93,&8E,&33,&92,&D4,&A6
  EQUB &9B,&1A,&A8,&EC,&C7,&93,&33,&8D,&33,&93,&96,&70,&F2,&6A,&C6,&8D
  EQUB &2C,&B4,&E3,&43,&C0,&64,&EC,&67,&1F,&3E,&C3,&1E,&6E,&EE,&E0,&C4
  EQUB &01,&C4,&F6,&30,&64,&E3,&1C,&5F,&1A,&CC,&FB,&88,&8C,&FE,&38,&C9
  EQUB &82,&2C,&8C,&B3,&B3,&2E,&3F,&B6,&66,&CF,&8C,&4B,&85,&80,&8F,&9B
  EQUB &D1,&F2,&B1,&80,&52,&E0,&F3,&44,&BF,&27,&CF,&9A,&4C,&1C,&FD,&66
  EQUB &30,&E6,&E4,&63,&18,&E1,&C9,&98,&C1,&99,&97,&7C,&1C,&12,&8F,&9C
  EQUB &E6,&7D,&39,&E1,&E2,&4C,&66,&73,&9E,&27,&0E,&34,&C3,&81,&D9,&39
  EQUB &F9,&E7,&1C,&C8,&E6,&0D,&27,&4F,&90,&26,&37,&CF,&B6,&39,&34,&46
  EQUB &05,&CE,&D6,&71,&E1,&C7,&31,&34,&F3,&6D,&03,&31,&3A,&CD,&8F,&47
  EQUB &4E,&51,&C6,&66,&63,&99,&19,&B9,&1C,&65,&9C,&9C,&44,&DD,&AF,&49
  EQUB &E7,&23,&93,&8E,&24,&4E,&C6,&F1,&B7,&C2,&4E,&63,&1C,&A7,&27,&06
  EQUB &A3,&4E,&C1,&34,&F4,&EC,&F1,&F1,&B4,&78,&64,&33,&59,&A6,&0F,&0D
  EQUB &B6,&5C,&C6,&17,&32,&71,&21,&D9,&C9,&D8,&FB,&74,&C8,&32,&3C,&CC
  EQUB &7B,&33,&87,&0F,&60,&4B,&D1,&8E,&0C,&FE,&53,&29,&8F,&9A,&64,&EC
  EQUB &89,&A2,&F9,&13,&E6,&33,&F1,&18,&69,&A5,&B9,&3E,&0E,&3D,&86,&6C
  EQUB &C7,&8F,&23,&89,&C8,&C4,&67,&79,&D8,&3C,&8C,&66,&31,&9C,&CE,&E6
  EQUB &39,&A7,&3C,&59,&33,&15,&9A,&67,&13,&89,&9A,&E9,&C7,&26,&22,&D8
  EQUB &C7,&33,&59,&3E,&74,&C8,&C6,&EC,&B1,&3C,&E7,&FF,&FA,&00,&03,&ED
  EQUB &E0,&00,&10,&01,&FC,&03,&FF,&FF,&FE,&F8,&00,&0F,&FF,&FF,&F0,&00
  EQUB &41,&01,&80,&1E,&00,&00,&03,&F3,&FF,&FF,&FF,&FF,&F8,&00,&1F,&8E
  EQUB &F8,&7E,&00,&00,&30,&01,&F1,&A9,&82,&80,&E3,&CF,&FF,&FF,&FF,&FF
  EQUB &C0,&58,&39,&46,&20,&20,&00,&08,&87,&BF,&FE,&7A,&04,&A8,&0F,&FF
  EQUB &FF,&FF,&FF,&C1,&B4,&94,&00,&30,&00,&00,&10,&14,&EF,&DF,&D2,&7F
  EQUB &97,&C8,&B6,&FE,&FD,&FF,&C8,&6A,&AA,&5C,&01,&00,&00,&00,&51,&41
  EQUB &DB,&1C,&FF,&7D,&7F,&7A,&BF,&BB,&D8,&47,&E2
.D7_F001
  EQUB &37,&D0,&04,&1D
.D7_F005
  EQUB &20,&14,&08,&29,&00,&BA,&95,&3A,&7D,&FF,&FF,&FF,&96,&ED,&55,&59
  EQUB &2D,&48,&18,&22,&86,&50,&02,&C8,&49,&A9,&A0,&9D,&E9,&6E,&FF,&FF
  EQUB &F7,&DB,&B9,&20,&9D,&89,&5B,&10,&A0,&89,&01,&11,&04,&A9,&69,&5B
  EQUB &37,&B6,&BE,&F6,&DD,&FF,&6B,&B5,&24,&93,&55,&96,&92,&40,&84,&81
  EQUB &11,&08,&96,&72,&AD,&AD,&B6,&6F,&ED,&BF,&7D,&B4,&B6,&B3,&52,&A5
  EQUB &56,&94,&44,&90,&40,&24,&82,&4D,&74,&CA,&5A,&DB,&73,&AF,&DB,&DB
  EQUB &D6,&D6,&ED,&AC,&B4,&92,&49,&24,&82,&4A,&42,&21,&4A,&D5,&28,&D2
  EQUB &6A,&DB,&DD,&B6,&EB,&77,&B5,&BD,&76,&59,&AA,&D8,&EE,&33,&00,&BE
  EQUB &73,&7E,&00,&3E,&F3,&08,&63,&61,&7D,&F7,&E3,&00,&4C,&62,&E6,&64
  EQUB &F4,&40,&C4,&61,&EF,&FF,&FF,&FF,&9D,&D2,&40,&00,&00,&00,&04,&84
  EQUB &CF,&5D,&ED,&FB,&CF,&FB,&7E,&D3,&86,&64,&E3,&1C,&4A,&55,&94,&AC
  EQUB &31,&21,&10,&80,&42,&1A,&B6,&BB,&BF,&EF,&DE,&ED,&64,&66,&A6,&7A
  EQUB &F7,&D7,&D4,&99,&04,&02,&08,&B1,&56,&69,&8A,&24,&A2,&18,&55,&66
  EQUB &D7,&5E,&F5,&EB,&AD,&BA,&BA,&6B,&55,&69,&CC,&C6,&AC,&52,&A4,&A9
  EQUB &50,&C9,&54
.D7_F0E8
  EQUB &90,&A5,&44,&A9,&33,&13,&4E,&5C
.D7_F0F0
  EQUB &D5,&B4,&F9,&D7,&5B,&77,&5E,&6D
.D7_F0F8
  EQUB &B6,&76,&AD,&35,&2A,&91,&8C,&28,&61,&19,&24,&48,&8B,&12,&96,&54
  EQUB &CD,&59,&D9,&B5,&D7,&76,&D9,&F6,&B5,&DA,&B9,&96,&A6,&99,&4B,&25
  EQUB &2A,&4A,&92,&4A,&99,&46,&52,&4D,&29,&93,&65,&56,&2A,&AA,&A5,&B1
  EQUB &C9,&D4,&D5,&CB,&55,&B9,&6A,&B6,&AD,&B6,&AD,&5B,&59,&99,&5A,&95
  EQUB &32,&32,&52,&A4,&54,&52,&28,&54,&A8,&A5,&32,&AC,&D5,&9C,&AD,&AD
  EQUB &B6,&D6,&D7,&5B,&AD,&6D,&6B,&96,&D3,&2C,&CD,&2A,&49,&54,&94,&92
  EQUB &61,&A9,&48,&CA,&54,&4D,&49,&A5,&4C,&B2,&D5,&65,&5A,&D5,&AD,&5B
  EQUB &5A,&D5,&5B,&96,&D9,&B5,&57,&2E,&3A,&A6,&9A,&38,&D4,&C5,&54,&55
  EQUB &49,&32,&99,&52,&94,&CA,&8D,&2A,&66,&54,&CB,&33,&2D,&35,&36,&55
  EQUB &CA,&D6,&6A,&D6,&B5,&59,&B5,&AD,&76,&CD,&5B,&35,&56,&AB,&4A,&99
  EQUB &95,&4A,&4A,&92,&54,&55,&89,&52,&8A,&52,&A5,&54,&A6,&95,&65,&9A
  EQUB &AD,&9B,&56,&AD,&AD,&AD,&56,&D5,&AB,&5A,&D5,&55,&96,&CA,&D3,&2C
  EQUB &D6,&72,&5E,&39,&19,&07,&D0,&00,&FD,&EC,&49,&7F,&1E,&F8,&8F,&70
  EQUB &0B,&63,&60,&7A,&D0,&00,&1D,&B1,&2C,&1F,&FF,&FF,&FE,&A6,&74,&00
  EQUB &3C,&00,&3B,&7D,&D8,&00,&1F,&EF,&FF,&5F,&E2,&00,&1F,&E8,&16,&92
  EQUB &40,&68,&0F,&FE,&00,&78,&0C,&10,&0F,&FF,&0B,&FF,&E4,&90,&0F,&FF
  EQUB &EF,&78,&AB,&C0,&03,&FE,&01,&FF,&FF,&86,&00,&7F,&C1,&80,&2F,&80
  EQUB &00,&1F,&E0,&3F,&07,&FC,&00,&0F,&FF,&7F,&E7,&F8,&00,&07,&FE,&07
  EQUB &FC,&60,&00,&0F,&FE,&00,&54,&3F,&10,&0F,&FE,&00,&EF,&7F,&80,&07
  EQUB &FF,&83,&CF,&FC,&00,&03,&FF,&E7,&EA,&FE,&00,&00,&FF,&E0,&7C,&AF
  EQUB &00,&00,&3F,&E0,&3F,&E3,&02,&00,&7F,&FC,&7F,&FD,&40,&00,&7F,&FC
  EQUB &07,&F0,&80,&00,&3F,&FC,&00,&FC,&00,&00,&1F,&FF,&FF,&FF,&E0,&00
  EQUB &0F,&FC,&1F,&FF,&F8,&00,&0F,&FF,&8F,&FC,&58,&00,&07,&FF,&80,&10
  EQUB &50,&00,&07,&FF,&07,&FF,&FC,&00,&07,&FF,&C3,&FF,&28,&00,&07,&FF
  EQUB &83,&E0,&7F,&00,&03,&FE,&01,&FD,&B8,&80,&01,&FF,&C3,&FF,&6C,&00
  EQUB &03,&FF,&83,&FF,&0F,&40,&01,&FF,&C0,&FF,&FF,&E0,&81,&FE,&00,&7E
  EQUB &04,&20,&00,&FF,&80,&FF,&3E,&00,&01,&FF,&F9,&FF,&CE,&70,&00,&7F
  EQUB &00,&7F,&0F,&00,&00,&7F,&F0,&7F,&86,&00,&00,&7F,&F0,&3F,&FF,&C0
  EQUB &00,&7F,&FC,&3F,&F7,&FA,&00,&3F,&F8,&1F,&87,&E0,&00,&3F,&E0,&1F
  EQUB &E2,&E0,&00,&1F,&C0,&0F,&F7,&A0,&00,&3F,&FF,&1F,&E1,&FC,&00,&1F
  EQUB &FE,&03,&C1,&F8,&00,&1F,&FE
.D7_F2DF
  EQUB &03,&E9,&78,&00,&0F,&FE,&00,&FF,&BC,&00,&1F,&FF,&03,&FF,&FE,&00
  EQUB &0F,&FE,&00,&7F,&FC,&00,&07,&FE,&01,&EB,&F0,&00,&07,&FE,&00,&BB
  EQUB &FF,&80,&07,&FF,&03,&F8,&FF,&00,&03,&FF,&00,&04,&BF,&80,&03,&FF
  EQUB &80,&7E,&3F,&80,&03,&FF,&C0,&FE,&5F,&00,&03,&FF,&E0,&7F,&3F,&80
  EQUB &03,&FF,&C0,&7B,&0F,&C8,&01,&FF,&C0,&7F,&8F,&00,&00,&F8,&C0,&3E
  EQUB &07,&FF,&71,&FF,&E0,&1C,&03,&B8,&20,&FD,&84,&7E,&01,&F6,&00,&7F
  EQUB &E2,&FF,&08,&33,&90,&FC,&28,&3E,&01,&7F,&F8,&7F,&00,&7E,&A8,&BF
  EQUB &FC,&7F,&80,&7E,&00,&0B,&7C,&3C,&82,&7F,&18,&00,&7E,&3C,&43,&7F
  EQUB &28,&73,&FF,&1F,&0E,&1F,&90,&00,&D3,&07,&02,&0F,&E0,&0F,&FF,&0F
  EQUB &CF,&8B,&91,&05,&FF,&85,&01,&83,&F8,&1F,&FF,&AF,&81,&CE,&C0,&00
  EQUB &FF,&E0,&C4,&EE,&18,&60,&FF,&F0,&D4,&FC,&08,&0E,&F9,&38,&74,&7E
  EQUB &00,&05,&7F,&F8,&34,&FE,&00,&40,&7F,&7C,&B8,&3F,&10,&24,&7E,&1C
  EQUB &7C,&3E,&00,&40,&7F,&3E,&FC,&1F,&84,&FF,&FC,&7E,&3C,&1F,&00,&00
  EQUB &14,&3F,&7E,&07,&C0,&7C,&F6,&BC,&FF,&0F,&80,&08,&3F,&39,&7E,&03
  EQUB &80,&1F,&2C,&38,&7F,&AF,&A0,&34,&06,&3E,&7E,&34,&C0,&1E,&7F,&4E
  EQUB &F8,&00,&D0,&00,&F6,&FF,&E9,&9C,&D3,&2B,&E4,&E3,&9F,&E1,&05,&00
  EQUB &20,&7F,&9F,&BF,&8A,&00,&7D,&BF,&DF,&08,&C0,&84,&1C,&7F,&C7,&1D
  EQUB &60,&D5,&9F,&A2,&67,&FC,&00,&C0,&02,&0B,&57,&FF,&81,&E0,&3F,&3B
  EQUB &9F,&FF,&80,&00,&1B,&1F,&C3,&CD,&01,&C7,&9D,&0F,&A7,&FE,&00,&85
  EQUB &A8,&0F,&F7,&FF,&C0,&60,&04,&BF,&F3,&FE,&80,&00,&78,&72,&EA,&F8
  EQUB &E0,&EE,&14,&A8,&FA,&FC,&70,&13,&51,&89,&FA,&78,&20,&3F,&81,&15
  EQUB &FF,&F0,&30,&14,&C1,&5F,&FC,&F8,&29,&FF,&40,&03,&C8,&FB,&31,&40
  EQUB &F1,&69,&F3,&FC,&10,&E1,&E4,&EB,&F3,&FF,&30,&C1,&C0,&0C,&D0,&AE
  EQUB &3C,&71,&D4,&B4,&0A,&BF,&3E,&1D,&44,&7C,&48,&7C,&BC,&0B,&D9,&3C
  EQUB &26,&2C,&7C,&01,&00,&FF,&80,&7E,&7F,&F3,&E4,&DE,&40,&3E,&7E,&04
  EQUB &E1,&2D,&80,&1C,&BF,&C4,&AE,&BF,&EC,&0F,&3F,&9E,&48,&25,&C8,&06
  EQUB &3F,&FE,&08,&11,&32,&0F,&3D,&BC,&4C,&15,&6A,&07,&3F,&6D
.D7_F48D
  EQUB &76,&39,&F8,&03,&1B,&76,&C4,&00,&E0,&07,&8F,&DD,&D2,&93,&EE,&27
  EQUB &D1,&DF,&E6,&80,&6D,&06,&A5,&8F,&67,&24,&BA,&97,&A3,&9F,&63,&20
  EQUB &79,&4B,&45,&CF,&B9,&11,&51,&2E,&81,&DB,&5C,&01,&4A,&72,&29,&E7
  EQUB &FB,&54,&D0,&FF,&8B,&49,&F7,&00,&11,&2C,&27,&A6,&AB,&86,&09,&7F
  EQUB &81,&BA,&D7,&D2,&D9,&4F,&54,&86,&DF,&E1,&A5,&5F,&61,&97,&8F,&A0
  EQUB &00,&1F,&E1,&07,&CF,&E0,&69,&2A,&E3,&03,&8B,&F9,&4A,&0F,&A2,&23
  EQUB &A7,&F4,&4A,&1F,&F3,&31,&83,&E0,&4C,&0F,&E9,&2F,&8F,&F0,&0A,&2F
  EQUB &C0,&5D,&83,&FC,&D3,&07,&B4,&2E,&D3,&FF,&17,&0F,&E8,&2F,&80,&3C
  EQUB &23,&09,&D4,&1F,&C4,&FC,&25,&90,&B2,&0F,&A0,&7F,&15,&A4,&EB,&0F
  EQUB &E1,&7F,&A6,&88,&E8,&49,&B0,&1F,&26,&11,&4A,&25,&E9,&FF,&EF,&26
  EQUB &69,&82,&A0,&5F,&DF,&26,&2A,&C4,&B9,&5F,&DD,&13,&57,&C4,&55,&03
  EQUB &D2,&A4,&0D,&B1,&3A,&CF,&EB,&01,&43,&40,&16,&4D,&EE,&D6,&49,&DA
  EQUB &5E,&9C,&FD,&94,&AD,&4C,&23,&91,&AD,&0C,&85,&38,&57,&4F,&FD,&93
  EQUB &29,&C9,&2D,&A5,&EE,&46,&91,&D8,&BB,&29,&DE,&2D,&4D,&54,&0D,&46
  EQUB &FC,&0D,&26,&71,&6D,&56,&FD,&0A,&14,&70,&52,&49,&FF,&05,&0B,&EC
  EQUB &B1,&AC,&FF,&93,&43,&74,&12,&54,&ED,&89,&01,&9D,&39,&F6,&FE,&A3
  EQUB &42,&D5,&10,&97,&6F,&52,&91,&BE,&9A,&65,&B7,&C2,&A0,&EC,&12,&96
  EQUB &D3,&54,&54,&7A,&AC,&B4,&EB,&68,&94,&55,&14,&4B,&DB,&36,&44,&BE
  EQUB &3A,&8D,&ED,&5A,&59,&1C,&99,&11,&ED,&2D,&22,&5D,&55,&A6,&DB,&1A
  EQUB &5A,&95,&A6,&A9,&A9,&3E,&1E,&48,&C7,&69,&EA,&15,&98,&3E,&4F,&84
  EQUB &E5,&F0,&54,&79,&A9,&5A,&9C,&B2,&68,&D4,&9F,&D4,&32,&56,&85,&78
  EQUB &7F,&22,&66,&98,&A9,&79,&AA,&9E,&4A,&50,&F5,&AE,&29,&C6,&38,&7B
  EQUB &94,&3C,&1D,&66,&CE,&34,&27,&A1,&D9,&9D,&19,&9D,&11,&6B,&5A,&C5
  EQUB &7E,&01,&58,&BF,&15,&AE,&54,&1D,&86,&75,&AD,&52,&95,&4B,&D4,&5E
  EQUB &15,&C6,&34,&DA,&59,&CE,&52,&0F,&D2,&F0,&99,&27,&90,&FE,&99,&0C
  EQUB &E4,&CA,&DE,&91,&E0,&D1,&BD,&26,&A9,&E2,&1E,&69,&AA,&67,&25,&58
  EQUB &DF,&0A,&93,&71,&66,&96,&63,&9A,&69,&5C,&A9,&66,&A6,&DA,&03,&D9
  EQUB &59,&5C,&A9,&96,&99,&AB,&49,&3E,&D2,&86,&AA,&A8,&F2,&6F,&84,&B1
  EQUB &B1,&CB,&35,&70,&6C,&AB,&55,&2C,&CA,&97,&95,&45,&55,&D3,&22,&D9
  EQUB &5C,&6C,&CA,&91,&75,&CE,&17,&69,&41,&ED,&CA,&1B,&54,&AE,&98,&AD
  EQUB &65,&A6,&A7,&89,&5A,&2A,&E5,&F8,&14,&5B,&99,&6D,&5C,&05,&E2,&D9
  EQUB &7C,&25,&62,&DA,&1D,&97,&52,&8D,&57,&23,&6A,&66,&36,&93,&78,&5A
  EQUB &A5,&AA,&54,&F8,&67,&13,&58,&B6,&65,&6A,&57,&15,&4E,&5A,&43,&F8
  EQUB &6D,&81,&9D,&55,&66,&F0,&8E,&1F,&25,&B2,&99,&3E,&0B,&56,&9C,&A6
  EQUB &A5,&66,&66,&1B,&AB,&C8,&66,&2A,&CD,&B2,&72,&59,&33,&4B,&79,&86
  EQUB &98,&E5,&9C,&53,&C9,&9A,&55,&26,&CA,&D5,&33,&4C,&F0,&AB,&1C,&8B
  EQUB &E5,&D1,&1B,&47,&2A,&3F,&87,&43,&91,&3A,&C3,&BB,&A2,&51,&A9,&9A
  EQUB &B3,&36,&5B,&82,&62,&7E,&53,&8B,&C2,&55,&AA,&D3,&5C,&C3,&65,&72
  EQUB &45,&E5,&E2,&AA,&55,&5A,&9C,&5A,&5A,&8D,&4B,&B5,&25,&58,&B5,&1E
  EQUB &E8,&AA,&1D,&56,&72,&74,&B1,&39,&1E,&56,&D5,&24,&D6,&9A,&36,&B8
  EQUB &C9,&53,&87,&9A,&B8,&35,&8C,&EA,&57,&8A,&68,&EC,&87,&63,&8B,&B2
  EQUB &6C,&99,&5A,&A9,&99,&72,&71,&0F,&CA,&8A,&EB,&2B,&23,&55,&CC,&52
  EQUB &EA,&55,&9D,&4A,&8B,&4E,&66,&9A,&96,&A3,&95,&5D,&8A,&35,&5A,&8B
  EQUB &66,&AA,&57,&83,&4A,&F1,&A3,&59,&CA,&37,&41,&AA,&F8,&74,&AA,&99
  EQUB &83,&9D,&CE,&49,&97,&05,&D9,&9D,&92,&69,&0F,&C9,&63,&74,&A5,&9C
  EQUB &AA,&8D,&D0,&D6,&9A,&4E,&54,&D5,&A9,&59,&65,&66,&66,&72,&4E,&66
  EQUB &96,&6B,&16,&27,&69,&6A,&E2,&92,&CD,&96,&5A,&B4,&A5,&38,&5D,&CB
  EQUB &A2,&69,&98,&D4,&B7,&4E,&4B,&84,&76,&33,&CC,&E1,&8E,&82,&FA,&76
  EQUB &0D,&C4,&B7,&0B,&E0,&EC,&3B,&0E,&A5,&78,&95,&A8,&F4,&97,&88,&E5
  EQUB &71,&8D,&69,&B8,&95,&A8,&B5,&CC,&A2,&DA,&95,&1E,&E2,&72,&95,&68
  EQUB &DB,&17,&21,&BC,&98,&75,&AA,&A6,&A5,&98,&E6,&66,&3A,&9D,&25,&A1
  EQUB &D5,&95,&B2,&56,&8B,&6A,&9A,&5A,&70,&D5,&E2,&4B,&72,&96,&69,&66
  EQUB &B8,&93,&4D,&72,&2E,&5E,&13,&5A,&5A,&AB,&51,&36,&99,&95,&9C,&B5
  EQUB &C2,&30,&EF,&45,&D8,&59,&87,&E0,&EC,&1F,&84,&EA,&57,&26,&4B,&72
  EQUB &A9,&59,&68,&BC,&2D,&B1,&A8,&76,&99,&CA,&36,&A4,&F0,&DA,&95,&E2
  EQUB &71,&8D,&58,&D6
.D7_F801
  EQUB &95,&B2,&5A
.D7_F804
  EQUB &51,&AD,&B8,&A9,&96,&D2,&58,&9E,&56,&CA,&9A,&89,&79,&76,&1C,&96
  EQUB &8D,&39,&A9,&A7,&29,&C6,&52,&7A,&9D,&16,&6A,&47,&5C,&A4,&D5,&CA
  EQUB &5A,&59,&55,&4B,&D8,&5A,&56,&A0,&F7,&17,&89,&31,&A5,&B4,&AC,&D3
  EQUB &59,&1A,&8F,&39,&39,&8D,&49,&D1,&B3,&2A,&B6,&4B,&23,&B8,&CB,&62
  EQUB &B8,&AC,&D2,&B3,&92,&B5,&71,&18,&7B,&4E,&93,&22,&F2,&AD,&38,&CB
  EQUB &2B,&C2,&B5,&35,&16,&C6,&E9,&4E,&50,&F4,&5C,&CD,&4F,&15,&2A,&CB
  EQUB &0B,&DA,&C7,&03,&C8,&D7,&39,&54,&DC,&2B,&17,&29,&DC,&2C,&CD,&33
  EQUB &31,&D8,&D5,&A9,&2D,&0E,&E1,&B4,&CD,&3E,&05,&2F,&55,&4D,&74,&25
  EQUB &9B,&91,&B6,&54,&AB,&1A,&E3,&35,&27,&94,&B5,&2C,&6D,&65,&A1,&5A
  EQUB &B2,&B2,&F9
.D7_F897
  EQUB &0D,&0B,&A9,&B3,&35,&92,&B4,&AD,&54,&B4,&6C,&B9,&35,&94,&D4,&5A
  EQUB &AF,&45,&4A,&3F,&12,&D1,&76,&4B,&33,&69,&1B,&07,&E8,&D2,&B4,&C6
  EQUB &AB,&71,&1C,&AB,&4C,&6C,&D9,&46,&75,&5A,&E2,&55,&A3,&66,&3D,&85
  EQUB &98,&B6,&AE,&0B,&C3,&59,&6E,&43,&D8,&98,&4F,&95,&CD,&68,&8B,&55
  EQUB &61,&7E,&5D,&09,&41,&BE,&5E,&4B,&84,&E5,&1C,&B7,&4A,&9C,&D2,&66
  EQUB &94,&76,&5E,&27,&42,&D8,&B7,&87,&92,&72,&3A,&0F,&57,&1A,&79,&16
  EQUB &0A,&F6,&F0,&5E,&25,&44,&7E,&BD,&01,&DA,&54,&B5,&6B,&18,&D9,&2B
  EQUB &EC,&28,&D6,&55,&87,&5F,&09,&56,&8A,&C7,&B8,&56,&9B,&05,&D9,&A5
  EQUB &8F,&46,&A3,&68,&76,&AD,&1B,&85,&58,&3D,&A6,&65,&9E,&18,&E6,&96
  EQUB &5A,&9A,&35,&A9,&63,&D2,&4B,&5D,&27,&22,&B8,&76,&C7,&46,&A9,&39
  EQUB &99,&65,&E1,&6A,&96,&59,&96,&E1,&9A,&A5,&53,&AA,&E2,&35,&95,&99
  EQUB &9A,&6A,&55,&55,&3B,&1B,&2C,&0F,&8D,&D2,&66,&99,&A9,&B2,&96,&35
  EQUB &4A,&D3,&A4,&B4,&5D,&46,&C5,&F0,&6D,&33,&86,&D1,&D3,&5C,&2B,&4A
  EQUB &B1,&AF,&0C,&D5,&32,&B5,&1D,&89,&D3,&32,&D9,&66,&95,&35,&B1,&55
  EQUB &9A,&9A,&53,&6A,&69,&95,&E2,&35,&52,&D8,&AE,&46,&D1,&B9,&2D,&4D
  EQUB &47,&94,&E8,&6C,&CF,&09,&B9,&54,&3A,&CE,&56,&54,&AB,&1D,&55,&31
  EQUB &F1,&55,&49,&6A,&D2,&AC,&BA,&15,&A6,&2A,&D9,&D1,&66,&AD,&20,&FC
  EQUB &69,&1B,&69,&4C,&D8,&3A,&B2,&C3,&E9,&65,&1A,&C6,&CB,&C2,&B2,&CC
  EQUB &8F,&53,&E0,&E4,&3E,&1B,&43,&E9,&35,&1B,&49,&74,&D2,&D9,&5A,&0E
  EQUB &C5,&B5,&56,&33,&27,&2F,&10,&F9,&33,&1B,&A4,&74,&6A,&B3,&4B,&49
  EQUB &AC,&E8,&39,&CD,&91,&B3,&33,&1B,&47,&95,&2A,&B5,&1C,&CC,&D5,&54
  EQUB &AA,&1E,&97,&A1,&58,&D5,&9A,&65,&5A,&E0,&B6,&1E,&66,&A1,&EA,&6C
  EQUB &8B,&66,&A8,&DA,&71,&5A,&1F,&49,&69,&59,&1F,&15,&C6,&C9,&98,&BC
  EQUB &95,&8D,&D1,&6A,&53,&67,&25,&69,&71,&AC,&4E,&69,&58,&DA,&3C,&5D
  EQUB &0B,&C5,&69,&69,&59,&A7,&16,&E0,&DC,&55,&8F,&61,&5A,&35,&A8,&CD
  EQUB &C6,&A9,&72,&3C,&8D,&93,&CA,&69,&74,&6A,&4B,&8B,&74,&99,&A9,&63
  EQUB &2D,&C8,&E5,&96,&B2,&A2,&E9,&38,&DC,&9D,&85,&6A,&23,&FE,&07,&C1
  EQUB &E0,&E0,&F8,&F9,&61,&A8,&72,&D4,&DF,&12,&CC,&D2,&3C,&EB,&42,&B1
  EQUB &B2,&B9,&2E,&15,&D2,&AA,&CC,&6C,&AB,&A3,&54,&E4,&34,&BD,&E2,&35
  EQUB &50,&D8,&BD,&8F,&0B,&A4,&D0,&BD,&35,&4B,&E1,&49,&D2,&56,&BE,&87
  EQUB &25,&72,&15,&9F,&E3,&03,&A8,&75,&95,&5C,&C3,&8D,&58,&DC,&6B,&07
  EQUB &C5,&65,&6A,&8D,&66,&61,&DA,&9A,&A5,&C3,&35,&E2,&56,&46,&D5,&C9
  EQUB &AA,&6A,&1C,&C7,&E1,&A3,&72,&94,&D9,&A5,&C9,&A3,&D0,&9F,&23,&61
  EQUB &F8,&92,&BC,&8E,&34,&EC,&9A,&2D,&C5,&94,&F0,&D9,&99,&95,&A1,&D9
  EQUB &58,&7E,&2C,&8B,&58,&DA,&5D,&16,&37,&0D,&69,&5D,&15,&AA,&59,&58
  EQUB &B6,&97,&45,&74,&5A,&59,&8B,&A6,&C5,&A8,&7C,&65,&8E,&C9,&58,&DD
  EQUB &16,&93,&66,&C1,&DA,&6A,&58,&D6,&9D,&2A,&96,&5C,&0F,&A9,&96,&A5
  EQUB &9A,&56,&6B,&0D,&6A,&3B,&17,&15,&4D,&36,&9D,&0B,&69,&E0,&76,&79
  EQUB &26,&C3,&A0,&FC,&72,&36,&C9,&1B,&69,&5C,&5C,&99,&5A,&2B,&A6,&72
  EQUB &5A,&8E,&8B,&B1,&C9,&37,&43,&78,&9C,&2D,&96,&A8,&D9,&F0,&58,&3E
  EQUB &9C,&A5,&D2,&5A,&2F,&23,&AA,&5A,&36,&3D,&45,&61,&DA,&B8,&37,&24
  EQUB &E1,&F8,&5F,&05,&59,&50,&F6,&76,&47,&41,&9E,&66,&A5,&C6,&C3,&4D
  EQUB &B2,&36,&A6,&C9,&72,&58,&DC,&AB,&07,&C4,&DC,&1E,&A6,&86,&D5,&9C
  EQUB &95,&65,&D0,&B6,&74,&8B,&5B,&89,&66,&9C,&8D,&35,&CA,&5A,&98,&CD
  EQUB &6A,&A4,&F2,&9C,&A7,&0B,&E1,&32,&DC,&96,&59,&A4,&7D,&1C,&A9,&A1
  EQUB &DA,&5D,&16,&C5,&A9,&69,&99,&69,&A4,&7A,&B2,&56,&58,&AD,&6C,&72
  EQUB &96,&95,&63,&65,&78,&95,&8D,&C3,&E1,&54,&AB,&56,&90,&EC,&3E,&1B
  EQUB &4D,&C5,&27,&1A,&CB,&93,&61,&AD,&4A,&E1,&AC,&E9,&2D,&2B,&43,&B4
  EQUB &D2,&DC,&93,&0D,&CB,&36,&4D,&8B,&43,&A4,&F7,&45,&32,&D8,&3A,&D7
  EQUB &12,&66,&EC,&4A,&5E,&93,&53,&6C,&34,&8F,&64,&72,&B9,&4D,&0F,&91
  EQUB &BC,&39,&4D,&0F,&51,&AC,&AF,&05,&96,&79,&58,&AA,&CC,&CA,&D1,&B6
  EQUB &53,&42,&EC,&BC,&0F,&C1,&E2,&72,&AE,&4C,&CB,&26,&B3,&52,&D9,&4A
  EQUB &3A,&CB,&53,&64,&CB,&32,&9A,&D3,&92,&6E,&32,&AC,&D1,&B6,&54,&D4
  EQUB &AD,&31,&E8,&D5,&52,&CC,&AE,&A4,&B1,&A8,&EB,&2D,&4B,&A4,&D4,&3F
  EQUB &13,&16,&E0,&EE,&8E,&26,&D0,&EE,&2D,&8E,&46,&C6,&76,&2B,&A2,&C8
  EQUB &FA,&0F,&27,&C2,&B5,&4C,&D5,&C1,&D4,&F4,&37,&29,&C1,&D9,&A5,&A9
  EQUB &6C,&61,&F4,&8D,&91,&F2,&9D,&86,&A1,&E6,&AA,&B2,&A9,&2D,&5A,&56
  EQUB &9A,&8A,&E3,&79,&26,&2D,&E0,&76,&C7,&83,&47,&E1,&55,&65,&9A,&AA
  EQUB &4F,&13,&A3,&E2,&9C,&63,&A1,&CF,&98,&37,&90,&73,&9A,&57,&2C,&88
  EQUB &FA,&A3,&A3,&B2,&3C,&35,&54,&DE,&8C,&A2,&B2,&D9,&1F,&D1,&30,&A8
  EQUB &EE,&CB,&2A,&D2,&36,&47,&A3,&5A,&9A,&9D,&44,&AA,&E4,&B6,&D3,&1C
  EQUB &8D,&52,&D4,&D6,&9E,&C2,&47,&96,&5A,&6F,&02,&D6,&3C,&8D,&9C,&66
  EQUB &A5,&62,&E9,&78,&8E,&C3,&99,&5E,&27,&13,&C8,&73,&57,&A1,&66,&96
  EQUB &55,&A5,&5A,&9B,&4B,&36,&64,&9D,&C1,&D1,&B3,&2B,&52,&AC,&CC,&D6
  EQUB &4A,&6B,&55,&4B,&92,&D4,&9B,&46,&D3,&65,&3A,&49,&E1,&78,&2F,&A3
  EQUB &65,&34,&C3,&C9,&B4,&75,&99,&53,&0C,&EB,&C5,&38,&AA,&4E,&67,&62
  EQUB &9A,&9A,&90,&7C,&CB,&59,&17,&2C,&D2,&E4,&9B,&33,&92,&6A,&B9,&4A
  EQUB &D3,&35,&53,&C0,&DC,&BC,&55,&54,&B2,&3B,&27,&4C,&E9,&4A,&CC,&AC
  EQUB &67,&B0,&D5,&39,&4B,&39,&34,&AB,&35,&8A,&D5,&2B,&4B,&3A,&4D,&29
  EQUB &AB,&2D,&46,&B8,&D2,&BC,&A3,&AB,&1C,&93,&98,&D9,&56,&A6,&72,&8D
  EQUB &67,&C1,&35,&59,&A9,&6C,&5A,&83,&E5,&A6,&65,&AC,&33,&67,&29,&59
  EQUB &CA,&62,&E6,&B0,&EA,&A5,&A8,&D5,&A8,&D6,&CD,&21,&E4,&B5,&B5,&25
  EQUB &AC,&49,&E6,&65,&B2,&A9,&87,&66,&58,&E6,&96,&8D,&B0,&F2,&69,&4D
  EQUB &9A,&37,&86,&5A,&70,&E1,&DB,&A1,&53,&98,&D9,&A9,&A5,&66,&52,&AD
  EQUB &DC,&19,&66,&9A,&8D,&B5,&5B,&46,&41,&AB,&A6,&74,&72,&99,&54,&CE
  EQUB &AC,&A6,&5C,&95,&43,&F0,&BA,&A9,&A9,&72,&38,&E5,&AA,&37,&23,&B2
  EQUB &9A,&A5,&9D,&2A,&5A,&64,&EE,&1A,&66,&9A,&55,&96,&AA,&96,&55,&A2
  EQUB &BC,&D2,&56,&95,&A6,&49,&B9,&79,&2A,&71,&8B,&59,&55,&3D,&87,&22
  EQUB &D6,&36,&78,&AA,&95,&51,&5E,&67,&55,&C1,&2C,&D2,&E6,&56,&78,&8D
  EQUB &65,&5A,&37,&2E,&22,&B7,&89,&63,&9E,&26,&63,&D2,&36,&1D,&B5,&19
  EQUB &95,&5A,&4E,&97,&26,&AA,&1C,&E7,&16,&96,&6A,&55,&A5,&C9,&66,&3A
  EQUB &98,&B9,&96,&59,&A5,&C5,&25,&F0,&9B,&64,&A5,&D2,&C3,&CD,&14,&3E
  EQUB &75,&43,&59,&A8,&3B,&71,&9C,&8D,&B2,&56,&96,&8E,&9A,&55,&8D,&A6
  EQUB &A8,&CF,&C3,&03,&DB,&32,&2F,&86,&65,&3A,&98,&5E,&D3,&41,&EE,&28
  EQUB &A7,&6C,&CC,&65,&A6,&34,&7C,&C6,&A5,&6A,&65,&67,&0B,&99,&AC,&55
  EQUB &A6,&4D,&73,&45,&35,&55,&5A,&6A,&5A,&63,&56,&1E,&A9,&99,&95,&9A
  EQUB &1D,&66,&6A,&66,&C8,&AD,&95,&D2,&56,&56,&95,&C5,&95,&99,&9B,&0D
  EQUB &59,&AA,&D9,&54,&9D,&52,&B3,&63,&32,&B4,&AC,&B4,&D2,&75,&4C,&B3
  EQUB &32,&6A,&AF,&05,&BC,&3C,&07,&6B,&4A,&CC,&F1,&53,&1B,&49,&76,&4D
  EQUB &4D,&2C,&71,&CB,&4B,&33,&69,&26,&AC,&CA,&6B,&35,&33,&56,&64,&D6
  EQUB &69,&AB,&14,&8E,&3B,&93,&C8,&C9,&A9,&9A,&CC,&F0,&72,&CD,&52,&75
  EQUB &1A,&E4,&CD,&2B,&2A,&AB,&35,&A4,&AB,&4A,&D4,&AB,&4B,&2D,&35,&4A
  EQUB &B4,&B4,&B8,&AC,&AB,&25,&D1,&66,&66,&A5,&5C,&65,&94,&75,&99,&A6
  EQUB &65,&A0,&FB,&1A,&A4,&EA,&59,&59,&A5,&74,&96,&5A,&95,&A3,&47,&E8
  EQUB &74,&83,&E4,&6D,&75,&62,&66,&A1,&E4,&FA,&8C,&AA,&38,&AE,&59,&9D
  EQUB &8A,&64,&76,&A3,&B2,&A5,&A9,&5A,&59,&94,&BB,&89,&1E,&69,&94,&AD
  EQUB &A9,&AA,&53,&E2,&6A,&56,&56,&9A,&95,&B2,&59,&2F,&86,&93,&A9,&A5
  EQUB &99,&A6,&A5,&98,&DA,&65,&A6,&65,&69,&9A,&66,&95,&CA,&66,&B8,&35
  EQUB &96,&69,&6A,&5A,&95,&9A,&92,&E9,&A9,&A7,&32,&55,&59,&95,&73,&29
  EQUB &56,&CA,&1D,&AA,&68,&7C,&A5,&99,&AC,&8F,&26,&94,&B7,&1A,&5A,&6A
  EQUB &68,&BB,&4A,&A9,&39,&B2,&97,&47,&A2,&CB,&51,&5F,&15,&C2,&DD,&18
  EQUB &AD,&CA,&93,&78,&92,&1F,&F0,&61,&EC,&59,&57,&21,&7E,&32,&91,&D7
  EQUB &29,&99,&97,&44,&CD,&BC,&0B,&5C,&C9,&35,&6C,&53,&9E,&25,&27,&D4
  EQUB &38,&BD,&26,&8E,&93,&6A,&35,&BA,&0D,&A2,&B6,&59,&7A,&22,&AB,&65
  EQUB &A5,&74,&A9,&A7,&23,&62,&D9,&AD,&8A,&2B,&72,&59,&6E,&1A,&36,&99
  EQUB &93,&7A,&32,&CE,&95,&91,&B6,&34,&AB,&5E,&03,&AA,&D3,&1A,&B7,&0B
  EQUB &A3,&B1,&4D,&A5,&C8,&DA,&55,&68,&F8,&5C,&96,&99,&35,&A9,&6A,&95
  EQUB &95,&8F,&36,&11,&F1,&72,&1F,&19,&5B,&25,&5A,&3D,&29,&96,&C9,&5A
  EQUB &59,&56,&9A,&36,&AB,&4D,&58,&B4,&CC,&4E,&CB,&46,&AC,&E8,&9A,&A5
  EQUB &A8
  FILLTO &FFE0
IF REGION = 2
  EQUB &44,&59,&4E,&41
ELSE
ENDIF
  EQUB &42
IF REGION = 2
  EQUB &4C,&41,&53,&54
ELSE
  EQUB &4F,&4D,&42
ENDIF
  EQUB &45,&52
IF REGION = 2
  EQUB &20,&38
ELIF REGION_JP
  EQUB &20,&4D,&41,&4E,&20
ELSE
  EQUB &4D,&41,&4E
ENDIF
  EQUB &32
IF REGION = 2
  EQUB &36,&20,&7B,&7F
ELIF REGION_JP
  EQUB &20,&20,&20,&20,&04,&F8
ELSE
  EQUB &20,&39,&32,&38,&31,&37,&A7,&94
ENDIF
  EQUB &00,&00,&38,&84,&01,&0F,&18,&1C
  EQUW NMI

; Title bytes at FFE0. JP: BOMBER MAN 2, spaces, then 04 F8. US: BOMBERMAN 2, ASCII 92817, then A7 94. Vectors NMI/RESET/IRQ follow the shared 00 00 38 84 01 0F 18 1C.
.D7_FFFC
  EQUW RESET
  EQUW IRQ
