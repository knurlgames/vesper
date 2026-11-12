class_name Lessons
extends RefCounted
## Every lesson Vesper teaches and every piece of gear the sisters give (DESIGN.md, WO-007), by the Game flag that
## unlocks it. Nim's `known` set is filled from these flags by the level (Level.spawn_player); the test course unlocks
## them all.

## Vesper's lessons, one per world 1 to 4.
const TAKEDOWN_ABOVE := "lesson_takedown_above"
const FETCH_OPEN := "lesson_fetch_open"
const CEILING := "lesson_ceiling"
const HOLD_ROOM := "lesson_hold_room"

## The sisters' gear, one per world 1 to 6.
const CROP := "gear_crop"
const SCOLD := "gear_scold"
const ROPE := "gear_rope"
const PENDANT := "gear_pendant"
const LURE := "gear_lure"
const SIGNET := "gear_signet"

const LESSONS := [TAKEDOWN_ABOVE, FETCH_OPEN, CEILING, HOLD_ROOM]
const GEAR := [CROP, SCOLD, ROPE, PENDANT, LURE, SIGNET]
const ALL := LESSONS + GEAR

## What the HUD calls them.
const NAMES := {
	TAKEDOWN_ABOVE: "Takedown from above", FETCH_OPEN: "Commands: Fetch and Open",
	CEILING: "Ceiling crawl and headfirst descent", HOLD_ROOM: "Hold the Room",
	CROP: "the crop", SCOLD: "the Scold", ROPE: "the rope", PENDANT: "the pendant", LURE: "lures", SIGNET: "the signet",
}
## The gear LB uses, in the order D-pad left cycles through it (the crop is on X, the rope on RB, the signet is always on).
const LB_GEAR := [SCOLD, PENDANT, LURE]
