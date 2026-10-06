# T09-jp 日美版差异

## 概述

`bank*.asm` 里大约 177 个 `IF REGION_JP` 块。对照两边字节后，差异可以收成下面几类。美版是在日版内容上改过的那一版：英文界面、密码用数字、版权年份、手柄探测，以及因此挪动的表地址。

1. **图块和文字。** 界面元精灵、密码图块、开场图、标题、职员表、ROM 末尾标题串。
2. **常量。** 同一段 PPU 上传，源地址低字节不同（`28`/`2A`、`38`/`3A`）。版权年份一个字节。
3. **逻辑。** 手柄读取、标题流程、模式菜单、密码图块表、声音室字符串、关卡名表绘制。
4. **地址跟着表长走。** 敌人帧表、出生表、职员表行指针、关卡布局 B 指针。`jpmap.tsv` 能对上的，注释里写了映射。

## 已命名

日版独有标签用 `jp:b:XXXX` 命名。依据是绘制例程和指针表里的引用。

- `JP_WALK_01`、`JP_WALK_05`、`JP_WALK_06`、`JP_WALK_08` 到 `JP_WALK_15`：`DRAW_ENEMY_*` 和 `ENEMY_WALK_PTR_LIST` 的日版目标。美版对应 `ENEMY_WALK_*`。
- `JP_DEATH_0` 到 `JP_DEATH_4`：`ENEMY_DEATH_FRAMES` 的五帧。美版是 `D0_9D2A` 到 `D0_9D6E`。
- `JP_SPAWN_0`、`JP_SPAWN_2` 到 `JP_SPAWN_5`：`AREA_SPAWN_PTRS` 的日版表。美版从 `D0_AD7E` 起。
- `JP_SPR_*`：只在日版贴出来的元精灵或帧字。美版同一槽位用了别的标签。
- `JP_PASS_GLYPHS`：16 个密码图块，顺序 `50 43 4B 4E 46 4F 48 49 47 45 42 41 44 4A 4C 4D`。美版屏幕用 `PASS_GLYPHS`，暗语仍用 `PASS_GLYPH_US`，顺序和日版这张表一样。
- `JP_SND_ROOM_TEXT`：`DRAW_SND_ROOM_TEXT` 的日版字符串。美版是 `D5_A15E`。
- `JP_TITLE_Q1` 到 `JP_TITLE_Q4`：日版标题上传后面的 `28 19 08 19`。美版改画 `TITLE_NT_RLE_2`。
- `JP_TITLE_DY`：标题抖动的第二张字节表。美版是 `D5_A586`。
- `JP_INTRO_LO`、`JP_INTRO_NEXT`：过场元精灵指针的低字节。美版是 `D5_AEC4`、`D5_AEC6`。

每个差异块都在它前面的共享标签上写了 `JP: ... / US: ...`。同一标签下面有多处字节差时，合成一条注释。

能从相邻的 `COPYRIGHT` 文本定下编码：`40` 是空格，`41` 是 A，`31` 是 1。据此：

- 职员表 `D0_B463`：日版 `PCDEFGAB`，美版 `K3456712`。
- `D0_B497`：日版 `1991`，美版 `1992`。
- `$FFE0`：日版 `BOMBER MAN 2` 加空格再加 `04 F8`；美版 `BOMBERMAN 2` 加 ASCII `92817` 再加 `A7 94`。

其它已经对过的修改：

- 美版 `READ_JOYPADS` 先探测 `10h/20h`，命中走 `READ_JOY_ALT` 并置 `JOY_SIG_OK`。日版直接 `LDA #01` 进入 `READ_JOY_STD`，并在同一段里合成 `_NEW`。
- 美版模式菜单在 `GAME_MODE` 将要写成 `02` 且 `JOY_SIG_OK` 为 0 时，播声音 `04` 并继续等。
- 美版 `UI_META_GFX` 多了英文图块（`65 6A 5E 7A ...`），日版这 8 字节是 0。卡片绘制因此绑定 `UI_META_MAP` 或 `UI_META_MAP_JP`。
- 美版密码图多了 `31`–`38` 数字图块。日版保留 `41`、`45`、`49`、`4C`–`50`。
- 开场图 `OPENING_LAYOUT` 里一串图块号，日版比美版大 1，日版还多一个 `39`。
- 密码画面两个图块：日版 `14`、`15`，美版 `28`、`29`。
- `DRAW_NAMETABLE_RLE_2`：日版从列 0 上传；美版从列 `20h` 上传，并另有 `DRAW_NAMETABLE_RLE_1` 从列 0 上传。属性起点日版固定 `0,0`，美版用 `NT_SAVE_COL`/`NT_SAVE_ROW`。
- 关卡布局指针里日版的 `A108`、`A1BA`、`A22D` 就是美版的 `AREA1_LAYOUT_B`、`AREA2_LAYOUT_B`、`AREA3_LAYOUT_B`（`jpmap`：`4:A108`、`4:A1BA`、`4:A22D`）。
- 职员表行指针基址：日版 `AC1C`（`ADC #1C` 再 `ADC #AC`），美版 `B117`。后面的表日版是裸地址（大量 `AD94`），美版是 `EQUW D0_B28F`。`jpmap` 把 `0:AD94` 对到 `D0_B28F`。
- 多处 PPU 串的源低字节：日版 `28` 或 `38`，美版 `2A` 或 `3A`，高字节都是 `05`。用到的例程包括 `DRAW_LIVES`、`DRAW_STAGE_CLOCK`、`DRAW_SCORE_PAIR`、`DRAW_SND_VALUE`、`DRAW_PASS_LINE`、`MAKE_STAGE_CODE`、`DRAW_CARD_LIVES`。
- `L5_B8A4`：日版在列 6 画图块 `86` 共 4 格；美版在列 5 排队字符串 `D5_B8EF`（`FC FD FE FF 38 39 00`）。
- 标题：日版走 `JP_TITLE_PAL`、`JP_TITLE_MAP_A`、`JP_DRAW_BANNER`，不写 `SCROLL_X`。美版清 `SCROLL_X`，走 `LOAD_TITLE_PAL`、`DRAW_TITLE_MAP`，并在 `TITLE_PHASE` 非 0 时先不读开始键。抖动表和行数（日版 Y=`16`，美版 Y=`15`）也不一样。
- bank 1：美版在 `TITLE_BG_CHR` 前多了 8 行 CHR（从 `C2 18` 起）。日版在 `ENDING_SPR_CHR` 末尾多了 `FF` 填充。
- `SFX0A_PROG` 第一条是 `LDA abs,X`。日版操作数是 `L7_C61D+1`，美版是 `UPLOAD_CHR_RLE`。后面的 `TXA` 起两边相同。覆盖率没跑到这段。

