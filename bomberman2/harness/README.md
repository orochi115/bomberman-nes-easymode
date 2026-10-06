# grok harness：Bomberman II 可读性工作

源码由 `tools/merge.py` 根据两份 ROM、覆盖率数据和 `db/` 生成，美日两版都逐字节一致。可读性工作（命名、注释、确认指针）全部通过 `db/` 完成，所以任何时候都可以重新生成和校验，生成的 asm 不会被手改坏。

## 目录

| 路径 | 内容 |
|---|---|
| `RULES.md` | 给 agent 的操作规范（每个任务都会附带） |
| `tasks/Txx-*.md` | 任务说明：范围、已知事实、交付物 |
| `notes/` | agent 的笔记本（每个任务一份，加上共享的 `glossary.md`） |
| `logs/` | 运行日志 |
| `run.sh` | 在独立 git worktree 里运行一个任务 |

## 运行顺序

1. `T01-core`：单独先跑。它会建立 `glossary.md` 和内核名字，后面的任务都依赖这些。
2. 验收 T01 并提交之后，`T02`-`T07` 可以并行（各自在自己的 worktree 里，db 分片互不冲突）。
3. 全部验收后跑 `T08-ram`，再跑 `T09-jp`。

```bash
cd bomberman-nes/bomberman2
harness/run.sh T01-core
```

可选环境变量：
- `BM2_MAX_TURNS`：默认 400。
- `BM2_WORKTREES`：worktree 位置，默认 `../bm2-work`（相对仓库根目录）。

## 权限（最小化）

`run.sh` 不使用 `--always-approve`，而是这样限制 grok：

- `--permission-mode dontAsk`：只运行白名单里的操作，其他一律拒绝。
- 允许：`python3 tools/*`、`tools/*`，以及编辑 `harness/notes/**`。读文件和只读 shell 命令是内置允许的。
- 禁止：git、curl、wget、rm，以及网络搜索。
- `--sandbox workspace`：由内核强制，只能写自己的 worktree 和临时目录。

grok 修改数据库只能通过 `tools/db.py`，它会校验名字、只写本任务的分片，不允许覆盖别的任务。

## 验收（Claude 负责）

每个任务结束后，`run.sh` 会把以下结果拷回主目录并运行 `tools/check.sh`：
- `db/*.d/<任务>.tsv`
- `harness/notes/<任务>.md`

验收者再做这些：
1. `tools/check.sh --full`：两个区域，shift 1 和 256，全部场景。
2. 审阅 db 分片：抽查名字和注释与代码行为是否一致，对照 `q.py show`、`trace.py`。
3. 检查指针嫌疑项是否处理完（`tools/suspects.py`）。
4. 合格就提交；不合格就写意见，追加到任务文件里重跑，或者手工修正。
