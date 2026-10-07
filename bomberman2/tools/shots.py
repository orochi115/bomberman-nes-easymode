"""Screenshots of a ROM at scripted points (for checking the mod's screens).

Usage: shots.py ROM OUTDIR [script ...]
Scripts: title, menu, stage (area 0 HUD), pause, areas (HUD of every area),
gameover. ROM may be any build (original or mod); the region is read from the
iNES header (byte 15: 3 = JP).
Each shot is OUTDIR/<script>_<n>.png (view) and *_full.png (all nametables).
"""

import copy
import os
import sys

import cover
from cover import press, wait
from emu import NES, A, B, SELECT, START, UP, DOWN, LEFT, RIGHT
from ppu_render import render

STAGE_VARS = cover.STAGE_VARS


def region_of(rom):
    return "jp" if rom[15] == 3 else "us"


class Shooter:
    def __init__(self, rom, outdir):
        self.rom = rom
        self.out = outdir
        self.region = region_of(rom)

    def boot(self):
        nes = NES(self.rom, track=False)
        nes.region = self.region
        return nes

    def shot(self, nes, name):
        render(nes).save(os.path.join(self.out, name + ".png"))
        render(nes, full=True).save(os.path.join(self.out, name + "_full.png"))
        print(name, "frame", nes.frame)

    def title(self):
        nes = self.boot()
        wait(nes, 1500)
        self.shot(nes, "title_0")
        wait(nes, 30)
        self.shot(nes, "title_1")

    def to_menu(self):
        nes = self.boot()
        cover.to_menu(nes)
        return nes

    def menu(self):
        nes = self.to_menu()
        self.shot(nes, "menu_0")
        press(nes, DOWN)
        press(nes, DOWN)
        press(nes, DOWN)
        self.shot(nes, "menu_1")

    def start_stage(self, nes, area=0, rnd=0):
        AREA, ROUND, LIVES = STAGE_VARS[self.region]
        nes.force = {AREA: lambda v: area, ROUND: lambda v: rnd}
        for b in (START, START, A):
            press(nes, b)
            wait(nes, 94)
        nes.force = None
        wait(nes, 200)
        return nes

    def stage(self):
        nes = self.start_stage(self.to_menu())
        self.shot(nes, "stage_0")

    def pause(self):
        nes = self.start_stage(self.to_menu())
        press(nes, START)
        wait(nes, 60)
        self.shot(nes, "pause_0")

    def areas(self):
        base = self.to_menu()
        for a in range(6):
            nes = self.start_stage(copy.deepcopy(base), a, 0)
            self.shot(nes, "area%d" % a)

    def gameover(self):
        nes = self.start_stage(self.to_menu())
        AREA, ROUND, LIVES = STAGE_VARS[self.region]
        nes.force = {LIVES: lambda v: 0}
        wait(nes, 60)
        nes.force = None
        # wait for the clock to run out
        for i in range(400):
            wait(nes, 60)
            if nes.ram[LIVES] == 0xFF:
                break
        wait(nes, 400)
        self.shot(nes, "gameover_0")


def main():
    rom = open(sys.argv[1], "rb").read()
    out = sys.argv[2]
    os.makedirs(out, exist_ok=True)
    s = Shooter(rom, out)
    for name in sys.argv[3:] or ["title", "menu", "stage", "pause"]:
        getattr(s, name)()


if __name__ == "__main__":
    main()
