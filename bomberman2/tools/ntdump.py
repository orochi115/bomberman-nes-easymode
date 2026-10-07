"""Dump the nametable and palette at a frame of a scripted flow.
Usage: ntdump.py ROM FLOW FRAME"""
import sys
import emu
import shots

ARGS = {}


class Done(Exception):
    pass


def run_frame(self, _orig=emu.NES.run_frame):
    r = _orig(self)
    if self.frame == ARGS["frame"]:
        for nt in (0x2000, 0x2400):
            print("nametable %04X" % nt)
            for r_ in range(30):
                row = [self.vread(nt + r_ * 32 + x) for x in range(32)]
                print("%2d %s" % (r_, " ".join("%02X" % t for t in row)))
            print("attr", " ".join("%02X" % self.vread(nt + 0x3C0 + i) for i in range(64)))
        print("pal", self.pal.hex())
        raise Done()
    return r


emu.NES.run_frame = run_frame
rom = open(sys.argv[1], "rb").read()
ARGS["frame"] = int(sys.argv[3])
s = shots.Shooter(rom, "/tmp")
s.shot = lambda nes, name: None
try:
    getattr(s, sys.argv[2])()
except Done:
    pass
