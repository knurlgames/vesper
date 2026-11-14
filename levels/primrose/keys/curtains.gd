extends "res://levels/primrose/keys/primrose_key.gd"
## The curtain twitchers (worlds/02_PRIMROSE_CLOSE.md "Enemies"): every lit net curtain is a pair of eyes. Garb gets
## spotted, the suit doesn't. A window that sees her in her garb (the usual sight rules: the dark and crouching keep
## her hidden, so it's the lit gardens and lawns that give her away) for a moment twitches: "!" at the window, and
## someone rings round, and the bulldogs nearest come to look where she was. Then the street's quiet for a while.

## How far a window sees (in the light; less in the dark, like any watcher), and how wide.
const RANGE := 9.0
const HALF_ANGLE := deg_to_rad(55.0)
## Seen this long, it twitches.
const NOTICE := 0.7
## Then nothing twitches for this long.
const QUIET := 9.0
## The bulldogs this near where she was come to look.
const RING_ROUND := 28.0
## Checks a second (a window's ray is cheap, but there are dozens of them).
const RATE := 8.0

var _seen_t := 0.0
var _quiet := 0.0
var _tick := 0.0
var twitches := 0


func _physics_process(delta: float) -> void:
	_quiet -= delta
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 1.0 / RATE
	var n := nim()
	if n == null or Dialogue.is_active() or in_suit() or _quiet > 0.0:
		_seen_t = 0.0
		return
	var at := _watching(n)
	if at == Vector3.INF:
		_seen_t = maxf(_seen_t - 1.0 / RATE, 0.0)
		return
	_seen_t += 1.0 / RATE
	if _seen_t >= NOTICE:
		_twitch(at, n.global_position)


## A lit window that can see her just now, or INF.
func _watching(n: Nim) -> Vector3:
	var space := get_world_3d().direct_space_state
	var p := n.global_position
	for c: Array in level.get(&"curtains"):
		var at: Vector3 = c[0]
		var out: Vector3 = c[1]
		if absf(at.x - p.x) > RANGE or absf(at.z - p.z) > RANGE:
			continue
		var eye := at + out * 0.25
		if (p - eye).dot(out) <= 0.0:
			continue
		if Sight.sees(eye, out, n, RANGE, HALF_ANGLE, 0.0, space):
			return at
	return Vector3.INF


func _twitch(window: Vector3, where: Vector3) -> void:
	_seen_t = 0.0
	_quiet = QUIET
	twitches += 1
	var mark := Label3D.new()
	mark.text = "!"
	mark.font_size = 96
	mark.pixel_size = 0.01
	mark.modulate = Color("f0b040")
	mark.outline_size = 12
	mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mark.no_depth_test = true
	add_child(mark)
	mark.global_position = window + Vector3.UP * 0.9
	get_tree().create_timer(1.6).timeout.connect(mark.queue_free)
	Hud.caption("", "A net curtain twitches. Somewhere, a telephone rings.", 2.4)
	for e: Node in get_tree().get_nodes_in_group(&"enemy"):
		var g := e as Enemy
		if g and not g.is_bound() and g.global_position.distance_to(where) <= RING_ROUND:
			g.hear(where)
			g.hear(where)   # twice: not a "what was that", a phone call; he goes to look
