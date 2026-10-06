"""Collect a CDL-like coverage log by playing scripted/random scenarios.

Usage: cover.py REGION OUT_PREFIX [scenario ...]
Writes OUT_PREFIX.cdl (one flag byte per PRG byte: 1 opcode, 2 operand, 4 data read)
and OUT_PREFIX.json (indexed table bases, JMP () targets, JSR edges with banks).
Existing files are merged, so runs accumulate.
"""

import json
import os
import random
import sys

from emu import NES, A, B, SELECT, START, UP, DOWN, LEFT, RIGHT
from m6502 import ROMS

DIRS = [UP, DOWN, LEFT, RIGHT]


def press(nes, button, frames=3, pad=0):
    nes.pad[pad] = button
    for _ in range(frames):
        nes.run_frame()
    nes.pad[pad] = 0
    for _ in range(frames):
        nes.run_frame()


def wait(nes, frames):
    for _ in range(frames):
        if nes.run_frame() is False:
            raise RuntimeError("stopped: %r" % (nes.illegal,))


def random_play(nes, frames, rng, pads=(0,), start_every=0):
    """Wander with random directions, drop bombs, detonate."""
    t = 0
    hold = [0] * 2
    cur = [0] * 2
    while t < frames:
        for p in pads:
            if hold[p] <= 0:
                cur[p] = rng.choice(DIRS)
                if rng.random() < 0.35:
                    cur[p] |= A
                if rng.random() < 0.1:
                    cur[p] |= B
                hold[p] = rng.randint(4, 30)
            hold[p] -= 1
            # Tap A rather than holding it
            nes.pad[p] = cur[p] if t & 4 else cur[p] & ~A
        if start_every and t % start_every == start_every - 1:
            nes.pad[0] = START
        wait(nes, 1)
        t += 1
    nes.pad = [0, 0]


def to_menu(nes):
    wait(nes, 1500)
    press(nes, START)
    wait(nes, 60)


def scen_attract(nes, rng):
    wait(nes, 9000)


def scen_normal(nes, rng):
    to_menu(nes)
    press(nes, START)
    random_play(nes, 9000, rng)


def menu_pick(nes, n):
    for _ in range(n):
        press(nes, DOWN)
    press(nes, START)
    wait(nes, 60)


def scen_vs(nes, rng):
    to_menu(nes)
    menu_pick(nes, 1)
    for _ in range(6):
        press(nes, START)
        press(nes, A)
        wait(nes, 30)
    random_play(nes, 8000, rng, pads=(0, 1))


def scen_battle(nes, rng):
    to_menu(nes)
    menu_pick(nes, 2)
    for _ in range(6):
        press(nes, START)
        press(nes, A)
        wait(nes, 30)
    random_play(nes, 8000, rng, pads=(0, 1))


def scen_continue(nes, rng):
    to_menu(nes)
    menu_pick(nes, 3)
    for _ in range(40):
        press(nes, rng.choice(DIRS + [A, B, A, B]))
    press(nes, START)
    random_play(nes, 3000, rng)


def scen_menu_random(nes, rng):
    to_menu(nes)
    for _ in range(300):
        press(nes, rng.choice(DIRS + [A, B, START, SELECT]), frames=rng.randint(2, 20))


AREA, ROUND, LIVES = 0x4B, 0x4C, 0x04E5     # from Data Crystal + bank 7 stage loop


def play_stage(base, area, rnd, frames, rng):
    """Copy of a menu snapshot; start NORMAL MODE at area/round, infinite lives."""
    import copy
    nes = copy.deepcopy(base)
    nes.force = {AREA: lambda v: area, ROUND: lambda v: rnd, LIVES: lambda v: max(v, 2)}
    for b in (START, START, A):
        press(nes, b)
        wait(nes, 94)
    random_play(nes, frames, rng)
    nes.force = None
    return nes


def make_stage(area):
    def scen(nes, rng):
        to_menu(nes)
        nes.extra = [play_stage(nes, area, r, 1500, rng) for r in range(8)]
    return scen


for _a in range(6):
    globals()["scen_stage%d" % _a] = make_stage(_a)

SCENARIOS = {k[5:]: v for k, v in globals().items() if k.startswith("scen_")}


def merge(prefix, nes):
    cdl = bytearray(len(nes.prg))
    meta = {"tables": {}, "indirect": {}, "calls": []}
    if os.path.exists(prefix + ".cdl"):
        cdl = bytearray(open(prefix + ".cdl", "rb").read())
        meta = json.load(open(prefix + ".json"))
    for i in range(len(cdl)):
        c = nes.code[i]
        cdl[i] |= (1 if c == 1 else 2 if c == 2 else 0) | (4 if nes.data[i] and not c else 0)
    for (bank, base), idx in nes.tables.items():
        k = "%d:%04X" % (bank, base)
        meta["tables"][k] = sorted(set(meta["tables"].get(k, [])) | idx)
    if nes.taint:
        ptrs = {tuple(p[:3]): set(map(tuple, p[3])) for p in meta.get("ptrs", [])}
        for k, v in nes.ptrs.items():
            ptrs.setdefault(k, set()).update(v)
        meta["ptrs"] = sorted([list(k) + [sorted(v)] for k, v in ptrs.items()])
        partial = {tuple(p[:2]): p[2] for p in meta.get("partial", [])}
        for k, v in nes.partial.items():
            partial[k] = partial.get(k, 0) + v
        meta["partial"] = sorted([list(k) + [v] for k, v in partial.items()])
    for (bank, pc), tg in nes.indirect.items():
        k = "%d:%04X" % (bank, pc)
        meta["indirect"][k] = sorted(set(map(tuple, meta["indirect"].get(k, []))) | tg)
    calls = set(map(tuple, meta["calls"])) | nes.calls
    meta["calls"] = sorted(calls)
    open(prefix + ".cdl", "wb").write(cdl)
    json.dump(meta, open(prefix + ".json", "w"))


def main():
    region, prefix = sys.argv[1], sys.argv[2]
    names = sys.argv[3:] or list(SCENARIOS)
    seed = int(os.environ.get("SEED", "1"))
    for name in names:
        rom = open(ROMS[region], "rb").read()
        nes = NES(rom)
        nes.enable_taint()
        rng = random.Random(seed)
        try:
            SCENARIOS[name](nes, rng)
            status = "ok"
        except RuntimeError as e:
            status = str(e)
        merge(prefix, nes)
        for x in getattr(nes, "extra", []):
            merge(prefix, x)
        print("%-12s frames %6d  %s" % (name, nes.frame, status), flush=True)


if __name__ == "__main__":
    main()
