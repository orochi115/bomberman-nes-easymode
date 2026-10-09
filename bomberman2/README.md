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
