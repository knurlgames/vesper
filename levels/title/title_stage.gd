extends Node3D
## The title screen's cutscene (owner, 2026-11-13: "a small cutscene that plays in the background with the working title
## 'Vesper's Kinky Kapers' listed and 'Press Any Button'"; after Banjo's band on the title and Conker's throne room: the
## whole cast at home, in character, looping). On the Velvet Claw's roof at night, its neon sign buzzing over the street:
##   - the sisters off duty: Grizelda in a deckchair, Augusta reading, Silke coiling rope, Lull on a chaise under the
##     string lights, Dash stretching, Rivet up a step fixing the sign's wiring;
##   - Vesper at the parapet, watching the city;
##   - and Nim, late, dropping in off the fire escape, landing (mostly) on her feet beside her. Vesper doesn't look round.
## Four shots on a 26-second loop: the sign flickering on from the street; along the roof past the sisters; behind
## Vesper as Nim lands; the two of them at the parapet as the camera pulls back over the city. Built in code like the
## worlds (no assets but the cast and the props). Lives in the title's SubViewport (its own world).

const LOOP := 26.0
const PROP := "res://assets/props/%s.glb"
const VESPER_AT := Vector3(-0.6, 0.0, 5.1)
const NIM_AT := Vector3(0.9, 0.0, 5.0)
const NIM_DROP := 7.5

var cam: Camera3D
var t := 0.0
var _nim: CastModel
var _vesper: CastModel
var _rigs: Array = []      # [RigGear, kind, phase]
var _neon: Array[Label3D] = []
var _neon_light: OmniLight3D
var _landed := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 7
	_environment()
	_roof()
	_city()
	_sign()
	_cast()
	cam = Camera3D.new()
	cam.fov = 52.0
	add_child(cam)
	cam.make_current()
	_rain()
	_shoot(0.0)


# --- the set ---------------------------------------------------------------------------------------------------------

func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("120c24")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("4a3e7a")
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.15
	env.fog_enabled = true
	env.fog_light_color = Color("2a2050")
	env.fog_density = 0.012
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.85
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Look.MOON
	moon.light_energy = 0.55
	moon.shadow_enabled = true
	moon.rotation = Vector3(deg_to_rad(-38), deg_to_rad(150), 0)
	add_child(moon)
	# The moon itself, low over the city.
	var disc := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 4.0
	sm.height = 8.0
	disc.mesh = sm
	disc.material_override = _unlit(Color(2.2, 2.1, 1.8))
	disc.position = Vector3(-30, 26, 90)
	add_child(disc)


