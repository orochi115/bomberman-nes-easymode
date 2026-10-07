# Source code of NES game Bomberman II

A disassembly of Bomberman II (Hudson Soft, 1991/1992; MMC1, 8 × 16K PRG, CHR-RAM) that
rebuilds the USA, Japanese and European (Dynablaster) ROMs byte for byte from one source.

```
./make.sh us     # build/bomberman2_us.nes = Bomberman II (USA).nes
./make.sh jp     # build/bomberman2_jp.nes = Bomberman II (Japan).nes
./make.sh eu     # build/bomberman2_eu.nes = Dynablaster (Europe).nes (PAL)
./make.sh us 1   # the same with an iNES 1.0 header (only the PRG is compared)
```

Needs [beebasm](https://github.com/stardot/beebasm) (default `../../beebasm/beebasm`, or set
`BEEBASM=...`) and the original ROMs in `../..` (or set `BM2_ROMDIR=...`) for the comparison.

| File | Contents |
|---|---|
| `bman2.asm` | main file: assembles banks 0-6 at `$8000` and bank 7 (fixed) at `$C000` |
| `bank0.asm` - `bank7.asm` | the code and data of each PRG bank |
| `vars.asm` | RAM / WRAM names (values differ per region where the layout differs) |
| `macros.asm` | `FARCALL` (cross-bank call), `FILLTO`, forced absolute addressing, reset stub |
| `consts.asm`, `nesregs.asm`, `nes_header.asm` | region switch, hardware registers, iNES header |

Differences between the regions are `IF` / `ELIF` / `ELSE` blocks
(`beebasm -D REGION=0` USA, `1` Japan, `2` Europe). `REGION_JP` is true when `REGION = 1`.

## Chinese / options mod (branch bomberman2-cn)

```
./build.sh [-r us|jp] [-l zh|en] [-c config/NAME.asm] [-H 1|2]   # build/bomberman2_cn_REGION_LANG.nes
./run-ares.sh [same options]                            # build and open in ares (macOS)
./run-casual.sh                                         # = run-ares.sh -l zh -c config/casual.asm -r jp
```

`-r` picks the original the mod is based on (USA or Japan), `-l` the language
(Chinese, or English with only the new screens added), `-c` the rules of
普通模式 / NORMAL MODE and the initial options (`config/default.asm` = the
original game, `config/casual.asm` = unlimited lives, revive, slow, remote).
`-H` picks the header: NES 2.0 like the original dumps (default; it also
names the Four Score / Famicom four-player adapter, so emulators can plug it
in for battle mode), or iNES 1.0 for old emulators and loaders.

What it changes:

- **Chinese text** on every screen: title prompt (sprites), mode menu, stage
  card, HUD (时间 / 剩余), pause, game over, VS / battle cards, win count,
  winner screen, round results, bonus stage, sound room, credits. 12px
  Fusion Pixel font everywhere.
- **选项 / OPTIONS** replaces CONTINUE (the password screen is gone): area,
  stage, lives (1-9 or unlimited), fire, bombs, speed, time (or unlimited),
  revive, slow, remote control (no / yes / with fuse: the PACHINKO and
  PANICMAN words), wall pass, bomb pass, fire pass, x-ray, invincible, fuse
  (short / normal / long: the BOMBACE / BOMBMAN / BOMBOLD words), and the
  sound room and the bonus stage (the PCDEFGAB and PONEJACK words). Rules on
  the left, the original power-ups on the right. Up/Down move through both
  columns (past the bottom of one is the top of the other), SELECT jumps to
  the other column, Left/Right/A change, START plays, B goes back. The
  options stay until power off. The title, the demo, VS and battle always
  use the original rules.
- **Revive**: lose a life and get up where you died, invulnerable for about
  4 s with a full clock; losing the last life restarts the stage as it was
  entered. **Slow mode**: the game only moves while you hold the d-pad or B
  (A still drops a bomb). **X-ray**: the soft blocks hiding the item and the
  exit blink between the block and what they hide (they still have to be
  bombed).
- **Pause**: SELECT goes back to the title, Left/Right look round a wide map.
  The HUD flashes in the last 10 seconds.
- **Sound room** works like the options screen: Up/Down choose, Left/Right
  change, A (or START) plays, SELECT stops, B goes back to the options.

How it is built:

- On this branch the generator is frozen: `bank*.asm` are edited by hand and
  `tools/merge.py` / `tools/regen.sh` refuse to run (`tools/check.sh` skips
  them). Every change is inside `IF MOD` (or `IF ZH` = MOD and Chinese), so
  `make.sh` still builds and checks the unmodified US and JP ROMs.
- 256K PRG (MMC1, 16 banks): banks 0-6 as before, `mod_bank7.asm` (options,
  pause), `mod_bank8.asm` + banks 9-14 (text data), the original fixed bank
  is bank 15 (`text.asm`, `mod.asm`, `hud.asm` in its free space).
  `mod_vars.asm` lists the RAM the mod uses.
- Text: `text/{zh,en}_strings.txt` -> `tools/build_text.py` -> `build/text_*.asm`.
  The game has CHR-RAM, so each screen uploads the glyphs it needs into tiles
  that screen does not show (`SETS` in build_text.py, measured with
  `tools/tileuse.py`, `tools/screentiles.py`, `tools/freetiles.py`).
  `text.asm` uploads sets and prints records (`ZH_SCREEN`, `ZH_QUEUE`, ...).
- Checks: `tools/democheck.py ROM` (the attract demo plays exactly as in the
  original), `tools/shots.py ROM OUTDIR flow...` (screenshots of scripted
  flows: title, menu, options, stage, pause, gameover, vs_result, ending ...).

## Relocatable

All ROM addresses are labels, including pointer tables and `#LO()/#HI()` immediates, so
code and data can grow or move. `./make.sh us shift N` inserts N bytes at the start of
every bank, and `tools/shifttest.py` runs that build next to the original in an emulator,
comparing every PPU/APU write. Shifts of 1 and 256 bytes behave identically to the original
in all test scenarios (attract mode, all modes, every area and round) for both regions.

Known quirk: the ending sprite CHR stream in bank 1 (`ENDING_SPR_CHR`) runs past the end of
the bank and decodes fixed-bank code bytes `$C000-$C122` as tile data. Moving that code
changes a few unused tiles (`db/shift_ignore.tsv`).

## How the source is made

The `.asm` files are generated - edit `db/`, not the `.asm` files:

- `tools/emu.py`, `tools/cover.py` - a small NES emulator that records which bytes run as
  code, which are read as data, and (taint tracking) which bytes are used as pointers
- `tools/disasm.py`, `tools/emit.py` - static trace + coverage -> source items
- `tools/merge.py` - aligns the US and JP ROMs and writes one source
- `db/symbols.tsv`, `db/comments.tsv`, `db/pointers.tsv`, `db/code.tsv` (+ `*.d/` shards) -
  names, comments, pointers and code entry points (keys are US addresses)
- `tools/check.sh` - lint, regenerate, both builds byte-exact, quick relocation test
  (`--full`: every scenario, both regions, shift 1 and 256)
- `tools/q.py` (index, xref), `tools/db.py` (validated edits), `tools/suspects.py`,
  `tools/codeguess.py`, `tools/trace.py` (watch RAM, breakpoints, screenshots)

Naming and commenting were done through `harness/` (task split, rules and notes for the
agents that did the bulk of the work; see `harness/README.md`).
