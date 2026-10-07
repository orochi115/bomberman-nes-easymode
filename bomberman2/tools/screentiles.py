"""Background tiles shown during a frame window of a scripted flow.

Usage: screentiles.py ROM FLOW START END [SHOT.png]
FLOW is a shots.py flow (menu, normal_flow, vs_flow, battle_flow, gameover,
ending ...). Prints the union of nametable tiles (frames START..END, rendering
on) and the complement, and optionally saves a screenshot at START.
Use shots.py films to find the window of a screen first.
"""
import sys

import emu
import shots
from ppu_render import render

USED = set()
ARGS = {}


def run_frame(self, _orig=emu.NES.run_frame):
    r = _orig(self)
    if ARGS["start"] <= self.frame <= ARGS["end"] and self.ppumask & 0x18:
        if self.frame == ARGS["start"] and ARGS["shot"]:
            render(self).save(ARGS["shot"])
        for i in range(0x800):
            if (i & 0x3FF) < 0x3C0:
                USED.add(self.vram[i])
    return r


emu.NES.run_frame = run_frame


def main():
    rom = open(sys.argv[1], "rb").read()
    ARGS.update(start=int(sys.argv[3]), end=int(sys.argv[4]),
                shot=sys.argv[5] if len(sys.argv) > 5 else None)
    s = shots.Shooter(rom, "/tmp")
    s.shot = lambda nes, name: print(name, nes.frame)
    getattr(s, sys.argv[2])()
    print("used", " ".join("%02X" % t for t in sorted(USED)))
    print("free", " ".join("%02X" % t for t in range(256) if t not in USED))


if __name__ == "__main__":
    main()
