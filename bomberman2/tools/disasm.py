"""Bomberman II disassembler / source generator.

Combines a static trace (aware of the FAR_CALL trampoline and the bank switch
routines) with emulator coverage (cov/*.cdl, *.json), then emits BeebAsm
source for all 8 PRG banks.

Usage: disasm.py REGION [--report] [--out DIR]
"""

import argparse
import glob
import json
import os
import re
import sys
from collections import defaultdict

from m6502 import OPS, SIZE, BRANCHES, load_prg, FIXED

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))

# Key routines are found by byte pattern so that both regions work.
PATTERNS = {
    "FAR_CALL": bytes.fromhex("853386348435688536688537"),
    "BANK_SAVE_SWITCH": bytes.fromhex("ad0001851a8e0001a901851b"),
    "BANK_SWITCH_NMI": bytes.fromhex("8e0001a51bf0"),
}
STUB = 0xBFBC              # reset stub in every switchable bank
FIXED_STUB_END = 0xFFE0    # bank 7: id string + vectors follow

UNKNOWN, OP, OPND, DATA = 0, 1, 2, 3


class Bank:
    def __init__(self, n, prg):
        self.n = n
        self.base = 0xC000 if n == FIXED else 0x8000
        self.mem = prg[n * 0x4000:(n + 1) * 0x4000]
        self.kind = bytearray(0x4000)
        self.insn = {}          # addr -> (op, mnem, mode, size, value)
        self.far = {}           # addr of JSR FAR_CALL -> (bank, target)
        self.fixedbank = {}     # addr of JSR/JMP into $8000 from bank 7 -> bank

    def byte(self, a):
        return self.mem[a - self.base]

    def inside(self, a):
        return self.base <= a < self.base + 0x4000


