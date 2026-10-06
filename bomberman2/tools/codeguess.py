"""List likely code that is still classified as data.

Usage: codeguess.py [REGION]

Candidates are pointer targets (runtime or db/pointers.tsv) that land on
unclassified bytes which decode as plausible code. 'table' means another
entry of the same pointer table already points at known code - a strong
sign (e.g. an AI dispatch table whose unexecuted entries were never traced).
Confirm by reading the bytes, then: tools/db.py code KEY
"""

import sys

from emit import Emitter
from disasm import OP, UNKNOWN


def main():
    region = sys.argv[1] if len(sys.argv) > 1 else "us"
    e = Emitter(region)
    e.collect()
    d = e.d
    pairs = sorted(e.pairs)
    seen = set()
    for i, (lo, hi, tb, v, adj) in enumerate(pairs):
        b = d.banks[tb]
        if not b.inside(v) or (tb, v) in seen:
            continue
        if b.kind[v - b.base] != UNKNOWN:
            continue
        end = d.plausible(tb, v, strict=False)
        if end is None:
            continue
        seen.add((tb, v))
        # neighbours in the same table (lo bytes 1 or 2 apart)
        table = False
        for lo2, hi2, tb2, v2, adj2 in pairs:
            if 0 < abs(lo2 - lo) <= 8 and d.banks[tb2].inside(v2) and \
                    d.banks[tb2].kind[v2 - d.banks[tb2].base] == OP:
                table = True
                break
        n = lo // 0x4000
        print("%d:%04X\tfrom %d:%04X\t%d bytes\t%s" % (
            tb, v, n, d.banks[n].base + lo % 0x4000, end - v, "table" if table else "single"))


if __name__ == "__main__":
    main()
