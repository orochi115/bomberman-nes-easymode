"""List possible ROM pointers that are still raw numbers in the source.

Usage: suspects.py REGION [--bank N] [--all]

The relocation test only checks code paths that ran. This static scan looks
for the usual pointer shapes among bytes that are not yet expressed with
labels:

  word    two raw data bytes forming an address that hits code or a label
  imm     LDA/LDX/LDY #lo ... #hi stored to zp z and z+1
  split   LDA T1,X / LDA T2,X (raw tables) stored to zp z and z+1

Every suspect must end up either in db/pointers.tsv (it is a pointer) or in
db/notptr.tsv (checked, not a pointer, with a reason). Without --all, the
suspects listed in db/notptr.tsv are hidden.
"""

import argparse
import sys

from emit import Emitter, load_tsv
from disasm import OP, OPND, UNKNOWN, DATA, FIXED


def target_ok(e, n, v, strict):
    """Is v a plausible pointer target seen from bank n?"""
    if v < 0x8000:
        return False
    tb = FIXED if v >= 0xC000 else (n if n != FIXED else None)
    if tb is None:
        return False
    b = e.d.banks[tb]
    k = b.kind[v - b.base]
    if (tb, v) in e.kinds:
        return True
    return k == OP and not strict


def scan(e, bank_filter=None):
    out = []
    roles = e.roles
    for b in e.d.banks:
        if bank_filter is not None and b.n != bank_filter:
            continue
        base = b.n * 0x4000
        raw = lambda a: (b.inside(a) and b.kind[a - b.base] == UNKNOWN and base + a - b.base not in roles)
        # word: raw data pairs
        a = b.base
        while a < b.base + 0x3FFF:
            if raw(a) and raw(a + 1):
                v = b.byte(a) | b.byte(a + 1) << 8
                if target_ok(e, b.n, v, strict=False) and (b.byte(a) or b.byte(a + 1) != 0xFF):
                    # Runs of such words are much more convincing
                    run = 1
                    while raw(a + 2 * run) and raw(a + 2 * run + 1) and target_ok(
                            e, b.n, b.byte(a + 2 * run) | b.byte(a + 2 * run + 1) << 8, False):
                        run += 1
                    conf = "high" if run >= 3 else "med" if (b.n, v) in e.kinds else "low"
                    out.append(("word", "%d:%04X" % (b.n, a), "$%04X" % v, "x%d" % run, conf))
                    a += 2 * run
                    continue
            a += 1
        # imm and split: look at stores to zp pairs
        insns = sorted(b.insn.items())
        for i, (pc, (op, mnem, mode, size, v)) in enumerate(insns):
            if mnem != "STA" or mode != "zp":
                continue
            z = v
            # find the matching store to z+1 nearby
            for j in range(i + 1, min(i + 8, len(insns))):
                pc2, (op2, m2, md2, s2, v2) = insns[j]
                if m2 == "STA" and md2 == "zp" and v2 == z + 1:
                    break
            else:
                continue
            ld1 = insns[i - 1] if i > 0 else None
            ld2 = insns[j - 1]
            if not ld1 or ld1[1][1] != "LDA" or ld2[1][1] != "LDA":
                continue
            (p1, (o1, _, md1, _, v1)), (p2, (o2, _, md2b, _, v2b)) = ld1, ld2
            if md1 == "imm" and md2b == "imm":
                if base + p1 + 1 - b.base in roles or base + p2 + 1 - b.base in roles:
                    continue
                val = v1 | v2b << 8
                if target_ok(e, b.n, val, strict=False):
                    out.append(("imm", "%d:%04X" % (b.n, p1 + 1), "$%04X" % val, "hi %d:%04X" % (b.n, p2 + 1), "high"))
            elif md1 in ("abx", "aby") and md2b == md1 and v1 >= 0x8000 and v2b >= 0x8000:
                tb1 = FIXED if v1 >= 0xC000 else b.n
                if tb1 == FIXED and b.n == FIXED and v1 < 0xC000:
                    continue
                tbk = e.d.banks[tb1]
                ok = 0
                for k in range(64):
                    lo_a, hi_a = v1 + k, v2b + k
                    if not (tbk.inside(lo_a) and tbk.inside(hi_a)):
                        break
                    if tbk.base * 0 + tb1 * 0x4000 + (lo_a & 0x3FFF) in roles:
                        ok = -1
                        break
                    val = tbk.byte(lo_a) | tbk.byte(hi_a) << 8
                    if target_ok(e, tb1, val, strict=False):
                        ok += 1
                if ok > 0:
                    out.append(("split", "%d:%04X" % (tb1, v1), "lo/hi", "hi %d:%04X (%d hits)" % (tb1, v2b, ok), "high"))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("region")
    ap.add_argument("--bank", type=int)
    ap.add_argument("--all", action="store_true", help="also show suspects listed in db/notptr.tsv")
    ap.add_argument("--low", action="store_true", help="also show low-confidence word suspects")
    args = ap.parse_args()
    e = Emitter(args.region)
    e.collect()
    known = {row[0] for ln, row in load_tsv("notptr.tsv")}
    rows = [r for r in scan(e, args.bank) if (args.all or r[1] not in known) and (args.low or r[4] != "low")]
    order = {"high": 0, "med": 1, "low": 2}
    rows.sort(key=lambda r: (order[r[4]], r[1]))
    for r in rows:
        print("\t".join(r))
    counts = {}
    for r in rows:
        counts[r[4]] = counts.get(r[4], 0) + 1
    print("# %d suspects %s" % (len(rows), counts), file=sys.stderr)


if __name__ == "__main__":
    main()
