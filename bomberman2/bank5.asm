; ---------------------------------------------------------------------------
; PRG bank 5 ($8000-$BFFF)
; ---------------------------------------------------------------------------

  PAD SHIFT                               ; relocation test, see make.sh

; Story mode only. If W_04E5 changed and is not negative, store it in W_04CB and queue that digit at nametable column 1Bh row 02h.
; Skips when Z_49 is not 0. Called every frame from STAGE_LOOP.
.DRAW_LIVES
  LDA Z_49
  BNE L5_802E
  LDA W_04E5
  BMI L5_802E
  CMP W_04CB
  BEQ L5_802E
  STA W_04CB
  ORA #&30
  STA W_052A
  LDX #&1B
  LDY #&02
  JSR XY_TO_NT_ADDR
IF REGION_JP
  LDA #&28
ELSE
  LDA #&2A
ENDIF
  STA Z_20
  LDA #&05
  STA Z_21
  LDA #&00
  STA Z_2E
  LDX #&01
  JMP QUEUE_PPU_RUN
.L5_802E
  RTS

; Upload four CHR tiles to PPU 1800h.
; Offset is LEVEL_CHR_OFF indexed by W_04E3, times 16, from LEVEL_OBJ_TILES. Calls CHOOSE_LEVEL_CHR first.
.UPLOAD_LEVEL_CHR
  JSR CHOOSE_LEVEL_CHR
  LDX W_04E3
  LDA #&00
  STA Z_21
  LDA LEVEL_CHR_OFF,X
  ASL A
  ROL Z_21
  ASL A
  ROL Z_21
  ASL A
  ROL Z_21
  ASL A
  ROL Z_21
  CLC
  ADC #LO(LEVEL_OBJ_TILES)
  STA Z_20
  LDA Z_21
  ADC #HI(LEVEL_OBJ_TILES)
  STA Z_21
  LDA #&00
  STA Z_22
  LDA #&18
  STA Z_23
  LDX #&06
  LDY #&04
  JMP UPLOAD_CHR_RAW

; Pick W_04E3 for this area and stage from LEVEL_CHR_PICK.
; In: Z_4B, Z_4C, W_04E4, Z_AD, Z_AE, Z_AF. Out: W_04E3. Uses NEXT_RNG.
.CHOOSE_LEVEL_CHR
  ABS_LDA Z_4B
  ASL A
  ASL A
  ASL A
  ABS_ORA Z_4C
  STA Z_1C
  ASL A
  CLC
  ADC Z_1C
  TAX
  LDA D5_80CD,X
  STA Z_1E
  LDA W_04E4
  CMP Z_1C
  BNE L5_808D
  LDA LEVEL_CHR_PICK,X
  CMP #&01
  BEQ L5_8089
  CMP #&00
  BNE L5_808D
.L5_8089
  LDA #&19
  STA Z_1E
.L5_808D
  JSR NEXT_RNG
  CMP Z_1E
  BCC L5_8097
  BEQ L5_8097
  INX
.L5_8097
  LDA LEVEL_CHR_PICK,X
  STA W_04E3
  CMP #&02
  BEQ L5_80C0
  CMP #&06
  BEQ L5_80B5
  CMP #&07
  BEQ L5_80AA
  RTS
.L5_80AA
  ABS_LDA Z_AE
  BEQ L5_80CA
  LDA #&09
  STA W_04E3
  RTS
.L5_80B5
  ABS_LDA Z_AD
  BEQ L5_80CA
  LDA #&09
  STA W_04E3
  RTS
.L5_80C0
  ABS_LDA Z_AF
  BEQ L5_80CA
  LDA #&0A
  STA W_04E3
.L5_80CA
  RTS

; 48 stages, 3 bytes each: tile id, alternate id, RNG threshold.
; Index is (area*8+stage)*3. CHOOSE_LEVEL_CHR reads the threshold two bytes later. Ids 02, 06 and 07 are replaced when Z_AF, Z_AD or Z_AE is set.
.LEVEL_CHR_PICK
  EQUB &01,&09
.D5_80CD
  EQUB &C0,&00,&09,&C0,&01,&09,&C0,&02,&0A,&FF,&00,&09,&FF,&08,&00,&FF
  EQUB &01,&09,&FF,&02,&0A,&FF,&03,&00,&FF,&00,&09,&FF,&04,&05,&40,&02
  EQUB &0A,&FF,&00,&09,&99,&08,&00,&FF,&01,&09,&FF,&00,&09,&99,&02,&0A
  EQUB &FF,&04,&05,&C0,&06,&09,&FF,&00,&09,&FF,&01,&09,&FF,&08,&00,&FF
  EQUB &02,&0A,&FF,&00,&09,&80,&01,&09,&80,&00,&09,&FF,&04,&05,&80,&02
  EQUB &0A,&FF,&00,&09,&80,&08,&00,&FF,&01,&09,&80,&00,&09,&80,&01,&09
  EQUB &99,&00,&09,&99,&02,&0A,&FF,&04,&05,&C0,&00,&09,&FF,&08,&00,&FF
  EQUB &07,&09,&FF,&00,&09,&99,&02,&0A,&FF,&06,&09,&FF,&00,&09,&FF,&04
  EQUB &05,&FF,&01,&09,&C0,&08,&00,&FF,&00,&09,&80,&01,&09,&80

; 13 bytes. W_04E3 selects an entry; the value times 16 is the CHR offset used by UPLOAD_LEVEL_CHR.
.LEVEL_CHR_OFF
  EQUB &00,&00,&00,&04,&08,&0C,&10,&14,&18,&20,&1C,&00,&00

; Per-frame actor update. Called from UPDATE_PLAYERS.
; Runs SERVICE_DEMO_PAD. If Z_B7 is set, advances it and draws slot 0 unless Z_4E is 0 and Z_B7 has reached 20h.
; Otherwise walks the three Z_69 slots, then SHARE_ACTOR_A6, CHECK_ACTORS_LEFT and FOLLOW_ACTOR_SCROLL.
.UPDATE_ACTORS
  JSR SERVICE_DEMO_PAD
  LDA Z_B7
  BEQ L5_818F
  INC Z_B7
  ABS_LDA Z_4E
  BNE L5_817C
  LDA Z_B7
  CMP #&20
  BCS L5_818E
.L5_817C
  LDX #&00
  STX W_04C2
  STX W_04C1
  STX Z_68
  STX Z_7E
  JSR LOAD_ACTOR_WORK
  JMP DRAW_ACTOR
.L5_818E
  RTS
.L5_818F
  JSR UPDATE_ROUND
  ABS_LDX Z_49
  STX Z_68
.L5_8197
  LDX Z_68
  LDA Z_69,X
  BEQ L5_81AF
  JSR LOAD_ACTOR_WORK
  JSR LOAD_ACTOR_PAD
  JSR MOVE_ACTOR
  JSR ACTOR_HIT_TEST
  JSR DRAW_ACTOR
  JSR STORE_ACTOR_WORK
.L5_81AF
  DEC Z_68
  BPL L5_8197
  JSR SHARE_ACTOR_A6
  JSR CHECK_ACTORS_LEFT
  JMP FOLLOW_ACTOR_SCROLL

; Copy the pad for actor X into W_04C2 and W_04C1.
; Demo playback returns immediately. Story mode uses JOY_HELD and JOY_NEW. Other modes use JOYPAD1,X. If Z_A6 is negative and its low bits are 2, bit 7 of W_04C1 is set.
.LOAD_ACTOR_PAD
  LDA W_03EF
  BNE L5_81E4
  ABS_LDA Z_49
  BEQ L5_81E5
  LDA JOYPAD1,X
  STA W_04C2
  LDA JOYPAD1_NEW,X
  STA W_04C1
  LDA Z_A6
  BPL L5_81E4
  AND #&03
  CMP #&02
  BNE L5_81E4
  LDA W_04C1
  ORA #&80
  STA W_04C1
.L5_81E4
  RTS
.L5_81E5
  LDA JOY_HELD
  STA W_04C2
  LDA JOY_NEW
  STA W_04C1
  RTS

; Copy actor slot Z_68 from Z_69 through Z_99 into the work bytes Z_9C through Z_AC.
.LOAD_ACTOR_WORK
  LDX Z_68
  LDA Z_69,X
  STA Z_9C
  LDA Z_6C,X
  STA Z_9D
  LDA Z_6F,X
  STA Z_9E
  LDA Z_72,X
  STA Z_9F
  LDA Z_75,X
  STA Z_A0
  LDA Z_78,X
  STA Z_A1
  LDA Z_7B,X
  STA Z_A2
  LDA Z_7E,X
  STA Z_A3
  LDA Z_81,X
  STA Z_A4
  LDA Z_84,X
  STA Z_A5
  LDA Z_87,X
  STA Z_A6
  LDA Z_8A,X
  STA Z_A7
  LDA Z_8D,X
  STA Z_A8
  LDA Z_90,X
  STA Z_A9
  LDA Z_93,X
  STA Z_AA
  LDA Z_96,X
  STA Z_AB
  LDA Z_99,X
  STA Z_AC
  RTS

; Write work bytes Z_9C through Z_AC back to actor slot Z_68.
.STORE_ACTOR_WORK
  LDX Z_68
  LDA Z_9C
  STA Z_69,X
  LDA Z_9D
  STA Z_6C,X
  LDA Z_9E
  STA Z_6F,X
  LDA Z_9F
  STA Z_72,X
  LDA Z_A0
  STA Z_75,X
  LDA Z_A1
  STA Z_78,X
  LDA Z_A2
  STA Z_7B,X
  LDA Z_A3
  STA Z_7E,X
  LDA Z_A4
  STA Z_81,X
  LDA Z_A5
  STA Z_84,X
  LDA Z_A6
  STA Z_87,X
  LDA Z_A7
  STA Z_8A,X
  LDA Z_A8
  STA Z_8D,X
  LDA Z_A9
  STA Z_90,X
  LDA Z_AA
  STA Z_93,X
  LDA Z_AB
  STA Z_96,X
  LDA Z_AC
  STA Z_99,X
  RTS

; (not seen executing during the coverage runs)

; Set bit 6 of Z_9C and store 8 in W_04E9. DRAW_ACTOR uses that bit with FLASH_DRAW_MASK.
.SET_ACTOR_FLASH
  LDA Z_9C
  ORA #&40
  STA Z_9C
  LDA #&08
  STA W_04E9
  LDA #&00
  STA W_04EA
  RTS

; Clear bit 6 of Z_9C.
.CLR_ACTOR_FLASH
  LDA Z_9C
  AND #&BF
  STA Z_9C
  RTS

; 16 bytes. DRAW_ACTOR indexes with (FRAME_CNT and 7) or W_04E9. A 0 skips the sprite while Z_9C bit 6 is set.
.FLASH_DRAW_MASK
  EQUB &01,&01,&01,&01,&01,&01,&00,&00,&01,&00,&01,&00,&01,&00,&01,&00

; If Z_A5 and Z_B0 are both 0, scan 3Ch slots at X_60E2.
; A slot whose X_611E and X_615A match Z_9D and Z_9E jumps to L7_CEA4.
.ACTOR_HIT_TEST
  LDA Z_A5
  ORA Z_B0
  BNE L5_82C9
  LDX #&3B
.L5_82B0
  LDA X_60E2,X
  BEQ L5_82C6
  LDA X_611E,X
  CMP Z_9D
  BNE L5_82C6
  LDA X_615A,X
  CMP Z_9E
  BNE L5_82C6
  JMP L7_CEA4
.L5_82C6
  DEX
  BPL L5_82B0
.L5_82C9
  RTS

; If Z_53 and W_051B are 0: story mode sets Z_53 when slot 0 is empty.
; Other modes count live Z_69 slots and, if fewer than 2 remain, increment W_051B and X_6000.
.CHECK_ACTORS_LEFT
  ABS_LDA Z_53
  ORA W_051B
  BNE L5_82EB
  ABS_LDX Z_49
  BEQ L5_82EC
  LDY #&00
.L5_82D9
  LDA Z_69,X
  BEQ L5_82DE
  INY
.L5_82DE
  DEX
  BPL L5_82D9
  CPY #&02
  BCS L5_82EB
  INC W_051B
  INC X_6000
.L5_82EB
  RTS
.L5_82EC
  LDA Z_69,X
  BNE L5_82EB
  ABS_INC Z_53
  RTS

; One actor step. Z_A5 counts a death animation from DEATH_FRAME_TIME and then clears the slot.
; A negative Z_B5 takes KNOCK_STEP. Otherwise updates the cell, moves, checks the cell, animates, and handles buttons.
.MOVE_ACTOR
  LDA Z_A5
  BNE L5_8315
  LDA Z_B5
  BPL L5_82FF
  JMP KNOCK_STEP
.L5_82FF
  JSR ACTOR_XY_TO_CELL
  JSR APPLY_ACTOR_SPEED
  JSR TOUCH_MAP_CELL
  JSR ANIM_ACTOR_WALK
  JSR HANDLE_ACTOR_BTN
  JSR TICK_TIMED_POWERS
  JSR TICK_ACTOR_A6
  RTS
.L5_8315
  DEC Z_A4
  BNE L5_8336
  INC Z_A3
  LDX Z_A3
  LDA DEATH_FRAME_TIME,X
  STA Z_A4
  CPX #&0A
  BCC L5_8336
  LDA #&00
  STA Z_9C
  STA Z_A5
  ABS_LDA Z_49
  BNE L5_8336
  LDA #&12
  JSR AUDIO_CALL
.L5_8336
  RTS

; 10 bytes. Death-frame index added to 0Ch by DRAW_ACTOR while Z_A5 is set. MOVE_ACTOR clears the actor when the index reaches 0Ah.
.DEATH_FRAME_IDX
  EQUB &00,&01,&00,&01,&00,&02,&03,&04,&05,&06

; 10 bytes. Frame time reloaded into Z_A4 for each death frame.
.DEATH_FRAME_TIME
  EQUB &08,&08,&08,&08,&0A,&0A,&0A,&0A,&0A,&0A

; Cell from pixels. Z_9D is Z_9F with the high bit from Z_A0, divided by 16. Z_9E is Z_A1 divided by 16.
.ACTOR_XY_TO_CELL
  LDA Z_A0
  LSR A
  LDA Z_9F
  ROR A
  LSR A
  LSR A
  LSR A
  STA Z_9D
  LDA Z_A1
  LSR A
  LSR A
  LSR A
  LSR A
  STA Z_9E
  RTS

; If a direction is held in W_04C2, advance Z_A4 mod 8 and Z_A3 mod 4. Otherwise zero both.
.ANIM_ACTOR_WALK
  LDA W_04C2
  AND #&0F
  BEQ L5_8379
  INC Z_A4
  LDA Z_A4
  AND #&07
  STA Z_A4
  BNE L5_8378
  INC Z_A3
  LDA Z_A3
  AND #&03
  STA Z_A3
.L5_8378
  RTS
.L5_8379
  LDA #&00
  STA Z_A4
  STA Z_A3
  RTS

; Add one speed pair from ACTOR_SPEED_LO to Z_AB and Z_AC.
; Speed index is Z_B3, or Z_A6 low bits plus 5 when Z_A6 is negative and those bits are under 2.
; Z_AC is how many single steps to take. Right, left, up, down in W_04C2, in that order.
.APPLY_ACTOR_SPEED
  LDA Z_A6
  BPL L5_838F
  AND #&03
  CMP #&02
  BCS L5_838F
  CLC
  ADC #&05
  BNE L5_8391
.L5_838F
  LDA Z_B3
.L5_8391
  ASL A
  TAX
  LDA Z_AB
  CLC
  ADC ACTOR_SPEED_LO,X
  STA Z_AB
  LDA ACTOR_SPEED_HI,X
  ADC #&00
  STA Z_AC
  BEQ L5_83C1
  LDX W_04C2
  TXA
  AND #&01
  BNE L5_83C2
  TXA
  AND #&02
  BNE L5_8402
  TXA
  AND #&08
  BEQ L5_83B9
  JMP L5_8446
.L5_83B9
  TXA
  AND #&04
  BEQ L5_83C1
  JMP L5_8482
.L5_83C1
  RTS
.L5_83C2
  LDA #&01
  STA Z_A2
  JSR BIAS_CELL_Y
  LDY Z_29
  JSR MAP_ROW_PTR
  LDY Z_28
  INY
  LDA (Z_2F),Y
  STA W_051D
.L5_83D6
  JSR STEP_ACTOR_EAST
  DEC Z_AC
  BNE L5_83D6
  RTS

; One pixel east. Facing Z_A2 becomes 1. Blocked when the low nibble of Z_9F is at least 8 and CELL_BLOCKS_MOVE says the cell ahead is solid.
.STEP_ACTOR_EAST
  LDA Z_9F
  AND #&0F
  CMP #&08
  BCC L5_83FB
  LDA W_051D
  JSR CELL_BLOCKS_MOVE
  BNE L5_8401
  JSR SLIDE_ACTOR_Y
  BCC L5_8401
  JSR CELL_EAST_OF
  JSR CELL_BLOCKS_MOVE
  BNE L5_8401
.L5_83FB
  INC Z_9F
  BNE L5_8401
  INC Z_A0
.L5_8401
  RTS
.L5_8402
  LDA #&03
  STA Z_A2
  JSR BIAS_CELL_Y
  LDY Z_29
  JSR MAP_ROW_PTR
  LDY Z_28
  DEY
  LDA (Z_2F),Y
  STA W_051D
.L5_8416
  JSR STEP_ACTOR_WEST
  DEC Z_AC
  BNE L5_8416
  RTS

; One pixel west. Facing Z_A2 becomes 3. Same solid test as STEP_ACTOR_EAST, using the west cell.
.STEP_ACTOR_WEST
  LDA Z_9F
  AND #&0F
  CMP #&09
  BCS L5_843B
  LDA W_051D
  JSR CELL_BLOCKS_MOVE
  BNE L5_8445
  JSR SLIDE_ACTOR_Y
  BCC L5_8445
  JSR CELL_WEST_OF
  JSR CELL_BLOCKS_MOVE
  BNE L5_8445
.L5_843B
  DEC Z_9F
  LDA Z_9F
  CMP #&FF
  BNE L5_8445
  DEC Z_A0
.L5_8445
  RTS
.L5_8446
  LDA #&02
  STA Z_A2
  JSR BIAS_CELL_X
  LDY Z_29
  DEY
  JSR MAP_ROW_PTR
  LDY Z_28
  LDA (Z_2F),Y
  STA W_051D
.L5_845A
  JSR STEP_ACTOR_NORTH
  DEC Z_AC
  BNE L5_845A
  RTS

; One pixel north. Facing Z_A2 becomes 2. Tests the cell above when the low nibble of Z_A1 is below 9.
.STEP_ACTOR_NORTH
  LDA Z_A1
  AND #&0F
  CMP #&09
  BCS L5_847F
  LDA W_051D
  JSR CELL_BLOCKS_MOVE
  BNE L5_8481
  JSR SLIDE_ACTOR_X
  BCC L5_8481
  JSR CELL_NORTH_OF
  JSR CELL_BLOCKS_MOVE
  BNE L5_8481
.L5_847F
  DEC Z_A1
.L5_8481
  RTS
.L5_8482
  LDA #&00
  STA Z_A2
  JSR BIAS_CELL_X
  LDY Z_29
  INY
  JSR MAP_ROW_PTR
  LDY Z_28
  LDA (Z_2F),Y
  STA W_051D
.L5_8496
  JSR STEP_ACTOR_SOUTH
  DEC Z_AC
  BNE L5_8496
  RTS

; One pixel south. Facing Z_A2 becomes 0. Tests the cell below when the low nibble of Z_A1 is at least 8.
.STEP_ACTOR_SOUTH
  LDA Z_A1
  AND #&0F
  CMP #&08
  BCC L5_84BB
  LDA W_051D
  JSR CELL_BLOCKS_MOVE
  BNE L5_84BD
  JSR SLIDE_ACTOR_X
  BCC L5_84BD
  JSR CELL_SOUTH_OF
  JSR CELL_BLOCKS_MOVE
  BNE L5_84BD
.L5_84BB
  INC Z_A1
.L5_84BD
  RTS

; Point Z_28 and Z_29 at the cell one tile east of the actor, then PEEK_CELL_28. Out: A is the map byte.
.CELL_EAST_OF
  LDA Z_9F
  CLC
  ADC #&08
  STA Z_20
  LDA Z_A0
  ADC #&00
  LSR A
  LDA Z_20
  ROR A
  LSR A
  LSR A
  LSR A
  STA Z_28
  LDA Z_A1
  LSR A
  LSR A
  LSR A
  LSR A
  STA Z_29
  JMP PEEK_CELL_28

; Cell one tile west of the actor. Out: A from PEEK_CELL_28.
.CELL_WEST_OF
  LDA Z_9F
  SEC
  SBC #&09
  STA Z_20
  LDA Z_A0
  SBC #&00
  LSR A
  LDA Z_20
  ROR A
  LSR A
  LSR A
  LSR A
  STA Z_28
  LDA Z_A1
  LSR A
  LSR A
  LSR A
  LSR A
  STA Z_29
  JMP PEEK_CELL_28

; Cell one tile north of the actor. Out: A from PEEK_CELL_28.
.CELL_NORTH_OF
  LDA Z_A0
  LSR A
  LDA Z_9F
  ROR A
  LSR A
  LSR A
  LSR A
  STA Z_28
  LDA Z_A1
  SEC
  SBC #&09
  LSR A
  LSR A
  LSR A
  LSR A
  STA Z_29
  JMP PEEK_CELL_28

; Cell one tile south of the actor. Out: A from PEEK_CELL_28.
.CELL_SOUTH_OF
  LDA Z_A0
  LSR A
  LDA Z_9F
  ROR A
  LSR A
  LSR A
  LSR A
  STA Z_28
  LDA Z_A1
  CLC
  ADC #&08
  LSR A
  LSR A
  LSR A
  LSR A
  STA Z_29
  JMP PEEK_CELL_28

; Read the live map at column Z_28, row Z_29. Out: A. Uses MAP_ROW_PTR.
.PEEK_CELL_28
  LDY Z_29
  JSR MAP_ROW_PTR
  LDY Z_28
  LDA (Z_2F),Y
  RTS

; Seven little-endian speed pairs, low byte here and high byte at ACTOR_SPEED_HI: 0100 0140 0180 01C0 0200 0300 0080.
; APPLY_ACTOR_SPEED indexes with the speed times 2. Added into Z_AB and Z_AC.
.ACTOR_SPEED_LO
  EQUB &00
.ACTOR_SPEED_HI
  EQUB &01,&40,&01,&80,&01,&C0,&01,&00,&02,&00,&03,&80,&00

; For a vertical step, set Z_28 from Z_9D plus BIAS_DELTA. The delta index comes from SUBPIX_BIAS when the low 5 bits of Z_9F are below 10h, else 0. Z_29 is Z_9E.
.BIAS_CELL_X
  LDY #&00
  LDA Z_9F
  AND #&1F
  CMP #&10
  BCS L5_8555
  TAY
  LDA SUBPIX_BIAS,Y
  TAY
.L5_8555
  LDA Z_9D
  CLC
  ADC BIAS_DELTA,Y
  STA Z_28
  LDA Z_9E
  STA Z_29
  RTS

; For a horizontal step, set Z_29 from Z_9E plus BIAS_DELTA. Same sub-pixel rule on Z_A1. Z_28 is Z_9D.
.BIAS_CELL_Y
  LDY #&00
  LDA Z_A1
  AND #&1F
  CMP #&10
  BCS L5_8571
  TAY
  LDA SUBPIX_BIAS,Y
  TAY
.L5_8571
  LDA Z_9E
  CLC
  ADC BIAS_DELTA,Y
  STA Z_29
  LDA Z_9D
  STA Z_28
  RTS

; If the actor X sub-pixel is not centered, step west or east with the held direction and return carry clear. Centered returns carry set.
.SLIDE_ACTOR_X
  LDA Z_9F
  AND #&1F
  TAY
  LDA SUBPIX_BIAS,Y
  BEQ L5_85A4
  CMP #&01
  BEQ L5_8598
.L5_858C
  LDA W_04C2
  AND #&01
  BNE L5_859F
  JSR STEP_ACTOR_WEST
  CLC
  RTS
.L5_8598
  LDA W_04C2
  AND #&02
  BNE L5_858C
.L5_859F
  JSR STEP_ACTOR_EAST
  CLC
  RTS
.L5_85A4
  SEC
  RTS

; If the actor Y sub-pixel is not centered, step north or south and return carry clear. Centered returns carry set.
.SLIDE_ACTOR_Y
  LDA Z_A1
  AND #&1F
  TAY
  LDA SUBPIX_BIAS,Y
  BEQ L5_85A4
  CMP #&01
  BEQ L5_85C0
  LDA W_04C2
  AND #&04
  BNE L5_85C7
.L5_85BB
  JSR STEP_ACTOR_NORTH
  CLC
  RTS
.L5_85C0
  LDA W_04C2
  AND #&08
  BNE L5_85BB
.L5_85C7
  JSR STEP_ACTOR_SOUTH
  CLC
  RTS

; 32 bytes, one per sub-pixel 0-1Fh. Value is an index into BIAS_DELTA. 0 means centered.
.SUBPIX_BIAS
  EQUB &02,&02,&02,&02,&02,&02,&02,&02,&00,&01,&01,&01,&01,&01,&01,&01
  EQUB &01,&01,&01,&01,&01,&01,&01,&01,&00,&02,&02,&02,&02,&02,&02,&02

; Three signed cell deltas: 0, +1, -1. Indexed by SUBPIX_BIAS.
.BIAS_DELTA
  EQUB &00,&01,&FF

; Knockback step. Decrements Z_B6 and clears Z_B5 at 0.
; Otherwise refreshes the cell, forces Z_AC to 4, clears the pad, and steps on the low 2 bits of Z_B5. Facing is then flipped with EOR 2.
.KNOCK_STEP
  DEC Z_B6
  BEQ L5_861F
  JSR ACTOR_XY_TO_CELL
  JSR SETUP_KNOCKBACK
  JSR TOUCH_MAP_CELL
  LDA Z_A2
  EOR #&02
  STA Z_A2
  RTS

; Called from KNOCK_STEP. Sets Z_AC to 4, clears W_04C2 and W_04C1, and jumps to the step for Z_B5 bits 0-1: up, left, down, right.
.SETUP_KNOCKBACK
  LDA #&04
  STA Z_AC
  LDA #&00
  STA W_04C2
  STA W_04C1
  LDA Z_B5
  AND #&03
  TAX
  BEQ L5_8624
  DEX
  BEQ L5_8627
  DEX
  BEQ L5_862A
  DEX
  BEQ L5_862D
.L5_861F
  LDA #&00
  STA Z_B5
  RTS
.L5_8624
  JMP L5_8446
.L5_8627
  JMP L5_8402
.L5_862A
  JMP L5_8482
.L5_862D
  JMP L5_83C2

; If Z_A6 is negative, count down Z_A7 every frame and Z_A8 every 3Ch frames.
; At zero, clear Z_A6 and call QUEUE_A6_CLEAR.
.TICK_ACTOR_A6
  LDA Z_A6
  BPL L5_8647
  DEC Z_A7
  BNE L5_8647
  LDA #&3C
  STA Z_A7
  DEC Z_A8
  BNE L5_8647
  LDA #&00
  STA Z_A6
  JSR QUEUE_A6_CLEAR
.L5_8647
  RTS

; (not seen executing during the coverage runs)

; Reached from ITEM_HANDLERS. NEXT_RNG picks 0-3, stores that value ORed with 80h in Z_A6, a duration from A6_TIME_TAB in Z_A8, and 3Ch in Z_A7. Then QUEUE_A6_ATTR.
.ROLL_ACTOR_A6
  JSR NEXT_RNG
  AND #&03
  TAY
  ORA #&80
  STA Z_A6
  LDA A6_TIME_TAB,Y
  STA Z_A8
  LDA #&3C
  STA Z_A7
  JMP QUEUE_A6_ATTR

; Four durations for ROLL_ACTOR_A6: 1Eh, 14h, 1Eh, 0Fh. Stored in Z_A8.
.A6_TIME_TAB
  EQUB &1E,&14,&1E,&0F

; Only when Z_49 is 2. If two live actors share a cell and exactly one has a nonzero Z_87, copy Z_87, Z_8A and Z_8D to the other, call QUEUE_A6_ATTR, and play sound 5.
.SHARE_ACTOR_A6
  ABS_LDA Z_49
  CMP #&02
  BNE L5_86E3
  LDX #&00
.L5_866B
  LDA Z_69,X
  BEQ L5_86DE
  BMI L5_86DE
  TXA
  TAY
  INY
.L5_8674
  LDA Z_69,Y
  BEQ L5_86D9
  BMI L5_86D9
  LDA Z_6C,X
  CMP Z_6C,Y
  BNE L5_86D9
  LDA Z_6F,X
  CMP Z_6F,Y
  BNE L5_86D9
  LDA Z_87,X
  BNE L5_86B3
  LDA Z_87,Y
  BEQ L5_86D9
  STA Z_87,X
  LDA Z_8A,Y
  STA Z_8A,X
  LDA Z_8D,Y
  STA Z_8D,X
  STX Z_68
  TXA
  PHA
  TYA
  PHA
  JSR QUEUE_A6_ATTR
  LDA #&05
  JSR AUDIO_CALL
  PLA
  TAY
  PLA
  TAX
  JMP L5_86D9
.L5_86B3
  LDA Z_87,Y
  BNE L5_86D9
  LDA Z_87,X
  STA Z_87,Y
  LDA Z_8A,X
  STA Z_8A,Y
  LDA Z_8D,X
  STA Z_8D,Y
  STY Z_68
  TXA
  PHA
  TYA
  PHA
  JSR QUEUE_A6_ATTR
  LDA #&05
  JSR AUDIO_CALL
  PLA
  TAY
  PLA
  TAX
.L5_86D9
  INY
  CPY #&03
  BCC L5_8674
