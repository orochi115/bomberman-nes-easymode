; RAM, WRAM and register names
; Generated from db/symbols.tsv (ram:XXXX keys, US addresses).
; Z_xx / W_xxxx / X_xxxx are unnamed zero page / RAM / WRAM ($6000) locations.

WORK_PTR                = &00 ; Scratch pointer low. The sound driver walks a channel stream through it.
WORK_PTR_HI             = &01 ; Scratch pointer high.
WORK_PTR2               = &04 ; Scratch pointer low. SND_RUN_BGM points it at the channel-header table.
WORK_PTR2_HI            = &05 ; Scratch pointer high.
SND_TMP0                = &06 ; Sound driver scratch (volume, detune, SFX).
SND_TMP1                = &07 ; Sound driver scratch (volume, detune, SFX).
SND_ENV_PTR             = &08 ; Pitch envelope read pointer (SND_STEP_PITCH_ENV).
SND_ENV_PTR_HI          = &09 ; High byte of SND_ENV_PTR.
SND_VECTOR              = &0A ; Jump vector for SND_RUN_CMD handlers (JMP (SND_VECTOR)).
SND_VECTOR_HI           = &0B ; High byte of SND_VECTOR.
SND_ARG                 = &0C ; Sound driver 16-bit argument: signed pitch delta, multiply operand.
SND_ARG_HI              = &0D ; High byte of SND_ARG.
SND_TMP2                = &0E ; Sound driver scratch (SND_MUL_DURATION).
SND_TMP3                = &0F ; Sound driver scratch (SFX priority in SND_REQUEST).
PPU_ENABLED             = &10 ; 1 after PPU_ON, 0 after PPU_OFF
NMI_CNT                 = &11 ; incremented by NMI; WAIT_NMI clears it
OAM_READY               = &12 ; 1 = NMI should DMA the page-7 OAM buffer, then clear it
OAM_INDEX               = &13 ; next free byte in the page-7 OAM buffer
FRAME_CNT               = &14 ; incremented once per NMI
PAL_DIRTY               = &15 ; 1 = upload PAL_BUF on the next NMI
PAL_SRC                 = &16 ; Source pointer for COPY_PAL_ROWS.
PAL_SRC_HI              = &17 ; High byte of PAL_SRC.
PPU_CTRL_BUF            = &18 ; shadow of PPU control register
PPU_MASK_BUF            = &19 ; shadow of PPU mask register
SAVED_BANK              = &1A ; PRG bank saved by BANK_SAVE_SWITCH
MMC1_GUARD              = &1B ; nonzero while an MMC1 shift is in progress
TEMP1                   = &1C ; Scratch byte: CHR RLE literal (DECODE_CHR), strip and loop counters, other short-lived values.
TEMP2                   = &1D ; Scratch byte: CHR RLE control bits (DECODE_CHR), other short-lived values.
TEMP3                   = &1E ; Scratch byte: tiles left in UPLOAD_CHR_RLE; flame type in BLAST_CELL.
MAP_BYTE                = &1F ; Map cell latched by BLAST_CELL.
DATA_PTR                = &20 ; General data pointer: CHR, strings, queued bytes.
DATA_PTR_HI             = &21 ; High byte of DATA_PTR.
DEST_PTR                = &22 ; Destination pointer: PPU address for CHR and nametable uploads; second data pointer elsewhere.
DEST_PTR_HI             = &23 ; High byte of DEST_PTR.
DATA_PTR2               = &24 ; Second data pointer. Nametable upload reads 64 attribute bytes through it.
DATA_PTR2_HI            = &25 ; High byte of DATA_PTR2.
CELL_COL                = &28 ; Current map column.
CELL_ROW                = &29 ; Current map row.
TEMP4                   = &2A ; Scratch counter: area intro countdown, soft block quota, fixed spawn index, flame steps.
TEMP5                   = &2B ; Scratch byte (SHOW_AREA_INTRO).
TEMP6                   = &2C ; Scratch byte (PLACE_BOMB).
PPU_RUN_CTRL            = &2E ; Bit 7 selects vertical PPU increment for a queued run.
MAP_PTR                 = &2F ; Live map row pointer. MAP_ROW_PTR sets it from MAP_ROW_LO/HI.
MAP_PTR_HI              = &30 ; High byte of MAP_PTR.
SPLIT_MODE              = &31 ; 0 off, 1 top sprite-0 split, 80h low split
SPRITE0_Y               = &32 ; Y of sprite 0, used for the split
FAR_A                   = &33 ; A saved by FAR_CALL.
FAR_X                   = &34 ; X saved by FAR_CALL.
FAR_Y                   = &35 ; Y saved by FAR_CALL.
FAR_RET                 = &36 ; Caller return address low, used to read the inline bank and target.
FAR_RET_HI              = &37 ; Caller return address high.
FAR_TMP                 = &38 ; Resume address, then the target address low.
FAR_TMP_HI              = &39 ; Target address high read from the inline operand.
FAR_X2                  = &3A ; X saved across the bank restore in FAR_CALL.
ZP_FF                   = &FF ; Byte at 00FFh. CLEAR_LOW_RAM skips FC-FF. SND_SET_FADE loads it when the song id is 0Ch.
CUR_BANK                = &0100 ; PRG bank mapped at 8000h
W_0200                  = &0200
SND_CH                  = &0202 ; Channel 0-4 being updated.
SND_BYTE                = &0203 ; Last byte read from the channel stream.
SND_BANK                = &0204 ; PRG bank of the current song streams.
SND_SFX_ID              = &0205 ; SFX id. Bit 7 means the effect is ticking.
SND_BGM_ID              = &0206 ; Song id. Bit 7 means the headers are loaded.
SND_DMC_ID              = &0207 ; DMC id. Bit 7 means it has started. 1Eh is silence.
SND_CMD_ID              = &0208 ; Pending command 80h-8Ch.
W_0209                  = &0209
SND_BGM_LATCH           = &020A ; Copy of SND_BGM_ID taken when a song loads.
W_020B                  = &020B
W_020C                  = &020C
W_020D                  = &020D
W_020E                  = &020E
W_020F                  = &020F
W_0210                  = &0210
W_0211                  = &0211
W_0212                  = &0212
SND_STREAM              = &0213 ; 5 stream pointers, low bytes, stride 2.
SND_STREAM_HI           = &0214 ; 5 stream pointers, high bytes, stride 2.
W_021D                  = &021D
W_0222                  = &0222
W_0227                  = &0227
SND_NOTE_LEN            = &022C ; 5 bytes. Note length per channel.
SND_GATE                = &0231 ; 5 bytes. Frames left in the note gate.
SND_DUTY                = &0236 ; 5 bytes. Duty from stream command DA.
SND_GATE_SCL            = &023B ; 5 bytes. Gate scale from command DC.
SND_PENV                = &0240 ; 5 bytes. Pitch-envelope id from command DB.
SND_DUR_UNIT            = &0245 ; 5 bytes. Duration unit from command D4.
SND_OCTAVE              = &024A ; 5 bytes. Octave per channel.
W_024D                  = &024D
SND_TRANSPOSE           = &024F ; 5 bytes. Transpose from command D5.
W_0252                  = &0252
W_0254                  = &0254
W_0259                  = &0259
W_026D                  = &026D
W_0281                  = &0281
SND_LEGATO              = &0295 ; 5 bytes. Command D6: next note does not retrigger.
W_029A                  = &029A
W_029F                  = &029F
W_02A0                  = &02A0
W_02C7                  = &02C7
SND_VOLUME              = &02CC ; 5 bytes. Channel volume 00h-1Fh from E3 or E8.
SND_VIB_LEN             = &02D1 ; 5 bytes. Vibrato length from command E5.
SND_VIB_ID              = &02D6 ; 5 bytes. Vibrato id from command E4.
W_02D9                  = &02D9
W_02DC                  = &02DC
W_02DF                  = &02DF
SND_DETUNE              = &02E2 ; 5 bytes. Detune from command E6.
SND_DETUNE_ID           = &02E7 ; 5 bytes. Detune id from command E7.
W_02EC                  = &02EC
W_02EF                  = &02EF
W_02F2                  = &02F2
W_02F7                  = &02F7
W_02FC                  = &02FC
W_0301                  = &0301
W_0306                  = &0306
W_030B                  = &030B
SND_PITCH_LO            = &0310 ; 5 bytes. Pitch low, paired with SND_PITCH_HI.
SND_PITCH_HI            = &0315 ; 5 bytes. Pitch high.
W_031A                  = &031A
W_031F                  = &031F
W_0324                  = &0324
W_0329                  = &0329
SND_APU_BUF             = &032E ; APU register image for the music channels. 14h bytes cleared by SND_INIT.
W_032F                  = &032F
W_0330                  = &0330
W_0331                  = &0331
W_033A                  = &033A
W_033C                  = &033C
W_033D                  = &033D
W_033E                  = &033E
SND_DIRTY               = &0342 ; One dirty byte per channel. SND_INIT clears five bytes.
W_0345                  = &0345
W_0346                  = &0346
SND_SFX_ON              = &0347 ; Which channels the SFX layer owns.
W_0348                  = &0348
W_0349                  = &0349
W_034A                  = &034A
W_034B                  = &034B
W_034C                  = &034C
W_034D                  = &034D
W_034E                  = &034E
W_034F                  = &034F
W_0350                  = &0350
SND_MASTER              = &0351 ; Master volume. Starts at 10h. Below 10h square volume is scaled down.
SND_MIX                 = &0352 ; Shadow of 4015h.
SND_CMD_X               = &0353 ; Value returned in X by a sound command.
W_0354                  = &0354
SND_FADE_ACC            = &0355 ; Adds SND_FADE each frame. Carry lowers SND_MASTER.
SND_FADE                = &0356 ; Fade step from command 85h.
SND_MASTER0             = &0357 ; Master volume restored when a song loads or the fade wraps.
SND_CH_RUN              = &0358 ; How many channels SND_RUN_BGM actually ticked.
SND_BUSY                = &0359 ; Sound frame re-entry lock.
W_035A                  = &035A
SND_SFX_BUF             = &035B ; APU image for the SFX layer.
W_035C                  = &035C
W_035D                  = &035D
W_035E                  = &035E
W_035F                  = &035F
W_0360                  = &0360
W_036B                  = &036B
SND_SFX_DIRTY           = &036F ; Dirty flags for the SFX APU image.
W_0370                  = &0370
W_0373                  = &0373
W_0378                  = &0378
W_037C                  = &037C
W_0380                  = &0380
W_0384                  = &0384
W_0388                  = &0388
W_038C                  = &038C
TOP_NAME                = &03C0 ; Eight name tiles. The default is KOSAKA!!.
TOP_SCORE               = &03C8 ; Eight digits of the top score.
SCORE_NOW               = &03D0 ; Eight digits of the current score.
SCORE_NOW_1             = &03D1 ; Digit of SCORE_NOW.
SCORE_NOW_2             = &03D2 ; Digit of SCORE_NOW.
SCORE_NOW_3             = &03D3 ; Digit of SCORE_NOW.
SCORE_NOW_4             = &03D4 ; Digit of SCORE_NOW.
SCORE_NOW_5             = &03D5 ; Digit of SCORE_NOW.
SCORE_NOW_6             = &03D6 ; Digit of SCORE_NOW.
SCORE_NOW_7             = &03D7 ; Digit of SCORE_NOW.
RNG_1                   = &03D8 ; RNG state; demo records overwrite it
RNG_2                   = &03D9 ; RNG state; demo records overwrite it
RNG_3                   = &03DA ; RNG state; NEXT_RNG returns this byte
PASS_CODE               = &03DB ; Nine password bytes. RESET_MARKS fills them with FFh.
PASS_EDIT               = &03E4 ; Nine bytes edited on the password screen.
PASS_EDIT_1             = &03E5 ; Byte 1 of PASS_EDIT. The screen indexes from here.
FUSE_INIT               = &03ED ; Fuse stored into a new bomb. RESET_MARKS writes 4Bh.
PASS_MARK               = &03EE ; Set to 1 or 2 by a password word.
DEMO_MODE               = &03EF ; 0 normal, 1 demo, negative leaves the demo.
DEMO_SLOT               = &03F0 ; Demo record 0-3.
DEMO_POS                = &03F1 ; Index into the demo button record.
DEMO_HOLD               = &03F2 ; Frames left for the current demo buttons.
DEMO_BTN                = &03F3 ; Buttons stored or played by the demo.
DEMO_PREV               = &03F4 ; Previous demo buttons, used to make the edge.
DEMO_EDGE               = &03F5 ; Buttons newly set in the demo playback.
PAL_BUF                 = &0400 ; 32 palette bytes uploaded by NMI
PAL_BG1                 = &0404 ; Background color of palette row 1. Copied from PAL_BUF.
PAL_BG2                 = &0408 ; Background color of palette row 2.
PAL_BG3                 = &040C ; Background color of palette row 3.
PAL_BG4                 = &0410 ; Background color of palette row 4.
PAL_BG5                 = &0414 ; Background color of palette row 5.
PAL_BG6                 = &0418 ; Background color of palette row 6.
PAL_BG7                 = &041C ; Background color of palette row 7.
ATTR_BUF                = &0420 ; 128 cached attribute bytes
SPLIT_SCROLL_X          = &04A0 ; scroll X used while SPLIT_MODE is set
SPLIT_CTRL_BIT          = &04A1 ; ORed into PPU CTRL during a split
SCROLL_X                = &04A2 ; scroll X; sprites subtract it
SCROLL_NT               = &04A3 ; bit 0 is ORed into PPU CTRL
SCROLL_Y                = &04A4 ; scroll Y for normal and split paths
PPU_Q_WR                = &04A5 ; write index of the PPU queue
PPU_Q_RD                = &04A6 ; read index of the PPU queue
PPU_Q_HI                = &04A7 ; nametable high byte of a 2x2 record
PPU_Q_LEFT              = &04A8 ; Bytes or records left while a PPU run is drained.
NT_ADDR_LO              = &04A9 ; Nametable address low built by QUEUE_TILE.
NT_ADDR_HI              = &04AA ; Nametable address high built by QUEUE_TILE.
TILE_COL                = &04AB ; Column passed to QUEUE_MAP_TILE.
TILE_ROW                = &04AC ; Row passed to QUEUE_MAP_TILE.
PPU_WORK                = &04AD ; Attribute address in QUEUE_TILE. Also the size tested by PPU_Q_HAS_ROOM.
ATTR_KEEP               = &04AE ; Attribute bits kept while merging a tile nibble.
ATTR_NEW                = &04AF ; New attribute bits merged into ATTR_BUF.
TILE_PAL                = &04B0 ; Attribute nibble of the queued 2x2 tile.
TILE_CHR0               = &04B1 ; First CHR byte of the queued tile.
TILE_CHR1               = &04B2 ; Second CHR byte of the queued tile.
TILE_CHR2               = &04B3 ; Third CHR byte of the queued tile.
TILE_CHR3               = &04B4 ; Fourth CHR byte of the queued tile.
JOYPAD1                 = &04B5 ; held buttons, pad port 1 bit 0
JOYPAD2                 = &04B6 ; held buttons, pad port 2 bit 0
JOYPAD3                 = &04B7 ; held buttons, pad port 1 bit 1
JOYPAD1_NEW             = &04B8 ; JOYPAD1 bits newly pressed this read
JOYPAD2_NEW             = &04B9 ; JOYPAD2 bits newly pressed this read
JOYPAD3_NEW             = &04BA ; JOYPAD3 bits newly pressed this read
JOYPAD1_OLD             = &04BB ; JOYPAD1 from the previous frame
JOYPAD2_OLD             = &04BC ; JOYPAD2 from the previous frame
JOYPAD3_OLD             = &04BD ; JOYPAD3 from the previous frame
JOYPAD1_2ND             = &04BE ; second sample of JOYPAD1
JOYPAD2_2ND             = &04BF ; second sample of JOYPAD2
JOYPAD3_2ND             = &04C0 ; second sample of JOYPAD3
ACTOR_NEW               = &04C1 ; New buttons for the actor. Demo playback writes this.
ACTOR_HELD              = &04C2 ; Held direction for the actor. Demo playback writes this.
JOY_NEW                 = &04C3 ; OR of the three newly-pressed bytes
JOY_HELD                = &04C4 ; OR of the three held-button bytes
SND_RET_A               = &04C5 ; A returned by the bank-2 sound call
SND_RET_X               = &04C6 ; X returned by the bank-2 sound call
SND_NMI_LOCK            = &04C7 ; 1 while NMI is inside the sound tick
VS_PICTURE              = &04C8 ; 0-2. Picks the vs-result picture and tile group.
START_AREA              = &04C9 ; Copied into AREA_NUM for a new game. Bit 7 jumps to the ending.
W_04CA                  = &04CA
LIVES_SHOWN             = &04CB ; Last lives value drawn on the HUD.
PAUSE_X                 = &04CC ; X returned by AUDIO_CALL when pause starts.
SNDROOM_CUR             = &04CD ; Sound-room cursor, 0-2.
SNDROOM_P0              = &04CE ; First sound-room parameter. Initial bytes are 0C 00 1E.
SNDROOM_P1              = &04CF ; Second sound-room parameter.
SNDROOM_P2              = &04D0 ; Third sound-room parameter.
LAYOUT_ID               = &04D1 ; 16 ids unpacked from one layout strip. The draw uses the first 15.
LAYOUT_VAR              = &04E1 ; 0 or 1 layout variant. Also the horizontal-scroll flag read by S5_8F6E.
SOFT_COUNT              = &04E2 ; Soft blocks still to place, then still hidden. OPEN_BURIED decrements it.
TILESET                 = &04E3 ; Level tile-group index for LEVEL_OBJ_TILES.
POWER_STAGE             = &04E4 ; Area times 8 plus stage when the last power item was taken.
LIVES                   = &04E5 ; Lives. STAGE_BOOT stores 2. A loss decrements it.
POWER_TIME              = &04E6 ; Second timed-item counter, separate from ITEM_KIND.
POWER_FRAME             = &04E7 ; Frame divider for POWER_TIME. One tick is 3Ch frames.
POWER_LEFT              = &04E8 ; Steps left on POWER_TIME.
FLASH_IDX               = &04E9 ; Index into FLASH_DRAW_MASK. SET_ACTOR_FLASH stores 8.
FLASH_ZERO              = &04EA ; SET_ACTOR_FLASH stores 0. No reader found in the source.
BURIED_FLAG             = &04EB ; 15 buried-item flags.
BURIED_COL              = &04FA ; 15 columns for BURIED_FLAG.
W_0500                  = &0500
BURIED_ROW              = &0509 ; 15 rows for BURIED_FLAG.
BURIED_HIT              = &0518 ; Set to 1 when a buried cell has low bits 2.
ROUND_RES               = &051B ; Positive waits 30h frames. Negative low 2 bits pick the round sprite.
ROUND_WAIT              = &051C ; Frame counter for ROUND_RES.
W_051D                  = &051D
TITLE_BLINK             = &051E ; Blink counter for the title START text.
TITLE_IDLE              = &051F ; Low byte of the title idle timer. Starts at 05DCh.
TITLE_IDLE_HI           = &0520 ; High byte of the title idle timer. Zero starts the demo.
TITLE_PHASE             = &0521 ; 1 wait, 2 scroll, 0 done.
TITLE_DELAY             = &0522 ; Delay inside the title phase.
TITLE_ROW               = &0523 ; Title rows already drawn.
TITLE_JOLT              = &0524 ; Shake index on the title screen.
PPU_QUEUE               = &0600 ; 256-byte ring drained by NMI
OAM_Y                   = &0700 ; OAM buffer at 0700h. Sprite Y, indexed by 4.
OAM_TILE                = &0701 ; OAM tile. Sprite 0 uses tile 01h when the split is on.
OAM_ATTR                = &0702 ; OAM attribute byte. The split sprite stores 23h.
OAM_X                   = &0703 ; OAM X byte. The split sprite stores 00h.
OAM_PAGE1               = &0740 ; OAM Y bytes 40h-7Fh. CLEAR_OAM hides this quarter.
OAM_PAGE2               = &0780 ; OAM Y bytes 80h-BFh.
OAM_PAGE3               = &07C0 ; OAM Y bytes C0h-FFh.
FUSE_LOCK               = &6000 ; Nonzero: every bomb fuse stays put.
BOMB_FLAG               = &6001 ; 24 slots. 0 empty, positive is a bomb, negative counts BOMB_REARM then returns to 1.
BOMB_COL                = &6019 ; 24 slots. Bomb column.
BOMB_ROW                = &6031 ; 24 slots. Bomb row.
BOMB_FRAME              = &6049 ; 24 slots. Bomb animation frame.
BOMB_FUSE               = &6061 ; 24 slots. Fuse countdown. Remote bombs with kick 0 do not tick.
BOMB_KICK               = &6079 ; 24 slots. Kick direction. 0 means not kicked.
BOMB_OWNER              = &6091 ; 24 slots. Owner index on the ring.
BOMB_REARM              = &60A9 ; 24 slots. Countdown while BOMB_FLAG is negative.
RING_SLOT               = &60C1 ; 32-byte ring. FREE_RING_SLOT clears the current byte and advances.
RING_INDEX              = &60E1 ; Index into RING_SLOT, modulo 32.
FLAME_FLAG              = &60E2 ; 60 slots. Low nibble is the flame kind. Bit 7 is set when the flame is spawned.
FLAME_COL               = &611E ; 60 slots. Flame column.
FLAME_ROW               = &615A ; 60 slots. Flame row.
FLAME_ANIM              = &6196 ; 60 slots. Animation counter.
FLAME_RADIUS            = &61D2 ; 60 slots. Radius still to draw.
FLAME_OWNER             = &620E ; 60 slots. Actor that owns the flame.
RAY_LEFT                = &624A ; Cells still to walk on the current flame ray.
BLAST_RADIUS            = &624B ; Radius used by SPREAD_FLAME.
BLAST_OWNER             = &624C ; Actor that owns the blast being spread.
BLAST_TOG               = &624D ; Odd frames step bombs, even frames step flames.
BLAST_ANIM_A            = &624E ; Blast animation phase.
BLAST_ANIM_B            = &624F ; Second blast animation phase.
ENEMY_FLAGS             = &6250 ; 10 slots. 0 empty. Bit 3 draws every other frame, bit 4 hides, bit 5 skips the player, bit 6 skips blasts. Bit 7 or a negative byte is death.
ENEMY_TYPE              = &625A ; 10 slots. Index into the AI and draw tables. Death stores 11h and keeps the old type in ENEMY_PHASE.
ENEMY_X                 = &6264 ; 10 slots. Pixel X. A cell is column times 16 plus 8.
ENEMY_X_HI              = &626E ; 10 slots. Pixel X high byte.
ENEMY_Y                 = &6278 ; 10 slots. Pixel Y.
ENEMY_COL               = &6282 ; 10 slots. Column from pixel X divided by 16.
ENEMY_ROW               = &628C ; 10 slots. Row from pixel Y divided by 16.
ENEMY_SCORE             = &6296 ; 10 slots. Blast-chain count plus ENEMY_SCORE_INDEX. Type 11h picks an item sprite from it.
ENEMY_PHASE             = &62A0 ; 10 slots. AI state and script phase. Death uses it as a frame count.
ENEMY_ACC               = &62AA ; 10 slots. Speed accumulator. Death stores 30h.
ENEMY_TIMER             = &62B4 ; 10 slots. Turn or pause counter.
ENEMY_DIR               = &62BE ; 10 slots. 0 up, 1 left, 2 down, 3 right.
ENEMY_SUBT              = &62C8 ; 10 slots. Second timer for scripts and some AI.
ENEMY_SCRIPT            = &62D2 ; 10 slots. Index used by ENEMY_SCRIPT_STEP.
ENEMY_ORDER             = &62DC ; 0 uses draw-order phase 0. Otherwise FRAME_CNT bits 0-1.
ENEMY_REACT             = &62DD ; Bit 0 clear reacts to blasts. Bit 0 set reacts to the player.
ENEMIES_GONE            = &62DE ; 1 when every slot is empty or type 11h.
ENEMY_PLACE             = &62DF ; Type argument for PLACE_ENEMY.
ENEMY_INDEX             = &62E0 ; Slot currently drawn or tested.
ENEMY_SPAWN             = &62E1 ; Type kept while looking for an empty cell.
ENEMY_MASK              = &62E2 ; Map-byte mask. Seen values include 70h, 50h, 40h and F0h.
ENEMY_STEP              = &62E3 ; Step size for ENEMY_MOVE_SPEED.
PARADE_IDX              = &62E6 ; SPAWN_PARADE point index. Wraps at 41h.
TYPE10_TRY              = &62E7 ; Attempt counter for SPAWN_TYPE_10.
TYPE10_ARM              = &62E8 ; ARM_TYPE10_TIMER stores 1 when this is 0.
TYPE10_TIME             = &62E9 ; ARM_TYPE10_TIMER stores F0h here.
BURST_TIME              = &62EB ; Countdown. At 0 the same type is placed eight times.
BURST_COL               = &62EC ; Column stored with BURST_TIME.
BURST_ROW               = &62ED ; Row stored with BURST_TIME.
TYPE4_TIME              = &62EE ; Countdown for a type-4 spawn.
TYPE4_COL               = &62EF ; Column stored with TYPE4_TIME.
TYPE4_ROW               = &62F0 ; Row stored with TYPE4_TIME.
DRAW_PHASE              = &62F1 ; Draw-order phase copied from ENEMY_ORDER_BASE.
SCRIPT_FLAG             = &62F2 ; Script ops 09, 0A and 0B store 1, 0 and 2. Ending scroll runs only when this is 1.
MAP_TMP_A               = &6493 ; Holds the tile index while COPY_LAYOUT_CELL switches banks.
MAP_TMP_X               = &6494 ; Holds the column while COPY_LAYOUT_CELL switches banks.

