# T08-ram：RAM 变量统一命名（在 T01-T07 完成后执行）

## 范围
所有 `Z_xx`、`W_xxxx`、`X_xxxx` 占位名（`python3 tools/q.py todo`）。

## 任务
1. 读 `harness/notes/` 里各任务的「RAM 变量提议」，用 `q.py ram NAME` 核对每个变量的读写者，统一命名。
   命名风格以 `glossary.md` 为准。
2. 数组和结构（例如每个对象若干字节）：命名基地址，在块注释里说明字段偏移。
   字段可以命名为 `基名_字段`，只有确有独立访问的字段才单独命名。
3. 每个命名的 RAM 都写一句说明（`db.py name KEY NAME "说明"` 的第三个参数）。
4. 完全无法确定的保留占位名，在笔记里列出原因。
5. 笔记：`harness/notes/T08-ram.md`。
