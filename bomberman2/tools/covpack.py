"""Pack cov/REGION_*.cdl|json (scratch output of cover.py) into the committed
coverage/REGION.cdl|json, so the source can be regenerated from a checkout.

Usage: covpack.py
"""

import glob
import json
import os

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))


def main():
    os.makedirs(os.path.join(ROOT, "coverage"), exist_ok=True)
    for region in ("us", "jp", "eu"):
        files = sorted(glob.glob(os.path.join(ROOT, "cov", region + "_*.cdl")))
        packed = os.path.join(ROOT, "coverage", region)
        if os.path.exists(packed + ".cdl"):
            files.append(packed + ".cdl")
        cdl = bytearray(0x20000)
        meta = {"tables": {}, "indirect": {}, "calls": set(), "ptrs": {}, "partial": {}}
        for f in files:
            for i, v in enumerate(open(f, "rb").read()):
                cdl[i] |= v
            m = json.load(open(f[:-4] + ".json"))
            for k, v in m["tables"].items():
                meta["tables"].setdefault(k, set()).update(v)
            for k, v in m["indirect"].items():
                meta["indirect"].setdefault(k, set()).update(map(tuple, v))
            meta["calls"].update(map(tuple, m["calls"]))
            for lo, hi, kind, vals in m.get("ptrs", []):
                meta["ptrs"].setdefault((lo, hi, kind), set()).update(map(tuple, vals))
            for b, pc, cnt in m.get("partial", []):
                meta["partial"][(b, pc)] = meta["partial"].get((b, pc), 0) + cnt
        out = {
            "tables": {k: sorted(v) for k, v in meta["tables"].items()},
            "indirect": {k: sorted(v) for k, v in meta["indirect"].items()},
            "calls": sorted(meta["calls"]),
            "ptrs": sorted([list(k) + [sorted(v)] for k, v in meta["ptrs"].items()]),
            "partial": sorted([list(k) + [v] for k, v in meta["partial"].items()]),
        }
        open(packed + ".cdl", "wb").write(cdl)
        json.dump(out, open(packed + ".json", "w"), separators=(",", ":"))
        print("%s: %d files -> coverage/%s.cdl/.json" % (region, len(files), region))


if __name__ == "__main__":
    main()