IF REGION = 0
  JOY_PROBE_1             = &45 ; US extra byte shifted from pad port 1
ELIF REGION = 2
  JOY_PROBE_1             = &45 ; US extra byte shifted from pad port 1
ENDIF

IF REGION = 0
  JOY_PROBE_2             = &46 ; US extra byte shifted from pad port 2
ELIF REGION = 2
  JOY_PROBE_2             = &46 ; US extra byte shifted from pad port 2
ENDIF

IF REGION = 0
  JOY_SIG_OK              = &48 ; US 1 when probe matched 10h and 20h
ENDIF

IF REGION = 0
  GAME_MODE               = &49 ; 0 story, 1 vs, 2 battle. Selects the pre-stage card and enemy update.
ELIF REGION_JP
  GAME_MODE               = &3B ; 0 story, 1 vs, 2 battle. Selects the pre-stage card and enemy update.
ELIF REGION = 2
  GAME_MODE               = &48 ; 0 story, 1 vs, 2 battle. Selects the pre-stage card and enemy update.
ENDIF

IF REGION = 0
  KEEP_STAGE              = &4A ; Nonzero: STAGE_BOOT keeps the current area and stage.
ELIF REGION_JP
  KEEP_STAGE              = &3C ; Nonzero: STAGE_BOOT keeps the current area and stage.
