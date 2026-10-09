# T11-eu：欧版 Dynablaster 差异

在三区域源码生成之后执行。`make.sh eu` 已经和 `Dynablaster (Europe).nes` 逐字节一致。

## 范围
`IF REGION = 2`、`ELIF`、`IF REGION_JP OR REGION = 2` 块。欧版 bank 0 接近日版，bank 7 和文字接近美版。PAL 音乐速度、角色逻辑和 DYNABLASTER 标题图是欧版自己的。

## 任务
1. 还没有美/日符号的欧版入口仍使用 `E` 前缀自动名（`emit.py`）。用 `eu:b:XXXX` 键写成和日版 `T09-jp` 一样的名字。
2. 在块上方注明差异：PAL 帧计数、标题、音乐表、手柄。
3. 笔记：`harness/notes/T11-eu.md`。
