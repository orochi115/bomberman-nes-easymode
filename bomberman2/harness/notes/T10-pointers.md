# T10-pointers

## 概述

美版 `suspects.py us` 与 `codeguess.py us` 均为 0。日版 `suspects.py jp` 与 `codeguess.py jp` 在本轮结束时也是 0。运行时指针已写入 `db/pointers.d/T10-pointers.tsv`，确认不是指针的项在 `db/notptr.d/T10-pointers.tsv`。日版分派表里原先被当成数据的例程用 `db.py code` 标了入口。

`tools/check.sh` 没有通过。唯一失败项是 `db/code.d/T10-pointers.tsv` 第 34 行 `jp:2:A2A8`。美版、日版 ROM 仍然逐字节一致。

## 已命名

- `JP_ENEMY_AI_LO`（`jp:0:8266`，27 字）：日版敌人逻辑入口，索引方式和 `ENEMY_AI_LO` 相同。
- `JP_ENEMY_DRAW_LO`（`jp:0:82C7`，27 字）：日版敌人绘制入口，索引方式和 `ENEMY_DRAW_LO` 相同。
- `JP_SOUND_CODE_LO`（`jp:2:8746`，13 字）：日版声音例程指针，覆盖到 `JS2_8760`。

同名美版符号已经占用 `ENEMY_AI_LO`、`ENEMY_DRAW_LO`，日版表用 `JP_` 前缀，并写进 `glossary.md`。

另外标了块注释、没有另起名字的：`jp:5:ACE3`（`Z_3D` 左移后从四组字表抄到 `Z_20`、`Z_58`、`Z_56`、`Z_54`，再跳 `L7_CCF5`；`L7_CCF5` 是 `JSR` 进 bank 4 的远调用）、`jp:5:90E3`（`jp:5:9044` 那张 16 字跳转表的目标，表本身与美版 `ITEM_HANDLERS` 同址不同内容，没有复用那个名字）。

向量 `7:FFFA` 声明为 3 个字（NMI / RESET / IRQ）。积分、对战卡、胜利计数、字幕 CHR/调色板、日版模式跳转 `jp:5:9044`、日版 `jp:5:ADDF` 等字表已在指针分片里。美版三条 lo/hi 的高字节对不上日版（`5:B24D`、`5:B573`、`5:B60C`），键写成 `us:`，避免日版合并崩溃。

`5:AD33` 的 `$910C` 是区介绍字表里错位的一对字节（低字节属上一个字，高字节属下一个字），不是单独的指针。`notptr` 必须用嫌疑列表里的键 `5:AD33`；写成 `jp:5:AD33` 时 `suspects.py` 对不上。

## RAM 变量提议

无。本任务没有新的 RAM 名。沿用已有的 `Z_20`（脚本/布局）、`Z_54`/`Z_56`/`Z_58`（布局或 metasprite）、`Z_3D`（模式或区索引）。

## 疑问

- `jp:5:AE46` 声明了 5 个字。读取点是 `LDA $AE46,Y`，Y 来自 `Z_3D` 乘 2。`Z_3D` 的实际上界没有在覆盖运行里数清，5 是按表尾推断的。
- 发射器有时把立即数 `$41` 印成 `LO(UI_META_GFX)`。同一低字节也属于 `UI_META_ATTR`（`$9641`）。以成对的高字节为准。
- `jp:2:A2A8` 来自声音流里的字 `2:A20A`（codeguess 曾报 7 字节）。字节里有 `BMI`，跟踪会走进 `2:A27E` 的非法操作码 `$80`，并在 `2:A2AB` 踩进操作数。这是声音数据，不是代码。当前它仍被标成 code，所以 codeguess 不再列出它。

## 工具问题

- 美版 `lo` 指针：低字节能映射到日版、高字节不能时，`emit.py` 在解包处崩溃（`cannot unpack non-iterable NoneType`），而不是打出 “does not apply to JP”。处理：该条只用 `us:` 键。
- `db.py unname` 的说明写会删掉该任务对 KEY 的记录，实现只重写 `symbols.tsv`、`comments.tsv`、`pointers.tsv`，不碰 `code.tsv`。`db.py code` 只会覆盖同一键，不能删除。因此错误入口 `jp:2:A2A8` 无法用允许的 `db.py` 命令去掉。按规范没有改 `tools/`，也没有手改分片。

## check.sh 结果

```
== db lint
lint: 0 problems
== regenerate
...
  db/code.d/T10-pointers.tsv:34: code entry jp:2:A2A8: 2:A27E illegal opcode 80
  db/code.d/T10-pointers.tsv:34: code entry jp:2:A2A8: 2:A2AB trace runs into operand
ERROR: 2 db entries could not be applied (see above)
== build us
OK: identical to Bomberman II (USA).nes
== build jp
OK: identical to Bomberman II (Japan).nes
CHECK FAILED
```

没有出现 `CHECK PASSED`。失败原因只有上面两条 `jp:2:A2A8`。重定位测试被跳过（`check.sh` 在 regenerate 失败后不跑 shift）。
