# Source code of NES game Bomberman

![JPG](/imgstore/whc4f9a3ebbbf486.jpg)

Get sources from Git and run MAKE.BAT (Windows) or `./make.sh` (macOS/Linux) to build .NES file.

Pass `jp` to build the Japanese version instead (`make.bat jp`, `./make.sh jp`). It is selected with the
`REGION_JP` define (`breakasm.py -D REGION_JP ...`), which switches the `IFDEF REGION_JP` blocks in BMAN.NAS,
and uses BOMBER_JP.CHR for graphics.

Enjoy!

## More info

The USA version of the game has been decompiled (NES-BM-USA): https://nescartdb.com/profile/view/834/bomberman

- PRG CRC32: A913A222
- CHR CRC32: 1DB14E97

The Japanese version (HVC-BM) differs only in the title screen (logo, copyright text, menu layout),
the ending text and a few bytes of the reset code:

- PRG CRC32: 9684657F
- CHR CRC32: A775822E

## Credits

A more elaborate code can be found here: https://github.com/picosonic/bomberman-nes

Parts of the decompiled source code from there are transferred here as well.
