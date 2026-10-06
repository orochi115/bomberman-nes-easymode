# T04-game-b：主游戏逻辑（下半）

## 范围
bank 5 的 `$A000-$BFFF`（约 85 个例程）。

## 提示
- 先读 `harness/notes/glossary.md` 和 `harness/notes/T01-core.md`（内核的名字已经确定）。
- bank 5 从固定 bank 通过 `FARCALL 5, ...` 进入。用 `q.py xref` 找入口，从入口往下读。
- 可能包含：玩家移动、炸弹、火焰、道具、敌人管理、地图生成、关卡开始和结束、计分、计时器。
- 运行时观察：`tools/trace.py us --scenario stage0 --frames 2500 --watch XXXX`。

## 任务
1. 命名范围内所有 `S5_*`，写块注释；命名有意义的 `L5_*` 和 `D5_*` 数据表，并说明表格式。
2. 处理范围内的指针嫌疑项（`tools/suspects.py us --bank 5`，只处理地址在 `$A000-$BFFF` 的）。
3. RAM 提议写进笔记。只在本范围用、意义明确的可以直接命名，但先 `q.py ram` 确认没有别处使用。
4. 笔记：`harness/notes/T04-game-b.md`。
