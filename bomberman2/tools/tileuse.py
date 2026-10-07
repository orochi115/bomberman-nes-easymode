"""Tile usage grouped by the loaded CHR, over scripted flows (see shots.py).

Usage: tileuse.py ROM OUTDIR flow [flow ...]
Every frame with rendering on, the nametable tiles are added to the entry of
the current background pattern table contents (hash of $1000-$1FEF; tile FF
is skipped because uploads of FFh tiles leave it alone) and the OAM tiles to
the entry of the sprite pattern table. One screenshot per entry is saved as
OUTDIR/bg_<hash>.png / spr_<hash>.png. Prints the used and free tiles per
entry.
"""
import hashlib
import os
import sys

import emu
import shots
from ppu_render import render

BG, SPR = {}, {}
FIRST = {}


def record(nes):
    if not nes.ppumask & 0x18:
        return
    kb = hashlib.md5(bytes(nes.chr[0x1000:0x1FF0])).hexdigest()[:8]
    ks = hashlib.md5(bytes(nes.chr[0x0000:0x0FF0])).hexdigest()[:8]
    if kb not in BG:
        BG[kb] = set()
        FIRST["bg_" + kb] = nes.frame
        render(nes).save(os.path.join(OUT, "bg_%s.png" % kb))
    if ks not in SPR:
        SPR[ks] = set()
        FIRST["spr_" + ks] = nes.frame
        render(nes).save(os.path.join(OUT, "spr_%s.png" % ks))
    acc = BG[kb]
    for i in range(0x800):
        if (i & 0x3FF) < 0x3C0:
            acc.add(nes.vram[i])
    for i in range(64):
        if nes.oam[i * 4] < 0xEF:
            SPR[ks].add(nes.oam[i * 4 + 1])


orig = emu.NES.run_frame


def run_frame(self):
    r = orig(self)
    record(self)
    return r


emu.NES.run_frame = run_frame


def main():
    global OUT
    rom = open(sys.argv[1], "rb").read()
    OUT = sys.argv[2]
    os.makedirs(OUT, exist_ok=True)
    s = shots.Shooter(rom, "/tmp")
    s.shot = lambda nes, name: None
    for flow in sys.argv[3:]:
        getattr(s, flow)()
    for kind, tab in (("bg", BG), ("spr", SPR)):
        for k, used in tab.items():
            print("%s_%s first frame %d" % (kind, k, FIRST[kind + "_" + k]))
            print("  used", " ".join("%02X" % t for t in sorted(used)))
            print("  free", " ".join("%02X" % t for t in range(256) if t not in used))


if __name__ == "__main__":
    main()
