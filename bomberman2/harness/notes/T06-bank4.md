# T06-bank4

## 概述

Bank 4 前半是画面数据，`$B800` 起是关卡装载和名字表解压。Bank 3 全是乐曲流，没有代码。

关卡图块按区（0–6）分成三张表，由 `LOAD_AREA_LAYOUT` 写入 `Z_62`、`Z_64`、`Z_66`：

- `*_META_GFX`：每个图块 id 4 个 CHR 字节。
- `*_META_ATTR`：每个字节两个 id，低半字节在前，值 0–3。`PAINT_LAYOUT_STRIP` 把 id 右移一位再取半字节。
- `*_META_MAP`：每个 id 1 字节。`COPY_LAYOUT_CELL` 用这个字节写入活动地图。

压缩布局（关卡、区介绍、密码、游戏结束、模式卡片）格式相同。块首 32 个字是相对偏移，加到块首地址上。每条解出 16 个 id，只用前 15 个：`Z_1C` 是地图列（0–31），格子序号减 2 是地图行，行 ≥ 13 时 `COPY_LAYOUT_CELL` 不写地图。位流里 1 表示下一个字节是 id，0 表示 id 为 0。

`PICK_STAGE_LAYOUT` 在 `Z_49` 为 0 时读 `LAYOUT_VARIANT`（6 区 × 8 关，每项 0 或 1）到 `W_04E1`，再用 `area*2+该位` 查 `STAGE_LAYOUT_PTR`（7 区 × 2）。区 6 两个槽都指向 `AREA6_LAYOUT`。区 5 的 A 布局嵌在区 4 的 A 布局里面。`DECODE_LAYOUT` 结束时跳到 `L7_CF6F`，那里再调 `S5_8F6E`：`W_04E1` 非 0 时按玩家 X 设置横向滚动。

`PLACE_SOFT_AND_BOMBS` 先把若干格写成地图字节 1，避免软块落到出生点，散完再写回 0。故事模式 3 格，模式 1 再加 3 格，模式 2 再加 7 格。软块个数来自 `SOFT_BLOCK_QUOTA`（区×8+关）；`Z_49` 非 0 时改成 `$32`。空格是地图字节 0。软块写入 `$20` 并排队图块 `$39`。炸弹：故事模式 1 个，标志是 `W_04E3` 带上 bit7，再放一个地图字节 `$22` 的软块；其它模式 5 个 `$80`、5 个 `$81`，模式 2 再加 5 个 `$8B`。落点行来自 `SOFT_ROW_TABLE`（随机低半字节，行号 1–11）。

名字表 RLE：`UPLOAD_RLE_NAMETABLE` 从 `Z_20` 写 `$400` 字节。`$FF`、次数、图块，图块重复次数+1 次。然后从 `Z_24` 拷 64 字节属性到 PPU 和 `ATTR_BUF`。美版标题第二屏从列 `$20` 起，第一屏从列 0 起。

调色板都是给 `COPY_PAL_ROWS` 用的 16 字节一组。`AREA_BG_PAL` 是 7 区 × 16，`L7_CB14` 用 `Z_4B*16` 做关卡背景。区介绍、标题、模式卡片、结局另有各自的表。

Bank 3 是 `SND_BGM_TABLE` 里 bank 字节为 3 的曲子，id `$14`–`$1D`：对战关、道具、出口、结局、工作人员、模式选择、胜、负、对战结算、短音。每曲 5 个声道，顺序与 `SND_RUN_BGM` 写入 `W_0213` 的顺序一致。字节小于 `$D0` 是音符；`DF` 后一个字是短语地址；`E0` 从短语返回。

## 已命名

依据是 bank 4 这些例程本身，以及 bank 5 / bank 7 里把指针装进 `Z_62`/`Z_64`/`Z_66`/`Z_20`/`Z_16` 的调用。

