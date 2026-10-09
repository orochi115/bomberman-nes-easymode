"""Minimal headless NES emulator (6502 + MMC1 + approximate PPU timing).

It is not cycle-exact. It exists for two jobs:
  * coverage: which PRG bytes run as code, which are read as data,
    and where indexed tables start (a CDL-like log);
  * behaviour checks: record the PPU/OAM write stream of a ROM under a fixed
    input script, so that a rebuilt or relocated ROM can be compared with the
    original.
"""

import sys

from m6502 import OPS, SIZE

CYC_FRAME = 29781
CYC_LINE = 113.667
VBL_START = int(241 * CYC_LINE)
VBL_END = int(261 * CYC_LINE)

# Buttons (standard pad bit order as read from $4016)
A, B, SELECT, START, UP, DOWN, LEFT, RIGHT = (1 << i for i in range(8))


class NES:
    def __init__(self, rom_bytes, track=True, log_ppu=False):
        hdr = rom_bytes[:16]
        # NES 2.0 byte 12 bit 0 = PAL. Expansion byte 15: 02 US/EU, 03 JP.
        nes2 = (hdr[7] & 0x0C) == 0x08
        pal = (hdr[12] if nes2 else hdr[9]) & 1
        self.region = "eu" if pal else ("jp" if hdr[15] == 3 else "us")
        nprg = hdr[4]
        self.prg = bytearray(rom_bytes[16:16 + nprg * 0x4000])
        self.nbanks = nprg
        self.ram = bytearray(0x800)
        self.wram = bytearray(0x2000)
        # MMC1
        self.sr = 0x10
        self.ctrl = 0x0C
        self.prgbank = 0
        self.chr0 = self.chr1 = 0
        self._map()
        # PPU state
        self.ppuctrl = 0
        self.ppumask = 0
        self.vblank = False
        self.spr0 = False
        self.nmi_pending = False
        self.oam = bytearray(256)
        self.ppu_latch = False
        self.vram = bytearray(0x800)
        self.chr = bytearray(0x2000)
        self.pal = bytearray(32)
        self.vaddr = 0
        self.scroll = [0, 0]
        self.rbuf = 0
        # Controllers
        self.pad = [0, 0]
        self.shift = [0, 0]
        self.strobe = 0
        # CPU
        self.a = self.x = self.y = 0
        self.sp = 0xFD
        self.p = 0x24
        self.cyc = 0
        self.frame = 0
        # Tracking
        self.track = track
        self.code = bytearray(len(self.prg))   # 1 = opcode, 2 = operand
        self.data = bytearray(len(self.prg))   # 1 = read as data
        self.tables = {}                         # (bank, base) -> set of index values
        self.indirect = {}                       # (bank, pc) -> set of targets of JMP ()
        self.calls = set()                       # (bank, pc, target bank, target)
        self.illegal = None
        self.log_ppu = log_ppu
        self.ppulog = []
        self.pc = self.rd16(0xFFFC)

    # ------------------------------------------------------------------ memory
    def _map(self):
        mode = (self.ctrl >> 2) & 3
        b = self.prgbank & 0x0F
        last = self.nbanks - 1
        if mode <= 1:
            lo, hi = b & ~1, (b & ~1) | 1
        elif mode == 2:
            lo, hi = 0, b
        else:
            lo, hi = b, last
        self.lo, self.hi = lo % self.nbanks, hi % self.nbanks

    def prg_off(self, addr):
        if addr >= 0xC000:
            return self.hi * 0x4000 + addr - 0xC000
        return self.lo * 0x4000 + addr - 0x8000

    def bank_of(self, addr):
        return self.hi if addr >= 0xC000 else self.lo

    watch = None   # optional callback(kind, addr, value, pc); kind 'r' or 'w'

    def rd(self, addr):
        if addr < 0x2000:
            if self.watch:
                self.watch("r", addr & 0x7FF, self.ram[addr & 0x7FF], self.cur_pc)
            return self.ram[addr & 0x7FF]
        if addr >= 0x8000:
            off = self.prg_off(addr)
            if self.track:
                self.data[off] = 1
            return self.prg[off]
        if addr >= 0x6000:
            if self.watch:
                self.watch("r", addr, self.wram[addr - 0x6000], self.cur_pc)
            return self.wram[addr - 0x6000]
        if addr < 0x4000:
            r = addr & 7
            if r == 2:
                v = (0x80 if self.vblank else 0) | (0x40 if self.spr0 else 0)
                self.vblank = False
                self.ppu_latch = False
                return v
            if r == 7:
                a = self.vaddr
                v = self.rbuf
                self.rbuf = self.vread(a)
                if a >= 0x3F00:
                    v = self.rbuf
                self.vaddr = (a + (32 if self.ppuctrl & 4 else 1)) & 0x3FFF
                return v
            return 0
        if addr == 0x4016 or addr == 0x4017:
            i = addr - 0x4016
            if self.strobe:
                return 0x40 | (self.pad[i] & 1)
            v = self.shift[i] & 1
            self.shift[i] = (self.shift[i] >> 1) | 0x80
            return 0x40 | v
        return 0

    force = None   # optional {addr: fn(value) -> value} applied to CPU writes

    def wr(self, addr, v):
        if self.force and addr in self.force:
            v = self.force[addr](v)
        if self.watch:
            self.watch("w", addr, v, self.cur_pc)
        if addr < 0x2000:
            self.ram[addr & 0x7FF] = v
        elif addr >= 0x8000:
            self.mmc1(addr, v)
        elif addr >= 0x6000:
            self.wram[addr - 0x6000] = v
        elif addr < 0x4000:
            r = addr & 7
            if r == 0:
                if v & 0x80 and not self.ppuctrl & 0x80 and self.vblank:
                    self.nmi_delayed = 2
                self.ppuctrl = v
            elif r == 1:
                self.ppumask = v
            elif r == 5:
                self.scroll[1 if self.ppu_latch else 0] = v
                self.ppu_latch = not self.ppu_latch
            elif r == 6:
                if self.ppu_latch:
                    self.vaddr = (self.vaddr & 0xFF00) | v
                else:
                    self.vaddr = (self.vaddr & 0xFF) | (v & 0x3F) << 8
                self.ppu_latch = not self.ppu_latch
            elif r == 7:
                self.vwrite(self.vaddr, v)
                self.vaddr = (self.vaddr + (32 if self.ppuctrl & 4 else 1)) & 0x3FFF
            if self.log_ppu:
                self.log(0x2000 | r, v)
        elif addr == 0x4014:
            base = v << 8
            for i in range(256):
                self.oam[i] = self.rd(base + i)
            self.cyc += 513
            if self.log_ppu:
                self.log(0x4014, bytes(self.oam))
        elif addr == 0x4016:
            self.strobe = v & 1
            if self.strobe:
                self.shift = [self.pad[0], self.pad[1]]
        elif self.log_ppu and addr < 0x4014:
            self.log(addr, v)

    def ntoff(self, a):
        a &= 0xFFF
        m = self.ctrl & 3
        if m == 0:
            return a & 0x3FF
        if m == 1:
            return 0x400 | (a & 0x3FF)
        if m == 2:
            return a & 0x7FF
        return ((a >> 1) & 0x400) | (a & 0x3FF)

    def vwrite(self, a, v):
        if a < 0x2000:
            self.chr[a] = v
        elif a < 0x3F00:
            self.vram[self.ntoff(a)] = v
        else:
            i = a & 0x1F
            if i & 0x13 == 0x10:
                i &= 0x0F
            self.pal[i] = v

    def vread(self, a):
        if a < 0x2000:
            return self.chr[a]
        if a < 0x3F00:
            return self.vram[self.ntoff(a)]
        i = a & 0x1F
        if i & 0x13 == 0x10:
            i &= 0x0F
        return self.pal[i]

    def screenshot(self, path):
        from ppu_render import render
        render(self).save(path)

    def log(self, reg, v):
        self.ppulog.append((self.frame, reg, v))
        if self.taint:
            self.ppusrc.append((self.cur_pc, self.store_src))

    def mmc1(self, addr, v):
        if v & 0x80:
            self.sr = 0x10
            self.ctrl |= 0x0C
            self._map()
            return
        done = self.sr & 1
        self.sr = (self.sr >> 1) | ((v & 1) << 4)
        if done:
            reg = (addr >> 13) & 3
            val = self.sr
            if reg == 0:
                self.ctrl = val
            elif reg == 1:
                self.chr0 = val
            elif reg == 2:
                self.chr1 = val
            else:
                self.prgbank = val
            self.sr = 0x10
            self._map()

    def rd16(self, addr):
        return self.rd(addr) | self.rd((addr + 1) & 0xFFFF) << 8

    # --------------------------------------------------------------------- CPU
    def push(self, v):
        self.ram[0x100 + self.sp] = v
        self.sp = (self.sp - 1) & 0xFF

    def pull(self):
        self.sp = (self.sp + 1) & 0xFF
        return self.ram[0x100 + self.sp]

    def nmi(self):
        if self.taint:
            for i in range(3):
                self.ram_t[0x100 + ((self.sp - i) & 0xFF)] = None
        self.push(self.pc >> 8)
        self.push(self.pc & 0xFF)
        self.push((self.p | 0x20) & ~0x10)
        self.p |= 0x04
        self.pc = self.rd16(0xFFFA)
        self.cyc += 7

    def run_frame(self):
        """Run until the next frame boundary."""
        end_vbl = False
        while True:
            c = self.cyc
            if c >= CYC_FRAME:
                self.cyc -= CYC_FRAME
                self.frame += 1
                self.vbl_done = False
                return
            if not self.vblank_set_this_frame and c >= VBL_START:
                self.vblank_set_this_frame = True
                self.vblank = True
                if self.ppuctrl & 0x80:
                    self.nmi_pending = True
            if self.vblank_set_this_frame and c >= VBL_END and not end_vbl:
                end_vbl = True
                self.vblank = False
                self.spr0 = False
                self.vblank_set_this_frame = False
            if not self.spr0 and not self.vblank and self.ppumask & 0x18 and c < VBL_START:
                if c >= (self.oam[0] + 2) * CYC_LINE:
                    self.spr0 = True
            if self.nmi_pending:
                self.nmi_pending = False
                self.nmi()
            if not self.step():
                return False
            if self.nmi_delayed:
                # Enabling NMI during vblank fires after the next instruction
                self.nmi_delayed -= 1
                if not self.nmi_delayed:
                    self.nmi_pending = True

    vblank_set_this_frame = False
    nmi_delayed = 0

    def setnz(self, v):
        self.p = (self.p & 0x7D) | (v & 0x80) | (0 if v else 2)

    cur_pc = 0

    def step(self):
        pc = self.cur_pc = self.pc
        if pc < 0x8000:
            self.illegal = ("pc", pc)
            return False
        off = self.prg_off(pc)
        op = self.prg[off]
        if op not in OPS:
            self.illegal = ("op", self.bank_of(pc), pc, op)
            return False
        mnem, mode = OPS[op]
        n = SIZE[mode]
        if self.track:
            self.code[off] = 1
            for i in range(1, n):
                o2 = self.prg_off((pc + i) & 0xFFFF)
                if self.code[o2] != 1:
                    self.code[o2] = 2
        prg = self.prg
        if n >= 2:
            b1 = prg[self.prg_off(pc + 1)]
        if n == 3:
            w = b1 | prg[self.prg_off(pc + 2)] << 8
        self.pc = (pc + n) & 0xFFFF
        self.cyc += 2 + (n - 1)

        # Effective address
        ea = None
        if mode == "imm":
            val = b1
        elif mode == "zp":
            ea = b1
        elif mode == "zpx":
            ea = (b1 + self.x) & 0xFF
        elif mode == "zpy":
            ea = (b1 + self.y) & 0xFF
        elif mode == "abs":
            ea = w
        elif mode == "abx":
            ea = (w + self.x) & 0xFFFF
            if self.track and w >= 0x8000 and mnem not in ("STA",):
                self._table(pc, w, self.x)
        elif mode == "aby":
            ea = (w + self.y) & 0xFFFF
            if self.track and w >= 0x8000 and mnem not in ("STA",):
                self._table(pc, w, self.y)
        elif mode == "izx":
            z = (b1 + self.x) & 0xFF
            ea = self.ram[z] | self.ram[(z + 1) & 0xFF] << 8
        elif mode == "izy":
            base = self.ram[b1] | self.ram[(b1 + 1) & 0xFF] << 8
            ea = (base + self.y) & 0xFFFF
        elif mode == "rel":
            val = b1

        if self.taint:
            self._taint(pc, mnem, mode, ea, b1 if n >= 2 else None, w if n == 3 else None)

        # Execute
        if mnem == "LDA":
            self.a = val if mode == "imm" else self.rd(ea)
            self.setnz(self.a)
        elif mnem == "LDX":
            self.x = val if mode == "imm" else self.rd(ea)
            self.setnz(self.x)
        elif mnem == "LDY":
            self.y = val if mode == "imm" else self.rd(ea)
            self.setnz(self.y)
        elif mnem == "STA":
            self.wr(ea, self.a)
        elif mnem == "STX":
            self.wr(ea, self.x)
        elif mnem == "STY":
            self.wr(ea, self.y)
        elif mode == "rel":
            p = self.p
            take = {"BPL": not p & 0x80, "BMI": p & 0x80, "BVC": not p & 0x40, "BVS": p & 0x40,
                    "BCC": not p & 1, "BCS": p & 1, "BNE": not p & 2, "BEQ": p & 2}[mnem]
            if take:
                self.pc = (self.pc + ((val ^ 0x80) - 0x80)) & 0xFFFF
                self.cyc += 1
        elif mnem == "JSR":
            ret = (pc + 2) & 0xFFFF
            self.push(ret >> 8)
            self.push(ret & 0xFF)
            if self.track:
                self.calls.add((self.bank_of(pc), pc, self.bank_of(w), w))
            self.pc = w
            self.cyc += 3
        elif mnem == "RTS":
            lo = self.pull()
            self.pc = ((self.pull() << 8 | lo) + 1) & 0xFFFF
            self.cyc += 4
        elif mnem == "JMP":
            if mode == "abs":
                if self.track and pc >= 0xC000 and w < 0xC000:
                    self.calls.add((self.bank_of(pc), pc, self.bank_of(w), w))
                self.pc = w
            else:
                lo = self.rd(w)
                hi = self.rd((w & 0xFF00) | ((w + 1) & 0xFF))
                self.pc = hi << 8 | lo
                if self.track:
                    self.indirect.setdefault((self.bank_of(pc), pc), set()).add((self.bank_of(self.pc), self.pc))
                self.cyc += 2
        elif mnem in ("ADC", "SBC", "AND", "ORA", "EOR", "CMP", "CPX", "CPY", "BIT"):
            m = val if mode == "imm" else self.rd(ea)
            if mnem == "ADC" or mnem == "SBC":
                if mnem == "SBC":
                    m ^= 0xFF
                r = self.a + m + (self.p & 1)
                ov = (~(self.a ^ m) & (self.a ^ r) & 0x80)
                self.p = (self.p & 0x3E) | (1 if r > 0xFF else 0) | (0x40 if ov else 0)
                self.a = r & 0xFF
                self.setnz(self.a)
            elif mnem == "AND":
                self.a &= m
                self.setnz(self.a)
            elif mnem == "ORA":
                self.a |= m
                self.setnz(self.a)
            elif mnem == "EOR":
                self.a ^= m
                self.setnz(self.a)
            elif mnem == "BIT":
                self.p = (self.p & 0x3D) | (m & 0xC0) | (0 if self.a & m else 2)
            else:
                reg = self.a if mnem == "CMP" else (self.x if mnem == "CPX" else self.y)
                r = (reg - m) & 0x1FF
                self.p = (self.p & 0xFE) | (1 if reg >= m else 0)
                self.setnz(r & 0xFF)
        elif mnem in ("ASL", "LSR", "ROL", "ROR", "INC", "DEC"):
            m = self.a if mode == "acc" else self.rd(ea)
            c = self.p & 1
            if mnem == "ASL":
                c, m = m >> 7, (m << 1) & 0xFF
            elif mnem == "LSR":
                c, m = m & 1, m >> 1
            elif mnem == "ROL":
                c, m = m >> 7, ((m << 1) | c) & 0xFF
            elif mnem == "ROR":
                c, m = m & 1, (m >> 1) | (c << 7)
            elif mnem == "INC":
                m = (m + 1) & 0xFF
            else:
                m = (m - 1) & 0xFF
            if mnem not in ("INC", "DEC"):
                self.p = (self.p & 0xFE) | c
            self.setnz(m)
            if mode == "acc":
                self.a = m
            else:
                self.wr(ea, m)
                self.cyc += 2
        elif mnem == "INX":
            self.x = (self.x + 1) & 0xFF
            self.setnz(self.x)
        elif mnem == "INY":
            self.y = (self.y + 1) & 0xFF
            self.setnz(self.y)
        elif mnem == "DEX":
            self.x = (self.x - 1) & 0xFF
            self.setnz(self.x)
        elif mnem == "DEY":
            self.y = (self.y - 1) & 0xFF
            self.setnz(self.y)
        elif mnem == "TAX":
            self.x = self.a
            self.setnz(self.x)
        elif mnem == "TAY":
            self.y = self.a
            self.setnz(self.y)
        elif mnem == "TXA":
            self.a = self.x
            self.setnz(self.a)
        elif mnem == "TYA":
            self.a = self.y
            self.setnz(self.a)
        elif mnem == "TSX":
            self.x = self.sp
            self.setnz(self.x)
        elif mnem == "TXS":
            self.sp = self.x
        elif mnem == "PHA":
            self.push(self.a)
        elif mnem == "PHP":
            self.push(self.p | 0x30)
        elif mnem == "PLA":
            self.a = self.pull()
            self.setnz(self.a)
        elif mnem == "PLP":
            self.p = (self.pull() & 0xCF) | 0x20
        elif mnem == "RTI":
            self.p = (self.pull() & 0xCF) | 0x20
            lo = self.pull()
            self.pc = self.pull() << 8 | lo
        elif mnem == "CLC":
            self.p &= ~1
        elif mnem == "SEC":
            self.p |= 1
        elif mnem == "CLI":
            self.p &= ~4
        elif mnem == "SEI":
            self.p |= 4
        elif mnem == "CLV":
            self.p &= ~0x40
        elif mnem == "CLD":
            self.p &= ~8
        elif mnem == "SED":
            self.p |= 8
        elif mnem == "NOP":
            pass
        elif mnem == "BRK":
            self.illegal = ("brk", self.bank_of(pc), pc)
            return False
        return True

    # ------------------------------------------------------------- taint
    # Every register / RAM byte remembers the PRG offset it was loaded from
    # (ROM data or an immediate operand). When two such bytes are used together
    # as a pointer into ROM, both PRG bytes are recorded in self.ptrs.
    taint = False
    store_src = None
    ppusrc = []

    def enable_taint(self):
        self.taint = True
        self.ta = self.tx = self.ty = None
        self.ram_t = [None] * 0x800
        self.wram_t = [None] * 0x2000
        self.imm_src = set() # PRG offsets of immediate operands seen
        self.ptrs = {}       # (lo off, hi off, kind) -> set of (bank, value)
        self.partial = {}    # (pc bank, pc) -> count of half-tainted ROM pointers

    def _src(self, ea):
        if ea >= 0x8000:
            return self.prg_off(ea)
        if ea < 0x2000:
            return self.ram_t[ea & 0x7FF]
        if 0x6000 <= ea < 0x8000:
            return self.wram_t[ea - 0x6000]
        return None

    def _set(self, ea, t):
        if ea < 0x2000:
            self.ram_t[ea & 0x7FF] = t
        elif 0x6000 <= ea < 0x8000:
            self.wram_t[ea - 0x6000] = t

    def _ptr(self, pc, lo_t, hi_t, value, kind):
        if value < 0x8000:
            return
        if lo_t is not None and hi_t is not None:
            # The address stored in ROM (the base, before any offset was added)
            value = (self.prg[lo_t] | self.prg[hi_t] << 8) + (1 if kind == "rts" else 0)
            value &= 0xFFFF
            if value < 0x8000:
                return
            k = (lo_t, hi_t, kind)
            s = self.ptrs.get(k)
            if s is None:
                s = self.ptrs[k] = set()
            # The bank that is mapped where the pointer points
            s.add((self.bank_of(value), value))
        elif lo_t is not None or hi_t is not None:
            k = (self.bank_of(pc), pc)
            self.partial[k] = self.partial.get(k, 0) + 1

    def _taint(self, pc, mnem, mode, ea, b1, w):
        sp = self.sp
        if mnem in ("LDA", "LDX", "LDY"):
            if mode == "imm":
                t = self.prg_off(pc + 1)
                self.imm_src.add(t)
            else:
                t = self._src(ea)
            if mnem == "LDA":
                self.ta = t
            elif mnem == "LDX":
                self.tx = t
            else:
                self.ty = t
        elif mnem in ("STA", "STX", "STY"):
            t = self.ta if mnem == "STA" else self.tx if mnem == "STX" else self.ty
            self.store_src = t
            self._set(ea, t)
        elif mnem == "TAX":
            self.tx = self.ta
        elif mnem == "TAY":
            self.ty = self.ta
        elif mnem == "TXA":
            self.ta = self.tx
        elif mnem == "TYA":
            self.ta = self.ty
        elif mnem == "TSX":
            self.tx = None
        elif mnem == "PHA":
            self.ram_t[0x100 + sp] = self.ta
        elif mnem == "PHP":
            self.ram_t[0x100 + sp] = None
        elif mnem == "PLA":
            self.ta = self.ram_t[0x100 + ((sp + 1) & 0xFF)]
        elif mnem == "JSR":
            self.ram_t[0x100 + sp] = None
            self.ram_t[0x100 + ((sp - 1) & 0xFF)] = None
        elif mnem == "RTS":
            a1, a2 = 0x100 + ((sp + 1) & 0xFF), 0x100 + ((sp + 2) & 0xFF)
            v = (self.ram[a1] | self.ram[a2] << 8) + 1
            self._ptr(pc, self.ram_t[a1], self.ram_t[a2], v & 0xFFFF, "rts")
        elif mnem == "JMP" and mode == "ind":
            a2 = (w & 0xFF00) | ((w + 1) & 0xFF)
            v = self.rd(w) | self.rd(a2) << 8
            self._ptr(pc, self._src(w), self._src(a2), v, "jmp")
        elif mnem in ("ADC", "SBC"):
            # base + offset keeps the base's origin if only one side has one
            # (an immediate is the base when A is an index: ADC #<table)
            other = self.prg_off(pc + 1) if mode == "imm" else self._src(ea)
            if mode == "imm":
                if self.ta in self.imm_src:
                    self.ta = None          # LDA #c : ADC #base -> base
                elif self.ta is not None:
                    other = None            # table value + constant offset
            if self.ta is None:
                self.ta = other
            elif other is not None:
                self.ta = None
        elif mnem in ("AND", "ORA", "EOR") or (mode == "acc"):
            self.ta = None
        elif mnem in ("INX", "DEX"):
            self.tx = None
        elif mnem in ("INY", "DEY"):
            self.ty = None
        elif mnem in ("ASL", "LSR", "ROL", "ROR"):
            self._set(ea, None)
        if mode == "izy":
            v = self.ram[b1] | self.ram[(b1 + 1) & 0xFF] << 8
            self._ptr(pc, self.ram_t[b1], self.ram_t[(b1 + 1) & 0xFF], v, "ind")
        elif mode == "izx":
            z = (b1 + self.x) & 0xFF
            v = self.ram[z] | self.ram[(z + 1) & 0xFF] << 8
            self._ptr(pc, self.ram_t[z], self.ram_t[(z + 1) & 0xFF], v, "ind")

    def _table(self, pc, base, idx):
        key = (self.bank_of(base), base)
        s = self.tables.get(key)
        if s is None:
            s = self.tables[key] = set()
        s.add(idx)


def run_script(nes, script, frames):
    """script: list of (frame, pad0) changes, applied when nes.frame reaches frame."""
    i = 0
    for _ in range(frames):
        while i < len(script) and script[i][0] <= nes.frame:
            nes.pad[0] = script[i][1]
            i += 1
        if nes.run_frame() is False:
            return False
    return True


if __name__ == "__main__":
    import time
    rom = open(sys.argv[1], "rb").read()
    nes = NES(rom)
    t = time.time()
    run_script(nes, [(0, 0), (200, START), (205, 0)], int(sys.argv[2]))
    dt = time.time() - t
    print("frames", nes.frame, "time %.1fs" % dt, "illegal", nes.illegal)
    print("code bytes", sum(1 for c in nes.code if c), "data bytes", sum(nes.data))