ELIF REGION = 2
  KEEP_STAGE              = &49 ; Nonzero: STAGE_BOOT keeps the current area and stage.
ENDIF

IF REGION = 0
  AREA_NUM                = &4B ; Area 0-5. Area 6 is the ending, not a map.
ELIF REGION_JP
  AREA_NUM                = &3D ; Area 0-5. Area 6 is the ending, not a map.
ELIF REGION = 2
  AREA_NUM                = &4A ; Area 0-5. Area 6 is the ending, not a map.
ENDIF

IF REGION = 0
  STAGE_NUM               = &4C ; Stage 0-7 inside the area.
ELIF REGION_JP
  STAGE_NUM               = &3E ; Stage 0-7 inside the area.
ELIF REGION = 2
  STAGE_NUM               = &4B ; Stage 0-7 inside the area.
ENDIF

IF REGION = 0
  INTRO_AREA              = &4D ; Last area whose intro card has played.
ELIF REGION_JP
  INTRO_AREA              = &3F ; Last area whose intro card has played.
ELIF REGION = 2
  INTRO_AREA              = &4C ; Last area whose intro card has played.
ENDIF

IF REGION = 0
  SPECIAL_STAGE           = &4E ; Nonzero on the bonus stage and for fixed spawns. KILL_PLAYERS then only advances CLEAR_PHASE.
