"""Runtime inspection of the original ROM in the emulator.

Usage examples
  trace.py us --scenario normal --frames 3000 --watch 0020 --watch 0021 --limit 20
      who writes RAM $20/$21 (pc, bank, value, taint origin)
  trace.py us --scenario attract --frames 600 --reads 0049
      who reads RAM $49
  trace.py us --scenario normal --frames 2000 --break 7:C5E4 --history 30 --limit 1
      stop at an instruction, print the last 30 executed instructions
  trace.py us --scenario normal --frames 2500 --shot /tmp/x.png
      screenshot after N frames

Scenarios are those of cover.py (attract, normal, vs, battle, continue, menu_random).
Frames are counted from power-on; the scenario script provides the inputs.
"""

import argparse
import random
import sys
from collections import deque

import cover
from cover import SCENARIOS
from emu import NES
from m6502 import ROMS, OPS, SIZE, fmt


class Stop(Exception):
    pass


def where(nes, off):
    if off is None:
        return "-"
    b = off // 0x4000
    return "%d:%04X" % (b, (0xC000 if b == 7 else 0x8000) + off % 0x4000)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("region")
    ap.add_argument("--scenario", default="attract")
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--frames", type=int, default=2000)
    ap.add_argument("--watch", action="append", default=[], help="RAM address (hex) to report writes")
    ap.add_argument("--reads", action="append", default=[], help="RAM address (hex) to report reads")
    ap.add_argument("--romread", action="append", default=[], help="bank:addr (hex) of PRG byte: report reads")
    ap.add_argument("--break", dest="brk", action="append", default=[], help="bank:addr (hex) to stop at")
    ap.add_argument("--history", type=int, default=0, help="instructions to print before a break")
    ap.add_argument("--limit", type=int, default=50, help="max reports")
    ap.add_argument("--shot", help="save a screenshot at the end")
    args = ap.parse_args()

    nes = NES(open(ROMS[args.region], "rb").read(), track=False)
    nes.enable_taint()
    watch = {int(a, 16) for a in args.watch}
    reads = {int(a, 16) for a in args.reads}
    brk = {(int(x.split(":")[0]), int(x.split(":")[1], 16)) for x in args.brk}
    hist = deque(maxlen=max(args.history, 1))
    count = [0]

    def report(line):
        print(line)
        count[0] += 1
        if count[0] >= args.limit:
            raise Stop()

    if watch or reads:
        def w(kind, addr, v, pc):
            if kind == "w" and addr in watch or kind == "r" and addr in reads:
                t = nes.ta if kind == "w" else None
                report("frame %5d  %s %04X  pc %d:%04X  value %02X%s" % (
                    nes.frame, "write" if kind == "w" else "read ", addr, nes.bank_of(pc), pc, v,
                    "  (from %s)" % where(nes, t) if kind == "w" and t is not None else ""))
        nes.watch = w

    romread = {int(x.split(":")[0]) * 0x4000 + (int(x.split(":")[1], 16) & 0x3FFF) for x in args.romread}
    if romread:
        rd = nes.rd

        def rd_hook(addr):
            if addr >= 0x8000 and nes.prg_off(addr) in romread:
                pc = nes.cur_pc
                op = nes.prg[nes.prg_off(pc)]
                m, md = OPS.get(op, ("???", "imp"))
                ptr = ""
                if md in ("izy", "izx"):
                    z = nes.prg[nes.prg_off(pc + 1)]
                    if md == "izx":
                        z = (z + nes.x) & 0xFF
                    ptr = "  pointer $%02X=%04X (lo from %s, hi from %s)" % (
                        z, nes.ram[z] | nes.ram[(z + 1) & 0xFF] << 8,
                        where(nes, nes.ram_t[z]), where(nes, nes.ram_t[(z + 1) & 0xFF]))
                report("frame %5d  read %s at pc %d:%04X %s %s  X=%02X Y=%02X%s" % (
                    nes.frame, where(nes, nes.prg_off(addr)), nes.bank_of(pc), pc, m, md, nes.x, nes.y, ptr))
            return rd(addr)
        nes.rd = rd_hook

    step = nes.step

    def stepper():
        pc = nes.pc
        b = nes.bank_of(pc)
        if args.history:
            hist.append((nes.frame, b, pc, nes.a, nes.x, nes.y))
        if (b, pc) in brk:
            if args.history:
                for f, bb, p, a, x, y in hist:
                    def rom(q, bb=bb):
                        return nes.prg[(bb if q < 0xC000 else 7) * 0x4000 + (q & 0x3FFF)]
                    op = rom(p)
                    m, md = OPS.get(op, ("???", "imp"))
                    n = SIZE[md]
                    v = None
                    if n == 2:
                        v = rom(p + 1)
                        if md == "rel":
                            v = (p + 2 + ((v ^ 0x80) - 0x80)) & 0xFFFF
                    elif n == 3:
                        v = rom(p + 1) | rom(p + 2) << 8
                    print("  %5d %d:%04X  A=%02X X=%02X Y=%02X  %s" % (f, bb, p, a, x, y, fmt(m, md, v)))
            report("frame %5d  break at %d:%04X  A=%02X X=%02X Y=%02X  zp00-0F %s" % (
                nes.frame, b, pc, nes.a, nes.x, nes.y, nes.ram[:16].hex()))
        return step()

    if brk or args.history:
        nes.step = stepper

    class Limited:
        """Stop the scenario after --frames."""
        def __getattr__(self, k):
            return getattr(nes, k)

        def __setattr__(self, k, v):
            setattr(nes, k, v)

        def run_frame(self):
            if nes.frame >= args.frames:
                raise Stop()
            return nes.run_frame()

    try:
        SCENARIOS[args.scenario](Limited(), random.Random(args.seed))
        while nes.frame < args.frames:
            nes.run_frame()
    except Stop:
        pass
    print("stopped at frame %d" % nes.frame)
    if args.shot:
        nes.screenshot(args.shot)


if __name__ == "__main__":
    main()
