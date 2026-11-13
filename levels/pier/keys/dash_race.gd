extends "res://levels/pier/keys/pier_key.gd"
## Key 1: beat Dash from the gate to the end of the pier (worlds/01_PIER.md). She's at her beach hut. Agree to race and
## she meets Nim at the gate, counts them in, and goes on "two". She cheats: she vaults the 4 m fence at the Fun Palace's
## west corner and runs the walkway Nim can't get onto. Nim has to go over the top: the east walkway's marked wall, the
## roof, and down off its back (or through the fire door, once it's open). Win and Dash claims she let her, and gives
## her the crop (Lessons.CROP). Lose and she'll race again.

## Dash's whole run, start to finish, in seconds: about 5.4 m/s over her route. A clean run takes Nim about 42 s. Tune on the Deck.
@export var race_secs := 52.0

const HUT := Vector3(64.5, 0.0, 14.6)
const START := Vector3(2.5, 0.0, 5.0)
## Where Nim waits to be counted in: beside Dash at the gate.
const NIM_START := Vector3(-2.5, 0.0, 5.0)
const FINISH_Z := -249.0
## From her hut to the gate, along the promenade behind the beach huts' fronts and the deckchairs.
const TO_GATE := [Vector3(60.0, 0, 16.0), Vector3(10.0, 0, 16.0), Vector3(2.5, 0, 7.5), START]
## How far along her route the fence vault is (ROUTE's point 6, the top of the fence): she shouts as she goes over.
const VAULT_AT := 6
## Her route; the y bumps are the vaults (the Midway's rail, then the fence).
const ROUTE := [Vector3(2.5, 0, 5), Vector3(4, 0, -100), Vector3(-14, 0, -108.5), Vector3(-15.5, 1.3, -109.6),
	Vector3(-17.5, 0, -110.6), Vector3(-19, 0, -111.2), Vector3(-19, 4.4, -112.3), Vector3(-19, 0, -113.6),
	Vector3(-19, 0, -150), Vector3(-12, 0, -160), Vector3(0, 0, -250)]

enum Phase { IDLE, TO_START, COUNT, RACE, DONE }

var phase := Phase.IDLE
var dash: Talker
var _t := 0.0
var _along := 0.0
var _length := 0.0
var _count := 0
## Over her head during the race, seen through walls: where she's got to (owner, on the Deck: "it isn't obvious
## where she goes").
var _marker: Label3D
var _shouted := false
var _vault_along := 0.0


func _setup() -> void:
	dash = talker("Dash", "dash", "start", HUT, PI, "dash", "garb", "Dash", Color("e8a030"))
	dash.talked.connect(_on_talked)
	for i in ROUTE.size() - 1:
		if i == VAULT_AT - 1:
			_vault_along = _length
		_length += (ROUTE[i] as Vector3).distance_to(ROUTE[i + 1])
	_marker = Label3D.new()
	_marker.text = "DASH\n▼"
	_marker.font_size = 40
	_marker.pixel_size = 0.0012   # with fixed_size: the same size on screen at any distance
	_marker.outline_size = 10
	_marker.modulate = Color(2.4, 1.4, 0.4)
	_marker.outline_modulate = Look.INK
	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker.no_depth_test = true
	_marker.fixed_size = true
	_marker.position.y = 2.6
	_marker.visible = false
	dash.add_child(_marker)
	# The finish: two posts and a banner across the pier, short of the Prize Hall.
	for x: float in [-24.0, 24.0]:
		pier.call(&"block", Vector3(x, 2.0, FINISH_Z), Vector3(0.3, 4.0, 0.3), Look.toon(Color("e8e0d0")))
	var banner := Label3D.new()
	banner.text = "FINISH"
	banner.font_size = 96
	banner.pixel_size = 0.01
	banner.outline_size = 12
	banner.modulate = Color(2.2, 2.2, 2.2)
	banner.outline_modulate = Look.INK
	banner.shaded = false
	banner.position = Vector3(0, 4.0, FINISH_Z)
	add_child(banner)
	# Her hut's wardrobe is the first (the brief: "Dash is no help with the buttons").
	var n := nim()
	if n:
		n.suit.outfit_changed.connect(_on_changed)