class Disasm:
    def __init__(self, region):
        self.region = region
        self.prg = load_prg(region)
        self.banks = [Bank(n, self.prg) for n in range(8)]
        self.cdl = bytearray(len(self.prg))
        self.meta = {"tables": {}, "indirect": {}, "calls": [], "ptrs": {}, "partial": {}}
        self.problems = []
        self.labels = {}        # (bank, addr) -> name
        self.refs = defaultdict(set)   # (bank, addr) -> set of (bank, addr) referencing insns
        self.load_coverage()
        fixed = self.prg[FIXED * 0x4000:]
        self.known = {}
        for name, pat in PATTERNS.items():
            i = fixed.find(pat)
            assert i >= 0 and fixed.find(pat, i + 1) < 0, name
            self.known[name] = 0xC000 + i
        self.FAR_CALL = self.known["FAR_CALL"]
        self.known["BANK_SWITCH"] = self.known["BANK_SAVE_SWITCH"] + 5
        self.BANK_SWITCH = {self.known["BANK_SAVE_SWITCH"], self.known["BANK_SWITCH"],
                            self.known["BANK_SWITCH_NMI"]}

    # ------------------------------------------------------------- coverage
    def load_coverage(self):
        for f in glob.glob(os.path.join(ROOT, "cov", self.region + "_*.cdl")):
            data = open(f, "rb").read()
            for i, v in enumerate(data):
                self.cdl[i] |= v
            m = json.load(open(f[:-4] + ".json"))
            for k, v in m["tables"].items():
                self.meta["tables"].setdefault(k, set()).update(v)
            for k, v in m["indirect"].items():
                self.meta["indirect"].setdefault(k, set()).update(map(tuple, v))
            self.meta["calls"].extend(map(tuple, m["calls"]))
            for lo, hi, kind, vals in m.get("ptrs", []):
                self.meta["ptrs"].setdefault((lo, hi, kind), set()).update(map(tuple, vals))
            for b, pc, cnt in m.get("partial", []):
                self.meta["partial"][(b, pc)] = self.meta["partial"].get((b, pc), 0) + cnt
        # Runtime bank of $8000 targets called from the fixed bank
        self.rt_bank = defaultdict(set)
        for sb, spc, tb, t in self.meta["calls"]:
            if spc >= 0xC000 and t < 0xC000:
                self.rt_bank[spc].add(tb)

    def bank_for(self, cur, addr):
        """Bank holding `addr` when executing code of bank `cur`."""
        if addr >= 0xC000:
            return FIXED
        if addr >= 0x8000 and cur != FIXED:
            return cur
        return None

    # ---------------------------------------------------------------- trace
    def trace(self):
        work = []
        b7 = self.banks[FIXED]
        for v in (0xFFFA, 0xFFFC, 0xFFFE):
            work.append((FIXED, b7.byte(v) | b7.byte(v + 1) << 8, None))
        for n in range(7):
            work.append((n, STUB, None))
        # Emulator-executed instruction starts
        for off, v in enumerate(self.cdl):
            if v & 1:
                n = off // 0x4000
                work.append((n, self.banks[n].base + off % 0x4000, None))
        for k, tg in self.meta["indirect"].items():
            for tb, t in tg:
                work.append((tb, t, None))
        while work:
            n, pc, ctx = work.pop()
            self.trace_from(n, pc, ctx, work)

    def trace_from(self, n, pc, ctx, work):
        bank = self.banks[n]
        xbank = None                      # last LDX #imm, for bank switches
        cur = ctx                         # bank mapped at $8000 (fixed bank code)
        while True:
            if not bank.inside(pc):
                return
            off = pc - bank.base
            k = bank.kind[off]
            if k == OP:
                return
            if k in (OPND, DATA):
                self.problems.append("%d:%04X trace runs into %s" % (n, pc, "operand" if k == OPND else "data"))
                return
            op = bank.byte(pc)
            if op not in OPS:
                self.problems.append("%d:%04X illegal opcode %02X" % (n, pc, op))
                return
            mnem, mode = OPS[op]
            size = SIZE[mode]
            if pc + size > bank.base + 0x4000:
                self.problems.append("%d:%04X insn crosses bank end" % (n, pc))
                return
            if self.cdl[n * 0x4000 + off] & 4 and not self.cdl[n * 0x4000 + off] & 1:
                self.problems.append("%d:%04X traced code was read as data at runtime" % (n, pc))
            for i in range(1, size):
                if bank.kind[off + i] != UNKNOWN:
                    self.problems.append("%d:%04X operand overlaps %d:%04X" % (n, pc, n, pc + i))
                    return
            v = None
            if size == 2:
                v = bank.byte(pc + 1)
                if mode == "rel":
                    v = (pc + 2 + ((v ^ 0x80) - 0x80)) & 0xFFFF
            elif size == 3:
                v = bank.byte(pc + 1) | bank.byte(pc + 2) << 8
            bank.kind[off] = OP
            for i in range(1, size):
                bank.kind[off + i] = OPND
            bank.insn[pc] = (op, mnem, mode, size, v)
            nxt = pc + size

            if mnem == "LDX" and mode == "imm":
                xbank = v
            if mode == "rel":
                work.append((n, v, cur))
            elif mnem in ("JSR", "JMP") and mode == "abs":
                if v == self.FAR_CALL and mnem == "JSR":
                    fb = bank.byte(nxt)
                    ft = (bank.byte(nxt + 1) | bank.byte(nxt + 2) << 8) + 1
                    bank.far[pc] = (fb, ft)
                    for i in range(3):
                        bank.kind[off + size + i] = DATA
                    work.append((fb if ft < 0xC000 else FIXED, ft, fb))
                    nxt += 3
                elif v in self.BANK_SWITCH and xbank is not None:
                    cur = xbank
                tb = self.bank_for(n, v)
                if tb is None and v >= 0x8000:
                    cands = self.rt_bank.get(pc, set())
                    if cur is not None:
                        tb = cur
                    elif len(cands) == 1:
                        tb = next(iter(cands))
                    if tb is not None:
                        bank.fixedbank[pc] = tb
                    else:
                        self.problems.append("%d:%04X %s $%04X: unknown bank (runtime %s)" % (n, pc, mnem, v, sorted(cands)))
                if tb is not None and v != self.FAR_CALL:
                    work.append((tb, v, cur))
                if mnem == "JMP":
                    return
            elif mnem == "JMP":
                return
            elif mnem in ("RTS", "RTI", "BRK"):
                return
            pc = nxt

    # --------------------------------------------------------------- report
    def report(self):
        tot = defaultdict(int)
        print("bank  code   data(rt)  unknown   (bytes)")
        for b in self.banks:
            code = sum(1 for k in b.kind if k in (OP, OPND))
            far = sum(1 for k in b.kind if k == DATA)
            rtdata = sum(1 for i in range(0x4000) if self.cdl[b.n * 0x4000 + i] & 4 and b.kind[i] == UNKNOWN)
            unk = sum(1 for i in range(0x4000) if b.kind[i] == UNKNOWN and not self.cdl[b.n * 0x4000 + i] & 4)
            print("%d    %6d  %6d    %6d" % (b.n, code + far, rtdata, unk))
        print("problems: %d" % len(self.problems))
        for p in self.problems[:60]:
            print("  " + p)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("region")
    ap.add_argument("--report", action="store_true")
    args = ap.parse_args()
    d = Disasm(args.region)
    d.trace()
    d.report()


if __name__ == "__main__":
    main()
