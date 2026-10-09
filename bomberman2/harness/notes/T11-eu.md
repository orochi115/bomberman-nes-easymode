# T11-eu

`merge.py` 同时对齐日版和欧版到美版，写出 `db/jpmap.tsv` 和 `db/eumap.tsv`。

能对上美版或日版标签的代码沿用原来的名字。对不上的欧版地址仍是自动标签（`E` 前缀）。

`tools/emu.py` 用 NES 2.0 头偏移 12 识别 PAL，因此欧版覆盖和 shift 测试走 `eu`。

欧版 RAM 布局既不是美版也不是日版（见 `vars.asm` 的 `REGION = 2` 值；很多是美版地址减 1）。不要因为 bank 0 的代码接近日版，就沿用日版的 RAM 地址：

- `AREA_NUM` / `STAGE_NUM` = `$4A` / `$4B`（美版 `$4B/$4C`，日版 `$3D/$3E`）；`LIVES` = `$04E5`
- `ACTOR_X` / `ACTOR_Y` = `$71` / `$77`（美版 `$72/$78`，日版 `$64/$6A`）

覆盖数据先于源码：改了覆盖（`cover.py` + `covpack.py`）之后要重新生成（`tools/check.sh`）再提交，否则提交的 bank*.asm 和生成器对不上。
