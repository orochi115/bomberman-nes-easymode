# T10-pointers：清理全部指针嫌疑和未识别代码（美版 + 日版）

## 背景
重定位测试只检查运行过的路径。没执行过的代码里，用立即数拼出来的地址（`LDA #lo / STA Z_xx / LDA #hi / STA Z_xx+1`）和数据表里的地址，都必须变成标签表达式，否则改代码后它们会指错。

## 范围
- `python3 tools/suspects.py us` 和 `python3 tools/suspects.py jp` 列出的全部嫌疑项。
- `python3 tools/codeguess.py us` 和 `python3 tools/codeguess.py jp` 列出的「像代码的数据」。

## 怎么处理
1. **代码**：`codeguess.py` 的候选先用 `python3 tools/m6502.py us BANK ADDR 20` 读一遍反汇编。确认是代码后用 `python3 tools/db.py code b:XXXX` 声明（日版独有的用 `jp:b:XXXX`）。然后 `tools/regen.sh`，再看 `suspects.py`，会出现新的嫌疑项。
2. **立即数指针**：`imm` 行的意思是 `#lo` 在 KEY，`#hi` 在 `hi` 列。
   - 先确认目标确实是一张表或一段代码：`q.py xref` 看谁在用 Z 页指针，用 `m6502.py` 看目标字节。
   - 然后 `python3 tools/db.py pointer KEY lo HIKEY`。
   - **目标在别的 bank 时一定要加 `bank=N`**：看代码运行时映射的是哪个 bank，例如先 `LDX #&04 / JSR BANK_SWITCH`，或者由 FARCALL 进入某个 bank 的例程，再读 Z_62 等指针。bank 5 里设置 `Z_62/Z_64/Z_66` 的代码，指向的是 bank 4 的图块表（参考 `LOAD_AREA_LAYOUT`、`QUEUE_MAP_TILE` 的注释）。
3. **数据里的地址**：`word` 行是 `db.py pointer KEY word N`，split 表是 `db.py pointer KEY split HIKEY N`。确认不是指针的，用 `db.py notptr KEY '理由'`。
4. **日版**：美版键会自动映射到日版。如果 `merge.py` 输出 `note: ... does not apply to JP`，说明日版那段代码不同。去日版的对应位置（`IF REGION_JP` 块里的 `J...` 标签），用 `jp:b:XXXX` 键单独声明。
5. 每做一批就运行 `tools/check.sh`。它会拒绝声明在操作码或非立即数操作数上的指针。

## 完成标准
- `suspects.py us` 和 `suspects.py jp` 都为空，或者只剩已用 `notptr` 解释过的条目。
- `codeguess.py us/jp` 为空，或者笔记里写明了剩余候选为什么不是代码。
- 笔记：`harness/notes/T10-pointers.md`，列出声明了哪些代码和指针、依据，以及仍然不确定的项。