ELIF REGION_JP
  SPECIAL_STAGE           = &40 ; Nonzero on the bonus stage and for fixed spawns. KILL_PLAYERS then only advances CLEAR_PHASE.
ELIF REGION = 2
  SPECIAL_STAGE           = &4D ; Nonzero on the bonus stage and for fixed spawns. KILL_PLAYERS then only advances CLEAR_PHASE.
ENDIF

IF REGION = 0
  BONUS_BOMBS             = &4F ; RUN_BONUS_STAGE saves actor 0 bomb count here.
ELIF REGION_JP
  BONUS_BOMBS             = &41 ; RUN_BONUS_STAGE saves actor 0 bomb count here.
ELIF REGION = 2
  BONUS_BOMBS             = &4E ; RUN_BONUS_STAGE saves actor 0 bomb count here.
ENDIF

IF REGION = 0
  BONUS_FIRE              = &50 ; RUN_BONUS_STAGE saves actor 0 flame length here.
ELIF REGION_JP
  BONUS_FIRE              = &42 ; RUN_BONUS_STAGE saves actor 0 flame length here.
ELIF REGION = 2
  BONUS_FIRE              = &4F ; RUN_BONUS_STAGE saves actor 0 flame length here.
ENDIF

IF REGION = 0
  BONUS_STAGE             = &51 ; RUN_BONUS_STAGE saves STAGE_NUM here.
ELIF REGION_JP
  BONUS_STAGE             = &43 ; RUN_BONUS_STAGE saves STAGE_NUM here.
ELIF REGION = 2
  BONUS_STAGE             = &50 ; RUN_BONUS_STAGE saves STAGE_NUM here.
ENDIF

IF REGION = 0
  BONUS_AREA              = &52 ; RUN_BONUS_STAGE saves AREA_NUM here.
ELIF REGION_JP
  BONUS_AREA              = &44 ; RUN_BONUS_STAGE saves AREA_NUM here.
ELIF REGION = 2
  BONUS_AREA              = &51 ; RUN_BONUS_STAGE saves AREA_NUM here.
ENDIF

IF REGION = 0
  STAGE_PHASE             = &53 ; 0 in play. Counts after a round. F0h exits as a loss or a demo abort.
ELIF REGION_JP
  STAGE_PHASE             = &45 ; 0 in play. Counts after a round. F0h exits as a loss or a demo abort.
ELIF REGION = 2
  STAGE_PHASE             = &52 ; 0 in play. Counts after a round. F0h exits as a loss or a demo abort.
ENDIF

IF REGION = 0
  SPR_PTR                 = &54 ; Metasprite stream for DRAW_METASPRITE.
ELIF REGION_JP
  SPR_PTR                 = &46 ; Metasprite stream for DRAW_METASPRITE.
ELIF REGION = 2
  SPR_PTR                 = &53 ; Metasprite stream for DRAW_METASPRITE.
ENDIF

IF REGION = 0
  SPR_PTR_HI              = &55 ; High byte of SPR_PTR.
ELIF REGION_JP
  SPR_PTR_HI              = &47 ; High byte of SPR_PTR.
ELIF REGION = 2
  SPR_PTR_HI              = &54 ; High byte of SPR_PTR.
ENDIF

IF REGION = 0
  SPR_X                   = &56 ; Metasprite origin X.
ELIF REGION_JP
  SPR_X                   = &48 ; Metasprite origin X.
ELIF REGION = 2
  SPR_X                   = &55 ; Metasprite origin X.
ENDIF

IF REGION = 0
  SPR_X_HI                = &57 ; Metasprite origin X high.
ELIF REGION_JP
  SPR_X_HI                = &49 ; Metasprite origin X high.
ELIF REGION = 2
  SPR_X_HI                = &56 ; Metasprite origin X high.
ENDIF

IF REGION = 0
  SPR_Y                   = &58 ; Metasprite origin Y. DRAW_METASPRITE decrements it first.
ELIF REGION_JP
  SPR_Y                   = &4A ; Metasprite origin Y. DRAW_METASPRITE decrements it first.
ELIF REGION = 2
  SPR_Y                   = &57 ; Metasprite origin Y. DRAW_METASPRITE decrements it first.
ENDIF

IF REGION = 0
  SPR_Y_HI                = &59 ; Metasprite origin Y high.
ELIF REGION_JP
  SPR_Y_HI                = &4B ; Metasprite origin Y high.
ELIF REGION = 2
  SPR_Y_HI                = &58 ; Metasprite origin Y high.
ENDIF

IF REGION = 0
  SPR_FLIP                = &5A ; Flip bits EOR-ed into each sprite attribute. Bit 6 flips X, bit 7 flips Y.
ELIF REGION_JP
  SPR_FLIP                = &4C ; Flip bits EOR-ed into each sprite attribute. Bit 6 flips X, bit 7 flips Y.
ELIF REGION = 2
  SPR_FLIP                = &59 ; Flip bits EOR-ed into each sprite attribute. Bit 6 flips X, bit 7 flips Y.
ENDIF

IF REGION = 0
  SPR_COUNT               = &5B ; Sprites left in the current metasprite.