.L5_86DE
  INX
  CPX #&02
  BCC L5_866B
.L5_86E3
  RTS

; Queue the two bytes at A6_ATTR_ON onto the attribute address for actor Z_68.
; XY comes from A6_ATTR_XY. Z_2E is 0.
.QUEUE_A6_ATTR
  LDA Z_68
  ASL A
  TAX
  LDY D5_8723,X
  LDA A6_ATTR_XY,X
  TAX
  JSR XY_TO_ATTR
  LDA #LO(A6_ATTR_ON)
  STA Z_20
  LDA #HI(A6_ATTR_ON)
  STA Z_21
  LDX #&02
  LDA #&00
  STA Z_2E
  JMP QUEUE_PPU_RUN

; Queue the two bytes at A6_ATTR_OFF. Same attribute address as QUEUE_A6_ATTR.
.QUEUE_A6_CLEAR
  LDA Z_68
  ASL A
  TAX
  LDY D5_8723,X
  LDA A6_ATTR_XY,X
  TAX
  JSR XY_TO_ATTR
  LDA #LO(A6_ATTR_OFF)
  STA Z_20
  LDA #HI(A6_ATTR_OFF)
  STA Z_21
  LDX #&02
  LDA #&00
  STA Z_2E
  JMP QUEUE_PPU_RUN

; Six bytes, three XY pairs for actors 0-2: (02,02), (09,02), (10,02). Passed to XY_TO_ATTR. The next four bytes are FF FF 00 00 and are not read as pairs.
.A6_ATTR_XY
  EQUB &02
.D5_8723
  EQUB &02,&09,&02,&10,&02
.A6_ATTR_ON
  EQUB &FF                              ; Two FFh bytes queued by QUEUE_A6_ATTR.
  EQUB &FF
.A6_ATTR_OFF
  EQUB &00                              ; Two 00h bytes queued by QUEUE_A6_CLEAR.
  EQUB &00

; Count down W_04E6 via W_04E7 and W_04E8, or else Z_B0 via Z_B1 and Z_B2.
; Each tick is 3Ch frames. Below 4 remaining, play sound 9. At 3, clear W_04E9. At the end, clear the flag and CLR_ACTOR_FLASH.
.TICK_TIMED_POWERS
  LDA W_04E6
  BEQ L5_875A
  DEC W_04E7
  BPL L5_8780
  LDA #&3B
  STA W_04E7
  DEC W_04E8
  BMI L5_8752
  LDA W_04E8
  CMP #&03
  BNE L5_874C
  LDA #&00
  STA W_04E9
.L5_874C
  LDA W_04E8
  JMP L5_8777
.L5_8752
  LDA #&00
  STA W_04E6
  JMP CLR_ACTOR_FLASH
.L5_875A
  LDA Z_B0
  BEQ L5_8780
  DEC Z_B1
  BPL L5_8780
  LDA #&3B
  STA Z_B1
  DEC Z_B2
  BMI L5_8781
  LDA Z_B2
  CMP #&03
  BNE L5_8775
  LDA #&00
  STA W_04E9
.L5_8775
  LDA Z_B2
.L5_8777
  CMP #&04
  BCS L5_8780
  LDA #&09
  JSR AUDIO_CALL
.L5_8780
  RTS
.L5_8781
  LDA #&00
  STA Z_B0
  JMP CLR_ACTOR_FLASH

; In: A is a map byte. Out: A is 0 if the actor may enter.
; Bit 6 or a zero byte returns 0. Bit 5 returns Z_AD EOR 1. Bit 4 returns Z_AE EOR 1. Any other nonzero byte returns 0.
.CELL_BLOCKS_MOVE
  TAX
  BEQ L5_879B
  AND #&40
  BNE L5_879B
  TXA
  AND #&20
  BNE L5_879C
  TXA
  AND #&10
  BNE L5_87A1
  LDA #&00
.L5_879B
  RTS
.L5_879C
  LDA Z_AD
  EOR #&01
  RTS
.L5_87A1
  LDA Z_AE
  EOR #&01
  RTS

; Bit 7 of W_04C1 stores Z_9D and Z_9E and jumps to L7_CF96.
; Bit 6 jumps to L7_CFD4 when Z_AF is set.
.HANDLE_ACTOR_BTN
  LDA W_04C1
  TAX
  AND #&80
  BNE L5_87B4
  TXA
  AND #&40
  BNE L5_87BF
  RTS
.L5_87B4
  LDA Z_9D
  STA Z_1C
  LDA Z_9E
  STA Z_1D
  JMP L7_CF96
.L5_87BF
  LDA Z_AF
  BEQ L5_87C6
  JMP L7_CFD4
.L5_87C6
  RTS

; Four bytes added to the walk frame for facing Z_A2: 8, 0, 4, 0.
.FACE_FRAME_ADD
  EQUB &08,&00,&04,&00

; Four attribute bytes for facing Z_A2, stored in Z_5A by DRAW_ACTOR: 00, 40h, 00, 00.
.FACE_ATTR
  EQUB &00,&40,&00,&00

; Draw actor Z_68 through DRAW_METASPRITE.
; Frame list is ACTOR_FR_PTR. A set bit 6 of Z_9C can skip the draw via FLASH_DRAW_MASK. Death uses DEATH_FRAME_IDX plus 0Ch. Sprite Y is Z_A1 plus 20h.
.DRAW_ACTOR
  LDA Z_9C
  BEQ L5_8824
  AND #&40
  BEQ L5_87E4
  LDA FRAME_CNT
  AND #&07
  ORA W_04E9
  TAY
  LDA FLASH_DRAW_MASK,Y
  BEQ L5_8824
.L5_87E4
  LDA Z_68
  ASL A
  TAX
  LDA ACTOR_FR_PTR,X
  STA Z_20
  LDA D5_8843,X
  STA Z_21
  LDA Z_9F
  ABS_STA Z_56
  LDA Z_A0
  ABS_STA Z_57
  LDA Z_A1
  CLC
  ADC #&20
  ABS_STA Z_58
  LDA Z_A5
  BNE L5_8825
  LDX Z_A2
  LDA FACE_ATTR,X
  ABS_STA Z_5A
  LDA FACE_FRAME_ADD,X
  CLC
  ADC Z_A3
  ASL A
  TAY
  LDA (Z_20),Y
  STA Z_54
  INY
  LDA (Z_20),Y
  STA Z_55
  JMP DRAW_METASPRITE
.L5_8824
  RTS
.L5_8825
  LDA #&00
  STA Z_A2
  ABS_STA Z_5A
  LDX Z_A3
  LDA DEATH_FRAME_IDX,X
  CLC
  ADC #&0C
  ASL A
  TAY
  LDA (Z_20),Y
  STA Z_54
  INY
  LDA (Z_20),Y
  STA Z_55
  JMP DRAW_METASPRITE

; Three words, one frame list per actor slot: ACTOR0_FRAMES, ACTOR1_FRAMES, ACTOR2_FRAMES.
.ACTOR_FR_PTR
  EQUB LO(ACTOR0_FRAMES)
.D5_8843
  EQUB HI(ACTOR0_FRAMES)
  EQUW ACTOR1_FRAMES
  EQUW ACTOR2_FRAMES

; 19 words. Walk and death metasprite pointers for actor 0. DRAW_ACTOR indexes with the frame times 2.
.ACTOR0_FRAMES
  EQUW D5_898D
  EQUW D5_89AA
  EQUW D5_898D
  EQUW D5_8970
  EQUW D5_8932
  EQUW D5_8953
  EQUW D5_8932
  EQUW D5_8915
  EQUW D5_88D7
  EQUW D5_88F8
  EQUW D5_88D7
  EQUW ACTOR_SPRITES
  EQUW D5_89C7
  EQUW D5_89E8
  EQUW D5_8A11
  EQUW D5_8A32
  EQUW D5_8A63
  EQUW D5_8A94
  EQUW D5_8AC5

; 19 words. Same frame order as ACTOR0_FRAMES, for actor 1.
.ACTOR1_FRAMES
  EQUW D5_8BC9
  EQUW D5_8BE6
  EQUW D5_8BC9
  EQUW D5_8BAC
  EQUW D5_8B6E
  EQUW D5_8B8F
  EQUW D5_8B6E
  EQUW D5_8B51
  EQUW D5_8B13
  EQUW D5_8B34
  EQUW D5_8B13
  EQUW D5_8AF6
  EQUW D5_8C03
  EQUW D5_8C24
  EQUW D5_8C4D
  EQUW D5_8C6E
  EQUW D5_8C9F
  EQUW D5_8CD0
  EQUW D5_8D01

; 19 words. Same frame order as ACTOR0_FRAMES, for actor 2. Targets sit inside ACTOR_SPRITES.
.ACTOR2_FRAMES
  EQUW D5_8E05
  EQUW D5_8E22
  EQUW D5_8E05
  EQUW D5_8DE8
  EQUW D5_8DAA
  EQUW D5_8DCB
  EQUW D5_8DAA
  EQUW D5_8D8D
  EQUW D5_8D4F
  EQUW D5_8D70
  EQUW D5_8D4F
  EQUW D5_8D32
  EQUW D5_8E3F
  EQUW D5_8E60
  EQUW D5_8E89
  EQUW D5_8EAA
  EQUW D5_8EDB
  EQUW D5_8F0C
  EQUW D5_8F3D

; Metasprites for DRAW_METASPRITE. First byte is the sprite count, then count groups of tile, dx, dy, attr.
; ACTOR0_FRAMES and ACTOR1_FRAMES point at the separate blobs. ACTOR2_FRAMES points into the later bytes of this run.
.ACTOR_SPRITES
  EQUB &07,&05,&F8,&F3,&01,&06,&00,&F3,&01,&15,&F8,&FB,&03,&16,&00,&FB
  EQUB &03,&1F,&08,&FB,&03,&0E,&F8,&03,&03,&0F,&00,&03,&03
.D5_88D7
  EQUB &08,&04,&F9,&F3,&41,&04,&00,&F3,&01,&1F,&F2,&FC,&43,&14,&F9,&FB
  EQUB &43,&14,&00,&FB,&03,&1F,&07,&FD,&03,&0D,&F9,&03,&43,&0D,&00,&03
  EQUB &03
.D5_88F8
  EQUB &07,&06,&F9,&F3,&41,&05,&01,&F3,&41,&1F,&F1,&FB,&43,&16,&F9,&FB
  EQUB &43,&15,&01,&FB,&43,&0F,&F9,&03,&43,&0E,&01,&03,&43
.D5_8915
  EQUB &07,&02,&F9,&F3,&01,&03,&01,&F3,&01,&12,&F9,&FB,&03,&13,&01,&FB
  EQUB &03,&1F,&08,&FC,&03,&0F,&F9,&03,&43,&0E,&01,&03,&43
.D5_8932
  EQUB &08,&01,&F9,&F3,&41,&01,&00,&F3,&01,&1F,&F2,&FD,&43,&11,&F9,&FB
  EQUB &43,&11,&00,&FB,&03,&1F,&07,&FD,&03,&0D,&F9,&03,&43,&0D,&00,&03
  EQUB &03
.D5_8953
  EQUB &07,&03,&F8,&F3,&41,&02,&00,&F3,&41,&1F,&F1,&FC,&43,&13,&F8,&FB
  EQUB &43,&12,&00,&FB,&43,&0E,&F8,&03,&03,&0F,&00,&03,&03
.D5_8970
  EQUB &07,&09,&F7,&F3,&01,&0A,&FF,&F3,&01,&1F,&06,&F2,&01,&19,&F7,&FB
  EQUB &03,&1A,&FF,&FB,&03,&20,&F7,&02,&03,&21,&FF,&03,&03
.D5_898D
  EQUB &07,&07,&F8,&F3,&01,&08,&00,&F3,&01,&1F,&08,&F2,&01,&17,&F8,&FB
  EQUB &03,&18,&00,&FB,&03,&1D,&F8,&03,&03,&1E,&00,&03,&03
.D5_89AA
  EQUB &07,&0B,&F7,&F3,&01,&0C,&FF,&F3,&01,&1F,&07,&F2,&01,&1B,&F7,&FB
  EQUB &03,&1C,&FF,&FB,&03,&20,&F7,&03,&03,&21,&FF,&03,&03
.D5_89C7
  EQUB &08,&37,&F9,&F3,&41,&37,&00,&F3,&01,&27,&F1,&FA,&43,&26,&F9,&F9
  EQUB &43,&26,&00,&F9,&03,&27,&08,&F9,&03,&36,&F9,&01,&43,&36,&00,&01
  EQUB &03
.D5_89E8
  EQUB &0A,&37,&F9,&F3,&41,&37,&00,&F3,&01,&29,&F1,&FB,&43,&28,&F9,&FB
  EQUB &43,&28,&00,&FB,&03,&29,&08,&FB,&03,&39,&F1,&03,&43,&38,&F9,&03
  EQUB &43,&38,&00,&03,&03,&39,&08,&03,&03
.D5_8A11
  EQUB &08,&2A,&F9,&F3,&41,&2A,&00,&F3,&01,&3B,&F1,&FB,&43,&3A,&F9,&FB
  EQUB &43,&3A,&00,&FB,&03,&3B,&08,&FB,&03,&2B,&F9,&03,&43,&2B,&00,&03
  EQUB &03
.D5_8A32
  EQUB &0C,&2D,&F1,&F3,&43,&2C,&F9,&F3,&43,&2C,&00,&F3,&03,&2D,&08,&F3
  EQUB &03,&3D,&F1,&FB,&43,&3C,&F9,&FB,&43,&3C,&00,&FB,&03,&3D,&08,&FB
  EQUB &03,&2F,&F1,&03,&43,&2E,&F9,&03,&43,&2E,&00,&03,&03,&2F,&08,&03
  EQUB &03
.D5_8A63
  EQUB &0C,&3F,&F1,&F3,&43,&3E,&F9,&F3,&43,&3E,&00,&F3,&03,&3F,&08,&F3
  EQUB &03,&41,&F1,&FB,&43,&40,&F9,&FB,&43,&40,&00,&FB,&03,&41,&08,&FB
  EQUB &03,&51,&F1,&03,&43,&50,&F9,&03,&43,&50,&00,&03,&03,&51,&08,&03
  EQUB &03
.D5_8A94
  EQUB &0C,&42,&F9,&EE,&43,&42,&00,&EE,&03,&53,&F1,&F6,&43,&52,&F9,&F6
  EQUB &43,&52,&00,&F6,&03,&53,&08,&F6,&03,&53,&F1,&FE,&C3,&52,&F9,&FE
  EQUB &C3,&52,&00,&FE,&83,&53,&08,&FE,&83,&42,&F9,&06,&C3,&42,&00,&06
  EQUB &83
.D5_8AC5
  EQUB &0C,&44,&F9,&EE,&43,&44,&00,&EE,&03,&55,&F1,&F6,&43,&54,&F9,&F6
  EQUB &43,&54,&00,&F6,&03,&55,&08,&F6,&03,&55,&F1,&FE,&C3,&54,&F9,&FE
  EQUB &C3,&54,&00,&FE,&83,&55,&08,&FE,&83,&44,&F9,&06,&C3,&44,&00,&06
  EQUB &83
.D5_8AF6
  EQUB &07,&05,&F8,&F3,&02,&06,&00,&F3,&02,&15,&F8,&FB,&02,&16,&00,&FB
  EQUB &02,&1F,&08,&FB,&02,&0E,&F8,&03,&02,&0F,&00,&03,&02
.D5_8B13
  EQUB &08,&04,&F9,&F3,&42,&04,&00,&F3,&02,&1F,&F2,&FC,&42,&14,&F9,&FB
  EQUB &42,&14,&00,&FB,&02,&1F,&07,&FD,&02,&0D,&F9,&03,&42,&0D,&00,&03
  EQUB &02
.D5_8B34
  EQUB &07,&06,&F9,&F3,&42,&05,&01,&F3,&42,&1F,&F1,&FB,&42,&16,&F9,&FB
  EQUB &42,&15,&01,&FB,&42,&0F,&F9,&03,&42,&0E,&01,&03,&42
.D5_8B51
  EQUB &07,&02,&F9,&F3,&02,&03,&01,&F3,&02,&12,&F9,&FB,&02,&13,&01,&FB
  EQUB &02,&1F,&08,&FC,&02,&0F,&F9,&03,&42,&0E,&01,&03,&42
.D5_8B6E
  EQUB &08,&01,&F9,&F3,&42,&01,&00,&F3,&02,&1F,&F2,&FD,&42,&11,&F9,&FB
  EQUB &42,&11,&00,&FB,&02,&1F,&07,&FD,&02,&0D,&F9,&03,&42,&0D,&00,&03
  EQUB &02
.D5_8B8F
  EQUB &07,&03,&F8,&F3,&42,&02,&00,&F3,&42,&1F,&F1,&FC,&42,&13,&F8,&FB
  EQUB &42,&12,&00,&FB,&42,&0E,&F8,&03,&02,&0F,&00,&03,&02
.D5_8BAC
  EQUB &07,&09,&F7,&F3,&02,&0A,&FF,&F3,&02,&1F,&06,&F2,&02,&19,&F7,&FB
  EQUB &02,&1A,&FF,&FB,&02,&20,&F7,&02,&02,&21,&FF,&03,&02
.D5_8BC9
  EQUB &07,&07,&F8,&F3,&02,&08,&00,&F3,&02,&1F,&08,&F2,&02,&17,&F8,&FB
  EQUB &02,&18,&00,&FB,&02,&1D,&F8,&03,&02,&1E,&00,&03,&02
.D5_8BE6
  EQUB &07,&0B,&F7,&F3,&02,&0C,&FF,&F3,&02,&1F,&07,&F2,&02,&1B,&F7,&FB
  EQUB &02,&1C,&FF,&FB,&02,&20,&F7,&03,&02,&21,&FF,&03,&02
.D5_8C03
  EQUB &08,&37,&F9,&F3,&42,&37,&00,&F3,&02,&27,&F1,&FA,&42,&26,&F9,&F9
  EQUB &42,&26,&00,&F9,&02,&27,&08,&F9,&02,&36,&F9,&01,&42,&36,&00,&01
  EQUB &02
.D5_8C24
  EQUB &0A,&37,&F9,&F3,&42,&37,&00,&F3,&02,&29,&F1,&FB,&42,&28,&F9,&FB
  EQUB &42,&28,&00,&FB,&02,&29,&08,&FB,&02,&39,&F1,&03,&42,&38,&F9,&03
  EQUB &42,&38,&00,&03,&02,&39,&08,&03,&02
.D5_8C4D
  EQUB &08,&2A,&F9,&F3,&42,&2A,&00,&F3,&02,&3B,&F1,&FB,&42,&3A,&F9,&FB
  EQUB &42,&3A,&00,&FB,&02,&3B,&08,&FB,&02,&2B,&F9,&03,&42,&2B,&00,&03
  EQUB &02
.D5_8C6E
  EQUB &0C,&2D,&F1,&F3,&42,&2C,&F9,&F3,&42,&2C,&00,&F3,&02,&2D,&08,&F3
  EQUB &02,&3D,&F1,&FB,&42,&3C,&F9,&FB,&42,&3C,&00,&FB,&02,&3D,&08,&FB
  EQUB &02,&2F,&F1,&03,&42,&2E,&F9,&03,&42,&2E,&00,&03,&02,&2F,&08,&03
  EQUB &02
.D5_8C9F
  EQUB &0C,&3F,&F1,&F3,&42,&3E,&F9,&F3,&42,&3E,&00,&F3,&02,&3F,&08,&F3
  EQUB &02,&41,&F1,&FB,&42,&40,&F9,&FB,&42,&40,&00,&FB,&02,&41,&08,&FB
  EQUB &02,&51,&F1,&03,&42,&50,&F9,&03,&42,&50,&00,&03,&02,&51,&08,&03
  EQUB &02
.D5_8CD0
  EQUB &0C,&42,&F9,&EE,&42,&42,&00,&EE,&02,&53,&F1,&F6,&42,&52,&F9,&F6
  EQUB &42,&52,&00,&F6,&02,&53,&08,&F6,&02,&53,&F1,&FE,&C2,&52,&F9,&FE
  EQUB &C2,&52,&00,&FE,&82,&53,&08,&FE,&82,&42,&F9,&06,&C2,&42,&00,&06
  EQUB &82
.D5_8D01
  EQUB &0C,&44,&F9,&EE,&42,&44,&00,&EE,&02,&55,&F1,&F6,&42,&54,&F9,&F6
  EQUB &42,&54,&00,&F6,&02,&55,&08,&F6,&02,&55,&F1,&FE,&C2,&54,&F9,&FE
  EQUB &C2,&54,&00,&FE,&82,&55,&08,&FE,&82,&44,&F9,&06,&C2,&44,&00,&06
  EQUB &82
.D5_8D32
  EQUB &07,&05,&F8,&F3,&00,&06,&00,&F3,&00,&15,&F8,&FB,&00,&16,&00,&FB
  EQUB &00,&1F,&08,&FB,&00,&0E,&F8,&03,&00,&0F,&00,&03,&00
.D5_8D4F
  EQUB &08,&04,&F9,&F3,&40,&04,&00,&F3,&00,&1F,&F2,&FC,&40,&14,&F9,&FB
  EQUB &40,&14,&00,&FB,&00,&1F,&07,&FD,&00,&0D,&F9,&03,&40,&0D,&00,&03
  EQUB &00
.D5_8D70
  EQUB &07,&06,&F9,&F3,&40,&05,&01,&F3,&40,&1F,&F1,&FB,&40,&16,&F9,&FB
  EQUB &40,&15,&01,&FB,&40,&0F,&F9,&03,&40,&0E,&01,&03,&40
.D5_8D8D
  EQUB &07,&02,&F9,&F3,&00,&03,&01,&F3,&00,&12,&F9,&FB,&00,&13,&01,&FB
  EQUB &00,&1F,&08,&FC,&00,&0F,&F9,&03,&40,&0E,&01,&03,&40
.D5_8DAA
  EQUB &08,&01,&F9,&F3,&40,&01,&00,&F3,&00,&1F,&F2,&FD,&40,&11,&F9,&FB
  EQUB &40,&11,&00,&FB,&00,&1F,&07,&FD,&00,&0D,&F9,&03,&40,&0D,&00,&03
  EQUB &00
.D5_8DCB
  EQUB &07,&03,&F8,&F3,&40,&02,&00,&F3,&40,&1F,&F1,&FC,&40,&13,&F8,&FB
  EQUB &40,&12,&00,&FB,&40,&0E,&F8,&03,&00,&0F,&00,&03,&00
.D5_8DE8
  EQUB &07,&09,&F7,&F3,&00,&0A,&FF,&F3,&00,&1F,&06,&F2,&00,&19,&F7,&FB
  EQUB &00,&1A,&FF,&FB,&00,&20,&F7,&02,&00,&21,&FF,&03,&00
.D5_8E05
  EQUB &07,&07,&F8,&F3,&00,&08,&00,&F3,&00,&1F,&08,&F2,&00,&17,&F8,&FB
  EQUB &00,&18,&00,&FB,&00,&1D,&F8,&03,&00,&1E,&00,&03,&00
.D5_8E22
  EQUB &07,&0B,&F7,&F3,&00,&0C,&FF,&F3,&00,&1F,&07,&F2,&00,&1B,&F7,&FB
  EQUB &00,&1C,&FF,&FB,&00,&20,&F7,&03,&00,&21,&FF,&03,&00
.D5_8E3F
  EQUB &08,&37,&F9,&F3,&40,&37,&00,&F3,&00,&27,&F1,&FA,&40,&26,&F9,&F9
  EQUB &40,&26,&00,&F9,&00,&27,&08,&F9,&00,&36,&F9,&01,&40,&36,&00,&01
  EQUB &00
.D5_8E60
  EQUB &0A,&37,&F9,&F3,&40,&37,&00,&F3,&00,&29,&F1,&FB,&40,&28,&F9,&FB
  EQUB &40,&28,&00,&FB,&00,&29,&08,&FB,&00,&39,&F1,&03,&40,&38,&F9,&03
  EQUB &40,&38,&00,&03,&00,&39,&08,&03,&00
.D5_8E89
  EQUB &08,&2A,&F9,&F3,&40,&2A,&00,&F3,&00,&3B,&F1,&FB,&40,&3A,&F9,&FB
  EQUB &40,&3A,&00,&FB,&00,&3B,&08,&FB,&00,&2B,&F9,&03,&40,&2B,&00,&03
  EQUB &00
.D5_8EAA
  EQUB &0C,&2D,&F1,&F3,&40,&2C,&F9,&F3,&40,&2C,&00,&F3,&00,&2D,&08,&F3
  EQUB &00,&3D,&F1,&FB,&40,&3C,&F9,&FB,&40,&3C,&00,&FB,&00,&3D,&08,&FB
  EQUB &00,&2F,&F1,&03,&40,&2E,&F9,&03,&40,&2E,&00,&03,&00,&2F,&08,&03
  EQUB &00
.D5_8EDB
  EQUB &0C,&3F,&F1,&F3,&40,&3E,&F9,&F3,&40,&3E,&00,&F3,&00,&3F,&08,&F3
  EQUB &00,&41,&F1,&FB,&40,&40,&F9,&FB,&40,&40,&00,&FB,&00,&41,&08,&FB
  EQUB &00,&51,&F1,&03,&40,&50,&F9,&03,&40,&50,&00,&03,&00,&51,&08,&03
  EQUB &00
.D5_8F0C
  EQUB &0C,&42,&F9,&EE,&40,&42,&00,&EE,&00,&53,&F1,&F6,&40,&52,&F9,&F6
  EQUB &40,&52,&00,&F6,&00,&53,&08,&F6,&00,&53,&F1,&FE,&C0,&52,&F9,&FE
  EQUB &C0,&52,&00,&FE,&80,&53,&08,&FE,&80,&42,&F9,&06,&C0,&42,&00,&06
  EQUB &80
.D5_8F3D
  EQUB &0C,&44,&F9,&EE,&40,&44,&00,&EE,&00,&55,&F1,&F6,&40,&54,&F9,&F6
  EQUB &40,&54,&00,&F6,&00,&55,&08,&F6,&00,&55,&F1,&FE,&C0,&54,&F9,&FE
  EQUB &C0,&54,&00,&FE,&80,&55,&08,&FE,&80,&44,&F9,&06,&C0,&44,&00,&06
  EQUB &80

; Set SCROLL_Y to 0. If W_04E1 is 0, SCROLL_X is F8h and SCROLL_NT is FFh.
; Otherwise follow actor 0: Z_72 minus 80h, with the borrow from Z_75, clamped to the same F8h edge.
.FOLLOW_ACTOR_SCROLL
  LDA #&00
  STA SCROLL_Y
  LDA W_04E1
  BEQ L5_8FB6
  LDA Z_72
  SEC
  SBC #&80
  STA Z_20
  LDA Z_75
  SBC #&00
  STA Z_21
  BMI L5_8F98
  LDX #&F8
  CPX Z_20
  LDA #&00
  SBC Z_21
  BCS L5_8FAB
  STX Z_20
  LDA #&00
  STA Z_21
  RTS
.L5_8F98
  LDX #&F8
  CPX Z_20
  LDA #&FF
  SBC Z_21
  BCC L5_8FAB
  STX SCROLL_X
  LDA #&FF
  STA SCROLL_NT
  RTS
.L5_8FAB
  LDA Z_20
  STA SCROLL_X
  LDA Z_21
  STA SCROLL_NT
  RTS
.L5_8FB6
  LDA #&F8
  STA SCROLL_X
  LDA #&FF
  STA SCROLL_NT
  RTS

; Read the actor cell. Bit 5 returns. Low bits 0 return.
; Low bits 2, with X_62DE set and the actor near the cell center, clear W_0518, increment Z_B7 and play sound 16h.
; Low bits 1 clear the cell, dispatch the item in that bomb slot, and queue tile 38h.
.TOUCH_MAP_CELL
  LDY Z_9E
  STY Z_29
  JSR MAP_ROW_PTR
  LDY Z_9D
  STY Z_28
  LDA (Z_2F),Y
  TAX
  AND #&20
  BNE L5_9003
  TXA
  AND #&03
  BEQ L5_9003
  CMP #&01
  BEQ PICK_UP_ITEM
  LDA X_62DE
  BEQ L5_9003
  LDA Z_9F
  CLC
  ADC #&06
  AND #&0F
  CMP #&0D
  BCC L5_9003
  LDA Z_A1
  CLC
  ADC #&06
  AND #&0F
  CMP #&0D
  BCC L5_9003
  LDA #&00
  STA W_0518
  INC Z_B7
  LDA #&16
  JSR AUDIO_CALL
.L5_9003
  RTS

; Clear the item cell, take the low nibble of W_04EB,X as an ITEM_HANDLERS index, clear that bomb flag, queue tile 38h, and play sound 15h in story mode.
.PICK_UP_ITEM
  LDA #&00
  STA (Z_2F),Y
  JSR FIND_BOMB_CELL
  LDA W_04EB,X
  AND #&0F
  PHA
  ASL A
  TAY
  LDA ITEM_HANDLERS,Y
  STA Z_20
  LDA D5_9045,Y
  STA Z_21
  TXA
  PHA
  JSR DISPATCH_ITEM
  PLA
  TAX
  LDA #&00
  STA W_04EB,X
  LDX Z_28
  LDY Z_29
  LDA #&38
  JSR QUEUE_TILE_Y2
  PLA
  JSR PLAY_ITEM_SND
  ABS_LDA Z_49
  BNE ITEM_RETURN
  LDA #&15
  JSR AUDIO_CALL
.ITEM_RETURN
  RTS

; Jump through Z_20. PICK_UP_ITEM stores one ITEM_HANDLERS entry there.
.DISPATCH_ITEM
  JMP (Z_20)

; 16 words. Index is the low nibble of the bomb flag. Targets are the item handlers, and the last four entries are ITEM_RETURN.
; One entry is ROLL_ACTOR_A6.
.ITEM_HANDLERS
  EQUB LO(INC_FIRE)
