# 验收：worker 疑问清单逐条处理

## 工具问题（全部已修）

| 来源 | 问题 | 处理 |
|---|---|---|
| T01 | 并行调用 db.py 互相覆盖分片 | db.py 加文件锁 |
| T04 | check.sh 管道没有 pipefail，merge 崩溃仍显示 PASSED | 加 pipefail；merge 对 db 错误退出码 2 |
| T04、T05 | 日版在映射建立前按美版地址读 db 指针，导致 IndexError 或误报冲突 | 指针表跳过 0000/FFFF；越界改为冲突提示；美版键对不上日版只记 note |
| T05 | pointer_roles 重复调用时 conflicts 累加 | 每次调用清空 |
| T10 | lo 指针的高字节映射不到日版时崩溃 | region_key 返回 None 时跳过该条 |
| T10 | unname 删不掉 code 条目 | unname 覆盖 code/notptr；run.sh 收集 code 分片 |

## 内容问题（本轮已处理）

- 区 5 介绍帧表 `5:AEC4`：8 个字，T04 因工具 bug 留了 notptr → 已声明为指针，notptr 已删除。
- 对战结算表 `VS_RESULT_SPR_PTR`（美版）→ 已声明。
- 日版 `STAGE_LAYOUT_PTR`（`jp:4:BBDF`）有 4 个裸字（T06 疑问）→ 已声明 14 个字。
- `jp:5:AE46`：T10 把坐标表误声明为指针 → 已删除，改为 notptr。
- `jp:2:A2A8`：被误标为代码的声音数据 → 已删除。
- 声音命令 D9/DD/DE/E1/E2/EB（T02 疑问）→ 已命名 `SND_CMD_RESTART`、`SND_CMD_DD`、`SND_CMD_JUMP`、`SND_CMD_E1`、`SND_CMD_E2`、`SND_CMD_TRANSPOSE_REL`。
- 多用途零页（T08 疑问）：
  - `$06-$0F` 是声音驱动专用，改为 `SND_TMP*`、`SND_ENV_PTR`、`SND_VECTOR`、`SND_ARG`。
  - `$2A-$2C` 改为 `TEMP4`-`TEMP6`。
  - `$1C-$1E`、`$22/$23` 原先按单一用途命名，改为中性名 `TEMP1`-`TEMP3`、`DEST_PTR`。
- `SND_STEP_STREAM`（T08 时还未命名）→ 已命名。
- `SFX0A_PROG` 的 `LDA abs,X`（T09 疑问）：两版的操作数差别正好等于固定 bank 的位移，所以是真实的地址操作数，代码判断成立。这条指令的结果被下一条 `TXA` 覆盖，是无效读取，不影响行为。
- 日版 `7:FFF0`、`4:8653` 的嫌疑项 → notptr（卡带标识尾字节、图块号）。

## 结论正确、无需处理

- `$12` 是 `OAM_READY` 而不是暂停（纠正了 Data Crystal 的说法）。
- `READ_JOY_PROBE` 的 `$10/$20` 是 NES Four Score 的签名字节，美版用它判断是否接了四人连接器（模式 2 需要）。
- 走不到的代码（`ENTER_Z49_1` 后的 JMP、`NEXT_RNG` 后的清零段、`MODE_TO_AREA` 之后的字节）：保持原样，注释已说明。

## 留作后续（需要玩游戏或看画面才能确认）

- 敌人类型号对应的名字（T05）、道具类型 `$0B`/`$80`-`$83`（T01/T02/T06）、地图字节的碰撞含义（T03/T06）。
  可以用 `trace.py --shot` 加 `stage*` 场景截图，逐个对照。
- 曲目 `$1C`/`$1D` 对应的画面（T02）。
- 未命名的声音 RAM 字节 `W_0209`-`W_038C`（T08）：需要逐条命令核对字段。
- `PASS_WORDS` 的字模、日版职员表假名（T03/T05）。