func _box(at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = mat
	m.position = at
	add_child(m)
	return m


func _unlit(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	return m


func _prop(prop_name: String, at: Vector3, yaw: float, scale := 1.0) -> Node3D:
	if not ResourceLoader.exists(PROP % prop_name):
		return null
	var p: Node3D = (load(PROP % prop_name) as PackedScene).instantiate()
	p.position = at
	p.rotation.y = yaw
	p.scale = Vector3.ONE * scale
	add_child(p)
	return p


func _light(at: Vector3, c: Color, energy: float, reach: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = energy
	l.omni_range = reach
	l.position = at
	add_child(l)
	return l


## The club's roof: tar, a parapet round it, the water tank, a skylight, chimneys, the fire escape's rail, string lights.
func _roof() -> void:
	# (Damp, not puddled: the puddles threw pink ovals of the neon across the shots.)
	var tar := Look.painted(Look.Pattern.PLASTER, Color("2e2836"), Color("0e0a14"), {"wet": 0.3})
	var brick := Look.painted(Look.Pattern.BRICK, Color("6a3a3c"), Color("1e1014"), {"wet": 0.5})
	var stone := Look.toon(Color("8a7a70"))
	_box(Vector3(0, -0.25, -1.0), Vector3(22.0, 0.5, 16.0), tar)
	# The parapet: front (the street), sides, back.
	_box(Vector3(0, 0.45, 7.1), Vector3(22.0, 0.9, 0.4), brick)
	_box(Vector3(0, 0.95, 7.1), Vector3(22.4, 0.12, 0.6), stone)
	for s: float in [-1.0, 1.0]:
		_box(Vector3(s * 11.0, 0.45, -1.0), Vector3(0.4, 0.9, 16.0), brick)
	_box(Vector3(0, 0.45, -9.1), Vector3(22.0, 0.9, 0.4), brick)
	# The water tank on its legs, back left.
	var tank := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.4
	cyl.bottom_radius = 1.4
	cyl.height = 2.6
	tank.mesh = cyl
	tank.material_override = Look.painted(Look.Pattern.PLANKS, Color("5a4434"), Color("1a120c"), {"wet": 0.4})
	tank.position = Vector3(-8.0, 3.6, -6.5)
	add_child(tank)
	var cone := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.05
	cm.bottom_radius = 1.55
	cm.height = 0.9
	cone.mesh = cm
	cone.material_override = Look.toon(Color("3a3440"))
	cone.position = Vector3(-8.0, 5.35, -6.5)
	add_child(cone)
	for lx: float in [-1.0, 1.0]:
		for lz: float in [-1.0, 1.0]:
			_box(Vector3(-8.0 + lx * 1.0, 1.15, -6.5 + lz * 1.0), Vector3(0.14, 2.3, 0.14), Look.toon(Color("2a2430")))
	# The skylight (glass, lit from the club below), chimneys.
	_box(Vector3(3.5, 0.3, -5.0), Vector3(3.2, 0.6, 2.2), brick)
	_box(Vector3(3.5, 0.66, -5.0), Vector3(3.0, 0.12, 2.0), _unlit(Color(1.6, 0.5, 0.8)))
	for c: Vector3 in [Vector3(9.0, 0, -7.6), Vector3(-10.0, 0, 3.0)]:
		_box(c + Vector3(0, 1.0, 0), Vector3(1.0, 2.0, 1.0), brick)
	# String lights on poles round the lounge: warm bulbs, sagging between.
	var poles := [Vector3(-9.5, 0, -8.2), Vector3(-9.5, 0, 6.2), Vector3(9.5, 0, 6.2), Vector3(9.5, 0, -8.2)]
	for p: Vector3 in poles:
		_box(p + Vector3(0, 1.6, 0), Vector3(0.1, 3.2, 0.1), Look.toon(Look.INK))
	var bulb := _unlit(Color(2.4, 1.7, 0.9))
	for i in poles.size():
		var a: Vector3 = poles[i] + Vector3(0, 3.1, 0)
		var b: Vector3 = poles[(i + 1) % poles.size()] + Vector3(0, 3.1, 0)
		for k in 14:
			var f := (k + 0.5) / 14.0
			var p := a.lerp(b, f) + Vector3.DOWN * 0.7 * 4.0 * f * (1.0 - f)
			var s := MeshInstance3D.new()
			var sp := SphereMesh.new()
			sp.radius = 0.07
			sp.height = 0.14
			s.mesh = sp
			s.material_override = bulb
			s.position = p
			add_child(s)
	_light(Vector3(-4.0, 2.6, -2.0), Color("ffc890"), 1.4, 9.0)
	_light(Vector3(5.0, 2.6, -2.0), Color("ffc890"), 1.2, 9.0)
	_light(Vector3(3.5, 1.4, -5.0), Color("ff70b0"), 1.0, 5.0)
	# The fire escape's top rail at the right-hand front corner, where Nim comes from.
	_box(Vector3(2.4, 1.3, 7.4), Vector3(0.08, 2.6, 0.08), Look.toon(Color("2a2430")))
	# Pot plants, an air vent, a crate of the club's empties.
	_prop("crate", Vector3(7.5, 0.0, 3.0), 0.4)
	_prop("crate", Vector3(8.2, 0.0, 2.2), 1.1)
	_box(Vector3(-5.5, 0.4, -7.6), Vector3(1.6, 0.8, 1.0), Look.toon(Color("6a6a74")))


## The city round it: blocks of flats and offices, their windows lit here and there (one MultiMesh of lit windows).
func _city() -> void:
	var walls := [Look.toon(Color("241e30")), Look.toon(Color("2c2438")), Look.toon(Color("1e1a2a"))]
	var windows := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in 46:
		var a := _rng.randf_range(0.0, TAU)
		var r := _rng.randf_range(26.0, 70.0)
		var at := Vector3(sin(a) * r, 0, cos(a) * r)
		if at.z < 8.0 and absf(at.x) < 18.0:
			continue   # (not where the roof is)
		var w := _rng.randf_range(5.0, 11.0)
		var d := _rng.randf_range(5.0, 11.0)
		var h := _rng.randf_range(8.0, 34.0)
		var block := _box(at + Vector3(0, h / 2.0 - 6.0, 0), Vector3(w, h, d), walls[i % 3])
		block.rotation.y = 0.0
		# Lit windows on the face toward the roof.
		var to := -at.normalized()
		var face := Vector3(signf(to.x), 0, 0) if absf(to.x) > absf(to.z) else Vector3(0, 0, signf(to.z))
		var half := Vector3(w, 0, d) / 2.0
		for row in int(h / 2.4):
			for col in int((d if absf(face.x) > 0.5 else w) / 1.8):
				if _rng.randf() > 0.32:
					continue
				var along := Vector3(0, 0, 1) if absf(face.x) > 0.5 else Vector3(1, 0, 0)
				var off: float = -((d if absf(face.x) > 0.5 else w) / 2.0) + 0.9 + col * 1.8
				var p := at + face * (half.x if absf(face.x) > 0.5 else half.z) * 1.0 + face * 0.05 + along * off \
					+ Vector3(0, -6.0 + 1.4 + row * 2.4, 0)
				windows.append(p)
				normals.append(face)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var quad := QuadMesh.new()
	quad.size = Vector2(0.9, 1.2)
	mm.mesh = quad
	mm.instance_count = windows.size()
	for i in windows.size():
		var n: Vector3 = normals[i]
		var basis := Basis.looking_at(-n, Vector3.UP)
		mm.set_instance_transform(i, Transform3D(basis, windows[i]))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var lit := _unlit(Color(2.0, 1.5, 0.8))
	lit.cull_mode = BaseMaterial3D.CULL_DISABLED
	mmi.material_override = lit
	add_child(mmi)
	# The street far below the front, a glow of lamps.
	_box(Vector3(0, -6.2, 18.0), Vector3(80.0, 0.2, 14.0), Look.toon(Color("1a1420")))
	_light(Vector3(0, -3.0, 16.0), Color("ffb060"), 2.0, 16.0)


## The sign over the street: THE VELVET CLAW in neon, on a frame at the roof's front edge.
func _sign() -> void:
	var frame := Look.toon(Color("2a2430"))
	for x: float in [-4.6, 4.6]:
		_box(Vector3(x, 2.4, 7.25), Vector3(0.14, 3.0, 0.14), frame)
	_box(Vector3(0, 3.9, 7.25), Vector3(9.6, 0.1, 0.1), frame)
	_box(Vector3(0, 2.1, 7.25), Vector3(9.6, 0.1, 0.1), frame)
	# Both faces: the street reads it, and so do we, from the roof (reversed: we see its back).
	for side: float in [1.0, -1.0]:
		var l := Label3D.new()
		l.text = "THE VELVET CLAW"
		l.font = UiKit.display()
		l.font_size = 120
		l.pixel_size = 0.0072
		l.modulate = Color(3.2, 0.7, 1.4)
		l.outline_modulate = Color(0.6, 0.05, 0.2)
		l.outline_size = 22
		l.shaded = false
		l.double_sided = false
		l.position = Vector3(0, 3.0, 7.3 if side > 0.0 else 7.2)
		l.rotation.y = 0.0 if side > 0.0 else PI
		add_child(l)
		_neon.append(l)
	_neon_light = _light(Vector3(0, 3.0, 7.9), Color("ff4f9a"), 3.5, 12.0)


# --- the cast --------------------------------------------------------------------------------------------------------

func _model(who: String, outfit: String, at: Vector3, yaw: float) -> CastModel:
	if not CastModel.exists(who, outfit):
		return null
	var holder := Node3D.new()
	holder.name = who.capitalize()
	holder.position = at
	holder.rotation.y = yaw
	add_child(holder)
	var m := CastModel.new()
	m.who = who
	m.outfit = outfit
	holder.add_child(m)
	return m


## Held still and posed (RigGear), breathing a little every frame (`kind` says how).
func _posed(m: CastModel, kind: String) -> void:
	if m == null:
		return
	await get_tree().process_frame
	await get_tree().process_frame
	m.hold(true)
	var sk := m.skeleton()
	if sk == null:
		return
	var rig := RigGear.new(sk, m.get_parent() as Node3D)
	match kind:
		"sit":
			var drop := rig.pose_sit()
			(m.get_parent() as Node3D).position.y -= drop * 0.86
		"read":
			var f := rig.fwd()
			var book := (rig.pos("chest") + f * 0.32 + Vector3.DOWN * 0.12)
			rig.reach(book, "R")
			rig.reach(book, "L")
			var b := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.2, 0.03, 0.26)
			b.mesh = bm
			b.material_override = Look.toon(Color("6a1a24"))
			rig.wear("handR", b, book + Vector3.UP * 0.02, f)
			rig.turn("head", rig.left(), 0.28)   # eyes down, at the page
		"coil":
			var f := rig.fwd()
			var at := rig.pos("chest") + f * 0.3 + Vector3.DOWN * 0.3
			rig.reach(at + rig.left() * 0.1, "L")
			rig.reach(at - rig.left() * 0.1, "R")
			var coil := MeshInstance3D.new()
			var tor := TorusMesh.new()
			tor.inner_radius = 0.12
			tor.outer_radius = 0.17
			coil.mesh = tor
			coil.material_override = Look.toon(RigGear.ROPE)
			rig.wear("handL", coil, at, f)
		"stretch":
			rig.pose_arms_up()
		"fix":
			rig.reach(Vector3(1.4, 3.0, 7.2), "R")
	rig.capture()
	_rigs.append([rig, kind, _rng.randf_range(0.0, TAU)])


func _cast() -> void:
	# Grizelda in a deckchair; Lull on a chaise under the lights; Augusta reading; Silke with a coil of rope; Dash
	# stretching; Rivet on a crate, at the sign's wiring.
	_prop("deckchair", Vector3(-7.0, 0.0, 0.8), PI * 0.85)
	_posed(_model("grizelda", "garb", Vector3(-7.0, 0.0, 0.7), PI * 0.85), "sit")
	_prop("chaise", Vector3(4.6, 0.0, -2.4), PI * 1.1)
	_posed(_model("lull", "garb", Vector3(4.4, 0.0, -2.3), PI * 1.1), "sit")
	_posed(_model("augusta", "garb", Vector3(-4.4, 0.0, -1.6), PI * 0.9), "read")
	_posed(_model("silke", "garb", Vector3(-2.0, 0.0, 1.2), PI * 1.15), "coil")
	_posed(_model("dash", "garb", Vector3(7.0, 0.0, 0.6), PI * 1.2), "stretch")
	_prop("crate", Vector3(1.6, 0.0, 6.3), 0.0)
	_posed(_model("rivet", "garb", Vector3(1.6, 0.6, 6.3), PI * 0.05), "fix")
	_vesper = _model("vesper", "suit", VESPER_AT, PI)   # facing the city (+Z)
	_nim = _model("nim", "garb", NIM_AT + Vector3(0, NIM_DROP, 0), PI)


func _rain() -> void:
	var p := GPUParticles3D.new()
	p.amount = 900
	p.lifetime = 1.2
	p.visibility_aabb = AABB(Vector3(-14, -14, -14), Vector3(28, 28, 28))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(12, 1, 12)
	pm.direction = Vector3(0.1, -1, 0)
	pm.spread = 2.0
	pm.initial_velocity_min = 14.0
	pm.initial_velocity_max = 18.0
	pm.gravity = Vector3.ZERO
	p.process_material = pm
	var drop := QuadMesh.new()
	drop.size = Vector2(0.015, 0.4)
	var dm := _unlit(Color(0.75, 0.8, 1.0, 0.35))
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	drop.material = dm
	p.draw_pass_1 = drop
	p.position = Vector3(0, 9, 0)
	cam.add_child(p)


# --- the loop --------------------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	t = fmod(t + delta, LOOP)
	_shoot(t)
	_act(t)
	# The off-duty sisters breathe (and Dash sways in her stretch).
	for r: Array in _rigs:
		var rig: RigGear = r[0]
		var ph: float = r[2]
		rig.restore()
		var b := sin(t * 1.6 + ph)
		rig.turn("chest", rig.left(), -0.025 * b)
		if r[1] == "stretch":
			rig.turn("hips", rig.fwd(), 0.12 * sin(t * 0.9 + ph))
		elif r[1] == "fix":
			rig.turn("handR", rig.left(), 0.25 * sin(t * 7.0))   # the screwdriver
	# The neon buzzes: a flicker on start, an occasional stutter.
	var on := 1.0
	if t < 1.2:
		on = 1.0 if fmod(t, 0.23) > 0.11 and t > 0.4 else 0.15
	elif fmod(t, 7.3) < 0.08:
		on = 0.3
	for l in _neon:
		l.modulate = Color(3.2, 0.7, 1.4) * on
	_neon_light.light_energy = 3.5 * on


## The camera, by the clock: four shots, eased.
func _shoot(at: float) -> void:
	var from: Vector3
	var look: Vector3
	if at < 6.0:
		var k := _ease(at / 6.0)
		from = Vector3(-14, 12, 30).lerp(Vector3(-5, 5.5, 17), k)
		look = Vector3(0, 3.0, 7.0)
	elif at < 12.0:
		var k := _ease((at - 6.0) / 6.0)
		from = Vector3(-10.5, 1.8, -6.0).lerp(Vector3(8.5, 1.8, -6.0), k)
		look = from + Vector3(1.5, -0.4, 6.0)
	elif at < 17.0:
		var k := _ease((at - 12.0) / 5.0)
		from = Vector3(-2.6, 2.1, 0.6).lerp(Vector3(-1.8, 1.9, 1.6), k)
		look = Vector3(0.3, 1.5, 6.0)
	else:
		var k := _ease((at - 17.0) / 9.0)
		from = Vector3(0.2, 2.0, 0.0).lerp(Vector3(0.2, 7.5, -14.0), k)
		look = Vector3(0.2, 2.2 + k * 1.4, 6.5)
	cam.global_position = from
	cam.look_at(look, Vector3.UP)


func _ease(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)


## Nim's entrance: off the fire escape at 13 s, down, a landing with a wobble, then she squares up beside Vesper.
func _act(at: float) -> void:
	if _nim == null:
		return
	var holder := _nim.get_parent() as Node3D
	if at < 13.0:
		holder.position = NIM_AT + Vector3(0.6, NIM_DROP, 0.6)
		holder.scale = Vector3.ONE
		_landed = false
	elif at < 13.6:
		var k := (at - 13.0) / 0.6
		holder.position = (NIM_AT + Vector3(0.6, NIM_DROP, 0.6)).lerp(NIM_AT, k) + Vector3.UP * (NIM_DROP * (1.0 - k * k) - NIM_DROP * (1.0 - k))
		holder.position.y = lerpf(NIM_DROP, 0.0, k * k)
	elif at < 14.4:
		var k := (at - 13.6) / 0.8
		holder.position = NIM_AT
		holder.scale = Vector3(1.0 + 0.12 * (1.0 - k), 1.0 - 0.18 * (1.0 - k) * absf(cos(k * 9.0)), 1.0 + 0.12 * (1.0 - k))
		holder.rotation.z = 0.12 * sin(k * 14.0) * (1.0 - k)   # the wobble
	else:
		holder.position = NIM_AT
		holder.scale = Vector3.ONE
		holder.rotation.z = 0.0
	if _vesper:
		_vesper.demo_talk = at > 15.0 and at < 16.6   # a word to her, without looking round
