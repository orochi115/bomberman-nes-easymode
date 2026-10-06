# T04-game-b bank 5 `$A000–$BFFF`

## 概述

这一段不是主循环里的玩家移动，而是两组画面和爆炸。

画面从固定 bank 的 `FARCALL 5` 进来。`RUN_TITLE` 播标题滚动，超时进演示。`MODE_MENU_LOOP` 画模式菜单（普通 / VS / 战斗 / 继续）。`S5_9FC0` 进入声音房，改三个参数并直接 `AUDIO_CALL`。命数耗尽走 `GAME_OVER_LOOP`（`Z_4A` 二选一）。区号第一次变化时 `SHOW_AREA_INTRO` 播区介绍。区 6 走 `ENDING_LOOP`（横向卷轴）和 `OPENING_LOOP`。`SETUP_BY_MODE` 按 `Z_49` 选关前卡：0 关卡卡，2 战斗卡，其余对战卡。对战结算是 `VS_RESULT_LOOP`。`Z_49` 为 2 时 `BATTLE_WIN_MENU` 让人在 1..5 里选胜场，否则把 `W_0563` 写成 5。

爆炸由 `UPDATE_BLASTS` → `STEP_BLASTS` 每帧交替处理。奇数拍走 24 个 `X_6001` 炸弹槽，偶数拍走 60 个 `X_60E2` 火焰演员。放炸弹是 `PLACE_BOMB`（`L7_CF96`），遥控引爆是 `DETONATE_REMOTE`（`L7_CFD4`）。炸弹倒计时到 0 后 `SPREAD_FLAME` 按 `Z_B8` 的四个方向、半径 `X_624B` 扫格子。

地图字节在 `BLAST_CELL` 里的用法：bit6 或值 `A0h` 挡住火焰；bit4 是已放的炸弹，会被 `KICK_DIR_MASK` 踢一下并停火；低两位为 1 或 2 交给 `BLAST_CONTENTS`（1 清 `W_04EB` 再进 `L7_D11B`，2 进 `L7_D103`）；值 `20h` 走 `OPEN_BURIED`，揭开的图块在 `BURIED_REVEAL_TILE`，并 `DEC W_04E2`。

## 已命名

依据是调用方（`bank7.asm` 里已有的包装例程）和这段自身的读写。

- 声音房：`SND_ROOM_INPUT`、`DRAW_SND_CURSOR`、`DRAW_SND_PARAMS`、`DRAW_SND_VALUE`、`DRAW_SND_ROOM_TEXT`、`QUEUE_XY_BYTES`。三行参数夹在 `SND_PARAM_MIN` 和 `SND_PARAM_MAX` 之间，半字节图块是 `SND_HEX_GLYPH`
- 标题：`RUN_TITLE`、`LOAD_TITLE_CHR`、`DRAW_TITLE_MAP`、`LOAD_TITLE_PAL`、`DRAW_TITLE_BANNER`、`STEP_TITLE_SCROLL`、`BLINK_START_TEXT`、`DRAW_TITLE_ACTORS`。滚动行来自 `TITLE_MAP_ROWS`（`11h` 行 × `20h` 图块）。日版对应 `JP_TITLE_MAP_A`、`JP_TITLE_PAL`、`JP_DRAW_BANNER`、`JP_DRAW_BANNER2`、`JP_TITLE_SHAKE`
- 模式菜单：`MODE_MENU_LOOP`、`MODE_MENU_INPUT`、`DRAW_MODE_CURSOR`、`MODE_TO_AREA`（非 0 时把 `W_04C9` 写成 6）、`DRAW_MODE_MENU`、`DRAW_TOP_SCORE`。字符串是 `DRAW_INLINE_STR` 记录：列、行、长度、图块。`PPU_WRITE_TEXT` 是它的实现，`20h` 会写成 `40h`
- 游戏结束和分数：`GAME_OVER_LOOP`、`SAVE_TOP_SCORE`、`DRAW_HUD_SCORE`、`SEED_DEFAULT_SCORE`。默认名 8 字节能对上 `DEFAULT_TOP_NAME`（图块 `4B 4F 53 41 4B 41 21 21`，即 KOSAKA!!）
- 区介绍：`SHOW_AREA_INTRO`、`DRAW_AREA_INTRO`、`LOAD_AREA_INTRO`、`DRAW_INTRO_SPRITE`。六区各一组 bank 4 指针。只有区 5 用 `AREA5_FRAME_DLY` 推进 `W_0532`
- 结局 / 开场：`ENDING_LOOP`、`SCROLL_ENDING`（仅当 `X_62F2` 为 1）、`OPENING_LOOP`、`LOAD_ENDING_CHR`
- 对战和关前卡：`VS_RESULT_LOOP`、`BATTLE_WIN_MENU`、`SHOW_BATTLE_CARD`、`SHOW_VS_CARD`、`SHOW_STAGE_CARD`。数字图块表是 `SCORE_DIGIT_TILE`
- 炸弹和火焰：`PLACE_BOMB`、`DETONATE_REMOTE`、`STEP_BLASTS`、`STEP_BOMB`、`ALLOC_BOMB_SLOT`、`SPREAD_FLAME`、`BLAST_CELL`、`SPAWN_FLAME`、`BLAST_CONTENTS`、`OPEN_BURIED`、`FIND_FREE_FLAME`、`FIND_BOMB_SLOT`、`CLEAR_FLAME_HERE`

## RAM 变量提议

这些地址别的 bank 也在用，这里只提议，没有改名。

