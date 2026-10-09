"""Generate BeebAsm source for Bomberman II from the disassembly analysis.

Usage: emit.py REGION [--out DIR]

Inputs
  ROM + cov/REGION_*.cdl|json (via disasm.Disasm)
  db/symbols.tsv   KEY  NAME  [comment]     KEY = b:XXXX (ROM bank b) or ram:XXXX
  db/comments.tsv  KEY  KIND  TEXT          KIND ';' end of line, '>' block before
                                            (TEXT may contain \\n)
Output
  bank0.asm .. bank7.asm, macros.asm, vars.asm in DIR (default: ..)
"""

import argparse
import os
import re
from collections import defaultdict

from disasm import Disasm, OP, OPND, DATA, UNKNOWN, FIXED, ROOT, STUB
from m6502 import OPS, SIZE

REGS = {
    0x2000: "PPU_CTRL_REG1", 0x2001: "PPU_CTRL_REG2", 0x2002: "PPU_STATUS",
    0x2003: "PPU_SPR_ADDR", 0x2004: "PPU_SPR_DATA", 0x2005: "PPU_SCROLL_REG",
    0x2006: "PPU_ADDRESS", 0x2007: "PPU_DATA",
    0x4000: "APU_REG_BASE", 0x4004: "APU_SQUARE2_REG", 0x4008: "APU_TRIANGLE_REG",
    0x400C: "APU_NOISE_REG", 0x4010: "APU_DMC_FREQ_REG", 0x4011: "APU_DMC_RAW_REG",
    0x4012: "APU_DMC_START_REG", 0x4013: "APU_DMC_LEN_REG", 0x4014: "PPU_SPR_DMA",
    0x4015: "APU_MASTERCTRL_REG", 0x4016: "JOYPAD_PORT1", 0x4017: "JOYPAD_PORT2",
}
MMC1 = {0x9FFF: "MMC1_CONTROL", 0xBFFF: "MMC1_CHR0", 0xDFFF: "MMC1_CHR1", 0xFFFF: "MMC1_PRG"}
WRITES = {"STA", "STX", "STY", "INC", "DEC", "ASL", "LSR", "ROL", "ROR"}
ZP_MODE = {"abs": "zp", "abx": "zpx", "aby": "zpy"}

DB = os.path.join(ROOT, "db")
MAXSHIFT = 256  # largest SHIFT the relocation test uses
DPCM = 0xE000   # start of the DPCM samples in bank 7 ($C000 + 64 * n)


def h2(v):
    return "&%02X" % v


def h4(v):
    return "&%04X" % v


class Item:
    """One source element: an instruction, a data byte, a pointer, a fill..."""
    __slots__ = ("addr", "size", "kind", "text", "labels", "block", "eol", "sub", "rams")

    def __init__(self, addr, size, kind, text):
        self.addr, self.size, self.kind, self.text = addr, size, kind, text
        self.labels, self.block, self.eol, self.sub = [], [], None, False
        self.rams = []

    def token(self):
        return ("B%02X" % self.text) if self.kind == "byte" else self.kind[0] + self.text


def render(items, indent="  "):
    """Source lines for items; consecutive data bytes are grouped into EQUB lines."""
    lines = []
    run = []

    def flush():
        if run:
            lines.append(indent + "EQUB " + ",".join(h2(x) for x in run))
            del run[:]
    for it in items:
        if it.labels or it.block or it.eol or it.kind != "byte" or len(run) >= 16:
            flush()
        for text in it.block:
            lines.append("")
            lines += ["; " + l if l else ";" for l in text.split("\n")]
        if it.labels and it.sub and not it.block:
            lines.append("")
        lines += ["." + n for n in it.labels]
        if it.kind == "byte":
            run.append(it.text)
            if it.eol:
                lines.append("%-40s; %s" % (indent + "EQUB " + h2(it.text), it.eol))
                del run[:]
            continue
        line = indent + it.text
        if it.eol:
            line = "%-40s; %s" % (line, it.eol)
        lines.append(line)
    flush()
    return lines


