extends Node3D
## The file select (owner, 2026-11-13: "a fun, interactive screen - perhaps a tour of a mini dungeon where each save is a
## location in that dungeon"; after Banjo-Kazooie's file select in Grunty's lair, and Banjo-Tooie's): the Velvet Rope's
## vaults, a corridor of rooms, a sister in each. Nim walks between them; each room is something to do:
##   The Quiet Room (Lull)     content notes, and the extras
##   The Rope Room (Silke)     save 1
##   The Parlour (Augusta)     save 2
##   The Throne Room (Grizelda) save 3
##   The Workshop (Rivet)      settings
##   The Front Door (Dash)     quit
## Each room's curtain draws back as Nim reaches it, its lamp comes up, and its sister turns to her. The title
## (levels/title/title.gd) runs the input and the cards; this is the set, and `go_to(i)`. Lives in the title's
## SubViewport (its own world).

signal arrived(i: int)

const SPACING := 5.2
const PROP := "res://assets/props/%s.glb"
## [sister, outfit, prop, prop offset, prop yaw, lamp colour, sister offset, sister yaw]
const ROOMS := [
	["lull", "garb", "chaise", Vector3(0.3, 0, -3.2), 0.0, Color("8fb8ff"), Vector3(-0.9, 0, -2.2), 0.3],
	["silke", "suit", "rope_frame", Vector3(0.6, 0, -3.6), 0.0, Color("ff6f91"), Vector3(-0.8, 0, -2.0), 0.4],
	["augusta", "suit", "parlour_armchair", Vector3(0.7, 0, -3.3), -0.4, Color("f2c56a"), Vector3(-0.7, 0, -2.0), 0.3],
	["grizelda", "suit", "club_throne", Vector3(0.0, 0, -3.8), 0.0, Color("c87050"), Vector3(-1.0, 0, -2.2), 0.4],
	["rivet", "suit", "workbench", Vector3(0.5, 0, -3.6), 0.0, Color("9fdc8f"), Vector3(-0.8, 0, -2.0), 0.3],
	["dash", "suit", "punch_bag", Vector3(0.8, 0, -3.4), 0.0, Color("f0b040"), Vector3(-0.8, 0, -2.0), 0.35],
]

var cam: Camera3D
var at := 0
var walking := false
var _nim: CastModel
var _nim_holder: Node3D
var _curtains: Array = []   # [left, right] per room
var _lamps: Array[OmniLight3D] = []
var _sisters: Array[CastModel] = []
var _plaques: Array[Label3D] = []
var _cam_x := 0.0
var _walk_tw: Tween


func _ready() -> void:
	_environment()
	_corridor()
	for i in ROOMS.size():
		_room(i)
	_nim_holder = Node3D.new()
	_nim_holder.position = Vector3(x_of(at), 0.0, 0.4)
	add_child(_nim_holder)
	if CastModel.exists("nim", "garb"):
		_nim = CastModel.new()
		_nim.who = "nim"
		_nim.outfit = "garb"
		_nim_holder.add_child(_nim)
	cam = Camera3D.new()
	cam.fov = 50.0
	add_child(cam)
	cam.make_current()
	_cam_x = x_of(at)
	_place_cam(1.0)
	_open(at, true)


func x_of(i: int) -> float:
	return i * SPACING


## Walk Nim to room `i` (the curtain there opens as she arrives).
func go_to(i: int) -> void:
	i = clampi(i, 0, ROOMS.size() - 1)
	if i == at and not walking:
		return
	_close(at)
	at = i
	walking = true
	if _walk_tw and _walk_tw.is_valid():
		_walk_tw.kill()
	var to := Vector3(x_of(i), 0.0, 0.4)
	var d := to.x - _nim_holder.position.x
	_nim_holder.rotation.y = -PI / 2.0 if d > 0.0 else PI / 2.0   # facing along the corridor
	if _nim:
		_nim.speed = 3.6
	_walk_tw = create_tween()
	_walk_tw.tween_property(_nim_holder, ^"position", to, absf(d) / 3.6)
	await _walk_tw.finished
	if at != i:
		return
	walking = false
	if _nim:
		_nim.speed = 0.0
	var turn := create_tween()
	turn.tween_property(_nim_holder, ^"rotation:y", 0.0, 0.25)   # to the room
	_open(i)
	arrived.emit(i)