.D5_9045
  EQUB HI(INC_FIRE)
  EQUW INC_BOMBS
  EQUW GIVE_REMOTE
  EQUW INC_SPEED
  EQUW START_POWER_18
  EQUW START_POWER_10
  EQUW GIVE_BOMB_PASS
  EQUW GIVE_WALL_PASS
  EQUW SET_CLEAR_FLAG
  EQUW SPAWN_RAND_EXTRA
  EQUW ROLL_LIFE_OR_MOB
  EQUW ROLL_ACTOR_A6
  EQUW ITEM_RETURN
  EQUW ITEM_RETURN
  EQUW ITEM_RETURN
  EQUW ITEM_RETURN

; In: A is the item index. 0Bh plays sound 5. Anything else plays sound 3.
.PLAY_ITEM_SND
  CMP #&0B
  BEQ L5_906E
  LDA #&03
  JSR AUDIO_CALL
  RTS
.L5_906E
  LDA #&05
  JSR AUDIO_CALL
  RTS

; (not seen executing during the coverage runs)

; Increment Z_A9 up to 7, then MARK_PWR_STAGE.
.INC_FIRE
  LDA Z_A9
  CMP #&07
  BCS L5_907C
  INC Z_A9
.L5_907C
  JSR MARK_PWR_STAGE
  RTS

; Increment Z_AA up to 4, then MARK_PWR_STAGE.
.INC_BOMBS
  LDA Z_AA
  CMP #&04
  BCS L5_9088
  INC Z_AA
.L5_9088
  JSR MARK_PWR_STAGE
  RTS

; Store 1 in Z_AF. HANDLE_ACTOR_BTN uses that flag for button B.
.GIVE_REMOTE
  LDA #&01
  STA Z_AF
  RTS

; Increment Z_B3 up to 4. APPLY_ACTOR_SPEED uses Z_B3 as the speed index.
.INC_SPEED
  LDA Z_B3
  CMP #&04
  BCS L5_9099
  INC Z_B3
.L5_9099
  RTS

; Store 1 in Z_B0, 18h in Z_B2 and 0 in Z_B1, then SET_ACTOR_FLASH. TICK_TIMED_POWERS counts Z_B2 down.
.START_POWER_18
  LDA #&01
  STA Z_B0
  LDA #&18
  STA Z_B2
  LDA #&00
  STA Z_B1
  JMP SET_ACTOR_FLASH

; Store 2 in Z_B0, 10h in Z_B2 and 0 in Z_B1, then SET_ACTOR_FLASH.
.START_POWER_10
  LDA #&02
  STA Z_B0
  LDA #&10
  STA Z_B2
  LDA #&00
  STA Z_B1
  JMP SET_ACTOR_FLASH

; Store 1 in Z_AD. CELL_BLOCKS_MOVE then lets the actor into map cells with bit 5.
.GIVE_BOMB_PASS
  LDA #&01
  STA Z_AD
  RTS

; Store 1 in Z_AE. CELL_BLOCKS_MOVE then lets the actor into map cells with bit 4.
.GIVE_WALL_PASS
  LDA #&01
  STA Z_AE
  RTS

; Store 1 in Z_B4. STAGE_WON checks Z_B4 after the stage.
.SET_CLEAR_FLAG
  LDA #&01
  STA Z_B4
  RTS

; Index EXTRA_SPAWN_IDX with FRAME_CNT bits 0-3 and jump to L7_D192 with that value in Y.
.SPAWN_RAND_EXTRA
  LDA FRAME_CNT
  AND #&0F
  TAX
  LDA EXTRA_SPAWN_IDX,X
  TAY
  JMP L7_D192

; 16 spawn indexes for SPAWN_RAND_EXTRA. The bytes after this table are ROLL_LIFE_OR_MOB, which ITEM_HANDLERS also calls.
.EXTRA_SPAWN_IDX
  EQUB &00,&03,&03,&02,&04,&02,&04,&01,&03,&01,&02,&04,&0A,&05,&02,&01

; NEXT_RNG low 3 bits index LIFE_ROLL_TAB.
; A positive byte is passed to L7_D192. Bit 7 with bit 0 set starts the W_04E6 timer and SET_ACTOR_FLASH. Bit 7 with bit 0 clear increments W_04E5 and plays sound 0Ah.
.ROLL_LIFE_OR_MOB
  EQUB &A5,&14,&29,&07,&AA,&BD,&0C,&91,&10,&E2,&29,&01,&F0,&12,&A9,&01
  EQUB &8D,&E6,&04,&A9,&10,&8D,&E8,&04,&A9,&00,&8D,&E7,&04,&4C
  EQUW SET_ACTOR_FLASH
  EQUB &EE,&E5,&04,&A9,&0A,&20
IF REGION_JP
  EQUB &61
ELSE
  EQUB &F5
ENDIF
  EQUB &C8,&60

; Eight bytes read by ROLL_LIFE_OR_MOB. Bit 7 selects the life or W_04E6 path. A positive value is a Y argument to L7_D192.
.LIFE_ROLL_TAB
  EQUB &80,&05,&81,&0A,&05,&81,&0A,&81

; (not seen executing during the coverage runs)

; Store area*8 OR stage into W_04E4. CHOOSE_LEVEL_CHR compares against it.
.MARK_PWR_STAGE
  ABS_LDA Z_4B
  ASL A
  ASL A
  ASL A
  ABS_ORA Z_4C
  STA W_04E4
  RTS

; Round-end timer. With Z_53 clear, a positive W_051B waits 30h frames, then either marks a winner or starts Z_53.
; While Z_53 is below 96h and Z_49 is not 0, draw a round sprite. A negative W_051B waits 96h frames, then stores B4h in Z_53.
.UPDATE_ROUND
  ABS_LDA Z_53
  BNE L5_9153
  LDA W_051B
  BEQ L5_9177
  BMI L5_9178
  INC W_051C
  LDA W_051C
  CMP #&30
  BCC L5_9177
  LDA #&00
  STA W_051C
  ABS_LDX Z_49
.L5_913F
  LDA Z_69,X
  BEQ L5_9147
  LDA Z_84,X
  BEQ L5_916B
.L5_9147
  DEX
  BPL L5_913F
  ABS_INC Z_53
  LDA #&1B
  JSR AUDIO_CALL
  RTS
.L5_9153
  ABS_LDA Z_49
  BEQ L5_9177
  ABS_LDA Z_53
  CMP #&96
  BCS L5_9177
  LDX #&08
  LDA W_055A
  BPL L5_9190
  LDX #&0A
  JMP L5_9190
.L5_916B
  INX
  TXA
  ORA #&80
  STA W_051B
  LDA #&1A
  JSR AUDIO_CALL
.L5_9177
  RTS
.L5_9178
  AND #&03
  ASL A
  TAX
  INC W_051C
  LDA W_051C
  CMP #&96
  BCC L5_9190
  LDA #&00
  STA W_051B
  LDA #&B4
  ABS_STA Z_53
.L5_9190
  LDA ROUND_OAM_PTRS,X
  STA Z_54
  LDA D5_91B2,X
  STA Z_55
  LDA ROUND_SPR_X
  ABS_STA Z_56
  LDA D5_91BE
  ABS_STA Z_58
  LDA #&00
  ABS_STA Z_57
  ABS_STA Z_5A
  JMP DRAW_METASPRITE

; Six words for UPDATE_ROUND. The first is 0000. The others point at metasprites just after ROUND_SPR_X.
; X is 0, 2, 4 or 6 from the low bits of W_051B, or 8 or 0Ah from the sign of W_055A.
.ROUND_OAM_PTRS
  EQUB &00
.D5_91B2
  EQUB &00
  EQUW ROUND_SPR_SLOT0
  EQUW ROUND_SPR_SLOT1
  EQUW ROUND_SPR_SLOT2
  EQUW ROUND_SPR_TIME_POS
  EQUW ROUND_SPR_TIME_NEG

; Screen X 7Dh for the round sprite. The next byte is screen Y 94h. Later bytes are the metasprites named by ROUND_OAM_PTRS.
.ROUND_SPR_X
  EQUB &7D
.D5_91BE
  EQUB &94

; 8-sprite metasprite. UPDATE_ROUND selects it when the low bits of negative W_051B are 1.
.ROUND_SPR_SLOT0
  EQUB &08,&C0,&E0,&ED,&01,&C1,&E8,&E8,&01,&C2,&F0,&E6,&01,&C3,&F8,&E4
  EQUB &01,&C4,&00,&E4,&01,&C5,&08,&E6,&01,&C6,&10,&E8,&01,&C9,&18,&ED
  EQUB &01

; 8-sprite metasprite. Selected when the low bits of negative W_051B are 2. One tile byte differs from ROUND_SPR_SLOT0 (C7 instead of C6).
.ROUND_SPR_SLOT1
  EQUB &08,&C0,&E0,&ED,&01,&C1,&E8,&E8,&01,&C2,&F0,&E6,&01,&C3,&F8,&E4
  EQUB &01,&C4,&00,&E4,&01,&C5,&08,&E6,&01,&C7,&10,&E8,&01,&C9,&18,&ED
  EQUB &01

; 8-sprite metasprite. Selected when the low bits of negative W_051B are 3. One tile byte differs (C8).
.ROUND_SPR_SLOT2
  EQUB &08,&C0,&E0,&ED,&01,&C1,&E8,&E8,&01,&C2,&F0,&E6,&01,&C3,&F8,&E4
  EQUB &01,&C4,&00,&E4,&01,&C5,&08,&E6,&01,&C8,&10,&E8,&01,&C9,&18,&ED
  EQUB &01

; 5-sprite metasprite. UPDATE_ROUND uses pointer index 4 while Z_53 is below 96h and W_055A is positive.
.ROUND_SPR_TIME_POS
  EQUB &05,&CB,&E8,&E8,&01,&C5,&F2,&E8,&01,&C2,&FC,&E8,&01,&CA,&06,&E8
  EQUB &01,&C9,&10,&E8,&01

; 7-sprite metasprite. Same path as ROUND_SPR_TIME_POS, but W_055A is negative.
.ROUND_SPR_TIME_NEG
  EQUB &07,&CC,&E0,&E8,&01,&CD,&E8,&E8,&01,&CE,&F0,&E8,&01,&C4,&F8,&E8
  EQUB &01,&CF,&08,&E8,&01,&D0,&10,&E8,&01,&CC,&18,&E8,&01

; Fill 1A0h bytes at 62F3h with FFh. Called from FILL_MAP_FF.
.FILL_MAP_RAM
  LDA #&F3
  STA Z_20
  LDA #&62
  STA Z_21
  LDA #&A0
  STA Z_22
  LDA #&01
  STA Z_23
  LDY #&00
.L5_9266
  LDA #&FF
  STA (Z_20),Y
  INY
  BNE L5_926F
  INC Z_21
.L5_926F
  DEC Z_22
  LDA Z_22
  CMP #&FF
  BNE L5_9279
  DEC Z_23
.L5_9279
  LDA Z_22
  ORA Z_23
  BNE L5_9266
  RTS

; Fill nine bytes at W_03DB with FFh. Store 4Bh in W_03ED and 0 in W_03EE. Called from RESET_MARKS.
.INIT_PASS_BYTES
  LDX #&08
  LDA #&FF
.L5_9284
  STA W_03DB,X
  DEX
  BPL L5_9284
  LDA #&4B
  STA W_03ED
  LDA #&00
  STA W_03EE
  RTS

; Password screen. Loads CHR and palettes, copies W_03DB to W_03E4, then loops on the editor until TRY_PASS_ENTRY returns carry clear.
; On exit stores 1 in Z_4A and Z_53, stores 0 in Z_49, and fades out. Does not return to its caller until that fade.
.RUN_PASS_SCREEN
  JSR PPU_OFF
  JSR NMI_OFF
  JSR CLEAR_ATTRS
  JSR LOAD_PASS_CHR
  JSR NMI_ON
  JSR LOAD_PASS_PAL
  JSR BIND_PASS_LAYOUT
  JSR CLEAR_SCROLL
  JSR CLEAR_PASS_POS
  LDA #&00
  STA W_054E
  JSR CLEAR_PASS_REPEAT
  JSR SAVE_PASS_BYTES
  JSR PPU_ON
  JSR MARK_PALETTE
  LDA #&13
  JSR AUDIO_CALL
.L5_92C6
  JSR WAIT_NMI
  JSR POLL_PASS_KEYS
  JSR EDIT_PASS_INPUT
  JSR DRAW_PASS_CURSOR
  JSR DRAW_PASS_SLOT
  JSR DRAW_PASS_LINE
  JSR MARK_OAM
  JSR TRY_PASS_ENTRY
  BCC L5_92E3
  JMP L5_92C6
.L5_92E3
  LDA #&01
  ABS_STA Z_4A
  ABS_STA Z_53
  LDA #&00
  ABS_STA Z_49
  JSR FADE_PALETTE
  JMP PPU_OFF

; Upload UI_SPR_CHR to PPU 1000h and the short PASS_CHR_BYTES run to PPU 0000h.
.LOAD_PASS_CHR
  LDA #LO(UI_SPR_CHR)
  STA Z_20
  LDA #HI(UI_SPR_CHR)
  STA Z_21
  LDA #&00
  STA Z_22
  LDA #&10
  STA Z_23
  LDX #&06
  LDY #&FF
  JSR UPLOAD_CHR_RLE
  LDA #LO(PASS_CHR_BYTES)
  STA Z_20
  LDA #HI(PASS_CHR_BYTES)
  STA Z_21
  LDA #&00
  STA Z_22
  LDA #&00
  STA Z_23
  LDX #&05
  LDY #&01
  JMP UPLOAD_CHR_RLE

; Copy 16 background colors from D4_B119 and 16 sprite colors from PASS_SPR_PAL, then MIRROR_BG_COLOR.
.LOAD_PASS_PAL
  LDA #LO(D4_B119)
  STA Z_16
  LDA #HI(D4_B119)
  STA Z_17
  LDA #&00
  LDX #&04
  FARCALL 4, COPY_PAL_ROWS
  LDA #LO(PASS_SPR_PAL)
  STA Z_16
  LDA #HI(PASS_SPR_PAL)
  STA Z_17
  LDA #&04
  LDX #&04
  JSR COPY_PAL_ROWS
  JMP MIRROR_BG_COLOR

; 16 sprite-palette bytes. Four rows, copied by LOAD_PASS_PAL at palette offset 4.
.PASS_SPR_PAL
  EQUB &0F,&0F,&30,&30,&0F,&0F,&0F,&30,&0F,&0F,&0F,&30,&0F,&0F,&0F,&30

; 13 bytes passed to UPLOAD_CHR_RLE by LOAD_PASS_CHR. Not a pointer table.
.PASS_CHR_BYTES
  EQUB &3F,&08,&04,&02,&01,&FF,&00,&3E,&10,&38,&7C,&FE,&00
IF REGION_JP

.BIND_PASS_LAYOUT
  LDA #LO(D4_986C)
ELSE

; Point Z_62, Z_64 and Z_66 at bank-4 password layout tables, point Z_20 at D4_AC9E, and jump to L7_CD89.
.BIND_PASS_LAYOUT
  LDA #LO(D4_9869)
ENDIF
  STA Z_66
IF REGION_JP
  LDA #HI(D4_986C)
ELSE
  LDA #HI(D4_9869)
ENDIF
  STA Z_67
IF REGION_JP
  LDA #LO(D4_9880)
ELSE
  LDA #LO(D4_987E)
ENDIF
  STA Z_64
IF REGION_JP
  LDA #HI(D4_9880)
ELSE
  LDA #HI(D4_987E)
ENDIF
  STA Z_65
  LDA #LO(D4_97C1)
  STA Z_62
  LDA #HI(D4_97C1)
  STA Z_63
  LDA #LO(D4_AC9E)
  STA Z_20
  LDA #HI(D4_AC9E)
  STA Z_21
  JMP L7_CD89

; Copy nine bytes from W_03DB to W_03E4.
.SAVE_PASS_BYTES
  LDX #&08
.L5_938A
  LDA W_03DB,X
  STA W_03E4,X
  DEX
  BPL L5_938A
  RTS

; Copy nine bytes from W_03E4 to W_03DB.
.LOAD_PASS_BYTES
  LDX #&08
.L5_9396
  LDA W_03E4,X
  STA W_03DB,X
  DEX
  BPL L5_9396
  RTS

; Zero W_054A, W_054B, W_054C and W_054D.
.CLEAR_PASS_POS
  LDA #&00
  STA W_054A
  STA W_054B
  STA W_054C
  STA W_054D
  RTS

; Edit the password from W_0551, which POLL_PASS_KEYS just built.
; Directions move W_054B and W_054C. B moves W_054D along the eight digits. Bit 7 of W_0551 writes PASS_KEY_MAP into W_03E4.
.EDIT_PASS_INPUT
  LDX W_0551
  TXA
  AND #&80
  BEQ L5_93BA
  JMP L5_9459
.L5_93BA
  LDA JOY_HELD
  AND #&40
  BNE L5_9433
  TXA
  AND #&01
  BNE L5_9403
  TXA
  AND #&02
  BNE L5_941E
  TXA
  AND #&08
  BNE L5_93DE
  TXA
  AND #&04
  BNE L5_93EE
  TXA
  AND #&10
  BEQ L5_93DD
  JMP L5_948B
.L5_93DD
  RTS
.L5_93DE
  LDA #&07
  JSR AUDIO_CALL
  DEC W_054C
  BPL L5_93ED
  LDA #&02
  STA W_054C
.L5_93ED
  RTS
.L5_93EE
  LDA #&07
  JSR AUDIO_CALL
  INC W_054C
  LDA W_054C
  CMP #&03
  BCC L5_93ED
  LDA #&00
  STA W_054C
  RTS
.L5_9403
  LDA #&07
  JSR AUDIO_CALL
  INC W_054B
  LDA W_054C
  CMP #&02
  BNE L5_9415
  INC W_054B
.L5_9415
  LDA W_054B
  AND #&07
  STA W_054B
  RTS
.L5_941E
  LDA #&07
  JSR AUDIO_CALL
  DEC W_054B
  LDA W_054C
  CMP #&02
  BNE L5_9415
  DEC W_054B
  JMP L5_9415
.L5_9433
  TXA
  AND #&01
  BNE L5_943E
  TXA
  AND #&02
  BNE L5_944E
  RTS
.L5_943E
  LDY W_054D
  CPY #&07
  BCS L5_944D
  LDA W_03E4,Y
  BMI L5_944D
  INC W_054D
.L5_944D
  RTS
.L5_944E
  DEC W_054D
  BPL L5_944D
  LDA #&00
  STA W_054D
  RTS
.L5_9459
  LDA W_054C
  ASL A
  ASL A
  ASL A
  ORA W_054B
  TAX
  LDA PASS_KEY_MAP,X
  BMI L5_947F
  LDY W_054D
  STA W_03E4,Y
  CPY #&07
  BCS L5_947B
  INC W_054D
  LDA #&02
  JSR AUDIO_CALL
  RTS
.L5_947B
  INC W_054A
  RTS
.L5_947F
  AND #&03
  BEQ L5_944E
  CMP #&01
  BEQ L5_943E
  CMP #&02
  BEQ L5_948F
.L5_948B
  INC W_054A
  RTS
.L5_948F
  LDX W_054D
  LDA W_03E4,X
  BMI L5_94A2
.L5_9497
  LDA W_03E5,X
  STA W_03E4,X
  INX
  CPX #&08
  BCC L5_9497
.L5_94A2
  RTS

; 24 X offsets for the password cursor, indexed by row*8+column, then added to 48h.
; The matching Y row bases are PASS_CUR_ROWY.
.PASS_CUR_XY
  EQUB &00,&10,&20,&30,&40,&50,&60,&70,&00,&10,&20,&30,&40,&50,&60,&70
  EQUB &00,&00,&20,&20,&48,&48,&68,&68

; Three Y bases for password rows 0-2. DRAW_PASS_CURSOR adds 66h.
.PASS_CUR_ROWY
  EQUB &00,&10,&20

; 24 keypad values, row-major, 8 columns by 3 rows. 00h-0Fh are digit nybbles. 80h-83h are back, forward, delete and confirm.
.PASS_KEY_MAP
  EQUB &0B,&0A,&01,&0C,&09,&04,&08,&06,&07,&0D,&02,&0E,&0F,&03,&05,&00
  EQUB &80,&80,&81,&81,&82,&82,&83,&83

; Draw the keypad cursor from PASS_CURSOR_SPR at the PASS_CUR_XY position.
.DRAW_PASS_CURSOR
  LDA W_054C
  LDY W_054C
  ASL A
  ASL A
  ASL A
  ORA W_054B
  TAX
  LDA PASS_CUR_XY,X
  CLC
  ADC #&48
  ABS_STA Z_56
  LDA PASS_CUR_ROWY,Y
  CLC
  ADC #&66
  ABS_STA Z_58
  LDA #&00
  ABS_STA Z_57
  ABS_STA Z_5A
  LDA #LO(PASS_CURSOR_SPR)
  STA Z_54
  LDA #HI(PASS_CURSOR_SPR)
  STA Z_55
  JMP DRAW_METASPRITE

; One metasprite: count 1, tile 0, dx 0, dy 0, attr 0. Used by both password cursors.
.PASS_CURSOR_SPR
  EQUB &01,&00,&00,&00,&00

; Draw PASS_CURSOR_SPR over password digit W_054D. X is the digit times 8 plus 68h. Y is 9Eh.
.DRAW_PASS_SLOT
  LDA W_054D
  ASL A
  ASL A
  ASL A
  CLC
  ADC #&68
  ABS_STA Z_56
  LDA #&9E
  ABS_STA Z_58
  LDA #&00
  ABS_STA Z_57
  ABS_STA Z_5A
  LDA #LO(PASS_CURSOR_SPR)
  STA Z_54
  LDA #HI(PASS_CURSOR_SPR)
  STA Z_55
  JMP DRAW_METASPRITE

; Map the eight password bytes to tiles and queue them at column 0Dh, row 13h.
.DRAW_PASS_LINE
  JSR MAP_PASS_TILES
  LDX #&0D
  LDY #&13
  JSR XY_TO_NT_ADDR
IF REGION_JP
  LDA #&38
ELSE
  LDA #&3A
ENDIF
  STA Z_20
  LDA #&05
  STA Z_21
  LDX #&08
  LDA #&00
  STA Z_2E
  JMP QUEUE_PPU_RUN

; For each of eight bytes in W_03E4, store PASS_GLYPHS of that nybble into W_053A, or FEh when the byte is negative.
.MAP_PASS_TILES
  LDX #&07
.L5_954E
  LDY W_03E4,X
  BMI L5_9559
IF REGION_JP
  LDA JD5_9609,Y
ELSE
  LDA PASS_GLYPHS,Y
ENDIF
  JMP L5_955B
.L5_9559
  LDA #&FE
.L5_955B
  STA W_053A,X
  DEX
  BPL L5_954E
  RTS

; Build an eight-nybble code in W_03E4 from RNG, Z_4B, Z_4C, Z_90 and Z_93, XOR it, and queue the tiles. Called from MIX_STAGE_BYTES.
.MAKE_STAGE_CODE
  JSR NEXT_RNG
  AND #&0F
  BEQ MAKE_STAGE_CODE
  LDX #&00
  STA W_03E4,X
  LDA #&00
  STA Z_1C
  ABS_LDA Z_4B
  LDX #&01
  STA W_03E4,X
  JSR ADD_PASS_NIBBLE
  ABS_LDA Z_4C
  LDX #&02
  STA W_03E4,X
  JSR ADD_PASS_NIBBLE
  ABS_LDA Z_90
  LDX #&04
  STA W_03E4,X
  JSR ADD_PASS_NIBBLE
  ABS_LDA Z_93
  LDX #&06
  STA W_03E4,X
  JSR ADD_PASS_NIBBLE
  JSR NEXT_RNG
  AND #&0F
  LDX #&05
  STA W_03E4,X
  JSR ADD_PASS_NIBBLE
  JSR NEXT_RNG
  AND #&0F
  LDX #&07
  STA W_03E4,X
  JSR ADD_PASS_NIBBLE
  LDA Z_1C
  AND #&0F
  LDX #&03
  STA W_03E4,X
  JSR XOR_PASS_BYTES
  JSR LOAD_PASS_BYTES
  JSR MAP_PASS_TILES
  LDX #&0C
  LDY #&14
  JSR XY_TO_NT_ADDR
IF REGION_JP
  LDA #&38
ELSE
  LDA #&3A
ENDIF
  STA Z_20
  LDA #&05
  STA Z_21
  LDX #&08
  LDA #&00
  STA Z_2E
  JMP QUEUE_PPU_RUN

; Add A into the running sum Z_1C. MAKE_STAGE_CODE calls this after each stored nybble.
.ADD_PASS_NIBBLE
  CLC
  ADC Z_1C
  STA Z_1C
  RTS

; XOR W_03E4 bytes 1 through 7 with byte 0.
.XOR_PASS_BYTES
  LDX #&01
.L5_95EA
  LDA W_03E4,X
  EOR W_03E4
  STA W_03E4,X
  INX
  CPX #&08
  BCC L5_95EA
  RTS
  EQUB &0B,&0A,&01,&0C,&09,&04,&08,&06,&07,&0D,&02,&0E,&0F,&03,&05,&00
IF REGION_JP
.JD5_9609
  EQUB &50,&43
ELSE
ENDIF

; 16 tile ids, one per password nybble. The US order and the JP order differ. MAP_PASS_TILES and the JP side of MATCH_PASS_WORD read it.
.PASS_GLYPHS
  EQUB &4B
IF REGION_JP
  EQUB &4E,&46,&4F,&48,&49,&47,&45,&42,&41
ELSE
  EQUB &33
ENDIF
  EQUB &44
IF REGION_JP
ELSE
  EQUB &48,&36
ENDIF
  EQUB &4A
IF REGION_JP
  EQUB &4C,&4D
ELSE
  EQUB &38,&42,&37,&35,&32,&31,&34,&43,&46,&47
ENDIF

; When W_054A is set, accept the eight digits.
; A short entry can set W_054E. A full entry must match a secret word or pass TEST_PASS_SUM and APPLY_PASS_STAGE. Carry clear leaves the screen. Carry set stays.
.TRY_PASS_ENTRY
  LDA W_054A
  BEQ L5_9657
  LDA #&00
  STA W_054A
  JSR COPY_PASS_ENTRY
  BCS L5_9644
  JSR MATCH_PASS_WORD
  BCC L5_963D
  JSR XOR_PASS_ENTRY
  JSR TEST_PASS_SUM
  BNE L5_9650
  JSR APPLY_PASS_STAGE
  BCS L5_9650
  JSR LOAD_PASS_BYTES
.L5_963D
  LDA #&03
  JSR AUDIO_CALL
  CLC
  RTS
.L5_9644
  CPX #&00
  BNE L5_9650
  LDA #&01
  STA W_054E
  JMP L5_963D
.L5_9650
  LDA #&04
  JSR AUDIO_CALL
  SEC
  RTS
.L5_9657
  SEC
  RTS

; Copy eight W_03E4 bytes into W_0542. Carry is set if any source byte is negative.
.COPY_PASS_ENTRY
  LDX #&00
.L5_965B
  LDA W_03E4,X
  BMI L5_966A
  STA W_0542,X
  INX
  CPX #&08
  BCC L5_965B
  CLC
  RTS
.L5_966A
  SEC
  RTS

; XOR W_0542 bytes 1 through 7 with byte 0. Out: Z flag from the last byte. The caller treats nonzero as failure.
.XOR_PASS_ENTRY
  LDX #&01
.L5_966E
  LDA W_0542,X
  EOR W_0542
  STA W_0542,X
  INX
  CPX #&08
  BCC L5_966E
  RTS

; Add W_0543, W_0544, W_0546, W_0547, W_0548 and W_0549, keep the low nibble, and compare it with W_0545.
; Out: Z set when the sum matches.
.TEST_PASS_SUM
  LDA W_0543
  CLC
  ADC W_0544
  CLC
  ADC W_0546
  CLC
  ADC W_0547
  CLC
  ADC W_0548
  CLC
  ADC W_0549
  AND #&0F
  CMP W_0545
  RTS

; Store the decoded nybbles into Z_4B, Z_4C, Z_90 and Z_93 when they are below 6, 8, 8 and 5. Carry set means reject.
.APPLY_PASS_STAGE
  LDA W_0543
  ABS_STA Z_4B
  CMP #&06
  BCS L5_96C4
  LDA W_0544
  ABS_STA Z_4C
  CMP #&08
  BCS L5_96C4
  LDA W_0546
  ABS_STA Z_90
  CMP #&08
  BCS L5_96C4
  LDA W_0548
  ABS_STA Z_93
  CMP #&05
  BCS L5_96C4
  CLC
  RTS
.L5_96C4
  SEC
  RTS

; Compare the eight decoded tiles with the seven words at PASS_WORDS.
; Out: carry clear and Z_1C = word index on a match. Carry set and Z_1C = FFh otherwise.
.MATCH_PASS_WORD
  LDA #&00
  STA Z_1C
  LDA #LO(PASS_WORDS)
  STA Z_20
  LDA #HI(PASS_WORDS)
  STA Z_21
.L5_96D2
  LDY #&00
.L5_96D4
  LDX W_0542,Y
IF REGION_JP
  LDA JD5_9609,X
ELSE
  LDA PASS_GLYPH_US,X
ENDIF
  CMP (Z_20),Y
  BNE L5_96E8
  INY
  CPY #&08
  BCC L5_96D4
  JSR APPLY_PASS_WORD
  CLC
  RTS
.L5_96E8
  LDA Z_20
  CLC
  ADC #&08
  STA Z_20
  LDA Z_21
  ADC #&00
  STA Z_21
  INC Z_1C
  LDA Z_1C
  CMP #&07
  BCC L5_96D2
  LDA #&FF
  STA Z_1C
  SEC
  RTS

