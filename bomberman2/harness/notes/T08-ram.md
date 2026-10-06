# T08-ram RAM 变量统一命名

## 概述

按 T01–T07 笔记里的读写说明，核对 `bank*.asm` 里的用法后，给能确定的零页、RAM 和 WRAM 起了名。每个名字都带一句说明。数组只给基址命名，说明里写槽数和步长；只有代码单独访问的字节才再给名字。

主循环用到的状态是 `GAME_MODE`、`AREA_NUM`、`STAGE_NUM`、`LIVES`、`DEMO_MODE`、`STAGE_PHASE`、`CLEAR_PHASE`。三个玩家槽从 `ACTOR_FLAG` 起，步长 3，`LOAD_ACTOR_WORK` 把当前槽拷进 `ACT_W_*`。十个敌人槽从 `ENEMY_FLAGS` 起，步长 10。炸弹 24 槽、火焰 60 槽、埋藏物 15 槽各自一组基址。声音驱动的五声道状态沿用 T02 的字段名。

## 已命名

依据是各任务笔记，加上对应例程里的读写。

- 模式和流程：`GAME_MODE`、`KEEP_STAGE`、`AREA_NUM`、`STAGE_NUM`、`INTRO_AREA`、`SPECIAL_STAGE`、`STAGE_PHASE`、`EXIT_OPEN`、`CLEAR_PHASE`、`START_AREA`、`LIVES`、`LIVES_SHOWN`、`DEMO_MODE`、`DEMO_SLOT`
- 奖励关暂存：`BONUS_FIRE`、`BONUS_BOMBS`、`BONUS_AREA`、`BONUS_STAGE`，只被 `RUN_BONUS_STAGE` 保存和恢复
- 玩家：`ACTOR_INDEX` 和步长 3 的 `ACTOR_FLAG` 到 `ACTOR_SPDHI`，工作副本 `ACT_W_FLAG` 到 `ACT_W_SPDHI`，以及 `ACT_PASSBOMB`、`ACT_PASSWALL`、`ACT_REMOTE`、`ACT_SPEED`、`ITEM_*`、`KNOCK_*`、`FLAME_DIR`、`ACTOR_HELD`、`ACTOR_NEW`
- 敌人、出生和脚本：`ENEMY_*`、`PARADE_IDX`、`TYPE10_*`、`BURST_*`、`TYPE4_*`、`DRAW_PHASE`、`SCRIPT_FLAG`
- 炸弹和火焰：`FUSE_LOCK`、`BOMB_*`、`RING_*`、`FLAME_*`、`RAY_LEFT`、`BLAST_*`、`BURIED_*`
- 地图和画面指针：`CELL_COL`、`CELL_ROW`、`MAP_PTR`、`DATA_PTR`、`DATA_PTR2`、`PPU_ADDR`、`PAL_SRC`、`TILE_GFX`、`TILE_MAP`、`TILE_ATTR`、`PPU_RUN_CTRL`、`RLE_*`、`MAP_BYTE`
- 精灵：`SPR_*` 给 `DRAW_METASPRITE`，`OAM_Y` / `OAM_TILE` / `OAM_ATTR` / `OAM_X` 和三个 OAM 页基址
- 远调用保存：`FAR_A`、`FAR_X`、`FAR_Y`、`FAR_RET`、`FAR_TMP`、`FAR_X2`。全程序只有 `FAR_CALL` 读写
- 声音：T02 列出的 `SND_*`。另外 `SND_BGM_LATCH`、`SND_FADE_ACC`、`SND_MASTER0`、`SND_CH_RUN`、`SND_CMD_X` 是从 `SND_RUN_BGM` 和 `SND_SET_FADE` 读出来的
- 分数、密码、时钟、标题、职员表、关前卡：`TOP_NAME`、`TOP_SCORE`、`SCORE_NOW`、`PASS_*`、`CLOCK_*`、`TITLE_*`、`CREDITS_*`、`MATCH_0`–`MATCH_2`、`WINS_GOAL`、`MENU_*`
- 队列和软块：`TILE_COL`、`TILE_ROW`、`TILE_PAL`、`TILE_CHR0`–`TILE_CHR3`、`LAYOUT_ID`、`LAYOUT_VAR`、`SOFT_COUNT`、`TILESET`、`POWER_STAGE`

`q.py stats`：RAM 385 个已命名（含寄存器），113 个仍是占位名。

## RAM 变量提议

本任务就是命名任务，没有再往外推的地址。

## 疑问 / 待确认

下面这些保留占位名。没有把握写成一个名字。

- `Z_06`–`Z_0F`：bank 2 的乘法和音高运算把它们当临时量。`Z_08`/`Z_09` 在声音里是一对指针，其它地方也会占用，所以没有收成 `SND_` 名字。
- `Z_2A`、`Z_2B`、`Z_2C`：多处计数器。区介绍倒计时、软块配额、固定出生的下标都写 `Z_2A`，不是同一个变量。
- `W_0200`：`CLEAR_LOW_RAM` 用它清一页，没有单独含义。
- `W_0209`、`W_020B`–`W_0212`、`W_021D`、`W_0222`、`W_0227` 以及 `W_024D` 到 `W_038C` 里还空着的声音字节：能看出属于五声道状态或 APU 镜像，但命令和字段的对应没有逐个核对，T02 也没有给名字。
- `W_04CA`、`W_0500`、`W_051D`、`W_052A`、`W_0533`–`W_0535`、`W_053A`、`W_0543`–`W_054D`、`W_055B`、`W_0561`、`W_0562`：有引用，笔记里没有独立含义。`W_0543` 起应是 `PASS_DEC` 的后续字节，没有单独访问就不另命名。`W_055B` 只看到 `INIT_STAGE_CLOCK` 写成 0。
- `X_62E4`、`X_62E5`：夹在 `ENEMY_STEP` 和 `PARADE_IDX` 之间，本轮没有找到稳定用途。
- `ZP_FF`：`CLEAR_LOW_RAM` 不停在 `FC`–`FF`。`SND_SET_FADE` 在乐曲号是 `0C` 时读这个字节当作返回值。不能从源码证明上电后这里一定是 `FFh`。
- `ENEMY_TYPE` 的说明沿用 T05：死亡后类型改成 `11h`，旧类型留在 `ENEMY_PHASE`。这和「`ENEMY_PHASE` 是 AI 状态」叠在同一字节上，死亡路径会改写它。
- `ATTR_KEEP` / `ATTR_NEW` 是 `QUEUE_TILE` 合并属性时的两个掩码，具体哪几位留给哪一块，没有逐位算完。
- `FLASH_ZERO` 只有 `SET_ACTOR_FLASH` 写入 0，没有读。

`S7_D81F` 仍未命名，不在本任务范围。

## 工具问题

无。`tools/check.sh` 通过。日版指针提示 `US 5:B14B` / `5:B15B` 是原来的 note，不是这次命名引起的。

## check.sh 结果

```
== db lint
lint: 0 problems
== regenerate
IF REGION_JP blocks 195
  note: pointers: US 5:B14B does not apply to JP (5:B14B holds $3E00)
  note: pointers: US 5:B15B does not apply to JP (5:B15B holds $2062)
== build us
OK: identical to Bomberman II (USA).nes
== build jp
OK: identical to Bomberman II (Japan).nes
== relocation test
  us shift 1: quick        OK (1566 frames)
CHECK PASSED
```
