"""6502 opcode table and ROM helpers shared by the Bomberman II tools."""

import os

# Addressing modes: imp, acc, imm, zp, zpx, zpy, izx, izy, abs, abx, aby, ind, rel
_OPS = """
00 BRK imp|01 ORA izx|05 ORA zp|06 ASL zp|08 PHP imp|09 ORA imm|0A ASL acc|0D ORA abs|0E ASL abs
10 BPL rel|11 ORA izy|15 ORA zpx|16 ASL zpx|18 CLC imp|19 ORA aby|1D ORA abx|1E ASL abx
20 JSR abs|21 AND izx|24 BIT zp|25 AND zp|26 ROL zp|28 PLP imp|29 AND imm|2A ROL acc|2C BIT abs|2D AND abs|2E ROL abs
30 BMI rel|31 AND izy|35 AND zpx|36 ROL zpx|38 SEC imp|39 AND aby|3D AND abx|3E ROL abx
40 RTI imp|41 EOR izx|45 EOR zp|46 LSR zp|48 PHA imp|49 EOR imm|4A LSR acc|4C JMP abs|4D EOR abs|4E LSR abs
50 BVC rel|51 EOR izy|55 EOR zpx|56 LSR zpx|58 CLI imp|59 EOR aby|5D EOR abx|5E LSR abx
60 RTS imp|61 ADC izx|65 ADC zp|66 ROR zp|68 PLA imp|69 ADC imm|6A ROR acc|6C JMP ind|6D ADC abs|6E ROR abs
70 BVS rel|71 ADC izy|75 ADC zpx|76 ROR zpx|78 SEI imp|79 ADC aby|7D ADC abx|7E ROR abx
81 STA izx|84 STY zp|85 STA zp|86 STX zp|88 DEY imp|8A TXA imp|8C STY abs|8D STA abs|8E STX abs
90 BCC rel|91 STA izy|94 STY zpx|95 STA zpx|96 STX zpy|98 TYA imp|99 STA aby|9A TXS imp|9D STA abx
A0 LDY imm|A1 LDA izx|A2 LDX imm|A4 LDY zp|A5 LDA zp|A6 LDX zp|A8 TAY imp|A9 LDA imm|AA TAX imp|AC LDY abs|AD LDA abs|AE LDX abs
B0 BCS rel|B1 LDA izy|B4 LDY zpx|B5 LDA zpx|B6 LDX zpy|B8 CLV imp|B9 LDA aby|BA TSX imp|BC LDY abx|BD LDA abx|BE LDX aby
C0 CPY imm|C1 CMP izx|C4 CPY zp|C5 CMP zp|C6 DEC zp|C8 INY imp|C9 CMP imm|CA DEX imp|CC CPY abs|CD CMP abs|CE DEC abs
D0 BNE rel|D1 CMP izy|D5 CMP zpx|D6 DEC zpx|D8 CLD imp|D9 CMP aby|DD CMP abx|DE DEC abx
E0 CPX imm|E1 SBC izx|E4 CPX zp|E5 SBC zp|E6 INC zp|E8 INX imp|E9 SBC imm|EA NOP imp|EC CPX abs|ED SBC abs|EE INC abs
F0 BEQ rel|F1 SBC izy|F5 SBC zpx|F6 INC zpx|F8 SED imp|F9 SBC aby|FD SBC abx|FE INC abx
"""

OPS = {}
for _line in _OPS.split("\n"):
    for _e in _line.split("|"):
        _e = _e.split()
        if _e:
            OPS[int(_e[0], 16)] = (_e[1], _e[2])

SIZE = {"imp": 1, "acc": 1, "imm": 2, "zp": 2, "zpx": 2, "zpy": 2, "izx": 2,
        "izy": 2, "abs": 3, "abx": 3, "aby": 3, "ind": 3, "rel": 2}

BRANCHES = {"BPL", "BMI", "BVC", "BVS", "BCC", "BCS", "BNE", "BEQ"}

HERE = os.path.dirname(os.path.abspath(__file__))
ROMDIR = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
ROMS = {"us": os.path.join(ROMDIR, "Bomberman II (USA).nes"),
        "jp": os.path.join(ROMDIR, "Bomberman II (Japan).nes")}

NBANKS = 8
FIXED = 7


def load_prg(region):
    with open(ROMS[region], "rb") as f:
        data = f.read()
    return data[16:16 + 0x20000]


def bank_base(bank):
    return 0xC000 if bank == FIXED else 0x8000


def read(prg, bank, addr):
    """Byte at CPU address addr with `bank` mapped at $8000."""
    if addr >= 0xC000:
        return prg[FIXED * 0x4000 + addr - 0xC000]
    return prg[bank * 0x4000 + addr - 0x8000]


def decode(prg, bank, pc):
    """Return (opcode, mnem, mode, size, operand) or None for illegal opcodes."""
    op = read(prg, bank, pc)
    if op not in OPS:
        return None
    mnem, mode = OPS[op]
    n = SIZE[mode]
    if pc + n - 1 > 0xFFFF:
        return None
    if n == 2:
        v = read(prg, bank, pc + 1)
        if mode == "rel":
            v = (pc + 2 + ((v ^ 0x80) - 0x80)) & 0xFFFF
    elif n == 3:
        v = read(prg, bank, pc + 1) | read(prg, bank, pc + 2) << 8
    else:
        v = None
    return op, mnem, mode, n, v


def fmt(mnem, mode, v, name=None):
    a = name if name is not None else ("$%02X" % v if mode in ("imm", "zp", "zpx", "zpy", "izx", "izy") else ("$%04X" % v if v is not None else ""))
    return {"imp": mnem, "acc": mnem + " A", "imm": "%s #%s" % (mnem, a),
            "zp": "%s %s" % (mnem, a), "zpx": "%s %s,X" % (mnem, a), "zpy": "%s %s,Y" % (mnem, a),
            "izx": "%s (%s,X)" % (mnem, a), "izy": "%s (%s),Y" % (mnem, a),
            "abs": "%s %s" % (mnem, a), "abx": "%s %s,X" % (mnem, a), "aby": "%s %s,Y" % (mnem, a),
            "ind": "%s (%s)" % (mnem, a), "rel": "%s %s" % (mnem, a)}[mode]


def listing(prg, bank, start, count):
    """Simple linear disassembly for exploration."""
    pc, out = start, []
    for _ in range(count):
        d = decode(prg, bank, pc)
        if d is None:
            out.append("%04X  %02X        .byte" % (pc, read(prg, bank, pc)))
            pc += 1
            continue
        op, mnem, mode, n, v = d
        raw = " ".join("%02X" % read(prg, bank, pc + i) for i in range(n))
        out.append("%04X  %-9s %s" % (pc, raw, fmt(mnem, mode, v)))
        pc += n
    return "\n".join(out)


if __name__ == "__main__":
    import sys
    region, bank, start, count = sys.argv[1], int(sys.argv[2]), int(sys.argv[3], 16), int(sys.argv[4])
    print(listing(load_prg(region), bank, start, count))
