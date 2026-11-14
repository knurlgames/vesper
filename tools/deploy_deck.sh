#!/usr/bin/env bash
# Exports the "Linux / Steam Deck" preset as Vesper.x86_64 and copies it to a Steam Deck over SSH ("push it").
# Ported from Nine Lives' 3d/tools/deploy_deck.sh. Add the game to Steam once by hand (Desktop Mode, right-click >
# Add to Steam); later copies replace it in place.
#
#   tools/deploy_deck.sh              export, then copy
#   tools/deploy_deck.sh --no-export  copy the build that's already in build/linux
#
# Settings (environment variables):
#   DECK_HOST  ssh target          (default deck@steamdeck; use deck@<ip> if the name doesn't resolve)
#   DECK_DIR   folder on the Deck  (default Games/Vesper, under the deck user's home)
#   GODOT      Godot binary        (default the 4.7.1 console build)
set -euo pipefail

DECK_HOST="${DECK_HOST:-deck@steamdeck}"
DECK_DIR="${DECK_DIR:-Games/Vesper}"
GODOT="${GODOT:-C:/dev/tools/godot/Godot_v4.7.1-stable_mono_win64_console.exe}"
PRESET="Linux / Steam Deck"
NAME="Vesper.x86_64"

cd "$(dirname "$0")/.."
BUILD="build/linux/$NAME"

EXPORT=1
for arg in "$@"; do
	case "$arg" in
		--no-export) EXPORT=0 ;;
		*) echo "Unknown option: $arg" >&2; exit 2 ;;
	esac
done

if (( EXPORT )); then
	echo "Exporting \"$PRESET\"..."
	mkdir -p build/linux
	LOG="build/linux/export.log"
	"$GODOT" --headless --path . --export-release "$PRESET" "$BUILD" > "$LOG" 2>&1 || true
	if grep -qE "SCRIPT ERROR|Parse Error|ERROR: Cannot export" "$LOG" || [[ ! -s "$BUILD" ]]; then
		cat "$LOG"
		echo "Export failed (log: $LOG)." >&2
		exit 1
	fi
fi
[[ -s "$BUILD" ]] || { echo "No build at $BUILD; run without --no-export." >&2; exit 1; }
# One connection: stream to a temp name, mark it executable, then swap it in so a dropped copy never leaves a half-written game.
echo "Copying $(du -h "$BUILD" | cut -f1) to $DECK_HOST:~/$DECK_DIR/$NAME..."
ssh "$DECK_HOST" "mkdir -p ~/'$DECK_DIR' && cat > ~/'$DECK_DIR/$NAME.part' && chmod +x ~/'$DECK_DIR/$NAME.part' && mv -f ~/'$DECK_DIR/$NAME.part' ~/'$DECK_DIR/$NAME'" < "$BUILD"
echo "Done. On the Deck: ~/$DECK_DIR/$NAME"
# Smoke test: start it headless on the Deck through the title (which loads Nim's model) and fail on any load error.
# 2026-11-13: an export filter left out a texture Nim's rebuilt model needs, and the game crashed on launch.
echo "Smoke test on the Deck (headless, 900 frames)..."
SMOKE=$(ssh "$DECK_HOST" "cd ~/'$DECK_DIR' && timeout 90 ./'$NAME' --headless --quit-after 900 2>&1" || true)
if grep -qE "ERROR|SCRIPT ERROR|Failed loading" <<< "$SMOKE"; then
	grep -E "ERROR|SCRIPT ERROR|Failed loading" <<< "$SMOKE" | head -20
	echo "Smoke test FAILED: the build on the Deck logs errors at startup." >&2
	exit 1
fi
echo "Smoke test passed: it starts cleanly."