ELIF REGION_JP
  SPR_COUNT               = &4D ; Sprites left in the current metasprite.
ELIF REGION = 2
  SPR_COUNT               = &5A ; Sprites left in the current metasprite.
ENDIF

IF REGION = 0
  SPR_DX                  = &5C ; Sprite X after the metasprite offset and scroll.
ELIF REGION_JP
  SPR_DX                  = &4E ; Sprite X after the metasprite offset and scroll.
ELIF REGION = 2
  SPR_DX                  = &5B ; Sprite X after the metasprite offset and scroll.
ENDIF

IF REGION = 0
  SPR_DX_HI               = &5D ; High byte of SPR_DX. Nonzero skips the sprite.
ELIF REGION_JP
  SPR_DX_HI               = &4F ; High byte of SPR_DX. Nonzero skips the sprite.
ELIF REGION = 2
  SPR_DX_HI               = &5C ; High byte of SPR_DX. Nonzero skips the sprite.
ENDIF

IF REGION = 0
  SPR_DY                  = &5E ; Sprite Y written to OAM.
ELIF REGION_JP
  SPR_DY                  = &50 ; Sprite Y written to OAM.
ELIF REGION = 2
  SPR_DY                  = &5D ; Sprite Y written to OAM.
ENDIF

IF REGION = 0
  SPR_DY_HI               = &5F ; High byte of SPR_DY.
ELIF REGION_JP
  SPR_DY_HI               = &51 ; High byte of SPR_DY.
ELIF REGION = 2
  SPR_DY_HI               = &5E ; High byte of SPR_DY.
ENDIF

IF REGION = 0
  SPR_TILE                = &60 ; Tile byte written to OAM.
ELIF REGION_JP
  SPR_TILE                = &52 ; Tile byte written to OAM.
ELIF REGION = 2
  SPR_TILE                = &5F ; Tile byte written to OAM.
ENDIF

IF REGION = 0
  SPR_ATTR                = &61 ; Attribute byte written to OAM.
ELIF REGION_JP
  SPR_ATTR                = &53 ; Attribute byte written to OAM.
ELIF REGION = 2
  SPR_ATTR                = &60 ; Attribute byte written to OAM.
ENDIF

IF REGION = 0
  TILE_GFX                = &62 ; Pointer to 4 CHR bytes per tile id. Set from the area layout.
ELIF REGION_JP
  TILE_GFX                = &54 ; Pointer to 4 CHR bytes per tile id. Set from the area layout.
ELIF REGION = 2
  TILE_GFX                = &61 ; Pointer to 4 CHR bytes per tile id. Set from the area layout.
ENDIF

IF REGION = 0
  TILE_GFX_HI             = &63 ; High byte of TILE_GFX.
ELIF REGION_JP
  TILE_GFX_HI             = &55 ; High byte of TILE_GFX.
ELIF REGION = 2
  TILE_GFX_HI             = &62 ; High byte of TILE_GFX.
ENDIF

IF REGION = 0
  TILE_MAP                = &64 ; Pointer to map-byte values per tile id.
ELIF REGION_JP
  TILE_MAP                = &56 ; Pointer to map-byte values per tile id.
ELIF REGION = 2
  TILE_MAP                = &63 ; Pointer to map-byte values per tile id.
ENDIF

IF REGION = 0
  TILE_MAP_HI             = &65 ; High byte of TILE_MAP.
ELIF REGION_JP
  TILE_MAP_HI             = &57 ; High byte of TILE_MAP.
ELIF REGION = 2
  TILE_MAP_HI             = &64 ; High byte of TILE_MAP.
ENDIF

IF REGION = 0
  TILE_ATTR               = &66 ; Pointer to attribute nibbles per tile id.
ELIF REGION_JP
  TILE_ATTR               = &58 ; Pointer to attribute nibbles per tile id.
ELIF REGION = 2
  TILE_ATTR               = &65 ; Pointer to attribute nibbles per tile id.
ENDIF

IF REGION = 0
  TILE_ATTR_HI            = &67 ; High byte of TILE_ATTR.
ELIF REGION_JP
  TILE_ATTR_HI            = &59 ; High byte of TILE_ATTR.
ELIF REGION = 2
  TILE_ATTR_HI            = &66 ; High byte of TILE_ATTR.
ENDIF

IF REGION = 0
  ACTOR_INDEX             = &68 ; Actor slot 0-2 being updated.
ELIF REGION_JP
  ACTOR_INDEX             = &5A ; Actor slot 0-2 being updated.
ELIF REGION = 2
  ACTOR_INDEX             = &67 ; Actor slot 0-2 being updated.
ENDIF

IF REGION = 0
  ACTOR_FLAG              = &69 ; 3 bytes. Nonzero if that actor is active. Bit 6 flashes the sprite.
ELIF REGION_JP
  ACTOR_FLAG              = &5B ; 3 bytes. Nonzero if that actor is active. Bit 6 flashes the sprite.
ELIF REGION = 2
  ACTOR_FLAG              = &68 ; 3 bytes. Nonzero if that actor is active. Bit 6 flashes the sprite.
ENDIF

IF REGION = 0
  ACTOR_COL               = &6C ; 3 bytes. Map column of each actor.
ELIF REGION_JP
  ACTOR_COL               = &5E ; 3 bytes. Map column of each actor.
ELIF REGION = 2
  ACTOR_COL               = &6B ; 3 bytes. Map column of each actor.
ENDIF

IF REGION = 0
  ACTOR_ROW               = &6F ; 3 bytes. Map row of each actor.
ELIF REGION_JP
  ACTOR_ROW               = &61 ; 3 bytes. Map row of each actor.
ELIF REGION = 2
  ACTOR_ROW               = &6E ; 3 bytes. Map row of each actor.
ENDIF

IF REGION = 0
  ACTOR_X                 = &72 ; 3 bytes. Pixel X of each actor.
ELIF REGION_JP
  ACTOR_X                 = &64 ; 3 bytes. Pixel X of each actor.
ELIF REGION = 2
  ACTOR_X                 = &71 ; 3 bytes. Pixel X of each actor.
ENDIF

IF REGION = 0
  ACTOR_XSUB              = &75 ; 3 bytes. X subpixel. INIT_PLAYERS stores 0.
ELIF REGION_JP
  ACTOR_XSUB              = &67 ; 3 bytes. X subpixel. INIT_PLAYERS stores 0.
ELIF REGION = 2
  ACTOR_XSUB              = &74 ; 3 bytes. X subpixel. INIT_PLAYERS stores 0.
ENDIF

IF REGION = 0
  ACTOR_Y                 = &78 ; 3 bytes. Pixel Y of each actor.
ELIF REGION_JP
  ACTOR_Y                 = &6A ; 3 bytes. Pixel Y of each actor.
ELIF REGION = 2
  ACTOR_Y                 = &77 ; 3 bytes. Pixel Y of each actor.
ENDIF

IF REGION = 0
  ACTOR_DIR               = &7B ; 3 bytes. Facing 0-3.
ELIF REGION_JP
  ACTOR_DIR               = &6D ; 3 bytes. Facing 0-3.
ELIF REGION = 2
  ACTOR_DIR               = &7A ; 3 bytes. Facing 0-3.
ENDIF

IF REGION = 0
  ACTOR_FRAME             = &7E ; 3 bytes. Walk frame.
ELIF REGION_JP
  ACTOR_FRAME             = &70 ; 3 bytes. Walk frame.
ELIF REGION = 2
  ACTOR_FRAME             = &7D ; 3 bytes. Walk frame.
ENDIF

IF REGION = 0
  ACTOR_FTIMER            = &81 ; 3 bytes. Frame timer.
ELIF REGION_JP
  ACTOR_FTIMER            = &73 ; 3 bytes. Frame timer.
ELIF REGION = 2
  ACTOR_FTIMER            = &80 ; 3 bytes. Frame timer.
ENDIF

IF REGION = 0
  ACTOR_DEATH             = &84 ; 3 bytes. Nonzero while the death animation runs.
ELIF REGION_JP
  ACTOR_DEATH             = &76 ; 3 bytes. Nonzero while the death animation runs.
ELIF REGION = 2
  ACTOR_DEATH             = &83 ; 3 bytes. Nonzero while the death animation runs.
ENDIF

IF REGION = 0
  ACTOR_TIMED             = &87 ; 3 bytes. Bit 7 is a timed state. Low 2 bits pick A6_TIME_TAB.
ELIF REGION_JP
  ACTOR_TIMED             = &79 ; 3 bytes. Bit 7 is a timed state. Low 2 bits pick A6_TIME_TAB.
