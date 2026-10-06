# Source code of NES game Bomberman

![JPG](/imgstore/whc4f9a3ebbbf486.jpg)

Get sources from Git and run `./make.sh` to build bomberman.nes (needs [beebasm](https://github.com/stardot/beebasm) on the PATH, or set `BEEBASM=/path/to/beebasm`).

Run `./make.sh . jp` to build the Japanese version (bomberman_jp.nes) instead. It is selected with the
`REGION_JP` symbol (`beebasm -D REGION_JP -i bman.asm`), which switches the `IF REGION_JP` blocks in bman.asm,
and uses bomber_jp.chr for graphics. The Japanese version differs only in the title screen (logo, copyright text,
menu layout), the ending text and a few bytes of the reset code:

- PRG CRC32: 9684657F
- CHR CRC32: A775822E

Enjoy!
