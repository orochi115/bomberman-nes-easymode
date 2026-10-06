# T05-bank0 敌人行为与职员表

## 概述

bank 0 做两件不相干的事。

关卡里：`SPAWN_STAGE_ENEMIES` 按区 `Z_4B`、关 `Z_4C` 读出生表（类型字节，以负字节结束）。`Z_49` 非 0 直接返回。`Z_4E` 非 0 则不读表，在 `FIXED_SPAWN_COL/ROW` 放 8 个类型 0。空位出生会重试，直到地图格为 0。10 个槽，下标 9 到 0。`DRAW_ALL_ENEMIES` 按四组轮换顺序逐个 `DISPATCH_ENEMY_DRAW`。逻辑走 `DISPATCH_ENEMY_AI`，按 `X_625A` 查 `ENEMY_AI_LO`。被炸后 `X_6250` 变负，`ENEMY_DEATH_STEP` 数 6 步，类型改成 `$11`，再交给 `L7_D192`。

方向：0 上、1 左、2 下、3 右。一格 16 像素，像素坐标是格号乘 16 再加 8。阻挡看前进方向的地图格，并与 `X_62E2` 相与。

另一段是通关职员表。`SHOW_CREDITS` 关画面、清名表、上传 `$A486` 的 RLE CHR 和 bank 4 的四行调色板，播声音 `$18`，再由 `TICK_CREDITS` 上滚。行指针表在 `$B117`，187 项，`$0000` 结束。名表文字是 `$40` 当空格的 ASCII，能读出 STAFF、PROGRAM、YASUHIRO KOSAKA、GRAPHIC DESIGN、MIKA SASAKI、GAME DESIGN、HITOSHI OKUNO、MUSIC COMPOSE、ATSUSHI CHIKUMA、SOUND PROGRAM、OSAMU NARITA、PRODUCE、SHIGEKI FUJIWARA、SPECIAL THANKS、BENHUR NAGACHAN、ONJI KUWAHARA、SECRET PASSWORD，以及 COPYRIGHT 和 HUDSON SOFT。

日版和美版的敌人逻辑大体相同。`IF REGION_JP` 主要换三样：出生表和精灵表里的指针目标、职员表全文和指针表、调色板源地址。美版版权行是 1992，日版是 1991。美版密码字符是 `K3456712`，日版是 `PCDEFGAB`。精灵流格式两边一样：第一个字节是精灵个数，随后每 4 字节为图块、X 偏移、Y 偏移、属性。`DRAW_METASPRITE` 这样读。

## 已命名

依据是这段代码本身。类型号来自 `ENEMY_AI_LO` / `ENEMY_DRAW_LO` 的下标。