ELIF REGION = 2
  ACTOR_TIMED             = &86 ; 3 bytes. Bit 7 is a timed state. Low 2 bits pick A6_TIME_TAB.
ENDIF

IF REGION = 0
  ACTOR_TFRAME            = &8A ; 3 bytes. Timed-state frame count.
ELIF REGION_JP
  ACTOR_TFRAME            = &7C ; 3 bytes. Timed-state frame count.
ELIF REGION = 2
  ACTOR_TFRAME            = &89 ; 3 bytes. Timed-state frame count.
ENDIF

IF REGION = 0
  ACTOR_TSTEP             = &8D ; 3 bytes. Timed-state steps left.
ELIF REGION_JP
  ACTOR_TSTEP             = &7F ; 3 bytes. Timed-state steps left.
ELIF REGION = 2
  ACTOR_TSTEP             = &8C ; 3 bytes. Timed-state steps left.
ENDIF

IF REGION = 0
  ACTOR_BOMBS             = &90 ; 3 bytes. Bombs at a time minus 1, max 7 (ALLOC_BOMB_SLOT). Demo records and the mode table also write slot 0.
ELIF REGION_JP
  ACTOR_BOMBS             = &82 ; 3 bytes. Bombs at a time minus 1, max 7 (ALLOC_BOMB_SLOT). Demo records and the mode table also write slot 0.
ELIF REGION = 2
  ACTOR_BOMBS             = &8F ; 3 bytes. Bombs at a time minus 1, max 7 (ALLOC_BOMB_SLOT). Demo records and the mode table also write slot 0.
ENDIF

IF REGION = 0
  ACTOR_FIRE              = &93 ; 3 bytes. Flame length minus 1, max 4 (BLAST_RADIUS in DETONATE_BOMB).
ELIF REGION_JP
  ACTOR_FIRE              = &85 ; 3 bytes. Flame length minus 1, max 4 (BLAST_RADIUS in DETONATE_BOMB).
ELIF REGION = 2
  ACTOR_FIRE              = &92 ; 3 bytes. Flame length minus 1, max 4 (BLAST_RADIUS in DETONATE_BOMB).
ENDIF

IF REGION = 0
  ACTOR_SPDLO             = &96 ; 3 bytes. Speed accumulator low.
ELIF REGION_JP
  ACTOR_SPDLO             = &88 ; 3 bytes. Speed accumulator low.
ELIF REGION = 2
  ACTOR_SPDLO             = &95 ; 3 bytes. Speed accumulator low.
ENDIF

IF REGION = 0
  ACTOR_SPDHI             = &99 ; 3 bytes. Speed accumulator high.
ELIF REGION_JP
  ACTOR_SPDHI             = &8B ; 3 bytes. Speed accumulator high.
ELIF REGION = 2
  ACTOR_SPDHI             = &98 ; 3 bytes. Speed accumulator high.
ENDIF

IF REGION = 0
  ACT_W_FLAG              = &9C ; Work copy of ACTOR_FLAG for ACTOR_INDEX.
ELIF REGION_JP
  ACT_W_FLAG              = &8E ; Work copy of ACTOR_FLAG for ACTOR_INDEX.
ELIF REGION = 2
  ACT_W_FLAG              = &9B ; Work copy of ACTOR_FLAG for ACTOR_INDEX.
ENDIF

IF REGION = 0
  ACT_W_COL               = &9D ; Work copy of the actor column.
ELIF REGION_JP
  ACT_W_COL               = &8F ; Work copy of the actor column.
ELIF REGION = 2
  ACT_W_COL               = &9C ; Work copy of the actor column.
ENDIF

IF REGION = 0
  ACT_W_ROW               = &9E ; Work copy of the actor row.
ELIF REGION_JP
  ACT_W_ROW               = &90 ; Work copy of the actor row.
ELIF REGION = 2
  ACT_W_ROW               = &9D ; Work copy of the actor row.
ENDIF

IF REGION = 0
  ACT_W_X                 = &9F ; Work copy of pixel X.
ELIF REGION_JP
  ACT_W_X                 = &91 ; Work copy of pixel X.
ELIF REGION = 2
  ACT_W_X                 = &9E ; Work copy of pixel X.
ENDIF

IF REGION = 0
  ACT_W_XSUB              = &A0 ; Work copy of the X subpixel.
ELIF REGION_JP
  ACT_W_XSUB              = &92 ; Work copy of the X subpixel.
ELIF REGION = 2
  ACT_W_XSUB              = &9F ; Work copy of the X subpixel.
ENDIF

IF REGION = 0
  ACT_W_Y                 = &A1 ; Work copy of pixel Y.
ELIF REGION_JP
  ACT_W_Y                 = &93 ; Work copy of pixel Y.
ELIF REGION = 2
  ACT_W_Y                 = &A0 ; Work copy of pixel Y.
ENDIF

IF REGION = 0
  ACT_W_DIR               = &A2 ; Work copy of facing.
ELIF REGION_JP
  ACT_W_DIR               = &94 ; Work copy of facing.
ELIF REGION = 2
  ACT_W_DIR               = &A1 ; Work copy of facing.
ENDIF

IF REGION = 0
  ACT_W_FRAME             = &A3 ; Work copy of the walk frame.
ELIF REGION_JP
  ACT_W_FRAME             = &95 ; Work copy of the walk frame.
ELIF REGION = 2
  ACT_W_FRAME             = &A2 ; Work copy of the walk frame.
ENDIF

IF REGION = 0
  ACT_W_FTMR              = &A4 ; Work copy of the frame timer.
ELIF REGION_JP
  ACT_W_FTMR              = &96 ; Work copy of the frame timer.
ELIF REGION = 2
  ACT_W_FTMR              = &A3 ; Work copy of the frame timer.
ENDIF

IF REGION = 0
  ACT_W_DEATH             = &A5 ; Work copy of the death flag.
ELIF REGION_JP
  ACT_W_DEATH             = &97 ; Work copy of the death flag.
ELIF REGION = 2
  ACT_W_DEATH             = &A4 ; Work copy of the death flag.
ENDIF

IF REGION = 0
  ACT_W_TIMED             = &A6 ; Work copy of ACTOR_TIMED.
ELIF REGION_JP
  ACT_W_TIMED             = &98 ; Work copy of ACTOR_TIMED.
ELIF REGION = 2
  ACT_W_TIMED             = &A5 ; Work copy of ACTOR_TIMED.
ENDIF

IF REGION = 0
  ACT_W_TFR               = &A7 ; Work copy of the timed frame count.
ELIF REGION_JP
  ACT_W_TFR               = &99 ; Work copy of the timed frame count.
ELIF REGION = 2
  ACT_W_TFR               = &A6 ; Work copy of the timed frame count.
ENDIF

IF REGION = 0
  ACT_W_TSTEP             = &A8 ; Work copy of timed steps left.
ELIF REGION_JP
  ACT_W_TSTEP             = &9A ; Work copy of timed steps left.
ELIF REGION = 2
  ACT_W_TSTEP             = &A7 ; Work copy of timed steps left.
ENDIF

IF REGION = 0
  ACT_W_BOMBS             = &A9 ; Work copy of the bomb count.
ELIF REGION_JP
  ACT_W_BOMBS             = &9B ; Work copy of the bomb count.
ELIF REGION = 2
  ACT_W_BOMBS             = &A8 ; Work copy of the bomb count.
ENDIF

IF REGION = 0
  ACT_W_FIRE              = &AA ; Work copy of the flame length.
ELIF REGION_JP
  ACT_W_FIRE              = &9C ; Work copy of the flame length.
ELIF REGION = 2
  ACT_W_FIRE              = &A9 ; Work copy of the flame length.
ENDIF

IF REGION = 0
  ACT_W_SPDLO             = &AB ; Work copy of speed low.
ELIF REGION_JP
  ACT_W_SPDLO             = &9D ; Work copy of speed low.
ELIF REGION = 2
  ACT_W_SPDLO             = &AA ; Work copy of speed low.
ENDIF

IF REGION = 0
  ACT_W_SPDHI             = &AC ; Work copy of speed high.
ELIF REGION_JP
  ACT_W_SPDHI             = &9E ; Work copy of speed high.
ELIF REGION = 2
  ACT_W_SPDHI             = &AB ; Work copy of speed high.
ENDIF

IF REGION = 0
  ACT_PASSWALL            = &AD ; Nonzero: the actor walks through soft blocks (map bit 5, CELL_BLOCKS_MOVE).
