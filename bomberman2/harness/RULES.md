# Bomberman II 反汇编：Agent 操作规范

你在为 NES 游戏《Bomberman II》（MMC1，8×16K PRG）的反汇编源码做**可读性**工作：给例程/数据/RAM 变量命名、写注释、确认指针。源码已经能逐字节重建美版和日版 ROM，这个性质任何时候都不能破坏。

## 1. 绝对规则

1. **不要直接编辑生成的源码**：`bank*.asm`、`macros.asm`、`vars.asm` 和 `db/jpmap.tsv` 都由 `tools/merge.py` 生成，会被覆盖。
   所有修改都只能通过 `tools/db.py` 写进数据库（`db/*.d/<任务名>.tsv`）。
2. **不要修改** `tools/`、`make.sh`、`bman2.asm`、`nes_header.asm`、`consts.asm`、`nesregs.asm`、`db/*.tsv`（无 .d 的主文件）和别的任务的分片。
   如果发现工具有 bug，写进笔记的「问题」一节，不要自己修。
3. **结束前必须运行 `tools/check.sh`**，并且看到 `CHECK PASSED`。失败就修正你的 db 条目，直到通过。
4. **不要编造**。注释只写从代码、数据或运行结果中能确认的事实。
   - 有把握但未完全验证的，在注释里用 `?` 标出，例如 `; ? enemy speed table`。
   - 不确定的放进笔记的「疑问」一节，不要写进源码。
5. 不要使用 git 提交、切换分支或改写历史，也不要访问网络。只在当前目录工作。
6. 每个任务有自己的范围（bank 或地址段）。范围外的东西只读不改；需要改的写进笔记，交给验收者。

## 2. 工具

权限是白名单。允许的只有：`python3 tools/*`、`tools/*.sh`、常用只读命令（ls、cat、grep、head、tail、wc、sort、awk、`sed -n`），以及编辑 `harness/notes/` 下的文件。其他命令会被拒绝，而被拒绝会中断你当前这一轮。所以：
- **每次只运行一条命令**，不要用 `&&`、`;` 把多条拼在一起；
- 不要在命令里展开环境变量。
- 读源码优先用文件读取工具或 `q.py`。

在仓库的 `bomberman2/` 目录下运行（`BM2_TASK` 已由 `harness/run.sh` 设好）：

| 命令 | 用途 |
|---|---|
| `python3 tools/q.py show NAME` | 查看例程或表的源码（含上方注释） |
| `python3 tools/q.py xref NAME` | 谁引用了 NAME（行号、所在例程、代码） |
| `python3 tools/q.py calls NAME` | 例程调用了什么、读写了哪些 RAM |
| `python3 tools/q.py ram NAME` | RAM 变量被哪些例程读（R）、写（W） |
| `python3 tools/q.py todo --bank N` | 未命名的例程和 RAM，按引用数排序 |
| `python3 tools/q.py stats` | 进度统计 |
| `python3 tools/db.py name KEY NAME ["说明"]` | 命名（KEY 可以直接写占位名，如 `S5_8123`、`Z_4B`） |
| `python3 tools/db.py comment KEY '>' "文本"` | 在 KEY 上方加块注释（`\n` 换行） |
| `python3 tools/db.py comment KEY ';' "文本"` | 在 KEY 这一行加行尾注释 |
| `python3 tools/db.py pointer KEY word N` 等 | 声明运行时没跑到的指针（见 `db/pointers.tsv` 表头） |
| `python3 tools/db.py notptr KEY "理由"` | 嫌疑项确认不是指针 |
| `python3 tools/suspects.py us --bank N` | 还没转成标签的疑似指针 |
| `tools/regen.sh` | 改完 db 后重新生成源码，`q.py` 才能看到新名字 |
| `tools/check.sh` | 自检：lint、重新生成、美日两版逐字节一致、重定位测试 |
| `python3 tools/trace.py us --scenario normal --frames 2500 --watch 004B` | 在模拟器里观察：谁写了某个 RAM |
| `python3 tools/trace.py us --frames 2000 --break 7:C5E4 --history 30` | 断点，打印之前执行过的指令 |
| `python3 tools/trace.py us --scenario stage3 --frames 2400 --shot /tmp/x.png` | 截图 |

