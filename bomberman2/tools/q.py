"""Query the generated source (index / cross reference) - for humans and agents.

Usage
  q.py show NAME [-n MAX]     source of a routine/table (until the next routine)
  q.py xref NAME              where NAME is used (line, enclosing routine, code)
  q.py ram NAME               accesses to a RAM symbol, grouped by routine (R/W)
  q.py calls NAME             what a routine calls and which RAM it reads/writes
  q.py find REGEX             label / symbol names matching REGEX
  q.py todo [--bank N]        unnamed routines and RAM, most used first
  q.py stats                  naming / comment progress per bank

NAME is a label or symbol as it appears in the source (S5_8123, Z_4B,
FAR_CALL ...) or a US address b:XXXX. Run tools/regen.sh first if db/ changed.
"""

import argparse
import os
import re
import sys
from collections import defaultdict, Counter

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
PLACEHOLDER = re.compile(r"^J?([SLD])(\d)_([0-9A-F]{4})$")
RAM_PH = re.compile(r"^J?([ZWX])_([0-9A-F]{2,4})$")
WRITE_OPS = {"STA", "STX", "STY", "INC", "DEC", "ASL", "LSR", "ROL", "ROR"}


class Source:
    def __init__(self):
        self.lines = []          # (bank, lineno, text)
        self.labels = {}         # name -> index into lines
        self.routine_of = []     # index -> routine name
        self.region = []         # index -> 'both' or regions joined by '+'
        for n in range(8):
            path = os.path.join(ROOT, "bank%d.asm" % n)
            routine, reg, seen = "(bank %d start)" % n, "both", []
            prev_blank = True
            for ln, text in enumerate(open(path, encoding="utf-8"), 1):
                text = text.rstrip("\n")
                s = text.strip()
                m = re.match(r"(IF|ELIF) (REGION.*)$", s)
                if m:
                    conds = re.split(r"\s+OR\s+", m.group(2).split(";")[0].strip())
                    mine = [{"REGION_JP": "jp", "REGION = 0": "us", "REGION = 2": "eu"}.get(c, c)
                            for c in conds]
                    seen = mine if m.group(1) == "IF" else seen + mine
                    reg = "+".join(mine)
                elif s == "ELSE" and reg != "both":
                    reg = "+".join(r for r in ("us", "jp", "eu") if r not in seen)
                elif s == "ENDIF" and reg != "both":
                    reg = "both"
                if s.startswith(".") and not s.startswith(".."):
                    name = s[1:].split()[0]
                    self.labels.setdefault(name, len(self.lines))
                    if prev_blank or not PLACEHOLDER.match(name) or name[0] == "S" or name[:2] == "JS":
                        if prev_blank or name[0] in "SJ" or not PLACEHOLDER.match(name):
                            routine = name if (prev_blank or name.startswith(("S", "JS"))) else routine
                self.lines.append((n, ln, text))
                self.routine_of.append(routine)
                self.region.append(reg)
                prev_blank = (s == "" or s.startswith(";"))
        self.vars = {}
        for path in ("vars.asm", "nesregs.asm"):
            for text in open(os.path.join(ROOT, path), encoding="utf-8"):
                m = re.match(r"\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(&[0-9A-Fa-f]+)", text)
                if m:
                    self.vars.setdefault(m.group(1), []).append(m.group(2))

    def resolve(self, name):
        m = re.match(r"^(\d):([0-9A-Fa-f]{4})$", name)
        if m:
            n, a = int(m.group(1)), int(m.group(2), 16)
            for lab in self.labels:
                pm = PLACEHOLDER.match(lab)
                if pm and int(pm.group(2)) == n and int(pm.group(3), 16) == a and not lab.startswith("J"):
                    return lab
            # named labels: look up db
            from_db = db_names().get("%d:%04X" % (n, a))
            if from_db:
                return from_db
            sys.exit("no label at %s" % name)
        return name

    def uses(self, name):
        pat = re.compile(r"(?<![A-Za-z0-9_])%s(?![A-Za-z0-9_])" % re.escape(name))
        for i, (n, ln, text) in enumerate(self.lines):
            code = text.split(";")[0]
            if code.strip().startswith("."):
                continue
            if pat.search(code):
                yield i


def db_names():
    import glob
    out = {}
    for path in [os.path.join(ROOT, "db", "symbols.tsv")] + glob.glob(os.path.join(ROOT, "db", "symbols.d", "*.tsv")):
        if os.path.exists(path):
            for line in open(path, encoding="utf-8"):
                if line.startswith("#") or not line.strip():
                    continue
                p = line.rstrip("\n").split("\t")
                if len(p) >= 2:
                    out[p[0]] = p[1]
    return out


def where(src, i):
    n, ln, text = src.lines[i]
    reg = src.region[i]
    return "bank%d.asm:%-5d %-22s %s%s" % (n, ln, src.routine_of[i], text.strip(),
                                          "" if reg == "both" else "   [%s only]" % reg.upper())