ELIF REGION_JP
  ACT_PASSWALL            = &9F ; Nonzero: the actor walks through soft blocks (map bit 5, CELL_BLOCKS_MOVE).
ELIF REGION = 2
  ACT_PASSWALL            = &AC ; Nonzero: the actor walks through soft blocks (map bit 5, CELL_BLOCKS_MOVE).
ENDIF

IF REGION = 0
  ACT_PASSBOMB            = &AE ; Nonzero: the actor walks through bombs (map bit 4, CELL_BLOCKS_MOVE).
ELIF REGION_JP
  ACT_PASSBOMB            = &A0 ; Nonzero: the actor walks through bombs (map bit 4, CELL_BLOCKS_MOVE).
ELIF REGION = 2
  ACT_PASSBOMB            = &AD ; Nonzero: the actor walks through bombs (map bit 4, CELL_BLOCKS_MOVE).
ENDIF

IF REGION = 0
  ACT_REMOTE              = &AF ; 1: B detonates. Bombs with kick 0 do not count down.
ELIF REGION_JP
  ACT_REMOTE              = &A1 ; 1: B detonates. Bombs with kick 0 do not count down.
ELIF REGION = 2
  ACT_REMOTE              = &AE ; 1: B detonates. Bombs with kick 0 do not count down.
ENDIF

IF REGION = 0
  ITEM_KIND               = &B0 ; Kind of the active timed item.
ELIF REGION_JP
  ITEM_KIND               = &A2 ; Kind of the active timed item.
ELIF REGION = 2
  ITEM_KIND               = &AF ; Kind of the active timed item.
ENDIF

IF REGION = 0
  ITEM_FRAME              = &B1 ; Frame counter for ITEM_KIND.
ELIF REGION_JP
  ITEM_FRAME              = &A3 ; Frame counter for ITEM_KIND.
ELIF REGION = 2
  ITEM_FRAME              = &B0 ; Frame counter for ITEM_KIND.
ENDIF

IF REGION = 0
  ITEM_LEFT               = &B2 ; Steps left for ITEM_KIND.
ELIF REGION_JP
  ITEM_LEFT               = &A4 ; Steps left for ITEM_KIND.
ELIF REGION = 2
  ITEM_LEFT               = &B1 ; Steps left for ITEM_KIND.
ENDIF

IF REGION = 0
  ACT_SPEED               = &B3 ; Speed gear.
ELIF REGION_JP
  ACT_SPEED               = &A5 ; Speed gear.
ELIF REGION = 2
  ACT_SPEED               = &B2 ; Speed gear.
ENDIF

IF REGION = 0
  EXIT_OPEN               = &B4 ; Nonzero after the exit item. PREP_STAGE_B4 then calls RUN_BONUS_STAGE.
ELIF REGION_JP
  EXIT_OPEN               = &A6 ; Nonzero after the exit item. PREP_STAGE_B4 then calls RUN_BONUS_STAGE.
ELIF REGION = 2
  EXIT_OPEN               = &B3 ; Nonzero after the exit item. PREP_STAGE_B4 then calls RUN_BONUS_STAGE.
ENDIF

IF REGION = 0
  KNOCK_DIR               = &B5 ; Negative while in knockback. Low 2 bits are the direction.
ELIF REGION_JP
  KNOCK_DIR               = &A7 ; Negative while in knockback. Low 2 bits are the direction.
ELIF REGION = 2
  KNOCK_DIR               = &B4 ; Negative while in knockback. Low 2 bits are the direction.
ENDIF

IF REGION = 0
  KNOCK_LEFT              = &B6 ; Knockback steps remaining.
ELIF REGION_JP
  KNOCK_LEFT              = &A8 ; Knockback steps remaining.
ELIF REGION = 2
  KNOCK_LEFT              = &B5 ; Knockback steps remaining.
ENDIF

IF REGION = 0
  CLEAR_PHASE             = &B7 ; Nonzero while a stage is ending. STAGE_LOOP leaves at F0h.
ELIF REGION_JP
  CLEAR_PHASE             = &A9 ; Nonzero while a stage is ending. STAGE_LOOP leaves at F0h.
ELIF REGION = 2
  CLEAR_PHASE             = &B6 ; Nonzero while a stage is ending. STAGE_LOOP leaves at F0h.
ENDIF

IF REGION = 0
  FLAME_DIR               = &B8 ; Four direction bits for SPREAD_FLAME.
ELIF REGION_JP
  FLAME_DIR               = &AA ; Four direction bits for SPREAD_FLAME.
ELIF REGION = 2
  FLAME_DIR               = &B7 ; Four direction bits for SPREAD_FLAME.
ENDIF

IF REGION = 0
  DEMO_PTR                = &B9 ; Pointer to the demo pad record selected by DEMO_SLOT.
ELIF REGION_JP
  DEMO_PTR                = &AB ; Pointer to the demo pad record selected by DEMO_SLOT.
ELIF REGION = 2
  DEMO_PTR                = &B8 ; Pointer to the demo pad record selected by DEMO_SLOT.
ENDIF

IF REGION = 0
  DEMO_PTR_HI             = &BA ; High byte of DEMO_PTR.
ELIF REGION_JP
  DEMO_PTR_HI             = &AC ; High byte of DEMO_PTR.
ELIF REGION = 2
  DEMO_PTR_HI             = &B9 ; High byte of DEMO_PTR.
ENDIF

IF REGION = 0
  TITLE_SPR0              = &0525 ; Title actor frame.
ELIF REGION_JP
  TITLE_SPR0              = &0525 ; Title actor frame.
ENDIF

IF REGION = 0
  TITLE_SPR1              = &0526 ; Second title actor frame.
ELIF REGION_JP
  TITLE_SPR1              = &0526 ; Second title actor frame.
ENDIF

IF REGION = 0
  NT_SAVE_COL             = &0527 ; Column saved by the US SET_NAMETABLE_XY.
ENDIF

IF REGION = 0
  NT_SAVE_ROW             = &0528 ; Row saved by the US SET_NAMETABLE_XY.
ENDIF

IF REGION = 0
  W_052A                  = &052A
ELIF REGION_JP
  W_052A                  = &0528
ELIF REGION = 2
  W_052A                  = &0528
ENDIF

IF REGION = 0
  W_052B                  = &052B
ELIF REGION_JP
  W_052B                  = &0529
ELIF REGION = 2
  W_052B                  = &0529
ENDIF

IF REGION = 0
  W_052C                  = &052C
ELIF REGION_JP
  W_052C                  = &052A
ELIF REGION = 2
  W_052C                  = &052A
ENDIF

IF REGION = 0
  W_052D                  = &052D
ELIF REGION_JP
  W_052D                  = &052B
ELIF REGION = 2
  W_052D                  = &052B
ENDIF

IF REGION = 0
  W_052E                  = &052E
ELIF REGION_JP
  W_052E                  = &052C
ELIF REGION = 2
  W_052E                  = &052C
ENDIF

IF REGION = 0
  INTRO_FRAME             = &0532 ; Area-intro frame. Only area 5 steps it with AREA5_FRAME_DLY.
ELIF REGION_JP
  INTRO_FRAME             = &0530 ; Area-intro frame. Only area 5 steps it with AREA5_FRAME_DLY.
ELIF REGION = 2
  INTRO_FRAME             = &0530 ; Area-intro frame. Only area 5 steps it with AREA5_FRAME_DLY.
ENDIF

IF REGION = 0
  W_0533                  = &0533
ELIF REGION_JP
  W_0533                  = &0531
ELIF REGION = 2
  W_0533                  = &0531
ENDIF

IF REGION = 0
  W_0534                  = &0534
ELIF REGION_JP
  W_0534                  = &0532
ELIF REGION = 2
  W_0534                  = &0532
ENDIF

IF REGION = 0
  W_0535                  = &0535
ELIF REGION_JP
  W_0535                  = &0533
ELIF REGION = 2
  W_0535                  = &0533
ENDIF

IF REGION = 0
  CREDITS_MODE            = &0536 ; 1 scrolling, 2 waiting at the end, 0 finished.
ELIF REGION_JP
  CREDITS_MODE            = &0534 ; 1 scrolling, 2 waiting at the end, 0 finished.
ELIF REGION = 2
  CREDITS_MODE            = &0534 ; 1 scrolling, 2 waiting at the end, 0 finished.
ENDIF

IF REGION = 0
  CREDITS_TICK            = &0537 ; Credits scroll counter.
