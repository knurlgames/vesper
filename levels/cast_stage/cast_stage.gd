extends Level
## The cast stage: a performance test, not a level. All 17 cast bodies stand on a small night plaza so the owner can
## walk Nim among them and read the frame rate on the Deck (the perf overlay, core/perf_overlay.gd, is on here; F3 or
## L3 hides it). Reached by Back / Tab from the test course, or "Cast stage" on the title screen.
##
## The plaza is centred on the origin. North (-Z): a round dais with Vesper in garb and suit and Swyne between them.
## West: the garbs, masked, on an arc of radius 10. East: the suits, on the mirror arc. Four more (two garbs, two
## suits) walk a loop of radius 14.5 round the outside, so skinned animation costs what it would in a busy scene.
## Nim starts in the open south side, facing the dais. Lit like the street corner: moon (the one shadow), sodium lamps,
## fog, glow.

const LAMP := preload("res://assets/props/gas_lamp.glb")

const SPAWN := Vector3(0, 0.05, 9)
const ARC_RADIUS := 10.0
const LOOP_RADIUS := 14.5
const DAIS_AT := Vector3(0, 0, -9)
const DAIS_RADIUS := 3.0
const DAIS_TOP := 0.3

## [who, outfit] on the west arc (garbs) and the east arc (suits), from the dais outwards.
const GARBS := [["augusta", "garb"], ["dash", "garb"], ["lull", "garb"], ["bastion", "garb"], ["silke", "garb"]]
const SUITS := [["augusta", "suit"], ["rivet", "suit"], ["lull", "suit"], ["bastion", "suit"], ["grizelda", "suit"]]
## The walkers: [who, outfit, speed m/s]. Spaced a quarter of the loop apart; the last one runs.
const WALKERS := [["rivet", "garb", 1.3], ["silke", "suit", 1.4], ["grizelda", "garb", 1.2], ["dash", "suit", 3.6]]

## WO-013's enemies: a lineup in a row behind the spawn (Nim turns round to see them), facing the plaza, and two live
## goons on guard in the south corners, facing away, to fight, knock down and bind.
## One row per world, the back row first: the Pier, then Primrose Close.
const LINEUP := [["weasel_goon", "badger_bouncer", "gull_lookout", "laffer", "stoat_courier"],
	["bulldog_goon", "meerkat_watch", "gander"], ["rat_goon", "cormorant_lookout", "tusk", "stoat_customs"],
	["sheep_orderly", "heron_staff", "strix"], ["mole_goon", "doberman_guard", "magpie_qc", "grubb"]]
const LINEUP_Z := [12.8, 11.0, 14.6, 16.4, 18.2]
const GOONS := [["weasel_goon", Vector3(-9, 0, 8)], ["badger_bouncer", Vector3(9, 0, 8)]]

## The enemy models standing in the lineup, and the live goons (the probe checks both).
var lineup: Array[EnemyModel] = []
var goons: Array[Node] = []

## Every CastModel placed here (the probe counts them).
var cast: Array[CastModel] = []
## [model, angle] for the ones walking the loop.
var _walkers: Array = []
var _overlay: Node


func _ready() -> void:
	world_id = &"cast"
	_environment()
	_ground()
	_backdrop()
	_dais()
	for q: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		_lamp(Vector3(q.x * 12.5, 0, q.y * 12.5))
	_place_cast()
	_place_enemies()
	spawn_player(SPAWN, 0.0)
	_overlay = preload("res://core/perf_overlay.gd").new()
	add_child(_overlay)


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0c0a1a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("3c3a6e")
	env.ambient_light_energy = 0.7
	env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.15
	env.fog_enabled = true
	env.fog_light_color = Color("1e1a3a")
	env.fog_density = 0.022
	env.fog_height = 0.6
	env.fog_height_density = 0.12
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 0.9
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	# The moon: the one shadow-casting light (ART_DIRECTION.md "Performance"), from behind Nim's right shoulder so the
	# cast's faces are lit as she walks up.
	var moon := DirectionalLight3D.new()
	moon.light_color = Look.MOON
	moon.light_energy = 0.55
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 40.0
	moon.rotation = Vector3(deg_to_rad(-55), deg_to_rad(25), 0)
	add_child(moon)


