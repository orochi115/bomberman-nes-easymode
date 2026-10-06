# T03-game-a 主游戏逻辑上半（bank 5 `$8000`–`$9FFF`）

## 概述

这段从 `STAGE_LOOP` / `UPDATE_PLAYERS` / `STAGE_SETUP` 经 `FARCALL 5` 进来，管关卡里的角色、道具、密码、计时和计分。

`UPDATE_ACTORS` 每帧先跑 `SERVICE_DEMO_PAD`。`Z_B7` 非 0 时只推进结算并画 0 号槽。否则三个 `Z_69` 槽各做一次：`LOAD_ACTOR_WORK` 把槽拷进 `Z_9C`–`Z_AC`，`MOVE_ACTOR` 走一步，再 `STORE_ACTOR_WORK` 写回。然后 `SHARE_ACTOR_A6`、`CHECK_ACTORS_LEFT`、`FOLLOW_ACTOR_SCROLL`。

`MOVE_ACTOR`：`Z_A5` 非 0 时播死亡帧；`Z_B5` 为负时走 `KNOCK_STEP`；否则按 `W_04C2` 的方向步进，`CELL_BLOCKS_MOVE` 看格子，`TOUCH_MAP_CELL` 捡道具或触发出口。`HANDLE_ACTOR_BTN` 把 A 键交给 `L7_CF96`，B 键在 `Z_AF` 为 1 时交给 `L7_CFD4`。

道具表 `ITEM_HANDLERS` 共 16 项，下标是炸弹标志的低 4 位。效果包括火力、炸弹数、遥控、速度、两档限时、穿弹、穿墙、过关标志 `Z_B4`、随机生成，以及 `ROLL_LIFE_OR_MOB` / `ROLL_ACTOR_A6`。

`$9254` 起是密码画面：`RUN_PASS_SCREEN` 编辑 `W_03E4` 的八个半字节，短词走 `PASS_WORDS`，普通码走 `TEST_PASS_SUM` 和 `APPLY_PASS_STAGE`。`MAKE_STAGE_CODE` 用区、关、`Z_90`、`Z_93` 和 RNG 造码。

`INIT_STAGE_CLOCK` / `TICK_STAGE_CLOCK` 管三位数关卡钟，归零调用 `KILL_PLAYERS`。`DRAW_MODE_HUD` 按 `Z_49` 画命或三组分数。`RUN_BONUS_STAGE`（`$9E92`）把区关改成 0 区 7 关，自带帧循环直到 `Z_B7` 到 `F0h`。`RUN_MODE1_MENU` 把 `Z_49` 设成 1 后不再返回。

## 已命名

依据是本段指令、表项之间的跳转，以及 `STAGE_LOOP` 的调用关系。

- 关卡图块：`DRAW_LIVES`、`UPLOAD_LEVEL_CHR`、`CHOOSE_LEVEL_CHR`、`LEVEL_CHR_PICK`（48 关 × 3 字节）、`LEVEL_CHR_OFF`（13 字节）。
- 角色：`UPDATE_ACTORS`、`LOAD_ACTOR_PAD`、`LOAD_ACTOR_WORK`、`STORE_ACTOR_WORK`、`MOVE_ACTOR`、四个 `STEP_ACTOR_*`、`CELL_*_OF`、`PEEK_CELL_28`、`CELL_BLOCKS_MOVE`、`DRAW_ACTOR`、`ACTOR_FR_PTR`、`ACTOR0_FRAMES` / `ACTOR1_FRAMES` / `ACTOR2_FRAMES`（各 19 个字）、`ACTOR_SPRITES`。
- 速度和击退：`ACTOR_SPEED_LO` / `ACTOR_SPEED_HI`（7 对小端速度）、`SUBPIX_BIAS`、`BIAS_DELTA`、`KNOCK_STEP`、`SETUP_KNOCKBACK`。
- 道具和限时：`PICK_UP_ITEM`、`ITEM_HANDLERS`、`INC_FIRE`、`INC_BOMBS`、`GIVE_REMOTE`、`INC_SPEED`、`START_POWER_18`、`START_POWER_10`、`GIVE_BOMB_PASS`、`GIVE_WALL_PASS`、`SET_CLEAR_FLAG`、`TICK_TIMED_POWERS`、`TICK_ACTOR_A6`、`ROLL_ACTOR_A6`。
- 回合：`UPDATE_ROUND`、`ROUND_OAM_PTRS`、`ROUND_SPR_X`、`ROUND_SPR_SLOT0`–`SLOT2`（负的 `W_051B` 低 2 位为 1、2、3）、`ROUND_SPR_TIME_POS` / `ROUND_SPR_TIME_NEG`（`W_055A` 的符号）。
- 密码：`RUN_PASS_SCREEN`、`PASS_KEY_MAP`（8×3）、`PASS_WORDS`（7 个词 × 8 字节）、`PASS_GLYPHS`、`TRY_PASS_ENTRY`、`APPLY_PASS_STAGE`、`APPLY_PASS_WORD`。
- 计时计分和演示：`INIT_STAGE_CLOCK`、`STAGE_TIME_TAB`（48 关 × 2 字节）、`TICK_STAGE_CLOCK`、`DRAW_STAGE_CLOCK`、`DRAW_MODE_HUD`、`DRAW_SCORE_PAIR`、`SERVICE_DEMO_PAD`、`DEMO_PAD_PTR`、`DEMO_REC_A`–`D`。
- 奖励和模式：`RUN_BONUS_STAGE`、`BONUS_FRAME`、`SHOW_BONUS_CARD`、`RUN_MODE1_MENU`。