; Seven secret words, 8 tile bytes each. MATCH_PASS_WORD compares them with the decoded password tiles. US tile ids come from PASS_GLYPH_US.
.PASS_WORDS
  EQUB &50,&43,&44,&45,&46,&47,&41,&42,&50,&41,&43,&48,&49,&4E,&4B,&4F
  EQUB &50,&41,&4E,&49,&43,&4D,&41,&4E,&50,&4F,&4E,&45,&4A,&41,&43,&4B
  EQUB &50,&42,&4F,&4D,&42,&41,&43,&45,&50,&42,&4F,&4D,&42,&4D,&41,&4E
  EQUB &50,&42,&4F,&4D,&42,&4F,&4C,&44
IF REGION_JP
ELSE

; US only. 16 tile ids used by MATCH_PASS_WORD. Index is the decoded nybble.
.PASS_GLYPH_US
  EQUB &50,&43,&4B,&4E,&46,&4F,&48,&49,&47,&45,&42,&41,&44,&4A,&4C,&4D
ENDIF

; Apply secret word Z_1C.
; 0 sets W_054F. 1 and 2 set W_03EE to 1 or 2 and W_054E. 3 sets W_0550. 4, 5 and 6 set W_03ED to 2Dh, 4Bh or 69h and set W_054E.
.APPLY_PASS_WORD
  LDX Z_1C
  BEQ L5_979F
  DEX
  BEQ L5_9794
  DEX
  BEQ L5_9789
  DEX
  BEQ L5_9783
  DEX
  BEQ L5_9778
  DEX
  BEQ L5_976D
  DEX
  BEQ L5_9762
  RTS
.L5_9762
  LDA #&69
  STA W_03ED
  LDA #&01
  STA W_054E
  RTS
.L5_976D
  LDA #&4B
  STA W_03ED
  LDA #&01
  STA W_054E
  RTS
.L5_9778
  LDA #&2D
  STA W_03ED
  LDA #&01
  STA W_054E
  RTS
.L5_9783
  LDA #&01
  STA W_0550
  RTS
.L5_9789
  LDA #&02
  STA W_03EE
  LDA #&01
  STA W_054E
  RTS
.L5_9794
  LDA #&01
  STA W_03EE
  LDA #&01
  STA W_054E
  RTS
.L5_979F
  LDA #&01
  STA W_054F
  RTS

; Zero the eight key-repeat timers at W_0552.
.CLEAR_PASS_REPEAT
  LDX #&07
  LDA #&00
.L5_97A9
  STA W_0552,X
  DEX
  BPL L5_97A9
  RTS

; Build W_0551 from JOY_NEW and JOY_HELD. Bit 7 is A, then B, Select, Start, up, down, left, right.
; A held direction repeats every 6 frames after a 0Eh-frame delay, using W_0552.
.POLL_PASS_KEYS
  LDX #&07
  LDA #&80
  STA Z_1C
.L5_97B6
  LDA Z_1C
  BIT JOY_NEW
  BNE L5_97D1
  CLC
  BIT JOY_HELD
  BEQ L5_97D7
  DEC W_0552,X
  BNE L5_97D7
  LDA #&06
  STA W_0552,X
  SEC
  JMP L5_97D7
.L5_97D1
  LDA #&0E
  STA W_0552,X
  SEC
.L5_97D7
  ROL W_0551
  LSR Z_1C
  DEX
  BPL L5_97B6
  RTS

; Start the stage clock. Frame counter W_055A is 3Ch and W_055B is 0.
; Z_4E uses digits 0 and 3. A nonzero Z_49 uses 3 and 0. Story mode reads the two digits from STAGE_TIME_TAB. Called from STAGE_SETUP.
.INIT_STAGE_CLOCK
  ABS_LDA Z_4E
  BNE L5_981F
  ABS_LDA Z_49
  BNE L5_980C
  LDA #&3C
  STA W_055A
  LDA #&00
  STA W_055B
  ABS_LDA Z_4B
  ASL A
  ASL A
  ASL A
  ABS_ORA Z_4C
  ASL A
  TAX
  LDA D5_9835,X
  STA W_055C
  LDA STAGE_TIME_TAB,X
  STA W_055D
  RTS
.L5_980C
  LDA #&3C
  STA W_055A
  LDA #&00
  STA W_055B
  STA W_055C
  LDA #&03
  STA W_055D
  RTS
.L5_981F
  LDA #&3C
  STA W_055A
  LDA #&00
  STA W_055B
  LDA #&03
  STA W_055C
  LDA #&00
  STA W_055D
  RTS

; 48 stages, 2 bytes each: the first drawn digit and the second. Indexed by (area*8+stage)*2. INIT_STAGE_CLOCK stores them in W_055D and W_055C. The third digit starts at 0.
.STAGE_TIME_TAB
  EQUB &02
.D5_9835
  EQUB &00,&02,&00,&02,&00,&02,&00,&03,&00,&03,&00,&03,&00,&03,&00,&01
  EQUB &05,&02,&05,&01,&05,&02,&05,&01,&05,&02,&05,&01,&05,&02,&05,&01
  EQUB &00,&02,&00,&02,&00,&02,&00,&01,&00,&02,&00,&01,&00,&02,&00,&01
  EQUB &00,&01,&00,&01,&05,&01,&05,&01,&00,&01,&05,&01,&00,&01,&05,&01
  EQUB &00,&01,&05,&01,&05,&01,&00,&01,&05,&01,&05,&01,&00,&01,&05,&01
  EQUB &02,&01,&02,&01,&02,&01,&02,&01,&02,&01,&02,&01,&02,&01,&02
.L5_9894
  RTS

; Count the stage clock down once per frame unless Z_B7, W_051B, Z_53, or a negative W_055A says to stop.
; At zero, call KILL_PLAYERS. When only the last digit remains, 3Bh and 1Dh play sound 8. Then falls into DRAW_STAGE_CLOCK.
.TICK_STAGE_CLOCK
  ABS_LDA Z_B7
  ORA W_051B
  ABS_ORA Z_53
  BNE L5_9894
  LDA W_055A
  BMI L5_9894
  DEC W_055A
  BPL L5_98DD
  LDA #&3B
  STA W_055A
  DEC W_055B
  BPL L5_98DD
  LDA #&09
  STA W_055B
  DEC W_055C
  BPL L5_98DD
  LDA #&09
  STA W_055C
  DEC W_055D
  BPL L5_98DD
  LDX #&00
  STX W_055B
  STX W_055C
  STX W_055D
  DEX
  STX W_055A
  JSR KILL_PLAYERS
  JMP DRAW_STAGE_CLOCK
.L5_98DD
  LDA W_055D
  ORA W_055C
  BNE DRAW_STAGE_CLOCK
  LDA W_055A
  CMP #&3B
  BEQ L5_98F0
  CMP #&1D
  BNE DRAW_STAGE_CLOCK
.L5_98F0
  LDA #&08
  JSR AUDIO_CALL

; Queue five tiles: 54h, 7Eh, and the three clock digits ORed with 30h.
; Column comes from CLOCK_HUD_COL indexed by Z_49. Row is 2.
.DRAW_STAGE_CLOCK
  LDA #&54
  STA W_052A
  LDA #&7E
  STA W_052B
  LDA W_055D
  ORA #&30
  STA W_052C
  LDA W_055C
  ORA #&30
  STA W_052D
  LDA W_055B
  ORA #&30
  STA W_052E
  ABS_LDY Z_49
  LDX CLOCK_HUD_COL,Y
  LDY #&02
  JSR XY_TO_NT_ADDR
IF REGION_JP
  LDA #&28
ELSE
  LDA #&2A
ENDIF
  STA Z_20
  LDA #&05
  STA Z_21
  LDA #&00
  STA Z_2E
  LDX #&05
  JMP QUEUE_PPU_RUN

; Three nametable columns for the clock, indexed by Z_49: 0Eh, 0Dh, 18h.
.CLOCK_HUD_COL
  EQUB &0E,&0D,&18

; Zero W_055E, W_055F and W_0560. Called from NEW_AREA.
.CLEAR_SCORE_RAM
  LDA #&00
  STA W_055E
  STA W_055F
  STA W_0560
  RTS

; Draw the score HUD. Z_49 0 falls into DRAW_LIVES_HUD.
; Z_49 1 draws W_055E and W_055F. Any other value draws those two plus W_0560. Each value is one digit.
.DRAW_MODE_HUD
  LDA #&50
  STA W_052A
  LDA #&7E
  STA W_052C
  ABS_LDY Z_49
  BEQ DRAW_LIVES_HUD
  CPY #&01
  BEQ L5_9982
  LDA #&31
  STA W_052B
  LDX #&03
  LDY #&02
  LDA W_055E
  JSR DRAW_SCORE_PAIR
  LDA #&32
  STA W_052B
  LDX #&0A
  LDY #&02
  LDA W_055F
  JSR DRAW_SCORE_PAIR
  LDA #&33
  STA W_052B
  LDX #&11
  LDY #&02
  LDA W_0560
  JMP DRAW_SCORE_PAIR
.L5_9982
  LDA #&31
  STA W_052B
  LDX #&05
  LDY #&02
  LDA W_055E
  JSR DRAW_SCORE_PAIR
  LDA #&32
  STA W_052B
  LDX #&17
  LDY #&02
  LDA W_055F
  JMP DRAW_SCORE_PAIR

; Queue LIVES_TEXT and the W_04E5 digit at column 16h, row 2. Called for story mode and from the bonus stage.
.DRAW_LIVES_HUD
  LDX #&00
.L5_99A2
  LDA LIVES_TEXT,X
  STA W_052A,X
  INX
  CPX #&05
  BCC L5_99A2
  LDA W_04E5
  ORA #&30
  STA W_052A,X
  LDX #&16
  LDY #&02
  JSR XY_TO_NT_ADDR
IF REGION_JP
  LDA #&28
ELSE
  LDA #&2A
ENDIF
  STA Z_20
  LDA #&05
  STA Z_21
  LDA #&00
  STA Z_2E
  LDX #&06
  JMP QUEUE_PPU_RUN

; Five tiles queued before the life digit: 4Ch, 45h, 46h, 54h, 40h.
.LIVES_TEXT
  EQUB &4C,&45,&46,&54,&40

; In: A is a one-byte count, X and Y are the nametable cell. Queues four tiles starting at W_052A, with the count ORed with 30h in the fourth byte.
.DRAW_SCORE_PAIR
  PHA
  JSR XY_TO_NT_ADDR
  PLA
  ORA #&30
  STA W_052D
IF REGION_JP
  LDA #&28
ELSE
  LDA #&2A
ENDIF
  STA Z_20
  LDA #&05
  STA Z_21
  LDA #&00
  STA Z_2E
  LDX #&04
  JMP QUEUE_PPU_RUN

; Demo pad. Returns at once when W_03EF is 0.
; DEMO_PAD_PTR selects the record from W_03F0. DEMO_PAD_LOCK clear records JOYPAD1 into the record. Nonzero plays the record back into W_04C2 and W_04C1.
.SERVICE_DEMO_PAD
  LDA W_03EF
  BEQ L5_9A41
  LDA W_03F0
  ASL A
  TAX
  LDA DEMO_PAD_PTR,X
  STA Z_B9
  LDA D5_9A8B,X
  STA Z_BA
  LDA DEMO_PAD_LOCK
  BNE L5_9A4D
  LDA JOYPAD1
  STA W_04C2
  LDA JOYPAD1_NEW
  STA W_04C1
  LDA W_03F1
  ASL A
  TAY
  LDA W_03F3
  CMP JOYPAD1
  BEQ L5_9A42
.L5_9A1F
  LDA W_03F3
  STA (Z_B9),Y
  LDA W_03F2
  INY
  STA (Z_B9),Y
  INC W_03F1
  LDA #&00
  STA W_03F2
  LDA JOYPAD1
  STA W_03F3
  STA W_04C2
  LDA JOYPAD1_NEW
  STA W_04C1
.L5_9A41
  RTS
.L5_9A42
  INC W_03F2
  LDA W_03F2
  CMP #&FF
  BEQ L5_9A1F
  RTS
.L5_9A4D
  LDA W_03F3
  STA W_03F4
  LDA W_03F2
  BEQ L5_9A5E
  DEC W_03F2
  JMP L5_9A71
.L5_9A5E
  LDA W_03F1
  INC W_03F1
  ASL A
  TAY
  LDA (Z_B9),Y
  STA W_03F3
  INY
  LDA (Z_B9),Y
  STA W_03F2
.L5_9A71
  LDA W_03F3
  EOR W_03F4
  AND W_03F3
  STA W_03F5
  LDA W_03F3
  STA W_04C2
  LDA W_03F5
  STA W_04C1
  RTS

; Four words, one demo-pad record per W_03F0. The records are DEMO_REC_A, DEMO_REC_B, DEMO_REC_C, and DEMO_REC_D.
; Each record is pairs of pad byte and duration.
.DEMO_PAD_PTR
  EQUB LO(DEMO_REC_A)
.D5_9A8B
  EQUB HI(DEMO_REC_A)
  EQUW DEMO_REC_B
  EQUW DEMO_REC_C
  EQUW DEMO_REC_D
.DEMO_REC_A
  EQUB &00,&1D,&04,&1C,&01,&02,&81,&03,&01,&17,&04,&02,&84,&04,&04,&14
  EQUB &00,&00,&02,&13,&00,&11,&40,&03,&00,&25,&01,&07,&09,&00,&08,&1E
  EQUB &88,&05,&08,&1B,&80,&01,&81,&02,&01,&1B,&00,&00,&04,&12,&00,&18
  EQUB &40,&08,&00,&22,&08,&06,&09,&00,&01,&24,&00,&00,&04,&00,&84,&04
  EQUB &04,&17,&00,&00,&01,&10,&00,&0A,&40,&05,&00,&33,&01,&0F,&00,&1C
  EQUB &04,&1C,&00,&1C,&04,&04,&84,&06,&04,&04,&00,&02,&04,&13,&84,&00
  EQUB &80,&04,&00,&01,&01,&17,&00,&08,&04,&19,&00,&0A,&40,&04,&00,&2A
  EQUB &02,&06,&0A,&03,&02,&03,&00,&02,&08,&0B,&02,&1E,&04,&21,&84,&06
  EQUB &04,&17,&01,&13,&00,&08,&40,&05,&00,&1C,&02,&0B,&08,&1A,&02,&47
  EQUB &82,&00,&80,&00,&81,&02,&01,&14,&00,&00,&04,&26,&00,&01,&02,&00
  EQUB &42,&03,&02,&38,&82,&00,&80,&02,&81,&01,&01,&1C,&08,&0F,&00,&0E
  EQUB &40,&04,&00,&1F,&04,&10,&00,&02,&80,&04,&00,&03,&08,&17,&01,&16
  EQUB &00,&11,&40,&06,&00,&1D,&02,&07,&08,&62,&00,&01,&01,&1B,&00,&00
  EQUB &00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00
  EQUB &00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00
  EQUB &00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00

; Second demo-pad record. Pairs of held-pad byte and frame count. SERVICE_DEMO_PAD reads it through DEMO_PAD_PTR.
.DEMO_REC_B
  EQUB &00,&29,&04,&16,&00,&0B,&80,&05,&08,&0C,&00,&00,&01,&13,&00,&1C
  EQUB &40,&06,&00,&1D,&02,&0A,&04,&21,&00,&0A,&80,&04,&00,&01,&08,&15
  EQUB &00,&01,&01,&1A,&00,&0E,&40,&04,&00,&18,&02,&08,&06,&00,&04,&61
  EQUB &01,&22,&80,&01,&82,&02,&02,&18,&00,&00,&88,&04,&08,&15,&09,&00
  EQUB &01,&26,&00,&0B,&40,&04,&00,&1E,&80,&03,&00,&01,&04,&1C,&00,&05
  EQUB &04,&00,&01,&1D,&00,&02,&80,&03,&82,&01,&02,&17,&00,&0B,&80,&01
  EQUB &82,&01,&02,&1A,&00,&00,&04,&15,&00,&16,&40,&03,&00,&2D,&08,&29
  EQUB &09,&00,&01,&30,&00,&0B,&80,&04,&00,&00,&02,&06,&00,&00,&04,&17
  EQUB &00,&0F,&40,&02,&00,&1C,&08,&0C,&01,&44,&00,&00,&80,&02,&82,&02
  EQUB &02,&16,&82,&04,&02,&17,&00,&01,&08,&1E,&00,&01,&01,&15,&00,&06
  EQUB &40,&04,&00,&1B,&01,&2F,&88,&01,&80,&01,&82,&00,&0A,&00,&02,&0E
  EQUB &0A,&02,&08,&2C,&00,&06,&40,&03,&00,&10,&01,&0B,&00,&0D,&80,&04
  EQUB &02,&06,&04,&22,&00,&00,&01,&03,&41,&05,&01,&33,&04,&30,&00,&00
  EQUB &00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00
  EQUB &00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00
  EQUB &00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00

; Third demo-pad record. The fourth record begins 100h bytes later in this block.
.DEMO_REC_C
  EQUB &00,&26,&01,&17,&04,&44,&00,&03,&80,&04,&00,&00,&08,&18,&88,&05
  EQUB &08,&15,&01,&22,&41,&02,&40,&00,&00,&1C,&04,&20,&80,&01,&82,&02
  EQUB &02,&15,&00,&17,&02,&04,&00,&06,&04,&12,&00,&0E,&40,&04,&00,&1D
  EQUB &04,&0B,&00,&03,&80,&04,&00,&1A,&08,&13,&01,&15,&00,&26,&01,&13
  EQUB &00,&28,&04,&0F,&00,&07,&40,&05,&00,&1D,&04,&08,&05,&05,&01,&1F
  EQUB &00,&01,&80,&00,&82,&03,&02,&17,&00,&01,&08,&0E,&00,&0D,&40,&03
  EQUB &00,&29,&04,&06,&05,&05,&01,&5D,&00,&04,&04,&1D,&00,&00,&80,&03
  EQUB &00,&14,&02,&1E,&04,&19,&00,&0D,&40,&04,&00,&23,&08,&09,&02,&25
  EQUB &00,&00,&04,&01,&84,&04,&04,&16,&06,&00,&02,&01,&82,&03,&02,&15
  EQUB &06,&00,&04,&22,&44,&00,&40,&02,&00,&1E,&80,&00,&88,&03,&08,&18
  EQUB &88,&00,&89,&00,&81,&02,&01,&16,&08,&14,&00,&08,&40,&04,&00,&25
  EQUB &04,&0E,&84,&03,&04,&11,&05,&03,&01,&1E,&05,&01,&04,&01,&80,&00
  EQUB &82,&03,&02,&15,&82,&05,&02,&15,&08,&13,&00,&10,&40,&02,&00,&36
  EQUB &08,&2E,&00,&02,&80,&03,&00,&01,&04,&17,&84,&03,&04,&03,&00,&01
  EQUB &02,&1E,&84,&04,&04,&1C,&01,&0F,&00,&0E,&40,&02,&00,&2D,&02,&04
  EQUB &0A,&00,&08,&3F,&00,&01,&01,&18,&00,&00,&00,&00,&00,&00,&00,&00
.DEMO_REC_D
  EQUB &00,&26,&04,&14,&00,&09,&80,&03,&08,&0E,&00,&00,&01,&10,&00,&14
  EQUB &40,&06,&00,&1D,&02,&0C,&04,&22,&01,&00,&81,&03,&01,&16,&00,&00
  EQUB &04,&02,&84,&03,&04,&14,&00,&00,&02,&15,&00,&1B,&40,&05,&00,&1A
  EQUB &02,&0F,&82,&00,&80,&01,&81,&01,&01,&19,&89,&00,&88,&04,&08,&18
  EQUB &00,&05,&02,&12,&00,&11,&40,&03,&00,&27,&01,&0B,&00,&00,&04,&1F
  EQUB &05,&00,&01,&21,&04,&00,&00,&00,&82,&04,&02,&12,&06,&00,&04,&04
  EQUB &84,&04,&04,&1B,&84,&06,&04,&12,&01,&15,&00,&07,&40,&04,&00,&24
  EQUB &01,&0D,&09,&00,&08,&01,&88,&04,&08,&19,&88,&05,&08,&14,&01,&15
  EQUB &00,&08,&40,&05,&00,&25,&02,&09,&04,&1C,&05,&00,&01,&45,&05,&00
  EQUB &04,&00,&80,&00,&82,&04,&02,&18,&82,&05,&02,&13,&04,&1D,&00,&03
  EQUB &40,&04,&00,&21,&08,&0F,&09,&00,&01,&62,&00,&0E,&80,&04,&02,&17
  EQUB &08,&15,&00,&1F,&40,&05,&00,&20,&04,&0A,&05,&01,&01,&21,&04,&02
  EQUB &84,&04,&04,&18,&84,&04,&04,&17,&00,&00,&02,&14,&42,&01,&40,&02
  EQUB &00,&23,&02,&07,&82,&03,&02,&1A,&82,&06,&02,&18,&82,&00,&80,&00
  EQUB &88,&04,&08,&17,&02,&15,&00,&02,&40,&05,&00,&29,&01,&08,&05,&01
  EQUB &04,&28,&02,&18,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00

; Bonus stage. Saves Z_90, Z_93, Z_4B and Z_4C, sets Z_4E, area 0, stage 7, Z_90 to 8 and Z_93 to 5, then runs its own frame loop until Z_B7 reaches F0h.
; Restores the saved bytes, clears Z_4E and Z_B4, and returns. SHOW_BONUS_CARD runs first.
.RUN_BONUS_STAGE
  JSR SHOW_BONUS_CARD
  JSR NMI_OFF
  LDA #&01
  STA Z_4E
  ABS_LDA Z_90
  STA Z_4F
  ABS_LDA Z_93
  STA Z_50
  LDA Z_4B
  STA Z_52
  LDA Z_4C
  STA Z_51
  LDA #&08
  ABS_STA Z_90
  LDA #&05
  ABS_STA Z_93
  LDA #&07
  STA Z_4C
  LDA #&00
  STA Z_4B
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
  JSR LOAD_ENEMIES
  FARCALL 5, INIT_STAGE_CLOCK
  FARCALL 5, DRAW_STAGE_CLOCK
  FARCALL 5, DRAW_LIVES_HUD
  LDA #&00
  ABS_STA Z_B7
  STA Z_53
  STA X_62E6
  STA X_62E7
  STA X_62E8
  JSR PPU_ON
  JSR SET_TOP_SPLIT
  JSR MARK_PALETTE
  LDA #&14
  JSR AUDIO_CALL

; One bonus-stage frame: players, enemy spawn, blasts, enemies, DRAW_LIVES, the clock, and the bank routine DRAW_HUD_SCORE. Leaves when Z_B7 reaches F0h.
.BONUS_FRAME
  JSR WAIT_NMI
  JSR UPDATE_PLAYERS
  JSR STEP_ENEMY_GEN
  JSR UPDATE_BLASTS
  JSR UPDATE_ENEMIES
  FARCALL 5, DRAW_LIVES
  FARCALL 5, TICK_STAGE_CLOCK
  FARCALL 5, DRAW_HUD_SCORE
  ABS_LDA Z_B7
  CMP #&F0
  BCS L5_9F44
  JSR MARK_OAM
  JMP BONUS_FRAME
.L5_9F44
  LDA Z_4F
  ABS_STA Z_90
  LDA Z_50
  ABS_STA Z_93
  LDA Z_52
  STA Z_4B
  LDA Z_51
  STA Z_4C
  LDA #&00
  STA Z_4E
  ABS_STA Z_B4
  RTS

; Blank the screen, load mode CHR, draw the bonus string, wait B4h frames, and fade out.
.SHOW_BONUS_CARD
  JSR NMI_OFF
  JSR CLEAR_SCROLL
  LDA #&00
  JSR FILL_NAMETABLE
  JSR CLEAR_ATTRS
  JSR LOAD_MODE_GFX
  JSR LOAD_BONUS_PAL
  JSR DRAW_BONUS_TEXT
  JSR NMI_ON
  JSR PPU_ON
  JSR MARK_PALETTE
  LDA #&1D
  JSR AUDIO_CALL
  LDX #&B4
.L5_9F85
  JSR WAIT_NMI
  DEX
  BNE L5_9F85
  JSR FADE_PALETTE
  JMP PPU_OFF
IF REGION_JP

.DRAW_BONUS_TEXT
  LDA #&9E
ELSE

; Point Z_20 at the bonus string that follows LOAD_BONUS_PAL and call DRAW_INLINE_STR. The US string and the JP string are at different addresses in this bank.
.DRAW_BONUS_TEXT
  LDA #&AE
ENDIF
  STA Z_20
  LDA #&9F
  STA Z_21
  JMP DRAW_INLINE_STR
IF REGION_JP

.LOAD_BONUS_PAL
  LDA #&AC
ELSE

; Copy one 4-byte palette row from the bytes after the bonus string, then MIRROR_BG_COLOR.
.LOAD_BONUS_PAL
  LDA #&BC
ENDIF
  STA Z_16
  LDA #&9F
  STA Z_17
  LDA #&00
  LDX #&01
  JSR COPY_PAL_ROWS
  JMP MIRROR_BG_COLOR
  EQUB &0B,&0D,&0B,&42,&4F,&4E,&55,&53,&20,&53,&54,&41,&47,&45,&0F,&10
  EQUB &30,&0F

; Set Z_49 to 1, fill the nametable with 40h, load mode graphics, and repeat INIT_MODE1_SEL plus the menu handlers at SND_ROOM_INPUT. Does not return.
.RUN_MODE1_MENU
  JSR NMI_OFF
  LDA #&40
  JSR FILL_NAMETABLE
  LDA #&01
  STA Z_49
  JSR CLEAR_ATTRS
  JSR LOAD_MODE_GFX
  JSR NMI_ON
  JSR DRAW_SND_ROOM_TEXT
  JSR INIT_MODE1_SEL
  JSR PPU_ON
  JSR MARK_PALETTE
.L5_9FE1
  JSR WAIT_NMI
  JSR SND_ROOM_INPUT
  JSR DRAW_SND_CURSOR
  JSR DRAW_SND_PARAMS
  JSR MARK_OAM
  JMP L5_9FE1

; Zero W_04CD and copy the three bytes at SND_PARAM_MIN into W_04CE, W_04CF and W_04D0.
.INIT_MODE1_SEL
  LDA #&00
  STA W_04CD
  LDA SND_PARAM_MIN
  STA W_04CE
  LDA D5_A086
  STA W_04CF
  LDA D5_A087
  STA W_04D0
  RTS

; Sound-room input. Called each frame from RUN_MODE1_MENU.
; In: JOY_NEW. Up/down wraps W_04CD in 0..2.
; B/A clamp W_04CE,X to SND_PARAM_MIN/MAX.
; Start plays that byte; Select plays command 80h.
.SND_ROOM_INPUT
  LDX JOY_NEW
  TXA
  AND #&08
  BNE SND_CUR_UP
  TXA
  AND #&04
  BNE SND_CUR_DOWN
  TXA
  AND #&20
  BNE L5_A048
  TXA
  AND #&10
  BNE SND_PLAY_PARAM
  TXA
  AND #&40
  BNE SND_PARAM_DOWN
  TXA
  AND #&80
  BNE SND_PARAM_UP
  RTS
.SND_CUR_UP
  DEC W_04CD
  BPL L5_A037
  LDA #&02
  STA W_04CD
.L5_A037
  RTS
.SND_CUR_DOWN
  INC W_04CD
  LDA W_04CD
  CMP #&03
  BCC L5_A037
  LDA #&00
  STA W_04CD
  RTS
.L5_A048
  LDA #&80
  JMP AUDIO_CALL
.SND_PLAY_PARAM
  LDX W_04CD
  LDA W_04CE,X
  JMP AUDIO_CALL
.SND_PARAM_DOWN
  LDX W_04CD
  DEC W_04CE,X
  BMI L5_A066
  LDA W_04CE,X
  CMP SND_PARAM_MIN,X
  BCS L5_A06F
.L5_A066
  LDA SND_PARAM_MAX,X
  SEC
  SBC #&01
  STA W_04CE,X
.L5_A06F
  RTS
.SND_PARAM_UP
  LDX W_04CD
  INC W_04CE,X
  LDA W_04CE,X
  CMP SND_PARAM_MAX,X
  BCC L5_A084
  LDA SND_PARAM_MIN,X
  STA W_04CE,X
.L5_A084
  RTS

; Sound-room minimum for the three W_04CE values. 3 bytes: 0Ch, 00h, 1Eh.
.SND_PARAM_MIN
  EQUB &0C
.D5_A086
  EQUB &00
.D5_A087
  EQUB &1E

; Sound-room exclusive maximum. 3 bytes: 1Eh, 0Ch, 2Bh. One past the last accepted value.
.SND_PARAM_MAX
  EQUB &1E,&0C,&2B
.SND_CURSOR_X
  EQUB &40

; Cursor Y for sound-room rows 0..2. 3 bytes: 50h, 60h, 70h. X is the single byte SND_CURSOR_X.
.SND_CURSOR_Y
  EQUB &50,&60,&70

; Draw the sound-room cursor.
; In: W_04CD. X from SND_CURSOR_X, Y from SND_CURSOR_Y.
.DRAW_SND_CURSOR
  LDX W_04CD
  LDA SND_CURSOR_X
  ABS_STA Z_56
  LDA SND_CURSOR_Y,X
  ABS_STA Z_58
  LDA #&00
  ABS_STA Z_57
  ABS_STA Z_5A
IF REGION_JP
  LDA #&A1
ELSE
  LDA #&B1
ENDIF
  STA Z_54
  LDA #&A0
  STA Z_55
  JMP DRAW_METASPRITE
  EQUB &01,&2A,&00,&00,&00

; Draw the three sound-room values by calling DRAW_SND_VALUE with X=0,1,2.
.DRAW_SND_PARAMS
  LDX #&00
  JSR DRAW_SND_VALUE
  LDX #&01
  JSR DRAW_SND_VALUE
  LDX #&02

