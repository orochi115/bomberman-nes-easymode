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
        self.pair_alias = {}   # JP target -> US target, from pointers at the same position
        self.no_alias = set()  # pairs dropped because they would define a label twice
        self.name_alias = {}   # JP key -> US name: same object, one name per region
        self.no_name = set()

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
        def alias(key):
            if key in self.name_alias:
                return self.name_alias[key]
            if key in self.pair_alias:
                return us.name_of(self.pair_alias[key])
            return us.name_of(self.amap[key]) if key in self.amap else None
        jp.alias = alias
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
            # Pointers through the full map (also 'replace' runs, where tables
            # differ): only if the target maps exactly onto the source target.
            # Coordinates or tile bytes that merely look like addresses fail this.
            full = self.rmap if src is self.us else self.amap
            back = self.amap if src is self.us else self.rmap
            for lo, hi, tb, v, adj in list(src.pairs):
                kl = full.get((lo // 0x4000, src.d.banks[lo // 0x4000].base + lo % 0x4000))
                kh = full.get((hi // 0x4000, src.d.banks[hi // 0x4000].base + hi % 0x4000))
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
                if not self.corresponds(dst, (dtb, dv), (tb, v)):
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

    def corresponds(self, dst, dkey, skey):
        """Is dkey (in region dst) the counterpart of skey (other region)?
        Exact address map, or the JP/US target pairing from pointers."""
        if dst is self.jp:
            jk, uk = dkey, skey
        else:
            jk, uk = skey, dkey
        return self.amap.get(jk) == uk or self.pair_alias.get(jk) == uk

    def cross_pointers(self):
        """Raw words that are pointers in both regions: the US word V_us and the
        JP word V_jp at corresponding positions differ, and the address map
        takes V_jp exactly onto V_us (the object moved, the pointer followed).
        Catches table entries that the coverage runs never used."""
        from disasm import UNKNOWN
        us, jp = self.us, self.jp
        found = 0
        for n in range(8):
            ub = us.d.banks[n]
            off = 0
            while off < 0x3FFF:
                a = ub.base + off
                uo = n * 0x4000 + off
                if ub.kind[off] != UNKNOWN or ub.kind[off + 1] != UNKNOWN or uo in us.roles or uo + 1 in us.roles:
                    off += 1
                    continue
                kl, kh = self.rmap.get((n, a)), self.rmap.get((n, a + 1))
                if not kl or not kh or kh[1] != kl[1] + 1:
                    off += 1
                    continue
                jb = jp.d.banks[kl[0]]
                jo = kl[0] * 0x4000 + (kl[1] & 0x3FFF)
                if jb.kind[kl[1] - jb.base] != UNKNOWN or jb.kind[kh[1] - jb.base] != UNKNOWN:
                    off += 1
                    continue
                vu = ub.mem[off] | ub.mem[off + 1] << 8
                vj = jp.d.prg[jo] | jp.d.prg[jo + 1] << 8
                ok = False
                if vu != vj and vu >= 0x8000 and vj >= 0x8000:
                    tb = FIXED if vu >= 0xC000 else n
                    tbj = FIXED if vj >= 0xC000 else kl[0]
                    if tb == tbj or tb == FIXED:
                        ok = self.corresponds(jp, (tbj, vj), (tb, vu))
                if ok and us.add_pair(uo, uo + 1, tb, vu, 0):
                    jp.add_pair(jo, jo + 1, tbj, vj, 0)
                    self.extra["jp"].append((jo, jo + 1, tbj, vj, 0))
                    found += 1
                    off += 2
                else:
                    off += 1
        return found

    def run(self, verbose=True):
        for it in range(6):
            self.align_bytes()
            self.align_ram()
            linked = self.link()
            # pointers.tsv entries keyed by US address are now mappable for JP
            self.jp.roles = self.jp.pointer_roles()
            for p in self.extra["jp"]:
                self.jp.add_pair(*p)
            self.pair_targets()
            moved = self.propagate() + self.cross_pointers()
            if moved:
                self.us.collect()
                self.jp.collect()
            if verbose:
                print("  pass %d: aligned %d bytes, labels linked %s, facts copied %d" % (
                    it, len(self.amap), linked, moved), flush=True)
            if not linked and not moved:
                break

    def pair_targets(self):
        """JP pointer targets correspond to the US targets of the pointer at the
        same position: give them the US name (e.g. JP's ENEMY_WALK_00 table
        moved, so its position maps to some other US data)."""
        us_by_lo = {}
        for lo, hi, tb, v, adj in self.us.pairs:
            us_by_lo[lo] = (tb, v)
        cand = {}
        for lo, hi, tb, v, adj in self.jp.pairs:
            n = lo // 0x4000
            uk = self.amap.get((n, self.jp.d.banks[n].base + lo % 0x4000))
            if uk is None:
                continue
            ulo = uk[0] * 0x4000 + (uk[1] & 0x3FFF)
            ut = us_by_lo.get(ulo)
            if ut is None or self.amap.get((tb, v)) == ut:
                continue
            cand.setdefault((tb, v), set()).add(ut)
        back = {}
        for jt, uts in cand.items():
            if len(uts) == 1:
                back.setdefault(next(iter(uts)), set()).add(jt)
        self.pair_alias = {next(iter(jts)): ut for ut, jts in back.items()
                           if len(jts) == 1 and (next(iter(jts)), ut) not in self.no_alias}
        for jt, ut in self.pair_alias.items():
            prio = {"S": 3, "L": 2, "D": 1}
            k = self.jp.kinds.get(jt, "D")
            if prio[k] > prio.get(self.us.kinds.get(ut), 0):
                self.us.kinds[ut] = k

    def unify_names(self, outdir):
        """Lines that differ only by one label name, where the JP label is
        defined only in the JP build and the US label only in the US build, are
        the same object: give the JP label the US name."""
        import re
        defs = {"us": set(), "jp": set()}
        blocks = []
        for n in range(8):
            region, jp_lines, us_lines = None, [], []
            for line in open(os.path.join(outdir, "bank%d.asm" % n)):
                s = line.rstrip("\n").strip()
                if s == "IF REGION_JP":
                    region, jp_lines, us_lines = "jp", [], []
                    continue
                if s == "ELSE" and region == "jp":
                    region = "us"
                    continue
                if s == "ENDIF" and region:
                    blocks.append((jp_lines, us_lines))
                    region = None
                    continue
                if s.startswith("."):
                    for r in ([region] if region else ["us", "jp"]):
                        defs[r].add(s[1:].split()[0])
                elif s and not s.startswith(";") and region:
                    (jp_lines if region == "jp" else us_lines).append(s.split(";")[0].strip())
        tok = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
        names = {}
        for key in self.jp.kinds:
            names.setdefault(self.jp.name_of(key), key)
        found = {}
        for jl, ul in blocks:
            if len(jl) != len(ul):
                continue
            for a, b in zip(jl, ul):
                ta, tb = tok.findall(a), tok.findall(b)
                if len(ta) != len(tb) or tok.sub("@", a) != tok.sub("@", b):
                    continue
                d = [(x, y) for x, y in zip(ta, tb) if x != y]
                if len(d) != 1:
                    continue
                jn, un = d[0]
                if jn in defs["us"] or un in defs["jp"] or jn not in names:
                    continue
                found.setdefault(names[jn], set()).add(un)
        new = {k: next(iter(v)) for k, v in found.items()
               if len(v) == 1 and (k, next(iter(v))) not in self.no_name}
        changed = any(self.name_alias.get(k) != v for k, v in new.items())
        self.name_alias.update(new)
        return changed

    @staticmethod
    def duplicate_labels(outdir):
        """Label names defined twice in the US or the JP build."""
        import re
        seen = {"us": {}, "jp": {}}
        dups = set()
        for n in range(8):
            region = None
            for line in open(os.path.join(outdir, "bank%d.asm" % n)):
                s = line.strip()
                if s == "IF REGION_JP":
                    region = "jp"
                elif s == "ELSE" and region == "jp":
                    region = "us"
                elif s == "ENDIF" and region:
                    region = None
                elif s.startswith("."):
                    name = s[1:].split()[0]
                    for r in ([region] if region else ["us", "jp"]):
                        if name in seen[r]:
                            dups.add(name)
                        seen[r][name] = True
        return dups

    # ----------------------------------------------------------- render
    def bank_lines(self, n):
        us, jp = self.us, self.jp
        ub = us.d.banks[n]
        U, J = us.items(ub), jp.items(jp.d.banks[n])
        lines = ["; " + "-" * 75,
                 "; PRG bank %d ($%04X-$%04X)" % (n, ub.base, ub.base + 0x3FFF),
                 "; " + "-" * 75, ""]
        shared, du, dj = [], [], []
        segs = []          # ("same", items) | ("diff", us_items, jp_items)

        def flush_shared():
            if shared:
                segs.append(("same", list(shared)))
                del shared[:]

        def flush_diff():
            if du or dj:
                flush_shared()
                # Second pass: identical runs inside the difference (same text,
                # labels included) are emitted once; short identical byte runs
                # stay inside the surrounding difference
                ut = ["\n".join(render([x])) for x in du]
                jt = ["\n".join(render([x])) for x in dj]
                sm = difflib.SequenceMatcher(None, ut, jt, autojunk=False)
                for tag, i1, i2, j1, j2 in sm.get_opcodes():
                    keep = tag == "equal" and (i2 - i1 >= 4 or any(x.kind != "byte" for x in du[i1:i2]))
                    if keep:
                        segs.append(("same", du[i1:i2]))
                    elif segs and segs[-1][0] == "diff":
                        segs[-1][1].extend(du[i1:i2])
                        segs[-1][2].extend(dj[j1:j2])
                    else:
                        segs.append(("diff", list(du[i1:i2]), list(dj[j1:j2])))
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
            if va != u.addr and u.kind != "byte" and render([u]) == render([v]):
                va = u.addr      # same text, labels included: safe to share
            if u.kind == v.kind == "fill" and u.text == v.text:
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
        return lines + self.render_segments(segs)

    def render_segments(self, segs):
        """Coalesce and render: short shared byte runs between two differences
        join them; differences that are only label positions get IF blocks
        around the labels alone."""
        def plain(items):
            return all(x.kind == "byte" and not x.labels and not x.block and not x.eol for x in items)
        out = []
        for seg in segs:
            if (seg[0] == "diff" and len(out) >= 2 and out[-2][0] == "diff"
                    and out[-1][0] == "same" and len(out[-1][1]) < 4 and plain(out[-1][1])):
                mid = out.pop()[1]
                prev = out[-1]
                prev[1].extend(mid + seg[1])
                prev[2].extend(mid + seg[2])
            elif seg[0] == "diff" and out and out[-1][0] == "diff":
                out[-1][1].extend(seg[1])
                out[-1][2].extend(seg[2])
            else:
                out.append((seg[0], list(seg[1])) if seg[0] == "same" else (seg[0], list(seg[1]), list(seg[2])))
        lines = []
        for seg in out:
            if seg[0] == "same":
                lines.extend(render(seg[1]))
                continue
            us_items, jp_items = seg[1], seg[2]
            strip = lambda it: (it.kind, it.text, it.size, tuple(it.block), it.eol)
            if len(us_items) == len(jp_items) and all(strip(a) == strip(b) for a, b in zip(us_items, jp_items)):
                # same code and data, labels at different places
                for a, b in zip(us_items, jp_items):
                    if a.labels != b.labels:
                        self.ndiff += 1
                        lines += ["IF REGION_JP"] + ["." + n for n in b.labels] + ["ELSE"] + \
                                 ["." + n for n in a.labels] + ["ENDIF"]
                    labels, a.labels = a.labels, []
                    lines.extend(render([a]))
                    a.labels = labels
                continue
            self.ndiff += 1
            lines.append("IF REGION_JP")
            lines.extend(render(jp_items))
            lines.append("ELSE")
            lines.extend(render(us_items))
            lines.append("ENDIF")
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
    ap.add_argument("--notes", action="store_true")
    args = ap.parse_args()
    m = Merger()
    m.run()
    m.pair_targets()
    for _ in range(12):
        m.write(args.out)
        dups = m.duplicate_labels(args.out)
        if dups:
            names = {jt: m.us.name_of(ut) for jt, ut in m.pair_alias.items()}
            dropped = {(jt, m.pair_alias[jt]) for jt, nm in names.items() if nm in dups}
            dropped_n = {(k, v) for k, v in m.name_alias.items() if v in dups}
            if not dropped and not dropped_n:
                print("ERROR: duplicate labels %s" % sorted(dups))
                sys.exit(2)
            m.no_alias |= dropped
            m.no_name |= dropped_n
            for k, v in dropped_n:
                m.name_alias.pop(k, None)
            m.pair_targets()
            continue
        if not m.unify_names(args.out):
            break
    print("unified JP names: %d" % len(m.name_alias))
    print("pointer-paired JP labels: %d" % len(m.pair_alias))
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
