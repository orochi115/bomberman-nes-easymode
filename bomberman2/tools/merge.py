"""Generate one source for US, JP and EU (IF / ELIF / ELSE).

Usage: merge.py [--out DIR]

1. Each bank is aligned byte by byte (difflib on raw bytes, with the address
   operands of instructions masked), giving a JP -> US address map.
2. RAM operands of aligned instructions give the JP -> US RAM map.
3. JP labels at aligned addresses take the US names; facts found by one
   region's coverage (code, pointers) are copied to the other region.
4. Items are paired by address; equal items are emitted once, the rest go
   into IF REGION_JP blocks.
Writes bank0-7.asm, macros.asm, vars.asm, db/jpmap.tsv and db/eumap.tsv.
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
        self.eu = Emitter("eu")
        self.emitters = {"us": self.us, "jp": self.jp, "eu": self.eu}
        for e in self.emitters.values():
            e.collect()
        self.amap = {}     # jp key -> us key
        self.rmap = {}     # us key -> jp key
        self.eumap = {}    # eu key -> us key
        self.eurmap = {}
        self.extra = {"us": [], "jp": [], "eu": []}
        self.pair_alias = {}   # JP target -> US target, from pointers at the same position
        self.eu_alias = {}
        self.no_alias = set()  # pairs dropped because they would define a label twice
        self.no_eu_alias = set()
        self.name_alias = {}   # JP key -> US name: same object, one name per region
        self.eu_name = {}
        self.no_name = set()
        self.no_eu_name = set()

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

    def _align_one(self, other):
        amap, eqmap = {}, {}
        for n in range(8):
            base = self.us.d.banks[n].base
            us, ot = self.symbols(self.us, n), self.symbols(other, n)
            sm = difflib.SequenceMatcher(None, us, ot)
            for tag, i1, i2, j1, j2 in sm.get_opcodes():
                long_equal = tag == "equal" and i2 - i1 >= 8
                if tag == "equal" or (tag == "replace" and i2 - i1 == j2 - j1):
                    for d in range(i2 - i1):
                        amap[(n, base + j1 + d)] = (n, base + i1 + d)
                        if long_equal:
                            eqmap[(n, base + j1 + d)] = (n, base + i1 + d)
        return amap, eqmap

    def align_bytes(self):
        amap, eqmap = self._align_one(self.jp)
        self.amap, self.eqmap = amap, eqmap
        self.rmap = {v: k for k, v in amap.items()}
        self.reqmap = {v: k for k, v in eqmap.items()}
        eumap, eueq = self._align_one(self.eu)
        self.eumap, self.eueq = eumap, eueq
        self.eurmap = {v: k for k, v in eumap.items()}
        self.eureq = {v: k for k, v in eueq.items()}

    def norm_items(self, e, n):
        e.norm = True
        try:
            return e.items(e.d.banks[n])
        finally:
            e.norm = False

    def _ram_alias(self, other, rmap):
        votes = Counter()
        for n in range(8):
            oi = {it.addr: it for it in self.norm_items(other, n)}
            for u in self.norm_items(self.us, n):
                if u.kind != "insn" or not u.rams:
                    continue
                k = rmap.get((n, u.addr))
                o = oi.get(k[1]) if k else None
                if o and o.text == u.text and len(o.rams) == len(u.rams):
                    for a, b in zip(o.rams, u.rams):
                        votes[(a, b)] += 1
        best, used = {}, set()
        for (a, b), c in votes.most_common():
            if a not in best and b not in used:
                best[a] = b
                used.add(b)
        other.ram_alias = best

    def align_ram(self):
        self._ram_alias(self.jp, self.rmap)
        self._ram_alias(self.eu, self.eurmap)

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
        for key, kind in list(self.eu.kinds.items()):
            uk = self.eumap.get(key)
            if uk is not None and prio[kind] > prio.get(us.kinds.get(uk), 0):
                us.kinds[uk] = kind
                changed = True
        for key, kind in list(us.kinds.items()):
            ek = self.eurmap.get(key)
            if ek is not None and prio[kind] > prio.get(self.eu.kinds.get(ek), 0):
                self.eu.kinds[ek] = kind
                changed = True
        def eu_alias(key):
            if key in self.eu_name:
                return self.eu_name[key]
            if key in self.eu_alias:
                return us.name_of(self.eu_alias[key])
            return us.name_of(self.eumap[key]) if key in self.eumap else None
        self.eu.alias = eu_alias
        self.eu.alias_key = lambda uk: self.eurmap.get(uk)
        return changed

    def propagate(self):
        """Share what one region's coverage found with the other region."""
        changed = 0
        # Only through byte-identical runs: a 'replace' run of the same length can
        # hold different tables in the two regions (e.g. coordinates vs pointers).
        trips = ((self.us, self.jp, self.reqmap, self.rmap),
                 (self.jp, self.us, self.eqmap, self.amap),
                 (self.us, self.eu, self.eureq, self.eurmap),
                 (self.eu, self.us, self.eueq, self.eumap))
        for src, dst, fwd, full in trips:
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
                if not self.corresponds(dst, (dtb, dv), (tb, v), src):
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

    def _us_key(self, emitter, key):
        if emitter is self.us:
            return key
        if emitter is self.jp:
            return self.pair_alias.get(key) or self.amap.get(key)
        return self.eu_alias.get(key) or self.eumap.get(key)

    def corresponds(self, dst, dkey, skey, src=None):
        """Is dkey (in region dst) the counterpart of skey (in src)?"""
        if src is None:
            src = self.us if dst is not self.us else self.jp
        a, b = self._us_key(dst, dkey), self._us_key(src, skey)
        return a is not None and a == b

    def _cross(self, other, rmap):
        """Words that are pointers in US and `other` and whose targets correspond."""
        from disasm import UNKNOWN
        us = self.us
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
                kl, kh = rmap.get((n, a)), rmap.get((n, a + 1))
                if not kl or not kh or kh[1] != kl[1] + 1:
                    off += 1
                    continue
                ob = other.d.banks[kl[0]]
                oo = kl[0] * 0x4000 + (kl[1] & 0x3FFF)
                if ob.kind[kl[1] - ob.base] != UNKNOWN or ob.kind[kh[1] - ob.base] != UNKNOWN:
                    off += 1
                    continue
                vu = ub.mem[off] | ub.mem[off + 1] << 8
                vo = other.d.prg[oo] | other.d.prg[oo + 1] << 8
                ok = False
                if vu != vo and vu >= 0x8000 and vo >= 0x8000:
                    tb = FIXED if vu >= 0xC000 else n
                    tbo = FIXED if vo >= 0xC000 else kl[0]
                    if tb == tbo or tb == FIXED:
                        ok = self.corresponds(other, (tbo, vo), (tb, vu), us)
                if ok and us.add_pair(uo, uo + 1, tb, vu, 0):
                    other.add_pair(oo, oo + 1, tbo, vo, 0)
                    self.extra[other.region].append((oo, oo + 1, tbo, vo, 0))
                    found += 1
                    off += 2
                else:
                    off += 1
        return found

    def cross_pointers(self):
        return self._cross(self.jp, self.rmap) + self._cross(self.eu, self.eurmap)

    def run(self, verbose=True):
        for it in range(6):
            self.align_bytes()
            self.align_ram()
            linked = self.link()
            # pointers.tsv entries keyed by US address are now mappable for JP
            for other, amap in ((self.jp, self.rmap), (self.eu, self.eurmap)):
                other.roles = other.pointer_roles()
                for p in self.extra[other.region]:
                    other.add_pair(*p)
            self.pair_targets()
            moved = self.propagate() + self.cross_pointers()
            if moved:
                for e in self.emitters.values():
                    e.collect()
            if verbose:
                print("  pass %d: aligned jp %d eu %d, labels linked %s, facts copied %d" % (
                    it, len(self.amap), len(self.eumap), linked, moved), flush=True)
            if not linked and not moved:
                break

    def _pair_one(self, other, amap, banned):
        us_by_lo = {}
        for lo, hi, tb, v, adj in self.us.pairs:
            us_by_lo[lo] = (tb, v)
        cand = {}
        for lo, hi, tb, v, adj in other.pairs:
            n = lo // 0x4000
            uk = amap.get((n, other.d.banks[n].base + lo % 0x4000))
            if uk is None:
                continue
            ulo = uk[0] * 0x4000 + (uk[1] & 0x3FFF)
            ut = us_by_lo.get(ulo)
            if ut is None or amap.get((tb, v)) == ut:
                continue
            cand.setdefault((tb, v), set()).add(ut)
        back = {}
        for jt, uts in cand.items():
            if len(uts) == 1:
                back.setdefault(next(iter(uts)), set()).add(jt)
        alias = {next(iter(jts)): ut for ut, jts in back.items()
                 if len(jts) == 1 and (next(iter(jts)), ut) not in banned}
        prio = {"S": 3, "L": 2, "D": 1}
        for jt, ut in alias.items():
            k = other.kinds.get(jt, "D")
            if prio[k] > prio.get(self.us.kinds.get(ut), 0):
                self.us.kinds[ut] = k
        return alias

    def pair_targets(self):
        """Pointer targets in JP/EU take the US name when the pointer moved with the object."""
        self.pair_alias = self._pair_one(self.jp, self.amap, self.no_alias)
        self.eu_alias = self._pair_one(self.eu, self.eumap, self.no_eu_alias)

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
                if s.startswith("IF ") and s != "IF REGION_JP":
                    region = "skip"
                    continue
                if s == "IF REGION_JP":
                    region, jp_lines, us_lines = "jp", [], []
                    continue
                if region == "skip":
                    if s == "ENDIF":
                        region = None
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
    def _holds(cond, region):
        REGION = {"us": 0, "jp": 1, "eu": 2}[region]
        REGION_JP = -1 if REGION == 1 else 0
        expr = cond.replace("=", "==").replace(" OR ", " or ").replace(" AND ", " and ")
        return bool(eval(expr, {"__builtins__": {}}, {"REGION": REGION, "REGION_JP": REGION_JP}))

    def duplicate_labels(self, outdir):
        """Label names defined twice in one region's build."""
        seen = {r: {} for r in ("us", "jp", "eu")}
        dups = set()
        for n in range(8):
            stack = [{"parent": {"us", "jp", "eu"}, "taken": set(), "active": {"us", "jp", "eu"}}]
            for line in open(os.path.join(outdir, "bank%d.asm" % n)):
                s = line.strip()
                if s.startswith("IF ") or s.startswith("ELIF "):
                    cond = s.split(None, 1)[1]
                    if s.startswith("IF "):
                        parent = stack[-1]["active"]
                        match = {r for r in parent if self._holds(cond, r)}
                        stack.append({"parent": parent, "taken": set(match), "active": match})
                    else:
                        top = stack[-1]
                        match = {r for r in top["parent"] if self._holds(cond, r)} - top["taken"]
                        top["taken"] |= match
                        top["active"] = match
                    continue
                if s == "ELSE":
                    top = stack[-1]
                    top["active"] = set(top["parent"]) - top["taken"]
                    continue
                if s == "ENDIF" and len(stack) > 1:
                    stack.pop()
                    continue
                if s.startswith("."):
                    name = s[1:].split()[0]
                    for r in stack[-1]["active"]:
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
        return lines + self.with_eu(n, segs)

    def with_eu(self, n, segs):
        """Merge EU items into the US/JP segmentation, one item at a time."""
        atoms = []
        for seg in segs:
            if seg[0] == "same":
                for it in seg[1]:
                    atoms.append([it, it, None])
            else:
                # zip by the same address walk already done; lengths may differ
                us_items, jp_items = seg[1], seg[2]
                iu = ij = 0
                while iu < len(us_items) or ij < len(jp_items):
                    u = us_items[iu] if iu < len(us_items) else None
                    j = jp_items[ij] if ij < len(jp_items) else None
                    if u is None:
                        atoms.append([None, j, None]); ij += 1; continue
                    if j is None:
                        atoms.append([u, None, None]); iu += 1; continue
                    va = self.amap.get((n, j.addr), (None, None))[1]
                    if j.kind in ("pad", "raw") and u.kind == j.kind:
                        va = u.addr
                    if u.kind == j.kind == "fill" and u.text == j.text:
                        va = u.addr
                    if va == u.addr:
                        atoms.append([u, j, None]); iu += 1; ij += 1
                    elif va is None or (va is not None and va < u.addr):
                        atoms.append([None, j, None]); ij += 1
                    else:
                        atoms.append([u, None, None]); iu += 1
        E = self.eu.items(self.eu.d.banks[n])
        k = 0
        out_atoms = []
        for atom in atoms:
            u = atom[0]
            target = u.addr if u is not None else (self.amap.get((n, atom[1].addr), (None, None))[1] if atom[1] is not None else None)
            while k < len(E):
                e = E[k]
                ea = e.addr if e.kind in ("pad", "raw", "fill") else self._us_addr("eu", n, e)
                if target is None:
                    break
                if ea is None or ea < target:
                    out_atoms.append([None, None, e]); k += 1; continue
                if ea == target and (u is None or e.size == u.size or e.kind == u.kind == "fill"):
                    atom[2] = e
                    k += 1
                break
            out_atoms.append(atom)
        while k < len(E):
            out_atoms.append([None, None, E[k]]); k += 1
        # fold EU labels into a shared item and drop EU when the text matches
        folded = []
        for u, j, e in out_atoms:
            if u is not None and j is not None and e is not None and self._same_item(u, j) and self._same_item(u, e):
                for name in e.labels:
                    if name not in u.labels:
                        u.labels.append(name)
                folded.append(("same", [u]))
            else:
                folded.append(("tri", [u] if u else [], [j] if j else [], [e] if e else []))
        # coalesce adjacent tri/same of the same shape is left to render
        merged = []
        for seg in folded:
            if seg[0] == "tri" and merged and merged[-1][0] == "tri":
                for i in range(1, 4):
                    merged[-1][i].extend(seg[i])
            elif seg[0] == "same" and merged and merged[-1][0] == "same":
                merged[-1][1].extend(seg[1])
            else:
                merged.append(seg)
        return self.render_segments(merged)

    def _us_addr(self, region, n, it):
        amap = self.amap if region == "jp" else self.eumap
        m = amap.get((n, it.addr))
        return m[1] if m else None

    @staticmethod
    def _same_item(a, b):
        return render([a]) == render([b]) or (a.kind == b.kind and a.text == b.text)

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
            elif seg[0] == "tri":
                out.append(("tri", list(seg[1]), list(seg[2]), list(seg[3])))
            else:
                out.append((seg[0], list(seg[1])) if seg[0] == "same" else (seg[0], list(seg[1]), list(seg[2])))
        lines = []
        for seg in out:
            if seg[0] == "same":
                lines.extend(render(seg[1]))
                continue
            if seg[0] == "tri":
                lines.extend(self.render_tri(seg[1], seg[2], seg[3]))
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

    def render_tri(self, us_items, jp_items, eu_items):
        blocks = {"us": render(us_items), "jp": render(jp_items), "eu": render(eu_items)}
        if blocks["eu"] == blocks["jp"] == blocks["us"]:
            return blocks["us"]
        self.ndiff += 1
        if blocks["eu"] == blocks["us"]:
            return ["IF REGION_JP"] + blocks["jp"] + ["ELSE"] + blocks["us"] + ["ENDIF"]
        if blocks["eu"] == blocks["jp"]:
            return ["IF REGION_JP OR REGION = 2"] + blocks["jp"] + ["ELSE"] + blocks["us"] + ["ENDIF"]
        if blocks["jp"] == blocks["us"]:
            return ["IF REGION = 2"] + blocks["eu"] + ["ELSE"] + blocks["us"] + ["ENDIF"]
        return (["IF REGION = 2"] + blocks["eu"] + ["ELIF REGION_JP"] + blocks["jp"]
                + ["ELSE"] + blocks["us"] + ["ENDIF"])

    def copy_tables(self):
        """Indexed tables found in the US coverage apply at the aligned EU/JP address."""
        src = self.us.d.meta.get("tables") or {}
        for other, rmap in ((self.jp, self.rmap), (self.eu, self.eurmap)):
            dst = other.d.meta.setdefault("tables", {})
            for k, idx in src.items():
                b, a = k.split(":")
                ek = rmap.get((int(b), int(a, 16)))
                if ek:
                    dst.setdefault("%d:%04X" % (ek[0], ek[1]), idx)

    def write(self, outdir):
        self.copy_tables()
        self.ndiff = 0
        for e in self.emitters.values():
            e.ram_used = {}
        for n in range(8):
            text = "\n".join(self.bank_lines(n)) + "\n"
            open(os.path.join(outdir, "bank%d.asm" % n), "w").write(text)
        us, jp, eu = self.us, self.jp, self.eu
        us.force_macros |= jp.force_macros | eu.force_macros
        open(os.path.join(outdir, "macros.asm"), "w").write(us.emit_macros())
        open(os.path.join(outdir, "vars.asm"), "w").write(us.emit_vars_multi({"jp": jp, "eu": eu}))
        for name, amap in (("jpmap.tsv", self.amap), ("eumap.tsv", self.eumap)):
            with open(os.path.join(ROOT, "db", name), "w") as f:
                f.write("# Generated by tools/merge.py: region address -> US address of aligned bytes\n")
                for (n, a), (n2, a2) in sorted(amap.items()):
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
            names.update({jt: m.us.name_of(ut) for jt, ut in m.eu_alias.items()})
            dropped = {(jt, m.pair_alias[jt]) for jt, nm in names.items() if nm in dups and jt in m.pair_alias}
            dropped_eu = {(jt, m.eu_alias[jt]) for jt, nm in names.items() if nm in dups and jt in m.eu_alias}
            dropped_n = {(k, v) for k, v in m.name_alias.items() if v in dups}
            dropped_en = {(k, v) for k, v in m.eu_name.items() if v in dups}
            if not dropped and not dropped_n and not dropped_eu and not dropped_en:
                print("ERROR: duplicate labels %s" % sorted(dups))
                sys.exit(2)
            m.no_alias |= dropped
            m.no_eu_alias |= dropped_eu
            m.no_name |= dropped_n
            m.no_eu_name |= dropped_en
            for k, v in dropped_n:
                m.name_alias.pop(k, None)
            for k, v in dropped_en:
                m.eu_name.pop(k, None)
            m.pair_targets()
            continue
        if not m.unify_names(args.out):
            break
    print("unified JP names: %d" % len(m.name_alias))
    print("pointer-paired JP labels: %d EU %d" % (len(m.pair_alias), len(m.eu_alias)))
    print("IF REGION_JP blocks %d" % m.ndiff)
    bad = 0
    for e in (m.us, m.jp, m.eu):
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