; Draw one sound parameter as two glyphs.
; In: X = row 0..2. Value is W_04CE,X minus SND_PARAM_MIN.
; Queued at column 12h, row SND_VALUE_ROW,X.
.DRAW_SND_VALUE
  LDA W_04CE,X
  SEC
  SBC SND_PARAM_MIN,X
  STA Z_1C
  LSR A
  LSR A
  LSR A
  LSR A
  TAY
  LDA SND_HEX_GLYPH,Y
  STA W_052A
  LDA Z_1C
  AND #&0F
  TAY
  LDA SND_HEX_GLYPH,Y
  STA W_052B
  LDY SND_VALUE_ROW,X
  LDX #&12
  JSR XY_TO_NT_ADDR
IF REGION_JP
  LDA #&28
ELSE
  LDA #&2A
ENDIF
  STA Z_20
  LDA #&05
  STA Z_21
  LDX #&02
  LDA #&00
  STA Z_2E
  JMP QUEUE_PPU_RUN

; Nametable rows for the three sound values. 3 bytes: 0Ah, 0Ch, 0Eh.
.SND_VALUE_ROW
  EQUB &0A,&0C,&0E

; 16 tiles for a nibble, used by DRAW_SND_VALUE. 30h..39h then 41h..46h.
.SND_HEX_GLYPH
  EQUB &30,&31,&32,&33,&34,&35,&36,&37,&38,&39,&41,&42,&43,&44,&45,&46
IF REGION_JP

.DRAW_SND_ROOM_TEXT
  LDA #&4E
ELSE

; Queue the four sound-room strings through QUEUE_XY_BYTES.
; Each record is X, Y, length, then tiles.
.DRAW_SND_ROOM_TEXT
  LDA #&5E
ENDIF
  STA Z_20
  LDA #&A1
  STA Z_21
  JSR QUEUE_XY_BYTES
IF REGION_JP
  LDA #&6A
ELSE
  LDA #&77
ENDIF
  STA Z_20
  LDA #&A1
  STA Z_21
  JSR QUEUE_XY_BYTES
IF REGION_JP
  LDA #&72
ELSE
  LDA #&7F
ENDIF
  STA Z_20
  LDA #&A1
  STA Z_21
  JSR QUEUE_XY_BYTES
IF REGION_JP
  LDA #&7B
ELSE
  LDA #&88
ENDIF
  STA Z_20
  LDA #&A1
  STA Z_21
  JMP QUEUE_XY_BYTES

; Queue a nametable run from a record at Z_20.
; In: (Z_20) = X, Y, length, bytes. Advances Z_20 past the header.
; Out: PPU queue via QUEUE_PPU_RUN. Z_2E cleared.
.QUEUE_XY_BYTES
  LDY #&00
  LDA (Z_20),Y
  TAX
  INY
  LDA (Z_20),Y
  TAY
  JSR XY_TO_NT_ADDR
  LDY #&02
  LDA (Z_20),Y
  TAX
  LDA Z_20
  CLC
  ADC #&03
  STA Z_20
  LDA Z_21
  ADC #&00
  STA Z_21
  LDA #&00
  STA Z_2E
  JMP QUEUE_PPU_RUN
IF REGION_JP
  EQUB &03
ELSE
ENDIF
  EQUB &05
IF REGION_JP
  EQUB &19
ELSE
  EQUB &05,&16,&40
ENDIF
  EQUB &42,&4F,&4D,&42,&45,&52
IF REGION_JP
  EQUB &40
ELSE
ENDIF
  EQUB &4D,&41,&4E
IF REGION_JP
  EQUB &40
ELSE
ENDIF
  EQUB &32
IF REGION_JP
  EQUB &40
ELSE
ENDIF
  EQUB &40,&53,&4F,&55,&4E,&44,&40,&52,&4F,&4F,&4D
IF REGION_JP
  EQUB &40
ELSE
ENDIF
  EQUB &0A,&0A,&05,&4D,&55,&53,&49,&43,&0A,&0C,&06,&45,&46,&46,&45,&43
  EQUB &54,&0A,&0E,&03,&50,&43,&4D

; Title screen. SHOW_FRONT enters here.
; Loads CHR, map and palette, then animates until Start/A or the idle timer W_051F/W_0520 hits 0.
; Idle timeout calls START_DEMO. Exit fades and turns the PPU off.
.RUN_TITLE
  JSR PPU_OFF
  JSR NMI_OFF
  JSR CLEAR_SCROLL
IF REGION_JP
  LDA #&01
ELSE
  LDA #&00
  STA SCROLL_X
  LDA #&01
ENDIF
  STA W_0521
  STA SCROLL_NT
  LDA #&60
  STA SCROLL_Y
  LDA #&00
  STA W_0523
  STA W_0522
  STA W_0524
  LDA #&FF
  STA W_04E4
  LDA #&00
  JSR FILL_NAMETABLE
  JSR CLEAR_ATTRS
  JSR LOAD_TITLE_CHR
IF REGION_JP
  JSR JP_TITLE_PAL
  JSR JP_TITLE_MAP_A
ELSE
  JSR LOAD_TITLE_PAL
  JSR DRAW_TITLE_MAP
ENDIF
  LDA #&00
  STA W_051E
  ABS_STA Z_49
  LDA #&DC
  STA W_051F
  LDA #&05
  STA W_0520
  LDA #&00
  STA W_03EF
  JSR NMI_ON
  JSR RESET_TITLE_FRAME
IF REGION_JP
  JSR JP_DRAW_BANNER
  JSR CLEAR_OAM
  JSR DRAW_TITLE_ACTORS
  JSR MARK_OAM
  JSR PPU_ON
  JSR SET_LOW_SPLIT
  JSR MARK_PALETTE
ELSE
  JSR CLEAR_OAM
  JSR DRAW_TITLE_ACTORS
  JSR MARK_OAM
  JSR PPU_ON
  JSR SET_LOW_SPLIT
  JSR MARK_PALETTE
ENDIF
  LDA #&27
  JSR AUDIO_CALL
.TITLE_LOOP
  JSR WAIT_NMI
  JSR STEP_TITLE_SCROLL
  JSR DRAW_TITLE_ACTORS
  JSR BLINK_START_TEXT
  JSR MARK_OAM
IF REGION_JP
ELSE
  LDA W_0521
  BNE L5_A219
ENDIF
  LDA JOY_NEW
  AND #&90
  BNE TITLE_START_EXIT
.L5_A219
  DEC W_051F
  LDA W_051F
  CMP #&FF
  BNE L5_A226
  DEC W_0520
.L5_A226
  LDA W_051F
  ORA W_0520
  BNE TITLE_LOOP
  JSR START_DEMO
.TITLE_START_EXIT
  JSR FADE_PALETTE
  JMP PPU_OFF

; Upload TITLE_SPR_CHR at PPU $1000 and TITLE_BG_CHR at $0000.
; RLE. No inputs. Falls into the US map setup on the US path.
.LOAD_TITLE_CHR
  LDA #LO(TITLE_SPR_CHR)
  STA Z_20
  LDA #HI(TITLE_SPR_CHR)
  STA Z_21
  LDA #&00
  STA Z_22
  LDA #&10
  STA Z_23
  LDX #&01
  LDY #&FF
  JSR UPLOAD_CHR_RLE
  LDA #LO(TITLE_BG_CHR)
IF REGION_JP
  STA Z_20
  LDA #HI(TITLE_BG_CHR)
  STA Z_21
  LDA #&00
  STA Z_22
  LDA #&00
  STA Z_23
  LDX #&01
  LDY #&FF
  JMP UPLOAD_CHR_RLE

; JP title map piece. FARCALL bank 4 S4_BACB with D4_A8B5 and D4_A900.
.JP_TITLE_MAP_A
  LDA #LO(D4_A8B5)
  STA Z_20
  LDA #HI(D4_A8B5)
  STA Z_21
  LDA #LO(D4_A900)
  STA Z_24
  LDA #HI(D4_A900)
  STA Z_25
  FARCALL 4, S4_BACB
  RTS

; JP title palette. FARCALL bank 4 COPY_PAL_ROWS, 8 rows from D4_B0F9.
.JP_TITLE_PAL
  LDA #LO(D4_B0F9)
  STA Z_16
  LDA #HI(D4_B0F9)
  STA Z_17
  LDA #&00
  LDX #&08
  FARCALL 4, COPY_PAL_ROWS
  JMP MIRROR_BG_COLOR

; JP: queue 11h bytes of TITLE_LOGO_TILES at the XY in JD5_A2B1.
.JP_DRAW_BANNER
  LDX JD5_A2B1
  LDY JD5_A2B2
  JSR XY_TO_NT_ADDR
  LDA #LO(TITLE_LOGO_TILES)
  STA Z_20
  LDA #HI(TITLE_LOGO_TILES)
  STA Z_21
  LDA #&00
  STA Z_2E
  LDX #&11
  JMP QUEUE_PPU_RUN

; JP: queue the same 11h bytes at the XY in JD5_A2B3. Called when the title scroll finishes.
.JP_DRAW_BANNER2
  LDX JD5_A2B3
  LDY JD5_A2B4
  JSR XY_TO_NT_ADDR
  LDA #LO(TITLE_LOGO_TILES)
ELSE
  STA Z_20
  LDA #HI(TITLE_BG_CHR)
  STA Z_21
  LDA #&00
  STA Z_22
  LDA #&00
  STA Z_23
  LDX #&01
  LDY #&FF
  JMP UPLOAD_CHR_RLE

; US title background. FARCALL bank 4 S4_BADB and S4_BACB with D4_A8F4/D4_A8B5 and D4_A900.
.DRAW_TITLE_MAP
  LDA #LO(D4_A8F4)
  STA Z_20
  LDA #HI(D4_A8F4)
  STA Z_21
  LDA #LO(D4_A900)
  STA Z_24
  LDA #HI(D4_A900)
  STA Z_25
  FARCALL 4, S4_BADB
  LDA #LO(D4_A8B5)
ENDIF
  STA Z_20
IF REGION_JP
  LDA #HI(TITLE_LOGO_TILES)
  STA Z_21
  LDA #&00
  STA Z_2E
  LDX #&11
  JMP QUEUE_PPU_RUN
.JD5_A2B1
  EQUB &28
.JD5_A2B2
  EQUB &19
.JD5_A2B3
  EQUB &08
.JD5_A2B4
  EQUB &19
ELSE
  LDA #HI(D4_A8B5)
  STA Z_21
  LDA #LO(D4_A900)
  STA Z_24
  LDA #HI(D4_A900)
  STA Z_25
  FARCALL 4, S4_BACB
  RTS

; US title palette. FARCALL bank 4 COPY_PAL_ROWS of 8 rows from D4_B0F9, then MIRROR_BG_COLOR.
.LOAD_TITLE_PAL
  LDA #LO(D4_B0F9)
  STA Z_16
  LDA #HI(D4_B0F9)
  STA Z_17
  LDA #&00
  LDX #&08
  FARCALL 4, COPY_PAL_ROWS
  JMP MIRROR_BG_COLOR

; US: queue two 1Dh-byte nametable runs, TITLE_BANNER_TOP at (0,18h) and TITLE_BANNER_BOT at (0,1Ah).
.DRAW_TITLE_BANNER
  LDA #&00
  STA Z_2E
  LDX D5_A2DB
  LDY D5_A2DC
  JSR XY_TO_NT_ADDR
  LDA #LO(TITLE_BANNER_TOP)
  STA Z_20
  LDA #HI(TITLE_BANNER_TOP)
  STA Z_21
  LDX #&1D
  JSR QUEUE_PPU_RUN
  LDX D5_A2DD
  LDY D5_A2DE
  JSR XY_TO_NT_ADDR
  LDA #LO(TITLE_BANNER_BOT)
  STA Z_20
  LDA #HI(TITLE_BANNER_BOT)
  STA Z_21
  LDX #&1D
  JMP QUEUE_PPU_RUN
  EQUB &20,&18,&20,&1A
.D5_A2DB
  EQUB &00
.D5_A2DC
  EQUB &18
.D5_A2DD
  EQUB &00
.D5_A2DE
  EQUB &1A
.TITLE_BANNER_TOP
  EQUB &00,&00,&00,&00,&E7,&F3,&00,&E6,&E5,&E9,&00
ENDIF
.TITLE_LOGO_TILES
  EQUB &ED
IF REGION_JP
ELSE
  EQUB &00
ENDIF
  EQUB &EB,&EC,&EC
IF REGION_JP
  EQUB &EB
ELSE
  EQUB &F9
ENDIF
  EQUB &00,&E3,&E1,&E9,&E2,&E8,&E5,&00,&E2,&E8,&EA,&E7
IF REGION_JP
ELSE
.TITLE_BANNER_BOT
  EQUB &00,&00,&00,&00,&00,&00,&F4,&F5,&F6,&EE,&E5,&E2,&EE,&E9,&00,&F7
  EQUB &F8,&00,&E5,&F5,&E5,&E7,&EE,&E5,&E9,&E8,&00,&00,&00
ENDIF

; Blink the title prompt while W_0521 is 0.
; W_051E counts to 20h (draw START_TEXT_ON) and 38h (blank START_TEXT_OFF, reset).
.BLINK_START_TEXT
  LDA W_0521
  BNE L5_A32C
  INC W_051E
  LDA W_051E
  CMP #&20
  BEQ L5_A34A
  CMP #&38
  BEQ L5_A32D
.L5_A32C
  RTS
.L5_A32D
  LDA #&00
  STA W_051E
  LDX #&0B
IF REGION_JP
  LDY #&16
ELSE
  LDY #&15
ENDIF
  JSR XY_TO_NT_ADDR
  LDA #LO(START_TEXT_ON)
  STA Z_20
  LDA #HI(START_TEXT_ON)
  STA Z_21
  LDA #&00
  STA Z_2E
  LDX #&0B
  JMP QUEUE_PPU_RUN
.L5_A34A
  LDX #&0B
IF REGION_JP
  LDY #&16
ELSE
  LDY #&15
ENDIF
  JSR XY_TO_NT_ADDR
  LDA #LO(START_TEXT_OFF)
  STA Z_20
  LDA #HI(START_TEXT_OFF)
  STA Z_21
  LDA #&00
  STA Z_2E
  LDX #&0B
  JMP QUEUE_PPU_RUN

; 11 tiles queued when the title prompt turns on. START_TEXT_OFF is 11 zero tiles.
.START_TEXT_ON
  EQUB &E0,&E1,&E2,&E3,&00,&E2,&E7,&E6,&E4,&E7,&EF
.START_TEXT_OFF
  EQUB &00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00
  EQUB &00

; Clear title sprite frame W_0525 and tick W_0526.
.RESET_TITLE_FRAME
  LDA #&00
  STA W_0525
  STA W_0526
  RTS

; Title sprites. Advances W_0525 every 8 frames, 3 frames.
; Draws TITLE_ACTOR_PTR[frame] and TITLE_BOMBER_SPR unless sprite Y is in B0h..DFh.
.DRAW_TITLE_ACTORS
  INC W_0526
  LDA W_0526
  CMP #&08
  BCC L5_A3A5
  LDA #&00
  STA W_0526
  INC W_0525
  LDA W_0525
  CMP #&03
  BCC L5_A3A5
  LDA #&00
  STA W_0525
.L5_A3A5
  JSR DRAW_TITLE_LOGO
  JSR TITLE_SPRITE_Y
  ABS_LDA Z_58
  CMP #&B0
  BCC L5_A3B6
  CMP #&E0
  BCC L5_A3E0
.L5_A3B6
  LDA #&00
  ABS_STA Z_5A
  LDA W_0525
  ASL A
  TAY
  LDA TITLE_ACTOR_PTR,Y
  STA Z_54
  LDA D5_A411,Y
  STA Z_55
  JSR DRAW_METASPRITE
  JSR TITLE_SPRITE_Y
  LDA #&00
  ABS_STA Z_5A
  LDA #LO(TITLE_BOMBER_SPR)
  STA Z_54
  LDA #HI(TITLE_BOMBER_SPR)
  STA Z_55
  JMP DRAW_METASPRITE
.L5_A3E0
  RTS

; Draw the scrolling logo when SCROLL_Y is 60h..87h (frame 0) or >= 88h (frame 1).
; Sprite Y is fixed at B2h. Uses TITLE_SPRITE_X.
.DRAW_TITLE_LOGO
  LDX #&00
  LDA SCROLL_Y
  BEQ L5_A3F5
  CMP #&60
  BCC L5_A3F5
  CMP #&88
  BCC L5_A3F6
  LDX #&02
  JMP L5_A3F6
.L5_A3F5
  RTS
.L5_A3F6
  LDA TITLE_LOGO_PTR,X
  STA Z_54
  LDA D5_A440,X
  STA Z_55
  JSR TITLE_SPRITE_X
  LDA #&B2
  ABS_STA Z_58
  LDA #&20
  ABS_STA Z_5A
  JMP DRAW_METASPRITE

; 3 words. Metasprite pointers TITLE_ACTOR_0, TITLE_ACTOR_1, TITLE_ACTOR_2. Index is W_0525.
.TITLE_ACTOR_PTR
  EQUB LO(TITLE_ACTOR_0)
.D5_A411
  EQUB HI(TITLE_ACTOR_0)
  EQUW TITLE_ACTOR_1
  EQUW TITLE_ACTOR_2

; Title sprite Y from the scroll.
; Out: Z_58 = 20h-SCROLL_Y, minus 10h when SCROLL_Y >= 40h. Falls through to TITLE_SPRITE_X if SCROLL_Y >= 40h.
.TITLE_SPRITE_Y
  LDA #&20
  SEC
  SBC SCROLL_Y
  ABS_STA Z_58
  LDA SCROLL_Y
  CMP #&40
  BCC TITLE_SPRITE_X
  ABS_LDA Z_58
  SEC
  SBC #&10
  ABS_STA Z_58

; Title sprite X.
; Out: Z_56 = 48h-SPLIT_SCROLL_X, Z_57 = SCROLL_NT.
.TITLE_SPRITE_X
  LDA #&48
  SEC
  SBC SPLIT_SCROLL_X
  ABS_STA Z_56
  LDA SCROLL_NT
  ABS_STA Z_57
  RTS

; 2 words. TITLE_LOGO_A and TITLE_LOGO_B. DRAW_METASPRITE records: count, then count*(tile, dx, dy, attr).
.TITLE_LOGO_PTR
  EQUB LO(TITLE_LOGO_A)
.D5_A440
  EQUB HI(TITLE_LOGO_A)
  EQUW TITLE_LOGO_B
.TITLE_LOGO_A
  EQUB &23,&0B,&E0,&E8,&00,&0B,&E8,&E8,&00,&0B,&F0,&E8,&00,&0B,&F8,&E8
  EQUB &00,&0B,&00,&E8,&00,&0B,&E0,&F0,&00,&0B,&E8,&F0,&00,&0B,&F0,&F0
  EQUB &00,&0B,&F8,&F0,&00,&0B,&00,&F0,&00,&0B,&E0,&F8,&00,&0B,&E8,&F8
  EQUB &00,&0B,&F0,&F8,&00,&0B,&F8,&F8,&00,&0B,&00,&F8,&00,&0B,&E0,&00
  EQUB &00,&0B,&E8,&00,&00,&0B,&F0,&00,&00,&0B,&F8,&00,&00,&0B,&00,&00
  EQUB &00,&0B,&E0,&08,&00,&0B,&E8,&08,&00,&0B,&F0,&08,&00,&0B,&F8,&08
  EQUB &00,&0B,&00,&08,&00,&0B,&E0,&10,&00,&0B,&E8,&10,&00,&0B,&F0,&10
  EQUB &00,&0B,&F8,&10,&00,&0B,&00,&10,&00,&0B,&E0,&18,&00,&0B,&E8,&18
  EQUB &00,&0B,&F0,&18,&00,&0B,&F8,&18,&00,&0B,&00,&18,&00
.TITLE_LOGO_B
  EQUB &14,&0B,&E0,&E8,&00,&0B,&E8,&E8,&00,&0B,&F0,&E8,&00,&0B,&F8,&E8
  EQUB &00,&0B,&00,&E8,&00,&0B,&E0,&F0,&00,&0B,&E8,&F0,&00,&0B,&F0,&F0
  EQUB &00,&0B,&F8,&F0,&00,&0B,&00,&F0,&00,&0B,&E0,&F8,&00,&0B,&E8,&F8
  EQUB &00,&0B,&F0,&F8,&00,&0B,&F8,&F8,&00,&0B,&00,&F8,&00,&0B,&E0,&00
  EQUB &00,&0B,&E8,&00,&00,&0B,&F0,&00,&00,&0B,&F8,&00,&00,&0B,&00,&00
  EQUB &00

; Title scroll state in W_0521.
; 1: wait W_0522 to 2Dh, play sound 01h, go to 2.
; 2: TITLE_SHAKE drives SPLIT_SCROLL_X; SCROLL_Y increments to F0h, then the scroll stops and DRAW_TITLE_BANNER runs.
; Every 8 scanlines of the scroll, queue one 20h-byte row from TITLE_MAP_ROWS.
.STEP_TITLE_SCROLL
  LDA W_0521
  BEQ L5_A584
  CMP #&02
  BEQ TITLE_SCROLL_ON
  INC W_0522
  LDA W_0522
  CMP #&2D
  BCC L5_A584
  INC W_0521
  LDA #&01
  JSR AUDIO_CALL
.TITLE_SCROLL_ON
  INC W_0524
  LDA W_0524
  AND #&0F
  STA W_0524
  ASL A
  TAX
IF REGION_JP
  LDA JP_TITLE_SHAKE,X
ELSE
  LDA TITLE_SHAKE,X
ENDIF
  STA SPLIT_SCROLL_X
IF REGION_JP
  LDA JD5_A533,X
ELSE
  LDA D5_A586,X
ENDIF
  AND #&01
  STA SPLIT_CTRL_BIT
  INC SCROLL_Y
  LDA SCROLL_Y
  CMP #&F0
  BCC TITLE_DRAW_ROW
  LDA #&00
  STA SCROLL_Y
  STA W_0521
  LDA #&00
  STA SPLIT_SCROLL_X
  LDA #&01
  STA SPLIT_CTRL_BIT
  LDA #&0D
  JSR AUDIO_CALL
  LDA #&00
  ABS_STA SPLIT_MODE
  STA SCROLL_NT
IF REGION_JP
  JSR JP_DRAW_BANNER2
ELSE
  JSR DRAW_TITLE_BANNER
ENDIF
  RTS
.L5_A584
  RTS
IF REGION_JP
.JP_TITLE_SHAKE
  EQUB &FA
.JD5_A533
  EQUB &FF,&FD,&FF,&FA,&FF,&FD,&FF,&FA,&FF,&FD,&FF
ELSE
ENDIF

; 16 words. Low byte is SPLIT_SCROLL_X, bit 0 of the high byte is SPLIT_CTRL_BIT. Index is W_0524.
.TITLE_SHAKE
  EQUB &FE
.D5_A586
  EQUB &FF
IF REGION_JP
  EQUB &FB,&FF
ELSE
  EQUB &01,&00
ENDIF
  EQUB &FE,&FF
IF REGION_JP
ELSE
  EQUB &01,&00
ENDIF
  EQUB &FE,&FF
IF REGION_JP
  EQUB &FD,&FF,&FA,&FF,&FA,&FF,&FD,&FF
ELSE
  EQUB &01,&00,&02,&00,&FF,&FF,&02,&00,&02,&00,&01,&00
ENDIF
  EQUB &FE,&FF
IF REGION_JP
  EQUB &FB
ELSE
  EQUB &FE,&FF,&01,&00,&02,&00,&FF
ENDIF
  EQUB &FF
.TITLE_DRAW_ROW
  AND #&07
  BNE L5_A5EE
  LDX #&00
  STX Z_21
  LDA W_0523
  BMI L5_A5EE
  ASL A
  ROL Z_21
  ASL A
  ROL Z_21
  ASL A
  ROL Z_21
  ASL A
  ROL Z_21
  ASL A
  ROL Z_21
  CLC
  ADC #LO(TITLE_MAP_ROWS)
  STA Z_20
  LDA Z_21
  ADC #HI(TITLE_MAP_ROWS)
  STA Z_21
  LDY W_0523
  INY
  INY
  LDX #&00
  JSR XY_TO_NT_ADDR
  LDA #&00
  STA Z_2E
  LDX #&20
  JSR QUEUE_PPU_RUN
  INC W_0523
  LDA W_0523
  CMP #&11
  BCC L5_A5EE
  LDA #&FF
  STA W_0523
.L5_A5EE
  RTS

; Title nametable rows revealed while SCROLL_Y climbs. 11h rows of 20h tiles. Not pointers.
.TITLE_MAP_ROWS
  EQUB &00,&00,&02,&03,&04,&05,&06,&00,&00,&00,&00,&00,&00,&00,&00,&00
  EQUB &00,&00,&00,&00,&00,&00,&00,&00,&80,&81,&82,&00,&00,&00,&00,&00
  EQUB &00,&11,&12,&13,&14,&15,&16,&00,&00,&19,&1A,&00,&00,&00,&00,&00
  EQUB &00,&00,&00,&00,&00,&08,&27,&23,&24,&25,&83,&84,&85,&86,&00,&00
  EQUB &00,&21,&22,&10,&F0,&F1,&26,&00,&28,&29,&2A,&2B,&2C,&2D,&00,&2F
  EQUB &95,&96,&00,&20,&07,&18,&37,&33,&34,&35,&10,&10,&87,&88,&89,&00
  EQUB &00,&31,&32,&10,&F2,&3A,&36,&00,&38,&39,&10,&3B,&3C,&3D,&3E,&3F
  EQUB &97,&98,&99,&30,&17,&10,&10,&43,&44,&10,&09,&0A,&10,&8A,&8B,&00
  EQUB &00,&41,&42,&10,&10,&45,&46,&47,&48,&10,&10,&10,&10,&4D,&4E,&10
  EQUB &10,&01,&9A,&40,&10,&10,&10,&54,&55,&10,&10,&10,&8C,&8D,&8E,&00
  EQUB &00,&00,&31,&53,&10,&A3,&56,&57,&58,&10,&10,&10,&10,&5D,&5E,&10
  EQUB &10,&10,&9B,&50,&10,&10,&10,&64,&65,&10,&10,&90,&91,&92,&00,&00
  EQUB &00,&00,&41,&63,&10,&CF,&66,&67,&68,&69,&10,&69,&10,&6D,&6E,&10
  EQUB &10,&01,&9C,&60,&10,&10,&10,&0B,&0C,&0D,&0E,&0F,&93,&00,&00,&00
  EQUB &00,&00,&00,&73,&74,&75,&76,&77,&78,&79,&7A,&79,&7C,&7D,&7E,&7F
  EQUB &7F,&9D,&9E,&70,&7F,&7F,&7F,&1B,&1C,&1D,&1E,&1F,&94,&00,&00,&00
  EQUB &00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&D0,&D1
  EQUB &D2,&D3,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00
  EQUB &00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&D4,&D5
  EQUB &D6,&D7,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00,&00
  EQUB &00,&00,&00,&00,&00,&00,&49,&4A,&4B,&4C,&00,&00,&00,&00,&D8,&D9
  EQUB &DA,&DB,&00,&00,&00,&00,&C2,&C3,&C4,&C5,&00,&00,&00,&00,&00,&00
  EQUB &00,&00,&00,&00,&00,&00,&59,&5A,&10,&5C,&A0,&A1,&A2,&00,&DC,&DD
  EQUB &DE,&DF,&00,&6A,&6B,&6C,&C6,&C7,&10,&C8,&00,&00,&00,&00,&00,&00
  EQUB &00,&00,&00,&00,&00,&00,&41,&42,&10,&10,&B0,&B1,&B2,&B3,&51,&52
  EQUB &A9,&AA,&AB,&AC,&10,&AD,&C9,&10,&CA,&CB,&00,&00,&00,&00,&00,&00
  EQUB &00,&00,&00,&00,&00,&00,&00,&31,&53,&10,&10,&10,&10,&2E,&61,&62
  EQUB &10,&B4,&B5,&B6,&10,&10,&10,&10,&CC,&00,&00,&00,&00,&00,&00,&00
  EQUB &00,&00,&00,&00,&00,&00,&00,&41,&42,&10,&10,&10,&10,&4F,&71,&72
  EQUB &B7,&B8,&B9,&BA,&10,&10,&10,&CA,&CB,&00,&00,&00,&00,&00,&00,&00
  EQUB &00,&00,&00,&00,&00,&00,&00,&00,&31,&53,&10,&10,&10,&5F,&8F,&10
  EQUB &10,&10,&7B,&10,&AE,&10,&10,&CC,&00,&00,&00,&00,&00,&00,&00,&00
  EQUB &00,&00,&00,&00,&00,&00,&00,&00,&A4,&A5,&A6,&A7,&A8,&6F,&9F,&BB
  EQUB &BC,&BD,&BE,&BF,&C0,&C1,&CD,&CE
IF REGION_JP
  EQUB &00,&00
ELSE
  EQUB &E7,&F3
ENDIF
  EQUB &00,&00,&00,&00,&00,&00

; Game-mode menu. RUN_MODE_MENU enters here.
; Clears W_054E, W_054F, W_0550, sets W_0563 to 1, fills the nametable with tile 13h.
; Up/Down/Select cycle Z_49 in 0..3. Start/A confirms.
; On the US build, Z_49 2 is rejected when JOY_SIG_OK is 0 (sound 04h).
; MODE_TO_AREA then writes W_04C9. Fades out.
.MODE_MENU_LOOP
  LDA #&00
  STA W_054E
  STA W_054F
  STA W_0550
  LDA #&01
  STA W_0563
  JSR PPU_OFF
  JSR NMI_OFF
  JSR CLEAR_SCROLL
  LDA #&13
  JSR FILL_NAMETABLE
  JSR CLEAR_ATTRS
  JSR LOAD_MENU_CHR
  JSR LOAD_MODE_PAL
  JSR DRAW_MODE_MENU
  LDA #&00
  ABS_STA Z_49
  STA W_04C9
  STA W_03EF
  ABS_STA Z_4A
  JSR NMI_ON
  JSR PPU_ON
  JSR MARK_PALETTE
  LDA #&13
  JSR AUDIO_CALL
