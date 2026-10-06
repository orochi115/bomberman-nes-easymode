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
        files = glob.glob(os.path.join(ROOT, "cov", self.region + "_*.cdl"))
        files += glob.glob(os.path.join(ROOT, "coverage", self.region + ".cdl"))
        for f in files:
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

    # --------------------------------------------------- declared code
    def declared_code(self):
        """Trace code entry points listed in db/code.tsv (+ shards): code that
        never ran in the coverage runs but is known to be code (e.g. reached
        through a pointer table). Keys: b:XXXX (US), us:b:XXXX, jp:b:XXXX."""
        import glob as _glob
        paths = [os.path.join(ROOT, "db", "code.tsv")] + sorted(_glob.glob(os.path.join(ROOT, "db", "code.d", "*.tsv")))
        self.spec = getattr(self, "spec", set())
        for path in paths:
            if not os.path.exists(path):
                continue
            for ln, line in enumerate(open(path, encoding="utf-8"), 1):
                if line.startswith("#") or not line.strip():
                    continue
                key = line.split("\t")[0].strip()
                parts = key.split(":")
                if len(parts) == 3:
                    if parts[0] != self.region:
                        continue
                    parts = parts[1:]
                elif self.region != "us":
                    continue          # US keys reach JP through the merger
                n, a = int(parts[0]), int(parts[1], 16)
                b = self.banks[n]
                before = bytes(b.kind)
                nprob = len(self.problems)
                work = [(n, a, None)]
                while work:
                    w = work.pop()
                    self.trace_from(w[0], w[1], w[2], work)
                for p in self.problems[nprob:]:
                    p2 = "%s:%d: code entry %s: %s" % (os.path.relpath(path, ROOT), ln, key, p)
                    self.problems.append(p2)
                    self.db_errors.append(p2)
                for bb in self.banks:
                    for pc in bb.insn:
                        off = bb.n * 0x4000 + pc - bb.base
                        if not self.cdl[off] & 1:
                            self.spec.add((bb.n, pc))

    db_errors = []

    # ----------------------------------------------------------- speculate
    def plausible(self, n, pc, strict=True):
        """Check that a never-executed run starting at pc looks like real code.

        Linear decode until RTS/RTI/JMP; every byte must be unclassified and
        never read as data, operands must hit RAM, registers or ROM, and
        branches must stay within the run or land on known code."""
        b = self.banks[n]
        start, seen = pc, []
        while True:
            if not b.inside(pc):
                return None
            off = pc - b.base
            if b.kind[off] != UNKNOWN or self.cdl[n * 0x4000 + off] & 4:
                return None
            op = b.byte(pc)
            if op not in OPS or op == 0x00:
                return None
            mnem, mode = OPS[op]
            size = SIZE[mode]
            for i in range(1, size):
                if not b.inside(pc + i) or b.kind[off + i] != UNKNOWN:
                    return None
            v = None
            if size == 3:
                v = b.byte(pc + 1) | b.byte(pc + 2) << 8
                if 0x0800 <= v < 0x2000 or 0x2008 <= v < 0x4000 or 0x4018 <= v < 0x6000:
                    return None
                if mnem in ("JSR", "JMP") and mode == "abs":
                    tb = self.bank_for(n, v)
                    if tb is None or self.banks[tb].kind[v - self.banks[tb].base] not in (OP, UNKNOWN):
                        return None
            if mode == "rel":
                v = (pc + 2 + ((b.byte(pc + 1) ^ 0x80) - 0x80)) & 0xFFFF
            seen.append((pc, mode, v))
            pc += size
            if mnem in ("RTS", "RTI") or (mnem == "JMP"):
                break
            if len(seen) > 400:
                return None
        if len(seen) < 3:
            return None
        for p, mode, v in seen:
            if mode == "rel" and not start <= v < pc:
                if not b.inside(v) or b.kind[v - b.base] not in ((OP,) if strict else (OP, UNKNOWN)):
                    return None
        return pc

    def speculate(self):
        """Trace plausible code in unclassified gaps that follow code."""
        self.spec = getattr(self, "spec", set())
        changed = True
        while changed:
            changed = False
            for b in self.banks:
                for off in range(1, 0x4000):
                    if b.kind[off] != UNKNOWN or b.kind[off - 1] == UNKNOWN:
                        continue
                    if b.mem[off] == 0xFF:
                        continue
                    pc = b.base + off
                    if self.plausible(b.n, pc) is None:
                        continue
                    before = sum(1 for k in b.kind if k == OP)
                    snapshot = bytes(b.kind)
                    nprob = len(self.problems)
                    self.trace_from(b.n, pc, None, work := [])
                    while work:
                        n2, pc2, ctx = work.pop()
                        self.trace_from(n2, pc2, ctx, work)
                    if len(self.problems) > nprob:
                        # Ran into data: undo
                        b.kind[:] = snapshot
                        for a in list(b.insn):
                            if b.kind[a - b.base] != OP:
                                del b.insn[a]
                        del self.problems[nprob:]
                        continue
                    for i in range(0x4000):
                        if snapshot[i] == UNKNOWN and b.kind[i] == OP:
                            self.spec.add((b.n, b.base + i))
                    changed = True

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
