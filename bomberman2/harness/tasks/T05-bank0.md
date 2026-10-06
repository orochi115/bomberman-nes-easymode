# T05-bank0：bank 0（敌人行为 / 过场？）

## 范围
bank 0 全部，约 38 个例程，以及大量数据（精灵组合表等）。WRAM `$6200-$62FF` 被大量使用，像是敌人对象表。

## 提示
- 先读 `glossary.md`、`T01-core.md`。
- 很多敌人只在后面的区出现，覆盖不全：`tools/trace.py` 用 `--scenario stage0` 到 `stage5` 观察。
- 日版和美版在这个 bank 差异最大（大量 `IF REGION_JP`）。在笔记里说明差异是什么（文字、精灵数据、逻辑？）。

## 任务
1. 命名所有 `S0_*` 并写块注释；精灵和动画数据表要说明格式，并命名主要的表。
2. 处理指针嫌疑项（`tools/suspects.py us --bank 0`），这个 bank 的表里指针很多。
3. 对象表的字段（`X_62xx`）在笔记里整理成结构说明（偏移、含义），作为 RAM 提议。
4. 笔记：`harness/notes/T05-bank0.md`。