.MODE_MENU_WAIT
  JSR WAIT_NMI
  JSR MODE_MENU_INPUT
  JSR DRAW_MODE_CURSOR
  JSR MARK_OAM
  JSR NEXT_RNG
  LDA JOY_NEW
  AND #&90
  BEQ MODE_MENU_WAIT
  ABS_LDX Z_49
  LDA MODE_ID_VALUE,X
  ABS_STA Z_49
IF REGION_JP
ELSE
  CMP #&02
  BNE L5_A885
  ABS_LDA JOY_SIG_OK
  BNE L5_A885
  LDA #&04
  JSR AUDIO_CALL
  JMP MODE_MENU_WAIT
ENDIF
.L5_A885
  JSR MODE_TO_AREA
  JSR FADE_PALETTE
  JMP PPU_OFF

; 4 bytes written back to Z_49 when the mode menu confirms: 00h, 01h, 02h, 03h.
.MODE_ID_VALUE
  EQUB &00,&01,&02,&03

; Upload UI_SPR_CHR (6 RLE blocks at $1000) and PLAY_BG_CHR (C0h bytes at $0000).
.LOAD_MENU_CHR
  LDA #LO(UI_SPR_CHR)
  STA Z_20
  LDA #HI(UI_SPR_CHR)
  STA Z_21
  LDA #&00
  STA Z_22
  LDA #&10
  STA Z_23
  LDX #&06
  LDY #&FF
  JSR UPLOAD_CHR_RLE
  LDA #LO(PLAY_BG_CHR)
  STA Z_20
  LDA #HI(PLAY_BG_CHR)
  STA Z_21
  LDA #&00
  STA Z_22
  LDA #&00
  STA Z_23
  LDX #&01
  LDY #&C0
  JMP UPLOAD_CHR_RLE

; Mode menu. Select, Down or Up change Z_49, wrapping 0..3, and play sound 07h.
.MODE_MENU_INPUT
  LDX JOY_NEW
  TXA
  AND #&20
  BNE L5_A8E3
  TXA
  AND #&04
  BNE L5_A8E3
  TXA
  AND #&08
  BNE L5_A8D3
  RTS
.L5_A8D3
  LDA #&07
  JSR AUDIO_CALL
  ABS_DEC Z_49
  BPL L5_A8F7
  LDA #&03
  ABS_STA Z_49
  RTS
.L5_A8E3
  LDA #&07
  JSR AUDIO_CALL
  ABS_INC Z_49
  ABS_LDA Z_49
  CMP #&04
  BCC L5_A8F7
  LDA #&00
  ABS_STA Z_49
.L5_A8F7
  RTS

; Draw MENU_CURSOR_SPR at MODE_CURSOR_X / MODE_CURSOR_Y[Z_49].
.DRAW_MODE_CURSOR
  ABS_LDX Z_49
  LDA MODE_CURSOR_X
  ABS_STA Z_56
  LDA MODE_CURSOR_Y,X
  ABS_STA Z_58
  LDA #&00
  ABS_STA Z_57
  ABS_STA Z_59
  ABS_STA Z_5A
  LDA #LO(MENU_CURSOR_SPR)
  STA Z_54
  LDA #HI(MENU_CURSOR_SPR)
  STA Z_55
  JMP DRAW_METASPRITE
.MODE_CURSOR_X
  EQUB &48

; Mode-menu cursor Y. 4 bytes, index Z_49: 58h, 68h, 78h, 88h. X is MODE_CURSOR_X.
.MODE_CURSOR_Y
  EQUB &58,&68,&78,&88

; Shared menu cursor metasprite. Count 07h. Also used by the game-over cursor.
.MENU_CURSOR_SPR
  EQUB &07,&05,&F8,&F3,&01,&06,&00,&F3,&01,&15,&F8,&FB,&03,&16,&00,&FB
  EQUB &03,&1F,&08,&FB,&03,&0E,&F8,&03,&03,&0F,&00,&03,&03

; If Z_49 is not 0, store 6 in W_04C9. Mode 0 leaves W_04C9 alone.
.MODE_TO_AREA
  ABS_LDA Z_49
  BEQ L5_A949
  LDA #&06
  STA W_04C9
.L5_A949
  RTS
  EQUB &AD
IF REGION_JP
  EQUB &3B
ELSE
  EQUB &49
ENDIF
  EQUB &00,&D0,&2C,&A2,&00,&AD,&B6,&04,&F0,&21,&E8,&C9,&02,&F0,&1C,&E8
  EQUB &C9,&04,&F0,&17,&E8,&C9,&01,&F0,&12,&E8,&C9,&40,&F0,&0D,&E8,&C9
  EQUB &80,&F0,&08,&A2,&FF,&C9,&08,&F0,&02,&A2,&00,&8E,&C9,&04,&60,&60

; Copy 8 palette rows from MODE_MENU_PAL and mirror the background color.
.LOAD_MODE_PAL
  LDA #LO(MODE_MENU_PAL)
  STA Z_16
  LDA #HI(MODE_MENU_PAL)
  STA Z_17
  LDA #&00
  LDX #&08
  JSR COPY_PAL_ROWS
  JMP MIRROR_BG_COLOR

; 8 palette rows (32 bytes) for the mode menu.
.MODE_MENU_PAL
  EQUB &0F,&10,&30,&21,&17,&16,&27,&38,&0F,&0F,&0F,&0F,&0F,&0F,&0F,&0F
  EQUB &0F,&20,&01,&06,&0F,&0D,&26,&20,&0F,&0F,&2A,&20,&0F,&0F,&21,&20

; Draw TOP and the five mode lines via DRAW_INLINE_STR.
; Records are column, row, count, tiles.
.DRAW_MODE_MENU
  JSR DRAW_TOP_SCORE
  LDA #LO(MODE_TEXT_0)
  STA Z_20
  LDA #HI(MODE_TEXT_0)
  STA Z_21
  JSR DRAW_INLINE_STR
  LDA #LO(MODE_TEXT_1)
  STA Z_20
  LDA #HI(MODE_TEXT_1)
  STA Z_21
  JSR DRAW_INLINE_STR
  LDA #LO(MODE_TEXT_2)
  STA Z_20
  LDA #HI(MODE_TEXT_2)
  STA Z_21
  JSR DRAW_INLINE_STR
  LDA #LO(MODE_TEXT_3)
  STA Z_20
  LDA #HI(MODE_TEXT_3)
  STA Z_21
  JSR DRAW_INLINE_STR
  LDA #LO(MODE_TEXT_4)
  STA Z_20
  LDA #HI(MODE_TEXT_4)
  STA Z_21
  JMP DRAW_INLINE_STR

; Draw TOP_SCORE_LABEL, then 8 digits from W_03C8 (high index first) at column 0Eh row 03h. ORs each byte with 30h.
.DRAW_TOP_SCORE
  LDA #LO(TOP_SCORE_LABEL)
  STA Z_20
  LDA #HI(TOP_SCORE_LABEL)
  STA Z_21
  JSR DRAW_INLINE_STR
  LDX #&0E
  LDY #&03
  JSR XY_TO_NT_ADDR
  LDA Z_23
  STA PPU_ADDRESS
  LDA Z_22
  STA PPU_ADDRESS
  LDX #&07
.L5_AA06
  LDA W_03C8,X
  ORA #&30
  STA PPU_DATA
  DEX
  BPL L5_AA06
  RTS

; DRAW_INLINE_STR record: column, row, count, then tiles. TOP is 3 tiles. The five MODE_TEXT lines are the same shape.
.TOP_SCORE_LABEL
  EQUB &0A,&03,&03,&54,&4F,&50
.MODE_TEXT_0
  EQUB &05,&06,&17,&50,&4C,&45,&41,&53,&45,&20,&53,&45,&4C,&45,&43,&54
  EQUB &20,&47,&41,&4D,&45,&20,&4D,&4F,&44,&45
.MODE_TEXT_1
  EQUB &0B,&0B,&0B,&4E,&4F,&52,&4D,&41,&4C,&20,&4D,&4F,&44,&45
.MODE_TEXT_2
  EQUB &0B,&0D,&0B,&20,&20,&56,&53,&20,&20,&20,&4D,&4F,&44,&45
.MODE_TEXT_3
  EQUB &0B,&0F,&0B,&42,&41,&54,&54,&4C,&45,&20,&4D,&4F,&44,&45
.MODE_TEXT_4
  EQUB &0B,&11,&0B,&20,&20,&43,&4F,&4E,&54,&49,&4E,&55,&45,&20

; Continue / game-over screen. RUN_GAME_OVER enters here.
; Draws a map, sets Z_4A to 1, plays sound 19h.
; Select/Up/Down toggle Z_4A. Start/A fades out.
.GAME_OVER_LOOP
  JSR PPU_OFF
  JSR NMI_OFF
  JSR SAVE_TOP_SCORE
  JSR CLEAR_ATTRS
  JSR LOAD_MENU_CHR
  JSR NMI_ON
  JSR LOAD_GAME_OVER_PAL
  JSR DRAW_GAME_OVER_MAP
  JSR CLEAR_SCROLL
  JSR MIX_STAGE_BYTES
  LDA #&01
  ABS_STA Z_4A
  JSR PPU_ON
  JSR MARK_PALETTE
  LDA #&19
  JSR AUDIO_CALL
.GAME_OVER_WAIT
  JSR WAIT_NMI
  JSR DRAW_OVER_CURSOR
  JSR MARK_OAM
  LDA JOY_NEW
  AND #&90
  BEQ GAME_OVER_WAIT
  JSR FADE_PALETTE
  JMP PPU_OFF

; Point Z_66/Z_64/Z_62 at the shared UI tiles and Z_20 at D4_ABD9, then JMP L7_CD89.
.DRAW_GAME_OVER_MAP
  LDA #LO(D4_9641)
IF REGION_JP
  STA Z_66
  LDA #HI(D4_9641)
  STA Z_67
  LDA #LO(D4_96C5)
  STA Z_64
  LDA #HI(D4_96C5)
  STA Z_65
  LDA #LO(D4_9241)
  STA Z_62
  LDA #HI(D4_9241)
ELSE
  STA Z_66
  LDA #HI(D4_9641)
  STA Z_67
  LDA #LO(D4_96C1)
  STA Z_64
  LDA #HI(D4_96C1)
  STA Z_65
  LDA #LO(D4_9241)
  STA Z_62
  LDA #HI(D4_9241)
ENDIF
  STA Z_63
  LDA #LO(D4_ABD9)
  STA Z_20
  LDA #HI(D4_ABD9)
  STA Z_21
  JMP L7_CD89

; Palette for the game-over screen: 4 rows from D4_B119 via bank 4, then 4 rows of GAME_OVER_PAL at row 4.
.LOAD_GAME_OVER_PAL
  LDA #LO(D4_B119)
  STA Z_16
  LDA #HI(D4_B119)
  STA Z_17
  LDA #&00
  LDX #&04
  FARCALL 4, COPY_PAL_ROWS
  LDA #LO(GAME_OVER_PAL)
  STA Z_16
  LDA #HI(GAME_OVER_PAL)
  STA Z_17
  LDA #&04
  LDX #&04
  JSR COPY_PAL_ROWS
  JMP MIRROR_BG_COLOR
.GAME_OVER_PAL
  EQUB &0F,&20,&01,&06,&0F,&0D,&26,&20,&0F,&0F,&2A,&20,&0F,&0F,&21,&20

; Read GAME_OVER_INPUT, then draw MENU_CURSOR_SPR at OVER_CURSOR_X / OVER_CURSOR_Y[Z_4A].
.DRAW_OVER_CURSOR
  JSR GAME_OVER_INPUT
  JMP L5_AB20

; If JOY_NEW has Up, Down or Select (2Ch), toggle Z_4A bit 0 and play sound 07h.
.GAME_OVER_INPUT
  LDA JOY_NEW
  AND #&2C
  BEQ L5_AB1F
  ABS_LDA Z_4A
  EOR #&01
  ABS_STA Z_4A
  LDA #&07
  JSR AUDIO_CALL
.L5_AB1F
  RTS
.L5_AB20
  ABS_LDX Z_4A
  LDA OVER_CURSOR_X
  ABS_STA Z_56
  LDA OVER_CURSOR_Y,X
  ABS_STA Z_58
  LDA #&00
  ABS_STA Z_57
  ABS_STA Z_59
  ABS_STA Z_5A
  LDA #LO(MENU_CURSOR_SPR)
  STA Z_54
  LDA #HI(MENU_CURSOR_SPR)
  STA Z_55
  JMP DRAW_METASPRITE
.OVER_CURSOR_X
  EQUB &50
.OVER_CURSOR_Y
  EQUB &80,&70,&07,&05,&F8,&F3,&01,&06,&00,&F3,&01,&15,&F8,&FB,&03,&16
  EQUB &00,&FB,&03,&1F,&08,&FB,&03,&0E,&F8,&03,&03,&0F,&00,&03,&03

; Write one inline string straight to the PPU. DRAW_INLINE_STR enters here.
; In: Z_20 -> column, row, count, bytes. Byte 20h is stored as 40h.
.PPU_WRITE_TEXT
  LDY #&00
  LDA (Z_20),Y
  TAX
  INY
  LDA (Z_20),Y
  TAY
  JSR XY_TO_NT_ADDR
  LDA Z_23
  STA PPU_ADDRESS
  LDA Z_22
  STA PPU_ADDRESS
  LDY #&02
  LDA (Z_20),Y
  TAX
.L5_AB80
  INY
  LDA (Z_20),Y
  CMP #&20
  BNE L5_AB89
  LDA #&40
.L5_AB89
  STA PPU_DATA
  DEX
  BNE L5_AB80
  RTS
.TITLE_BOMBER_SPR
  EQUB &16,&01,&F8,&F0,&00,&02,&00,&F0,&00,&03,&F0,&F8,&00,&04,&F8,&F8
  EQUB &00,&05,&00,&F8,&00,&06,&E8,&00,&00,&07,&F0,&00,&00,&08,&F8,&00
  EQUB &00,&09,&00,&00,&00,&0A,&E8,&08,&00,&0B,&F0,&08,&00,&0B,&F8,&08
  EQUB &00,&0C,&00,&08,&00,&0D,&E0,&10,&00,&0E,&E8,&10,&00,&0F,&F0,&10
  EQUB &00,&0B,&F8,&10,&00,&10,&00,&10,&00,&11,&E8,&18,&00,&12,&F0,&18
  EQUB &00,&13,&F8,&18,&00,&14,&00,&18,&00
.TITLE_ACTOR_0
  EQUB &08,&15,&F2,&E9,&01,&16,&FA,&E9,&01,&17,&F2,&F1,&01,&18,&FA,&F1
  EQUB &01,&19,&02,&F1,&01,&1A,&F2,&F9,&01,&1B,&FA,&F9,&01,&1C,&02,&F9
  EQUB &01
.TITLE_ACTOR_1
  EQUB &0A,&1D,&F0,&EE,&01,&1E,&F8,&EE,&01,&1F,&00,&ED,&01,&20,&F0,&F6
  EQUB &01,&21,&F8,&F6,&01,&22,&00,&F5,&01,&23,&08,&F4,&01,&24,&F0,&FE
  EQUB &01,&25,&F8,&FE,&01,&26,&00,&FD,&01
.TITLE_ACTOR_2
  EQUB &08,&27,&F4,&EB,&01,&28,&FC,&EB,&01,&29,&04,&EB,&01,&2A,&F4,&F3
  EQUB &01,&2B,&FC,&F3,&01,&2C,&04,&F3,&01,&2D,&F4,&FB,&01,&2E,&FC,&FB
  EQUB &01

; If W_03C0 is not DEFAULT_TOP_NAME, clear W_03C8, call RESET_MARKS and RESET_DEMO_IDX, then copy that 8-byte name into W_03C0.
.SEED_DEFAULT_SCORE
  LDX #&07
.L5_AC56
  LDA DEFAULT_TOP_NAME,X
  CMP W_03C0,X
  BNE L5_AC62
  DEX
  BPL L5_AC56
  RTS
.L5_AC62
  JSR CLEAR_TOP_SCORE
  JSR RESET_MARKS
  JSR RESET_DEMO_IDX
  LDX #&07
.L5_AC6D
  LDA DEFAULT_TOP_NAME,X
  STA W_03C0,X
  DEX
  BPL L5_AC6D
  RTS

; 8 tiles compared with W_03C0. Bytes are K O S A K A ! !.
.DEFAULT_TOP_NAME
  EQUB &4B,&4F,&53,&41,&4B,&41,&21,&21

; Zero the 8 score digits at W_03C8.
.CLEAR_TOP_SCORE
  LDA #&00
  LDX #&07
.L5_AC83
  STA W_03C8,X
  DEX
  BPL L5_AC83
  RTS

; Zero the 8 working score digits at W_03D0.
.CLEAR_STAGE_SCORE
  LDA #&00
  LDX #&07
.L5_AC8E
  STA W_03D0,X
  DEX
  BPL L5_AC8E
.L5_AC94
  RTS

; If Z_49 is 0, draw W_03D0 as 8 digits (OR 30h) at column 4 row 2.
; Skipped for the other modes. Called from STAGE_LOOP.
.DRAW_HUD_SCORE
  ABS_LDY Z_49
  BNE L5_AC94
  LDX #&07
  LDY #&00
.L5_AC9E
  LDA W_03D0,X
  ORA #&30
  STA W_052A,Y
  INY
  DEX
  BPL L5_AC9E
  LDX #&04
  LDY #&02
  JSR XY_TO_NT_ADDR
IF REGION_JP
  LDA #&28
ELSE
  LDA #&2A
ENDIF
  STA Z_20
  LDA #&05
  STA Z_21
  LDA #&00
  STA Z_2E
  LDX #&08
  JMP QUEUE_PPU_RUN

; If Z_49 is 0 and W_03D0 is greater than W_03C8 (high byte first), copy the 8 digits into W_03C8.
.SAVE_TOP_SCORE
  ABS_LDA Z_49
  BNE L5_ACD6
  LDX #&07
.L5_ACC9
  LDA W_03D0,X
  CMP W_03C8,X
  BCC L5_ACD6
  BNE L5_ACD7
  DEX
  BPL L5_ACC9
.L5_ACD6
  RTS
.L5_ACD7
  LDX #&07
.L5_ACD9
  LDA W_03D0,X
  STA W_03C8,X
  DEX
  BPL L5_ACD9
  RTS
.L5_ACE3
  RTS

; Area intro card. MAYBE_AREA_CARD enters here.
; Returns at once unless W_03EF, Z_49 and Z_4C are 0 and Z_4B differs from Z_4D.
; Stores the area in Z_4D, shows the card, plays sound 11h, waits on Start or a timer in Z_2A/Z_2B.
.SHOW_AREA_INTRO
  LDA W_03EF
  BNE L5_ACE3
  ABS_LDA Z_49
  ABS_ORA Z_4C
  BNE L5_ACE3
  ABS_LDA Z_4B
  ABS_CMP Z_4D
  BEQ L5_ACE3
  ABS_STA Z_4D
  JSR NMI_OFF
  JSR LOAD_AREA_INTRO
  JSR NMI_ON
  JSR DRAW_AREA_INTRO
  JSR RESET_INTRO_ANIM
  JSR CLEAR_SCROLL
  JSR PPU_ON
  JSR MARK_PALETTE
  LDA #&11
  JSR AUDIO_CALL
  LDA #&E0
  STA Z_2A
  LDA #&01
  STA Z_2B
.AREA_INTRO_WAIT
  JSR WAIT_NMI
  JSR DRAW_INTRO_SPRITE
  JSR MARK_OAM
  LDA JOY_NEW
  AND #&10
  BNE L5_AD41
  DEC Z_2A
  LDA Z_2A
  CMP #&FF
  BNE L5_AD3B
  DEC Z_2B
.L5_AD3B
  LDA Z_2A
  ORA Z_2B
  BNE AREA_INTRO_WAIT
.L5_AD41
  JSR FADE_PALETTE
  JMP PPU_OFF

; Draw the area-intro map for Z_4B.
; Six word pointers each: map, attr, layout, tiles, all in bank 4. JMP L7_CD89.
.DRAW_AREA_INTRO
  ABS_LDA Z_4B
  ASL A
  TAX
  LDA AREA_INTRO_MAP,X
  STA Z_20
  LDA D5_AD78,X
  STA Z_21
  LDA AREA_INTRO_ATTR,X
  STA Z_66
  LDA D5_AD9C,X
  STA Z_67
  LDA AREA_INTRO_LAY,X
  STA Z_64
  LDA D5_AD90,X
  STA Z_65
  LDA AREA_INTRO_TILE,X
  STA Z_62
  LDA D5_AD84,X
  STA Z_63
  JMP L7_CD89

; 6 words, one per area. Bank-4 map pointer passed to L7_CD89 as Z_20. AREA_INTRO_TILE, AREA_INTRO_LAY and AREA_INTRO_ATTR are the matching Z_62, Z_64 and Z_66 tables.
.AREA_INTRO_MAP
  EQUB LO(D4_A473)
.D5_AD78
  EQUB HI(D4_A473)
  EQUW D4_A53B
  EQUW D4_A5CD
  EQUW D4_A69A
  EQUW D4_A77A
  EQUW D4_A7F5
.AREA_INTRO_TILE
  EQUB LO(D4_8BF4)
.D5_AD84
  EQUB HI(D4_8BF4)
  EQUW D4_8CF1
  EQUW D4_8D86
  EQUW D4_8EA4
  EQUW D4_90A4
  EQUW D4_9123
.AREA_INTRO_LAY
  EQUB LO(D4_8CC3)
.D5_AD90
  EQUB HI(D4_8CC3)
  EQUW D4_8D6B
  EQUW D4_8E70
  EQUW D4_9047
  EQUW D4_910C
  EQUW D4_920D
.AREA_INTRO_ATTR
  EQUB LO(D4_8CAC)
.D5_AD9C
  EQUB HI(D4_8CAC)
  EQUW D4_8D5D
  EQUW D4_8E56
  EQUW D4_9018
  EQUW D4_9100
  EQUW D4_91F3

; Load the area-intro CHR and palettes for Z_4B.
; Sprite CHR from AREA_INTRO_CHR, INTRO_BG_CHR, 4 palette rows from AREA_INTRO_PAL, then 4 rows from D4_B0E9.
.LOAD_AREA_INTRO
  ABS_LDA Z_4B
  ASL A
  TAX
  LDA AREA_INTRO_CHR,X
  STA Z_20
  LDA D5_AE0B,X
  STA Z_21
  LDA #&00
  STA Z_22
  LDA #&10
  STA Z_23
  LDX #&01
  LDY #&FF
  JSR UPLOAD_CHR_RLE
  LDA #LO(INTRO_BG_CHR)
  STA Z_20
  LDA #HI(INTRO_BG_CHR)
  STA Z_21
  LDA #&00
  STA Z_22
  LDA #&00
  STA Z_23
  LDX #&01
  LDY #&FF
  JSR UPLOAD_CHR_RLE
  ABS_LDA Z_4B
  ASL A
  TAX
  LDA AREA_INTRO_PAL,X
  STA Z_16
  LDA D5_AE17,X
  STA Z_17
  LDA #&00
  LDX #&04
  FARCALL 4, COPY_PAL_ROWS
  LDA #LO(D4_B0E9)
  STA Z_16
  LDA #HI(D4_B0E9)
  STA Z_17
  LDA #&04
  LDX #&04
  FARCALL 4, COPY_PAL_ROWS
  JMP MIRROR_BG_COLOR

; 6 words. RLE sprite CHR for the area intro, selected by Z_4B.
.AREA_INTRO_CHR
  EQUB LO(AREA0_INTRO_SPR)
.D5_AE0B
  EQUB HI(AREA0_INTRO_SPR)
  EQUW AREA1_INTRO_SPR
  EQUW AREA2_INTRO_SPR
  EQUW AREA3_INTRO_SPR
  EQUW AREA4_INTRO_SPR
  EQUW AREA5_INTRO_SPR

; 6 words. Bank-4 palette, 4 rows, selected by Z_4B.
.AREA_INTRO_PAL
  EQUB LO(D4_B089)
.D5_AE17
  EQUB HI(D4_B089)
  EQUW D4_B099
  EQUW D4_B0A9
  EQUW D4_B0B9
  EQUW D4_B0C9
  EQUW D4_B0D9

; Clear intro animation bytes W_0532..W_0535.
.RESET_INTRO_ANIM
  LDA #&00
  STA W_0532
  STA W_0534
  STA W_0533
  STA W_0535
  RTS

; Draw the area-intro metasprite.
; INTRO_DRAW_PTR[Z_4B]: areas 0..4 share one draw; area 5 steps W_0532 through AREA5_FRAME_DLY first.
.DRAW_INTRO_SPRITE
  ABS_LDA Z_4B
  ASL A
  TAX
  LDA INTRO_DRAW_PTR,X
  STA Z_20
  LDA D5_AE44,X
  STA Z_21
  JMP (Z_20)

; 6 words. Code pointers. Areas 0..4 point at the shared draw; area 5 points at INTRO_AREA5_FRAME.
.INTRO_DRAW_PTR
  EQUB LO(L5_AE4F)
.D5_AE44
  EQUB HI(L5_AE4F)
  EQUW L5_AE4F
  EQUW L5_AE4F
  EQUW L5_AE4F
  EQUW L5_AE4F
  EQUW INTRO_AREA5_FRAME
.L5_AE4F
  JMP DRAW_INTRO_META
.INTRO_AREA5_FRAME
  LDY W_0532
  CPY #&06
  BCS L5_AE6C
  INC W_0534
  LDA W_0534
  CMP AREA5_FRAME_DLY,Y
  BCC L5_AE6C
  LDA #&00
  STA W_0534
  INC W_0532
.L5_AE6C
  JMP DRAW_INTRO_META

; 7 frame delays for the area-5 intro. W_0534 counts up to the byte indexed by W_0532, which stops at 6.
.AREA5_FRAME_DLY
  EQUB &07,&07,&20,&10,&08,&08,&00
.DRAW_INTRO_META
  ABS_LDA Z_4B
  ASL A
  TAY
  LDA INTRO_SPR_XY,Y
  ABS_STA Z_56
  LDA D5_AEAB,Y
  ABS_STA Z_58
  LDA INTRO_FRAME_PTR,Y
  STA Z_20
  LDA D5_AEB7,Y
  STA Z_21
  LDA #&00
  ABS_STA Z_57
  ABS_STA Z_5A
  LDA W_0532
  ASL A
  TAY
  LDA (Z_20),Y
  STA Z_54
  INY
  LDA (Z_20),Y
  STA Z_55
  JMP DRAW_METASPRITE

; 6 areas, interleaved X then Y for the intro sprite. Not a pointer. INTRO_FRAME_PTR is the matching 6 words of animation lists.
.INTRO_SPR_XY
  EQUB &90
.D5_AEAB
  EQUB &90,&90,&BC,&90,&BC,&90,&A4,&90,&B0,&88,&B8
.INTRO_FRAME_PTR
  EQUB LO(D5_AEC2)
.D5_AEB7
  EQUB HI(D5_AEC2)
IF REGION_JP
  EQUW JD5_AE60
  EQUW JD5_AE60
  EQUW JD5_AE60
  EQUW JD5_AE60
  EQUW JD5_AE62
ELSE
  EQUW D5_AEC4
  EQUW D5_AEC4
  EQUW D5_AEC4
  EQUW D5_AEC4
  EQUW D5_AEC6
ENDIF
.D5_AEC2
  EQUW INTRO_META_0
IF REGION_JP
.JD5_AE60
  EQUB &A1,&AE
.JD5_AE62
  EQUB &E2,&AE,&F3,&AE,&14,&AF
.D5_AEC6
  EQUW INTRO_META_3
  EQUB &76
ELSE
.D5_AEC4
  EQUW INTRO_META_1
.D5_AEC6
  EQUW INTRO_META_2
  EQUB &57
ENDIF
  EQUB &AF
IF REGION_JP
  EQUB &A7
ELSE
  EQUB &78
ENDIF
  EQUB &AF
IF REGION_JP
  EQUB &E8
ELSE
  EQUB &A9
ENDIF
  EQUB &AF
IF REGION_JP
ELSE
  EQUB &DA,&AF,&0B,&B0,&4C,&B0
ENDIF

; Intro metasprite. First byte is the DRAW_METASPRITE count. INTRO_META_1..3 are the later frames.
.INTRO_META_0
  EQUB &0C,&08,&E0,&E0,&02,&09,&E8,&E0,&00,&09,&F0,&E0,&40,&08,&F8,&E0
  EQUB &42,&0A,&E0,&E8,&02,&0B,&E8,&E8,&00,&0B,&F0,&E8,&40,&0A,&F8,&E8
  EQUB &42,&0C,&E0,&F0,&02,&0D,&E8,&F0,&01,&0D,&F0,&F0,&41,&0C,&F8,&F0
  EQUB &42
.INTRO_META_1
  EQUB &10,&00,&E0,&E0,&00,&01,&E8,&E0,&00,&01,&F0,&E0,&40,&00,&F8,&E0
  EQUB &40,&02,&E0,&E8,&00,&03,&E8,&E8,&00,&03,&F0,&E8,&40,&02,&F8,&E8
  EQUB &40,&04,&E0,&F0,&01,&05,&E8,&F0,&01,&05,&F0,&F0,&41,&04,&F8,&F0
  EQUB &41,&06,&E0,&F8,&01,&07,&E8,&F8,&01,&07,&F0,&F8,&41,&06,&F8,&F8
  EQUB &41
