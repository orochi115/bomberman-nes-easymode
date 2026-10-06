# T01-core 固定 bank 内核（$C000–$D7FF）

## 概述

`RESET` 关中断、热身 PPU、清 RAM、复位 MMC1，然后进入 `GAME_LOOP`。

`NMI` 每帧：若 `OAM_READY` 则 DMA 精灵；上传调色板，否则消化 `$0600` 的 PPU 队列；分割画面时等精灵 0 并改滚动；应用普通滚动；清精灵缓冲；在 `NMI_CNT` 从 0 变成 1 的那一帧读手柄；`FRAME_CNT` 加一；用 `SND_NMI_LOCK` 防重入地调用 bank 2 的声音节拍。

`GAME_LOOP` 先跑开场（`RUN_OPENING`），再在 `MENU_LOOP` 里画前端画面和模式菜单。选关之后 `STAGE_BOOT` 把命数写成 2，`STAGE_SETUP` 装 CHR、调色板、敌人和 BGM。`STAGE_LOOP` 每帧等 NMI，处理暂停、玩家、爆炸和敌人。过关加关/区，区到 6 进结局并 `RESET`。命数减到负数进游戏结束画面。`W_03EF` 非 0 是演示关。

bank 切换：`BANK_SWITCH` 把 X 写入 `CUR_BANK` 再串行写 MMC1。若中途 `MMC1_GUARD` 被 NMI 改掉，会整片复位 MMC1 再写一次。`BANK_SWITCH_NMI` 是 NMI 里用的版本。`FAR_CALL` 读 JSR 后面的 bank 和地址-1。

CHR 解压在 `DECODE_CHR`。bank 1 `$B724` 的图会读过 bank 末尾，一直进本 bank 的 `$C000–$C122`（`shift_ignore` 已记录）。

## 已命名

依据都是这段代码本身，加上被它直接 FARCALL 的短例程开头。

- 复位与画面：`PPU_WARMUP`、`CLEAR_LOW_RAM`、`INIT_MAPPER`、`MMC1_RESET`、`RESET_VIDEO`、`PPU_ON`、`PPU_OFF`、`NMI_ON`、`NMI_OFF`、`WAIT_VBLANK`、`WAIT_NMI`、`WAIT_FRAME`
- 滚动和分割：`CLEAR_SCROLL`、`APPLY_SCROLL`、`SET_TOP_SPLIT`、`SET_LOW_SPLIT`、`PPU_BUS_FIX`
- 精灵：`OAM_DMA`、`CLEAR_OAM`、`MARK_OAM`、`DRAW_METASPRITE`
- 手柄：`READ_JOYPADS`、`READ_JOY_STD`、`READ_JOY_PROBE`（仅美版）、`READ_JOY_ALT`（仅美版）
- 调色板和 CHR：`FILL_PAL_BLACK`、`FADE_PALETTE`、`UPLOAD_PALETTE`、`COPY_PAL_ROWS`、`UPLOAD_CHR_RLE`、`UPLOAD_CHR_RAW`、`DECODE_CHR`、`LOAD_AREA_CHR`、`LOAD_MODE_GFX`、`LOAD_4_TILES`
- PPU 队列：`PPU_Q_HAS_ROOM`、`WAIT_PPU_Q`、`QUEUE_PPU_RUN`、`QUEUE_TILE`、`QUEUE_MAP_TILE`、`DRAIN_PPU_Q`、`XY_TO_NT_ADDR`、`XY_TO_ATTR`
- 主循环标签：`GAME_LOOP`、`MENU_LOOP`、`STAGE_BOOT`、`STAGE_SETUP`、`STAGE_LOOP`、`STAGE_WON`、`STAGE_LOST`、`ALL_CLEAR`、`DEMO_EXIT`、`PREP_STAGE_B4`
- 声音：`START_AUDIO`、`AUDIO_CALL`、`AUDIO_CMD_80`、`AUDIO_CMD_85`、`PLAY_AREA_BGM`
- 随机数：`NEXT_RNG`。演示记录会覆盖 `RNG_1..3`
- 地图：`MAP_ROW_PTR`、`PEEK_MAP_BYTE`、`COPY_LAYOUT_CELL`、`FILL_MAP_FF`。行地址是 WRAM，不是 PRG 指针
- 暂停：`UPDATE_PAUSE` 画 `PAUSE_TEXT`（ASCII “PAUSE”），并滑动 `SPLIT_SCROLL_X`

直接命名的内核 RAM：`FRAME_CNT`、`NMI_CNT`、`OAM_READY`、`OAM_INDEX`、`PPU_ENABLED`、`PPU_CTRL_BUF`、`PPU_MASK_BUF`、`PAL_DIRTY`、`PAL_BUF`、`CUR_BANK`、`SAVED_BANK`、`MMC1_GUARD`、`SPLIT_MODE`、`SPRITE0_Y`、滚动和队列指针、三套手柄及其 `_NEW`/`_OLD`/`_2ND`、`JOY_NEW`、`JOY_HELD`、`RNG_1..3`、`SND_NMI_LOCK`、`PPU_QUEUE`。美版探测字节 `JOY_PROBE_1/2`、`JOY_SIG_OK` 只在美版读手柄里出现。

## RAM 变量提议

这些被内核读写，但别的 bank 也在用，没有在这里改名。

