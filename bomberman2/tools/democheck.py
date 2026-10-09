"""Compare the attract-mode demo of a ROM with the original.

Usage: democheck.py ROM [frames]
Records, for every frame of a demo stage (DEMO_MODE = 1, rendering on), the
player and enemy positions, bomb and flame slots and the score, and compares
the sequences of states (frame numbers may differ: only the order of the
states counts). Prints the first difference.
"""
import sys

from emu import NES
from m6502 import ROMS
from shots import region_of

# EU bank 0 matches JP, so actor slots follow the JP map.
ACTOR_X = {"us": 0x72, "jp": 0x64, "eu": 0x64}
ACTOR_Y = {"us": 0x78, "jp": 0x6A, "eu": 0x6A}


def states(rom, frames):
    region = region_of(rom)
    nes = NES(rom, track=False)
    out = []
    for _ in range(frames):
        nes.run_frame()
        r, w = nes.ram, nes.wram
        if r[0x03EF] != 1 or not nes.ppumask & 0x18:
            if out and out[-1] is not None:
                out.append(None)        # a demo stage ended
            continue
        st = (r[ACTOR_X[region]], r[ACTOR_Y[region]], bytes(w[0x264:0x264 + 10]),
              bytes(w[0x278:0x278 + 10]), bytes(w[0x001:0x001 + 24]), bytes(r[0x3D0:0x3D8]))
        if not out or out[-1] != st:
            out.append(st)
    return out


def main():
    rom = open(sys.argv[1], "rb").read()
    frames = int(sys.argv[2]) if len(sys.argv) > 2 else 12000
    orig = open(ROMS[region_of(rom)], "rb").read()
    a, b = states(orig, frames), states(rom, frames)
    n = min(len(a), len(b))
    for i in range(n):
        if a[i] != b[i]:
            print("DIFF at state %d of %d/%d" % (i, len(a), len(b)))
            print("  original", a[i])
            print("  this    ", b[i])
            sys.exit(1)
    print("demo OK: %d states (%d demo stages), lengths %d / %d" % (n, a[:n].count(None), len(a), len(b)))


if __name__ == "__main__":
    main()