func _ground() -> void:
	block(Vector3(0, -0.5, 0), Vector3(60, 1, 60), Look.painted(Look.Pattern.COBBLES, Color("4a4658"), Color("15121c"), {"wet": 0.7, "puddles": 0.4}))
	# The plaza proper: flagstones, a hair above the cobbles (never coplanar).
	block(Vector3(0, 0.005, -1), Vector3(34, 0.01, 30), Look.painted(Look.Pattern.FLAGSTONES, Color("5c5866"), Color("201c26"), {"wet": 0.6, "puddles": 0.25}), self, false)


## Three walls of townhouse fronts, so the plaza reads as a place and the far view has something behind the cast.
func _backdrop() -> void:
	var brick := Look.painted(Look.Pattern.BRICK, Color("4a3438"), Color("141018"), {"wet": 0.6})
	var plaster := Look.painted(Look.Pattern.PLASTER, Color("4c5a66"), Color("161a20"), {"wet": 0.5})
	var lit := StandardMaterial3D.new()
	lit.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lit.albedo_color = Color("ffb862")
	var dark := Look.toon(Color("0d1424"), 0.8)
	block(Vector3(0, 6, -22), Vector3(48, 12, 4), brick)
	block(Vector3(-22, 5, -2), Vector3(4, 10, 44), plaster)
	block(Vector3(22, 5, -2), Vector3(4, 10, 44), plaster)
	# Windows: a few lit, most dark. Thin boxes standing proud of the wall, one MultiMesh (one draw call) per material,
	# so the backdrop doesn't skew the cast's numbers.
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var batches := {lit: [], dark: []}
	for floor_y: float in [2.2, 5.6, 9.0]:
		for i in 9:
			var x := -16.0 + i * 4.0
			batches[lit if rng.randf() < 0.3 else dark].append(Transform3D(Basis.from_scale(Vector3(1.1, 1.7, 0.1)), Vector3(x, floor_y, -19.95)))
	for floor_y: float in [2.2, 5.6]:
		for i in 8:
			var z := -16.0 + i * 4.0
			for x: float in [-19.95, 19.95]:
				batches[lit if rng.randf() < 0.3 else dark].append(Transform3D(Basis.from_scale(Vector3(0.1, 1.7, 1.1)), Vector3(x, floor_y, z)))
	var unit := BoxMesh.new()
	for mat: Material in batches:
		var list: Array = batches[mat]
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


## The round dais at the north: velvet top, brass rim, a warm light over it.
func _dais() -> void:
	var body := StaticBody3D.new()
	body.position = DAIS_AT + Vector3.UP * DAIS_TOP / 2.0
	var shape := CylinderShape3D.new()
	shape.radius = DAIS_RADIUS
	shape.height = DAIS_TOP
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = DAIS_RADIUS
	cyl.bottom_radius = DAIS_RADIUS
	cyl.height = DAIS_TOP
	cyl.radial_segments = 40
	mesh.mesh = cyl
	mesh.material_override = Look.toon(Look.VELVET, 0.25)
	body.add_child(mesh)
	var rim := MeshInstance3D.new()
	var ring := TorusMesh.new()   # a ring round the top edge, not a disc over the velvet
	ring.inner_radius = DAIS_RADIUS - 0.03
	ring.outer_radius = DAIS_RADIUS + 0.07
	ring.rings = 48
	ring.ring_segments = 8
	rim.mesh = ring
	rim.material_override = Look.toon(Look.BRASS, 0.7)
	rim.position.y = DAIS_TOP / 2.0 - 0.02
	body.add_child(rim)
	add_child(body)
	var light := OmniLight3D.new()
	light.light_color = Color("ffc890")
	light.light_energy = 1.1
	light.omni_range = 7.0
	light.omni_attenuation = 1.4
	light.position = DAIS_AT + Vector3(0, 4.5, 1.5)
	add_child(light)


func _lamp(at: Vector3) -> void:
	var lamp: Node3D = LAMP.instantiate()
	lamp.position = at
	add_child(lamp)
	Look.dress(lamp, 0.02, 0.0, 2.5)
	collider(at + Vector3.UP * 1.6, Vector3(0.4, 3.2, 0.4))
	var light := OmniLight3D.new()
	light.light_color = Look.SODIUM
	light.light_energy = 3.2
	light.omni_range = 11.0
	light.omni_attenuation = 1.2
	light.position = at + Vector3.UP * 2.95
	add_child(light)


# --- the cast --------------------------------------------------------------------------------------------------------

