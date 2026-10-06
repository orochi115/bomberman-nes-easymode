# T07-gfx 图形数据（bank 1、bank 6）

## 概述

bank 1 和 bank 6 几乎全是 CHR。关卡和过场通过 `UPLOAD_CHR_RLE`（固定 bank 的 `UPLOAD_CHR_RLE`）按块数解压进 PPU；只有 `LEVEL_OBJ_TILES` 走 `UPLOAD_CHR_RAW`。

`DECODE_CHR` 一次解 **8 字节的一个位面**，一块图调用两次（先低位面，再高位面）：

- 先读 1 个控制字节，从最高位开始（`ASL`）。
- 该位为 1：再读 1 个字节，记成「当前字节」。
- 该位为 0：不读，重复当前字节。当前字节初始是 0，所以开头的 0 位写的是 0，但并不是「0 位永远写 0」。
- 8 位各写一次 `PPU_DATA`，然后把源指针加上用掉的字节数。

许多上传次数是 `FFh`（255 块）或 `40h`/`60h`，解压终点经常越过下一块的标签。那些标签是另一条上传的起点，不是上一条的结尾。下面的终点是用这段规则对美版 `EQUB` 走出来的，和 `PLAY_BG_CHR` 的 `C0h` 块正好停在 `ENDING_EXTRA_BG_CHR`、`PLAY_SPR_CHR` 的 `80h` 块正好停在 `AREA0_SPR_CHR`、`AREA5_SPR_CHR` 正好停在 `VS_BATTLE_SPR_CHR` 对得上。

### bank 1（RLE）

| 起点 | 谁上传 | 块数 | 解压后源指针停在 |
|---|---|---|---|
| `PLAY_BG_CHR` | `LOAD_AREA_CHR`、`S5_A892` → PPU `$0000` | `C0h` | `ENDING_EXTRA_BG_CHR` |
| 同上 | 通关 `S5_B0DE` | `A0h` | `$8835`（块内部） |
| `ENDING_EXTRA_BG_CHR` | `S5_B0DE` → PPU `$0A30` | `50h` | `$8DB1`（越过 `ENEMY_AREA0_CHR`） |
| `ENEMY_AREAn_CHR` | `ENEMY_CHR_PTR`，`LOAD_AREA_CHR` → PPU `$0C00` | `40h` | 都越过下一项；area0 停在 `$905A`，area1 `$91C7`，area2 `$92FE`，area3 `$949F`，area4 `$957D` |
| `ENEMY_VS_CHR` | 同上，仅当 `Z_4B` = 6 | `40h` | `$9796` |
| `MODE_BG_CHR` | `LOAD_MODE_GFX` → PPU `$0000` | `FFh` | `$A129` |
| `AREAn_INTRO_SPR` | `S5_ADA7`（区卡 `S5_ACE4`）按 `Z_4B` → PPU `$1000` | `FFh` | area0 `$A2EF`，area1 `$A5C8`，area2 `$A7E2`，area3 `$AA4F`，area4 `$AE4E`，area5 `$AFDA` |
| `INTRO_BG_CHR` | `S5_ADA7` → PPU `$0000` | `FFh` | `$B2A1` |
| `TITLE_SPR_CHR` | `S5_A237` → PPU `$1000` | `FFh` | `$B525`（下一项 `TITLE_BG_CHR` 在 `$B529`，中间 4 字节没有被这两次上传读到） |
| `TITLE_BG_CHR` | `S5_A237` → PPU `$0000` | `FFh` | `$BF73`（美版；后面到 bank 末尾的字节这次不读） |
| `ENDING_SPR_CHR` | `S5_B0DE` → PPU `$1000` | `FFh` | 用完 bank 1，再读固定 bank `7:C000`–`7:C122`（`db/shift_ignore.tsv`） |

`ENEMY_CHR_PTR` 下标 5 和 4 是同一地址（都是 `ENEMY_AREA4_CHR`）。`AREA5_CHR_IDX` 只选 0–4。

`TITLE_SPR_US_ONLY`（`D1_AF05`）是美版标题精灵流中间的一段；日版源码用 `IF REGION_JP` 跳过这些字节。它不是单独的上传。

### bank 6

| 起点 | 谁上传 | 块数 | 解压后源指针停在 |
|---|---|---|---|
| `PLAY_SPR_CHR` | `LOAD_AREA_CHR` → PPU `$1000` | `80h` | `AREA0_SPR_CHR` |
| `AREAn_SPR_CHR` | `AREA_CHR_PTR[Z_4B]` → PPU `$1A00` | `60h` | area0 `$8A02`，area1 `$8EFA`，area2 `$945E`，area3 `$97D6`，area4 `$9D17`，area5 正好是 `VS_BATTLE_SPR_CHR` |
| `VS_BATTLE_SPR_CHR` | 上表下标 6（`Z_4B` = 6） | `60h` | `$A524`（穿过 `LEVEL_OBJ_TILES`，进入 `UI_SPR_CHR`） |
| `LEVEL_OBJ_TILES` | `S5_802F` / `LOAD_4_TILES`，未压缩 | 4 块 | 表长 `$240` 字节，接到 `UI_SPR_CHR`。`D5_815B[W_04E3]<<4` 选出 9 组里的一组（偏移 `00,04,08,0C,10,14,18,1C,20`）送到 PPU `$1800` |
| `UI_SPR_CHR` | `S5_92F6`、`S5_A892`、`LOAD_MODE_GFX`、`S0_B052` → PPU `$1000` | `FFh` | `$B027`。后面还有少量 `EQUB`，再是 `FILLTO` |

