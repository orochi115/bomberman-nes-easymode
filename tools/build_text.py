#!/usr/bin/env python3
"""Build the CNROM CHR banks (bomber_text.chr) and the text data
(text_data.asm) from text/<lang>_strings.txt. Chinese uses the Fusion Pixel
12px font (OFL, based on Ark Pixel; see fonts/), English the original 8x8 font.

CHR banks (8KB each, sprite table always copied unchanged):
  0 GAME   in-game graphics
  1 TITLE  title menu
  2 TEXT   stage intro, bonus stage, game over, ending
  3 OPTS   options screen

Each CJK character is drawn into a 16x16 cell (2x2 tiles) using the same
colours as the original font: 3 = body, 1 = shadow, 2 = background.
Strings are emitted as two rows of tile ids so the 6502 side only has to copy
bytes to the nametable. Records are labelled ZH_<ID> in both languages.

Text syntax (see the strings files): CJK characters are 2x2 tiles; ASCII
letters / digits use the original font in the bottom row; '<', '>', '+' and
':' are extra 8x8 symbols; {XX} is the raw tile XX; {} is an empty string.
A text of '@' only defines the address constant ZH_<ID>_ADDR (the exact tile
at ROW, COL). "CONST NAME VALUE" lines are passed on as assembler constants.

Usage: build_text.py [--lang zh|en] [--preview]
  (--preview also writes text/preview_*.png)
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.dirname(HERE)

FONT = os.path.join(SRC, 'fonts', 'fusion-pixel-12px-monospaced-zh_hans.bdf')
OUT_CHR = os.path.join(SRC, 'bomber_text.chr')
OUT_ASM = os.path.join(SRC, 'text_data.asm')
LANGS = ('zh', 'en')

BANKS = ['GAME', 'TITLE', 'TEXT', 'OPTS']
BG = 0x1000  # Background pattern table offset within a bank

BLANK = 0xB0  # Blank tile (colour 0), as used by CLS
HUD_BLANK = 0x3A  # ':' is a tile filled with colour 2, the status bar background

# Glyph placement of the 12x12 em box inside the 16x16 cell
GLYPH_X = 1
GLYPH_Y = 3

# Tiles which must survive in each bank (everything else may be replaced)
DIGITS = set(range(0x30, 0x3B))  # 0-9 and ':' (filled blank)


def letters(s):
    return {ord(c) for c in s if 'A' <= c <= 'Z'}


def title_tiles():
    """Tiles used by the title logo, read from MAINMENU_HI/LO in bman.asm."""
    src = open(os.path.join(SRC, 'bman.asm')).read()
    start = src.index('.MAINMENU_HI')
    end = src.index('.DRAWMENUTEXT')
    used = {int(h, 16) for h in re.findall(r'&([0-9A-F]{2})', src[start:end])}
    return used


KEEP = {
    'GAME': None,  # Special case (see free_tiles)
    'TITLE': lambda: title_tiles() | DIGITS | {BLANK, 0xFD, 0xFE}
    | letters('TM AND HUDSON SOFT LICENSED BY NINTENDO OF AMERICA INC'),
    'TEXT': lambda: DIGITS | {BLANK} | set(range(0x68, 0x6C)),  # bricks
    'OPTS': lambda: DIGITS | {BLANK} | letters('START'),
}


def free_tiles(bank):
    if bank == 'GAME':
        # A-Z, and the title logo tiles which the game never uses
        return list(range(0x41, 0x5B)) + [t for t in range(0xAC, 0x100) if t != BLANK]
    keep = KEEP[bank]()
    return [t for t in range(256) if t not in keep]


# ---------------------------------------------------------------------------
# Font

def load_bdf(path, wanted):
    """Return {char: (12x12 list of rows of 0/1)} for the wanted chars."""
    glyphs = {}
    ascent = 10
    cur = None
    with open(path, encoding='utf-8') as f:
        lines = iter(f)
        for line in lines:
            if line.startswith('FONT_ASCENT'):
                ascent = int(line.split()[1])
            elif line.startswith('ENCODING'):
                code = int(line.split()[1])
                cur = chr(code) if chr(code) in wanted else None
            elif cur and line.startswith('BBX'):
                w, h, xo, yo = map(int, line.split()[1:])
            elif cur and line.startswith('BITMAP'):
                bm = [[0] * 12 for _ in range(12)]
                top = ascent - (yo + h)
                for r in range(h):
                    bits = int(next(lines).strip(), 16)
                    nbits = ((w + 7) // 8) * 8
                    for c in range(w):
                        if bits >> (nbits - 1 - c) & 1:
                            y, x = top + r, xo + c
                            if 0 <= y < 12 and 0 <= x < 12:
                                bm[y][x] = 1
                glyphs[cur] = bm
                cur = None
    missing = [c for c in wanted if c not in glyphs]
    if missing:
        sys.exit('Missing glyphs in font: ' + ''.join(missing))
    return glyphs


def arrow(right):
    """8x16 triangle pointing right or left, roughly centred on CJK text."""
    bm = [[0] * 8 for _ in range(16)]
    widths = [1, 2, 3, 4, 5, 4, 3, 2, 1]
    for i, wd in enumerate(widths):
        for c in range(wd):
            x = 1 + c if right else 6 - c
            bm[5 + i][x] = 1
    return bm


SPECIAL = {'▶': lambda: arrow(True), '◀': lambda: arrow(False)}


def small(rows):
    """8x8 symbol from a picture, X = body."""
    return [[1 if c == 'X' else 0 for c in r] for r in rows]


# 8x8 symbols missing from the original font, drawn in the bottom tile row
SMALL = {
    '<': small(['....X...', '...XX...', '..XXX...', '.XXXX...',
                '..XXX...', '...XX...', '....X...', '........']),
    '>': small(['..X.....', '..XX....', '..XXX...', '..XXXX..',
                '..XXX...', '..XX....', '..X.....', '........']),
    '+': small(['........', '...XX...', '...XX...', '.XXXXXX.',
                '.XXXXXX.', '...XX...', '...XX...', '........']),
    ':': small(['........', '...XX...', '...XX...', '........',
                '...XX...', '...XX...', '........', '........']),
}


def shade(body, w, h):
    """Colour a body bitmap: 3 body, 1 shadow (right/down), 2 background."""
    px = [[2] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            if body[y][x]:
                for dx, dy in ((1, 0), (0, 1), (1, 1)):
                    if x + dx < w and y + dy < h and not body[y + dy][x + dx]:
                        px[y + dy][x + dx] = 1
    for y in range(h):
        for x in range(w):
            if body[y][x]:
                px[y][x] = 3
    return px


def cell_for(ch, font):
    """Return (columns, pixel rows) for a character cell 16 px high."""
    if ch in SMALL:
        return 1, [[2] * 8 for _ in range(8)] + shade(SMALL[ch], 8, 8)
    if ch in SPECIAL:
        return 1, shade(SPECIAL[ch](), 8, 16)
    body = [[0] * 16 for _ in range(16)]
    g = font[ch]
    for y in range(12):
        for x in range(12):
            if g[y][x]:
                body[GLYPH_Y + y][GLYPH_X + x] = 1
    return 2, shade(body, 16, 16)


def encode_tile(px, ox, oy):
    """Encode the 8x8 area at (ox, oy) of a pixel grid as 16 CHR bytes."""
    lo = bytearray(8)
    hi = bytearray(8)
    for y in range(8):
        for x in range(8):
            c = px[oy + y][ox + x]
            if c & 1:
                lo[y] |= 0x80 >> x
            if c & 2:
                hi[y] |= 0x80 >> x
    return bytes(lo + hi)


# ---------------------------------------------------------------------------
# Strings

def is_wide(ch):
    return ch in SPECIAL or ord(ch) > 0x7F and ch != '　'


def tokens(text):
    """Split a string into characters and {XX} raw tiles ({} is nothing)."""
    out = []
    for m in re.finditer(r'\{([0-9A-Fa-f]{2})?\}|.', text):
        if m.group(0).startswith('{'):
            if m.group(1):
                out.append(int(m.group(1), 16))
        else:
            out.append(m.group(0))
    return out


def parse_strings(path):
    out, consts = [], []
    with open(path, encoding='utf-8') as f:
        for n, line in enumerate(f, 1):
            if not line.strip() or line.lstrip().startswith('#'):
                continue
            if line.startswith('CONST'):
                _, name, value = line.split()
                consts.append((name, value))
                continue
            m = re.match(r'(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(.*?)\s*$', line)
            if not m:
                sys.exit('%s:%d: bad line' % (path, n))
            bank, sid, row, col, text = m.groups()
            if bank not in BANKS:
                sys.exit('%s:%d: unknown bank %s' % (path, n, bank))
            out.append((bank, sid, row, col, text))
    return out, consts


def main():
    preview = '--preview' in sys.argv
    lang = 'zh'
    if '--lang' in sys.argv:
        lang = sys.argv[sys.argv.index('--lang') + 1]
    if lang not in LANGS:
        sys.exit('Unknown language %s (expected one of %s)' % (lang, ', '.join(LANGS)))
    path = os.path.join(SRC, 'text', '%s_strings.txt' % lang)

    strings, consts = parse_strings(path)
    wanted = {c for s in strings for c in tokens(s[4])
              if isinstance(c, str) and is_wide(c) and c not in SPECIAL}
    font = load_bdf(FONT, wanted) if wanted else {}

    orig = open(os.path.join(SRC, 'bomber.chr'), 'rb').read()
    assert len(orig) == 8192
    banks = {b: bytearray(orig) for b in BANKS}
    # Letters, digits and raw tiles used by a bank's strings keep their tiles
    def original_tile(c):
        if isinstance(c, int):
            return c
        if c.isdigit() or 'A' <= c <= 'Z':
            return ord(c)
        return None
    used_ascii = {b: {original_tile(c) for s in strings if s[0] == b
                      for c in tokens(s[4])} - {None} for b in BANKS}
    free = {b: [t for t in free_tiles(b) if t not in used_ascii[b]] for b in BANKS}
    alloc = {b: {} for b in BANKS}  # char -> (top tiles, bottom tiles)

    def tiles_for(bank, ch):
        if ch in alloc[bank]:
            return alloc[bank][ch]
        cols, px = cell_for(ch, font)
        rows = ((8, 'bot'),) if ch in SMALL else ((0, 'top'), (8, 'bot'))
        if len(free[bank]) < cols * len(rows):
            sys.exit('Out of tiles in bank %s at %r' % (bank, ch))
        top, bot = [], []
        if ch in SMALL:
            top.append(HUD_BLANK if bank == 'GAME' else BLANK)
        for c in range(cols):
            for row, name in rows:
                lst = top if name == 'top' else bot
                t = free[bank].pop(0)
                off = BG + t * 16
                banks[bank][off:off + 16] = encode_tile(px, c * 8, row)
                lst.append(t)
        alloc[bank][ch] = (top, bot)
        return top, bot

    asm = ['; Generated by tools/build_text.py from text/%s_strings.txt - do not edit' % lang,
           ';',
           '; Record: PPU address hi, lo (0,0 = positioned at run time),',
           ';         width in tiles, top row tiles, bottom row tiles', '',
           'LANG_ZH = %d' % (lang == 'zh'), 'LANG_EN = %d' % (lang == 'en')]
    asm += ['%s = %s' % c for c in consts]
    asm.append('')
    for bank, sid, row, col, text in strings:
        if text == '@':
            # Position only
            asm.append('ZH_%s_ADDR = &%04X' % (sid, 0x2000 + int(row) * 32 + int(col)))
            asm.append('')
            continue
        top, bot = [], []
        # The status bar background is the filled ':' tile, not the blank one
        blank = HUD_BLANK if bank == 'GAME' else BLANK
        for ch in tokens(text):
            if isinstance(ch, int):
                top.append(blank)
                bot.append(ch)
            elif is_wide(ch) or ch in SMALL:
                t, b = tiles_for(bank, ch)
                top += t
                bot += b
            elif ch == '　':
                top += [blank, blank]
                bot += [blank, blank]
            elif ch == ' ':
                top.append(blank)
                bot.append(blank)
            elif ch.isdigit() or 'A' <= ch <= 'Z':
                top.append(blank)
                bot.append(ord(ch))
            else:
                sys.exit('Unsupported character %r in %s' % (ch, sid))
        width = len(top)
        if row == '-':
            addr = 0
        else:
            c = (32 - width) // 2 if col == 'c' else int(col)
            if c + width > 32:
                sys.exit('%s is too wide (%d tiles at column %d)' % (sid, width, c))
            addr = 0x2000 + int(row) * 32 + c
            asm.append('ZH_%s_ADDR = &%04X' % (sid, addr))
        asm.append('.ZH_%s ; %s (bank %s)' % (sid, text, bank))
        asm.append('  EQUB &%02X, &%02X, %d' % (addr >> 8, addr & 0xFF, width))
        if width:
            asm.append('  EQUB ' + ','.join('&%02X' % t for t in top))
            asm.append('  EQUB ' + ','.join('&%02X' % t for t in bot))
        asm.append('')

    with open(OUT_ASM, 'w', encoding='utf-8') as f:
        f.write('\n'.join(asm))
    with open(OUT_CHR, 'wb') as f:
        for b in BANKS:
            f.write(banks[b])

    for b in BANKS:
        print('%s bank %-5s %3d chars, %3d tiles free' % (lang, b, len(alloc[b]), len(free[b])))

    if preview:
        write_previews(banks)


def write_previews(banks):
    from PIL import Image
    pal = [(0, 0, 0), (116, 116, 116), (0, 0, 0), (252, 252, 252)]
    for i, b in enumerate(BANKS):
        im = Image.new('RGB', (128, 128))
        data = banks[b]
        for t in range(256):
            off = BG + t * 16
            for y in range(8):
                for x in range(8):
                    c = (data[off + y] >> (7 - x) & 1) | (data[off + 8 + y] >> (7 - x) & 1) << 1
                    im.putpixel(((t % 16) * 8 + x, (t // 16) * 8 + y), pal[c])
        im.resize((512, 512), Image.NEAREST).save(
            os.path.join(SRC, 'text', 'preview_%d_%s.png' % (i, b.lower())))


if __name__ == '__main__':
    main()
