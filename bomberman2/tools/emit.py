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
    __slots__ = ("addr", "size", "kind", "text", "labels", "block", "eol", "sub")

    def __init__(self, addr, size, kind, text):
        self.addr, self.size, self.kind, self.text = addr, size, kind, text
        self.labels, self.block, self.eol, self.sub = [], [], None, False

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
        if it.labels and it.sub:
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
    path = os.path.join(DB, name)
    rows = []
    if not os.path.exists(path):
        return rows
    for ln, line in enumerate(open(path, encoding="utf-8"), 1):
        line = line.rstrip("\n")
        if not line.strip() or line.startswith("#"):
            continue
        rows.append((ln, line.split("\t")))
    return rows


def parse_key(k):
    a, b = k.split(":")
    return (a if a == "ram" else int(a), int(b, 16))


class Emitter:
    def __init__(self, region):
        self.d = Disasm(region)
        self.d.trace()
        self.region = region
        self.names = {}            # (bank|'ram', addr) -> name
        self.symcomment = {}
        self.comments = defaultdict(list)   # (bank, addr) -> [(kind, text)]
        for ln, row in load_tsv("symbols.tsv"):
            key = parse_key(row[0])
            self.names[key] = row[1]
            if len(row) > 2 and row[2]:
                self.symcomment[key] = row[2]
        for ln, row in load_tsv("comments.tsv"):
            self.comments[parse_key(row[0])].append((row[1], row[2].replace("\\n", "\n")))
        self.labels = {}           # (bank, addr) -> name (ROM labels to define)
        self.kinds = {}            # (bank, addr) -> 'S' | 'L' | 'D'
        self.inner = {}            # (bank, addr) -> (bank, insn addr, offset) labels inside an insn
        self.force_macros = set()
        self.unresolved = []
        self.conflicts = []
        self.roles = self.pointer_roles()

    def pointer_roles(self):
        """PRG offset -> ('lo'|'hi', (bank, target), adjust) from runtime pointer uses."""
        roles = {}
        for (lo, hi, kind), vals in self.d.meta["ptrs"].items():
            if len(vals) != 1:
                self.conflicts.append("pointer %d:%d used with several banks/targets %s" % (lo, hi, sorted(vals)))
                continue
            tb, v = next(iter(vals))
            adj = 0
            if kind == "rts":
                v, adj = v - 1, 1                 # stored as target - 1
            tb = FIXED if v >= 0xC000 else tb
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
        return roles

    def ptr_expr(self, role):
        part, (tb, v), adj = role
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

    def name_of(self, key):
        if key in self.names:
            return self.names[key]
        bank, addr = key
        return "%s%d_%04X" % (self.kinds.get(key, "D"), bank, addr)

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

    def ram(self, v, width):
        key = ("ram", v)
        if key in self.names:
            return self.names[key]
        if 0x2000 <= v < 0x4020 and v in REGS:
            return REGS[v]
        return h2(v) if width == 1 else h4(v)

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
                    it = Item(pc, insn[3], "insn", self.fmt_insn(b, pc, insn))
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
        if key in self.kinds:
            it.labels.append(self.name_of(key))
            it.sub = self.kinds[key] == "S"
        for kind, text in self.comments.get(self.ckey(key), []):
            if kind == ">":
                it.block.append(text)
            else:
                it.eol = text

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

    def emit_vars(self):
        out = ["; RAM, WRAM and register names (generated from db/symbols.tsv)", ""]
        for key in sorted(k for k in self.names if k[0] == "ram"):
            name = self.names[key]
            c = self.symcomment.get(key)
            line = "%-24s= %s" % (name, h4(key[1]) if key[1] > 0xFF else h2(key[1]))
            out.append(line + (" ; " + c if c else ""))
        out.append("")
        out.append("MMC1_CONTROL            = &9FFF")
        out.append("MMC1_CHR0               = &BFFF")
        out.append("MMC1_CHR1               = &DFFF")
        out.append("MMC1_PRG                = &FFFF")
        return "\n".join(out) + "\n"

    def run(self, outdir):
        self.collect()
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
