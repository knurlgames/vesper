"""The texture budget (build size; owner, 2026-11-13: "do the build size pass"). Sets each texture's import size
limit under assets/, then a re-import applies it:

  - Normal, metallic and roughness maps: 32 px. Nothing in the game reads them: every model is dressed in the toon
    shader with its colour map only (Look.toon). They stay because the GLBs' own materials point at them.
  - Colour maps: 2048 px for the cast and Nim, 1024 for enemies, clients and props. The Deck's screen is 1280 x 800;
    4K maps cost 16 MB each in the build and showed nothing
    more, even in the club's close scenes.
  - Everything GPU-compressed (VRAM, S3TC on the Deck) rather than lossless.

  python tools/texture_budget.py [--check]      (--check lists what would change and exits 1 if anything would)
  then: godot --headless --path . --editor --quit   (re-imports)
"""
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
UNUSED = re.compile(r"normal|metallic|roughness", re.I)
COLOUR_LIMIT = 2048
UNUSED_LIMIT = 32


## Enemies, clients and props are never seen as close as the cast (the club's scenes frame the cast and Nim): 1K.
FAR_LIMIT = 1024


def limit_for(path: str) -> int:
    name = os.path.basename(path)
    if UNUSED.search(name):
        return UNUSED_LIMIT
    parts = path.replace("\\", "/").split("/")
    return FAR_LIMIT if ("enemies" in parts or "props" in parts) else COLOUR_LIMIT


def main() -> int:
    check = "--check" in sys.argv
    changed = []
    for base, _dirs, files in os.walk(os.path.join(ROOT, "assets")):
        for f in files:
            if not f.endswith(".png.import"):
                continue
            path = os.path.join(base, f)
            with open(path, encoding="utf-8") as fh:
                text = fh.read()
            want = "process/size_limit=%d" % limit_for(path)
            new = re.sub(r"process/size_limit=\d+", want, text)
            # GPU-compressed (S3TC on the Deck), not lossless: smaller in the build and in the Deck's memory. (Tried
            # for Nim: full size and lossless looked the same up close; Deck review 5's "cracks" were the camera
            # pressed into her, not the textures.)
            new = re.sub(r"compress/mode=\d+", "compress/mode=2", new)
            if new != text:
                changed.append(os.path.relpath(path, ROOT))
                if not check:
                    with open(path, "w", encoding="utf-8", newline="\n") as fh:
                        fh.write(new)
    print("%s %d texture imports" % ("would change" if check else "changed", len(changed)))
    for c in changed[:10]:
        print("  ", c)
    return 1 if check and changed else 0


if __name__ == "__main__":
    sys.exit(main())
