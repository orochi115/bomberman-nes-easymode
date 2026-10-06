# T02-sound

## 概述

NMI 在切到 bank 2 之后 `JSR SND_FRAME_ENTRY`（`$D806`），该入口跳到 `SND_FRAME`。开机初始化走 `SND_RESET_ENTRY`（`$D800`）到 `SND_INIT`。游戏侧请求声音时把 id 放在 A，经 bank 7 的 `$C8F5` 调 `SND_REQUEST`（本任务不改 `$C8F5`，它在范围外）。

`SND_REQUEST` 按 id 分段：

- `$00`–`$0B`：方波/噪声音效，写入 `W_0205`。`SND_SFX_PRIORITY` 数值更小的可以替换正在响的音效。bit7 区分 init 和 tick。
- `$0C`–`$1D`：乐曲，写入 `W_0206`。bit7 清掉表示要重新装表。
- `$1E`–`$2A`：DMC，写入 `W_0207`。`$1E` 是静音槽。
- `$80`–`$8C`：控制命令，写入 `W_0208`，由 `SND_RUN_CMD` 查 `SND_CMD_VECTORS`。X 是参数，返回值放回 X（经 `W_0353`）。

每帧顺序：`SND_RUN_BGM`、`SND_RUN_SFX`、`SND_UPDATE_NOISE`、`SND_FLUSH_APU`。`W_0359` 防止重入。

乐曲表 `SND_BGM_TABLE` 共 18 项，每项 3 字节：PRG bank，再加指向 5 声道头的指针。空的声道指针换成 `SND_REST_STREAM`。声道流可以在 bank 3（id `$13` 起的 bank 字节是 3）。读流时用 `W_0204` 切 bank。

音符字节小于 `$D0`：高半字节是音高，低半字节是时值。大于等于 `$D0` 的字节走 `SND_STREAM_CMDS`（下标 = 字节 − `$D0`）：

| 字节 | 作用 |
|---|---|
| D0 | 声道结束 |
| D1 / D2 / D3 | 八度 +1 / −1 / 设为下一字节 |
| D4 | 时值单位 |
| D5 | 移调 |
| D6 | 下一音符不重新触发；出现在时值后面时把多段时值加在一起 |
| D7 / D8 | 循环压栈 / 弹出（深 4） |
| D9 | 未执行到的例程 `$DA23` |
| DA | 占空比掩码 |
| DB | 音高包络号 |
| DC | 门时间比例 |
| DD / DE | 未执行到的例程 `$DA65` / `$DA6F` |
| DF / E0 | 调用短语 / 返回（深 4） |
| E1 / E2 | 未执行到的例程 `$DAD4` / `$DADE` |
| E3 | 音量偏移 |
| E4 / E5 | 颤音波形 / 颤音重载计数（仅方波） |
| E6 / E7 | 固定失谐 / 失谐表（仅方波） |
| E8 | 相对音量（下一字节取反后相加，夹在 `$00`–`$1F`） |
| E9 / EA | 记下循环点 / 跳回循环点 |
| EB | 未执行到的例程 `$DB5F` |

音高包络：低于 `$F0` 是时值加 16 位音高增量；`$F0`–`$FE` 查 `SND_PENV_CMDS`；`$FF` 结束。

命令 `$80`–`$8C`：全停、停乐曲、停 DMC 和音效、读/写主音量 `W_0351`、读/写声道开关 `W_0352`、设淡出步进 `W_0356`、读乐曲/音效/DMC 号、返回三类 id 的范围、再停一次 DMC。音量低于 `$10` 时方波音量被缩小，低于 `$08` 时噪声脚本改写为静音。

`$E000` 起是 DPCM 采样位，只加了名字和注释。

## 已命名

依据是请求点的立即数，以及这些立即数旁边的模式/计时器/画面文字。

- 驱动入口和每帧：`SND_RESET_ENTRY`、`SND_REQUEST_ENTRY`、`SND_FRAME_ENTRY`、`SND_INIT`、`SND_REQUEST`、`SND_FRAME`。
- 乐曲：`SND_RUN_BGM` 读 `SND_BGM_TABLE`。id 对应关系：`$0C` 静音，`$0D` 标题卷轴结束，`$0E`/`$0F`/`$10` 由 `S7_CAEE` 按 `Z_4B` 选（0/2/4、1/3、5），`$11` 换区卡片（`S5_ACE4`），`$12` `Z_A5` 计时结束且 `Z_49` 为 0，`$13` 标题菜单和密码，`$14` `Z_49` 非 0 的关卡，`$15` 道具（`S5_9064` 里不是 `$0B` 的那支），`$16` `Z_B7` 被置位，`$17` `S5_B07D` 把 `Z_4B` 写成 6，`$18` `S0_B008` 滚文字，`$19` `S5_AA6A` 模式选择，`$1A`/`$1B` `S5_9121` 还剩一人 / 无人站着，`$1C` `S5_B209`，`$1D` `S5_9F5E`、`S5_B595`、`S5_B8F6` 的短曲。
- 音效：`$01` 标题滚动，`$02` 密码落子，`$03` 普通道具，`$04` 玩家或敌人死亡以及菜单拒绝，`$05` `Z_49` 为 2 时复制炸弹计时以及道具类型 `$0B`，`$06` 暂停，`$07` 光标，`$08` 秒数为 0 时的滴答，`$09` 计时低于 4，`$0A` `X_625A` 为 `$10` 且 `W_04E5` 加一，`$00` 空，`$0B` 下滑音（没有直接的 `LDA #$0B` 请求点）。
- DMC：`SND_DMC_PTRS` 13 项，id `$1E`–`$2A`。`$27` 在标题引入和 `S7_D018` 使用。
- 流解释器在 bank 7 `$D80A`–`$DD55`，命令处理例程按上表命名。

