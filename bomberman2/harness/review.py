"""Acceptance helper: show a task's db entries next to the code they describe.

Usage: harness/review.py TASK [--lines N] [--only names|comments|pointers]

Run tools/regen.sh first so that the source uses the new names.
"""

import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
sys.path.insert(0, os.path.join(ROOT, "tools"))

from q import Source  # noqa: E402


def shard(name, task):
    path = os.path.join(ROOT, "db", name + ".d", task + ".tsv")
    if not os.path.exists(path):
        return []
    out = []
    for line in open(path, encoding="utf-8"):
        if line.strip() and not line.startswith("#"):
            out.append(line.rstrip("\n").split("\t"))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("task")
    ap.add_argument("--lines", type=int, default=6)
    ap.add_argument("--only")
    a = ap.parse_args()
    src = Source()
    syms = shard("symbols", a.task)
    comments = {}
    for row in shard("comments", a.task):
        comments.setdefault(row[0], []).append((row[1], row[2]))
    if a.only in (None, "names"):
        print("### names (%d)" % len(syms))
        for row in syms:
            key, name = row[0], row[1]
            note = row[2] if len(row) > 2 else ""
            print("\n== %-10s %-32s %s" % (key, name, note))
            for kind, text in comments.get(key, []):
                for l in text.split("\\n"):
                    print("   %s %s" % (kind, l))
            if key.startswith("ram:"):
                vals = src.vars.get(name)
                users = sorted({src.routine_of[i] for i in src.uses(name)})
                print("   = %s, used by %d routines: %s" % (" / ".join(vals or ["?"]), len(users), ", ".join(users[:8])))
                continue
            if name in src.labels:
                i = src.labels[name]
                for k in range(i + 1, min(i + 1 + a.lines, len(src.lines))):
                    print("   | " + src.lines[k][2])
    if a.only in (None, "comments"):
        named = {r[0] for r in syms}
        rest = {k: v for k, v in comments.items() if k not in named}
        print("\n### comments on unnamed keys (%d)" % len(rest))
        for k, v in rest.items():
            for kind, text in v:
                print("  %s %s %s" % (k, kind, text[:150]))
    if a.only in (None, "pointers"):
        for f in ("pointers", "notptr"):
            rows = shard(f, a.task)
            print("\n### %s (%d)" % (f, len(rows)))
            for r in rows:
                print("  " + "  ".join(r))


if __name__ == "__main__":
    main()
