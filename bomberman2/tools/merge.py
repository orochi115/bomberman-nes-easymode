"""Generate one source for both regions (IF REGION_JP ... ELSE ... ENDIF).

Usage: merge.py [--out DIR]

1. Each bank is aligned byte by byte (difflib on raw bytes, with the address
   operands of instructions masked), giving a JP -> US address map.
2. RAM operands of aligned instructions give the JP -> US RAM map.
3. JP labels at aligned addresses take the US names; facts found by one
   region's coverage (code, pointers) are copied to the other region.
4. Items are paired by address; equal items are emitted once, the rest go
   into IF REGION_JP blocks.
Writes bank0-7.asm, macros.asm, vars.asm and db/jpmap.tsv.
"""

import argparse
import difflib
import os
import sys
from collections import Counter

from emit import Emitter, render, ROOT, FIXED

MASK = 0x100     # masked operand byte


class Merger:
    def __init__(self):
        self.us = Emitter("us")
        self.jp = Emitter("jp")
        self.us.collect()
        self.jp.collect()
        self.amap = {}     # jp key -> us key
        self.rmap = {}     # us key -> jp key
        self.extra = {"us": [], "jp": []}

    # ------------------------------------------------------------ align
    @staticmethod
    def symbols(e, n):
        """Raw bytes of bank n, address operands of instructions masked."""
        b = e.d.banks[n]
        syms = list(b.mem)
        for pc, (op, mnem, mode, size, v) in b.insn.items():
            if mode not in ("imp", "acc", "imm"):
                for i in range(1, size):
                    syms[pc - b.base + i] = MASK
        for pc in b.far:
            for i in range(1, 6):
                syms[pc - b.base + i] = MASK
        return syms

    def align_bytes(self):
        amap = {}
        eqmap = {}    # only bytes inside 'equal' runs: safe for copying facts
        for n in range(8):
            base = self.us.d.banks[n].base
            us, jp = self.symbols(self.us, n), self.symbols(self.jp, n)
            sm = difflib.SequenceMatcher(None, us, jp)
            for tag, i1, i2, j1, j2 in sm.get_opcodes():
                long_equal = tag == "equal" and i2 - i1 >= 8
                if tag == "equal" or (tag == "replace" and i2 - i1 == j2 - j1):
                    for d in range(i2 - i1):
                        amap[(n, base + j1 + d)] = (n, base + i1 + d)
                        if long_equal:      # short equal runs can be coincidences
                            eqmap[(n, base + j1 + d)] = (n, base + i1 + d)
        self.amap = amap
        self.rmap = {v: k for k, v in amap.items()}
        self.eqmap = eqmap
        self.reqmap = {v: k for k, v in eqmap.items()}

    def norm_items(self, e, n):
        e.norm = True
        try:
            return e.items(e.d.banks[n])
        finally:
            e.norm = False

    def align_ram(self):
        votes = Counter()
        for n in range(8):
            ji = {it.addr: it for it in self.norm_items(self.jp, n)}
            for u in self.norm_items(self.us, n):
                if u.kind != "insn" or not u.rams:
                    continue
                k = self.rmap.get((n, u.addr))
                j = ji.get(k[1]) if k else None
                if j and j.text == u.text and len(j.rams) == len(u.rams):
                    for a, b in zip(j.rams, u.rams):
                        votes[(a, b)] += 1
        best, used = {}, set()
        for (a, b), c in votes.most_common():
            if a not in best and b not in used:
                best[a] = b
                used.add(b)
        self.jp.ram_alias = best

    def link(self):
        """JP labels at aligned addresses use (and create) the US label."""
        us, jp = self.us, self.jp
        changed = False
        prio = {"S": 3, "L": 2, "D": 1}
        for key, kind in list(jp.kinds.items()):
            uk = self.amap.get(key)
            if uk is not None and prio[kind] > prio.get(us.kinds.get(uk), 0):
                us.kinds[uk] = kind
                changed = True
        for key, kind in list(us.kinds.items()):
            jk = self.rmap.get(key)
            if jk is not None and prio[kind] > prio.get(jp.kinds.get(jk), 0):
                jp.kinds[jk] = kind
                changed = True
        jp.alias = lambda key: us.name_of(self.amap[key]) if key in self.amap else None
        # db entries keyed by US address also apply to JP through the full map
        # (tables whose values moved); emit.py validates the bytes and skips
        # entries that do not fit, with a note
        jp.alias_key = lambda uk: self.rmap.get(uk)
        return changed

    def propagate(self):
        """Share what one region's coverage found with the other region."""
        changed = 0
        # Only through byte-identical runs: a 'replace' run of the same length can
        # hold different tables in the two regions (e.g. coordinates vs pointers).
        for src, dst, fwd in ((self.us, self.jp, self.reqmap), (self.jp, self.us, self.eqmap)):
            # pointers: map where the lo/hi bytes are, take the target from the
            # bytes actually present in the other region
            for lo, hi, tb, v, adj in list(src.pairs):
                kl = fwd.get((lo // 0x4000, src.d.banks[lo // 0x4000].base + lo % 0x4000))
                kh = fwd.get((hi // 0x4000, src.d.banks[hi // 0x4000].base + hi % 0x4000))
                if kl is None or kh is None:
                    continue
                dlo = kl[0] * 0x4000 + (kl[1] & 0x3FFF)
                dhi = kh[0] * 0x4000 + (kh[1] & 0x3FFF)
                if dlo in dst.roles and dhi in dst.roles:
                    continue
                dv = ((dst.d.prg[dlo] | dst.d.prg[dhi] << 8) + adj) & 0xFFFF
                if dv < 0x8000:
                    continue
                own = lo // 0x4000
                dtb = FIXED if dv >= 0xC000 else (kl[0] if tb == own else tb)
                if dtb == FIXED and dv < 0xC000:
                    continue
                if dst.add_pair(dlo, dhi, dtb, dv, adj):
                    self.extra[dst.region].append((dlo, dhi, dtb, dv, adj))
                    changed += 1
            # code entry points
            for b in src.d.banks:
                for pc in list(b.insn):
                    k = fwd.get((b.n, pc))
                    if k is None:
                        continue
                    db = dst.d.banks[k[0]]
                    if db.kind[k[1] - db.base] == 0 and db.byte(k[1]) == b.byte(pc):
                        work = []
                        dst.d.trace_from(k[0], k[1], None, work)
                        while work:
                            w = work.pop()
                            dst.d.trace_from(w[0], w[1], w[2], work)
                        changed += 1
        return changed

    def run(self, verbose=True):
        for it in range(6):
            self.align_bytes()
            self.align_ram()
            linked = self.link()
            # pointers.tsv entries keyed by US address are now mappable for JP
            self.jp.roles = self.jp.pointer_roles()
            for p in self.extra["jp"]:
                self.jp.add_pair(*p)
            moved = self.propagate()
            if moved:
                self.us.collect()
                self.jp.collect()
            if verbose:
                print("  pass %d: aligned %d bytes, labels linked %s, facts copied %d" % (
                    it, len(self.amap), linked, moved), flush=True)
            if not linked and not moved:
                break

    # ----------------------------------------------------------- render
    def bank_lines(self, n):
        us, jp = self.us, self.jp
        ub = us.d.banks[n]
        U, J = us.items(ub), jp.items(jp.d.banks[n])
        lines = ["; " + "-" * 75,
                 "; PRG bank %d ($%04X-$%04X)" % (n, ub.base, ub.base + 0x3FFF),
                 "; " + "-" * 75, ""]
        shared, du, dj = [], [], []

        def flush_shared():
            if shared:
                lines.extend(render(shared))
                del shared[:]

        def flush_diff():
            if du or dj:
                flush_shared()
                self.ndiff += 1
                lines.append("IF REGION_JP")
                lines.extend(render(dj))
                lines.append("ELSE")
                lines.extend(render(du))
                lines.append("ENDIF")
                del du[:]
                del dj[:]

        i = j = 0
        while i < len(U) or j < len(J):
            u = U[i] if i < len(U) else None
            v = J[j] if j < len(J) else None
            if u is None:
                dj.append(v)
                j += 1
                continue
            if v is None:
                du.append(u)
                i += 1
                continue
            va = self.amap.get((n, v.addr), (None, None))[1]
            if u.kind in ("pad", "raw") and v.kind == u.kind:
                va = u.addr
            if va == u.addr and (u.size == v.size or u.kind == v.kind == "fill"):
                if render([u]) == render([v]) or (u.kind == v.kind and u.text == v.text):
                    flush_diff()
                    for name in v.labels:
                        if name not in u.labels:
                            u.labels.append(name)
                    shared.append(u)
                else:
                    du.append(u)
                    dj.append(v)
                i += 1
                j += 1
            elif va is None:
                dj.append(v)
                j += 1
            elif (n, u.addr) not in self.rmap:
                du.append(u)
                i += 1
            elif va < u.addr:
                dj.append(v)
                j += 1
            else:
                du.append(u)
                i += 1
        flush_diff()
        flush_shared()
        return lines

    def write(self, outdir):
        self.ndiff = 0
        self.us.ram_used, self.jp.ram_used = {}, {}
        for n in range(8):
            text = "\n".join(self.bank_lines(n)) + "\n"
            open(os.path.join(outdir, "bank%d.asm" % n), "w").write(text)
        us, jp = self.us, self.jp
        us.force_macros |= jp.force_macros
        open(os.path.join(outdir, "macros.asm"), "w").write(us.emit_macros())
        open(os.path.join(outdir, "vars.asm"), "w").write(us.emit_vars(jp))
        with open(os.path.join(ROOT, "db", "jpmap.tsv"), "w") as f:
            f.write("# Generated by tools/merge.py: JP address -> US address of aligned bytes\n")
            for (n, a), (n2, a2) in sorted(self.amap.items()):
                f.write("%d:%04X\t%d:%04X\n" % (n, a, n2, a2))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=ROOT)
    args = ap.parse_args()
    m = Merger()
    m.run()
    m.write(args.out)
    print("IF REGION_JP blocks %d" % m.ndiff)
    bad = 0
    for e in (m.us, m.jp):
        notes = sorted(set(e.warnings))
        if notes and "--notes" in sys.argv:
            for w in notes:
                print("  note: " + w)
        elif notes:
            print("  %d US db entries have no JP counterpart (merge.py --notes lists them)" % len(notes))
        if e.conflicts or e.unresolved:
            print("%s: %d conflicts, %d unresolved" % (e.region, len(e.conflicts), len(set(e.unresolved))))
            for c in (e.conflicts + sorted(set(e.unresolved)))[:40]:
                print("  " + c)
            # Problems caused by db/ entries must be fixed by whoever wrote them
            bad += sum(1 for c in e.conflicts if ".tsv" in c or c.startswith("pointers:"))
        for p in e.d.db_errors:
            print("  " + p)
            bad += 1
    if bad:
        print("ERROR: %d db entries could not be applied (see above)" % bad)
        sys.exit(2)


if __name__ == "__main__":
    main()
