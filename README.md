# Source code of NES game Bomberman

![JPG](/imgstore/whc4f9a3ebbbf486.jpg)

This version adds a Chinese translation and new options:

- All in-game text is in Chinese (12px Fusion Pixel font). The BOMBERMAN
  logo and the trademark lines are unchanged.
- The CONTINUE password screen is replaced by an options screen (选项):
  stage, lives, bomb power / count, time limit, starting power-ups, and
  - 复活 (revive): losing a life keeps the stage as it is and respawns you
    in a safe spot; only when all lives are gone is the stage restarted.
  - 缓动 (slow mode): game time only passes while a direction or B is held.
  - 透视 (show hidden exit / bonus) and 无敌 (invincible).
- While paused, SELECT returns to the title screen.

"开始游戏" (start) and the demo play with the original rules.

## Building

Needs [BeebAsm](https://github.com/stardot/beebasm) and Python 3.

    ./build.sh        # builds bomberman.nes
    ./run-ares.sh     # builds and runs it in ares (macOS)

The ROM is now CNROM (mapper 3): 32KB PRG-ROM and four 8KB CHR banks.
The original code stays at $C000-$FFFF; new code lives in ext.asm and
options.asm at $8000-$BFFF.

## Chinese text

Strings are in `text/zh_strings.txt`. `tools/build_zh.py` (run by build.sh)
draws them with the font in `fonts/`, writes the CHR banks to
`bomber_zh.chr` and the tile data to `zh_text.asm`. Run
`python3 tools/build_zh.py --preview` to also write PNG previews of the CHR
banks to `text/`.

The font is [Fusion Pixel Font](https://github.com/TakWolf/fusion-pixel-font)
by TakWolf, licensed under the SIL Open Font License 1.1 (see `fonts/`).