- 装关：`LOAD_AREA_LAYOUT`、`DECODE_LAYOUT`、`UNPACK_STRIP_BYTES`、`PAINT_LAYOUT_STRIP`、`PICK_STAGE_LAYOUT`
- 撒软块和炸弹：`PLACE_SOFT_AND_BOMBS`、`SEAL_PLACEMENT_CELLS`、`PLACE_BOMB_PICKUPS`、`PLACE_ONE_PICKUP`，以及三组 seal/open
- 名字表：`DRAW_NAMETABLE_RLE_1`、`DRAW_NAMETABLE_RLE_2`、`SET_NAMETABLE_XY`、`UPLOAD_RLE_NAMETABLE`
- 图块：`AREA0_META_*`–`AREA6_META_*`，`CARD0_META_*`–`CARD5_META_*`，`UI_META_*`，`PASS_META_*`，`END_META_*`
- 布局：`AREA0_LAYOUT_A/B`–`AREA6_LAYOUT`，`CARD0_LAYOUT`–`CARD5_LAYOUT`，`BATTLE_CARD_LAY`，`VS_CARD_LAY`，`VS_RESULT_LAY`，`STORY_CARD_LAY`，`GAME_OVER_LAY`，`PASSWORD_LAY`，`WIN_COUNT_LAY`，`OPENING_LAYOUT`
- 调色板：`AREA_BG_PAL`，`CARD0_BG_PAL`–`CARD5_BG_PAL`，`CARD_SPR_PAL`，`TITLE_PAL`，`UI_BG_PAL`，`MODE_SPR_PAL`，`STORY_MODE_PAL`，`ENDING_BG_PAL`，`ENDING_SPR_PAL`
- 小表：`AREA_GFX_PTR`、`AREA_ATTR_PTR`、`AREA_MAP_PTR`、`STAGE_LAYOUT_PTR`、`LAYOUT_VARIANT`、`SOFT_BLOCK_QUOTA`、`SOFT_ROW_TABLE`、三组 `*_SEAL_COL/ROW`
- Bank 3：`BGM_BATTLE_CH0`–`CH4` 以及各曲的 `CH*` 和 `BGM_PH_*`。曲号对应 `BGM_BATTLE_HDR`、`BGM_TITLE_HDR`、`BGM_ITEM_HDR`、`BGM_EXIT_HDR`、`BGM_CREDITS_HDR`、`BGM_AREA6_HDR`、`BGM_MODE_HDR`、`BGM_WIN_HDR`、`BGM_LOSE_HDR`、`BGM_SCENE_HDR`、`BGM_STING_HDR`

## RAM 变量提议

本段没有独占、可以单独改名的 RAM。下面只提议。

| 地址 | 提议名 | 依据 |
|---|---|---|
| `Z_62`/`Z_63` | 图块 CHR 指针 | `LOAD_AREA_LAYOUT` 和各画面装入 `*_META_GFX` |
| `Z_64`/`Z_65` | 图块地图字节指针 | `COPY_LAYOUT_CELL` 用 id 作下标读 |
| `Z_66`/`Z_67` | 图块属性指针 | `PAINT_LAYOUT_STRIP` 取 2 bit |
| `W_04D1` | 一条布局解出的 16 个 id | `UNPACK_STRIP_BYTES` 写入，只画前 15 个 |
| `W_04E1` | 布局变体 / 横滚标志 | `PICK_STAGE_LAYOUT` 写入，`S5_8F6E` 读取 |
| `W_04E2` | 本关已放软块计数 | 初始写成配额，每放一个加一；bank 5 里会减 |
| `W_04B0`–`W_04B4` | 当前格的属性和 4 个 CHR | 交给 `QUEUE_TILE` |
| `W_0527`/`W_0528` | RLE 上传时保存的列、行 | 只在美版 `SET_NAMETABLE_XY` 使用 |

## 疑问 / 待确认

- 地图字节 `$00`、`$01`、`$20`、`$21`、`$22` 只确认了谁写入、谁把它当成空格。碰撞含义要到读活动地图的代码里才能定。
- 炸弹标志 `$80`、`$81`、`$8B` 以及 `W_04E3|80h` 分别是哪种道具，这里只看到写入 `W_04EB`。
- `S5_8F6E` 用 `Z_72`/`Z_75` 算滚动。本任务没有改那段，只确认它读 `W_04E1`。
- 日版 `STAGE_LAYOUT_PTR` 里还有三处未变成 `EQUW` 的字：`08 A1`、`BA A1`、`2D A2`。按美版同一张表，它们应是区 1B、区 2B、区 4A 的布局地址，但 `jp:` 指针没有全部落到这些字节上。已转成 `EQUW` 的日版项指向和美版同名的布局标签。
- 声道 0–4 哪个是方波、三角、噪声，本 bank 看不出来。

## 工具问题

无。

## check.sh 结果

```
== db lint
lint: 0 problems
== regenerate
  pass 1: aligned 127235 bytes, labels linked True, facts copied 1
  pass 2: aligned 127235 bytes, labels linked False, facts copied 0
IF REGION_JP blocks 207
== build us
OK: identical to Bomberman II (USA).nes
== build jp
OK: identical to Bomberman II (Japan).nes
== relocation test
  us shift 1: quick        OK (1566 frames)
CHECK PASSED
```
