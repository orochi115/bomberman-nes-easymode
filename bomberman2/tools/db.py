"""Edit and check the naming database (db/*.tsv and db/*.d/TASK.tsv shards).

Usage
  db.py name KEY NAME [COMMENT]      name a label / RAM location
  db.py comment KEY '>' TEXT         block comment above KEY (use \\n for new lines)
  db.py comment KEY ';' TEXT         end-of-line comment at KEY
  db.py pointer KEY word [N] | split HIKEY N | lo HIKEY  [bank=B] [adj=1]
  db.py notptr KEY REASON            suspect checked: not a pointer
  db.py code KEY                     KEY is code that the coverage runs never executed
  db.py unname KEY                   remove this task's entry for KEY
  db.py lint                         check every shard for clashes

KEY: b:XXXX (US address; bank b, 7 = fixed bank), ram:XXXX, jp:b:XXXX for
JP-only code, or a placeholder as it appears in the source (S5_8123, L7_C02D,
D4_9241, Z_4B, W_0550, X_62A0, JS5_8123 for JP-only).
Edits go to db/<file>.d/$BM2_TASK.tsv (default: manual).
"""

import glob
import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
DB = os.path.join(ROOT, "db")
TASK = os.environ.get("BM2_TASK", "manual")

IDENT = re.compile(r"^[A-Z][A-Z0-9_]*$")
PLACEHOLDER = re.compile(r"^J?([SLD]\d_[0-9A-F]{4}|[ZWX]_[0-9A-F]{2,4})$")
MNEMONICS = set("""ADC AND ASL BCC BCS BEQ BIT BMI BNE BPL BRK BVC BVS CLC CLD CLI CLV CMP CPX CPY
DEC DEX DEY EOR INC INX INY JMP JSR LDA LDX LDY LSR NOP ORA PHA PHP PLA PLP ROL ROR RTI RTS SBC
SEC SED SEI STA STX STY TAX TAY TSX TXA TXS TYA""".split())
RESERVED = MNEMONICS | {"A", "X", "Y", "LO", "HI", "P%", "TRUE", "FALSE", "PI", "AND", "OR", "EOR",
                        "DIV", "MOD", "NOT", "SHIFT", "REGION_JP", "FARCALL", "FILLTO", "PAD",
                        "RESET_STUB", "MMC1_CONTROL", "MMC1_CHR0", "MMC1_CHR1", "MMC1_PRG"}


def regs():
    names = set()
    for path in ("nesregs.asm", "consts.asm"):
        for line in open(os.path.join(ROOT, path)):
            m = re.match(r"\s*([A-Za-z_][A-Za-z0-9_]*)\s*=", line)
            if m:
                names.add(m.group(1))
    return names


def key_of(arg):
    """Normalise a KEY argument."""
    m = PLACEHOLDER.match(arg)
    if m:
        jp = arg.startswith("J")
        a = arg[1:] if jp else arg
        if a[0] in "ZWX":
            if jp:
                sys.exit("JP-only RAM %s: name the US variable instead (see vars.asm)" % arg)
            return "ram:%04X" % int(a[2:], 16)
        n, addr = a[1], a[3:]
        return ("jp:" if jp else "") + "%s:%s" % (n, addr)
    m = re.match(r"^(jp:|us:)?(\d):([0-9A-Fa-f]{4})$", arg)
    if m:
        n, a = int(m.group(2)), int(m.group(3), 16)
        if not (0 <= n <= 7):
            sys.exit("bank must be 0-7")
        if n == 7 and a < 0xC000 or n != 7 and not 0x8000 <= a < 0xC000:
            sys.exit("%s: bank %d covers %s" % (arg, n, "$C000-$FFFF" if n == 7 else "$8000-$BFFF"))
        return "%s%d:%04X" % (m.group(1) or "", n, a)
    m = re.match(r"^ram:([0-9A-Fa-f]{1,4})$", arg)
    if m:
        return "ram:%04X" % int(m.group(1), 16)
    # an existing name: find its key
    for path, ln, row in rows("symbols.tsv"):
        if row[1] == arg:
            return row[0]
    sys.exit("unknown KEY %s" % arg)


def shard_files(name):
    stem = name[:-4]
    return [os.path.join(DB, name)] + sorted(glob.glob(os.path.join(DB, stem + ".d", "*.tsv")))


def rows(name):
    for path in shard_files(name):
        if not os.path.exists(path):
            continue
        for ln, line in enumerate(open(path, encoding="utf-8"), 1):
            line = line.rstrip("\n")
            if line.strip() and not line.startswith("#"):
                yield path, ln, line.split("\t")


def own_shard(name):
    stem = name[:-4]
    d = os.path.join(DB, stem + ".d")
    os.makedirs(d, exist_ok=True)
    return os.path.join(d, TASK + ".tsv")