## Snap there (the title's first frame, the probes).
func jump_to(i: int) -> void:
	_close(at)
	at = clampi(i, 0, ROOMS.size() - 1)
	walking = false
	_nim_holder.position = Vector3(x_of(at), 0.0, 0.4)
	_nim_holder.rotation.y = 0.0
	_cam_x = x_of(at)
	_place_cam(1.0)
	_open(at, true)


func _process(delta: float) -> void:
	_cam_x = lerpf(_cam_x, _nim_holder.position.x, clampf(delta * 3.0, 0.0, 1.0))
	_place_cam(delta)


func _place_cam(_delta: float) -> void:
	cam.global_position = Vector3(_cam_x, 2.2, 6.4)
	cam.look_at(Vector3(_cam_x, 1.55, -2.2), Vector3.UP)


# --- the set ---------------------------------------------------------------------------------------------------------

func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0c0812")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("3a2a48")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_hdr_threshold = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color("1a1024")
	env.fog_density = 0.02
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _box(p: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = mat
	m.position = p
	add_child(m)
	return m


func _corridor() -> void:
	var length := SPACING * ROOMS.size() + 8.0
	var mid := SPACING * (ROOMS.size() - 1) / 2.0
	var flags := Look.painted(Look.Pattern.FLAGSTONES, Color("4a3e4e"), Color("16101a"), {"wet": 0.3})
	var brick := Look.painted(Look.Pattern.BRICK, Color("5a2e34"), Color("1a0e12"), {"wet": 0.2})
	_box(Vector3(mid, -0.1, -1.0), Vector3(length, 0.2, 12.0), flags)
	# The back wall, between the rooms' arches; a runner of red carpet down the corridor.
	for i in ROOMS.size() + 1:
		var x := x_of(i) - SPACING / 2.0
		_box(Vector3(x, 2.2, -1.6), Vector3(SPACING - 3.4, 4.4, 0.4), brick)
	_box(Vector3(mid, 4.6, -1.6), Vector3(length, 0.6, 0.4), brick)
	_box(Vector3(mid, 0.005, 0.4), Vector3(length, 0.01, 1.4), Look.toon(Color("7a1a30")))
	# Sconces between the arches.
	for i in ROOMS.size() + 1:
		var x := x_of(i) - SPACING / 2.0
		var s := _box(Vector3(x, 2.6, -1.35), Vector3(0.18, 0.3, 0.12), _unlit(Color(2.2, 1.5, 0.8)))
		s.name = "Sconce_%d" % i
		var l := OmniLight3D.new()
		l.light_color = Color("ffb870")
		l.light_energy = 1.1
		l.omni_range = 4.0
		l.position = Vector3(x, 2.6, -0.9)
		add_child(l)


func _unlit(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	return m


## A room off the corridor: its alcove, its prop, its sister, its lamp, its curtain, its plaque.
func _room(i: int) -> void:
	var r: Array = ROOMS[i]
	var x := x_of(i)
	var wall := Look.painted(Look.Pattern.PLASTER, Color("3a2030"), Color("120810"), {"wet": 0.0})
	_box(Vector3(x, 2.2, -5.6), Vector3(3.4, 4.4, 0.3), wall)
	for s: float in [-1.0, 1.0]:
		_box(Vector3(x + s * 1.75, 2.2, -3.6), Vector3(0.2, 4.4, 4.0), wall)
	_box(Vector3(x, 0.01, -3.6), Vector3(3.3, 0.02, 4.0), Look.toon(Color("2a1620")))
	if ResourceLoader.exists(PROP % r[2]):
		var p: Node3D = (load(PROP % r[2]) as PackedScene).instantiate()
		p.position = Vector3(x, 0, 0) + (r[3] as Vector3)
		p.rotation.y = r[4]
		add_child(p)
	var holder := Node3D.new()
	holder.position = Vector3(x, 0, 0) + (r[6] as Vector3)
	holder.rotation.y = PI - float(r[7])   # facing out of her room (+Z), a little toward the middle
	add_child(holder)
	var m: CastModel = null
	if CastModel.exists(r[0], r[1]):
		m = CastModel.new()
		m.who = r[0]
		m.outfit = r[1]
		holder.add_child(m)
	_sisters.append(m)
	var lamp := OmniLight3D.new()
	lamp.light_color = r[5]
	lamp.light_energy = 0.0
	lamp.omni_range = 6.0
	lamp.position = Vector3(x, 3.0, -3.0)
	add_child(lamp)
	_lamps.append(lamp)
	# The curtain: two halves of deep velvet across the arch, under a dark valance with a gold edge.
	var velvet := Look.toon(Color("3a0818"), 0.35, 0.25)
	var left := _box(Vector3(x - 0.8, 1.8, -1.4), Vector3(1.6, 3.6, 0.08), velvet)
	var right := _box(Vector3(x + 0.8, 1.8, -1.4), Vector3(1.6, 3.6, 0.08), velvet)
	_curtains.append([left, right])
	_box(Vector3(x, 3.85, -1.36), Vector3(3.5, 0.62, 0.14), Look.toon(Color("1e0a14")))
	_box(Vector3(x, 3.52, -1.33), Vector3(3.5, 0.05, 0.16), Look.toon(UiKit.GOLD_DEEP, 0.6))
	# The plaque on the valance (the title names the room).
	var plaque := Label3D.new()
	plaque.font = UiKit.display()
	plaque.font_size = 56
	plaque.pixel_size = 0.0055
	plaque.modulate = Color(UiKit.GOLD, 0.0)
	plaque.outline_size = 10
	plaque.outline_modulate = UiKit.INK
	plaque.position = Vector3(x, 3.86, -1.27)
	add_child(plaque)
	_plaques.append(plaque)


## The room's name on its plaque (the title sets it: "Save 1" and so on).
func set_plaque(i: int, text: String) -> void:
	if i >= 0 and i < _plaques.size():
		_plaques[i].text = text


func _open(i: int, now := false) -> void:
	var secs := 0.01 if now else 0.5
	var c: Array = _curtains[i]
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	tw.tween_property(c[0], ^"position:x", x_of(i) - 1.55, secs)
	tw.tween_property(c[0], ^"scale:x", 0.25, secs)
	tw.tween_property(c[1], ^"position:x", x_of(i) + 1.55, secs)
	tw.tween_property(c[1], ^"scale:x", 0.25, secs)
	tw.tween_property(_lamps[i], ^"light_energy", 2.6, secs)
	tw.tween_property(_plaques[i], ^"modulate:a", 1.0, secs)
	var m := _sisters[i]
	if m:
		m.demo_talk = true
		# (A method, not a lambda: leaving the vaults within the 1.6 s frees it, and the connection with it.)
		get_tree().create_timer(1.6).timeout.connect(_hush.bind(i))


func _hush(i: int) -> void:
	var m := _sisters[i]
	if is_instance_valid(m):
		m.demo_talk = false


func _close(i: int) -> void:
	var c: Array = _curtains[i]
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	tw.tween_property(c[0], ^"position:x", x_of(i) - 0.8, 0.4)
	tw.tween_property(c[0], ^"scale:x", 1.0, 0.4)
	tw.tween_property(c[1], ^"position:x", x_of(i) + 0.8, 0.4)
	tw.tween_property(c[1], ^"scale:x", 1.0, 0.4)
	tw.tween_property(_lamps[i], ^"light_energy", 0.0, 0.4)
	tw.tween_property(_plaques[i], ^"modulate:a", 0.25, 0.4)
