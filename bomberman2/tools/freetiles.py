"""Which background tiles a screen of the original game uses.

Usage: freetiles.py REGION SCREEN [frames]
SCREEN: game0..game5 (every round of that area, random play), menu, gameover.
Prints the set of BG tiles ($1000 table) ever seen in the nametables, sampled
every 4 frames, and the complement (candidates for text glyphs).
"""
import copy
import random
import sys

import cover
from cover import press, wait, random_play
from emu import NES, START, A
from m6502 import ROMS


def used_now(nes, acc):
    for i in range(0x800):
        if (i & 0x3FF) < 0x3C0:
            acc.add(nes.vram[i])


def sample(nes, frames, acc, rng=None):
    for f in range(0, frames, 4):
        if rng:
            random_play(nes, 4, rng)
        else:
            wait(nes, 4)
        used_now(nes, acc)


def main():
    region, screen = sys.argv[1], sys.argv[2]
    frames = int(sys.argv[3]) if len(sys.argv) > 3 else 1500
    rng = random.Random(1)
    nes = NES(open(ROMS[region], "rb").read(), track=False)
    nes.region = region
    acc = set()
    cover.to_menu(nes)
    if screen == "menu":
        sample(nes, 200, acc)
    elif screen.startswith("game"):
        area = int(screen[4:])
        AREA, ROUND, LIVES = cover.STAGE_VARS[region]
        for rnd in range(8):
            n = copy.deepcopy(nes)
            n.force = {AREA: lambda v: area, ROUND: lambda v: rnd, LIVES: lambda v: max(v, 2)}
            for b in (START, START, A):
                press(n, b)
                wait(n, 94)
            wait(n, 120)
            sample(n, frames, acc, rng)
    free = [t for t in range(256) if t not in acc]
    print("used", " ".join("%02X" % t for t in sorted(acc)))
    print("free", " ".join("%02X" % t for t in free))


if __name__ == "__main__":
    main()