## The first time Nim's in the suit: Dash explains it (the strut, Composure, cover, Kneel), if she's at the hut. If
## Nim changed somewhere else first, the HUD says it in brief. Either way the controls follow as a note.
func _on_changed(_outfit: int) -> void:
	if flag("buttons") or not nim().suit.in_suit():
		return
	set_flag("buttons")
	await get_tree().create_timer(1.2).timeout   # the change itself, first
	if not is_inside_tree():
		return
	if near(HUT, 7.0) and phase == Phase.IDLE:
		await talk("dash", "suit")
	else:
		Hud.note("The Domme suit: walk, don't run. Running, jumping, climbing or fighting where people can see costs Composure; lose it all and your cover's blown.", 7.0)
		await get_tree().create_timer(7.0).timeout
	Hud.note("Strut: push the stick part-way, or hold %s. Commands: %s picks someone, %s the word, %s says it." % [
		Controls.glyph(&"crouch"), Controls.glyph(&"lock_on"), "the D-pad" if Controls.using_pad else "1-4",
		Controls.glyph(&"interact")], 7.0)


func _on_talked(_which: String) -> void:
	if flag("race_go"):
		clear("race_go")
		set_flag("race_on")
		phase = Phase.TO_START
		Hud.note("Race Dash: meet her at the gate.")
		# She runs there (owner: no teleporting): from her hut along the promenade, or back up the pier from the
		# finish for a rematch.
		var from_finish := dash.global_position.z < -100.0
		var way: Array = ROUTE.duplicate()
		way.reverse()
		await dash.walk_path(way if from_finish else TO_GATE, 6.0)
		if is_inside_tree():
			_place_dash(START, 0.0)


func _physics_process(delta: float) -> void:
	match phase:
		Phase.TO_START:
			if near(NIM_START, 3.0) and not dash.walking:
				phase = Phase.COUNT
				_t = 0.0
				_count = 0
		Phase.COUNT:
			_t += delta
			if _t >= _count:
				_count += 1
				match _count:
					1: Hud.caption("Dash", "Three...")
					2:
						Hud.caption("Dash", "Two-GO!")
						_go()
		Phase.RACE:
			_run(delta)


func _go() -> void:
	phase = Phase.RACE
	_along = 0.0
	_shouted = false
	_marker.visible = true


func _run(delta: float) -> void:
	_along += _length / race_secs * delta
	var p := _at(_along)
	var ahead := _at(_along + 0.5)
	_place_dash(p, atan2(-(ahead.x - p.x), -(ahead.z - p.z)))
	if dash.model:
		dash.model.speed = _length / race_secs
	if not _shouted and _along >= _vault_along:
		_shouted = true
		Hud.caption("Dash", "Over the fence! Find your own way round, slowpoke!", 3.0)
	var n := nim()
	if n and n.global_position.z < FINISH_Z and n.global_position.y > -1.0:
		_finish(true)
	elif _along >= _length:
		_finish(false)


func _finish(won: bool) -> void:
	phase = Phase.DONE
	clear("race_on")
	_marker.visible = false
	if won:
		# She's still on her route: she runs the rest of it, then up to Nim (no teleport).
		var rest: Array = []
		var d := _along + 2.0
		while d < _length:
			rest.append(_at(d))
			d += 6.0
		rest.append(Vector3(nim().global_position.x + 2.5, 0.0, FINISH_Z - 1.0))
		await dash.walk_path(rest, 8.0)
		if not is_inside_tree():
			return
		dash.rotation.y = PI
		set_flag("race_won")
		await talk("dash", "won")
		Game.set_flag(Lessons.CROP)
		nim().known[Lessons.CROP] = true
		Hud.note("Dash's crop: hold X to crack it.")
		var p := nim().global_position
		award(&"pier_01", Vector3(p.x, 0.0, p.z - 1.5))
	else:
		if dash.model:
			dash.model.speed = 0.0
		set_flag("race_lost")
		Hud.caption("Dash", "And the winner, still, forever: Dash! Find me for a rematch.")
	phase = Phase.IDLE


## The point `d` metres along her route.
func _at(d: float) -> Vector3:
	for i in ROUTE.size() - 1:
		var a: Vector3 = ROUTE[i]
		var b: Vector3 = ROUTE[i + 1]
		var seg := a.distance_to(b)
		if d <= seg:
			return a.lerp(b, d / seg)
		d -= seg
	return ROUTE[ROUTE.size() - 1]


func _place_dash(at: Vector3, yaw: float) -> void:
	dash.global_position = at
	dash.rotation.y = yaw