func _place_cast() -> void:
	# The dais: Vesper in each outfit, Swyne between them a step back, all facing south (+Z), the way Nim comes in.
	var top := DAIS_AT + Vector3.UP * DAIS_TOP
	_stand("vesper", "garb", top + Vector3(-1.5, 0, 0.6), Vector3(0, 0, 1))
	_stand("swyne", "garb", top + Vector3(0, 0, -0.4), Vector3(0, 0, 1))
	_stand("vesper", "suit", top + Vector3(1.5, 0, 0.6), Vector3(0, 0, 1))
	# The arcs: from 35 degrees off north to 95, every 15 (2.6 m apart), each facing the middle of the plaza.
	for i in GARBS.size():
		var a := deg_to_rad(35.0 + 15.0 * i)
		_stand(GARBS[i][0], GARBS[i][1], Vector3(-sin(a), 0, -cos(a)) * ARC_RADIUS, Vector3.ZERO)
	for i in SUITS.size():
		var a := deg_to_rad(35.0 + 15.0 * i)
		_stand(SUITS[i][0], SUITS[i][1], Vector3(sin(a), 0, -cos(a)) * ARC_RADIUS, Vector3.ZERO)
	for i in WALKERS.size():
		var cm := _model(WALKERS[i][0], WALKERS[i][1])
		cm.speed = WALKERS[i][2]
		_walkers.append([cm, TAU * i / WALKERS.size()])
	_walk(0.0)


## A standing body at `at`, facing `face` (a direction), or facing the point `toward` if `face` is zero. It gets a box
## collider so Nim walks round it, not through it.
func _place_enemies() -> void:
	for row in LINEUP.size():
		var bodies: Array = LINEUP[row]
		for i in bodies.size():
			if EnemyModel.exists(bodies[i]):
				_line_up(bodies[i], Vector3((i - (bodies.size() - 1) / 2.0) * 2.4, 0, LINEUP_Z[row]))
	for g: Array in GOONS:
		var e := Enemy.new()
		e.id = StringName("stage_" + String(g[0]))
		e.body = g[0]
		e.position = g[1]
		add_child(e)
		e.rotation.y = 0.0          # facing -Z, away from the spawn: sneak up behind him
		goons.append(e)


func _line_up(body: String, at: Vector3) -> void:
	var em := EnemyModel.new()
	em.body = body
	em.name = body
	add_child(em)
	em.transform = Transform3D(Basis.looking_at(Vector3(0, 0, -1), Vector3.UP), at)
	em.show_state(0, 0.0, 0.0, 0.0)
	collider(at + Vector3.UP * 0.9, Vector3(0.8, 1.8, 0.8))
	lineup.append(em)


func _stand(who: String, outfit: String, at: Vector3, face: Vector3, toward := Vector3(0, 0, 2)) -> void:
	var cm := _model(who, outfit)
	var dir := face if face != Vector3.ZERO else (toward - at) * Vector3(1, 0, 1)
	cm.transform = Transform3D(Basis.looking_at(dir.normalized(), Vector3.UP), at)
	collider(at + Vector3.UP * 0.9, Vector3(0.7, 1.8, 0.7))


func _model(who: String, outfit: String) -> CastModel:
	var cm := CastModel.new()
	cm.name = "%s_%s" % [who.capitalize(), outfit] if who != "swyne" else "Swyne"
	cm.who = who
	cm.outfit = outfit
	cm.masked = outfit == "garb"
	add_child(cm)
	cast.append(cm)
	return cm


## Moves the walkers round the loop (counter-clockwise seen from above), each facing the way it's going.
func _walk(delta: float) -> void:
	for w: Array in _walkers:
		var cm: CastModel = w[0]
		w[1] = fmod(w[1] + cm.speed / LOOP_RADIUS * delta, TAU)
		var a: float = w[1]
		var at := Vector3(sin(a), 0, cos(a)) * LOOP_RADIUS
		var heading := Vector3(cos(a), 0, -sin(a))
		cm.transform = Transform3D(Basis.looking_at(heading, Vector3.UP), at)


## Whoever Nim stands near talks (their own talk clip, brows lifting on emphasis), so the gestures can be seen
## without a conversation.
const TALK_NEAR := 3.5


func _physics_process(delta: float) -> void:
	super(delta)
	_walk(delta)
	if nim:
		for cm: CastModel in cast:
			cm.demo_talk = cm.global_position.distance_to(nim.global_position) < TALK_NEAR
