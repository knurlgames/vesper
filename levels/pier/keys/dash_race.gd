extends "res://levels/pier/keys/pier_key.gd"
## Key 1: beat Dash from the gate to the end of the pier (worlds/01_PIER.md). She's at her beach hut. Agree to race and
## she meets Nim at the gate, counts them in, and goes on "two". She cheats: she hops the Midway's west rail, bounds up
## the crates stacked against the staff fence at the Fun Palace's west corner (Pier._west_fence), vaults its capped top
## and runs the walkway behind. Nim can follow her up the crates (owner, Deck review 3: it wasn't clear how Dash got
## over, and Nim could barely manage it), or go over the top: the east walkway's marked wall, the roof, and down off its
## back (or through the fire door, once it's open). Win and Dash claims she let her, and gives her the crop
## (Lessons.CROP). Lose and she'll race again.

## Dash's whole run, start to finish, in seconds: about 5.4 m/s on her feet, plus the hops. A clean run takes Nim about
## 42 s over the roof. Tune on the Deck.
@export var race_secs := 52.0

const HUT := Vector3(64.5, 0.0, 14.6)
const START := Vector3(2.5, 0.0, 5.0)
## Where Nim waits to be counted in: beside Dash at the gate.
const NIM_START := Vector3(-2.5, 0.0, 5.0)
const FINISH_Z := -249.0
## From her hut to the gate, along the promenade behind the beach huts' fronts and the deckchairs.
const TO_GATE := [Vector3(60.0, 0, 16.0), Vector3(10.0, 0, 16.0), Vector3(2.5, 0, 7.5), START]
## Her route from START, leg by leg: [where to, hop]. A hop of 0 is running; otherwise it's a jump, `hop` metres of
## arc over the straight line, taking `secs`, after a crouch: over the Midway's rail, up the two crates, and the vault
## over the fence's cap (Pier.FENCE_TOP, 3 m) down onto the walkway.
const LEGS := [
	[Vector3(4, 0, -100), 0.0], [Vector3(-14, 0, -108.6), 0.0], [Vector3(-15.2, 0, -109.2), 0.0],
	[Vector3(-17.0, 0, -109.6), 1.5, 0.55, 20.0],            # the rail (1.1 m)
	[Vector3(-18.5, 0, -109.5), 0.0],
	[Vector3(-18.5, 1.0, -110.5), 0.6, 0.4, 12.0],           # onto the crate
	[Vector3(-18.5, 2.0, -111.5), 0.6, 0.4, 12.0],           # onto the stack
	[Vector3(-19.0, 0, -113.8), 2.6, 0.8, 65.0],             # the vault: hands down on the cap, over, and down
	[Vector3(-19, 0, -150), 0.0], [Vector3(-12, 0, -160), 0.0], [Vector3(0, 0, -250), 0.0]]
## The fence vault is this leg: she shouts as she crouches for it.
const VAULT_LEG := 7
## The crouch before a hop, and the squash as she lands, in seconds.
const CROUCH := 0.14
const LAND := 0.16

enum Phase { IDLE, TO_START, COUNT, RACE, DONE }

var phase := Phase.IDLE
var dash: Talker
var _t := 0.0
## Seconds into her run, and its whole length (race_secs). The legs' start times, their lengths, her running speed.
var _time := 0.0
var _length := 0.0
var _starts: Array[float] = []
var _speed := 5.4
var _count := 0
## Over her head during the race, seen through walls: where she's got to (owner, on the Deck: "it isn't obvious
## where she goes").
var _marker: Label3D
var _shouted := false


func _setup() -> void:
	# A race left running (saved and quit mid-race, or left the Pier) is over: she offers a rematch. Saved, the flag
	# kept her saying "The gate, Nim" with no race to run (owner, Deck review 4).
	if flag("race_on") or flag("race_go"):
		clear("race_on")
		clear("race_go")
		if not flag("race_won"):
			set_flag("race_lost")
	dash = talker("Dash", "dash", "start", HUT, PI, "dash", "garb", "Dash", Color("e8a030"))
	dash.talked.connect(_on_talked)
	# Her running speed: what's left of race_secs once the hops (and their crouches) are taken out.
	var run := 0.0
	var fixed := 0.0
	var from := START
	for leg: Array in LEGS:
		if float(leg[1]) > 0.0:
			fixed += CROUCH + float(leg[2])
		else:
			run += from.distance_to(leg[0])
		from = leg[0]
	_speed = run / maxf(race_secs - fixed, 1.0)
	_length = 0.0
	from = START
	for leg: Array in LEGS:
		_starts.append(_length)
		_length += _leg_secs(from, leg)
		from = leg[0]
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
	# Two banners back to back: one sided, so from beyond the line it doesn't read backwards ("HSINIF": owner, Deck clip).
	for side: float in [1.0, -1.0]:
		var banner := Label3D.new()
		banner.text = "FINISH"
		banner.font_size = 96
		banner.pixel_size = 0.01
		banner.outline_size = 12
		banner.modulate = Color(2.2, 2.2, 2.2)
		banner.outline_modulate = Look.INK
		banner.shaded = false
		banner.double_sided = false
		banner.position = Vector3(0, 4.0, FINISH_Z + side * 0.02)
		banner.rotation.y = 0.0 if side > 0.0 else PI
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
		var way: Array = [START]
		for leg: Array in LEGS:
			way.append(leg[0])
		way.reverse()
		await dash.walk_path(way if from_finish else TO_GATE, 6.0)
		if is_inside_tree():
			_place_dash(START, 0.0, 0.0, 0.0)