- 出生：`SPAWN_STAGE_ENEMIES`、`SPAWN_ENEMY_ON_EMPTY`、`SPAWN_PARADE`、`SPAWN_TYPE_10`、`SPAWN_BURST`、`SPAWN_TYPE_4`、`PLACE_ENEMY`、`FIND_FREE_ENEMY`、`LOAD_SPAWN_LIST`、`NOTE_ENEMIES_CLEARED`
- 每帧：`DRAW_ALL_ENEMIES`、`DISPATCH_ENEMY_DRAW`、`DISPATCH_ENEMY_AI`、`ENEMY_BLAST_OR_PLAYER`
- 移动和碰撞：`ENEMY_PIX_TO_CELL`、`ENEMY_MOVE_1`、`ENEMY_MOVE_SPEED`、`ENEMY_DIR_BLOCKED`、四个 `ENEMY_BLOCK_*`、`ENEMY_AIM_PLAYER`、`ENEMY_STRAFE_AXIS`、`ENEMY_AT_ODD_CENTER`、`ENEMY_AT_CELL_CENTER`、`ENEMY_ON_BLAST_LINE`
- 类型 0–26 的 `ENEMY_AI_*` 和 `DRAW_ENEMY_*`。16、18、19、22 的入口覆盖率没跑到，名字来自 `ENEMY_AI_LO` / `ENEMY_DRAW_LO` 的下标，行为是把那些 `EQUB` 按指令译出来的
- 行走帧：`ENEMY_WALK_00` 到 `ENEMY_WALK_15`（按类型号，不是地址顺序）。16 个字，方向×4 加 `FRAME_CNT/8` 的低 2 位。每字指向一块元精灵。`ENEMY_DEATH_FRAMES` 是死亡帧。`ENEMY_FRAME_PTRS_18` 给类型 `$12` 和 `$14`，`ENEMY_FRAME_PTRS_19` 给 `$13` 和 `$15`
- `ARM_TYPE10_TIMER`：`X_62E8` 为 0 时把它写成 1，并把 `X_62E9` 写成 `$F0`。`BURST_TYPE_LIST` 是类型 1–4
- `ENEMY_WALK_PTR_LIST`：16 个字，顺序是类型 2、3、0、4、1、7、8、9、`$0A`、`$0B`、5、`$0C`–`$0F`、6。本 bank 没有直接引用。日版目标不同。键写成 `us:`，避免在地址映射建立前按美版地址去读日版 ROM
- `ENEMY_ORDER_BASE` 是绘制顺序的四个起点。`ENEMY_TURN_DELTAS` 是 8 组转向增量。`ENEMY_SCRIPT_OPS` 是脚本阶段 0 到 `$0C` 的入口。`ENEMY_PHASE_ANIM` 为 0 时画第 1 帧，非 0 时用 `FRAME_CNT/8` 的低 2 位
- 脚本：`RUN_ENEMY_SCRIPT`、`ENEMY_SCRIPT_STEP`，以及 `ENEMY_SCRIPT_20/21/25/26`
- 分数：`ADD_SCORE`、`SCORE_ADD_TABLE`、`ENEMY_SCORE_INDEX`
- 职员表：`SHOW_CREDITS`、`LOAD_CREDITS_GFX`、`TICK_CREDITS`
- 精灵：`DRAW_ENEMY_WALK` 用方向乘 4 加帧号选词；`ENEMY_DIR_FLIP` 前 4 字节是四个方向的属性（第四个是水平翻转 `$40`）

## RAM 变量提议

10 个槽，美版基址如下。下标 X 为 0–9。正式命名留给 RAM 任务。

| 地址 | 提议名 | 依据 |
|---|---|---|
| `X_6250` | ENEMY_FLAGS | 0 空槽。出生写成 1。bit3 隔帧画，bit4 不画，bit5 跳过玩家重叠，bit6 跳过爆炸反应，bit7 或整个字节为负是死亡 |
| `X_625A` | ENEMY_TYPE | 查 AI 和绘制表。死亡后改成 `$11`，旧类型留在 `X_62A0` |
| `X_6264` / `X_626E` | ENEMY_X_LO / HI | 像素 X。格号乘 16 加 8 |
| `X_6278` | ENEMY_Y | 像素 Y |
| `X_6282` / `X_628C` | ENEMY_COL / ROW | `ENEMY_PIX_TO_CELL` 从像素除 16 得到 |
| `X_6296` | ENEMY_SCORE_SLOT | 爆炸链计数加上 `ENEMY_SCORE_INDEX`。类型 `$11` 用它选 `ITEM_SPRITE_PTRS` |
| `X_62A0` | ENEMY_PHASE | AI 状态，也是脚本阶段。死亡时当帧计数 |
| `X_62AA` | ENEMY_SPEED_ACC | 速度累加。死亡时初值 `$30` |
| `X_62B4` | ENEMY_TIMER | 转向或停顿计数 |
| `X_62BE` | ENEMY_DIR | 0 上、1 左、2 下、3 右 |
| `X_62C8` | ENEMY_SUBTIMER | 脚本和部分 AI 的第二计时 |
| `X_62D2` | ENEMY_SCRIPT_PC | `ENEMY_SCRIPT_STEP` 的脚本下标 |
| `X_62DC` | ENEMY_ORDER_MODE | 0 用第 0 组绘制顺序，否则用 `FRAME_CNT` 低 2 位 |
| `X_62DD` | ENEMY_REACT_MODE | bit0 为 0 走爆炸，为 1 走玩家重叠 |
| `X_62DE` | ENEMIES_CLEARED | 全部空槽或类型 `$11` 时置 1 |
| `X_62DF` | ENEMY_PLACE_TYPE | `PLACE_ENEMY` 的临时类型 |
| `X_62E0` | ENEMY_INDEX | 当前绘制和反应的槽 |
| `X_62E1` | ENEMY_SPAWN_TYPE | 随机找空格时记住的类型 |
| `X_62E2` | ENEMY_CELL_MASK | 地图格相与的掩码，常见 `$70`、`$50`、`$40`、`$F0` |
| `X_62E3` | ENEMY_STEP | `ENEMY_MOVE_SPEED` 的步长 |
| `X_62E6` | PARADE_INDEX | `SPAWN_PARADE` 的点下标，到 `$41` 回 0 |
| `X_62E7`–`X_62E9` | TYPE10 计时 | `SPAWN_TYPE_10` 的两次尝试 |
| `X_62EB`–`X_62ED` | 爆发出生 | 倒计时和格子。触发后同一种类型放 8 个 |
| `X_62EE`–`X_62F0` | 类型 4 出生 | 倒计时和格子 |
| `X_62F1` | 绘制顺序相位 | `ENEMY_ORDER_BASE` 的值 |
| `X_62F2` | 脚本开关 | 脚本 `$09`/`$0A`/`$0B` 写成 1、0、2 |

