extends "res://levels/primrose/keys/primrose_key.gd"
## Key 6: the washing lines (worlds/02_PRIMROSE_CLOSE.md). Cross every garden on the west side, end to end, on the
## lines and the fences, and never touch a lawn. It starts when she's up on a fence or the line at the gardens' south
## end, and it's done at the north end. A foot on a lawn on the way: back to the start. The last line holds the
## Coalition chairwoman's corset. Nim doesn't comment. (Garb: the suit doesn't climb.)

## The west gardens: x -24..-46, z -4..-88; the washing line at x -35, 3.7 up.
const AREA := Rect2(-46.5, -88.5, 22.5, 85.0)
const START_Z := -10.0
const END_Z := -82.0
## Up off the lawn: a fence's top is 1.8, the line 3.7.
const UP := 1.4

var running := false


func _setup() -> void:
	# The corset, pegged on the line's last stretch (a cream one, laced: suggestive, and nobody's in it).
	# Just before the end, so she passes it. Its top is just under the wire; the lacing a little shorter (no shared
	# faces); the pegs over both.
	var at := Vector3(-35.0, 3.68 - 0.31, -79.0)
	level.call(&"block", at, Vector3(0.05, 0.62, 0.42), Look.toon(Color("e8d8c8")), self, false)
	level.call(&"block", at, Vector3(0.07, 0.58, 0.06), Look.toon(Color("6a2a3e")), self, false)
	for dz: float in [-0.16, 0.16]:
		level.call(&"block", Vector3(-35.0, 3.69, -79.0 + dz), Vector3(0.06, 0.1, 0.03), Look.toon(Color("8a6a4a")), self, false)


func _physics_process(_delta: float) -> void:
	if has_key(&"primrose_06") or Dialogue.is_active():
		return
	var n := nim()
	if n == null:
		return
	var p := n.global_position
	var inside := AREA.has_point(Vector2(p.x, p.z))
	if not running:
		if inside and p.z > START_Z and p.y > UP and n.is_on_floor() and not in_suit():
			running = true
			Hud.note("The washing lines: to the far end of the gardens without touching a lawn.")
		return
	if not inside and p.z > END_Z:
		running = false   # she left the gardens: it's off, quietly
		return
	if n.is_on_floor() and p.y < 0.5:
		running = false
		Hud.caption("", "A foot on the lawn. Back to the start of the gardens.", 2.5)
		return
	if p.z < END_Z and p.y > UP:
		running = false
		Hud.caption("", "The last line holds the Coalition chairwoman's corset. Nim doesn't comment.", 4.0)
		award(&"primrose_06", p + Vector3(0, 0, -1.0))   # to her, up on the line (on the lawn below, it'd cost a foot down)