func _physics_process(delta: float) -> void:
	match phase:
		Phase.TO_START:
			# Beside her: her left (NIM_START) or anywhere close to her. Only the marked spot used to count, and
			# a player who walked up to Dash herself was a few metres off it, and she kept saying "The gate, Nim"
			# (owner, Deck clip _20261114_020400).
			if (near(NIM_START, 3.0) or near(START, 4.5)) and not dash.walking:
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
	_time = 0.0
	_shouted = false
	_marker.visible = true


func _run(delta: float) -> void:
	_time += delta
	var pose := _pose_at(_time)
	_place_dash(pose.at, pose.yaw, pose.pitch, pose.squash)
	if dash.model:
		dash.model.speed = _speed
	if not _shouted and _time >= _starts[VAULT_LEG]:
		_shouted = true
		Hud.caption("Dash", "Over the fence! Find your own way round, slowpoke!", 3.0)
	var n := nim()
	if n and n.global_position.z < FINISH_Z and n.global_position.y > -1.0:
		_finish(true)
	elif _time >= _length:
		_finish(false)


func _finish(won: bool) -> void:
	phase = Phase.DONE
	clear("race_on")
	_marker.visible = false
	if won:
		# She's still on her route: she runs the rest of it, then up to Nim (no teleport).
		_place_dash(dash.global_position, dash.rotation.y, 0.0, 0.0)
		var rest: Array = []
		for i in LEGS.size():
			if _starts[i] + _leg_secs(START if i == 0 else LEGS[i - 1][0], LEGS[i]) > _time:
				rest.append(LEGS[i][0])
		rest.append(Vector3(nim().global_position.x + 2.5, 0.0, FINISH_Z - 1.0))
		await dash.walk_path(rest, 8.0)
		if not is_inside_tree():
			return
		dash.rotation.y = PI
		set_flag("race_won")
		await talk("dash", "won")
		Game.set_flag(Lessons.CROP)
		nim().known[Lessons.CROP] = true
		Hud.note("Got: Dash's crop. Hold X to crack it at bells, switches and targets out of reach. In the suit, X is always the crop.", 6.0)
		var p := nim().global_position
		award(&"pier_01", Vector3(p.x, 0.0, p.z - 1.5))
	else:
		if dash.model:
			dash.model.speed = 0.0
		set_flag("race_lost")
		Hud.caption("Dash", "And the winner, still, forever: Dash! Find me for a rematch.")
	phase = Phase.IDLE


## How long a leg takes: running at her speed, or a hop's crouch and flight.
func _leg_secs(from: Vector3, leg: Array) -> float:
	if float(leg[1]) > 0.0:
		return CROUCH + float(leg[2])
	return from.distance_to(leg[0]) / _speed


## Where she is `t` seconds into her run, which way she faces, how far she's pitched forward (radians), and how
## squashed she is (0..1: crouching to jump, or landing).
func _pose_at(t: float) -> Dictionary:
	var from := START
	for i in LEGS.size():
		var leg: Array = LEGS[i]
		var to: Vector3 = leg[0]
		var secs := _leg_secs(from, leg)
		var u := t - _starts[i]
		if u <= secs or i == LEGS.size() - 1:
			var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
			var yaw := atan2(-flat.x, -flat.z)
			var hop := float(leg[1])
			if hop <= 0.0:
				var k := clampf(u / maxf(secs, 0.001), 0.0, 1.0)
				# Landing: a squash as she comes down off the hop before.
				var landed := i > 0 and float(LEGS[i - 1][1]) > 0.0
				var squash := clampf(1.0 - u / LAND, 0.0, 1.0) if landed else 0.0
				return {"at": from.lerp(to, k), "yaw": yaw, "pitch": 0.0, "squash": squash}
			if u < CROUCH:
				# The crouch: down on her haunches, leaning in, before she goes.
				return {"at": from, "yaw": yaw, "pitch": -0.2, "squash": sin(u / CROUCH * PI * 0.5)}
			var f := clampf((u - CROUCH) / float(leg[2]), 0.0, 1.0)
			var at := from.lerp(to, f)
			at.y += 4.0 * hop * f * (1.0 - f)
			# Pitched over the top of the arc (the vault: hands down on the cap, heels over), upright to land.
			return {"at": at, "yaw": yaw, "pitch": -deg_to_rad(float(leg[3])) * sin(f * PI), "squash": 0.0}
		from = to
	return {"at": from, "yaw": 0.0, "pitch": 0.0, "squash": 0.0}


## Placed, turned, pitched forward about her hips (not her feet), and squashed down from the top.
func _place_dash(at: Vector3, yaw: float, pitch := 0.0, squash := 0.0) -> void:
	var hips := Vector3(0, 0.9, 0)
	var b := Basis.from_euler(Vector3(pitch, yaw, 0.0))
	dash.global_position = at + hips - b * hips
	dash.rotation = Vector3(pitch, yaw, 0.0)
	if dash.model:
		dash.model.scale = Vector3(1.0 + 0.07 * squash, 1.0 - 0.18 * squash, 1.0 + 0.07 * squash)
