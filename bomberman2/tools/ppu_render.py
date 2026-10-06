"""Render the visible background (scroll-aware, single screen) and sprites."""

from PIL import Image

PALETTE = [
    0x666666, 0x002A88, 0x1412A7, 0x3B00A4, 0x5C007E, 0x6E0040, 0x6C0600, 0x561D00,
    0x333500, 0x0B4800, 0x005200, 0x004F08, 0x00404D, 0x000000, 0x000000, 0x000000,
    0xADADAD, 0x155FD9, 0x4240FF, 0x7527FE, 0xA01ACC, 0xB71E7B, 0xB53120, 0x994E00,
    0x6B6D00, 0x388700, 0x0C9300, 0x008F32, 0x007C8D, 0x000000, 0x000000, 0x000000,
    0xFFFEFF, 0x64B0FF, 0x9290FF, 0xC676FF, 0xF36AFF, 0xFE6ECC, 0xFE8170, 0xEA9E22,
    0xBCBE00, 0x88D800, 0x5CE430, 0x45E082, 0x48CDDE, 0x4F4F4F, 0x000000, 0x000000,
    0xFFFEFF, 0xC0DFFF, 0xD3D2FF, 0xE8C8FF, 0xFBC2FF, 0xFEC4EA, 0xFECCC5, 0xF7D8A5,
    0xE4E594, 0xCFEF96, 0xBDF4AB, 0xB3F3CC, 0xB5EBF2, 0xB8B8B8, 0x000000, 0x000000,
]


def rgb(c):
    c = PALETTE[c & 0x3F]
    return (c >> 16, (c >> 8) & 0xFF, c & 0xFF)


def render(nes, full=False):
    """full=True: whole 512x480 nametable space, else the 256x240 view at the scroll."""
    w, h = (512, 480) if full else (256, 240)
    img = Image.new("RGB", (w, h))
    px = img.load()
    bgpt = 0x1000 if nes.ppuctrl & 0x10 else 0
    base_nt = nes.ppuctrl & 3
    sx = 0 if full else nes.scroll[0] + (base_nt & 1) * 256
    sy = 0 if full else nes.scroll[1] + (base_nt >> 1) * 240
    for y in range(h):
        wy = (y + sy) % 480
        nty, ty, fy = wy // 240, (wy % 240) // 8, wy % 8
        for x in range(w):
            wx = (x + sx) % 512
            ntx, tx, fx = wx // 256, (wx % 256) // 8, wx % 8
            nta = 0x2000 + (nty * 2 + ntx) * 0x400
            t = nes.vread(nta + ty * 32 + tx)
            at = nes.vread(nta + 0x3C0 + (ty // 4) * 8 + tx // 4)
            pal = (at >> (((ty & 2) << 1) | (tx & 2))) & 3
            lo = nes.chr[bgpt + t * 16 + fy]
            hi = nes.chr[bgpt + t * 16 + fy + 8]
            c = ((lo >> (7 - fx)) & 1) | (((hi >> (7 - fx)) & 1) << 1)
            px[x, y] = rgb(nes.pal[pal * 4 + c] if c else nes.pal[0])
    if not full:
        sppt = 0x1000 if nes.ppuctrl & 8 else 0
        tall = nes.ppuctrl & 0x20
        for i in range(63, -1, -1):
            yy, t, at, xx = nes.oam[i * 4:i * 4 + 4]
            if yy >= 0xEF:
                continue
            for r in range(16 if tall else 8):
                if tall:
                    tile = (t & 0xFE) + (r >> 3)
                    base = (t & 1) * 0x1000
                else:
                    tile, base = t, sppt
                rr = (15 - r if tall else 7 - r) if at & 0x80 else r
                if tall:
                    tile = (t & 0xFE) + (rr >> 3)
                addr = base + tile * 16 + (rr & 7)
                lo, hi = nes.chr[addr], nes.chr[addr + 8]
                for c in range(8):
                    b = 7 - c if not at & 0x40 else c
                    v = ((lo >> b) & 1) | (((hi >> b) & 1) << 1)
                    X, Y = xx + c, yy + 1 + r
                    if v and X < 256 and Y < 240:
                        px[X, Y] = rgb(nes.pal[0x10 + (at & 3) * 4 + v])
    return img