`S5_A237` 是标题（`SHOW_FRONT` → `S5_A18E`）。`S5_A892` 被模式选择 `S5_A80F` 和 `S5_AA6A` 使用，背景用的是 `PLAY_BG_CHR` 而不是标题图。`LOAD_MODE_GFX` 的调用点包括奖励关 `S5_9F5E`（画面上有 BONUS STAGE）、`SHOW_VS_RESULT`（`S5_B209`）和 `SETUP_BY_MODE` 的三个过关前画面。区卡是另一条路：`MAYBE_AREA_CARD` → `S5_ACE4` → `S5_ADA7`。

## 已命名

- `PLAY_BG_CHR`：关卡公共背景，`C0h` 块到 PPU `$0000`；终点与 `ENDING_EXTRA_BG_CHR` 重合。
- `ENDING_EXTRA_BG_CHR`：通关补上传 `50h` 块到 PPU `$0A30`。
- `ENEMY_AREA0_CHR`–`ENEMY_AREA4_CHR`、`ENEMY_VS_CHR`：`ENEMY_CHR_PTR` 指向的敌人图，`40h` 块到 PPU `$0C00`。原先的 `*_BG_CHR` 容易看成地图块，和 `LOAD_AREA_CHR` 的注释不符，已改名。
- `MODE_BG_CHR`：只被 `LOAD_MODE_GFX` 整页上传到 PPU `$0000`。原先叫 `CARD_BG_CHR`，区卡实际用的是 `INTRO_BG_CHR`。
- `AREA0_INTRO_SPR`–`AREA5_INTRO_SPR`、`INTRO_BG_CHR`：区卡，`S5_ADA7`，各 `FFh` 块。
- `TITLE_SPR_CHR`、`TITLE_SPR_US_ONLY`、`TITLE_BG_CHR`：标题，`S5_A237`。
- `ENDING_SPR_CHR`：通关精灵，并跨进固定 bank。
- `PLAY_SPR_CHR`、`AREA0_SPR_CHR`–`AREA5_SPR_CHR`、`VS_BATTLE_SPR_CHR`：`LOAD_AREA_CHR` 的精灵页。
- `LEVEL_OBJ_TILES`：唯一的未压缩图块表。
- `UI_SPR_CHR`：菜单、模式、滚动字幕等画面的精灵页，`FFh` 块到 PPU `$1000`。

bank 1、6 没有 `S` 例程。

## 解压例程注释提议（范围外，不写进 bank 7）

`DECODE_CHR` 现有注释写「解进 `Z_1E`」。`Z_1E` 是 `UPLOAD_CHR_RLE` 的剩余块数；字面量记在 `Z_1C`，控制位在 `Z_1D`，输出直接进 `PPU_DATA`。建议改成：

> Decode 8 bytes of one CHR bitplane from (Z_20) into PPU_DATA.
> Control byte in Z_1D, MSB first. A 1-bit reads a new byte into Z_1C; a 0-bit repeats Z_1C (starts at 0).
> UPLOAD_CHR_RLE calls this twice per tile (low plane, then high plane). Y = tile count.
> The upload from ENDING_SPR_CHR reads past bank 1 into 7:C000-7:C122.

## RAM 变量提议

本范围没有新的 RAM。上传协议沿用已有的 `Z_20`（源）、`Z_22`（PPU 地址）、`Z_1C`（RLE 当前字节）、`Z_1D`（控制位）、`Z_1E`（剩余块数）、`Z_4B`（区，用来选表）。`W_04E3` 是 `LEVEL_OBJ_TILES` 的组号，由 bank 5 写入。

## 疑问 / 待确认

- `ENEMY_CHR_PTR` 和 `AREA_CHR_PTR` 的下标 6 只有 `Z_4B` = 6 才会被 `LOAD_AREA_CHR` 读到。通关会把 `Z_4B` 设成 6，但通关 CHR 是 `S5_B0DE` 自己上传的。没有追到对战模式是否以区号 6 调用 `LOAD_AREA_CHR`。名字保留 `ENEMY_VS_CHR` / `VS_BATTLE_SPR_CHR`。
- `FFh` 次上传会把后面几块的字节再解一遍。画面上用不用到这些高位图块没有逐格对过。
- 通关额外背景的 PPU 地址是 `$0A30`，比 `A0h` 块结束的 `$0A00` 晚 3 块。没有再查这 3 块是不是故意留白。
- 美版 `TITLE_BG_CHR` 的 255 块停在 `$BF73`，`UI_SPR_CHR` 停在 `$B027`，后面到 `FILLTO` 之前还有几个字节。没有别的指针指向它们。

## 工具问题

无。

## check.sh 结果

```
== db lint
lint: 0 problems
== regenerate
  pass 1: aligned 127235 bytes, labels linked True, facts copied 1
  pass 2: aligned 127235 bytes, labels linked False, facts copied 0
IF REGION_JP blocks 208
== build us
OK: identical to Bomberman II (USA).nes
== build jp
OK: identical to Bomberman II (Japan).nes
== relocation test
  us shift 1: quick        OK (1566 frames)
CHECK PASSED
```
