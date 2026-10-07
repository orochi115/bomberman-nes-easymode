#!/usr/bin/env python3
"""Build the mod's text data from text/<lang>_strings.txt.

Chinese uses the Fusion Pixel 12px font (OFL, see fonts/), drawn into 16x16
cells (2x2 tiles). The game has CHR-RAM, so every screen keeps its original
graphics and the glyphs of that screen's strings are uploaded into tiles the
screen does not use (a "set" per screen, see SETS). The 6502 side copies
tile ids from string records; it never looks characters up.

Output (all in build/):
  text_consts.asm   ZH_<ID> string numbers, ZH_SET_<SET> set numbers,
                    ZH_<ID>_ADDR addresses, CONST lines
  text_index.asm    fixed bank tables: set and string -> bank, address
  text_bankN.asm    N = 8..14: set headers, tile data, string records

Set header: number of upload runs, then per run PPU address hi, lo, tile
count, source lo, hi; then the number of strings printed by ZH_SCREEN and
their string numbers.
String record: PPU address hi, lo (0,0 = given at run time), width in tiles,
top row tile ids, bottom row tile ids.
Sprite string record (sets with table 'spr'): a DRAW_METASPRITE list
(count, then tile, dx, dy, attr per sprite), centred on the given X/Y.

Text syntax: CJK characters are 2x2 tiles; ASCII letters and digits use the
set's 8x8 font tile (same code as ASCII) in the bottom row; a space is one
8px blank column, a full-width space two; ◀ ▶ are 8x16 arrows; {XX} is raw
tile XX in the bottom row; {} is an empty string. A text of '@' only
defines ZH_<ID>_ADDR. A text of '=XX XX ...' is a row of attribute bytes at
attribute row ROW, column COL. An ID starting with '!' is not printed by
ZH_SCREEN.
An ID ending in /US or /JP is only used for that region. SET:B,S,G draws the
string's glyphs with other colours (body, shadow, background).

Usage: build_text.py [--lang zh|en] [--region us|jp] [--preview]
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.dirname(HERE)
OUT = os.path.join(SRC, 'build')

FONT = os.path.join(SRC, 'fonts', 'fusion-pixel-12px-monospaced-zh_hans.bdf')
LANGS = ('zh', 'en')
REGIONS = ('us', 'jp')

FIRST_BANK, LAST_BANK = 8, 14
BANK_SIZE = 0x3FBC - 64   # up to RESET_STUB, with some room to spare

# Glyph placement of the 12x12 em box inside the 16x16 cell
GLYPH_X = 1
GLYPH_Y = 3


def tiles(spec):
    """'41-44 47' -> [0x41..0x44, 0x47]"""
    out = []
    for part in spec.split():
        a, _, b = part.partition('-')
        out += range(int(a, 16), int(b or a, 16) + 1)
    return out


# Never free on the UI_SPR_CHR screens: the big digits (UI metatiles 64-6D:
# 04-0F 14-1F 2A-2D 3A-3D C6-C9), the 8px digits 30-39.
UI_POOL = tiles('2E 2F 36-39 3E 3F 46 4A 4B 51 58-5A 5D 74 75 7E 7F 89 C4 C5 CA-CF FC-FF')
UI_LETTERS = tiles('41-4F 51-5A')   # the 8px letters, except P (P1, P2 ...)

# Screen sets. table: 'bg' ($1000) or 'spr' ($0000). colors: palette index of
# body, shadow, background. blank: the screen's empty tile (top row of 8px
# characters, spaces). free: tiles the screen never shows (measured with
# tools/freetiles.py in both regions).
SETS = {
    # Mode menu: UI_SPR_CHR. It shows 13, 30-39 (TOP score) and the letters
    # of its own lines.
    'MENU': dict(table='bg', colors=(2, 0, 3), blank=0x13,
                 free=tiles('00-12 14-2F 3A-40 5B-FF')),
    # Story HUD: PLAY_SPR_CHR. Letters which the game does not use
    # (B D G-K M-O Q R V-Z) and 84-9F (never uploaded during play).
    'HUD': dict(table='bg', colors=(2, 3, 3), blank=0x65,
                free=tiles('42 44 47-4B 4D-4F 51 52 56-5A 84-9F')),
    # Story stage card (UI_SPR_CHR via LOAD_MODE_GFX): 00-3F (big and small
    # digits), SC / LEFT letters, 62 63 72 73 (-) and AREA (C0-FF) are kept.
    'CARD': dict(table='bg', colors=(2, 0, 0), blank=0x00,
                 free=tiles('41-42 44 47-4B 4D-52 55-61 64-71 74-BF')),
    # Game over (UI_SPR_CHR via LOAD_MENU_CHR): box 00-03 10-13, GAME OVER
    # 6C-7F 81 90 91, CONTINUE END, password brackets FA FB.
    'GAMEOVER': dict(table='bg', colors=(2, 0, 3), blank=0x13,
                     free=tiles('04-0F 14-2F 3A-40 5B-6B 82-8F 92-F9')),
    # Versus / battle screens with UI_SPR_CHR: tiles none of them shows
    # (measured over VS and battle play, cards and the result screen)
    'VSCARD': dict(table='bg', colors=(2, 0, 3), blank=0x13, free=UI_POOL + UI_LETTERS),
    'VSRES': dict(table='bg', colors=(2, 0, 3), blank=0x13, free=UI_POOL + UI_LETTERS),
    'BTSEL': dict(table='bg', colors=(2, 0, 3), blank=0x13, free=UI_POOL + UI_LETTERS),
    # Round result sprites in VS / battle play (sprite tiles 60-BF unused)
    'ROUND': dict(table='spr', colors=(3, 1, 0), blank=None, attr=1,
                  free=tiles('60-BF')),
    # Bonus stage card (UI_SPR_CHR, only BONUS STAGE on a black screen)
    'BONUS': dict(table='bg', colors=(2, 0, 0), blank=0x00, free=tiles('01-3F 5B-FF')),
    # Sound room (UI_SPR_CHR; fill tile 40, letters and hex digits 30-5A)
    'SOUND': dict(table='bg', colors=(2, 0, 3), blank=0x40, free=tiles('00-2F 5B-FF')),
    # Credits (UI_SPR_CHR; blank 40, letters and digits). Strings of the
    # pseudo set CREDROW are credit lines (see credits_table)
    'CREDITS': dict(table='bg', colors=(2, 0, 0), blank=0x40, free=tiles('00-2F 5B-FF')),
    # Options screen (UI_SPR_CHR, fill 13, digits; letters for English)
    'OPTS': dict(table='bg', colors=(2, 0, 3), blank=0x13, free=tiles('01-12 14-2F 3A-40 5B-FF')),
    # Title: the background table is full, the text is drawn with sprites.
    'TITLE': dict(table='spr', colors=(2, 3, 0), blank=None, attr=0,
                  free=tiles('30-FF')),
}


# ---------------------------------------------------------------------------
# Font

def load_bdf(path, wanted):
    """Return {char: 12x12 list of rows of 0/1} for the wanted chars."""
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
            bm[4 + i][x] = 1
    return bm


SPECIAL = {'▶': lambda: arrow(True), '◀': lambda: arrow(False)}


def shade(body, w, h, colors):
    """Colour a body bitmap with (body, shadow, background) indices; the
    shadow falls right and down."""
    cb, cs, cg = colors
    px = [[cg] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            if body[y][x]:
                for dx, dy in ((1, 0), (0, 1), (1, 1)):
                    if x + dx < w and y + dy < h and not body[y + dy][x + dx]:
                        px[y + dy][x + dx] = cs
    for y in range(h):
        for x in range(w):
            if body[y][x]:
                px[y][x] = cb
    return px


def cell_for(ch, font, colors):
    """Return (columns, 16 pixel rows) for a character cell."""
    if ch in SPECIAL:
        return 1, shade(SPECIAL[ch](), 8, 16, colors)
    if ord(ch) < 0x80:
        # Half-width character from the font (sprite sets have no 8x8 font)
        body = [[0] * 8 for _ in range(16)]
        g = font[ch]
        for y in range(12):
            for x in range(7):
                if g[y][x]:
                    body[GLYPH_Y + y][1 + x] = 1
        return 1, shade(body, 8, 16, colors)
    body = [[0] * 16 for _ in range(16)]
    g = font[ch]
    for y in range(12):
        for x in range(12):
            if g[y][x]:
                body[GLYPH_Y + y][GLYPH_X + x] = 1
    return 2, shade(body, 16, 16, colors)


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


def parse_strings(path, region):
    out, consts = [], []
    with open(path, encoding='utf-8') as f:
        for n, line in enumerate(f, 1):
            if not line.strip() or line.lstrip().startswith('#'):
                continue
            if line.startswith('CONST'):
                _, name, value = line.split()
                consts.append((name, value))
                continue
            # (not \s: the full-width space is part of the text)
            m = re.match(r'([^ \t]+)[ \t]+([^ \t]+)[ \t]+([^ \t]+)[ \t]+([^ \t]+)[ \t]+(.*?)[ \t]*$',
                         line.rstrip('\n'))
            if not m:
                sys.exit('%s:%d: bad line' % (path, n))
            sset, sid, row, col, text = m.groups()
            colors = None
            if ':' in sset:
                sset, c = sset.split(':')
                colors = tuple(int(x) for x in c.split(','))
            if sset not in SETS and sset != 'CREDROW':
                sys.exit('%s:%d: unknown set %s' % (path, n, sset))
            if '/' in sid:
                sid, reg = sid.split('/')
                if reg.lower() not in REGIONS:
                    sys.exit('%s:%d: unknown region %s' % (path, n, reg))
                if reg.lower() != region:
                    continue
            auto = not sid.startswith('!')
            sid = sid.lstrip('!')
            out.append(dict(set=sset, id=sid, row=row, col=col, text=text, auto=auto,
                            colors=colors))
    return out, consts


class SetBuilder:
    def __init__(self, name, spec, font):
        self.name = name
        self.spec = spec
        self.font = font
        self.free = [t for t in spec['free'] if t != 0 or spec['table'] == 'spr']
        self.alloc = {}        # char -> (top tiles, bottom tiles)
        self.data = {}         # tile -> 16 bytes

    def reserve(self, t):
        if t in self.free:
            self.free.remove(t)

    def glyph(self, ch, colors=None):
        colors = colors or self.spec['colors']
        if (ch, colors) in self.alloc:
            return self.alloc[(ch, colors)]
        cols, px = cell_for(ch, self.font, colors)
        if len(self.free) < cols * 2:
            sys.exit('Out of tiles in set %s at %r (%d glyphs placed); '
                     'shorten the text or use 8px text there' % (self.name, ch, len(self.alloc)))
        top, bot = [], []
        for c in range(cols):
            for row, lst in ((0, top), (8, bot)):
                t = self.free.pop(0)
                self.data[t] = encode_tile(px, c * 8, row)
                lst.append(t)
        self.alloc[(ch, colors)] = (top, bot)
        return top, bot

    def runs(self):
        """Contiguous runs of uploaded tiles: (first tile, [data...])."""
        out = []
        for t in sorted(self.data):
            if out and out[-1][0] + len(out[-1][1]) == t:
                out[-1][1].append(self.data[t])
            else:
                out.append((t, [self.data[t]]))
        return out


def build(lang, region):
    path = os.path.join(SRC, 'text', '%s_strings.txt' % lang)
    strings, consts = parse_strings(path, region)
    wanted = {c for s in strings for c in tokens(s['text'])
              if isinstance(c, str) and (is_wide(c) or s['set'] in SETS and SETS[s['set']]['table'] == 'spr'
                                         and c.isalnum()) and c not in SPECIAL}
    font = load_bdf(FONT, wanted) if wanted else {}
    sets = {name: SetBuilder(name, spec, font) for name, spec in SETS.items()}

    credit_rows = [s for s in strings if s['set'] == 'CREDROW']
    strings = [s for s in strings if s['set'] != 'CREDROW']
    for s in credit_rows:
        s['set'] = 'CREDITS'
    # 8px characters and raw tiles keep their original tiles
    for s in strings + credit_rows:
        for c in tokens(s['text']):
            if isinstance(c, int):
                sets[s['set']].reserve(c)
            elif (c.isdigit() or 'A' <= c <= 'Z') and SETS[s['set']]['table'] == 'bg':
                sets[s['set']].reserve(ord(c))

    consts_asm = ['; Generated by tools/build_text.py from text/%s_strings.txt - do not edit' % lang, '']
    consts_asm += ['%s = %s' % c for c in consts]
    consts_asm.append('')
    for i, name in enumerate(SETS):
        consts_asm.append('ZH_SET_%s = %d' % (name, i))
    consts_asm.append('')

    records = {name: [] for name in SETS}   # set -> asm lines
    autos = {name: [] for name in SETS}
    str_ids = []
    for s in strings:
        b = sets[s['set']]
        spec = b.spec
        sid, text = s['id'], s['text']
        if text.startswith('='):
            # Attribute bytes: ROW, COL are attribute table coordinates
            data = [int(x, 16) for x in text[1:].split()]
            addr = 0x23C0 + int(s['row']) * 8 + int(s['col'])
            num = len(str_ids)
            str_ids.append((sid, s['set']))
            consts_asm.append('ZH_%s = %d' % (sid, num))
            if s['auto']:
                autos[s['set']].append(num)
            records[s['set']] += ['.ZHS_%s ; attributes' % sid,
                                  '  EQUB &%02X, &%02X, &%02X' % (addr >> 8, addr & 0xFF, 0x80 | len(data)),
                                  '  EQUB ' + ','.join('&%02X' % x for x in data), '']
            continue
        if text == '@':
            consts_asm.append('ZH_%s_ADDR = &%04X' % (sid, 0x2000 + int(s['row']) * 32 + int(s['col'])))
            continue
        blank = spec['blank']
        top, bot = [], []
        for ch in tokens(text):
            if isinstance(ch, int):
                top.append(blank)
                bot.append(ch)
            elif is_wide(ch) or spec['table'] == 'spr' and ch.isalnum():
                t, bb = b.glyph(ch, s['colors'])
                top += t
                bot += bb
            elif ch in (' ', '　'):
                n = 1 if ch == ' ' else 2
                top += [blank] * n
                bot += [blank] * n
            elif ch.isdigit() or 'A' <= ch <= 'Z':
                top.append(blank)
                bot.append(ord(ch))
            else:
                sys.exit('Unsupported character %r in %s' % (ch, sid))
        width = len(top)
        num = len(str_ids)
        str_ids.append((sid, s['set']))
        consts_asm.append('ZH_%s = %d' % (sid, num))
        lines = records[s['set']]
        if spec['table'] == 'spr':
            sprites = []
            for i in range(width):
                for r, row in ((0, top), (8, bot)):
                    if row[i] is not None:
                        sprites.append((row[i], i * 8 - width * 4, r - 8, spec['attr']))
            lines.append('.ZHS_%s ; %s' % (sid, text))
            lines.append('  EQUB %d' % len(sprites))
            for t, dx, dy, at in sprites:
                lines.append('  EQUB &%02X, &%02X, &%02X, &%02X' % (t, dx & 0xFF, dy & 0xFF, at))
            lines.append('')
            continue
        if s['row'] == '-':
            addr = 0
        else:
            c = (32 - width) // 2 if s['col'] == 'c' else int(s['col'])
            nt = 0x2000
            if c >= 32:             # columns 32-63: the nametable at $2400
                nt, c = 0x2400, c - 32
            if c + width > 32:
                sys.exit('%s is too wide (%d tiles at column %d)' % (sid, width, c))
            addr = nt + int(s['row']) * 32 + c
            consts_asm.append('ZH_%s_ADDR = &%04X' % (sid, addr))
            if s['auto']:
                autos[s['set']].append(num)
        lines.append('.ZHS_%s ; %s' % (sid, text))
        lines.append('  EQUB &%02X, &%02X, %d' % (addr >> 8, addr & 0xFF, width))
        if width:
            lines.append('  EQUB ' + ','.join('&%02X' % t for t in top))
            lines.append('  EQUB ' + ','.join('&%02X' % t for t in bot))
        lines.append('')

    write(os.path.join(OUT, 'text_credits.asm'), credits_table(credit_rows, sets['CREDITS']))

    # Lay the sets out over the data banks
    bank_lines = {n: [] for n in range(FIRST_BANK, LAST_BANK + 1)}
    bank_used = {n: 0 for n in bank_lines}
    set_bank = {}
    for name, b in sets.items():
        base = 0x1000 if b.spec['table'] == 'bg' else 0x0000
        runs = b.runs()
        lines = ['; Set %s: %d characters, %d tiles, %d tiles left' %
                 (name, len(b.alloc), len(b.data), len(b.free)),
                 '.ZHSET_%s' % name, '  EQUB %d' % len(runs)]
        for i, (t, data) in enumerate(runs):
            addr = base + t * 16
            lines.append('  EQUB &%02X, &%02X, %d, LO(ZHT_%s_%d), HI(ZHT_%s_%d)' %
                         (addr >> 8, addr & 0xFF, len(data), name, i, name, i))
        lines.append('  EQUB %d%s' % (len(autos[name]), ''.join(', %d' % a for a in autos[name])))
        for i, (t, data) in enumerate(runs):
            lines.append('.ZHT_%s_%d ; tiles &%02X-&%02X' % (name, i, t, t + len(data) - 1))
            for d in data:
                lines.append('  EQUB ' + ','.join('&%02X' % x for x in d))
        lines.append('')
        lines += records[name]
        size = sum(len(d) * 16 for _, d in runs) + 512 + 8 * len(records[name])
        bank = next((n for n in bank_lines if bank_used[n] + size <= BANK_SIZE), None)
        if bank is None:
            sys.exit('Text data does not fit in banks %d-%d' % (FIRST_BANK, LAST_BANK))
        bank_used[bank] += size
        bank_lines[bank] += lines
        set_bank[name] = bank

    index = ['; Generated by tools/build_text.py - do not edit', '',
             '.ZH_SET_BANK', '  EQUB ' + ','.join(str(set_bank[n]) for n in SETS),
             '.ZH_SET_LO', '  EQUB ' + ','.join('LO(ZHSET_%s)' % n for n in SETS),
             '.ZH_SET_HI', '  EQUB ' + ','.join('HI(ZHSET_%s)' % n for n in SETS)]
    if str_ids:
        index += ['.ZH_STR_BANK', '  EQUB ' + ','.join(str(set_bank[st]) for _, st in str_ids),
                  '.ZH_STR_LO', '  EQUB ' + ','.join('LO(ZHS_%s)' % i for i, _ in str_ids),
                  '.ZH_STR_HI', '  EQUB ' + ','.join('HI(ZHS_%s)' % i for i, _ in str_ids)]
    else:
        index += ['.ZH_STR_BANK', '.ZH_STR_LO', '.ZH_STR_HI']

    os.makedirs(OUT, exist_ok=True)
    write(os.path.join(OUT, 'text_consts.asm'), consts_asm)
    write(os.path.join(OUT, 'text_index.asm'), index)
    for n, lines in bank_lines.items():
        write(os.path.join(OUT, 'text_bank%d.asm' % n),
              ['; Generated by tools/build_text.py - do not edit', ''] + lines)
    for name, b in sets.items():
        print('%s %s set %-6s %3d chars, %3d tiles free (bank %d)' %
              (lang, region, name, len(b.alloc), len(b.free), set_bank[name]))
    return sets


def credits_table(rows, b):
    """Credits line table for bank 0 (TICK_CREDITS, one entry per text row):
    the original table D0_B117 with the CREDROW lines replacing rows. ROW is
    the line of the bottom half (the top half goes in the row before), COL a
    column of the 26-tile line or c; a text of {} blanks the row."""
    src = open(os.path.join(SRC, 'bank0.asm')).read()
    tab = []
    for line in src[src.index('.D0_B117'):].split('\n')[1:]:
        m = re.match(r'\s+EQUW (\w+)', line)
        if not m:
            break
        tab.append(m.group(1))
    out = ['; Generated by tools/build_text.py - do not edit', '', '.ZH_CREDITS_TAB']
    data = []
    blank = b.spec['blank']
    for s in rows:
        n = int(s['row'])
        if s['text'] == '{}':
            tab[n] = 'D0_B28F'
            continue
        top, bot = [], []
        for ch in tokens(s['text']):
            if isinstance(ch, int) or not is_wide(ch):
                code = ch if isinstance(ch, int) else (blank if ch == ' ' else ord(ch))
                top.append(blank)
                bot.append(code)
            else:
                t, bb = b.glyph(ch, s['colors'])
                top += t
                bot += bb
        c = (26 - len(top)) // 2 if s['col'] == 'c' else int(s['col'])
        for half, row in (('T', top), ('B', bot)):
            line = [blank] * 26
            line[c:c + len(row)] = row
            label = 'ZHC_%d%s' % (n, half)
            data += ['.' + label + ' ; ' + s['text'], '  EQUB ' + ','.join('&%02X' % x for x in line)]
            tab[n - 1 if half == 'T' else n] = label
    out += ['  EQUW ' + t for t in tab] + ['  EQUW 0     ; end of the credits']
    return out + [''] + data


def write(path, lines):
    with open(path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines) + '\n')


def write_previews(sets):
    from PIL import Image
    pal = [(0, 0, 0), (116, 116, 116), (252, 252, 252), (60, 120, 220)]
    for name, b in sets.items():
        im = Image.new('RGB', (128, 128), (255, 0, 255))
        for t, data in b.data.items():
            for y in range(8):
                for x in range(8):
                    c = (data[y] >> (7 - x) & 1) | (data[8 + y] >> (7 - x) & 1) << 1
                    im.putpixel(((t % 16) * 8 + x, (t // 16) * 8 + y), pal[c])
        im.resize((512, 512), Image.NEAREST).save(os.path.join(OUT, 'preview_%s.png' % name.lower()))


def main():
    args = sys.argv[1:]
    lang = args[args.index('--lang') + 1] if '--lang' in args else 'zh'
    region = args[args.index('--region') + 1] if '--region' in args else 'us'
    if lang not in LANGS:
        sys.exit('Unknown language %s (expected one of %s)' % (lang, ', '.join(LANGS)))
    if region not in REGIONS:
        sys.exit('Unknown region %s (expected one of %s)' % (region, ', '.join(REGIONS)))
    sets = build(lang, region)
    if '--preview' in args:
        write_previews(sets)


if __name__ == '__main__':
    main()