- `W_04CD` 声音房光标 0..2。`W_04CE` 起三个参数，初值来自 `SND_PARAM_MIN`（`0C 00 1E`）
- `W_051E` 标题 “START” 闪烁计数。`W_051F`/`W_0520` 标题空闲倒计时，初值 `05DCh`，到 0 调用 `START_DEMO`
- `W_0521` 标题滚动相位：1 等待，2 滚动，0 结束。`W_0522` 相位延时，`W_0523` 已画的行，`W_0524` 抖动下标，`W_0525`/`W_0526` 角色帧
- `W_03C0` 八字高分名，`W_03C8` 高分数字，`W_03D0` 本局分数数字。`DRAW_HUD_SCORE` 只在 `Z_49` 为 0 时画到 (4,2)
- `W_04C8` 对战结算用的图像号，0..2，选 `D5_B29B`/`D5_B29E` 和图块组
- `W_055E` / `W_055F` / `W_0560` 关前卡上的三个小计数（战斗卡三个都画，对战卡画前两个）。`W_0563` 胜场，普通模式固定 5，战斗模式在 1..5 之间选
- `W_0532`..`W_0535` 区介绍动画。`Z_2A`/`Z_2B` 在区介绍和几张卡上当倒计时
- `Z_68` 当前玩家，选 `BOMB_SLOT_BASE`。`Z_A9` 和 `BOMB_SLOT_LIMIT` 比较，决定还能不能再占一个炸弹槽
- `Z_AF` 为 1 时，`X_6079` 为 0 的炸弹不减引信。`X_6000` 非 0 时所有引信停住。`W_03ED` 是新炸弹的引信初值（`RESET_MARKS` 写成 `4Bh`）
- `X_6001` 标志：0 空，正数是炸弹，负数时用 `X_60A9` 计数再变回 1。`X_6019`/`X_6031` 格子，`X_6049` 帧，`X_6061` 引信，`X_6079` 踢的方向，`X_6091` 环上的主人
- `X_60E2` 低四位是火焰种类，bit7 在生成时置上。`X_611E`/`X_615A` 格子，`X_6196` 动画计数，`X_61D2` 剩余半径，`X_620E` 主人
- `X_624B` 爆炸半径，`X_624C` 主人，`X_624D` 炸弹/火焰交替拍，`X_624E`/`X_624F` 两个动画拍
- `Z_B8` 方向屏蔽。`W_04E2` 在揭开埋藏格和 `OPEN_BURIED` 的两条路径里递减；bank 4 会把它递增
- `W_0518` 在埋藏格低两位为 2 时被写成 1
- `W_04E5` 命，关卡卡上画成一位数字，并抄到 `W_04CB`

## 疑问 / 待确认

- `MODE_TO_AREA` 后面有一段到不了的字节（`S5_A93F` 的 `RTS` 之后，直到 `LOAD_MODE_PAL`）。看起来像另一段手柄判断，没有调用方
- `Z_49` 在声音房入口被写成 1，和菜单里 “VS” 的 1 是不是同一含义，这段看不出来。声音房自己的循环不返回
- 区 5 介绍帧表 `D5_AEC6` 后面还有 6 个裸字（`57 AF` 起），和 `W_0532` 数到 6 对得上，应是后续帧指针。对战结算表 `VS_RESULT_SPR_PTR` 也有裸字。两边一旦用 `pointer word` 声明，`merge.py` 会在日版映像上读到窗口外的地址并崩溃，所以留了 `notptr`。见工具问题
- `BLAST_CONTENTS` 的低两位 1 和 2 只追到了 `L7_D11B` / `L7_D103`，没有在本段证实是道具和出口
- `W_04E2` 递减的对象（软墙计数？）要看 bank 4 的递增点
- `SCORE_DIGIT_TILE` 的下标 0 是 `6Dh`，1..9 才是 `64h..6Ch`。调用方把分数、区、关直接当下标，没有在这里看到范围检查

## 工具问题

`tools/check.sh` 把 `python3 tools/merge.py | tail -3` 写在没有 `pipefail` 的管道里。`merge.py` 崩溃时管道的退出码仍是 `tail` 的 0，脚本会打印 `CHECK PASSED`，源码却没有重新生成。这次字指针把日版地址解释出窗口时就是这样。

`db.py pointer` 的 `word` 在合并日版之前就按美版地址去读日版 ROM。`VS_RESULT_SPR_PTR`（`5:B2DE`）和区 5 帧表（`5:AEC6`）因此让 `emit.py` 的 `expr_of` 对超出 bank 的偏移抛 `IndexError`。单独声明结局地图那四条 `LDA #` 立即数（`5:B14B` 起）可以通过。

## 范围内的指针嫌疑

`suspects.py us --bank 5` 里落在 `$A000–$BFFF` 的项：

- `5:A801`、`5:A606`：`TITLE_MAP_ROWS` 里的图块，`notptr`
- `5:A7BF`：`MODE_TO_AREA` 后面到不了的字节，`notptr`
- `5:AEAD`：`INTRO_SPR_XY` 的 X/Y 交错字节，`notptr`
- `5:B15B` / `5:B163`：结局地图的 bank 4 指针，已和同例程的 `5:B14B`、`5:B153` 一起声明为 `lo/hi bank=4`。生成结果是 `D4_9AD4`、`D4_9B1A`、`D4_98A8`、`D4_AE17`
- `5:B2DE`、`5:B2E4`、`5:AECC`：见上面的工具问题，`notptr`

`$A000` 以下的嫌疑不在本任务范围。

## check.sh 结果

```
== db lint
lint: 0 problems
== regenerate
  pass 1: aligned 127235 bytes, labels linked True, facts copied 1
  pass 2: aligned 127235 bytes, labels linked False, facts copied 0
IF REGION_JP blocks 202
== build us
OK: identical to Bomberman II (USA).nes
== build jp
OK: identical to Bomberman II (Japan).nes
== relocation test
  us shift 1: quick        OK (1566 frames)
CHECK PASSED
```
