class_name ScuffleCloud
extends Node3D
## The old-cartoon fight cloud (owner, 2026-11-12: "like old-school cartoons, when you bind them, it might be fun to
## have like a rough and tumble of smoke briefly and then they end up bound"). Nim and the goon vanish into a
## churning ball of dust; grawlixes and a star or two pop out of it; it bounces and rolls; then it poofs away and
## he's sat there tied up. NimCombat spawns one when a bind begins, and calls `poof()` when it ends (or is broken
## off); whoever the cloud swallowed is hidden until then (`hide_while`).

## Seconds for the puffs to swell from nothing.
const GROW := 0.12
## The poof at the end: the puffs fly outward and shrink away.
const POOF := 0.28
const PUFFS := 11
const RADIUS := 0.75          # the ball's size: about a crouched Nim and a goon side by side
const CREAM := Color("e9e1cf")
const DUST := Color("bdb4a4")
## What pops out: comic swearing (symbols only), and the odd star.
const GRAWLIX := ["#@!", "%&*!", "@#$%", "!!", "*#!", "$@!!"]
const POP_EVERY := 0.16

var _t := 0.0
var _poof_t := -1.0
var _puffs: Array[MeshInstance3D] = []
var _seeds: Array[Vector4] = []      # per puff: orbit phase, speed, wobble phase, size
var _pop_in := 0.05
var _pops: Array[Label3D] = []
var _hidden: Array[Node3D] = []
var _base := Vector3.ZERO


## Hide these until the cloud poofs (their models: the fight is in the cloud).
func hide_while(nodes: Array) -> void:
	for n: Node3D in nodes:
		if n and n.visible:
			n.visible = false
			_hidden.append(n)


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in PUFFS:
		var m := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radial_segments = 16
		s.rings = 8
		var size := rng.randf_range(0.32, 0.52)
		s.radius = size
		s.height = size * 2.0
		m.mesh = s
		var tint := CREAM.lerp(DUST, rng.randf())
		m.material_override = Look.toon(tint, 0.0, 0.15)
		m.material_overlay = Look.outline(AABB(Vector3(-size, -size, -size), Vector3.ONE * size * 2.0), 0.012)
		m.scale = Vector3.ZERO
		add_child(m)
		_puffs.append(m)
		_seeds.append(Vector4(rng.randf() * TAU, rng.randf_range(4.0, 9.0) * (1 if rng.randf() < 0.5 else -1),
			rng.randf() * TAU, rng.randf_range(0.35, 1.0)))


func _process(delta: float) -> void:
	# Where it sits is read on its first frame, not in _ready: whoever spawns it adds it, then moves it into place.
	# (Read in _ready, the base was the level's origin: the cloud bobbed about there, out of sight, while the fighters
	# vanished where they stood.)
	if _t == 0.0:
		_base = position
	_t += delta
	var grow := clampf(_t / GROW, 0.0, 1.0)
	# An overshoot on the swell, like a cartoon "poomf".
	var swell := 1.0 + 0.25 * sin(clampf(_t / (GROW * 1.6), 0.0, 1.0) * PI) if grow >= 1.0 else grow
	var out := 0.0
	var fade := 1.0
	if _poof_t >= 0.0:
		_poof_t += delta
		var u := clampf(_poof_t / POOF, 0.0, 1.0)
		out = u
		fade = 1.0 - u * u
	# The whole ball bounces and lurches about as the two of them roll around inside it.
	position = _base + Vector3(0.12 * sin(_t * 17.0), 0.10 * absf(sin(_t * 13.0)), 0.12 * sin(_t * 11.0 + 1.3))
	rotation.y = _t * 5.0
	for i in _puffs.size():
		var sd := _seeds[i]
		var ang := sd.x + _t * sd.y
		var tilt := sin(sd.z + _t * 7.0)
		var dir := Vector3(cos(ang), 0.55 * tilt, sin(ang)).normalized()
		var dist := RADIUS * sd.w * (1.0 + 1.6 * out)
		_puffs[i].position = dir * dist + Vector3.UP * (0.75 + 0.15 * sin(sd.z + _t * 9.0))
		var wob := 1.0 + 0.18 * sin(sd.z + _t * 23.0)
		_puffs[i].scale = Vector3.ONE * maxf(swell * wob * fade, 0.0)
	_tick_pops(delta, _poof_t >= 0.0)
	if _poof_t >= POOF:
		queue_free()


## The pops: a grawlix or a star bursts out of the cloud, hangs a moment, and is gone.
func _tick_pops(delta: float, ending: bool) -> void:
	for p in _pops.duplicate():
		var age: float = p.get_meta(&"age") + delta
		p.set_meta(&"age", age)
		p.position += p.get_meta(&"vel") * delta
		p.scale = Vector3.ONE * (minf(age / 0.06, 1.0) * (1.0 - clampf((age - 0.25) / 0.12, 0.0, 1.0)))
		if age > 0.4:
			_pops.erase(p)
			p.queue_free()
	if ending:
		return
	_pop_in -= delta
	if _pop_in > 0.0:
		return
	_pop_in = POP_EVERY
	var p := Label3D.new()
	p.text = "*" if randf() < 0.25 else GRAWLIX[randi() % GRAWLIX.size()]
	p.font_size = 72 if p.text != "*" else 120
	p.pixel_size = 0.005
	p.outline_size = 16
	p.outline_modulate = Look.INK
	p.modulate = Color("ffd84a") if p.text == "*" else Color("fff3e0")
	p.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	p.no_depth_test = true
	var a := randf() * TAU
	var dir := Vector3(cos(a), randf_range(0.2, 0.9), sin(a)).normalized()
	p.position = Vector3.UP * 0.8 + dir * RADIUS * 0.9
	p.set_meta(&"vel", dir * 1.6)
	p.set_meta(&"age", 0.0)
	p.scale = Vector3.ZERO
	add_child(p)
	_pops.append(p)


## The fight's over: burst, and give back whoever was hidden.
func poof() -> void:
	if _poof_t >= 0.0:
		return
	_poof_t = 0.0
	for n in _hidden:
		if is_instance_valid(n):
			n.visible = true
	_hidden.clear()


func _exit_tree() -> void:
	# Never leave anyone invisible (a level change mid-cloud).
	for n in _hidden:
		if is_instance_valid(n):
			n.visible = true