def write_rows(path, keep, new=None):
    """Rewrite a shard, keeping rows where keep(row) and appending new.
    Holds an exclusive lock so that parallel db.py calls do not lose rows."""
    import fcntl
    with open(path + ".lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        _write_rows(path, keep, new)


def _write_rows(path, keep, new=None):
    lines = []
    if os.path.exists(path):
        for line in open(path, encoding="utf-8"):
            if line.startswith("#") or not line.strip() or keep(line.rstrip("\n").split("\t")):
                lines.append(line.rstrip("\n"))
    if new:
        lines.append(new)
    open(path, "w", encoding="utf-8").write("\n".join(lines) + "\n")


def norm_key(k):
    """Comparable form of a db key (keys may be written in different case)."""
    parts = k.split(":")
    return ":".join(parts[:-1] + ["%04X" % int(parts[-1], 16)])


def check_name(name, key):
    if not IDENT.match(name):
        return "%s: names are UPPER_CASE letters, digits and _" % name
    if PLACEHOLDER.match(name):
        return "%s looks like a placeholder" % name
    if name in RESERVED or name in regs():
        return "%s is reserved" % name
    if len(name) > 40:
        return "%s is too long" % name
    for path, ln, row in rows("symbols.tsv"):
        if row[1] == name and norm_key(row[0]) != norm_key(key):
            return "%s is already used for %s (%s:%d)" % (name, row[0], os.path.relpath(path, ROOT), ln)
    return None


def cmd_name(key, name, comment):
    err = check_name(name, key)
    if err:
        sys.exit(err)
    mine = own_shard("symbols.tsv")
    for path, ln, row in rows("symbols.tsv"):
        if norm_key(row[0]) == norm_key(key) and path != mine:
            sys.exit("%s is already named %s in %s:%d (ask the reviewer to change it)" % (
                key, row[1], os.path.relpath(path, ROOT), ln))
    write_rows(mine, lambda r: norm_key(r[0]) != norm_key(key),
               "\t".join([key, name] + ([comment] if comment else [])))
    print("%s = %s" % (key, name))


def cmd_comment(key, kind, text):
    if kind not in (">", ";"):
        sys.exit("comment kind must be '>' or ';'")
    if "\t" in text:
        sys.exit("no tabs in comments")
    text = text.replace("\r", "").replace("\n", "\\n")   # real newlines -> \n
    mine = own_shard("comments.tsv")
    write_rows(mine, lambda r: not (norm_key(r[0]) == norm_key(key) and r[1] == kind),
               "\t".join([key, kind, text]))
    print("comment %s %s" % (key, kind))


def cmd_lint():
    problems = []
    seen_key, seen_name = {}, {}
    for path, ln, row in rows("symbols.tsv"):
        where = "%s:%d" % (os.path.relpath(path, ROOT), ln)
        if len(row) < 2:
            problems.append("%s: needs KEY<TAB>NAME" % where)
            continue
        k, name = norm_key(row[0]), row[1]
        if not IDENT.match(name) or name in RESERVED or PLACEHOLDER.match(name):
            problems.append("%s: bad name %s" % (where, name))
        if k in seen_key and seen_key[k][0] != name:
            problems.append("%s: %s named %s, but %s says %s" % (where, k, name, seen_key[k][1], seen_key[k][0]))
        if name in seen_name and seen_name[name][0] != k:
            problems.append("%s: name %s also used for %s at %s" % (where, name, seen_name[name][0], seen_name[name][1]))
        seen_key.setdefault(k, (name, where))
        seen_name.setdefault(name, (k, where))
    for path, ln, row in rows("comments.tsv"):
        if len(row) != 3 or row[1] not in (">", ";"):
            problems.append("%s:%d: needs KEY<TAB>>|;<TAB>TEXT" % (os.path.relpath(path, ROOT), ln))
    for p in problems:
        print(p)
    print("lint: %d problems" % len(problems))
    return 1 if problems else 0


def main():
    a = sys.argv[1:]
    if not a:
        sys.exit(__doc__)
    cmd = a[0]
    if cmd == "name" and len(a) in (3, 4):
        cmd_name(key_of(a[1]), a[2], a[3].replace("\n", " ") if len(a) > 3 else None)
    elif cmd == "comment" and len(a) == 4:
        cmd_comment(key_of(a[1]), a[2], a[3])
    elif cmd == "pointer" and len(a) >= 3:
        key = key_of(a[1])
        args = [key_of(x) if re.match(r"^(jp:|us:)?\d:[0-9A-Fa-f]{4}$", x) else x for x in a[2:]]
        mine = own_shard("pointers.tsv")
        write_rows(mine, lambda r: norm_key(r[0]) != norm_key(key), "\t".join([key] + args))
        print("pointer %s %s" % (key, " ".join(args)))
    elif cmd == "code" and len(a) == 2:
        key = key_of(a[1])
        mine = own_shard("code.tsv")
        write_rows(mine, lambda r: norm_key(r[0]) != norm_key(key), key)
        print("code %s" % key)
    elif cmd == "notptr" and len(a) == 3:
        key = key_of(a[1]) if not re.match(r"^\d:[0-9A-F]{4}$", a[1]) else a[1]
        mine = own_shard("notptr.tsv")
        write_rows(mine, lambda r: r[0] != key, "\t".join([key, a[2]]))
        print("notptr %s" % key)
    elif cmd == "unname" and len(a) == 2:
        key = key_of(a[1])
        for f in ("symbols.tsv", "comments.tsv", "pointers.tsv", "code.tsv", "notptr.tsv"):
            p = own_shard(f)
            if os.path.exists(p):
                write_rows(p, lambda r: norm_key(r[0]) != norm_key(key))
        print("removed %s from %s" % (key, TASK))
    elif cmd == "lint":
        sys.exit(cmd_lint())
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