.INTRO_META_2
  EQUB &04,&0E,&E7,&F0,&00,&0F,&EF,&F0,&00,&0F,&F7,&F0,&40,&0E,&FF,&F0
  EQUB &40,&08,&00,&E7,&E8,&00,&01,&EF,&E8,&00,&01,&F7,&E8,&40,&00,&FF
  EQUB &E8,&40,&10,&E7,&F0,&00,&11,&EF,&F0,&00,&11,&F7,&F0,&40,&10,&FF
  EQUB &F0,&40,&0C,&00,&E7,&E0,&00,&01,&EF,&E0,&00,&01,&F7,&E0,&40,&00
  EQUB &FF,&E0,&40,&02,&E7,&E8,&00,&03,&EF,&E8,&00,&03,&F7,&E8,&40,&02
  EQUB &FF,&E8,&40,&12,&E7,&F0,&01,&13,&EF,&F0,&01,&13,&F7,&F0,&41,&12
  EQUB &FF,&F0,&41
.INTRO_META_3
  EQUB &0C,&14,&E7,&E0,&00,&15,&EF,&E0,&00,&15,&F7,&E0,&40,&14,&FF,&E0
  EQUB &40,&16,&E7,&E8,&01,&17,&EF,&E8,&00,&17,&F7,&E8,&40,&16,&FF,&E8
  EQUB &41,&18,&E7,&F0,&01,&19,&EF,&F0,&01,&19,&F7,&F0,&41,&18,&FF,&F0
  EQUB &41,&0C,&1A,&E3,&E1,&00,&1B,&EB,&E1,&00,&1C,&F3,&E1,&00,&1D,&FB
  EQUB &E1,&00,&1E,&E3,&E9,&01,&1F,&EB,&E9,&01,&20,&F3,&E9,&00,&21,&FB
  EQUB &E9,&00,&38,&E3,&F1,&00,&39,&EB,&F1,&01,&3A,&F3,&F1,&01,&3B,&FB
  EQUB &F1,&01,&10,&28,&E3,&E2,&00,&29,&EB,&E2,&00,&2A,&F3,&E2,&00,&2B
  EQUB &FB,&E2,&01,&2C,&E3,&EA,&00,&2D,&EB,&EA,&00,&2E,&F3,&EA,&00,&2F
  EQUB &FB,&EA,&00,&30,&E3,&F2,&01,&31,&EB,&F2,&00,&32,&F3,&F2,&01,&33
  EQUB &FB,&F2,&01,&34,&E3,&FA,&00,&35,&EB,&FA,&00,&36,&F3,&FA,&01,&37
  EQUB &FB,&FA,&01,&0C,&22,&E7,&EA,&00,&23,&EF,&EA,&00,&23,&F7,&EA,&40
  EQUB &22,&FF,&EA,&40,&24,&E7,&F2,&00,&25,&EF,&F2,&00,&25,&F7,&F2,&40
  EQUB &24,&FF,&F2,&40,&26,&E7,&FA,&01,&27,&EF,&FA,&00,&27,&F7,&FA,&40
  EQUB &26,&FF,&FA,&41

; Ending. RUN_ENDING enters here when the area reaches 6.
; Forces Z_4B=6, Z_4C=0, loads ending CHR and enemies, then waits until X_62F2 is 2.
; SCROLL_ENDING runs while X_62F2 is 1. Then fade and JMP L7_D1B0.
.ENDING_LOOP
  JSR PPU_OFF
  JSR NMI_OFF
  JSR SAVE_TOP_SCORE
  LDA #&00
  JSR FILL_NAMETABLE
  JSR CLEAR_ATTRS
  LDA #&00
  ABS_STA Z_4E
  ABS_STA Z_B4
  JSR RESET_ENEMY_RAM
  JSR LOAD_ENDING_CHR
  JSR NMI_ON
  JSR DRAW_ENDING_MAP
  LDA #&06
  ABS_STA Z_4B
  LDA #&00
  ABS_STA Z_4C
  JSR LOAD_ENEMIES
  JSR CLEAR_SCROLL
  LDA #&00
  STA X_62F2
  JSR PPU_ON
  JSR MARK_PALETTE
  LDA #&17
  JSR AUDIO_CALL
.ENDING_WAIT
  JSR WAIT_NMI
  JSR SCROLL_ENDING
  JSR UPDATE_ENEMIES
  JSR MARK_OAM
  LDA X_62F2
  CMP #&02
  BNE ENDING_WAIT
  JSR FADE_PALETTE
  JSR PPU_OFF
  JMP L7_D1B0

; Ending/opening CHR and palettes.
; ENDING_SPR_CHR at $1000, PLAY_BG_CHR (A0h bytes), ENDING_EXTRA_BG_CHR at $0A30, palettes D4_B159 and D4_B149.
.LOAD_ENDING_CHR
  LDA #LO(ENDING_SPR_CHR)
  STA Z_20
  LDA #HI(ENDING_SPR_CHR)
  STA Z_21
  LDA #&00
  STA Z_22
  LDA #&10
  STA Z_23
  LDX #&01
  LDY #&FF
  JSR UPLOAD_CHR_RLE
  LDA #LO(PLAY_BG_CHR)
  STA Z_20
  LDA #HI(PLAY_BG_CHR)
  STA Z_21
  LDA #&00
  STA Z_22
  LDA #&00
  STA Z_23
  LDX #&01
  LDY #&A0
  JSR UPLOAD_CHR_RLE
  LDA #LO(ENDING_EXTRA_BG_CHR)
  STA Z_20
  LDA #HI(ENDING_EXTRA_BG_CHR)
  STA Z_21
  LDA #&30
  STA Z_22
  LDA #&0A
  STA Z_23
  LDX #&01
  LDY #&50
  JSR UPLOAD_CHR_RLE
  LDA #LO(D4_B159)
  STA Z_16
  LDA #HI(D4_B159)
  STA Z_17
  LDA #&04
  LDX #&04
  FARCALL 4, COPY_PAL_ROWS
  LDA #LO(D4_B149)
  STA Z_16
  LDA #HI(D4_B149)
  STA Z_17
  LDA #&00
  LDX #&04
  FARCALL 4, COPY_PAL_ROWS
  JMP MIRROR_BG_COLOR

; Draw the ending nametable. Four bank-4 pointers (tiles, layout, attr, map) then JMP L7_CD89.
; US bytes are D4_9AD4, D4_9B1A, D4_98A8 and D4_AE17.
.DRAW_ENDING_MAP
  LDA #LO(D4_9AD4)
  STA Z_66
  LDA #HI(D4_9AD4)
  STA Z_67
  LDA #LO(D4_9B1A)
  STA Z_64
  LDA #HI(D4_9B1A)
  STA Z_65
  LDA #LO(D4_98A8)
  STA Z_62
  LDA #HI(D4_98A8)
  STA Z_63
  LDA #LO(D4_AE17)
  STA Z_20
  LDA #HI(D4_AE17)
  STA Z_21
  JMP L7_CD89

; If X_62F2 is 1, add 1 to SCROLL_X (with SCROLL_NT).
.SCROLL_ENDING
  LDA X_62F2
  CMP #&01
  BNE L5_B185
  LDA SCROLL_X
  CLC
  ADC #&01
  STA SCROLL_X
  LDA SCROLL_NT
  ADC #&00
  STA SCROLL_NT
.L5_B185
  RTS

; Opening scene. RUN_OPENING enters here.
; Zeros Z_49, Z_4E, Z_B4. Sets area 6 stage 1, loads enemies, waits until X_62F2 is 2 or Start/A.
.OPENING_LOOP
  LDA #&00
  ABS_STA Z_49
  ABS_STA Z_4E
  ABS_STA Z_B4
  JSR PPU_OFF
  JSR NMI_OFF
  LDA #&00
  JSR FILL_NAMETABLE
  JSR CLEAR_ATTRS
  JSR RESET_ENEMY_RAM
  JSR LOAD_ENDING_CHR
  JSR NMI_ON
  JSR DRAW_OPENING_MAP
  LDA #&06
  ABS_STA Z_4B
  LDA #&01
  ABS_STA Z_4C
  JSR LOAD_ENEMIES
  JSR CLEAR_SCROLL
  LDA #&00
  STA X_62F2
  STA X_62DC
  JSR PPU_ON
  JSR MARK_PALETTE
.OPENING_WAIT
  JSR WAIT_NMI
  JSR UPDATE_ENEMIES
  JSR MARK_OAM
  LDA X_62F2
  CMP #&02
  BEQ L5_B1E0
  LDA JOY_NEW
  AND #&90
  BEQ OPENING_WAIT
.L5_B1E0
  JSR FADE_PALETTE
  JMP PPU_OFF

; Draw the opening nametable from D4_9AD4, D4_9B1A, D4_98A8 and D4_AE17 via L7_CD89.
.DRAW_OPENING_MAP
  LDA #LO(D4_9AD4)
  STA Z_66
  LDA #HI(D4_9AD4)
  STA Z_67
  LDA #LO(D4_9B1A)
  STA Z_64
  LDA #HI(D4_9B1A)
  STA Z_65
  LDA #LO(D4_98A8)
  STA Z_62
  LDA #HI(D4_98A8)
  STA Z_63
  LDA #LO(D4_AE17)
  STA Z_20
  LDA #HI(D4_AE17)
  STA Z_21
  JMP L7_CD89

; Versus round result. SHOW_VS_RESULT enters here.
; Sets Z_4A to 1, plays sound 1Ch. Up/Down/Select toggle Z_4A. Start/A exits.
.VS_RESULT_LOOP
  JSR NMI_OFF
  JSR LOAD_MODE_GFX
  JSR NMI_ON
  LDA #&00
  STA W_0561
  STA W_0562
  LDA #&01
  ABS_STA Z_4A
  JSR DRAW_VS_RESULT_MAP
  JSR DRAW_VS_RESULT_MARK
  JSR CLEAR_SCROLL
  JSR PPU_ON
  JSR MARK_PALETTE
  LDA #&1C
  JSR AUDIO_CALL
.VS_RESULT_WAIT
  JSR WAIT_NMI
  JSR DRAW_VS_RESULT_SPR
  JSR VS_RESULT_INPUT
  JSR MARK_OAM
  LDA JOY_NEW
  AND #&90
  BEQ VS_RESULT_WAIT
  JSR FADE_PALETTE
  JMP PPU_OFF
IF REGION_JP

.DRAW_VS_RESULT_MAP
  LDA #LO(D4_9641)
  STA Z_66
  LDA #HI(D4_9641)
  STA Z_67
  LDA #LO(D4_96C5)
  STA Z_64
  LDA #HI(D4_96C5)
  STA Z_65
  LDA #LO(D4_9241)
  STA Z_62
  LDA #HI(D4_9241)
ELSE

; Draw the versus-result nametable. UI tile pointers plus map D4_AA05, then JMP L7_CD89.
.DRAW_VS_RESULT_MAP
  LDA #LO(D4_9241)
  STA Z_66
  LDA #&96
  STA Z_67
  LDA #&C1
  STA Z_64
  LDA #&96
  STA Z_65
  LDA #&41
  STA Z_62
  LDA #HI(D4_9241)
ENDIF
  STA Z_63
  LDA #LO(D4_AA05)
  STA Z_20
  LDA #HI(D4_AA05)
  STA Z_21
  JMP L7_CD89

; Stamp two tiles from D5_B29B/D5_B29E at (0Bh,4) and (0Bh,5) using W_04C8.
; If that index is 1, also draw a 2x2 mark via DRAW_MARK_2X2.
.DRAW_VS_RESULT_MARK
  LDX W_04C8
  LDA D5_B29B,X
  LDX #&0B
  LDY #&04
  JSR QUEUE_MAP_TILE
  LDX W_04C8
  LDA D5_B29E,X
  LDX #&0B
  LDY #&05
  JSR QUEUE_MAP_TILE
  LDA W_04C8
  ASL A
  ASL A
  STA Z_2A
  LDA #&07
  STA Z_28
  LDA #&06
  STA Z_29
  JMP DRAW_MARK_2X2
.D5_B29B
  EQUB &0A,&0B,&0C
.D5_B29E
  EQUB &0D,&0E,&0F

; Animate the versus-result sprite.
; W_0562 flips every 8 frames. Frame and W_04C8 pick a word in VS_RESULT_SPR_PTR. Drawn at (88h, 90h).
.DRAW_VS_RESULT_SPR
  INC W_0561
  LDA W_0561
  AND #&07
  STA W_0561
  BNE L5_B2B6
  LDA W_0562
  EOR #&01
  STA W_0562
.L5_B2B6
  LDA W_04C8
  ASL A
  ORA W_0562
  ASL A
  TAX
  LDA VS_RESULT_SPR_PTR,X
  STA Z_54
  LDA D5_B2DF,X
  STA Z_55
  LDA #&88
  ABS_STA Z_56
  LDA #&90
  ABS_STA Z_58
  LDA #&00
  ABS_STA Z_57
  ABS_STA Z_5A
  JMP DRAW_METASPRITE
IF REGION_JP
.VS_RESULT_SPR_PTR
  EQUB &86
ELSE

; 6 words. Versus-result metasprites. Index is (W_04C8*2 + W_0562)*2.
; US bytes still raw for the entries merge cannot take as pointers. See the notes.
.VS_RESULT_SPR_PTR
  EQUB &EA
ENDIF
.D5_B2DF
  EQUB &B2
IF REGION_JP
  EQUB &DF,&B2,&20
ELSE
  EQUB &43
ENDIF
  EQUB &B3
IF REGION_JP
  EQUB &79
ELSE
  EQUB &84
ENDIF
  EQUB &B3
IF REGION_JP
  EQUW VS_RESULT_SPR_4
  EQUW VS_RESULT_SPR_5
ELSE
  EQUW VS_RESULT_SPR_3
  EQUB &1E,&B4,&77,&B4
ENDIF
  EQUB &16,&24,&E0,&E0,&00,&25,&E8,&E0,&00,&25,&00,&E0,&40,&24,&08,&E0
  EQUB &40,&10,&E0,&E8,&00,&11,&E8,&E8,&00,&12,&F0,&E8,&00,&12,&F8,&E8
  EQUB &40,&11,&00,&E8,&40,&10,&08,&E8,&40,&13,&E8,&F0,&00,&14,&F0,&F0
  EQUB &00,&14,&F8,&F0,&40,&13,&00,&F0,&40,&15,&E8,&F8,&00,&05,&F0,&F8
  EQUB &00,&05,&F8,&F8,&40,&15,&00,&F8,&40,&06,&E8,&00,&00,&07,&F0,&00
  EQUB &00,&07,&F8,&00,&40,&06,&00,&00,&40,&10,&00,&E8,&E8,&00,&01,&F0
  EQUB &E8,&00,&01,&F8,&E8,&40,&00,&00,&E8,&40,&02,&E8,&F0,&00,&03,&F0
  EQUB &F0,&00,&03,&F8,&F0,&40,&02,&00,&F0,&40,&04,&E8,&F8,&00,&05,&F0
  EQUB &F8,&00,&05,&F8,&F8,&40,&04,&00,&F8,&40,&06,&E8,&00,&00,&07,&F0
  EQUB &00,&00,&07,&F8,&00,&40,&06,&00,&00,&40,&16,&24,&E0,&E0,&01,&25
  EQUB &E8,&E0,&01,&25,&00,&E0,&41,&24,&08,&E0,&41,&28,&E0,&E8,&01,&29
  EQUB &E8,&E8,&01,&12,&F0,&E8,&01,&12,&F8,&E8,&41,&29,&00,&E8,&41,&28
  EQUB &08,&E8,&41,&16,&E8,&F0,&01,&17,&F0,&F0,&01,&17,&F8,&F0,&41,&16
  EQUB &00,&F0,&41,&18,&E8,&F8,&01,&0D,&F0,&F8,&01,&0D,&F8,&F8,&41,&18
  EQUB &00,&F8,&41,&26,&E8,&00,&01,&27,&F0,&00,&01,&27,&F8,&00,&41,&26
  EQUB &00,&00,&41
.VS_RESULT_SPR_3
  EQUB &10,&08,&E8,&E8,&01,&09,&F0,&E8,&01,&09,&F8,&E8,&41,&08,&00,&E8
  EQUB &41,&0A,&E8,&F0,&01,&0B,&F0,&F0,&01,&0B,&F8,&F0,&41,&0A,&00,&F0
  EQUB &41,&0C,&E8,&F8,&01,&0D,&F0,&F8,&01,&0D,&F8,&F8,&41,&0C,&00,&F8
  EQUB &41,&26,&E8,&00,&01,&27,&F0,&00,&01,&27,&F8,&00,&41,&26,&00,&00
  EQUB &41
.VS_RESULT_SPR_4
  EQUB &16,&24,&E0,&E0,&02,&25,&E8,&E0,&02,&25,&00,&E0,&42,&24,&08,&E0
  EQUB &42,&28,&E0,&E8,&02,&29,&E8,&E8,&02,&12,&F0,&E8,&02,&12,&F8,&E8
  EQUB &42,&29,&00,&E8,&42,&28,&08,&E8,&42,&16,&E8,&F0,&02,&17,&F0,&F0
  EQUB &02,&17,&F8,&F0,&42,&16,&00,&F0,&42,&18,&E8,&F8,&02,&0D,&F0,&F8
  EQUB &02,&0D,&F8,&F8,&42,&18,&00,&F8,&42,&26,&E8,&00,&02,&27,&F0,&00
  EQUB &02,&27,&F8,&00,&42,&26,&00,&00,&42
.VS_RESULT_SPR_5
  EQUB &10,&08,&E8,&E8,&02,&09,&F0,&E8,&02,&09,&F8,&E8,&42,&08,&00,&E8
  EQUB &42,&0A,&E8,&F0,&02,&0B,&F0,&F0,&02,&0B,&F8,&F0,&42,&0A,&00,&F0
  EQUB &42,&0C,&E8,&F8,&02,&0D,&F0,&F8,&02,&0D,&F8,&F8,&42,&0C,&00,&F8
  EQUB &42,&26,&E8,&00,&02,&27,&F0,&00,&02,&27,&F8,&00,&42,&26,&00,&00
  EQUB &42

; Toggle Z_4A on Up/Down/Select and draw the one-tile cursor at X D5_B4F1, Y VS_CURSOR_Y[Z_4A].
.VS_RESULT_INPUT
  LDA JOY_NEW
  AND #&2C
  BEQ L5_B4CC
  ABS_LDA Z_4A
  EOR #&01
  ABS_STA Z_4A
  LDA #&07
  JSR AUDIO_CALL
.L5_B4CC
  ABS_LDX Z_4A
  LDA D5_B4F1
  ABS_STA Z_56
  LDA VS_CURSOR_Y,X
  ABS_STA Z_58
  LDA #&00
  ABS_STA Z_57
  ABS_STA Z_59
  ABS_STA Z_5A
  LDA #LO(D5_B4F4)
  STA Z_54
  LDA #HI(D5_B4F4)
  STA Z_55
  JMP DRAW_METASPRITE
.D5_B4F1
  EQUB &54
.VS_CURSOR_Y
  EQUB &B0,&A0
.D5_B4F4
  EQUB &01,&2A,&00,&00,&00

; Win-count screen. SET_WIN_COUNT enters here.
; If Z_49 is not 2, store 5 in W_0563 and return.
; If Z_49 is 2, show a menu: W_0563 wraps 1..5. Start/A fades out.
.BATTLE_WIN_MENU
  ABS_LDA Z_49
  CMP #&02
  BEQ L5_B506
  LDA #&05
  STA W_0563
  RTS
.L5_B506
  JSR NMI_OFF
  JSR LOAD_MENU_CHR
  JSR LOAD_GAME_OVER_PAL
  JSR NMI_ON
  JSR DRAW_WIN_MENU_MAP
  JSR CLEAR_SCROLL
  JSR PPU_ON
  JSR MARK_PALETTE
.WIN_MENU_WAIT
  JSR WAIT_NMI
  JSR WIN_COUNT_INPUT
  JSR DRAW_WIN_CURSOR
  JSR MARK_OAM
  LDA JOY_NEW
  AND #&90
  BEQ WIN_MENU_WAIT
  JSR FADE_PALETTE
  JMP PPU_OFF

; Win-count menu. Up wraps W_0563 down to 1; Down or Select wraps it up to 5. Sound 07h.
.WIN_COUNT_INPUT
  LDA JOY_NEW
  AND #&08
  BNE L5_B54D
  LDA JOY_NEW
  AND #&04
  BNE L5_B55D
  LDA JOY_NEW
  AND #&20
  BNE L5_B55D
  RTS
.L5_B54D
  LDA #&07
  JSR AUDIO_CALL
  DEC W_0563
  BNE L5_B55C
  LDA #&05
  STA W_0563
.L5_B55C
  RTS
.L5_B55D
  LDA #&07
  JSR AUDIO_CALL
  INC W_0563
  LDA W_0563
  CMP #&06
  BCC L5_B571
  LDA #&01
  STA W_0563
.L5_B571
  RTS
IF REGION_JP

.DRAW_WIN_MENU_MAP
  LDA #LO(D4_9641)
  STA Z_66
  LDA #HI(D4_9641)
  STA Z_67
  LDA #LO(D4_96C5)
  STA Z_64
  LDA #HI(D4_96C5)
  STA Z_65
  LDA #LO(D4_9241)
  STA Z_62
  LDA #HI(D4_9241)
ELSE

; Draw the win-count nametable from D4_AD4D plus the shared UI tile pointers. JMP L7_CD89.
.DRAW_WIN_MENU_MAP
  LDA #LO(D4_9241)
  STA Z_66
  LDA #&96
  STA Z_67
  LDA #&C1
  STA Z_64
  LDA #&96
  STA Z_65
  LDA #&41
  STA Z_62
  LDA #HI(D4_9241)
ENDIF
  STA Z_63
  LDA #LO(D4_AD4D)
  STA Z_20
  LDA #HI(D4_AD4D)
  STA Z_21
  JMP L7_CD89

; Draw MENU_CURSOR_SPR-shaped data at X = WIN_CURSOR_Y[0] and Y = WIN_CURSOR_Y[W_0563].
.DRAW_WIN_CURSOR
  LDX W_0563
  LDA WIN_CURSOR_Y
  ABS_STA Z_56
  LDA WIN_CURSOR_Y,X
  ABS_STA Z_58
  LDA #&00
  ABS_STA Z_59
  ABS_STA Z_5A
  LDA #LO(D5_B5BD)
  STA Z_54
  LDA #HI(D5_B5BD)
  STA Z_55
  JMP DRAW_METASPRITE

; Win-count cursor. Byte 0 is X (48h). Bytes 1..5 are Y for W_0563 = 1..5.
.WIN_CURSOR_Y
  EQUB &48,&70,&80,&90,&A0,&B0
.D5_B5BD
  EQUB &07,&05,&F8,&F3,&01,&06,&00,&F3,&01,&15,&F8,&FB,&03,&16,&00,&FB
  EQUB &03,&1F,&08,&FB,&03,&0E,&F8,&03,&03,&0F,&00,&03,&03

; Battle pre-stage card. SETUP_BY_MODE calls this when Z_49 is 2.
; Draws digits and a mark, plays sound 1Dh, waits B4h frames, fades out.
.SHOW_BATTLE_CARD
  JSR NMI_OFF
  JSR LOAD_MODE_GFX
  JSR NMI_ON
  JSR DRAW_BATTLE_CARD_MAP
  JSR DRAW_BATTLE_DIGITS
  JSR DRAW_WIN_COUNT_TILE
  JSR DRAW_BATTLE_MARK
  JSR CLEAR_SCROLL
  JSR PPU_ON
  JSR MARK_PALETTE
  LDA #&1D
  JSR AUDIO_CALL
  LDX #&B4
.L5_B5FF
  JSR WAIT_NMI
  DEX
  BNE L5_B5FF
  JSR FADE_PALETTE
  JMP PPU_OFF
IF REGION_JP

.DRAW_BATTLE_CARD_MAP
  LDA #LO(D4_9641)
  STA Z_66
  LDA #HI(D4_9641)
  STA Z_67
  LDA #LO(D4_96C5)
  STA Z_64
  LDA #HI(D4_96C5)
  STA Z_65
  LDA #LO(D4_9241)
  STA Z_62
  LDA #HI(D4_9241)
ELSE

; Draw the battle-card nametable from D4_A940. JMP L7_CD89.
.DRAW_BATTLE_CARD_MAP
  LDA #LO(D4_9241)
  STA Z_66
  LDA #&96
  STA Z_67
  LDA #&C1
  STA Z_64
  LDA #&96
  STA Z_65
  LDA #&41
  STA Z_62
  LDA #HI(D4_9241)
ENDIF
  STA Z_63
  LDA #LO(D4_A940)
  STA Z_20
  LDA #HI(D4_A940)
  STA Z_21
  JMP L7_CD89

; Draw W_055E, W_0560 and W_055F on the battle card.
; Digits come from SCORE_DIGIT_TILE. The middle value also places a second tile from BATTLE_TILE_RIGHT.
; Columns are D5_B66A, D5_B66B and D5_B66C; row is 0Ah.
.DRAW_BATTLE_DIGITS
  LDA #&0A
  STA Z_29
  LDY W_055E
  LDA SCORE_DIGIT_TILE,Y
  LDX D5_B66A
  LDY Z_29
  JSR QUEUE_MAP_TILE
  LDY W_0560
  LDA SCORE_DIGIT_TILE,Y
  LDX D5_B66C
  LDY Z_29
  JSR QUEUE_MAP_TILE
  LDY W_055F
  LDA BATTLE_TILE_RIGHT,Y
  PHA
  LDA BATTLE_TILE_LEFT,Y
  LDX D5_B66B
  LDY Z_29
  JSR QUEUE_MAP_TILE
  PLA
  LDX D5_B66B
  INX
  LDY Z_29
  JMP QUEUE_MAP_TILE
.D5_B66A
  EQUB &04
.D5_B66B
  EQUB &07
.D5_B66C
  EQUB &0B

; 10 tiles for the left half of the middle battle-card number. BATTLE_TILE_RIGHT is the matching right half. Index is W_055F.
.BATTLE_TILE_LEFT
  EQUB &22,&10,&12,&14,&16,&18,&1A,&1C,&1E,&20
.BATTLE_TILE_RIGHT
  EQUB &23,&11,&13,&15,&17,&19,&1B,&1D,&1F,&21

; Draw the battle mark for W_04C8.
; Negative: nothing. 1: 2x2 tiles at row 7 via DRAW_MARK_2X2. Other: one tile from D5_B6E5 at row 8.
.DRAW_BATTLE_MARK
  LDA W_04C8
  BMI L5_B6D8
  CMP #&01
  BEQ L5_B696
  TAY
  LDA D5_B6E5,Y
  LDX D5_B66A,Y
  LDY #&08
  JMP QUEUE_MAP_TILE
.L5_B696
  TAX
  ASL A
  ASL A
  STA Z_2A
  LDA D5_B66A,X
  STA Z_28
  LDA #&07
  STA Z_29
.DRAW_MARK_2X2
  LDY Z_2A
  LDA MARK_TILE_2X2,Y
  LDX Z_28
  LDY Z_29
  JSR QUEUE_MAP_TILE
  LDY Z_2A
  LDA D5_B6DA,Y
  LDX Z_28
  INX
  LDY Z_29
  JSR QUEUE_MAP_TILE
  LDY Z_2A
  LDA D5_B6DB,Y
  LDX Z_28
  LDY Z_29
  INY
  JSR QUEUE_MAP_TILE
  LDY Z_2A
  LDA D5_B6DC,Y
  LDX Z_28
  LDY Z_29
  INX
  INY
  JMP QUEUE_MAP_TILE
.L5_B6D8
  RTS

; 2x2 mark tiles. 3 groups of 4, index W_04C8*4: top-left, top-right, bottom-left, bottom-right.
.MARK_TILE_2X2
  EQUB &40
.D5_B6DA
  EQUB &41
.D5_B6DB
  EQUB &46
.D5_B6DC
  EQUB &47,&42,&43,&4E,&4F,&44,&45,&50,&51
.D5_B6E5
  EQUB &A4,&00,&AB

; Queue SCORE_DIGIT_TILE[W_0563] at column 3, row 3.
.DRAW_WIN_COUNT_TILE
  LDX W_0563
  LDA SCORE_DIGIT_TILE,X
  LDX #&03
  LDY #&03
  JMP QUEUE_MAP_TILE

; Versus pre-stage card. SETUP_BY_MODE calls this when Z_49 is not 0 or 2.
; Plays sound 1Dh and waits Z_2A counts of B4h frames.
.SHOW_VS_CARD
  JSR NMI_OFF
  JSR LOAD_MODE_GFX
  JSR NMI_ON
  JSR DRAW_VS_CARD_MAP
  JSR DRAW_VS_CARD_DIGITS
  JSR DRAW_VS_OUTCOME
  LDA #&00
  STA W_0561
  STA W_0562
  JSR CLEAR_SCROLL
  JSR PPU_ON
  JSR MARK_PALETTE
  LDA #&1D
  JSR AUDIO_CALL
  LDA #&B4
  STA Z_2A
.L5_B721
  JSR WAIT_NMI
  JSR DRAW_VS_CARD_SPRS
  JSR MARK_OAM
  DEC Z_2A
  BNE L5_B721
  JSR FADE_PALETTE
  JMP PPU_OFF

; Draw the versus-card nametable from D4_AAB6. JMP L7_CD89.
.DRAW_VS_CARD_MAP
  LDA #LO(D4_9641)
IF REGION_JP
  STA Z_66
  LDA #HI(D4_9641)
  STA Z_67
  LDA #LO(D4_96C5)
  STA Z_64
  LDA #HI(D4_96C5)
  STA Z_65
  LDA #LO(D4_9241)
  STA Z_62
  LDA #HI(D4_9241)