`FILLTO &D800`、`&B800`、`&BFBC` 两边表达式相同，只是前面字节长度不同，所以填多少不一样。

## RAM 变量提议

没有新的 RAM。`JOY_SIG_OK` 只被美版手柄探测和模式菜单使用，名字是已有的。

## 疑问 / 待确认

- `SFX0A_PROG` 为什么一条指向 `DRAIN_PPU_Q` 附近、另一条指向 `UPLOAD_CHR_RLE`。两边都没执行到。可能是数据被反汇编成 `LDA abs,X`，不能当手柄或 CHR 逻辑来读。
- `JP_TITLE_Q1` 的 `28 19 08 19` 是紧跟 `JMP QUEUE_PPU_RUN` 的字节。没有单独追这条 PPU 记录的长度。
- `JP_SPR_*` 只确认了「日版帧数据、美版表因插字节而换了标签」。没有逐条和美版某帧做像素级对应。
- 开场图整段 `+1` 是图块号平移还是另一套 `END_META_GFX` 编号，没有把画面还原出来。
- `$FFE0` 美版 `A7 94` 和日版 `04 F8` 在标题串后面，含义不清楚。只确认了 ASCII 那一段。

## 工具问题

`check.sh` 重新生成时列出多条 `pointers: US 5:... does not apply to JP`。本任务没有改 `pointers.tsv`。这些是已有指针声明在日版对不上字节。T08 的笔记里当时只看到 `5:B14B` 和 `5:B15B` 两条。

## check.sh 结果

```
== db lint
lint: 0 problems
== regenerate
IF REGION_JP blocks 177
  note: pointers: US 5:9F92 does not apply to JP (5:9F92 is an opcode)
  note: pointers: US 5:9F9D does not apply to JP (5:9F9D is an operand)
  note: pointers: US 5:A0A7 does not apply to JP (5:A0AB is an opcode)
  note: pointers: US 5:A10E does not apply to JP (5:A10E is an opcode)
  note: pointers: US 5:A119 does not apply to JP (5:A119 is an opcode)
  note: pointers: US 5:A124 does not apply to JP (5:A124 is an opcode)
  note: pointers: US 5:A12F does not apply to JP (5:A12F is an opcode)
  note: pointers: US 5:B14B does not apply to JP (5:B14B is an operand)
  note: pointers: US 5:B153 does not apply to JP (5:B153 is an operand)
  note: pointers: US 5:B15B does not apply to JP (5:B15B is an operand)
  note: pointers: US 5:B163 does not apply to JP (5:B163 is an operand)
  note: pointers: US 5:B255 does not apply to JP (5:B255 is an opcode)
  note: pointers: US 5:B25D does not apply to JP (5:B25D is an operand)
  note: pointers: US 5:B265 does not apply to JP (5:B265 is an opcode)
  note: pointers: US 5:B4E7 does not apply to JP (5:B4E7 is an operand)
  note: pointers: US 5:B57B does not apply to JP (5:B57B is an operand)
  note: pointers: US 5:B583 does not apply to JP (5:B583 is an operand)
  note: pointers: US 5:B58B does not apply to JP (5:B58B is an opcode)
  note: pointers: US 5:B5AD does not apply to JP (5:B5AD is an opcode)
  note: pointers: US 5:B614 does not apply to JP (5:B614 holds $1911)
  note: pointers: US 5:B61C does not apply to JP (5:B620 is an opcode)
  note: pointers: US 5:B624 does not apply to JP (5:B624 is an opcode)
  note: pointers: US 5:B89A does not apply to JP (5:B89A is an operand)
  note: pointers: US 5:B8AD does not apply to JP (5:B8AD is an operand)
  note: pointers: US 7:CC26 does not apply to JP (7:CC26 is inside a FARCALL)
== build us
OK: identical to Bomberman II (USA).nes
== build jp
OK: identical to Bomberman II (Japan).nes
== relocation test
  us shift 1: quick        OK (1566 frames)
CHECK PASSED
```