def cmd_show(src, name, maxn):
    name = src.resolve(name)
    if name not in src.labels:
        sys.exit("unknown label %s" % name)
    i = src.labels[name]
    # include the block comment above
    j = i
    while j > 0 and (src.lines[j - 1][2].startswith(";") or src.lines[j - 1][2].startswith(".")):
        j -= 1
    n = src.lines[i][0]
    print("; bank%d.asm:%d" % (n, src.lines[j][1]))
    count = 0
    pending = []          # comment lines that may belong to the next routine
    for k in range(j, len(src.lines)):
        if src.lines[k][0] != n:
            break
        text = src.lines[k][2]
        if k > i and src.routine_of[k] != src.routine_of[i] and text.strip().startswith("."):
            break
        if k > i and (text.startswith(";") or not text.strip()):
            pending.append(text)
            continue
        for p in pending:
            print(p)
        pending = []
        print(text)
        count += 1
        if count >= maxn:
            print("... (truncated, use -n)")
            break


def cmd_xref(src, name):
    name = src.resolve(name)
    hits = list(src.uses(name))
    for i in hits:
        print(where(src, i))
    print("# %d references to %s" % (len(hits), name), file=sys.stderr)


def cmd_ram(src, name):
    name = src.resolve(name)
    by = defaultdict(Counter)
    for i in src.uses(name):
        code = src.lines[i][2].split(";")[0].split()
        op = code[0] if code else "?"
        mn = op.split("_")[-1] if op.startswith("ABS") else op
        by[src.routine_of[i]]["W" if mn in WRITE_OPS else "R"] += 1
    vals = src.vars.get(name)
    print("%s = %s" % (name, " / ".join(vals) if vals else "?"))
    for r, c in sorted(by.items(), key=lambda x: -sum(x[1].values())):
        print("  %-28s %s" % (r, " ".join("%s%d" % kv for kv in sorted(c.items()))))


def cmd_calls(src, name):
    name = src.resolve(name)
    callees, rams = Counter(), defaultdict(Counter)
    for i, r in enumerate(src.routine_of):
        if r != name:
            continue
        code = src.lines[i][2].split(";")[0].split()
        if not code or code[0].startswith("."):
            continue
        op = code[0]
        arg = code[1] if len(code) > 1 else ""
        if op in ("JSR", "JMP") or op == "FARCALL":
            callees[arg.split(",")[-1].strip()] += 1
        for tok in re.findall(r"[A-Za-z_][A-Za-z0-9_]*", arg):
            if tok in src.vars and not tok.isupper() or RAM_PH.match(tok) or tok in src.vars:
                mn = op.split("_")[-1] if op.startswith("ABS") else op
                rams[tok]["W" if mn in WRITE_OPS else "R"] += 1
    print("calls: " + ", ".join(sorted(callees)))
    print("ram:   " + ", ".join("%s(%s)" % (k, "".join(sorted(v))) for k, v in sorted(rams.items())))


def cmd_find(src, regex):
    pat = re.compile(regex, re.I)
    for name in sorted(set(src.labels) | set(src.vars)):
        if pat.search(name):
            print(name)


def cmd_todo(src, bank):
    refs = Counter()
    for i, (n, ln, text) in enumerate(src.lines):
        code = text.split(";")[0]
        if code.strip().startswith("."):
            continue
        for tok in re.findall(r"[A-Za-z_][A-Za-z0-9_]*", code):
            refs[tok] += 1
    subs = [(refs[l], l) for l in src.labels if re.match(r"^J?S\d_", l)
            and (bank is None or int(re.search(r"S(\d)", l).group(1)) == bank)]
    print("unnamed routines (references):")
    for c, l in sorted(subs, reverse=True)[:60]:
        print("  %-12s %d" % (l, c))
    rams = [(refs[v], v) for v in src.vars if RAM_PH.match(v)]
    print("unnamed RAM (references):")
    for c, v in sorted(rams, reverse=True)[:60]:
        print("  %-12s %d" % (v, c))


def cmd_stats(src):
    print("bank  unnamed routines   named labels   comment lines")
    for n in range(8):
        labs = [l for l, i in src.labels.items() if src.lines[i][0] == n]
        def count(prefix):
            ph = [l for l in labs if re.match(r"^J?%s\d_" % prefix, l)]
            return ph
        subs_ph = count("S")
        named = [l for l in labs if not PLACEHOLDER.match(l)]
        comments = sum(1 for (b, ln, t) in src.lines if b == n and t.startswith(";") and ln > 4)
        print("%d     %8d   %12d   %13d" % (
            n, len(subs_ph), len(named), comments))
    rams = [v for v in src.vars if RAM_PH.match(v)]
    named = [v for v in src.vars if not RAM_PH.match(v)]
    print("RAM symbols: %d placeholders, %d named (incl. registers)" % (len(rams), len(named)))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("cmd")
    ap.add_argument("arg", nargs="?")
    ap.add_argument("-n", type=int, default=200)
    ap.add_argument("--bank", type=int)
    a = ap.parse_args()
    src = Source()
    if a.cmd == "show":
        cmd_show(src, a.arg, a.n)
    elif a.cmd == "xref":
        cmd_xref(src, a.arg)
    elif a.cmd == "ram":
        cmd_ram(src, a.arg)
    elif a.cmd == "calls":
        cmd_calls(src, a.arg)
    elif a.cmd == "find":
        cmd_find(src, a.arg)
    elif a.cmd == "todo":
        cmd_todo(src, a.bank)
    elif a.cmd == "stats":
        cmd_stats(src)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