def load_tsv(name):
    """Rows of db/NAME plus db/NAME.d/*.tsv shards (one shard per harness task).
    Returns [(where, columns)] with where = "file:line"."""
    import glob
    stem = name[:-4] if name.endswith(".tsv") else name
    paths = [os.path.join(DB, name)] + sorted(glob.glob(os.path.join(DB, stem + ".d", "*.tsv")))
    rows = []
    for path in paths:
        if not os.path.exists(path):
            continue
        rel = os.path.relpath(path, ROOT)
        for ln, line in enumerate(open(path, encoding="utf-8"), 1):
            line = line.rstrip("\n")
            if not line.strip() or line.startswith("#"):
                continue
            rows.append(("%s:%d" % (rel, ln), line.split("\t")))
    return rows


def parse_key(k):
    a, b = k.split(":")
    return (a if a == "ram" else int(a), int(b, 16))


class Emitter:
    prev_spec = False

    def __init__(self, region):
        self.d = Disasm(region)
        self.d.trace()
        self.d.db_errors = []
        self.d.declared_code()
        self.d.speculate()
        self.region = region
        self.names = {}            # (bank|'ram', addr) -> name
        self.symcomment = {}
        self.comments = defaultdict(list)   # (bank, addr) -> [(kind, text)]
        # db keys: ram:XXXX, b:XXXX (US address, shared code), us:b:XXXX, jp:b:XXXX
        for ln, row in load_tsv("symbols.tsv"):
            key = self.own_key(row[0])
            if key is None:
                continue
            self.names[key] = row[1]
            if len(row) > 2 and row[2]:
                self.symcomment[key] = row[2]
        for ln, row in load_tsv("comments.tsv"):
            key = self.own_key(row[0])
            if key is not None:
                self.comments[key].append((row[1], row[2].replace("\\n", "\n")))
        self.labels = {}           # (bank, addr) -> name (ROM labels to define)
        self.kinds = {}            # (bank, addr) -> 'S' | 'L' | 'D'
        self.inner = {}            # (bank, addr) -> (bank, insn addr, offset) labels inside an insn
        self.force_macros = set()
        self.cur_rams = []
        self.ram_used = {}         # RAM symbol name -> address in this region
        self.unresolved = []
        self.conflicts = []
        self.warnings = []
        self.roles = self.pointer_roles()

    def pointer_roles(self):
        """PRG offset -> ('lo'|'hi', (bank, target), adjust) from runtime pointer uses."""
        roles = {}
        self.conflicts = [c for c in self.conflicts if not c.startswith(("pointer", "PRG byte", "db/"))]
        self.warnings = []
        self.pairs = []          # (lo off, hi off, target bank, target, adj)
        for (lo, hi, kind), vals in self.d.meta["ptrs"].items():
            if len(vals) != 1:
                self.conflicts.append("pointer %d:%d used with several banks/targets %s" % (lo, hi, sorted(vals)))
                continue
            tb, v = next(iter(vals))
            adj = 0
            if kind == "rts":
                v, adj = v - 1, 1                 # stored as target - 1
            tb = FIXED if v >= 0xC000 else tb
            self.pairs.append((lo, hi, tb, v + adj, adj))
            for off, part in ((lo, "lo"), (hi, "hi")):
                n = off // 0x4000
                b = self.d.banks[n]
                a = b.base + off % 0x4000
                # Bytes inside FARCALL records are handled by the macro
                if b.kind[off % 0x4000] == DATA:
                    continue
                if b.kind[off % 0x4000] == OPND:
                    st = a
                    while b.kind[st - b.base] != OP:
                        st -= 1
                    if b.insn[st][2] != "imm":
                        self.conflicts.append("pointer byte %d:%04X is a non-immediate operand" % (n, a))
                        continue
                new = (part, (tb, v + adj), adj)
                if off in roles and roles[off] != new:
                    self.conflicts.append("PRG byte %d:%04X has two pointer roles %r %r" % (n, a, roles[off], new))
                    continue
                roles[off] = new
        # Pointers declared in db/pointers.tsv
        for ln, row in load_tsv("pointers.tsv"):
            try:
                self.db_pointer(roles, row)
            except Exception as e:
                self.conflicts.append("%s: %s" % (ln, e))
        return roles

    def db_pointer(self, roles, row):
        """KEY word [N] | KEY split HIKEY N | KEY lo HIKEY  [bank=B] [adj=1]"""
        opts = dict(x.split("=") for x in row[2:] if "=" in x)
        args = [x for x in row[1:] if "=" not in x]
        kind = args[0]
        lo_key = self.region_key(row[0])
        if lo_key is None:
            return
        n, a = lo_key
        if kind == "word":
            pairs = [(a + 2 * i, a + 2 * i + 1) for i in range(int(args[1]) if len(args) > 1 else 1)]
            hn = n
        else:
            hk = self.region_key(args[1])
            if hk is None:
                return           # the high byte has no counterpart in this region
            hn, ha = hk
            cnt = int(args[2]) if kind == "split" else 1
            pairs = [(a + i, ha + i) for i in range(cnt)]
        adj = int(opts.get("adj", 0))
        if opts.get("ram"):
            # #LO/#HI of a RAM address: rendered with the RAM symbol, whose value
            # is per region (vars.asm)
            for la, ha in pairs:
                lo_off = n * 0x4000 + (la & 0x3FFF)
                hi_off = hn * 0x4000 + (ha & 0x3FFF)
                v = self.d.prg[lo_off] | self.d.prg[hi_off] << 8
                bad = self.bad_pointer_bytes("lo", lo_off, hi_off)
                if bad or self.ram_placeholder(v) is None:
                    (self.warnings if self.region != "us" else self.conflicts).append(
                        "pointers: %s ram: %s" % (row[0], bad or "$%04X is not RAM" % v))
                    continue
                roles[lo_off] = ("lo", ("ram", v), 0)
                roles[hi_off] = ("hi", ("ram", v), 0)
            return
        for la, ha in pairs:
            lo_off = n * 0x4000 + (la & 0x3FFF)
            hi_off = hn * 0x4000 + (ha & 0x3FFF)
            raw = self.d.prg[lo_off] | self.d.prg[hi_off] << 8
            if raw in (0x0000, 0xFFFF):
                continue                 # null / end marker inside a pointer table
            v = raw + adj
            tb = FIXED if v >= 0xC000 else int(opts.get("bank", n if n != FIXED else -1))
            if tb < 0:
                raise ValueError("pointer to $%04X from the fixed bank needs bank=" % v)
            bad = self.bad_pointer_bytes(kind, lo_off, hi_off)
            if bad:
                if self.region != "us" and len(row[0].split(":")) == 2:
                    self.warnings.append("pointers: US %s does not apply to %s (%s)" % (row[0], self.region.upper(), bad))
                else:
                    self.conflicts.append("pointers: %s %s: %s (skipped)" % (row[0], kind, bad))
                continue
            if not self.d.banks[tb].inside(v):
                if self.region != "us" and len(row[0].split(":")) == 2:
                    # US-keyed entry whose JP counterpart differs: US only
                    self.warnings.append("pointers: US %s does not apply to %s (%d:%04X holds $%04X)" % (
                        row[0], self.region.upper(), n, la, v))
                else:
                    self.conflicts.append("pointers: %d:%04X holds $%04X, not an address in bank %d (skipped)" % (n, la, v, tb))
                continue
            self.pairs.append((lo_off, hi_off, tb, v, adj))
            for off, part in ((lo_off, "lo"), (hi_off, "hi")):
                new = (part, (tb, v), adj)
                if off in roles and roles[off] != new:
                    raise ValueError("byte %d:%04X already has role %r" % (off // 0x4000, off % 0x4000, roles[off]))
                roles[off] = new

    def bad_pointer_bytes(self, kind, lo_off, hi_off):
        """A declared pointer must be data bytes ('word', 'split'), or data or
        immediate operands ('lo'); never opcodes or other operands."""
        for off in (lo_off, hi_off):
            n, a = off // 0x4000, off % 0x4000
            b = self.d.banks[n]
            k = b.kind[a]
            if k == UNKNOWN:
                continue
            if k == OPND and kind == "lo":
                st = b.base + a - 1
                if st in b.insn and b.insn[st][2] == "imm":
                    continue
            return "%d:%04X is %s" % (n, b.base + a, {OP: "an opcode", OPND: "an operand",
                                                      DATA: "inside a FARCALL"}.get(k, "code"))
        return None

    def region_key(self, k):
        """db key -> (bank, addr) for this region, or None if it is another region's."""
        parts = k.split(":")
        if len(parts) == 3:
            if parts[0] != self.region:
                return None
            parts = parts[1:]
        elif self.region != "us":
            return self.alias_key((int(parts[0]), int(parts[1], 16)))
        return (int(parts[0]), int(parts[1], 16))

    def alias_key(self, us_key):
        """Map a US address to this region (identity for US; set by the merger)."""
        return us_key

    def add_pair(self, lo_off, hi_off, tb, v, adj):
        """Add a pointer (lo/hi PRG offsets -> target) unless it clashes."""
        new = {}
        for off, part in ((lo_off, "lo"), (hi_off, "hi")):
            n, a = off // 0x4000, off % 0x4000
            b = self.d.banks[n]
            k = b.kind[a]
            if k == DATA:
                return False
            if k == OPND:
                st = b.base + a - 1
                if st not in b.insn or b.insn[st][2] != "imm":
                    return False
            elif k != UNKNOWN:
                return False
            role = (part, (tb, v), adj)
            if off in self.roles and self.roles[off] != role:
                return False
            new[off] = role
        self.roles.update(new)
        self.pairs.append((lo_off, hi_off, tb, v, adj))
        return True

    def ptr_expr(self, role):
        part, (tb, v), adj = role
        if tb == "ram":
            return "%s(%s)" % ("LO" if part == "lo" else "HI", self.ram(v, 2))
        e = self.expr_of((tb, v))
        if adj:
            e = "%s-%d" % (e, adj)
        return "%s(%s)" % ("LO" if part == "lo" else "HI", e)

    # ------------------------------------------------------------ labels
    def want(self, bank, addr, kind):
        """Request a label at (bank, addr); returns the expression to use."""
        b = self.d.banks[bank]
        if not b.inside(addr):
            return None
        key = (bank, addr)
        prio = {"S": 3, "L": 2, "D": 1}
        if prio[kind] > prio.get(self.kinds.get(key), 0):
            self.kinds[key] = kind
        return key

    norm = False      # True: all ROM labels render as '@' (for aligning regions)
    alias = None      # merger: own key -> name of the matching US label

    def name_of(self, key):
        if self.norm:
            return "@"
        if self.alias is not None:
            name = self.alias(key)
            if name:
                return name
        if key in self.names:
            return self.names[key]
        bank, addr = key
        return "%s%s%d_%04X" % ("" if self.region == "us" else self.region[0].upper(),
                                self.kinds.get(key, "D"), bank, addr)

    def expr_of(self, key):
        """Expression for a requested ROM address (handles mid-instruction)."""
        bank, addr = key
        b = self.d.banks[bank]
        off = addr - b.base
        if b.kind[off] == OPND:
            start = addr
            while b.kind[start - b.base] != OP:
                start -= 1
            base = (bank, start)
            if base not in self.kinds:
                self.kinds[base] = "L"
            return "%s+%d" % (self.name_of(base), addr - start)
        return self.name_of(key)

    ram_alias = None   # merger (JP): own RAM address -> US RAM address

    @staticmethod
    def ram_placeholder(v):
        if v < 0x100:
            return "Z_%02X" % v
        if v < 0x800:
            return "W_%04X" % v
        if 0x6000 <= v < 0x8000:
            return "X_%04X" % v
        return None

    def ram(self, v, width):
        """RAM/WRAM operands are symbols named after the US address
        (placeholder Z_xx / W_xxxx / X_xxxx until db/symbols.tsv names them)."""
        if 0x2000 <= v < 0x4020 and v in REGS:
            return REGS[v]
        if self.ram_placeholder(v) is None:
            return h2(v) if width == 1 else h4(v)
        self.cur_rams.append(v)
        if self.norm:
            return "@"
        uv = v
        if self.ram_alias is not None:
            uv = self.ram_alias.get(v)
            if uv is None:
                name = "J" + self.ram_placeholder(v)
                self.ram_used[name] = v
                return name
        name = self.names.get(("ram", uv)) or self.ram_placeholder(uv)
        self.ram_used[name] = v
        return name

    # ---------------------------------------------------------- operands
    def rom_target(self, bank, pc, mnem, mode, v):
        """(bank, addr) key for a ROM operand, or None if unknown."""
        if v >= 0xC000:
            return (FIXED, v)
        if bank != FIXED:
            return (bank, v)
        fb = self.d.banks[FIXED].fixedbank.get(pc)
        if fb is not None:
            return (fb, v)
        cands = {int(k.split(":")[0]) for k in self.d.meta["tables"] if int(k.split(":")[1], 16) == v and int(k.split(":")[0]) != FIXED}
        if len(cands) == 1:
            return (cands.pop(), v)
        self.unresolved.append("%d:%04X %s %s" % (bank, pc, mnem, h4(v)))
        return None

    def collect(self):
        """First pass: decide which labels exist."""
        for b in self.d.banks:
            for pc, (op, mnem, mode, size, v) in b.insn.items():
                if mode == "rel":
                    self.want(b.n, v, "L")
                elif size == 3 and v >= 0x8000:
                    if mnem in WRITES:
                        continue
                    if pc in b.far:
                        fb, ft = b.far[pc]
                        self.want(fb if ft < 0xC000 else FIXED, ft, "S")
                        self.want(FIXED, v, "S")
                        continue
                    key = self.rom_target(b.n, pc, mnem, mode, v)
                    if key:
                        kind = "S" if mnem == "JSR" else "L" if mnem == "JMP" and mode == "abs" else "D"
                        self.want(key[0], key[1], kind)
        # Code reached only through tables / indirect jumps / roots
        for k, tg in self.d.meta["indirect"].items():
            for tb, t in tg:
                self.want(tb, t, "L")
        b7 = self.d.banks[FIXED]
        for v in (0xFFFA, 0xFFFC, 0xFFFE):
            self.want(FIXED, b7.byte(v) | b7.byte(v + 1) << 8, "S")
        for key in self.names:
            if key[0] != "ram":
                self.want(key[0], key[1], "D")
        for off, (part, (tb, v), adj) in self.roles.items():
            if tb == "ram":
                continue
            b = self.d.banks[tb]
            if b.inside(v):
                self.want(tb, v, "L" if b.kind[v - b.base] == OP else "D")
        self.unresolved = []

    def operand(self, b, pc, insn):
        op, mnem, mode, size, v = insn
        if mode in ("imp", "acc"):
            return None, None
        if mode == "imm":
            role = self.roles.get(b.n * 0x4000 + pc + 1 - b.base)
            return (self.ptr_expr(role) if role else h2(v)), None
        if mode == "rel":
            return self.expr_of((b.n, v)), None
        if size == 2:
            return self.ram(v, 1), None
        # 16-bit operand
        force = v < 0x100 and mode in ZP_MODE and (mnem, ZP_MODE[mode]) in {(m, md) for m, md in OPS.values()}
        if v < 0x8000:
            text = self.ram(v, 2)
        elif mnem in WRITES:
            text = MMC1.get(v, h4(v))
        else:
            key = self.rom_target(b.n, pc, mnem, mode, v)
            text = self.expr_of(key) if key and key in self.kinds or (key and self.d.banks[key[0]].kind[key[1] - self.d.banks[key[0]].base] == OPND) else (self.expr_of(key) if key else h4(v))
        return text, force

    def fmt_insn(self, b, pc, insn):
        op, mnem, mode, size, v = insn
        text, force = self.operand(b, pc, insn)
        if force:
            mac = "ABS%s_%s" % ({"abs": "", "abx": "X", "aby": "Y"}[mode], mnem)
            self.force_macros.add((mac, op))
            return "%s %s" % (mac, text)
        if text is None:
            return mnem + (" A" if mode == "acc" else "")
        return {"imm": "%s #%s", "zp": "%s %s", "zpx": "%s %s,X", "zpy": "%s %s,Y",
                "izx": "%s (%s,X)", "izy": "%s (%s),Y", "abs": "%s %s", "abx": "%s %s,X",
                "aby": "%s %s,Y", "ind": "%s (%s)", "rel": "%s %s"}[mode] % (mnem, text)

    # -------------------------------------------------------------- emit
    def fill_regions(self, b):
        """FF runs that pad up to an anchor (bank end stub, page-aligned data)."""
        regions = {}
        end = STUB if b.n != FIXED else 0xFFE0
        free = lambda k: b.mem[k] == 0xFF and b.kind[k] == UNKNOWN and not self.d.cdl[b.n * 0x4000 + k] & 4
        i = end - b.base
        while i > 0 and free(i - 1):
            i -= 1
        if end - b.base - i >= 1:
            regions[b.base + i] = end
        # Page-aligned anchors inside the bank
        i = 0
        while i < end - b.base:
            if free(i):
                j = i
                while j < 0x4000 and free(j):
                    j += 1
                if j - i >= 64 and (b.base + j) % 0x100 == 0 and b.base + i not in regions and b.base + j < end:
                    regions[b.base + i] = b.base + j
                i = j
            else:
                i += 1
        return regions

    def items(self, b):
        """Bank contents as a list of Item, covering the whole bank."""
        out = []
        fills = self.fill_regions(b)
        order = sorted(fills)
        sizes = [fills[k] - k for k in order]
        shift_first = bool(order) and sizes[0] >= MAXSHIFT
        shift_after = {k: i + 1 < len(order) and sizes[i + 1] >= MAXSHIFT for i, k in enumerate(order)}
        out.append(Item(b.base, 0, "pad", "PAD SHIFT                               ; relocation test, see make.sh"
                        if shift_first else "; (no free space to absorb SHIFT padding in this segment)"))
        end = STUB if b.n != FIXED else 0xFFE0
        pc = b.base
        while pc < end:
            key = (b.n, pc)
            off = pc - b.base
            if pc in fills:
                t = fills[pc]
                if t in (STUB, 0xFFE0):
                    text = "FILLTO %s" % h4(t)
                elif t == DPCM:
                    text = "FILLTO %s                            ; DPCM samples must stay put" % h4(t)
                elif shift_after[pc]:
                    text = "FILLTO %s + SHIFT" % h4(t)
                else:
                    text = "FILLTO %s" % h4(t)
                it = Item(pc, t - pc, "fill", text)
            elif b.kind[off] == OP:
                insn = b.insn[pc]
                if pc in b.far:
                    fb, ft = b.far[pc]
                    tkey = (fb if ft < 0xC000 else FIXED, ft)
                    it = Item(pc, 6, "insn", "FARCALL %d, %s" % (fb, self.expr_of(tkey)))
                else:
                    self.cur_rams = []
                    it = Item(pc, insn[3], "insn", self.fmt_insn(b, pc, insn))
                    it.rams = self.cur_rams
            else:
                boff = b.n * 0x4000 + off
                role = self.roles.get(boff)
                nxt = self.roles.get(boff + 1)
                if role and role[0] == "lo" and nxt and nxt[0] == "hi" and nxt[1:] == role[1:] \
                        and (b.n, pc + 1) not in self.kinds and off + 1 < 0x4000:
                    e = self.expr_of(role[1])
                    it = Item(pc, 2, "ptr", "EQUW %s" % (e + "-%d" % role[2] if role[2] else e))
                elif role:
                    it = Item(pc, 1, "ptr", "EQUB %s" % self.ptr_expr(role))
                else:
                    it = Item(pc, 1, "byte", b.mem[off])
            self.decorate(it, key)
            out.append(it)
            pc += it.size
        if b.n != FIXED:
            out.append(Item(STUB, 0, "raw", "ASSERT P% <= &BFBC"))
            out.append(Item(STUB, 0x44, "raw", "RESET_STUB"))
            self.check_stub(b)
        else:
            for a in range(0xFFE0, 0xFFFA):
                it = Item(a, 1, "byte", b.byte(a))
                self.decorate(it, (b.n, a))
                out.append(it)
            for a in (0xFFFA, 0xFFFC, 0xFFFE):
                v = b.byte(a) | b.byte(a + 1) << 8
                it = Item(a, 2, "ptr", "EQUW %s" % self.expr_of((FIXED, v)))
                self.decorate(it, (b.n, a))
                out.append(it)
        return out

    def decorate(self, it, key):
        """Attach labels and comments for key to an item."""
        if it.kind == "insn" and key in self.d.spec and not self.prev_spec:
            it.block.append("(not seen executing during the coverage runs)")
        self.prev_spec = it.kind == "insn" and key in self.d.spec
        if key in self.kinds:
            it.labels.append(self.name_of(key))
            it.sub = self.kinds[key] == "S"
        for kind, text in self.comments.get(self.ckey(key), []):
            text = self.subst(text)
            if kind == ">":
                it.block.append(text)
            else:
                it.eol = text

    PH_LABEL = re.compile(r"\bJ?([SLD])(\d)_([0-9A-F]{4})\b")
    PH_RAM = re.compile(r"\b([ZWX])_([0-9A-F]{2,4})\b")

    def subst(self, text):
        """Comments may refer to placeholders (S5_8123, Z_4B); show current names."""
        def lab(m):
            if m.group(0).startswith("J"):
                return m.group(0)
            name = self.names.get((int(m.group(2)), int(m.group(3), 16)))
            return name or m.group(0)

        def ram(m):
            return self.names.get(("ram", int(m.group(2), 16))) or m.group(0)
        return self.PH_RAM.sub(ram, self.PH_LABEL.sub(lab, text))

    def own_key(self, k):
        """db key -> key in this region's address space (None: not ours).
        Unprefixed ROM keys are US addresses; the merger maps them for JP."""
        parts = k.split(":")
        if parts[0] == "ram":
            return ("ram", int(parts[1], 16))
        if len(parts) == 3:
            return (int(parts[1]), int(parts[2], 16)) if parts[0] == self.region else None
        return (int(parts[0]), int(parts[1], 16)) if self.region == "us" else None

    def ckey(self, key):
        """Key into the comments database for a ROM address of this region."""
        return key

    def emit_bank(self, b):
        head = ["; " + "-" * 75,
                "; PRG bank %d ($%04X-$%04X)" % (b.n, b.base, b.base + 0x3FFF),
                "; " + "-" * 75, ""]
        return "\n".join(head + render(self.items(b))) + "\n"

    STUB_BYTES = None

    def check_stub(self, b):
        stub = bytes(b.mem[STUB - b.base:])
        if Emitter.STUB_BYTES is None:
            Emitter.STUB_BYTES = stub
        assert stub == Emitter.STUB_BYTES, "bank %d stub differs" % b.n

    def emit_macros(self):
        out = ["; Generated by tools/emit.py", ""]
        out += [
            "; Call a routine in another PRG bank: JSR FAR_CALL is followed by the",
            "; bank number and the target address - 1 (it returns there with RTS).",
            "MACRO FARCALL bank, addr",
            "  JSR %s" % self.name_of((FIXED, self.d.FAR_CALL)),
            "  EQUB bank",
            "  EQUW addr-1",
            "ENDMACRO",
            "",
            "; Insert n bytes of &FF (n may be 0)",
            "MACRO PAD n",
            "  IF n > 0",
            "    FOR i, 1, n",
            "      EQUB &FF",
            "    NEXT",
            "  ENDIF",
            "ENDMACRO",
            "",
            "; Pad with &FF up to addr",
            "MACRO FILLTO addr",
            "  ASSERT P% <= addr",
            "  FOR n, P%, addr-1",
            "    EQUB &FF",
            "  NEXT",
            "ENDMACRO",
            "",
            "; Absolute addressing of a zero page address (BeebAsm would pick zero page)",
        ]
        for mac, op in sorted(self.force_macros):
            out += ["MACRO %s addr" % mac, "  EQUB &%02X" % op, "  EQUW addr", "ENDMACRO", ""]
        # Reset stub shared by banks 0-6, at $BFBC (run at $FFBC if mapped high on power-up)
        stub = Emitter.STUB_BYTES
        out += ["; Power-on stub at the end of every switchable bank. MMC1 may map any bank",
                "; at $C000 on power-up, so each bank resets the mapper and jumps to RESET.",
                "MACRO RESET_STUB"]
        for i in range(0, len(stub) - 6, 16):
            out.append("  EQUB " + ",".join(h2(x) for x in stub[i:min(i + 16, len(stub) - 6)]))
        out.append("  EQUW &%04X, &%04X, &%04X" % tuple(stub[-6 + i] | stub[-5 + i] << 8 for i in (0, 2, 4)))
        out.append("ENDMACRO")
        return "\n".join(out) + "\n"

    def emit_vars(self, other=None):
        """RAM symbols. other: the JP Emitter when generating the merged source."""
        def lines(used):
            out = []
            for name, v in sorted(used.items(), key=lambda x: (x[1], x[0])):
                key = ("ram", v)
                line = "%-24s= %s" % (name, h4(v) if v > 0xFF else h2(v))
                # comments belong to the name (db keys are US addresses)
                c = None
                for k, nm in self.names.items():
                    if nm == name and k[0] == "ram":
                        c = self.symcomment.get(k)
                        break
                out.append(line + (" ; " + c if c else ""))
            return out
        out = ["; RAM, WRAM and register names", "; Generated from db/symbols.tsv (ram:XXXX keys, US addresses).",
               "; Z_xx / W_xxxx / X_xxxx are unnamed zero page / RAM / WRAM ($6000) locations.", ""]
        if other is None:
            out += lines(self.ram_used)
        else:
            shared = {k: v for k, v in self.ram_used.items() if other.ram_used.get(k) == v}
            us_only = {k: v for k, v in self.ram_used.items() if k not in shared}
            jp_only = {k: v for k, v in other.ram_used.items() if k not in shared}
            out += lines(shared)
            out += ["", "; Variables at different addresses in the Japanese version", "IF REGION_JP"]
            out += ["  " + l for l in lines(jp_only)]
            out += ["ELSE"]
            out += ["  " + l for l in lines(us_only)]
            out += ["ENDIF"]
        out.append("")
        out.append("MMC1_CONTROL            = &9FFF")
        out.append("MMC1_CHR0               = &BFFF")
        out.append("MMC1_CHR1               = &DFFF")
        out.append("MMC1_PRG                = &FFFF")
        return "\n".join(out) + "\n"

    def emit_vars_multi(self, others):
        """RAM symbols for US (self) plus JP and EU emitters in `others`."""
        def lines(used):
            out = []
            for name, v in sorted(used.items(), key=lambda x: (x[1], x[0])):
                line = "%-24s= %s" % (name, h4(v) if v > 0xFF else h2(v))
                c = None
                for k, nm in self.names.items():
                    if nm == name and k[0] == "ram":
                        c = self.symcomment.get(k)
                        break
                out.append(line + (" ; " + c if c else ""))
            return out
        regions = ["us", "jp", "eu"]
        have = {"us": self.ram_used, "jp": others["jp"].ram_used, "eu": others["eu"].ram_used}
        names = set()
        for used in have.values():
            names |= set(used)
        shared = {}
        groups = {}
        for name in names:
            vals = tuple(have[r].get(name) for r in regions)
            if vals[0] is not None and vals[0] == vals[1] == vals[2]:
                shared[name] = vals[0]
            else:
                groups.setdefault(vals, []).append(name)
        out = ["; RAM, WRAM and register names", "; Generated from db/symbols.tsv (ram:XXXX keys, US addresses).",
               "; Z_xx / W_xxxx / X_xxxx are unnamed zero page / RAM / WRAM ($6000) locations.", ""]
        out += lines(shared)
        cond = {"eu": "REGION = 2", "jp": "REGION_JP", "us": "REGION = 0"}
        for vals, group in sorted(groups.items(), key=lambda kv: tuple(-1 if v is None else v for v in kv[0])):
            out.append("")
            first = True
            for region, value in zip(regions, vals):
                if value is None:
                    continue
                used = {name: value for name in group}
                kw = "IF" if first else "ELIF"
                out.append("%s %s" % (kw, cond[region]))
                out += ["  " + l for l in lines(used)]
                first = False
            out.append("ENDIF")
        out.append("")
        out.append("MMC1_CONTROL            = &9FFF")
        out.append("MMC1_CHR0               = &BFFF")
        out.append("MMC1_CHR1               = &DFFF")
        out.append("MMC1_PRG                = &FFFF")
        return "\n".join(out) + "\n"

    def run(self, outdir):
        self.collect()
        self.ram_used = {}
        banks = {b.n: self.emit_bank(b) for b in self.d.banks}
        for n, text in banks.items():
            open(os.path.join(outdir, "bank%d.asm" % n), "w").write(text)
        open(os.path.join(outdir, "macros.asm"), "w").write(self.emit_macros())
        open(os.path.join(outdir, "vars.asm"), "w").write(self.emit_vars())
        return self.unresolved


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("region")
    ap.add_argument("--out", default=ROOT)
    args = ap.parse_args()
    e = Emitter(args.region)
    unresolved = e.run(args.out)
    print("labels %d, pointer bytes %d, unresolved ROM operands %d, conflicts %d" % (
        len(e.kinds), len(e.roles), len(set(unresolved)), len(e.conflicts)))
    for c in e.conflicts[:30]:
        print("  " + c)
    for u in sorted(set(unresolved))[:30]:
        print("  " + u)


if __name__ == "__main__":
    main()