ELIF REGION_JP
  CREDITS_TICK            = &0535 ; Credits scroll counter.
ELIF REGION = 2
  CREDITS_TICK            = &0535 ; Credits scroll counter.
ENDIF

IF REGION = 0
  CREDITS_ROW             = &0538 ; Credits line number.
ELIF REGION_JP
  CREDITS_ROW             = &0536 ; Credits line number.
ELIF REGION = 2
  CREDITS_ROW             = &0536 ; Credits line number.
ENDIF

IF REGION = 0
  W_053A                  = &053A
ELIF REGION_JP
  W_053A                  = &0538
ELIF REGION = 2
  W_053A                  = &0538
ENDIF

IF REGION = 0
  PASS_DEC                = &0542 ; Decode buffer for a password.
ELIF REGION_JP
  PASS_DEC                = &0540 ; Decode buffer for a password.
ELIF REGION = 2
  PASS_DEC                = &0540 ; Decode buffer for a password.
ENDIF

IF REGION = 0
  W_0543                  = &0543
ELIF REGION_JP
  W_0543                  = &0541
ELIF REGION = 2
  W_0543                  = &0541
ENDIF

IF REGION = 0
  W_0544                  = &0544
ELIF REGION_JP
  W_0544                  = &0542
ELIF REGION = 2
  W_0544                  = &0542
ENDIF

IF REGION = 0
  W_0545                  = &0545
ELIF REGION_JP
  W_0545                  = &0543
ELIF REGION = 2
  W_0545                  = &0543
ENDIF

IF REGION = 0
  W_0546                  = &0546
ELIF REGION_JP
  W_0546                  = &0544
ELIF REGION = 2
  W_0546                  = &0544
ENDIF

IF REGION = 0
  W_0547                  = &0547
ELIF REGION_JP
  W_0547                  = &0545
ELIF REGION = 2
  W_0547                  = &0545
ENDIF

IF REGION = 0
  W_0548                  = &0548
ELIF REGION_JP
  W_0548                  = &0546
ELIF REGION = 2
  W_0548                  = &0546
ENDIF

IF REGION = 0
  W_0549                  = &0549
ELIF REGION_JP
  W_0549                  = &0547
ELIF REGION = 2
  W_0549                  = &0547
ENDIF

IF REGION = 0
  W_054A                  = &054A
ELIF REGION_JP
  W_054A                  = &0548
ELIF REGION = 2
  W_054A                  = &0548
ENDIF

IF REGION = 0
  W_054B                  = &054B
ELIF REGION_JP
  W_054B                  = &0549
ELIF REGION = 2
  W_054B                  = &0549
ENDIF

IF REGION = 0
  W_054C                  = &054C
ELIF REGION_JP
  W_054C                  = &054A
ELIF REGION = 2
  W_054C                  = &054A
ENDIF

IF REGION = 0
  W_054D                  = &054D
ELIF REGION_JP
  W_054D                  = &054B
ELIF REGION = 2
  W_054D                  = &054B
ENDIF

IF REGION = 0
  MENU_REDRAW             = &054E ; Nonzero redraws the front menu.
ELIF REGION_JP
  MENU_REDRAW             = &054C ; Nonzero redraws the front menu.
ELIF REGION = 2
  MENU_REDRAW             = &054C ; Nonzero redraws the front menu.
ENDIF

IF REGION = 0
  MENU_MODE1              = &054F ; Nonzero enters the mode-1 menu and does not return.
ELIF REGION_JP
  MENU_MODE1              = &054D ; Nonzero enters the mode-1 menu and does not return.
ELIF REGION = 2
  MENU_MODE1              = &054D ; Nonzero enters the mode-1 menu and does not return.
ENDIF

IF REGION = 0
  MENU_BONUS              = &0550 ; Nonzero sets lives to 1 and runs the bonus stage.
ELIF REGION_JP
  MENU_BONUS              = &054E ; Nonzero sets lives to 1 and runs the bonus stage.
ELIF REGION = 2
  MENU_BONUS              = &054E ; Nonzero sets lives to 1 and runs the bonus stage.
ENDIF

IF REGION = 0
  PASS_EDGES              = &0551 ; Bits from POLL_PASS_KEYS. Bit 7 is A, then B, Select, Start, up, down, left, right.
ELIF REGION_JP
  PASS_EDGES              = &054F ; Bits from POLL_PASS_KEYS. Bit 7 is A, then B, Select, Start, up, down, left, right.
ELIF REGION = 2
  PASS_EDGES              = &054F ; Bits from POLL_PASS_KEYS. Bit 7 is A, then B, Select, Start, up, down, left, right.
ENDIF

IF REGION = 0
  PASS_REPEAT             = &0552 ; Eight key-repeat timers for the password screen.
ELIF REGION_JP
  PASS_REPEAT             = &0550 ; Eight key-repeat timers for the password screen.
ELIF REGION = 2
  PASS_REPEAT             = &0550 ; Eight key-repeat timers for the password screen.
ENDIF

IF REGION = 0
  CLOCK_FRAME             = &055A ; Stage-clock frame countdown from 3Ch. Negative stops the clock and picks the other round sprite.
ELIF REGION_JP
  CLOCK_FRAME             = &0558 ; Stage-clock frame countdown from 3Ch. Negative stops the clock and picks the other round sprite.
ELIF REGION = 2
  CLOCK_FRAME             = &0558 ; Stage-clock frame countdown from 3Ch. Negative stops the clock and picks the other round sprite.
ENDIF

IF REGION = 0
  W_055B                  = &055B
ELIF REGION_JP
  W_055B                  = &0559
ELIF REGION = 2
  W_055B                  = &0559
ENDIF

IF REGION = 0
  CLOCK_DIG1              = &055C ; First stage-clock digit from the time table.
ELIF REGION_JP
  CLOCK_DIG1              = &055A ; First stage-clock digit from the time table.
ELIF REGION = 2
  CLOCK_DIG1              = &055A ; First stage-clock digit from the time table.
ENDIF

IF REGION = 0
  CLOCK_DIG2              = &055D ; Second stage-clock digit from the time table.
ELIF REGION_JP
  CLOCK_DIG2              = &055B ; Second stage-clock digit from the time table.
ELIF REGION = 2
  CLOCK_DIG2              = &055B ; Second stage-clock digit from the time table.
ENDIF

IF REGION = 0
  MATCH_0                 = &055E ; First card counter. The loss path compares it with WINS_GOAL.
ELIF REGION_JP
  MATCH_0                 = &055C ; First card counter. The loss path compares it with WINS_GOAL.
ELIF REGION = 2
  MATCH_0                 = &055C ; First card counter. The loss path compares it with WINS_GOAL.
ENDIF

IF REGION = 0
  MATCH_1                 = &055F ; Second card counter.
ELIF REGION_JP
  MATCH_1                 = &055D ; Second card counter.
ELIF REGION = 2
  MATCH_1                 = &055D ; Second card counter.
ENDIF

IF REGION = 0
  MATCH_2                 = &0560 ; Third card counter. The battle card draws all three.
ELIF REGION_JP
  MATCH_2                 = &055E ; Third card counter. The battle card draws all three.
ELIF REGION = 2
  MATCH_2                 = &055E ; Third card counter. The battle card draws all three.
ENDIF

IF REGION = 0
  W_0561                  = &0561
ELIF REGION_JP
  W_0561                  = &055F
ELIF REGION = 2
  W_0561                  = &055F
ENDIF

IF REGION = 0
  W_0562                  = &0562
ELIF REGION_JP
  W_0562                  = &0560
ELIF REGION = 2
  W_0562                  = &0560
ENDIF

IF REGION = 0
  WINS_GOAL               = &0563 ; Wins required. 5 unless battle mode picked 1-5.
ELIF REGION_JP
  WINS_GOAL               = &0561 ; Wins required. 5 unless battle mode picked 1-5.
ELIF REGION = 2
  WINS_GOAL               = &0561 ; Wins required. 5 unless battle mode picked 1-5.
ENDIF

IF REGION = 0
  X_62E4                  = &62E4
ELIF REGION_JP
  X_62E4                  = &62E4
ENDIF

IF REGION = 0
  X_62E5                  = &62E5
ELIF REGION_JP
  X_62E5                  = &62E5
ENDIF

IF REGION = 0
  X_62EA                  = &62EA
ELIF REGION_JP
  X_62EA                  = &62EA
ENDIF

MMC1_CONTROL            = &9FFF
MMC1_CHR0               = &BFFF
MMC1_CHR1               = &DFFF
MMC1_PRG                = &FFFF
