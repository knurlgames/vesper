extends Level
## WO-002's style test: one Old Quarter street corner at night, in rain, built in code on the shader kit, with the three
## Meshy props and the greybox Nim. It's for the owner to judge the look ("velvet noir", ART_DIRECTION.md), not a
## level: nothing here is final layout.
##
## A crossroads at the origin, roads 10 m wide. NE: the Velvet Rope, red door and canopy on the corner. NW: two
## townhouses, a Decency League poster. SE: a lower block. SW: a little square with the advertising column, the bench and
## Nim. Lamps on every corner. Front of a Meshy prop is its +Z.

const LAMP := preload("res://assets/props/gas_lamp.glb")
const COLUMN := preload("res://assets/props/ad_column.glb")
const BENCH := preload("res://assets/props/bench.glb")

const ROAD := 5.0          # half the road's width
const KERB := 0.12         # pavement height
const STOREY := 3.4
const SPAWN := Vector3(-10, KERB + 0.05, 12)

# OWNER REVIEW: the poster's wording.
const POSTER_HEAD := "KEEP THE\nPURRLANDS\nDECENT"
const POSTER_VOTE := "Vote SWYNE"
const POSTER_SMALL := "Paid for by the Decency League.\nSeen something indecent? Write it down. Send it to us. All of it."

## material -> Array of box transforms, flushed into one MultiMesh each (one draw call per material, not per box).
var _batches := {}
var _rng := RandomNumberGenerator.new()

var _m_cobbles: ShaderMaterial
var _m_flags: ShaderMaterial
var _m_ink: ShaderMaterial
var _m_lit: StandardMaterial3D
var _m_lit_red: StandardMaterial3D
var _m_dark_glass: ShaderMaterial
var _m_sill: ShaderMaterial
var _m_slate: ShaderMaterial
var _m_velvet: ShaderMaterial
var _m_brass: ShaderMaterial


func _ready() -> void:
	_rng.seed = 7
	_materials()
	_environment()
	_ground()
	_buildings()
	_club()
	_poster(Vector3(-17.7, 1.9, -ROAD - 2.2), Vector3(0, 0, 1))   # between two ground-floor windows
	_props()
	_rain()
	_flush()
	# The hub's stand-in until the Old Quarter is built: "Return to the club" arrives at the Velvet Rope's door.
	world_id = &"hub"
	arrival("club_door", Vector3(ROAD + 5.5, KERB + 0.05, -ROAD - 0.8), PI)
	spawn_player(SPAWN, -PI / 4.0)
	_dress_nim()


func _materials() -> void:
	_m_cobbles = Look.painted(Look.Pattern.COBBLES, Color("4a4658"), Color("15121c"), {"wet": 0.85, "puddles": 0.55})
	_m_flags = Look.painted(Look.Pattern.FLAGSTONES, Color("5c5866"), Color("201c26"), {"wet": 0.8, "puddles": 0.3})
	_m_ink = Look.toon(Look.INK)
	_m_lit = StandardMaterial3D.new()
	_m_lit.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_m_lit.albedo_color = Color("ffb862")
	_m_lit_red = StandardMaterial3D.new()
	_m_lit_red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_m_lit_red.albedo_color = Color("d0304a")
	_m_dark_glass = Look.toon(Color("0d1424"), 0.8)
	_m_sill = Look.painted(Look.Pattern.PLASTER, Color("6a6470"), Color("201c26"), {"wet": 0.5})
	_m_slate = Look.painted(Look.Pattern.SLATE, Color("2e3444"), Color("0e1018"), {"wet": 0.9})
	_m_velvet = Look.toon(Look.VELVET, 0.25)
	_m_brass = Look.toon(Look.BRASS, 0.7)


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0c0a1a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("3c3a6e")
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color("1e1a3a")
	env.fog_density = 0.028
	env.fog_height = 0.6
	env.fog_height_density = 0.12
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 0.9
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	# The moon: cold, from above. The one shadow-casting light (ART_DIRECTION.md "Performance").
	var moon := DirectionalLight3D.new()
	moon.light_color = Look.MOON
	moon.light_energy = 0.45
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 45.0
	moon.rotation = Vector3(deg_to_rad(-58), deg_to_rad(-140), 0)
	add_child(moon)
	# No reflection probe: the puddles' lamp glints are the toon specular (shaders/toon_light.gdshaderinc). A probe cost
	# Deck time, reflected from the wrong place outdoors, and leaked textures at exit.