- `$49` `Z_49` 模式。0 走故事关的敌人更新；1 和 2 换关前画面和精灵调色板。菜单在选到 2 且 `JOY_SIG_OK` 为 0 时会拒绝
- `$4A` `Z_4A` 非 0 时 `STAGE_BOOT` 保留当前区/关，并在对战结算或游戏结束后从 `RESUME_MODE` 回来
- `$4B` / `$4C` 区 / 关。区比较到 6 进结局
- `$4D` 上一次播过片头的区。`MAYBE_AREA_CARD` 用它避免重复
- `$4E` 非 0 时 `KILL_PLAYERS` 只增加 `$B7` 并播声音 $16，不改玩家槽
- `$53` 关内计时到 $F0 走失败。演示退出时被写成 $F0。`INIT_PLAYERS` 在它非 0 时多清一块 RAM
- `$B7` 非 0 时 `STAGE_LOOP` 把它和 $F0 比较来离开关卡。`UPDATE_PLAYERS` 在它非 0 时只递增
- `$B4` 过关后非 0 则 `PREP_STAGE_B4` 调用 bank 5 `$9E92`（改关号、火力字节和 `$4E`）
- `$03EF` 演示标志。`$03F0` 是 4 条演示记录的下标
- `$04E5` 命。进关时写成 2；失败时减 1；`$0550` 那条入口写成 1
- `$054E` 非 0 则重画菜单。`$054F` 进 `ENTER_Z49_1`（bank 5 `$9FC0` 把模式设成 1 且不返回）。`$0550` 进 `ENTER_W0550`
- `$04C9` 新游戏时被复制到区号；最高位为 1 则直接结局
- `$0563` `SET_WIN_COUNT` 在模式不是 2 时写成 5。失败路径拿它和 `$055E` 比较
- `$20/$21` 通用指针（CHR 源、队列数据、字符串）
- `$22/$23` 算出的 PPU 地址
- `$16/$17` 调色板拷贝的源
- `$62/$63` 图块 4 字节组，`$64/$65` 布局行，`$66/$67` 属性半字节。由 `BIND_AREA_PTRS` 按区填
- `$2E` 队列标志。bit7 选择 PPU 纵向步进
- `$54–$5A` `DRAW_METASPRITE` 的数据指针、坐标和翻转
- `$69` 起三个玩家槽。`INIT_PLAYERS` 把 `$69,X` 设为 1，并清 `$75`、`$7E`、`$81`、`$84` 等
- `$90` / `$93` 由 `MODE_BYTE_90/93` 按模式填入，演示记录也会写
- `$04EB` 起 15 个炸弹标志，格子在 `$04FA` / `$0509`
- `X_6001` 24 个爆炸槽；`X_60E2` 60 个角色槽；`X_6250` 10 个敌人槽
- `X_60C1` 32 字节环，下标 `X_60E1`，`FREE_RING_SLOT` 清当前项并前进
- `$33–$3A` 只在 `FAR_CALL` 里保存 A/X/Y 和返回地址。其它代码可能把它们当临时单元，所以没改名

## 疑问 / 待确认

- Data Crystal 把 `$12` 标成暂停。这段代码里它是 `OAM_READY`：主循环每帧 `MARK_OAM`，NMI 先 DMA 再清缓冲。暂停不看这个字节
- `READ_JOY_PROBE` 要的 $10/$20 是什么设备，没有在 ROM 里写明。能确认的只有：对上之后 `JOY_SIG_OK` 为 1，模式菜单在它为 0 时不接受模式 2
- `BLAST_TYPE_TAB` 的 $80–$83 分别代表什么，只看到被写入 `Z_B5`
- `AUDIO_CMD_80` 和 `AUDIO_CMD_85` 在声音引擎里的具体动作要到 bank 2 才能看。这里只知道谁调用、传入的 A/X
- `W_0550` 入口会调用和 `PREP_STAGE_B4` 同一个 bank 5 例程 `$9E92`。它和密码或继续的关系没有在本段证实
- `ENTER_Z49_1` 后面的 `JMP GAME_LOOP` 到不了，因为 `$9FC0` 自己的帧循环不返回
- `NEXT_RNG` 的 RTS 后面有一段覆盖率没跑到的清零代码，没有命名

## 工具问题

无。并行调用 `db.py` 会互相覆盖 `db/symbols.d/T01-core.tsv`（`write_rows` 整文件重写）。后面改为一次只跑一条。

## 范围内的指针嫌疑

- `$C21E`：`BANK_RESTORE` 里的 `JMP BANK_SWITCH`，已声明 `word`
- `$CC57`/`$CC5B`：美版 `UPDATE_PAUSE` 把 `PAUSE_TEXT` 放进 `$20/$21`。日版同一条指令的立即数不是这个地址，所以只声明了 `us:7:CC57 lo us:7:CC5B`
- `$CC26`：敌人 CHR 表第 6 项，原来是裸字节 $926F，已声明 `word bank=1`（和前一项相同，指向 bank 1）
- `$D170`/`$D17D`：13 个 WRAM 行地址（$62F3 起，步长 $20）。扫描器的两次“命中”是表尾后面的字节。已 `notptr`

`$C000–$D7FF` 之外的嫌疑（例如 `$F9B1`、向量 `$FFFA`）不在本任务范围。

## check.sh 结果

```
== db lint
lint: 0 problems
== regenerate
  pass 1: aligned 127235 bytes, labels linked True, facts copied 1
  pass 2: aligned 127235 bytes, labels linked False, facts copied 0
IF REGION_JP blocks 208
== build us
OK: identical to Bomberman II (USA).nes
== build jp
OK: identical to Bomberman II (Japan).nes
== relocation test
  us shift 1: quick        OK (1566 frames)
CHECK PASSED
```