ELSE
  STA Z_66
  LDA #HI(D4_9641)
  STA Z_67
  LDA #LO(D4_96C1)
  STA Z_64
  LDA #HI(D4_96C1)
  STA Z_65
  LDA #LO(D4_9241)
  STA Z_62
  LDA #HI(D4_9241)
ENDIF
  STA Z_63
  LDA #LO(D4_AAB6)
  STA Z_20
  LDA #HI(D4_AAB6)
  STA Z_21
  JMP L7_CD89

; Queue SCORE_DIGIT_TILE[W_055E] at column D5_B77D and [W_055F] at D5_B77E, both on row 8.
.DRAW_VS_CARD_DIGITS
  LDY W_055E
  LDA SCORE_DIGIT_TILE,Y
  LDY #&08
  LDX D5_B77D
  JSR QUEUE_MAP_TILE
  LDY W_055F
  LDA SCORE_DIGIT_TILE,Y
  LDY #&08
  LDX D5_B77E
  JMP QUEUE_MAP_TILE

; Tiles indexed by a small count (score, wins, area, stage). Byte 0 is 6Dh; bytes 1..9 are 64h..6Ch.
.SCORE_DIGIT_TILE
  EQUB &6D
.D5_B774
  EQUB &64,&65,&66,&67,&68,&69,&6A,&6B,&6C
.D5_B77D
  EQUB &06
.D5_B77E
  EQUB &09

; Two versus-card metasprites. W_0562 flips every 8 frames and selects VS_CARD_SPR_A / VS_CARD_SPR_B.
.DRAW_VS_CARD_SPRS
  INC W_0561
  LDA W_0561
  AND #&07
  STA W_0561
  BNE L5_B794
  LDA W_0562
  EOR #&01
  STA W_0562
.L5_B794
  LDA W_0562
  ASL A
  TAX
  LDA VS_CARD_SPR_A,X
  STA Z_54
  LDA D5_B7E5,X
  STA Z_55
  LDA D5_B7E0
  ABS_STA Z_56
  LDA D5_B7E1
  ABS_STA Z_58
  LDA #&00
  ABS_STA Z_57
  ABS_STA Z_5A
  JSR DRAW_METASPRITE
  LDA W_0562
  ASL A
  TAX
  LDA VS_CARD_SPR_B,X
  STA Z_54
  LDA D5_B7E9,X
  STA Z_55
  LDA D5_B7E2
  ABS_STA Z_56
  LDA D5_B7E3
  ABS_STA Z_58
  LDA #&00
  ABS_STA Z_57
  ABS_STA Z_5A
  JMP DRAW_METASPRITE
.D5_B7E0
  EQUB &50
.D5_B7E1
  EQUB &80
.D5_B7E2
  EQUB &C8
.D5_B7E3
  EQUB &80

; 2 words, toggled by W_0562. Left versus-card metasprite. VS_CARD_SPR_B is the right one.
.VS_CARD_SPR_A
  EQUB LO(D5_B7EC)
.D5_B7E5
  EQUB HI(D5_B7EC)
  EQUW D5_B805
.VS_CARD_SPR_B
  EQUB LO(D5_B822)
.D5_B7E9
  EQUB HI(D5_B822)
  EQUW D5_B83B
.D5_B7EC
  EQUB &06,&1D,&F5,&F7,&40,&0F,&E1,&FE,&40,&0E,&E9,&FE,&40,&20,&F5,&FF
  EQUB &40,&1F,&E1,&06,&40,&1E,&E9,&06,&40
.D5_B805
  EQUB &07,&1A,&E0,&F9,&40,&19,&E8,&F9,&40,&1C,&E0,&01,&40,&1B,&E8,&01
  EQUB &40,&22,&F4,&FC,&40,&21,&FC,&FC,&40,&23,&F5,&04,&40
.D5_B822
  EQUB &06,&1D,&EB,&F7,&03,&20,&EB,&FF,&03,&0E,&F8,&FE,&03,&0F,&00,&FE
  EQUB &03,&1E,&F8,&06,&03,&1F,&00,&06,&03
.D5_B83B
  EQUB &07,&19,&F8,&F9,&03,&1A,&00,&F9,&03,&21,&E4,&FC,&03,&22,&EC,&FC
  EQUB &03,&1B,&F8,&01,&03,&1C,&00,&01,&03,&23,&EC,&04,&03

; Compare W_055E with W_055F and queue the outcome tiles.
; Equal and >= 4: one or two strings (9 uses two). Unequal with either side >= 4: a run of tiles via QUEUE_TILE_SPAN.
.DRAW_VS_OUTCOME
  LDA W_055E
  CMP W_055F
  BEQ L5_B87A
  CMP #&04
  BCS L5_B86B
  LDA W_055F
  CMP #&04
  BCC L5_B8CF
.L5_B86B
  LDA #&02
  STA Z_28
  LDA #&0A
  STA Z_29
  LDA #&8A
  LDX #&0C
  JMP QUEUE_TILE_SPAN
.L5_B87A
  CMP #&04
  BCC L5_B8CF
  CMP #&09
  BNE L5_B8A4
  LDA #&03
  STA Z_28
  LDA #&0A
  STA Z_29
  LDA #&B3
  LDX #&04
  JSR QUEUE_TILE_SPAN
  LDA #&08
  STA Z_28
  LDA #&0A
  STA Z_29
IF REGION_JP
  LDA #&7E
ELSE
  LDA #&E9
ENDIF
  STA Z_24
  LDA #&B8
  STA Z_25
  JMP QUEUE_STRING_TILES
IF REGION_JP
.L5_B8A4
  LDA #&06
ELSE
.L5_B8A4
  LDA #&05
ENDIF
  STA Z_28
  LDA #&0A
  STA Z_29
IF REGION_JP
  LDA #&86
  LDX #&04
ELSE
  LDA #&EF
  STA Z_24
  LDA #&B8
  STA Z_25
  JMP QUEUE_STRING_TILES
ENDIF

; Queue Z_2A consecutive tiles starting at A, column Z_28, row Z_29.
; Each tile increments A and the column. Uses W_04CA as the cursor.
.QUEUE_TILE_SPAN
  STA W_04CA
  STX Z_2A
.L5_B8BC
  LDA W_04CA
  LDX Z_28
  LDY Z_29
  JSR QUEUE_MAP_TILE
  INC W_04CA
  INC Z_28
  DEC Z_2A
  BNE L5_B8BC
.L5_B8CF
  RTS
.QUEUE_STRING_TILES
  LDY #&00
  LDA (Z_24),Y
  BEQ L5_B8E8
  LDX Z_28
  LDY Z_29
  JSR QUEUE_MAP_TILE
  INC Z_28
  INC Z_24
  BNE L5_B8E5
  INC Z_25
.L5_B8E5
  JMP QUEUE_STRING_TILES
.L5_B8E8
  RTS
  EQUB &B7,&B4,&B6,&88,&B8,&00
IF REGION_JP
ELSE
  EQUB &FC,&FD,&FE,&FF,&38,&39,&00
ENDIF

; Normal-mode stage card. SETUP_BY_MODE calls this when Z_49 is 0.
; Sound 1Dh, waits B4h frames, fades out.
.SHOW_STAGE_CARD
  JSR NMI_OFF
  JSR LOAD_MODE_GFX
  JSR NMI_ON
  JSR DRAW_STAGE_CARD_MAP
  JSR DRAW_STAGE_CARD
  JSR CLEAR_SCROLL
  JSR PPU_ON
  JSR MARK_PALETTE
  LDA #&1D
  JSR AUDIO_CALL
  LDX #&B4
.L5_B915
  JSR WAIT_NMI
  DEX
  BNE L5_B915
  JSR FADE_PALETTE
  JMP PPU_OFF

; Draw the stage-card nametable from D4_AB7D. JMP L7_CD89.
.DRAW_STAGE_CARD_MAP
  LDA #LO(D4_9641)
IF REGION_JP
  STA Z_66
  LDA #HI(D4_9641)
  STA Z_67
  LDA #LO(D4_96C5)
  STA Z_64
  LDA #HI(D4_96C5)
  STA Z_65
  LDA #LO(D4_9241)
  STA Z_62
  LDA #HI(D4_9241)
ELSE
  STA Z_66
  LDA #HI(D4_9641)
  STA Z_67
  LDA #LO(D4_96C1)
  STA Z_64
  LDA #HI(D4_96C1)
  STA Z_65
  LDA #LO(D4_9241)
  STA Z_62
  LDA #HI(D4_9241)
ENDIF
  STA Z_63
  LDA #LO(D4_AB7D)
  STA Z_20
  LDA #HI(D4_AB7D)
  STA Z_21
  JMP L7_CD89

; Stage card: score, the two-tile suffix D5_B9C7, lives, then SCORE_DIGIT_TILE for Z_4B and Z_4C.
.DRAW_STAGE_CARD
  JSR DRAW_CARD_SCORE
  JSR DRAW_CARD_LIVES
  ABS_LDX Z_4B
  LDA D5_B774,X
  LDX #&06
  LDY #&07
  JSR QUEUE_MAP_TILE
  ABS_LDX Z_4C
  LDA D5_B774,X
  LDX #&09
  LDY #&07
  JMP QUEUE_MAP_TILE

; Draw W_03D0 as 8 digits at (0Dh, 5) and queue D5_B9C7 (two tiles) at (0Ah, 5).
.DRAW_CARD_SCORE
  LDX #&07
  LDY #&00
.L5_B968
  LDA W_03D0,X
  ORA #&30
  STA W_052A,Y
  INY
  DEX
  BPL L5_B968
  LDX #&0D
  LDY #&05
  JSR XY_TO_NT_ADDR
IF REGION_JP
  LDA #&28
ELSE
  LDA #&2A
ENDIF
  STA Z_20
  LDA #&05
  STA Z_21
  LDA #&00
  STA Z_2E
  LDX #&08
  JSR QUEUE_PPU_RUN
  LDX #&0A
  LDY #&05
  JSR XY_TO_NT_ADDR
  LDA #LO(D5_B9C7)
  STA Z_20
  LDA #HI(D5_B9C7)
  STA Z_21
  LDA #&00
  STA Z_2E
  LDX #&02
  JMP QUEUE_PPU_RUN

; Copy W_04E5 into W_04CB and draw it as one digit (OR 30h) at column 12h, row 15h.
.DRAW_CARD_LIVES
  LDA W_04E5
  STA W_04CB
  ORA #&30
  STA W_052A
  LDX #&12
  LDY #&15
  JSR XY_TO_NT_ADDR
IF REGION_JP
  LDA #&28
ELSE
  LDA #&2A
ENDIF
  STA Z_20
  LDA #&05
  STA Z_21
  LDA #&00
  STA Z_2E
  LDX #&01
  JMP QUEUE_PPU_RUN
.D5_B9C7
  EQUB &53,&43

; Remote detonate for player Z_68. L7_CFD4 enters here when Z_AF is 0.
; Scans the 8 bomb slots under BOMB_SLOT_BASE[Z_68]. The first positive X_6001 flag jumps to DETONATE_BOMB.
.DETONATE_REMOTE
  LDX Z_68
  LDA BOMB_SLOT_BASE,X
  TAX
  LDY #&07
.L5_B9D1
  LDA X_6001,X
  BEQ L5_B9DB
  BMI L5_B9DB
  JMP DETONATE_BOMB
.L5_B9DB
  DEX
  DEY
  BPL L5_B9D1
  RTS

; Place a bomb at Z_1C/Z_1D. L7_CF96 enters here.
; ALLOC_BOMB_SLOT must return C=1. Writes the X_6001 slot, fuse W_03ED, map bit 10h, and plays sound 02h.
; A map byte with bit 7 also sets X_6079 bit 7 and fuse 2, and copies the actor id from FIND_ACTOR_CELL.
.PLACE_BOMB
  JSR ALLOC_BOMB_SLOT
  BCC L5_BA55
  STX Z_2C
  LDA #&01
  STA X_6001,X
  LDA Z_1C
  STA Z_28
  STA X_6019,X
  LDA Z_1D
  STA Z_29
  STA X_6031,X
  LDA #&00
  STA X_6049,X
  STA X_6079,X
  LDA #&FF
  STA X_6091,X
  LDA W_03ED
  STA X_6061,X
  LDX Z_1C
  LDY Z_1D
  LDA BOMB_ANIM_TILE
  JSR QUEUE_TILE_Y2
  LDX Z_1C
  LDY Z_1D
  JSR PEEK_MAP_BYTE
  PHA
  AND #&80
  BEQ L5_BA3C
  LDX Z_2C
  LDA #&80
  STA X_6079,X
  LDA #&02
  STA X_6061,X
  JSR FIND_ACTOR_CELL
  CPY #&FF
  BEQ L5_BA3C
  LDA X_620E,Y
  STA X_6091,X
.L5_BA3C
  LDY Z_1C
  PLA
  ORA #&10
  STA (Z_2F),Y
  LDX Z_2C
  LDA X_6091,X
  BPL L5_BA50
  JSR FREE_RING_SLOT
  STA X_6091,X
.L5_BA50
  LDA #&02
  JSR AUDIO_CALL
.L5_BA55
  RTS

; Bomb and flame tick. UPDATE_BLASTS enters here.
; X_624D even: step flames. Odd: step each occupied slot of the 24 at X_6001.
.STEP_BLASTS
  INC X_624D
  LDA X_624D
  LSR A
  BCS L5_BA75
  INC X_624E
  LDX #&17
  STX Z_2A
.L5_BA66
  LDX Z_2A
  LDA X_6001,X
  BEQ L5_BA70
  JSR STEP_BOMB
.L5_BA70
  DEC Z_2A
  BPL L5_BA66
  RTS
.L5_BA75
  INC X_624F
  JMP STEP_FLAMES

; One bomb slot in X.
; Negative X_6001 counts X_60A9 down, then the flag becomes 1.
; The fuse in X_6061 counts down unless X_6000 is set, or Z_AF is 1 and X_6079 is 0.
; Fuse 0 jumps to DETONATE_BOMB. The tile cycles BOMB_ANIM_TILE every 8 counts of X_624E.
.STEP_BOMB
  LDA X_6079,X
  BNE L5_BA8B
  LDA X_6001,X
  BMI L5_BABB
  LDA Z_AF
  CMP #&01
  BEQ L5_BA98
.L5_BA8B
  LDA X_6000
  BNE L5_BA98
  LDA X_6061,X
  BEQ DETONATE_BOMB
  DEC X_6061,X
.L5_BA98
  LDA X_624E
  AND #&07
  BNE L5_BABA
  LDA X_6049,X
  CLC
  ADC #&01
  AND #&03
  STA X_6049,X
  TAY
  LDA BOMB_ANIM_TILE,Y
  PHA
  LDY X_6031,X
  LDA X_6019,X
  TAX
  PLA
  JMP QUEUE_TILE_Y2
.L5_BABA
  RTS
.L5_BABB
  LDA #&00
  STA X_6049,X
  DEC X_60A9,X
  BNE L5_BACD
  LDA #&01
  STA X_6001,X
  STA X_6049,X
.L5_BACD
  RTS
.DETONATE_BOMB
  TXA
  LSR A
  LSR A
  LSR A
  AND #&03
  TAY
  LDA Z_93,Y
  STA X_624B
  LDA Z_87,Y
  BPL L5_BAEB
  AND #&03
  CMP #&03
  BNE L5_BAEB
  LDA #&00
  STA X_624B
.L5_BAEB
  JSR FIND_FREE_FLAME
  BCC L5_BABA
  LDY X_6031,X
  STY Z_1D
  STY Z_29
  JSR MAP_ROW_PTR
  LDY X_6019,X
  STY Z_1C
  STY Z_28
  LDA #&00
  STA (Z_2F),Y
  LDA #&00
  STA X_6001,X
  LDA X_6091,X
  STA X_624C
  LDA X_6079,X
  JMP L7_D018
.STEP_FLAMES
  LDX #&3B
  STX Z_2A
.L5_BB1A
  LDX Z_2A
  LDA X_60E2,X
  BEQ L5_BB65
  AND #&0F
  TAY
  INC X_6196,X
  LDA X_6196,X
  STA Z_1C
  AND #&01
  BNE L5_BB65
  LDA X_611E,X
  STA Z_28
  LDA X_615A,X
  STA Z_29
  LDA Z_1C
  LSR A
  ORA FLAME_TILE_BASE,Y
  TAY
  LDA FLAME_ANIM_TILE,Y
  LDY Z_29
  LDX Z_28
  JSR QUEUE_TILE_Y2
  LDA Z_1C
  CMP #&0E
  BCC L5_BB65
  LDA #&00
  LDX Z_2A
  STA X_60E2,X
  LDY Z_29
  JSR MAP_ROW_PTR
  LDY Z_28
  LDA (Z_2F),Y
  AND #&5F
  STA (Z_2F),Y
.L5_BB65
  DEC Z_2A
  BMI L5_BB6C
  JMP L5_BB1A
.L5_BB6C
  RTS

; 4 bomb tiles. X_6049 & 3 selects 01h, 02h, 03h, 02h.
.BOMB_ANIM_TILE
  EQUB &01,&02,&03,&02

; 16 base indexes added to the flame timer. The low nibble of X_60E2 selects the row. Unused types are 0.
.FLAME_TILE_BASE
  EQUB &00,&08,&18,&10,&20,&08,&28,&10,&30,&38,&40,&00,&00,&00,&00,&00

; Flame tiles. 9 rows of 8. Y = (X_6196 >> 1) OR the base from FLAME_TILE_BASE. The row is queued with QUEUE_TILE_Y2.
.FLAME_ANIM_TILE
  EQUB &04,&0B,&12,&19,&12,&0B,&04,&38,&07,&0E,&15,&1C,&15,&0E,&07,&38
  EQUB &0A,&11,&18,&1F,&18,&11,&0A,&38,&05,&0C,&13,&1A,&13,&0C,&05,&38
  EQUB &08,&0F,&16,&1D,&16,&0F,&08,&38,&06,&0D,&14,&1B,&14,&0D,&06,&38
  EQUB &09,&10,&17,&1E,&17,&10,&09,&38,&3A,&3A,&3B,&3C,&3D,&3E,&3F,&38
  EQUB &2D,&2D,&2E,&2F,&30,&31,&32,&38

; Find a free bomb slot for player Z_68.
; Empty map cell (bits 0..6 clear) required. Packs that player's 8 X_6001 slots down from BOMB_SLOT_BASE.
; C=1 if the free index is in range and Z_A9 >= BOMB_SLOT_LIMIT[X]. C=0 otherwise.
.ALLOC_BOMB_SLOT
  LDX Z_1C
  LDY Z_1D
  JSR PEEK_MAP_BYTE
  AND #&7F
  BNE L5_BC24
  LDX Z_68
  LDA BOMB_SLOT_BASE,X
  TAX
  TAY
  LDA #&07
  STA Z_2A
.L5_BBDF
  LDA X_6001,Y
  BEQ L5_BC13
  LDA #&00
  STA X_6001,Y
  LDA X_6019,Y
  STA X_6019,X
  LDA X_6031,Y
  STA X_6031,X
  LDA X_6049,Y
  STA X_6049,X
  LDA X_6061,Y
  STA X_6061,X
  LDA X_6079,Y
  STA X_6079,X
  LDA X_6091,Y
  STA X_6091,X
  LDA #&01
  STA X_6001,X
  DEX
.L5_BC13
  DEY
  DEC Z_2A
  BPL L5_BBDF
  TXA
  BMI L5_BC24
  LDA Z_A9
  CMP BOMB_SLOT_LIMIT,X
  BCC L5_BC24
  SEC
  RTS
.L5_BC24
  CLC
  RTS

; 24 bytes, three copies of 07h..00h. After ALLOC_BOMB_SLOT packs a player's bombs, Z_A9 must be >= the byte at the free slot index.
.BOMB_SLOT_LIMIT
  EQUB &07,&06,&05,&04,&03,&02,&01,&00,&07,&06,&05,&04,&03,&02,&01,&00
  EQUB &07,&06,&05,&04,&03,&02,&01,&00

; 3 bytes, one per player in Z_68: 07h, 0Fh, 17h. Top index of that player's 8 bomb slots in X_6001.
.BOMB_SLOT_BASE
  EQUB &07,&0F,&17

; Find a free flame slot among the 60 flags at X_60E2 (index 3Bh down).
; Out: C=1 and Y=slot, or C=0 if none.
.FIND_FREE_FLAME
  LDY #&3B
.L5_BC43
  LDA X_60E2,Y
  BEQ L5_BC4D
  DEY
  BPL L5_BC43
  CLC
  RTS
.L5_BC4D
  SEC
  RTS

; Spread a blast from Z_1C/Z_1D. L7_D018 stores the direction mask in Z_B8 and calls this.
; Range is X_624B. LSR Z_B8 drops a direction when its bit was set: up, down, left, right.
; Each step calls BLAST_CELL and stops on C=0 or when the range count expires.
.SPREAD_FLAME
  LDA X_62E7
  BMI L5_BC57
  INC X_62E7
.L5_BC57
  LDA X_624B
  STA X_624A
  LDA Z_1C
  STA Z_28
  LDA Z_1D
  STA Z_29
  LDA #&00
  JSR BLAST_CELL
  LSR Z_B8
  BCS L5_BC8D
  LDA Z_1C
  STA Z_28
  LDA Z_1D
  STA Z_29
.FLAME_UP
  DEC Z_29
  BMI L5_BC8D
  LDA #&01
  LDX X_624A
  BNE L5_BC83
  LDA #&02
.L5_BC83
  JSR BLAST_CELL
  BCC L5_BC8D
  DEC X_624A
  BPL FLAME_UP
.L5_BC8D
  LSR Z_B8
  BCS L5_BCB4
  LDA X_624B
  STA X_624A
  LDA Z_1C
  STA Z_28
  LDA Z_1D
  STA Z_29
.FLAME_DOWN
  INC Z_29
  LDA #&05
  LDX X_624A
  BNE L5_BCAA
  LDA #&06
.L5_BCAA
  JSR BLAST_CELL
  BCC L5_BCB4
  DEC X_624A
  BPL FLAME_DOWN
.L5_BCB4
  LSR Z_B8
  BCS L5_BCDD
  LDA X_624B
  STA X_624A
  LDA Z_1C
  STA Z_28
  LDA Z_1D
  STA Z_29
.FLAME_LEFT
  DEC Z_28
  BMI L5_BCDD
  LDA #&03
  LDX X_624A
  BNE L5_BCD3
  LDA #&04
.L5_BCD3
  JSR BLAST_CELL
  BCC L5_BCDD
  DEC X_624A
  BPL FLAME_LEFT
.L5_BCDD
  LSR Z_B8
  BCS L5_BD04
  LDA X_624B
  STA X_624A
  LDA Z_1C
  STA Z_28
  LDA Z_1D
  STA Z_29
.FLAME_RIGHT
  INC Z_28
  LDA #&07
  LDX X_624A
  BNE L5_BCFA
  LDA #&08
.L5_BCFA
  JSR BLAST_CELL
  BCC L5_BD04
  DEC X_624A
  BPL FLAME_RIGHT
.L5_BD04
  RTS

; One flame cell. In: A = flame type, Z_28/Z_29 = cell. Out: C=1 if the ray continues.
; Map bit 6 or value A0h stops the ray. Bit 4 kicks the bomb there (KICK_DIR_MASK) and stops.
; Low bits 1 or 2 go to BLAST_CONTENTS and stop. Value 20h opens a buried tile, then uses type 09h.
; Low bits 0 spawn a flame.
.BLAST_CELL
  STA Z_1E
  LDY Z_29
  LDA MAP_ROW_LO,Y
  STA Z_2F
  LDA MAP_ROW_HI,Y
  STA Z_30
  LDY Z_28
  LDA (Z_2F),Y
  STA Z_1F
  AND #&40
  BNE L5_BD84
  LDA Z_1F
  AND #&10
  BNE L5_BD86
  LDA Z_1F
  AND #&A0
  CMP #&A0
  BEQ L5_BD84
  CMP #&20
  BEQ L5_BD3A
  LDA Z_1F
  AND #&03
  BEQ SPAWN_FLAME
  JSR BLAST_CONTENTS
  CLC
  RTS
.L5_BD3A
  JSR OPEN_BURIED
  BCC L5_BD84
  LDA #&09
  STA Z_1E
  JSR SPAWN_FLAME
  BCC L5_BD84
  DEC W_04E2
  CLC
  RTS

; Spawn a flame actor if FIND_FREE_FLAME succeeds.
; Stores cell, type|80h, range X_624A, owner X_624C. Sets map bit 7. Calls NOTE_BLAST_TYPE. C=1.
.SPAWN_FLAME
  JSR CLEAR_FLAME_HERE
  JSR FIND_FREE_FLAME
  BCC L5_BD84
  LDA X_624A
  STA X_61D2,Y
  LDA Z_28
  STA X_611E,Y
  LDA Z_29
  STA X_615A,Y
  LDA #&FF
  STA X_6196,Y
  LDA Z_1E
  ORA #&80
  STA X_60E2,Y
  LDA X_624C
  STA X_620E,Y
  JSR NOTE_BLAST_TYPE
  LDY Z_28
  LDA Z_1F
  ORA #&80
  STA (Z_2F),Y
  SEC
  RTS
.L5_BD84
  CLC
  RTS
.L5_BD86
  LDX #&17
.L5_BD88
  LDA X_6001,X
  BEQ L5_BDBA
  LDA Z_28
  CMP X_6019,X
  BNE L5_BDBA
  LDA Z_29
  CMP X_6031,X
  BNE L5_BDBA
  LDA X_6079,X
  BMI L5_BDBA
  LDY Z_1E
  ORA KICK_DIR_MASK,Y
  STA X_6079,X
  LDA X_624C
  STA X_6091,X
  LDA #&02
  CMP X_6061,X
  BCS L5_BDBA
  STA X_6061,X
  CLC
  RTS
.L5_BDBA
  DEX
  BPL L5_BD88
  CLC
  RTS

; Flame hit a cell whose low bits are 1 or 2.
; 1: clear the matching W_04EB slot and the map byte, spawn flame type 0Ah, JMP L7_D11B.
; 2: JMP L7_D103. Other values return.
.BLAST_CONTENTS
  CMP #&01
  BNE L5_BDE4
  JSR FIND_BOMB_SLOT
  BMI L5_BDEB
  LDA #&00
  STA W_04EB,X
  LDY Z_29
  JSR MAP_ROW_PTR
  LDY Z_28
  LDA #&00
  STA (Z_2F),Y
  STA Z_1F
  LDA #&0A
  STA Z_1E
  JSR SPAWN_FLAME
  JMP L7_D11B
.L5_BDE4
  CMP #&02
  BNE L5_BDEB
  JMP L7_D103
.L5_BDEB
  RTS

; Find a placed-bomb slot whose cell is Z_28/Z_29.
; In: those coordinates. Out: X=slot and N clear if W_04EB,X is nonzero; X=FFh (N set) if none. 15 slots.
.FIND_BOMB_SLOT
  LDX #&0E
.L5_BDEE
  LDA W_04EB,X
  BEQ L5_BE01
  LDA W_04FA,X
  CMP Z_28
  BNE L5_BE01
  LDA W_0509,X
  CMP Z_29
  BEQ L5_BE04
.L5_BE01
  DEX
  BPL L5_BDEE
.L5_BE04
  RTS

; If this cell already has a flame actor whose low type nibble is not 9, clear that X_60E2 flag.
; Skipped when Z_1E is not 0 and the map byte Z_1F is 0.
.CLEAR_FLAME_HERE
  LDA Z_1E
  CMP #&00
  BEQ L5_BE0F
  LDA Z_1F
  BEQ L5_BE36
.L5_BE0F
  LDY #&3B
.L5_BE11
  LDA X_60E2,Y
  BEQ L5_BE33
  LDA X_611E,Y
  CMP Z_28
  BNE L5_BE33
  LDA X_615A,Y
  CMP Z_29
  BNE L5_BE33
  LDA X_60E2,Y
  AND #&0F
  CMP #&09
  BEQ L5_BE33
  LDA #&00
  STA X_60E2,Y
  RTS
.L5_BE33
  DEY
  BPL L5_BE11
.L5_BE36
  RTS

; 9 masks ORed into X_6079 when a flame of that type hits a bomb. Index is the flame type in Z_1E.
.KICK_DIR_MASK
  EQUB &F0,&02,&02,&08,&08,&01,&01,&04,&04

; Open a buried cell (map value 20h).
; Low bits 2: set W_0518 to 1, reveal tile 0Ch, C=0.
; Low bits 1: if FIND_BOMB_CELL hits, reveal BURIED_REVEAL_TILE[flag & 0Fh]; either way DEC W_04E2.
; Any other low bits: C=1 and the map byte is left for the flame.
.OPEN_BURIED
  LDA Z_1F
  AND #&03
  CMP #&02
  BEQ L5_BE64
  CMP #&01
  BEQ L5_BE54
  SEC
  RTS
.L5_BE4E
  LDA #&00
  STA Z_1F
  SEC
  RTS
.L5_BE54
  JSR FIND_BOMB_CELL
  BCC L5_BE4E
  DEC W_04E2
  LDA W_04EB,X
  AND #&0F
  JMP L5_BE6E
.L5_BE64
  DEC W_04E2
  LDA #&01
  STA W_0518
  LDA #&0C
.L5_BE6E
  TAX
  LDA BURIED_REVEAL_TILE,X
  LDX Z_28
  LDY Z_29
  JSR QUEUE_TILE_Y2
  LDY Z_29
  JSR MAP_ROW_PTR
  LDY Z_28
  LDA Z_1F
  AND #&03
  STA (Z_2F),Y
  CLC
  RTS

; 13 tiles revealed by OPEN_BURIED. Index is the bomb flag's low nibble, or 0Ch for map low-bits 2.
.BURIED_REVEAL_TILE
  EQUB &20,&21,&22,&22,&22,&22,&22,&22,&22,&22,&22,&2C,&29
  FILLTO &BFBC
  ASSERT P% <= &BFBC
  RESET_STUB
