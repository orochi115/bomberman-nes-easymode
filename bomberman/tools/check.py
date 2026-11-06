#!/usr/bin/env python3
"""Build both variants in temporary directories and compare complete ROMs.

Reference commits are deliberately fixed: updating a branch must not silently
change the bytes this check accepts. No generated files in the checkout are used.
"""
import argparse
import io
import itertools
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile

GAME = Path(__file__).resolve().parent.parent
REPO = GAME.parent
ORIGINAL = "08c1dd3c04e9f08385f8f31e0e3f91cf2ec6f5f6"
MODIFIED = "000c623052804d9d81522809b3834232b5396b71"


def run(args, cwd, env):
    result = subprocess.run(args, cwd=cwd, env=env, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if result.returncode:
        raise RuntimeError(f"{' '.join(map(str, args))} failed:\n{result.stdout}")
    return result.stdout


def archive(revision, dest):
    data = subprocess.check_output(["git", "archive", revision], cwd=REPO)
    with tarfile.open(fileobj=io.BytesIO(data)) as source:
        for member in source:
            if member.isfile():
                target = dest / member.name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(source.extractfile(member).read())
                target.chmod(member.mode)


def compare(actual, expected, scenario):
    if actual != expected:
        offset = next((i for i, (a, b) in enumerate(zip(actual, expected))
                       if a != b), min(len(actual), len(expected)))
        raise RuntimeError(f"MISMATCH: {scenario}; first difference at file offset "
                           f"0x{offset:X}; lengths {len(actual)} / {len(expected)}")
    print(f"OK: {scenario} ({len(actual)} bytes)")


def rom_name(region):
    return "bomberman_jp" if region == "jp" else "bomberman"


def original_reference(dest, region, header, env):
    assembler = env["BEEBASM"]
    run([assembler, "-D", f"NES2={int(header == 2)}", "-i", "nes_header.asm"], dest, env)
    defs = ["-D", "REGION_JP"] if region == "jp" else []
    run([assembler, *defs, "-i", "bman.asm"], dest, env)
    chr_name = "bomber_jp.chr" if region == "jp" else "bomber.chr"
    return ((dest / "nes_header.bin").read_bytes()
            + (dest / rom_name(region)).read_bytes() + (dest / chr_name).read_bytes())


def build_mod(dest, region, lang, config, header, env):
    run(["./build.sh", "-r", region, "-l", lang, "-c", f"config/{config}.asm",
         "-H", str(header)], dest, env)
    return (dest / (rom_name(region) + ".nes")).read_bytes()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline-dir", type=Path,
                        help="use the 20 saved baseline ROMs instead of rebuilding the fixed commits")
    args = parser.parse_args()
    candidate = os.environ.get("BEEBASM") or str(REPO.parent / "beebasm/beebasm")
    assembler = shutil.which(candidate) or shutil.which("beebasm")
    if not assembler:
        raise RuntimeError("BeebAsm not found; set BEEBASM=/path/to/beebasm")
    env = dict(os.environ, BEEBASM=str(Path(assembler).resolve()))
    with tempfile.TemporaryDirectory(prefix="bm1-check-") as temp:
        temp = Path(temp)
        current = temp / "current"
        current.mkdir()
        # Copy source from the checkout, including uncommitted tracked edits,
        # but never stale generated output or unrelated untracked files.
        # The historical commits are flat. The checkout keeps this game under bomberman/.
        files = subprocess.check_output(["git", "ls-files", "-z", "--", "bomberman"], cwd=REPO).decode().split("\0")
        prefix = "bomberman/"
        for name in filter(None, files):
            if not name.startswith(prefix):
                continue
            source = REPO / name
            if source.is_file():
                target = current / name[len(prefix):]
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, target)
        if not args.baseline_dir:
            archive(ORIGINAL, temp / "original")
            archive(MODIFIED, temp / "mod")

        originals = {}
        for region, header in itertools.product(("us", "jp"), (1, 2)):
            scenario = f"original-{region}-H{header}"
            expected = ((args.baseline_dir / (scenario + ".nes")).read_bytes()
                        if args.baseline_dir else
                        original_reference(temp / "original", region, header, env))
            originals[region, header] = expected
            run(["./make.sh", ".", region, str(header)], current, env)
            compare((current / (rom_name(region) + ".nes")).read_bytes(), expected, scenario)

        # Default script invocation must retain the original iNES 1.0 default.
        run(["./make.sh"], current, env)
        compare((current / "bomberman.nes").read_bytes(), originals["us", 1], "make.sh defaults")
        # Direct original assembly must not need any generated mod files.
        for region in ("us", "jp"):
            defs = ["-D", "REGION_JP"] if region == "jp" else []
            for mod in ([], ["-D", "MOD=0"]):
                run([env["BEEBASM"], *defs, *mod, "-i", "bman.asm"], current, env)
                compare((current / rom_name(region)).read_bytes(),
                        originals[region, 1][16:16 + 16384],
                        f"{region} direct assembly {'MOD=0' if mod else 'MOD omitted'}")

        for region, lang, config, header in itertools.product(
                ("us", "jp"), ("en", "zh"), ("default", "casual"), (1, 2)):
            scenario = f"mod-{region}-{lang}-{config}-H{header}"
            expected = ((args.baseline_dir / (scenario + ".nes")).read_bytes()
                        if args.baseline_dir else
                        build_mod(temp / "mod", region, lang, config, header, env))
            compare(build_mod(current, region, lang, config, header, env), expected, scenario)

        run(["./build.sh"], current, env)
        scenario = "mod-us-en-default-H2.nes"
        expected = ((args.baseline_dir / scenario).read_bytes() if args.baseline_dir else
                    build_mod(temp / "mod", "us", "en", "default", 2, env))
        compare((current / "bomberman.nes").read_bytes(), expected, "build.sh defaults")
        for region in ("us", "jp"):
            run(["./make.sh", ".", region, "2"], current, env)
            compare((current / (rom_name(region) + ".nes")).read_bytes(),
                    originals[region, 2], f"{region} original after mod builds")
    print("CHECK PASSED: all 20 ROM variants, defaults and build switching are byte-identical")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, subprocess.CalledProcessError) as error:
        raise SystemExit(str(error))