`trace.py` 的场景：`attract`（标题和演示）、`normal`、`vs`、`battle`、`continue`、`menu_random`、`stage0`–`stage5`（第 N 区，各 8 关）。

## 3. 地址和名字

- **占位名**：
  - `S5_8123`：bank 5、地址 $8123 的例程（被 JSR 或 FARCALL 调用）。
  - `L…`：跳转目标。
  - `D…`：数据。
  - `J` 前缀：只在日版存在的代码或数据，例如 `JS5_8123`（地址是日版地址）。
  - `Z_xx`：零页变量。
  - `W_xxxx`：$0100–$07FF 的 RAM 变量。
  - `X_xxxx`：$6000–$7FFF 的 WRAM 变量。
  - **RAM 名都按美版地址命名**。日版地址不同的变量，在 `vars.asm` 的 `IF REGION_JP` 块里，由工具自动给出日版的值。
- **bank 7** 固定映射在 $C000–$FFFF，bank 0–6 切换映射到 $8000–$BFFF。
  - 跨 bank 调用写作 `FARCALL bank, 目标`。
  - `BANK_SWITCH` 等例程负责切换 bank。
- **命名风格**：全大写，用下划线分隔。
  - 动词开头表示例程，如 `DRAW_STATUS_BAR`、`UPDATE_ENEMIES`；名词表示数据和变量，如 `ENEMY_SPEED_TABLE`、`PLAYER_X`。
  - 同一模块用统一前缀，如 `SND_`、`PPU_`、`ENEMY_`。
  - 名字最长 40 字符。参考第一代的源码 `../bman.asm` 和 `../vars.asm`，已有的叫法尽量沿用，例如 `FRAME_CNT`、`STAGE`、`JOYPAD1`。
  - **共享约定写在 `harness/notes/glossary.md`**：命名前先读；你确立了新前缀或新术语，就追加进去。
- **注释**：源码注释用英文，简洁。
  - 每个命名的例程上方写一个块注释（1–4 行）：做什么，输入（A/X/Y/变量），输出，副作用。
  - 数据表写清楚：格式、每项大小、条目数、谁在用。
  - 不要逐行翻译指令。只在不显然的地方加行尾注释。

## 4. 指针（重要）

工具已经把运行中用到的指针换成了标签，但**没执行到的代码和数据里还可能藏着写死的地址**。一旦重定位，这些地址就会出错。

- 理解了一张表的格式之后，如果其中有地址，用 `db.py pointer` 声明。如果目标在别的 bank，加 `bank=N`。
- 处理范围内 `tools/suspects.py` 列出的嫌疑项：要么声明为指针，要么用 `db.py notptr` 写明理由（例如「图块数据」「坐标表」）。

## 5. 笔记

每个任务在 `harness/notes/<任务名>.md` 写笔记（中文），包括以下几节：

1. **概述**：这段代码或数据是做什么的，主要流程。
2. **已命名**：一句话列表，说明依据。
3. **RAM 变量提议**：地址、提议名、依据（哪个例程怎么用它）。RAM 正式命名由专门任务统一做，其他任务只提议。
   例外：只在本任务范围内使用、含义明确的变量，可以直接命名。
4. **疑问 / 待确认**。
5. **工具问题**（如果有）。
6. **check.sh 结果**：贴最后几行输出。

## 6. 完成标准（验收者会逐条检查）

- [ ] `tools/check.sh` 通过。
- [ ] 范围内的每个 `S` 例程都有名字和块注释，有意义的 `L` 标签和数据表也都命名了。
- [ ] 范围内的指针嫌疑项全部处理（pointer 或 notptr）。
- [ ] 笔记完整，疑问如实写出。
- [ ] 抽查的名字和注释与代码行为一致。不一致的条目会被打回。
