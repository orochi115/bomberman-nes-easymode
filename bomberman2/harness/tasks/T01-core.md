# T01-core：固定 bank 内核（第一个任务，独立执行）

## 范围
bank 7 的 `$C000-$D7FF`（`bank7.asm` 中 `FILLTO &D800` 之前的部分），约 70 个例程。

## 已知事实（可以直接用）
- `RESET`、`NMI`、`IRQ` 是中断向量入口；`FAR_CALL` 是跨 bank 调用（`JSR FAR_CALL` 后跟 bank 号和目标地址-1）。
- bank 切换例程：`BANK_SWITCH`（X=bank，存进 `W_0100`）、`BANK_SAVE_SWITCH`（先把当前 bank 存进 `Z_1A`）、`BANK_RESTORE`、`BANK_SWITCH_NMI`。
- `$C5E0` 附近是 CHR 解压（从 PRG 读压缩图块写进 CHR-RAM）。bank 1 中 `$B724` 那段图形会越过 bank 末尾，一直读到 `$C122`。这是原版的怪癖，请在注释里说明（见 `db/shift_ignore.tsv`）。
- `$0600` 起是 PPU 写入队列（NMI 中消费）。`$C839` 检查队列空间。
- `Z_4B` = 区（0-5），`Z_4C` = 关（0-7），`W_04E5` = 剩余命数。来自 Data Crystal RAM map 和关卡循环代码。
  其他已知：`Z_12` 暂停，`Z_49` 菜单选项，`W_053A`-`W_0541` 密码，`W_055B`-`W_055D` 时间。

## 任务
1. 读懂内核：主循环 / 游戏状态机（`L7_C946` 一带）、NMI 流程、PPU 队列、手柄读取、随机数、bank 切换、乘除等工具例程。
2. 给范围内所有 `S7_*` 命名并写块注释，有意义的 `L7_*`、`D7_*` 也命名。
3. **建立 `harness/notes/glossary.md`**：模块前缀、通用术语、和第一代源码（`../bman.asm`）对应的名字。后续所有任务都会遵守它。
4. RAM：内核专用的变量（PPU 影子寄存器、队列指针、bank 记录、手柄状态、帧计数等）可以直接命名；其余写进笔记的「RAM 变量提议」。
5. 处理 `python3 tools/suspects.py us --bank 7` 中 `$C000-$D7FF` 的嫌疑项。
6. 笔记写在 `harness/notes/T01-core.md`。
