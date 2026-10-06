# Source code of NES game Bomberman

![JPG](/imgstore/whc4f9a3ebbbf486.jpg)

This version adds a Chinese translation (English is a build option) and new
options:

- All in-game text is in Chinese (12px Fusion Pixel font). The BOMBERMAN
  logo and the trademark lines are unchanged.
- The CONTINUE password screen is replaced by an options screen (选项):
  stage, lives, bomb power / count, time limit, starting power-ups, and
  - 复活 (revive): losing a life keeps the stage as it is and respawns you
    in a safe spot; only when all lives are gone is the stage restarted.
  - 缓动 (slow mode): game time only passes while a direction or B is held.
  - 透视 (show hidden exit / bonus) and 无敌 (invincible).
- Pause shows a message in the status bar; left / right scroll round the
  map, SELECT (or SELECT + START during play) returns to the title screen.
- Title menu: d-pad / SELECT choose, A / B / START confirm.

"开始游戏" (start) and the demo play with the original rules.

## Building

Needs [BeebAsm](https://github.com/stardot/beebasm) and Python 3.

    ./build.sh                    # English, original rules for START
    ./build.sh -l zh              # Chinese
    ./build.sh -l zh -r jp        # Chinese, on the Japanese version
    ./build.sh -c config/casual.asm
    ./run-casual.sh               # Chinese with config/casual.asm, in ares
    ./run-ares.sh [same options]  # builds and runs it in ares (macOS)

`-c` picks the settings file used by "开始游戏" (START) and as the options
screen defaults; `config/default.asm` is the original game.

`-r jp` builds `bomberman_jp.nes` from the Japanese version instead. It is
selected with the `REGION_JP` symbol (`beebasm -D REGION_JP -i bman.asm`),
which switches the `IF REGION_JP` blocks in bman.asm, and the CHR banks are
made from `bomber_jp.chr`. The Japanese version differs only in the title
screen (logo, copyright text, menu layout), the ending text and a few bytes of
the reset code. `./make.sh [dir] [us|jp]` still works and runs `build.sh -r`.

The ROM is CNROM (mapper 3): 32KB PRG-ROM and four 8KB CHR banks.
The original code stays at $C000-$FFFF; new code lives in ext.asm,
options.asm and pause.asm at $8000-$BFFF.

## Text

Strings are in `text/zh_strings.txt` and `text/en_strings.txt` (same IDs).
`tools/build_text.py` (run by build.sh) draws them, writes the CHR banks to
`bomber_text.chr` and the tile data to `text_data.asm`. Run
`python3 tools/build_text.py --preview` to also write PNG previews of the CHR
banks to `text/`.

The Chinese font is [Fusion Pixel Font](https://github.com/TakWolf/fusion-pixel-font)
by TakWolf, licensed under the SIL Open Font License 1.1 (see `fonts/`).