# --- ground ----------------------------------------------------------------------------------------------------------

func _ground() -> void:
	block(Vector3(0, -0.5, 0), Vector3(90, 1, 90), _m_cobbles)
	# A pavement in each quadrant, up a kerb.
	for q: Vector2 in [Vector2(1, -1), Vector2(-1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var c := Vector3(q.x * (ROAD + 20.0), KERB / 2.0, q.y * (ROAD + 20.0))
		block(c, Vector3(40, KERB, 40), _m_flags)


# --- buildings -------------------------------------------------------------------------------------------------------

func _buildings() -> void:
	var p := ROAD + 2.2   # building line: the pavement's 2.2 m wide
	# NW: a tall brick townhouse on the corner, a plaster one beside it.
	_building(Vector2(-14.5, -p - 14.0), Vector2(-p, -p), 13.6,
		Look.painted(Look.Pattern.BRICK, Color("6a3c34"), Color("1e1418"), {"wet": 0.6}), ["+z", "+x"])
	_building(Vector2(-24.0, -p - 14.0), Vector2(-14.5, -p), 10.2,
		Look.painted(Look.Pattern.PLASTER, Color("7a7266"), Color("201c22"), {"wet": 0.5}), ["+z"])
	# SE: lower, plaster, blue-grey.
	_building(Vector2(p, p), Vector2(p + 16.0, p + 14.0), 10.2,
		Look.painted(Look.Pattern.PLASTER, Color("4c5a66"), Color("161a20"), {"wet": 0.5}), ["-x", "-z"])
	# Backdrops: close the road ends and the square's back, so the corner reads as a city, not an island.
	var back := Look.painted(Look.Pattern.BRICK, Color("3e3440"), Color("141018"), {"wet": 0.6})
	_building(Vector2(-30.0, p + 9.0), Vector2(-p, p + 16.0), 13.6, back, ["-z", "+x"])
	_building(Vector2(-p - 8.0, -42.0), Vector2(p + 8.0, -34.0), 17.0, back, ["+z"])
	_building(Vector2(-p - 8.0, 34.0), Vector2(p + 8.0, 42.0), 17.0, back, ["-z"])
	_building(Vector2(34.0, -p - 8.0), Vector2(42.0, p + 8.0), 17.0, back, ["-x"])
	_building(Vector2(-42.0, -p - 8.0), Vector2(-34.0, p + 8.0), 17.0, back, ["+x"])


## A block from `a` to `b` (x, z corners), `h` tall: walls, a band at every storey, a cornice, a slate roof, chimneys,
## and windows on the faces listed ("+x", "-x", "+z", "-z": the way the face looks).
func _building(a: Vector2, b: Vector2, h: float, wall: ShaderMaterial, faces: Array, door_gap := Vector2.ZERO) -> void:
	var size := Vector3(b.x - a.x, h, b.y - a.y)
	var centre := Vector3((a.x + b.x) / 2.0, h / 2.0, (a.y + b.y) / 2.0)
	block(centre, size, wall)
	# Bands and cornice stand proud of the wall (never coplanar with it).
	var k := 1
	while k * STOREY < h - 1.0:
		_deco(Vector3(centre.x, k * STOREY, centre.z), Vector3(size.x + 0.24, 0.18, size.z + 0.24), _m_sill)
		k += 1
	_deco(Vector3(centre.x, h + 0.15, centre.z), Vector3(size.x + 0.6, 0.3, size.z + 0.6), _m_sill)
	# A pitched slate roof along the longer side, and two chimneys.
	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	var along_x := size.x >= size.z
	prism.size = Vector3(size.z if along_x else size.x, 2.6, size.x if along_x else size.z)
	roof.mesh = prism
	roof.material_override = _m_slate
	roof.position = Vector3(centre.x, h + 0.3 + 1.3, centre.z)
	roof.rotation.y = PI / 2.0 if along_x else 0.0
	add_child(roof)
	var brick := Look.painted(Look.Pattern.BRICK, Color("4a2e2c"), Color("140e10"), {"wet": 0.6})
	for f: float in [-0.3, 0.3]:
		var off := Vector3(size.x * f, 0, 0) if along_x else Vector3(0, 0, size.z * f)
		_deco(centre + off + Vector3(0, h / 2.0 + 2.2, 0), Vector3(0.8, 2.4, 0.8), brick)
	for face: String in faces:
		_windows(a, b, h, face, door_gap)


func _windows(a: Vector2, b: Vector2, h: float, face: String, door_gap: Vector2) -> void:
	var n := Vector3.ZERO
	var origin := Vector3.ZERO
	var u := Vector3.ZERO
	var length := 0.0
	match face:
		"+z":
			n = Vector3(0, 0, 1)
			origin = Vector3(a.x, 0, b.y)
			u = Vector3.RIGHT
			length = b.x - a.x
		"-z":
			n = Vector3(0, 0, -1)
			origin = Vector3(a.x, 0, a.y)
			u = Vector3.RIGHT
			length = b.x - a.x
		"+x":
			n = Vector3(1, 0, 0)
			origin = Vector3(b.x, 0, a.y)
			u = Vector3.BACK
			length = b.y - a.y
		"-x":
			n = Vector3(-1, 0, 0)
			origin = Vector3(a.x, 0, a.y)
			u = Vector3.BACK
			length = b.y - a.y
	var count := int((length - 1.2) / 2.5)
	var step := length / float(count)
	var k := 0
	while k * STOREY + 1.0 < h - 1.0:
		var y := k * STOREY + 1.9
		for i in count:
			var s := step * (i + 0.5)
			if door_gap != Vector2.ZERO and k == 0 and s > door_gap.x and s < door_gap.y:
				continue
			var lit := _rng.randf() < (0.4 if k > 0 else 0.25)
			_window(origin + u * s + Vector3.UP * y, u, n, 1.1, 1.7, lit)
		k += 1


func _window(at: Vector3, u: Vector3, n: Vector3, w: float, h: float, lit: bool) -> void:
	var au := u.abs()
	var an := n.abs()
	_deco(at + n * 0.03, au * (w + 0.18) + Vector3.UP * (h + 0.18) + an * 0.06, _m_ink)
	_deco(at + n * 0.05, au * w + Vector3.UP * h + an * 0.06, _m_lit if lit else _m_dark_glass)
	_deco(at + n * 0.095, au * 0.06 + Vector3.UP * h + an * 0.02, _m_ink)                   # mullion
	_deco(at + n * 0.095 + Vector3.UP * h * 0.18, au * w + Vector3.UP * 0.05 + an * 0.02, _m_ink)   # transom
	_deco(at + n * 0.1 - Vector3.UP * (h / 2.0 + 0.08), au * (w + 0.3) + Vector3.UP * 0.1 + an * 0.2, _m_sill)


# --- the Velvet Rope -------------------------------------------------------------------------------------------------

func _club() -> void:
	var p := ROAD + 2.2
	var a := Vector2(p, -p - 16.0)
	var b := Vector2(p + 15.0, -p)
	var wall := Look.painted(Look.Pattern.PLASTER, Color("3a2a3e"), Color("140c16"), {"wet": 0.55})
	# The door's on the +z face, 2.5 to 5 m in from the corner: no windows there on the ground floor.
	_building(a, b, 13.6, wall, ["+z", "-x"], Vector2(1.4, 5.2))
	var face_z := -p
	var dx := p + 3.3
	# The door: velvet, in a brass frame, up a step.
	_deco(Vector3(dx, 1.4, face_z + 0.04), Vector3(2.0, 2.9, 0.1), _m_brass)
	_deco(Vector3(dx, 1.35, face_z + 0.08), Vector3(1.7, 2.7, 0.1), _m_velvet)
	_deco(Vector3(dx + 0.55, 1.3, face_z + 0.16), Vector3(0.1, 0.1, 0.06), _m_brass)   # the handle
	# The canopy, and the name on its front edge in brass.
	block(Vector3(dx, 3.25, face_z + 0.9), Vector3(3.6, 0.35, 1.8), _m_velvet, self, false)
	_deco(Vector3(dx, 3.05, face_z + 1.82), Vector3(3.64, 0.08, 0.06), _m_brass)
	var name_sign := Label3D.new()
	name_sign.text = "THE VELVET ROPE"
	name_sign.font_size = 72
	name_sign.pixel_size = 0.0035
	name_sign.outline_size = 10
	name_sign.modulate = Color("f2c56a")
	name_sign.outline_modulate = Look.INK
	name_sign.position = Vector3(dx, 3.25, face_z + 1.81 + 0.02)
	name_sign.double_sided = false
	add_child(name_sign)
	var plaque := Label3D.new()
	plaque.text = "Members.\nAnd those who ask nicely."   # OWNER REVIEW
	plaque.font_size = 28
	plaque.pixel_size = 0.0035
	plaque.modulate = Color("e8d7c0")
	plaque.outline_size = 6
	plaque.outline_modulate = Look.INK
	plaque.position = Vector3(dx + 1.45, 1.7, face_z + 0.05)
	plaque.double_sided = false
	add_child(plaque)
	# The rope itself: two brass posts and a red rope sagging between them, across the pavement in front of the door.
	var z := face_z + 1.7
	var x0 := dx - 1.3
	var x1 := dx + 1.3
	for x: float in [x0, x1]:
		_post(Vector3(x, KERB, z))
		collider(Vector3(x, KERB + 0.5, z), Vector3(0.3, 1.0, 0.3))
	var segments := 10
	for i in segments:
		var t0 := float(i) / segments
		var t1 := float(i + 1) / segments
		var p0 := Vector3(lerpf(x0, x1, t0), KERB + 0.92 - sin(t0 * PI) * 0.22, z)
		var p1 := Vector3(lerpf(x0, x1, t1), KERB + 0.92 - sin(t1 * PI) * 0.22, z)
		var seg := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.035
		cyl.bottom_radius = 0.035
		cyl.height = p0.distance_to(p1) + 0.01
		cyl.radial_segments = 8
		seg.mesh = cyl
		seg.material_override = _m_velvet
		add_child(seg)
		seg.look_at_from_position((p0 + p1) / 2.0, p1, Vector3.UP)
		seg.rotate_object_local(Vector3.RIGHT, PI / 2.0)
	# Red light at the door: the only red in the street.
	var red := OmniLight3D.new()
	red.light_color = Color("ff4060")
	red.light_energy = 2.2
	red.omni_range = 5.0
	red.position = Vector3(dx, 2.8, face_z + 1.0)
	add_child(red)


func _post(at: Vector3) -> void:
	var post := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.08
	cyl.height = 0.95
	cyl.radial_segments = 12
	post.mesh = cyl
	post.material_override = _m_brass
	post.position = at + Vector3.UP * 0.475
	add_child(post)
	var knob := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16
	knob.mesh = sphere
	knob.material_override = _m_brass
	knob.position = at + Vector3.UP * 0.98
	add_child(knob)
	var foot := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.16
	disc.bottom_radius = 0.18
	disc.height = 0.05
	foot.mesh = disc
	foot.material_override = _m_brass
	foot.position = at + Vector3.UP * 0.025
	add_child(foot)


# --- the poster ------------------------------------------------------------------------------------------------------

## A Decency League poster on a wall facing `n`: cream and navy, Swyne's name, and small print.
func _poster(at: Vector3, n: Vector3) -> void:
	var cream := Look.toon(Look.DECENCY_CREAM)
	var navy := Look.toon(Look.DECENCY_NAVY)
	_deco(at + n * 0.03, Vector3(1.3, 1.8, 0.03), cream)
	_deco(at + n * 0.05 + Vector3(0, -0.55, 0), Vector3(1.3, 0.34, 0.02), navy)
	for line: Array in [[POSTER_HEAD, 64, 0.32, Look.DECENCY_NAVY], [POSTER_VOTE, 46, -0.55, Look.DECENCY_CREAM],
			[POSTER_SMALL, 15, -0.8, Look.DECENCY_NAVY]]:
		var l := Label3D.new()
		l.text = line[0]
		l.font_size = line[1]
		l.pixel_size = 0.0035
		l.modulate = line[3]
		l.outline_size = 0
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.width = 340.0
		l.position = at + n * 0.075 + Vector3(0, line[2], 0)
		l.double_sided = false
		l.shaded = true
		add_child(l)


# --- props -----------------------------------------------------------------------------------------------------------

func _props() -> void:
	var c := ROAD + 1.0
	for q: Vector2 in [Vector2(1, -1), Vector2(-1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		_lamp(Vector3(q.x * c, KERB, q.y * c))
	_lamp(Vector3(-15.0, KERB, ROAD + 1.0))
	_lamp(Vector3(ROAD + 1.0, KERB, -16.0))
	var column: Node3D = COLUMN.instantiate()
	column.position = Vector3(-9.5, KERB, 8.5)
	add_child(column)
	Look.dress(column, 0.02)
	collider(Vector3(-9.5, KERB + 1.5, 8.5), Vector3(1.2, 3.0, 1.2))
	var bench: Node3D = BENCH.instantiate()
	bench.position = Vector3(-13.0, KERB, ROAD + 1.3)
	add_child(bench)
	Look.dress(bench, 0.015)
	collider(Vector3(-13.0, KERB + 0.25, ROAD + 1.3), Vector3(1.65, 0.5, 0.6))


func _lamp(at: Vector3) -> void:
	var lamp: Node3D = LAMP.instantiate()
	lamp.position = at
	add_child(lamp)
	# The lantern's glass glows (the warm part of its texture), and sodium light pools round it.
	Look.dress(lamp, 0.02, 0.0, 2.5)
	collider(at + Vector3.UP * 1.6, Vector3(0.4, 3.2, 0.4))
	var light := OmniLight3D.new()
	light.light_color = Look.SODIUM
	light.light_energy = 3.2
	light.omni_range = 11.0
	light.omni_attenuation = 1.2
	light.position = at + Vector3.UP * 2.95
	add_child(light)


# --- rain ------------------------------------------------------------------------------------------------------------

var _rain_node: GPUParticles3D


func _rain() -> void:
	_rain_node = GPUParticles3D.new()
	_rain_node.amount = 2600
	_rain_node.lifetime = 0.9
	_rain_node.local_coords = false
	_rain_node.visibility_aabb = AABB(Vector3(-20, -20, -20), Vector3(40, 40, 40))
	_rain_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(16, 0.5, 16)
	pm.direction = Vector3(0.12, -1, 0.05)
	pm.spread = 2.0
	pm.initial_velocity_min = 17.0
	pm.initial_velocity_max = 21.0
	pm.gravity = Vector3.ZERO
	_rain_node.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.01, 0.45)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.75, 0.8, 1.0, 0.28)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	# Drops right at the lens would be bars across the screen: fade them in from 1.5 to 5 m.
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_min_distance = 1.5
	m.distance_fade_max_distance = 5.0
	quad.material = m
	_rain_node.draw_pass_1 = quad
	add_child(_rain_node)


func _process(_delta: float) -> void:
	if cam and _rain_node:
		_rain_node.global_position = cam.global_position + Vector3(0, 9, 0)


# --- helpers ---------------------------------------------------------------------------------------------------------

## A decorative box (no collision), batched by material.
func _deco(at: Vector3, size: Vector3, mat: Material) -> void:
	var list: Array = _batches.get_or_add(mat, [])
	list.append(Transform3D(Basis.from_scale(size), at))


func _flush() -> void:
	var unit := BoxMesh.new()
	for mat: Material in _batches:
		var list: Array = _batches[mat]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = unit
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		add_child(mmi)
	_batches.clear()


## The greybox in Nim's coat colour, toon-lit, inked, with her rim light.
func _dress_nim() -> void:
	for mi: MeshInstance3D in nim.find_children("*", "MeshInstance3D", true, false):
		var colour := Color("948a7e") if mi.mesh is CapsuleMesh else Color("c9d8b0")
		mi.material_override = Look.toon(colour, 0.0, 0.9 if mi.mesh is CapsuleMesh else 0.0)
		mi.material_overlay = Look.outline(mi.get_aabb(), 0.015)