`QUEUE_A6_ATTR` 把 `Z_20` 指到 `A6_ATTR_ON`（两个 `FFh`），`QUEUE_A6_CLEAR` 指到 `A6_ATTR_OFF`（两个 `00h`）。这两处立即数已声明为 `lo`/`hi` 指针。

## RAM 变量提议

本段用得最多、但别的 bank 也在读写，没有在这里改名。

- `Z_68` 当前槽号 0–2。`Z_69,X` 槽是否活着。`Z_9C`–`Z_AC` 是该槽的工作副本（`LOAD_ACTOR_WORK` / `STORE_ACTOR_WORK`）。
- `Z_9D` / `Z_9E` 格坐标。`Z_9F`/`Z_A0` 是 X 像素，`Z_A1` 是 Y 像素。`Z_A2` 朝向 0–3。`Z_A3` 行走帧，`Z_A4` 帧计时。
- `Z_A5` 非 0 时走死亡动画。`Z_A6` 最高位为 1 时是限时状态，低 2 位选 `A6_TIME_TAB`；`Z_A7` 帧计数，`Z_A8` 剩余大步。
- `Z_A9` 火力，上限 7。`Z_AA` 炸弹数，上限 4。`Z_AB`/`Z_AC` 速度累加。`Z_AD` 穿弹，`Z_AE` 穿墙，`Z_AF` 遥控。
- `Z_B0` 限时道具种类，`Z_B1`/`Z_B2` 其倒计时。`Z_B3` 速度档。`Z_B4` 过关标志。`Z_B5` 为负时击退，低 2 位是方向，`Z_B6` 是剩余步数。
- `W_04C2` 按住的方向，`W_04C1` 新按键。演示回放也写这两个字节。
- `W_04E3` 关卡图块组号。`W_04E4` 上次吃到道具时的区关编码。`W_04E6`–`W_04E9` 另一条限时和闪烁计数。
- `W_051B` 回合胜负。正数等待 `30h` 帧，负数的低 2 位选 `ROUND_SPR_SLOT*`。`W_055A` 时钟帧计数，为负时 `UPDATE_ROUND` 改画 `ROUND_SPR_TIME_NEG`。
- `W_055C` / `W_055D` 时钟的两个数字。`W_055E`–`W_0560` 三组分数。
- `W_03DB` 九字节密码原值，`W_03E4` 是画面上编辑的八个半字节加一个状态字节。`W_0542`–`W_0549` 是解码缓冲。`W_054E` / `W_054F` / `W_0550` 是密语出口，和 `T01-core` 里的菜单入口一致。

## 疑问 / 待确认

- `CELL_BLOCKS_MOVE` 对 bit6 和 0 返回 0（可以进入），只对 bit5 / bit4 看 `Z_AD` / `Z_AE`。其它非零字节也返回 0。硬墙是不是只靠 bit4，没有在这里证实。
- `ROLL_LIFE_OR_MOB` 在覆盖率里没跑到，源码按字节铺开，中间的 `EQUW SET_ACTOR_FLASH` 是 `JMP` 的操作数。`LIFE_ROLL_TAB` 的正数交给 `L7_D192` 之后生成什么，要到固定 bank 才能看。
- `ACTOR_SPRITES` 各块的图块含义没有对着 CHR 逐帧核对，所以仍用 `D5_` 标签，只在三张帧表里当指针目标。
- `PASS_WORDS` 七个词在画面上拼出来的英文字没有逐字节对过字模。`APPLY_PASS_WORD` 能确定的是它们写入的 RAM：`W_054F`、`W_03EE`、`W_0550`、`W_03ED`、`W_054E`。
- `RUN_MODE1_MENU` 末尾跳到本范围之外的 `S5_A00B`。
- `$A000` 之后的嫌疑指针（`5:A801`、`5:AEAD`、`5:B15B`、`5:B163`、`5:B2DE`、`5:A606`、`5:A7BF`、`5:B5B9`）不在本任务范围。

## 工具问题

无。

## 范围内的指针嫌疑

- `5:86F3` / `5:86F7`：`QUEUE_A6_ATTR` 的立即数，指向 `A6_ATTR_ON`。已声明 `lo`。
- `5:8712` / `5:8716`：`QUEUE_A6_CLEAR` 指向 `A6_ATTR_OFF`。已声明 `lo`。
- `5:8846`：`ACTOR_FR_PTR` 的第三个字，生成结果已是 `EQUW ACTOR2_FRAMES`。已 `notptr`。
- `5:90E9`：`ROLL_LIFE_OR_MOB` 里 `BD 0C 91` 的绝对地址操作数，指向 `LIFE_ROLL_TAB`，不是数据表。已 `notptr`。
- 已声明的字指针：`ITEM_HANDLERS`（16）、`ACTOR2_FRAMES`（19）、`DEMO_PAD_PTR`（4）、`ROUND_OAM_PTRS` 里从第二项起的 5 个字（`5:91B3`）、`5:9101` 的 `SET_ACTOR_FLASH`。

## check.sh 结果

```
== db lint
lint: 0 problems
== regenerate
  pass 1: aligned 127235 bytes, labels linked True, facts copied 1
  pass 2: aligned 127235 bytes, labels linked False, facts copied 0
IF REGION_JP blocks 206
== build us
OK: identical to Bomberman II (USA).nes
== build jp
OK: identical to Bomberman II (Japan).nes
== relocation test
  us shift 1: quick        OK (1566 frames)
CHECK PASSED
```