玩家格在 `Z_6C` / `Z_6F`，玩家像素在 `Z_72`/`Z_75` 和 `Z_78`。这三组内核也在用，这里只记录敌人怎么读它们。

`W_0536` 是职员表模式：1 滚动，2 收尾等待，0 结束。`W_0537` 是滚动计数，`W_0538` 是行号。`W_03D0` 起 8 个十进制数字是分数。

## 疑问 / 待确认

- 类型 `$10`、`$12`、`$13`、`$16` 的代码覆盖率没跑到，反汇编仍是 `EQUB`。块注释是按字节译出的指令，没有在模拟器里单步确认
- 类型 `$12` 的脚本在 `$935D`，类型 `$13` 的脚本在 `$938C`。这两段没有单独命名，因为它们夹在同一片未执行字节里
- `ENEMY_ON_BLAST_LINE` 是同一列或同一行就返回，不是同一格。是否故意用十字范围，没有别的证据
- `NOTE_ENEMIES_CLEARED` 里对 `Z_4E` 的比较两边都是 `RTS`，看不出作用
- 类型编号和画面上的敌人种类没有逐个对上名字。注释里只用类型号
- `Z_6C` / `Z_6F` 由别的 bank 写入。这里只看到敌人把它们当玩家格
- 日版职员表的假名没有逐行译出，只确认了指针表和文字区与美版分开

## 工具问题

`tools/check.sh` 停在 regenerate，不是 bank 0 的条目。

`Emitter.__init__` 会立刻调用 `pointer_roles()`。这时日版的 `alias_key` 还是恒等映射，日版 ROM 被按美版地址直接读取。`pointer_roles()` 后面再次调用时也不清空 `conflicts`。于是 `db/pointers.d/T04-game-b.tsv` 里的 `5:B15B` 和 `5:B14B`（`lo`，`bank=4`）在日版同一数字地址上读到 `$2062` 和 `$3E00`，被记成冲突，`merge.py` 以状态 2 退出。按规则没有改 T04 的分片，也没有改 `tools/`。

bank 0 自己的指针在这次 regenerate 里没有冲突。美版和日版都能逐字节对上原 ROM。因为 regenerate 失败，`check.sh` 没有进入 relocation test。

## check.sh 结果

```
== db lint
lint: 0 problems
== regenerate
IF REGION_JP blocks 198
jp: 2 conflicts, 0 unresolved
  pointers: 5:B15B holds $2062, not an address in bank 4 (skipped)
  pointers: 5:B14B holds $3E00, not an address in bank 4 (skipped)
ERROR: 2 db entries could not be applied (see above)
== build us
OK: identical to Bomberman II (USA).nes
== build jp
OK: identical to Bomberman II (Japan).nes
CHECK FAILED
```
