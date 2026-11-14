#!/usr/bin/env bash
# Puts the game's art on the Steam Deck (marketing/deck, from tools/store_art.gd): the library's portrait, wide tile,
# hero banner, logo and icon for the non-Steam shortcut to Vesper.x86_64. Steam names a shortcut's grid images by its
# app id, so this reads the id from the Deck's shortcuts.vdf (the entry whose exe is the game), then copies each image
# into userdata/<user>/config/grid as <id>p.png, <id>.png, <id>_hero.png, <id>_logo.png and <id>_icon.png.
# Restart Steam on the Deck (or switch to Game Mode) to see them.
#
#   tools/deck_art.sh
#
# Settings: DECK_HOST (default deck@steamdeck), DECK_EXE (default Vesper.x86_64).
set -euo pipefail

DECK_HOST="${DECK_HOST:-deck@steamdeck}"
DECK_EXE="${DECK_EXE:-Vesper.x86_64}"
cd "$(dirname "$0")/.."
ART="marketing/deck"
for f in portrait wide hero logo icon; do
	[ -f "$ART/$f.png" ] || { echo "Missing $ART/$f.png: run tools/store_art.gd first." >&2; exit 1; }
done

# On the Deck: every user's shortcuts.vdf, the shortcut for the game, its app id and that user's grid folder.
FOUND=$(ssh "$DECK_HOST" "python3 - '$DECK_EXE'" <<'PY'
import glob, os, struct, sys
exe = sys.argv[1]
for vdf in glob.glob(os.path.expanduser("~/.local/share/Steam/userdata/*/config/shortcuts.vdf")):
    data = open(vdf, "rb").read()
    i = 0
    while True:
        j = data.find(b"\x02appid\x00", i)
        if j < 0:
            break
        appid = struct.unpack("<I", data[j + 7:j + 11])[0]
        k = data.find(b"\x00", data.find(b"xe\x00", j) + 3)   # the "Exe" (or "exe") string's end
        start = data.find(b"xe\x00", j) + 3
        target = data[start:k].decode("utf-8", "replace")
        if exe in target:
            print(appid, os.path.join(os.path.dirname(vdf), "grid"))
            sys.exit(0)
        i = j + 1
sys.exit(1)
PY
) || { echo "No shortcut to $DECK_EXE on the Deck: add it to Steam once (Desktop Mode, Add a Non-Steam Game)." >&2; exit 1; }

APPID=$(echo "$FOUND" | cut -d' ' -f1)
GRID=$(echo "$FOUND" | cut -d' ' -f2-)
echo "Shortcut app id $APPID; grid folder $GRID"
ssh "$DECK_HOST" "mkdir -p '$GRID'"
scp -q "$ART/portrait.png" "$DECK_HOST:$GRID/${APPID}p.png"
scp -q "$ART/wide.png" "$DECK_HOST:$GRID/${APPID}.png"
scp -q "$ART/hero.png" "$DECK_HOST:$GRID/${APPID}_hero.png"
scp -q "$ART/logo.png" "$DECK_HOST:$GRID/${APPID}_logo.png"
scp -q "$ART/icon.png" "$DECK_HOST:$GRID/${APPID}_icon.png"
echo "Done. Restart Steam on the Deck to see the art."