## RAM 变量提议

正式命名留给 RAM 任务。下面都是美版地址，声音驱动在用。

| 地址 | 提议名 | 依据 |
|---|---|---|
| `W_0202` | `SND_CH` | 当前声道号，0–4 |
| `W_0203` | `SND_BYTE` | 刚读到的流字节 |
| `W_0204` | `SND_BGM_BANK` | 该曲流所在的 PRG bank |
| `W_0205` | `SND_SFX_ID` | 音效号，bit7 表示已经进入 tick |
| `W_0206` | `SND_BGM_ID` | 乐曲号，bit7 表示已经装好 |
| `W_0207` | `SND_DMC_ID` | DMC 号，bit7 表示已经启动 |
| `W_0208` | `SND_CMD_ID` | 待执行的 `$80` 命令 |
| `W_0213` | `SND_STREAM` | 5 个声道流指针，每项 2 字节 |
| `W_022C` | `SND_NOTE_LEN` | 音符时值 |
| `W_0231` | `SND_GATE` | 发声剩余帧 |
| `W_0236` | `SND_DUTY` | 命令 DA 写入的占空比 |
| `W_023B` | `SND_GATE_SCALE` | 命令 DC |
| `W_0240` | `SND_PENV` | 命令 DB 的包络号 |
| `W_0245` | `SND_DUR_UNIT` | 命令 D4 |
| `W_024A` | `SND_OCTAVE` | 每声道八度 |
| `W_024F` | `SND_TRANSPOSE` | 命令 D5 |
| `W_0295` | `SND_LEGATO` | 命令 D6，下一音符不重触发 |
| `W_02CC` | `SND_VOLUME` | 命令 E3/E8，范围 `$00`–`$1F` |
| `W_02D1` | `SND_VIB_LEN` | 命令 E5 |
| `W_02D6` | `SND_VIB_ID` | 命令 E4 |
| `W_02E2` | `SND_DETUNE` | 命令 E6 |
| `W_02E7` | `SND_DETUNE_ID` | 命令 E7 |
| `W_0310` | `SND_PITCH_LO` | 与 `W_0315` 组成 16 位音高 |
| `W_032E` | `SND_APU_SHADOW` | 乐曲声道的 APU 寄存器镜像 |
| `W_0342` | `SND_DIRTY` | 每声道 4 个寄存器的脏标志 |
| `W_0347` | `SND_SFX_ON` | 音效占用了哪几个声道 |
| `W_0351` | `SND_MASTER` | 主音量，初值 `$10` |
| `W_0352` | `SND_MIX` | `$4015` 的影子 |
| `W_0356` | `SND_FADE` | 命令 `$85` 写入的淡出步进 |
| `W_0359` | `SND_BUSY` | 帧更新重入锁 |
| `W_035B` | `SND_SFX_SHADOW` | 音效层 APU 镜像 |
| `W_036F` | `SND_SFX_DIRTY` | 音效层脏标志 |

`W_0205` 一带也被 bank 7 的暂停和淡出代码读写，所以没有在本任务里直接改名。

## 疑问 / 待确认

- 道具类型 `$0B` 和演员类型 `X_625A = $10` 在玩法上具体是什么，本范围看不出来。
- `$1C`、`$1D` 以及 `S5_9F5E` 那几屏没有画面文字，只知道是短曲或静图配乐。
- 命令 D9、DD、DE、E1、E2、EB 的处理代码覆盖运行没走到，只声明了指针，没有给那些入口起行为名。
- 音效 `$0B` 没有找到直接请求点。
- 部分 `DF` 短语指针只在未播放的曲子里，已按字声明；播放过的已经被反汇编器收成 `EQUW`。

## 工具问题

无。DPCM 区里成串的“像地址”的字节已用 notptr 标成采样位。

## check.sh 结果

```
== db lint
lint: 0 problems
== regenerate
  pass 1: aligned 127235 bytes, labels linked True, facts copied 1
  pass 2: aligned 127235 bytes, labels linked False, facts copied 0
IF REGION_JP blocks 209
== build us
OK: identical to Bomberman II (USA).nes
== build jp
OK: identical to Bomberman II (Japan).nes
== relocation test
  us shift 1: quick        OK (1566 frames)
CHECK PASSED
```
