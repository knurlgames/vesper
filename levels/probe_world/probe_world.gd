extends World
## WO-008's probe world: one yard with every collectible and every piece a world is built from, placed with the World
## helpers. `tools/world_probe.gd` plays it. Not part of the game; Back / Tab reaches it after the test room.
##
##   near end (z +): the spawn and a checkpoint; two Keys, three contraband, the collection tin; fast travel "Gate"
##   middle: five people in a trance in a row (all five pay Key 10); a goon on guard; a zone over it all
##   east: a short wall with a shortcut in it (it opens from this side); fast travel "Yard"; a wardrobe to the west
##   far end (z -20): a wall with a rank door (4 Keys)

const SPAWN := Vector3(0, 0.05, 20)


func _ready() -> void:
	world_id = &"probe"
	load_data()
	var floor_mat := Look.painted(Look.Pattern.FLAGSTONES, Color("5c5866"), Color("201c26"), {"wet": 0.2})
	var wall := Look.painted(Look.Pattern.BRICK, Color("5a3a34"), Color("1e1418"), {"wet": 0.2})
	block(Vector3(0, -0.5, 0), Vector3(64, 1, 64), floor_mat)
	for side: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1)]:
		var size := Vector3(1, 3, 64) if side.x != 0.0 else Vector3(64, 3, 1)
		block(side * 32.5 + Vector3.UP * 1.5, size, wall)
	# The far wall, with the rank door in a 3 m gap.
	block(Vector3(-16.75, 2.0, -20.0), Vector3(30.5, 4.0, 0.6), wall)
	block(Vector3(16.75, 2.0, -20.0), Vector3(30.5, 4.0, 0.6), wall)
	rank_door(4, Vector3(0, 0, -20.0), 0.0, "RankDoor")
	# A short wall with the shortcut in it; its bolt is on the near (+Z) side.
	block(Vector3(16.4, 1.5, -10.0), Vector3(4.8, 3.0, 0.4), wall)
	block(Vector3(23.6, 1.5, -10.0), Vector3(4.8, 3.0, 0.4), wall)
	shortcut(&"east_gate", Vector3(20.0, 0.0, -10.0))
	_env()

	zone("The Probe Yard", Vector3(0, 0, 0), Vector3(60, 4, 38))
	checkpoint_at(Vector3(0, 0, 18), 0.0)
	key(&"probe_01", Vector3(-4, 0, 14))
	key(&"probe_02", Vector3(8, 0, -14))
	for i in 3:
		contraband(StringName("c%d" % (i + 1)), Vector3(4 + i, 0, 14))
	tin(Vector3(-8, 0, 14))
	for i in 5:
		sleeper(StringName("s%d" % (i + 1)), Vector3(-12 + i * 6, 0.05, 6), PackedVector3Array())
	travel_point(&"gate", "Gate", Vector3(-20, 0, 16))
	travel_point(&"yard", "Yard", Vector3(20, 0, 16))
	wardrobe(Vector3(-20, 0, -4), PI, "Wardrobe_probe")
	var g := Enemy.new()
	g.id = &"guard"
	g.name = "Goon_guard"
	g.position = Vector3(12, 0.05, 4)
	g.rotation.y = -PI / 2.0   # faces +X, away from the yard
	add_child(g)

	arrival("start", SPAWN, 0.0)
	spawn_player(SPAWN, 0.0)
	finish()


func _env() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("141024")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("6a6494")
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var w := WorldEnvironment.new()
	w.environment = env
	add_child(w)
	var moon := DirectionalLight3D.new()
	moon.light_color = Look.MOON
	moon.light_energy = 1.0
	moon.shadow_enabled = true
	moon.rotation = Vector3(deg_to_rad(-55), deg_to_rad(-30), 0)
	add_child(moon)
