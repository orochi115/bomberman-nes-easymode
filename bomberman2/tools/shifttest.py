"""Relocation test: run the original and a shifted build side by side.

Usage: shifttest.py REGION SHIFTED.nes [scenario ...]

Both ROMs get the same inputs (cover.py scenarios). Each frame, the PPU/APU
register writes and OAM DMA contents must be identical; a difference means a
hard-coded ROM address was not turned into a label (or data moved that must
not move). Reports the first differing frame and saves screenshots.
"""

import os
import random
import sys

import cover
from cover import SCENARIOS
from emu import NES
from m6502 import ROMS


def where(off):
    if off is None:
        return "-"
    b = off // 0x4000
    return "%d:%04X" % (b, (0xC000 if b == 7 else 0x8000) + off % 0x4000)


def load_ignore():
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "db", "shift_ignore.tsv")
    rng = []
    for line in open(path):
        if line.startswith("#") or not line.strip():
            continue
        a, b = line.split("\t")[:2]
        off = lambda k: int(k.split(":")[0]) * 0x4000 + (int(k.split(":")[1], 16) & 0x3FFF)
        rng.append((off(a), off(b)))
    return rng


IGNORE = load_ignore()


def same(la, lb, sa):
    """Logs equal, except writes whose original data comes from an ignored range."""
    if len(la) != len(lb):
        return False
    for i, (ea, eb) in enumerate(zip(la, lb)):
        if ea != eb:
            src = sa[i][1] if i < len(sa) else None
            if src is None or not any(a <= src <= b for a, b in IGNORE) or ea[1] != eb[1]:
                return False
    return True


class Lockstep(Exception):
    pass


class Pair:
    """Drive two NES instances with identical inputs, frame by frame."""

    def __init__(self, rom_a, rom_b):
        self.a = NES(rom_a, track=False, log_ppu=True)
        self.b = NES(rom_b, track=False, log_ppu=True)
        self.a.enable_taint()
        self.b.enable_taint()
        self.pad = [0, 0]
        self.frame = 0
        self.diff = None
        self.garbage = False
        self.qa = []        # pending (reg, value, src) not yet matched
        self.qb = []

    @property
    def force(self):
        return self.a.force

    @force.setter
    def force(self, f):
        self.a.force = f
        self.b.force = f

    # cover.py's helpers use nes.pad, nes.run_frame and nes.frame
    def run_frame(self):
        self.a.pad = list(self.pad)
        self.b.pad = list(self.pad)
        ra = self.a.run_frame()
        rb = self.b.run_frame()
        self.frame += 1
        # Compare the write streams, not frames: data-dependent timing may move
        # writes across a frame boundary without changing behaviour.
        self.qa += [(e[1], e[2], s) for e, s in zip(self.a.ppulog, self.a.ppusrc)]
        self.qb += [(e[1], e[2], s) for e, s in zip(self.b.ppulog, self.b.ppusrc)]
        self.a.ppulog, self.b.ppulog, self.a.ppusrc, self.b.ppusrc = [], [], [], []
        n = min(len(self.qa), len(self.qb))
        bad = None
        for i in range(n):
            ea, eb = self.qa[i], self.qb[i]
            if self.garbage:
                # Inside an upload that consumed ignored bytes: any PPU_DATA
                # values are accepted until the upload ends.
                if ea[0] == eb[0] == 0x2007:
                    continue
                self.garbage = False
            if ea[:2] != eb[:2]:
                src = ea[2][1]
                if ea[0] != eb[0] or src is None or not any(a <= src <= b for a, b in IGNORE):
                    bad = i
                    break
                self.garbage = True
        if bad is None and (ra is False or rb is False or abs(len(self.qa) - len(self.qb)) > 20000):
            bad = n
        if bad is not None:
            self.diff = (self.frame, self.qa[bad:bad + 1], self.qb[bad:bad + 1], self.a.illegal, self.b.illegal)
            raise Lockstep(self)
        del self.qa[:n]
        del self.qb[:n]


def describe(diff):
    frame, la, lb, ia, ib = diff
    lines = ["first difference by frame %d" % frame]
    if ia or ib:
        lines.append("  stopped: original %r, shifted %r" % (ia, ib))
    fmt = lambda e: "-" if not e else "$%04X=%s  (pc %04X, data from %s)" % (
        e[0][0], e[0][1].hex()[:24] + "..." if isinstance(e[0][1], bytes) else "%02X" % e[0][1],
        e[0][2][0], where(e[0][2][1]))
    lines.append("  original %s" % fmt(la))
    lines.append("  shifted  %s" % fmt(lb))
    return "\n".join(lines)


def main():
    region, shifted = sys.argv[1], sys.argv[2]
    names = sys.argv[3:] or list(SCENARIOS)
    seed = int(os.environ.get("SEED", "1"))
    orig = open(ROMS[region], "rb").read()
    new = open(shifted, "rb").read()
    bad = 0
    for name in names:
        p = Pair(orig, new)
        try:
            SCENARIOS[name](p, random.Random(seed))
            print("%-12s OK (%d frames)" % (name, p.frame), flush=True)
            for x in getattr(p, "extra", []):
                pass
        except Lockstep as ex:
            bad += 1
            p = ex.args[0]          # the pair that diverged (stage runs use copies)
            print("%-12s DIFF %s" % (name, describe(p.diff)), flush=True)
            out = os.environ.get("SHOTS", "/tmp")
            p.a.screenshot(os.path.join(out, "shift_%s_orig.png" % name))
            p.b.screenshot(os.path.join(out, "shift_%s_new.png" % name))
            print("  pc original %04X (bank %d), shifted %04X (bank %d)" % (p.a.pc, p.a.lo, p.b.pc, p.b.lo))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
