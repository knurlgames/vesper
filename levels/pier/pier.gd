class_name Pier
extends BuiltWorld
## World 1, the Pier (docs/worlds/01_PIER.md; data/worlds/pier.json). WO-014 step 1: the layout, all six areas, built in
## code with the painted shaders, at night in the rain, with everything a world has placed. The Keys' scripts, Vesper's
## lesson, the Big Dipper chase and Laffer come in the next steps (WORK_ORDERS WO-014 "Build order").
##
## The pier runs out to sea along -Z from the promenade. The deck's top is y 0; the sand under it is y -6, the sea y -7.
##
##   The Promenade      z  34..4     x -70..70   shops to the north, beach huts and Dash's hut to the east, the gate
##                                               at x 0, a ramp down to the beach to the west, a marked stretch of
##                                               sea wall
##   (the neck)         z   4..-6    x  -8..8
##   The Midway         z  -6..-112  x -16..16   stalls both sides of an avenue: the shooting gallery (west), the high
##                                               striker (east), Madame Pearl's tent (west), the bait-and-tackle hut
##                                               over the trapdoor (east, the first shortcut)
##   Under the Pier     y  -6        x -22..22   the sand under the near half: pilings, cross-beams at y -3.2 and two
##                                               stringers at x ±6 to walk them, marked posts up to the beams, the
##                                               lifeguard hut (a wardrobe), the smugglers' landing at the far end
##   Laffer's Fun       z -112..-152 x -18..18   the arcade, 9 m tall, wall to wall but for a walkway down its east
##     Palace                                    side (a marked wall up to the roof): the bouncer at the front door,
##                                               cabinets, the prize counter and its shelves (Key 7), the back office
##                                               (in by the roof vent; out by its door), the staff locker (a wardrobe),
##                                               the fire door at the back (the second shortcut)
##   The Big Dipper     z -152..-258 x -40..40   the Ferris wheel to the west (Key 8 on its crown), the coaster's
##     and the wheel                             station and track to the east
##   The Prize Hall     z -258..-298 x -22..22   closed for stocktaking until Laffer's fight (step 4)

const FerrisWheel := preload("res://levels/pier/ferris_wheel.gd")

const DECK := 0.0
const DECK_T := 0.4
const SAND := -6.0
const SEA := -7.0
const BEAM_Y := -3.2
const SPAWN := Vector3(0, 0.05, 26)
## The people of the pier (WO-014 step 6): four species, each tinted per person to fill a crowd.
const CIVILIANS := ["otter_civilian", "hare_civilian", "fox_civilian", "hedgehog_civilian"]
## Where the wheel's axle is.
const WHEEL := Vector3(-24, 16, -205)

var wheel: Node3D

var _m := {}
var _contraband := 0


## The audit's Meshy buildings (2026-11-13): [prop -> items], placed at the end of _ready. Each stands over the
## greybox's own collision; `_have` says whether its GLB is built (else the greybox is drawn as before).
var _dressing := {}


func _have(prop: String) -> bool:
	return ResourceLoader.exists(PROP_PATH % prop)


func _dress(prop: String, item: Array) -> void:
	(_dressing.get_or_add(prop, []) as Array).append(item)


func _ready() -> void:
	world_id = &"pier"
	load_data()
	_materials()
	_environment()
	_promenade()
	_midway()
	_under()
	_palace()
	_pier_end()
	_hall()
	_sea()
	_people()
	_collectibles()
	_places()
	_keys()
	_rain()
	for p: String in _dressing:   # the Meshy buildings and railings, a MultiMesh each (the shells have no collision)
		props(p, _dressing[p], false)
	_flush()
	arrival("start", SPAWN, 0.0)
	arrival("hub", Vector3(-64.0, 0.05, 17.0), -PI / 2.0)   # in from the Old Quarter's arch, facing the pier
	spawn_player(SPAWN, 0.0)
	finish()


# --- materials and light ---------------------------------------------------------------------------------------------

func _materials() -> void:
	_m.planks = Look.painted(Look.Pattern.PLANKS, Color("5e4c40"), Color("1a120e"), {"wet": 0.8, "puddles": 0.3})
	_m.planks_dry = Look.painted(Look.Pattern.PLANKS, Color("54443a"), Color("1a120e"), {"wet": 0.2})
	_m.flags = Look.painted(Look.Pattern.FLAGSTONES, Color("5c5866"), Color("201c26"), {"wet": 0.8, "puddles": 0.35})
	_m.seawall = Look.painted(Look.Pattern.BRICK, Color("4a4650"), Color("16141c"), {"wet": 0.7, "scale": 1.4})
	_m.sand = Look.painted(Look.Pattern.PLASTER, Color("7a6c56"), Color("2e261c"), {"wet": 0.55, "stroke": 0.22})
	_m.climb = Look.painted(Look.Pattern.BRICK, Color("4f8a5a"), Color("173020"), {"wet": 0.5, "scale": 1.6})
	_m.timber = Look.toon(Color("4a3a30"))
	_m.beam = Look.toon(Color("6a5040"))
	_m.rail = Look.toon(Color("d8d0c0"), 0.2)
	_m.ink = Look.toon(Look.INK)
	_m.plaster = Look.painted(Look.Pattern.PLASTER, Color("6e6872"), Color("201c24"), {"wet": 0.5})
	_m.palace = Look.painted(Look.Pattern.PLASTER, Color("6a2a3e"), Color("1e0c14"), {"wet": 0.5})
	_m.palace_in = Look.painted(Look.Pattern.PLASTER, Color("3a2236"), Color("140a12"), {"wet": 0.0})
	_m.hall = Look.painted(Look.Pattern.PLASTER, Color("2e4a5e"), Color("0e1820"), {"wet": 0.5})
	_m.roof = Look.painted(Look.Pattern.SLATE, Color("2e3444"), Color("0e1018"), {"wet": 0.9})
	_m.counter = Look.toon(Color("3a2218"))
	_m.brass = Look.toon(Look.BRASS, 0.6)
	_m.velvet = Look.toon(Look.VELVET, 0.25)
	_m.cabinet = Look.toon(Color("24203a"), 0.3)
	_m.white = Look.toon(Color("e8e0d0"), 0.2)
	_m.pink = Look.toon(Color("e86a8a"))
	_m.blue = Look.toon(Color("6aa0c8"))
	_m.yellow = Look.toon(Color("e8c860"))
	_m.lit = _unlit(Color(2.0, 1.4, 0.8))
	_m.screen = _unlit(Color(0.5, 1.4, 1.6))
	_m.window = _unlit(Color("ffb862"))


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0c0a1a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("3c3a6e")
	env.ambient_light_energy = 0.6
	env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color("1e1a3a")
	env.fog_density = 0.012
	env.fog_height = -4.0
	env.fog_height_density = 0.08
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# The moon: the one shadow-casting light. The deck shades the sand under it, which is what makes it covert.
	var moon := DirectionalLight3D.new()
	moon.light_color = Look.MOON
	moon.light_energy = 0.5
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 60.0
	moon.rotation = Vector3(deg_to_rad(-52), deg_to_rad(-150), 0)
	add_child(moon)


# --- the promenade ---------------------------------------------------------------------------------------------------

func _promenade() -> void:
	# The promenade itself: its front face (z 4) is the sea wall, 6 m down to the beach.
	solid(Vector3(0, -4.0, 19), Vector3(140, 8, 30), _m.flags)
	# A marked stretch of sea wall, west of the gate: up and down without the ramp.
	solid(Vector3(-23, -3.025, 3.9), Vector3(6, 5.95, 0.2), _m.climb, 1 | 2)
	# The ramp down to the beach, along the foot of the wall: x -40 (the top, y 0) to x -54 (the sand).
	var run := 14.0
	var drop := -SAND
	var ang := atan2(drop, run)
	var ramp_len := sqrt(run * run + drop * drop)
	var ramp_centre := Vector3(-47.0, -3.0 - 0.2 / cos(ang), 3.1)
	_slab(ramp_centre, Vector3(ramp_len, 0.4, 1.8), Basis(Vector3.BACK, ang), _m.planks)
	solid(Vector3(-55.0, SAND - 0.18, 3.08), Vector3(2.0, 0.4, 1.76), _m.planks)   # 2 cm proud of the sand, off the wall
	# The railing along the sea wall, with gaps for the ramp, the marked wall and the pier's neck.
	for span: Vector2 in [Vector2(-70, -42), Vector2(-38, -26.5), Vector2(-19.5, -8), Vector2(8, 70)]:
		_railing(Vector3(span.x, DECK, 4.4), Vector3(span.y, DECK, 4.4))
	# The shops along the north side, facing the sea.
	var shops := [["ROCK & CANDY", Color("7a3a4a")], ["FISH & CHIPS", Color("3a5a6a")], ["AMUSEMENTS", Color("6a5a2a")],
		["B&B  VACANCIES", Color("4a4a6a")], ["SOUVENIRS", Color("5a3a5a")], ["TEA ROOM", Color("3a5a4a")]]
	for i in shops.size():
		var x0 := -66.0 + i * 22.0
		var h := 7.0 + (i % 3) * 1.6
		var wall := Look.painted(Look.Pattern.PLASTER, shops[i][1], Color("1a1418"), {"wet": 0.5})
		_shopfront(Vector2(x0, 28.0), Vector2(x0 + 20.0, 34.0), h, wall, shops[i][0])
	# Behind the shops, the town climbing the hill: dark blocks with a lit window or two.
	for i in 9:
		var x := -64.0 + i * 16.0
		var h := 12.0 + float((i * 7) % 5) * 2.5
		solid(Vector3(x, h / 2.0, 42.0 + (i % 2) * 6.0), Vector3(14.0, h, 8.0), _m.roof)
		deco(Vector3(x - 3.0, h * 0.6, 37.9 + (i % 2) * 6.0), Vector3(1.0, 1.4, 0.1), _m.window)
	# Beach huts on the promenade, east of the gate, 4.8 m apart: too far to jump. Bunting wires tie roof to roof.
	var stripes := [Color("d86a7a"), Color("6aa0c8"), Color("e8c860"), Color("7ac08a"), Color("c88ad8")]
	for i in 5:
		var cx := 22.0 + i * 8.0
		_beach_hut(Vector3(cx, DECK, 9.5), stripes[i])
		if i < 4:
			_bunting(Vector3(cx + 1.6, 3.0, 9.5), Vector3(cx + 6.4, 3.0, 9.5))
	# Dash's hut: bigger, cheetah orange with spots, at the end of the row. Its wardrobe stands at its door.
	solid(Vector3(62, 1.7, 9.5), Vector3(5, 3.4, 5), Look.toon(Color("e8a030")))
	deco(Vector3(62, 3.55, 9.5), Vector3(5.4, 0.3, 5.4), _m.ink)
	for spot: Vector3 in [Vector3(60.5, 2.4, 12.02), Vector3(63.2, 1.4, 12.02), Vector3(61.8, 0.8, 12.02), Vector3(63.8, 2.7, 12.02)]:
		deco(spot, Vector3(0.45, 0.45, 0.05), _m.ink)
	_sign("DASH'S", Vector3(62, 3.0, 12.05), 0.0, Color(2.2, 1.2, 0.4), 40)
	wardrobe(Vector3(60.0, DECK, 12.8), PI, "Wardrobe_hut")
	# The gate: two pillars and a crossbar over the neck, with Swyne's banner.
	if _have("pier_gate"):
		# The pink ironwork arch, its towers over the pillars' collision; Swyne's banner hung across under its span.
		for sx: float in [-7.5, 7.5]:
			_col(Vector3(sx, 3.5, 2.0), Vector3(1.2, 7.0, 1.2), 1)
		_dress("pier_gate", [Vector3(0, DECK, 2.0), 0.0, Vector3(17.0, 9.6, 1.4)])
	else:
		for sx: float in [-7.5, 7.5]:
			solid(Vector3(sx, 3.5, 2.0), Vector3(1.2, 7.0, 1.2), _m.white)
			deco(Vector3(sx, 7.3, 2.0), Vector3(1.6, 0.6, 1.6), _m.velvet)
	deco(Vector3(0, 6.2, 2.0), Vector3(13.6, 1.8, 0.5), Look.toon(Look.DECENCY_NAVY))   # between the pillars
	_sign("COUNCILLOR SWYNE:", Vector3(0, 6.6, 2.27), 0.0, Look.DECENCY_CREAM, 52, false)
	_sign("A CLEAN SEAFRONT FOR DECENT FAMILIES", Vector3(0, 5.85, 2.27), 0.0, Look.DECENCY_CREAM, 52, false)
	_sign("THE  PIER", Vector3(0, 8.0, 2.0), 0.0, Color(2.4, 0.6, 1.0), 72)
	_light(Vector3(0, 5.5, 3.5), Color("ff6aa8"), 3.0, 12.0)
	# Lamps along the promenade.
	for x: float in [-56.0, -28.0, 28.0, 56.0]:
		_lamp(Vector3(x, DECK, 6.0), true)
	# Lifebuoys on posts at the sea wall's railing, and deckchairs turned to the sea (step 6's dressing).
	props("lifebuoy", [[Vector3(-45.0, DECK, 4.95), 0.0], [Vector3(-31.0, DECK, 4.95), 0.0],
		[Vector3(13.0, DECK, 4.95), 0.0], [Vector3(48.0, DECK, 4.95), 0.0]])
	props("deckchair", [[Vector3(-36.0, DECK, 6.4), PI + 0.2], [Vector3(-34.6, DECK, 6.6), PI - 0.15],
		[Vector3(-16.0, DECK, 6.5), PI], [Vector3(16.5, DECK, 6.5), PI + 0.3], [Vector3(36.0, DECK, 6.4), PI - 0.1]],
		false)
	# The way back to the Old Quarter (the hub): an arch at the promenade's west end; a wall closes the rest of it.
	solid(Vector3(-70.3, 2.0, 8.0), Vector3(0.6, 4.0, 8.0), _m.seawall)
	solid(Vector3(-70.3, 2.0, 28.0), Vector3(0.6, 4.0, 12.0), _m.seawall)
	for z: float in [12.0, 22.0]:
		solid(Vector3(-69.6, 3.0, z), Vector3(1.0, 6.0, 1.0), _m.white)
	deco(Vector3(-69.6, 6.3, 17.0), Vector3(1.2, 0.8, 11.2), _m.velvet)
	_sign("THE OLD QUARTER", Vector3(-68.95, 6.3, 17.0), PI / 2.0, Color(2.2, 1.6, 0.9), 52)
	var back := WorldGate.new()
	back.name = "Gate_hub"
	back.world = &"hub"
	back.arrival = "seafront"
	back.size = Vector3(1.5, 3.0, 9.0)
	back.position = Vector3(-70.6, DECK, 17.0)
	add_child(back)
	# The neck: the pier's first 10 m, narrow.
	solid(Vector3(0, -DECK_T / 2.0, -1.0), Vector3(16, DECK_T, 10), _m.planks)
	_railing(Vector3(-8, DECK, 4.0), Vector3(-8, DECK, -6.0))
	_railing(Vector3(8, DECK, 4.0), Vector3(8, DECK, -6.0))


func _shopfront(a: Vector2, b: Vector2, h: float, wall: Material, name_text: String) -> void:
	var c := Vector3((a.x + b.x) / 2.0, h / 2.0, (a.y + b.y) / 2.0)
	solid(c, Vector3(b.x - a.x, h, b.y - a.y), wall)
	deco(Vector3(c.x, h + 0.15, c.z), Vector3(b.x - a.x + 0.4, 0.3, b.y - a.y + 0.4), _m.plaster)
	# A lit shop window and a door on the ground floor; two windows above, one lit.
	deco(Vector3(c.x - 4.0, 1.5, a.y - 0.02), Vector3(6.0, 2.0, 0.06), _m.window)
	deco(Vector3(c.x + 3.5, 1.2, a.y - 0.02), Vector3(1.4, 2.4, 0.06), _m.cabinet)
	deco(Vector3(c.x - 5.0, h - 2.2, a.y - 0.02), Vector3(1.4, 1.8, 0.06), _m.window)
	deco(Vector3(c.x + 4.0, h - 2.2, a.y - 0.02), Vector3(1.4, 1.8, 0.06), _m.cabinet)
	# The awning, and the shop's name in neon over it.
	deco(Vector3(c.x - 4.0, 2.9, a.y - 0.7), Vector3(7.0, 0.12, 1.4), _m.velvet)
	_sign(name_text, Vector3(c.x, 3.6, a.y - 0.05), PI, Color(2.0, 1.6, 0.9), 44)


func _beach_hut(at: Vector3, colour: Color) -> void:
	if _have("beach_hut"):
		# The Meshy hut (candy stripes, a step), its doors to the promenade (+Z), over the box's collision.
		_col(at + Vector3(0, 1.5, 0), Vector3(3.2, 3.0, 3.0), 1)
		_dress("beach_hut", [at, 0.0, Vector3(3.2, 3.8, 3.2)])
		return
	var wall := Look.toon(colour)
	solid(at + Vector3(0, 1.5, 0), Vector3(3.2, 3.0, 3.0), wall)
	deco(at + Vector3(0, 3.1, 0), Vector3(3.5, 0.2, 3.3), _m.white)
	# White stripes, a door.
	for sx: float in [-1.0, 0.0, 1.0]:
		deco(at + Vector3(sx, 1.5, 1.52), Vector3(0.3, 3.0, 0.04), _m.white)
	deco(at + Vector3(0, 1.0, 1.55), Vector3(1.0, 2.0, 0.04), _m.timber)


## A bunting wire from a to b (same height): something to tail-walk, flags hung under it.
func _bunting(a: Vector3, b: Vector3) -> void:
	var w := Beam.new()
	w.length = a.distance_to(b) + 0.3
	w.width = 0.05
	w.wire = true
	w.material = _m.ink
	w.position = (a + b) / 2.0
	w.rotation.y = -atan2(b.z - a.z, b.x - a.x)
	add_child(w)
	var flags := [_m.velvet, _m.yellow, _m.blue]
	var n := int(a.distance_to(b) / 0.6)
	for i in n:
		var p := a.lerp(b, (i + 0.5) / n)
		deco(p + Vector3(0, -0.2, 0), Vector3(0.25, 0.3, 0.02), flags[i % 3])


func _lamp(at: Vector3, lit: bool) -> void:
	solid(at + Vector3(0, 1.7, 0), Vector3(0.18, 3.4, 0.18), _m.ink)
	deco(at + Vector3(0, 3.5, 0), Vector3(0.4, 0.4, 0.4), _m.lit)
	if lit:
		_light(at + Vector3(0, 3.4, 0), Look.SODIUM, 3.0, 10.0)


## A railing between two points on the deck: posts and a top rail, and a collider 1.1 m tall (she can hop it).
func _railing(a: Vector3, b: Vector3) -> void:
	var length := a.distance_to(b)
	var mid := (a + b) / 2.0
	var along_x := absf(b.x - a.x) > absf(b.z - a.z)
	var size := Vector3(length, 1.1, 0.12) if along_x else Vector3(0.12, 1.1, length)
	_col(mid + Vector3(0, 0.55, 0), size, 1)
	if _have("sea_railing"):
		# The Victorian ironwork, in sections of about 2 m along it.
		var n := maxi(1, roundi(length / 2.0))
		var yaw := 0.0 if along_x else PI / 2.0
		for i in n:
			_dress("sea_railing", [a.lerp(b, (i + 0.5) / n), yaw, Vector3(length / n, 1.15, 0.16)])
		return
	var top := Vector3(length, 0.08, 0.1) if along_x else Vector3(0.1, 0.08, length)
	deco(mid + Vector3(0, 1.05, 0), top, _m.rail)
	deco(mid + Vector3(0, 0.55, 0), top, _m.rail)
	var n := maxi(1, int(length / 2.0))
	for i in n + 1:
		deco(a.lerp(b, float(i) / n) + Vector3(0, 0.55, 0), Vector3(0.1, 1.1, 0.1), _m.rail)


# --- the Midway ------------------------------------------------------------------------------------------------------

## The trapdoor's hole in the deck, inside the bait-and-tackle hut.
const HATCH := Rect2(13.4, -59.6, 1.2, 1.2)


func _midway() -> void:
	# The deck, with the hatch's hole in it (x 13.4..14.6, z -59.6..-58.4). The ladder's marked board fills x 14.6..14.9
	# up to the deck's top, so she climbs it straight out through the hole.
	solid(Vector3(-1.3, -DECK_T / 2.0, -59.0), Vector3(29.4, DECK_T, 106.0), _m.planks)
	solid(Vector3(15.45, -DECK_T / 2.0, -59.0), Vector3(1.1, DECK_T, 106.0), _m.planks)
	solid(Vector3(14.0, -DECK_T / 2.0, -32.2), Vector3(1.2, DECK_T, 52.4), _m.planks)
	solid(Vector3(14.0, -DECK_T / 2.0, -85.8), Vector3(1.2, DECK_T, 52.4), _m.planks)
	solid(Vector3(14.75, (SAND + DECK) / 2.0, -59.0), Vector3(0.3, -SAND, 0.8), _m.climb, 1 | 2)
	_railing(Vector3(-16, DECK, -6), Vector3(-16, DECK, -112))
	_railing(Vector3(16, DECK, -6), Vector3(16, DECK, -108))
	# West stalls open to +X (their counters at x -10); east stalls open to -X (counters at x 10).
	_stall(-1, -12.0, -20.0, "CANDYFLOSS", Color("e88ab0"), Color("f2e6d8"))
	_stall(-1, -24.0, -36.0, "SHOOTING GALLERY", Color("c83a3a"), Color("f2e6d8"), 7.0)
	_tent(Vector3(-12.5, DECK, -57.0))
	_stall(-1, -70.0, -78.0, "HOOK-A-DUCK", Color("3a8ac8"), Color("f2e6d8"))
	_stall(-1, -90.0, -100.0, "TEAS", Color("3a7a5a"), Color("f2e6d8"))
	_stall(1, -12.0, -20.0, "HOT DOGS", Color("d8a040"), Color("f2e6d8"))
	_striker(Vector3(12.0, DECK, -41.0))
	_tackle_hut()
	_stall(1, -70.0, -84.0, "PENNY FALLS", Color("8a4ac8"), Color("f2e6d8"))
	_stall(1, -92.0, -100.0, "WHELKS", Color("4a6a8a"), Color("f2e6d8"))
	# Lamp posts down the avenue; the gulls perch on three of them (their own posts: see _people).
	for z: float in [-12.0, -52.0, -112.0 + 20.0]:
		_lamp(Vector3(7.0, DECK, z), true)
		_lamp(Vector3(-7.0, DECK, z - 10.0), z != -52.0)
	# Strings of bulbs over the avenue.
	for z: float in [-24.0, -44.0, -64.0, -84.0, -104.0]:
		for i in 9:
			deco(Vector3(-8.0 + i * 2.0, 4.6 - absf(i - 4.0) * 0.08, z), Vector3(0.18, 0.18, 0.18), _m.lit)


## A stall on the Midway: three walls, a counter across its open side, a striped awning, its name in neon.
## side -1: the west row (open to +X); side 1: the east row (open to -X). `depth` from the rail inward.
func _stall(side: int, z0: float, z1: float, name_text: String, stripe: Color, cream: Color, depth := 6.0) -> void:
	var back := 16.0 * side - side * 0.2
	var front := 16.0 * side - side * depth
	var cz := (z0 + z1) / 2.0
	var length := z0 - z1
	var wall := Look.toon(stripe.darkened(0.35))
	var stripes := [Look.toon(stripe), Look.toon(cream)]
	if _have("pier_booth"):
		# The Meshy booth (striped awning, bulbs, counter), its open front to the avenue, over the same walls and
		# counter (the Keys and the gallery use them).
		_col(Vector3(back, 1.5, cz), Vector3(0.3, 3.0, length), 1)
		for z: float in [z0, z1]:
			_col(Vector3((back + front) / 2.0, 1.5, z), Vector3(depth - 0.2, 3.0, 0.3), 1)
		_col(Vector3(front + side * 0.3, 0.5, cz), Vector3(0.6, 1.0, length - 0.3), 1)
		_dress("pier_booth", [Vector3((back + front) / 2.0 + side * 0.4, DECK, cz), -side * PI / 2.0,
			Vector3(length, 4.2, depth + 0.8)])
		_sign(name_text, Vector3(front - side * 0.6, 4.4, cz), -PI / 2.0 * side, Color(2.2, 1.5, 0.8), 40)
		_light(Vector3(front + side * 1.5, 2.6, cz), Color("ffb070"), 1.6, 6.0)
		return
	solid(Vector3(back, 1.5, cz), Vector3(0.3, 3.0, length), wall)
	for z: float in [z0, z1]:
		solid(Vector3((back + front) / 2.0, 1.5, z), Vector3(depth - 0.2, 3.0, 0.3), wall)
	solid(Vector3(front + side * 0.3, 0.5, cz), Vector3(0.6, 1.0, length - 0.3), _m.counter)
	# The awning: alternating stripes, sloping out over the counter.
	var n := int(length / 1.0)
	for i in n:
		var z := z0 - (i + 0.5) * length / n
		deco(Vector3((back + front) / 2.0 - side * 0.6, 3.1, z), Vector3(depth + 1.4, 0.12, length / n), stripes[i % 2])
	_sign(name_text, Vector3(front - side * 0.4, 3.5, cz), -PI / 2.0 * side, Color(2.2, 1.5, 0.8), 40)
	_light(Vector3(front + side * 1.5, 2.6, cz), Color("ffb070"), 1.6, 6.0)


## Madame Pearl's tent: a closed tent with a curtained door facing the avenue.
func _tent(at: Vector3) -> void:
	var cloth := Look.toon(Color("4a2a6a"))
	var gold := Look.toon(Color("c8a040"), 0.4)
	solid(at + Vector3(-3.2, 1.6, 0), Vector3(0.2, 3.2, 8.0), cloth)
	solid(at + Vector3(0, 1.6, 4.0), Vector3(6.6, 3.2, 0.2), cloth)
	solid(at + Vector3(0, 1.6, -4.0), Vector3(6.6, 3.2, 0.2), cloth)
	solid(at + Vector3(3.2, 1.6, 2.4), Vector3(0.2, 3.2, 3.2), cloth)
	solid(at + Vector3(3.2, 1.6, -2.4), Vector3(0.2, 3.2, 3.2), cloth)
	solid(at + Vector3(3.2, 2.9, 0.0), Vector3(0.2, 0.6, 1.6), cloth)
	deco(at + Vector3(0, 3.5, 0), Vector3(7.0, 0.6, 8.4), gold)
	deco(at + Vector3(0, 4.1, 0), Vector3(4.0, 0.6, 5.0), cloth)
	# Inside: a round table with a crystal ball.
	if not props("fortune_table", [[at + Vector3(-1.0, 0, 0), PI / 2.0]], true, 0.012, 1.5):
		solid(at + Vector3(-1.0, 0.4, 0), Vector3(1.4, 0.8, 1.4), _m.velvet)
		deco(at + Vector3(-1.0, 1.0, 0), Vector3(0.4, 0.4, 0.4), _m.screen)
	_light(at + Vector3(-1.0, 1.8, 0), Color("a070ff"), 1.4, 5.0)
	_sign("MADAME PEARL", Vector3(at.x + 3.35, 3.8, at.z), PI / 2.0, Color(1.6, 0.9, 2.2), 40)
	_sign("FORTUNES TOLD", Vector3(at.x + 3.35, 3.35, at.z), PI / 2.0, Color(2.0, 1.6, 0.9), 26)


## The high striker: a 10.2 m marked tower, its top flush (a cap that overhung stopped the climb under its lip), the
## bell hung off its west face (levels/pier/keys/striker.gd), the mallet's base.
func _striker(at: Vector3) -> void:
	if _have("high_striker"):
		# The red-and-gold tower, its scale and bell, over the climbable column (still marked up its back, the
		# climber's side, so it reads as a climb).
		_col(at + Vector3(0, 5.1, 0), Vector3(1.4, 10.2, 1.4), 1 | 2)
		deco(at + Vector3(0.72, 5.1, 0), Vector3(0.04, 10.2, 1.2), _m.climb)
		_dress("high_striker", [at + Vector3(-0.4, DECK, 0), -PI / 2.0, Vector3(2.4, 10.6, 2.0)])
		_sign("TEST YOUR STRENGTH", Vector3(at.x - 1.3, 3.0, at.z), -PI / 2.0, Color(2.2, 0.8, 0.6), 36)
		_light(at + Vector3(-2.5, 3.0, 0), Color("ffb070"), 1.6, 7.0)
		return
	solid(at + Vector3(0, 5.1, 0), Vector3(1.4, 10.2, 1.4), _m.climb, 1 | 2)
	deco(at + Vector3(0, 10.22, 0), Vector3(1.44, 0.06, 1.44), _m.brass)
	solid(at + Vector3(-1.5, 0.3, 0), Vector3(1.4, 0.6, 1.4), _m.counter)
	# The scale painted up its front.
	for i in 9:
		deco(at + Vector3(-0.72, 1.0 + i * 1.0, 0), Vector3(0.04, 0.12, 0.7), _m.lit if i % 3 == 2 else _m.white)
	_sign("TEST YOUR STRENGTH", Vector3(at.x - 0.75, 2.8, at.z), -PI / 2.0, Color(2.2, 0.8, 0.6), 36)
	_light(at + Vector3(-2.5, 3.0, 0), Color("ffb070"), 1.6, 7.0)


## The bait-and-tackle hut over the hatch (x 11..16, z -56..-62). Its door is the first shortcut: bolted on the inside,
## opened on the way up from under the pier.
func _tackle_hut() -> void:
	var wall := Look.toon(Color("5a6a5a"))
	var pieces := [[Vector3(13.5, 1.5, -56.1), Vector3(5.0, 3.0, 0.2)], [Vector3(13.5, 1.5, -61.9), Vector3(5.0, 3.0, 0.2)],
		[Vector3(11.1, 1.5, -57.1), Vector3(0.2, 3.0, 1.8)], [Vector3(11.1, 1.5, -60.9), Vector3(0.2, 3.0, 1.8)],
		[Vector3(11.1, 2.8, -59.0), Vector3(0.2, 0.4, 2.2)]]
	if _have("tackle_hut"):
		# The weathered hut, rods and nets on its walls, its door west to the avenue: the walls are collision, the
		# hut's inside (the hatch) lined, the model with its door cut (props.py tackle_hut).
		for p: Array in pieces:
			_col(p[0], p[1], 1)
		_col(Vector3(13.5, 3.1, -59.0), Vector3(5.0, 0.2, 6.0), 1)
		_dress("tackle_hut", [Vector3(13.5, DECK, -59.0), -PI / 2.0, Vector3(6.0, 3.6, 5.0)])
		lining(Rect2(11.2, -61.8, 4.6, 5.6), 0.0, 3.0, wall, [["w", -60.0, -58.0, 2.6]])
	else:
		for p: Array in pieces:
			solid(p[0], p[1], wall)
		solid(Vector3(13.5, 3.1, -59.0), Vector3(5.0, 0.2, 6.0), _m.roof)
	_sign("BAIT & TACKLE", Vector3(10.95, 3.5, -59.0), -PI / 2.0, Color(1.2, 2.0, 1.4), 32)
	shortcut(&"trapdoor", Vector3(11.1, DECK, -59.0), PI / 2.0)


# --- under the pier --------------------------------------------------------------------------------------------------

func _under() -> void:
	# The beach under the promenade's edge, and the sandbar under the near half of the pier, out to the landing.
	solid(Vector3(0, SAND - 1.0, -4.0), Vector3(140, 2.0, 16.0), _m.sand)
	solid(Vector3(0, SAND - 1.0, -63.0), Vector3(44, 2.0, 102.0), _m.sand)
	# Pilings: under the Midway, rows every 10 m. Each sits just behind a cross-beam's line (+0.45 z), so the beam
	# runs clear of it.
	for k in range(1, 12):
		var z := -10.0 * k
		for x: float in [-15.0, -9.0, -3.0, 3.0, 9.0, 15.0]:
			_piling(Vector3(x, 0, z + 0.45))
		var cross := Beam.new()
		cross.length = 30.0
		cross.width = 0.3
		cross.material = _m.beam
		cross.position = Vector3(0, BEAM_Y, z)
		add_child(cross)
	for x: float in [-7.0, 0.0, 7.0]:
		_piling(Vector3(x, 0, -2.0))
	# Two stringers along the pier at x ±6, the length of the sandbar: the way along above the smugglers.
	for x: float in [-6.0, 6.0]:
		var s := Beam.new()
		s.length = 104.0
		s.width = 0.25
		s.material = _m.beam
		s.position = Vector3(x, BEAM_Y, -60.0)
		s.rotation.y = PI / 2.0
		add_child(s)
	# Marked posts up to the beams, beside the stringers.
	for p: Vector2 in [Vector2(-7.0, -16.0), Vector2(7.0, -46.0), Vector2(-7.0, -86.0), Vector2(7.0, -96.0)]:
		solid(Vector3(p.x, (SAND + BEAM_Y) / 2.0, p.y), Vector3(0.6, BEAM_Y - SAND, 0.6), _m.climb, 1 | 2)
	# The lifeguard hut: open to the middle, a wardrobe inside.
	var hut := Look.toon(Color("c84a3a"))
	solid(Vector3(-14.8, SAND + 1.5, -21.0), Vector3(0.4, 3.0, 6.0), hut)
	solid(Vector3(-13.0, SAND + 1.5, -18.2), Vector3(4.0, 3.0, 0.4), hut)
	solid(Vector3(-13.0, SAND + 1.5, -23.8), Vector3(4.0, 3.0, 0.4), hut)
	solid(Vector3(-13.0, SAND + 3.1, -21.0), Vector3(4.4, 0.2, 6.4), _m.white)
	_sign("LIFEGUARD", Vector3(-10.95, SAND + 2.6, -21.0), PI / 2.0, Color(2.2, 2.0, 1.8), 28)
	wardrobe(Vector3(-13.9, SAND, -21.0), -PI / 2.0, "Wardrobe_lifeguard")
	_light(Vector3(-12.0, SAND + 2.6, -21.0), Color("ffd8a0"), 1.6, 6.0)
	# The smugglers' landing, at the sandbar's far end: a jetty out to the west, a rowboat, crates, a lantern.
	solid(Vector3(-28.0, SAND + 0.4, -101.5), Vector3(14.0, 0.3, 3.0), _m.planks)
	for x: float in [-34.0, -28.0, -22.0]:
		solid(Vector3(x, SAND - 0.8, -100.2), Vector3(0.3, 2.2, 0.3), _m.timber)
		solid(Vector3(x, SAND - 0.8, -102.8), Vector3(0.3, 2.2, 0.3), _m.timber)
	if not props("rowboat", [[Vector3(-30.0, SEA - 0.25, -105.5), PI / 2.0]], false, 0.015):
		deco(Vector3(-30.0, SEA + 0.25, -105.5), Vector3(2.0, 0.6, 5.0), Look.toon(Color("6a4a3a")))
	var crates := []
	for i in 6:
		crates.append([Vector3(-15.0 + (i % 3) * 1.1, SAND + float(i / 3) * 1.0, -105.0), 0.0, Vector3.ONE])
	if not props("crate", crates):
		for c: Array in crates:
			solid((c[0] as Vector3) + Vector3(0, 0.5, 0), Vector3.ONE, _m.timber)
	_lamp(Vector3(-18.0, SAND, -100.0), false)
	_light(Vector3(-18.0, SAND + 3.4, -100.0), Color("ffb060"), 2.4, 9.0)
	_sign("HABERDASHERY", Vector3(-14.0, SAND + 1.0, -104.45), 0.0, Look.DECENCY_CREAM, 20, false)


func _piling(at: Vector3) -> void:
	var top := DECK - DECK_T
	var bottom := SEA - 2.0
	if _have("pier_piling"):
		# The iron-and-timber legs with their X brace and weed, over the post's collision (turned across the pier).
		_col(Vector3(at.x, (top + bottom) / 2.0, at.z), Vector3(0.5, top - bottom, 0.5), 1)
		_dress("pier_piling", [Vector3(at.x, bottom, at.z), 0.0, Vector3(1.8, top - bottom, 0.6)])
		return
	solid(Vector3(at.x, (top + bottom) / 2.0, at.z), Vector3(0.5, top - bottom, 0.5), _m.timber)


# --- Laffer's Fun Palace ---------------------------------------------------------------------------------------------

const PALACE_H := 9.0
## The office (x 6..18, z -138..-152) and the roof vent over it.
const VENT := Rect2(11.4, -146.6, 1.2, 1.2)


func _palace() -> void:
	solid(Vector3(0, -DECK_T / 2.0, -132.0), Vector3(40, DECK_T, 40), _m.planks)
	# The east walkway's way in: a strip of deck off the Midway's end, past the front wall's corner.
	solid(Vector3(18.0, -DECK_T / 2.0, -110.0), Vector3(4.0, DECK_T, 4.0), _m.planks)
	_railing(Vector3(16, DECK, -108), Vector3(20, DECK, -108))
	_railing(Vector3(20, DECK, -108), Vector3(20, DECK, -152))
	# The walkway down the east side ends at a tall fence; the west side is fenced off at the front.
	solid(Vector3(19.0, 2.0, -150.0), Vector3(2.0, 4.0, 0.2), _m.timber)
	_west_fence()
	_railing(Vector3(-20, DECK, -112), Vector3(-20, DECK, -152))
	_palace_body(PALACE_H)


## The west walkway's way in, Dash's cheat in the race (Key 1): a strip of deck over the Midway's west rail, with
## stacked crates up to the staff fence. Owner, Deck review 3: how she got over wasn't clear, and Nim could barely
## follow. Now it's a readable stair she can take too: hop the rail, onto the crate (1 m), the stack (2 m), the
## fence's capped top (3 m; the cap is deep enough to catch and stand on), and down onto the walkway.
const FENCE_TOP := 3.0
const CRATE_LOW := Vector3(-18.5, 0.0, -110.5)
const CRATE_HIGH := Vector3(-18.5, 0.0, -111.5)


func _west_fence() -> void:
	solid(Vector3(-18.0, -DECK_T / 2.0, -110.0), Vector3(4.0, DECK_T, 4.0), _m.planks)
	_railing(Vector3(-20, DECK, -108), Vector3(-16, DECK, -108))
	_railing(Vector3(-20, DECK, -108), Vector3(-20, DECK, -112))
	# The hoarding, and its cap: a beam 0.56 deep along the top (inside the palace's front wall's faces).
	solid(Vector3(-19.0, (FENCE_TOP - 0.2) / 2.0, -112.3), Vector3(2.0, FENCE_TOP - 0.2, 0.2), _m.timber)
	solid(Vector3(-19.0, FENCE_TOP - 0.1, -112.3), Vector3(2.0, 0.2, 0.56), _m.timber)
	_sign("STAFF\nONLY", Vector3(-19.5, 1.6, -112.19), 0.0, Look.DECENCY_CREAM, 20, false)   # beside the stack
	var crates := [[CRATE_LOW, 0.0, Vector3.ONE], [CRATE_HIGH, 0.0, Vector3.ONE],
		[CRATE_HIGH + Vector3(0, 1.0, 0), PI / 2.0, Vector3.ONE]]
	if not props("crate", crates):
		for c: Array in crates:
			solid((c[0] as Vector3) + Vector3(0, 0.5, 0), Vector3.ONE, _m.timber)
	_light(Vector3(-17.2, 3.4, -109.6), Color("ffb060"), 1.6, 6.0)


## The arcade itself: walls, roof, signs, the inside.
func _palace_body(h: float) -> void:
	# The front wall (z -112.3) with the door (x -1.5..1.5, 3.2 tall). With the Meshy jester front, it's collision
	# (the arcade's inside face lined), the front in front of it, its grinning mouth the door.
	var front := [[Vector3(-9.75, h / 2.0, -112.3), Vector3(16.5, h, 0.6)], [Vector3(9.75, h / 2.0, -112.3), Vector3(16.5, h, 0.6)],
		[Vector3(0, (3.2 + h) / 2.0, -112.3), Vector3(3.0, h - 3.2, 0.6)]]
	if _have("funhouse_front"):
		for p: Array in front:
			_col(p[0], p[1], 1)
		_dress("funhouse_front", [Vector3(0, DECK, -111.3), 0.0, Vector3(36.4, 13.0, 1.4)])
		for seg: Array in [[-9.75, 16.5, 0.0, h], [9.75, 16.5, 0.0, h], [0.0, 3.0, 3.2, h - 3.2]]:   # its inside face
			var q := MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(seg[1], seg[3])
			q.mesh = qm
			q.material_override = _m.palace
			q.rotation.y = PI   # facing -Z, into the arcade
			q.position = Vector3(seg[0], seg[2] + seg[3] / 2.0, -112.61)
			add_child(q)
	else:
		for p: Array in front:
			solid(p[0], p[1], _m.palace)
	# The side walls; the east one's marked from outside, for the climb to the roof.
	solid(Vector3(-17.7, h / 2.0, -132.0), Vector3(0.6, h, 40.0), _m.palace)
	solid(Vector3(17.7, h / 2.0, -132.0), Vector3(0.6, h, 40.0), _m.palace)
	# Marked panels run up to the roof's top (h + 0.4), so the climb ends in a pull-up onto it.
	solid(Vector3(18.1, (h + 0.4) / 2.0 - 0.025, -123.0), Vector3(0.2, h + 0.35, 6.0), _m.climb, 1 | 2)
	# The back wall (z -151.7), with the fire door at x -2; marked outside so she can climb back up from the platform.
	solid(Vector3(-10.4, h / 2.0, -151.7), Vector3(15.2, h, 0.6), _m.palace)
	solid(Vector3(8.4, h / 2.0, -151.7), Vector3(19.2, h, 0.6), _m.palace)
	solid(Vector3(-2.0, (2.6 + h) / 2.0, -151.7), Vector3(1.6, h - 2.6, 0.6), _m.palace)
	solid(Vector3(-11.0, (h + 0.4) / 2.0 - 0.025, -152.1), Vector3(6.0, h + 0.35, 0.2), _m.climb, 1 | 2)
	shortcut(&"fire_door", Vector3(-2.0, DECK, -151.7), PI)
	# The roof, with the vent's hole over the office, and the vent hoods around it.
	var r0 := Vector2(-18.0, -112.0)
	var r1 := Vector2(18.0, -152.0)
	_roof_around(r0, r1, VENT, h)
	# The vents sit on the roof's top (h + 0.4). Starting at h, their bottoms shared the ceiling's plane inside and
	# flickered against it.
	for v: Vector3 in [Vector3(-10, 0, -120), Vector3(-4, 0, -138), Vector3(4, 0, -124), Vector3(14, 0, -130)]:
		solid(Vector3(v.x, h + 0.4 + 0.6, v.z), Vector3(1.6, 1.2, 1.6), _m.white)
	deco(Vector3(VENT.position.x + 0.6, h + 0.4 + 0.5, VENT.position.y + 0.6 - 1.2), Vector3(1.4, 1.0, 0.12), _m.white)
	# The neon over the door.
	# (Over the jester's head, in front of the Meshy front; where they always were without it.)
	var nz := -110.5 if _have("funhouse_front") else -111.95
	var ny := 6.0 if _have("funhouse_front") else 0.0
	_sign("LAFFER'S", Vector3(0, 6.4 + ny, nz), 0.0, Color(2.4, 1.0, 0.4), 64)
	_sign("FUN PALACE", Vector3(0, 5.2 + ny, nz), 0.0, Color(2.4, 0.5, 1.2), 72)
	_sign("ha ha ha ha ha", Vector3(0, 4.2 + (ny if ny == 0.0 else -1.4), nz), 0.0, Color(1.0, 2.2, 1.2), 28)
	_light(Vector3(0, 4.5, -110.0), Color("ff70b0"), 3.0, 10.0)
	# Inside: rows of cabinets, their screens lit, facing east (stretched to the old boxes' 1.0 x 1.9 x 0.9, whose tops
	# the contraband and the routes use).
	var cabinets := []
	for x: float in [-13.0, -7.0, 3.0]:
		for i in 9:
			cabinets.append([Vector3(x, 0, -118.0 - i * 2.0), PI / 2.0, Vector3(0.9, 1.9, 1.0)])
	if not props("arcade_cabinet", cabinets, true, 0.012, 1.2):
		for c: Array in cabinets:
			var at: Vector3 = c[0]
			solid(at + Vector3(0, 0.95, 0), Vector3(1.0, 1.9, 0.9), _m.cabinet)
			deco(at + Vector3(0.51, 1.35, 0), Vector3(0.02, 0.6, 0.7), _m.screen)
	for p: Vector3 in [Vector3(-10, 6.0, -122), Vector3(0, 6.0, -134), Vector3(-10, 6.0, -144)]:
		_light(p, Color("d080ff"), 2.4, 12.0)
	# The prize counter along the back west, and behind it the prize wall: shelves 3.3 m tall, Key 7 on top, a marked
	# rolling ladder at its east end. The clerk works between them.
	solid(Vector3(-11.8, 0.55, -145.1), Vector3(11.6, 1.1, 1.0), _m.counter)
	solid(Vector3(-11.8, 1.65, -150.65), Vector3(11.6, 3.3, 1.5), _m.palace_in)
	for y: float in [0.2, 1.2, 2.2, 3.2]:
		deco(Vector3(-11.8, y, -149.85), Vector3(11.6, 0.08, 0.12), _m.timber)
	var prizes := []
	for y: float in [0.24, 1.24, 2.24]:
		for i in 9:
			prizes.append([Vector3(-16.6 + i * 1.2, y, -149.74), 0.0])
	if not props("prize_box", prizes, false):
		for p: Array in prizes:
			deco((p[0] as Vector3) + Vector3(0, 0.36, -0.1), Vector3(0.5, 0.5, 0.15), _m.pink)
	solid(Vector3(-6.6, 1.625, -149.8), Vector3(0.8, 3.25, 0.1), _m.climb, 1 | 2)
	_sign("PRIZES", Vector3(-11.8, 4.2, -149.85), 0.0, Color(2.4, 1.8, 0.6), 48)
	# The back office: walls to the roof, the door in its west wall (bolted inside), the safe, a desk.
	solid(Vector3(11.7, h / 2.0 - 0.02, -138.0), Vector3(11.4, h - 0.04, 0.4), _m.palace_in)   # short of the east wall and the roof
	solid(Vector3(6.0, h / 2.0, -141.0), Vector3(0.4, h, 6.0), _m.palace_in)
	solid(Vector3(6.0, h / 2.0 - 0.02, -148.8), Vector3(0.4, h - 0.04, 6.0), _m.palace_in)   # under the back wall's top
	solid(Vector3(6.0, (2.6 + h) / 2.0, -144.9), Vector3(0.4, h - 2.6, 1.8), _m.palace_in)
	shortcut(&"office", Vector3(6.0, DECK, -144.9), PI / 2.0)
	solid(Vector3(16.6, 0.7, -150.2), Vector3(1.4, 1.4, 1.2), Look.toon(Color("3a4048"), 0.5))
	deco(Vector3(16.6, 0.9, -149.58), Vector3(0.4, 0.4, 0.04), _m.brass)
	solid(Vector3(12.0, 0.4, -143.0), Vector3(2.4, 0.8, 1.2), _m.counter)
	_light(Vector3(12.0, 3.0, -145.0), Color("ffd090"), 1.6, 7.0)
	# The staff locker, just inside the door.
	wardrobe(Vector3(-17.0, DECK, -116.0), -PI / 2.0, "Wardrobe_locker")


## A flat roof over r0..r1 (x, z corners) at `h`, with a hole.
func _roof_around(r0: Vector2, r1: Vector2, hole: Rect2, h: float) -> void:
	var t := 0.4
	var y := h + t / 2.0
	var hx0 := hole.position.x
	var hx1 := hole.end.x
	var hz0 := hole.position.y
	var hz1 := hole.end.y
	# West of the hole, east of it, then north and south of it between.
	solid(Vector3((r0.x + hx0) / 2.0, y, (r0.y + r1.y) / 2.0), Vector3(hx0 - r0.x, t, r0.y - r1.y), _m.roof)
	solid(Vector3((hx1 + r1.x) / 2.0, y, (r0.y + r1.y) / 2.0), Vector3(r1.x - hx1, t, r0.y - r1.y), _m.roof)
	solid(Vector3((hx0 + hx1) / 2.0, y, (r0.y + hz1) / 2.0), Vector3(hx1 - hx0, t, r0.y - hz1), _m.roof)
	solid(Vector3((hx0 + hx1) / 2.0, y, (hz0 + r1.y) / 2.0), Vector3(hx1 - hx0, t, hz0 - r1.y), _m.roof)


# --- the Big Dipper and the wheel ------------------------------------------------------------------------------------

func _pier_end() -> void:
	solid(Vector3(0, -DECK_T / 2.0, -205.0), Vector3(80, DECK_T, 106), _m.planks)
	for k in range(0, 9):
		for x in range(-38, 39, 8):
			_piling(Vector3(x, 0, -158.0 - k * 12.0))
	for k in range(0, 4):
		for x: float in [-19.0, -12.0, -4.0, 4.0, 12.0, 19.0]:
			_piling(Vector3(x, 0, -116.0 - k * 10.0))
	_railing(Vector3(-40, DECK, -152), Vector3(-40, DECK, -258))
	_railing(Vector3(40, DECK, -152), Vector3(40, DECK, -258))
	_railing(Vector3(-40, DECK, -152), Vector3(-20, DECK, -152))
	_railing(Vector3(20, DECK, -152), Vector3(40, DECK, -152))
	# The wheel, its A-frame legs, the boarding step beside the cars' path, and the crown over the top (Key 8).
	wheel = FerrisWheel.new()
	wheel.name = "FerrisWheel"
	wheel.position = WHEEL
	add_child(wheel)
	for sx: float in [-2.6, 2.6]:
		for sz: float in [-9.0, 9.0]:
			var foot := Vector3(WHEEL.x + sx, DECK, WHEEL.z + sz)
			_strut(foot, Vector3(WHEEL.x + sx, WHEEL.y, WHEEL.z), 0.5, _m.white, true)
	solid(Vector3(WHEEL.x - 3.3, 0.8, WHEEL.z), Vector3(1.6, 1.6, 4.0), _m.velvet)
	solid(Vector3(WHEEL.x - 4.6, 0.4, WHEEL.z), Vector3(1.0, 0.8, 4.0), _m.velvet)
	var crown_x := WHEEL.x + 3.6
	var crown_top := WHEEL.y + 12.8
	_strut(Vector3(WHEEL.x + 2.6, WHEEL.y, WHEEL.z), Vector3(crown_x, crown_top - 0.2, WHEEL.z), 0.3, _m.white, false)
	solid(Vector3(crown_x, crown_top - 0.1, WHEEL.z), Vector3(1.6, 0.2, 1.6), _m.brass)
	deco(Vector3(crown_x, crown_top + 1.4, WHEEL.z), Vector3(0.3, 0.3, 0.3), _m.lit)
	_light(Vector3(crown_x, crown_top + 1.6, WHEEL.z), Color("ffd8a0"), 2.0, 8.0)
	_sign("THE BIG WHEEL", Vector3(WHEEL.x - 5.2, 3.0, WHEEL.z), PI / 2.0, Color(2.2, 1.8, 0.9), 40)
	_light(Vector3(WHEEL.x - 6.0, 4.0, WHEEL.z), Color("ffb070"), 2.4, 12.0)
	# The coaster's station: the boarding platform west of the track (x 27.5); the track, its cars and the chase are
	# levels/pier/keys/dipper.gd.
	solid(Vector3(20.8, 0.7, -164.0), Vector3(11.6, 1.4, 8.0), _m.planks_dry)
	solid(Vector3(14.0, 0.35, -164.0), Vector3(2.0, 0.7, 4.0), _m.planks_dry)
	deco(Vector3(22.0, 5.2, -164.0), Vector3(15.0, 0.3, 9.0), _m.velvet)
	for p: Vector2 in [Vector2(15.4, -160.2), Vector2(26.3, -160.2), Vector2(15.4, -167.8), Vector2(26.3, -167.8)]:
		solid(Vector3(p.x, 3.3, p.y), Vector3(0.3, 3.8, 0.3), _m.white)
	_sign("THE BIG DIPPER", Vector3(22.0, 6.0, -159.4), 0.0, Color(2.4, 0.7, 0.6), 64)
	_light(Vector3(22.0, 4.4, -164.0), Color("ff9060"), 2.4, 10.0)


## A stretch of coaster track: two rails, sleepers, and a strut down to the deck every few metres (drawn only).
func track(a: Vector3, b: Vector3) -> void:
	var d := b - a
	var flat := Vector3(d.x, 0, d.z).normalized()
	var side := Vector3(-flat.z, 0, flat.x)
	for s: float in [-0.6, 0.6]:
		_strut(a + side * s, b + side * s, 0.12, _m.rail, false)
	var n := maxi(1, int(d.length() / 4.0))
	for i in n:
		var p := a.lerp(b, float(i) / n)
		deco(p + Vector3(0, -0.08, 0), Vector3(1.5, 0.08, 0.25) if absf(flat.x) < 0.5 else Vector3(0.25, 0.08, 1.5), _m.timber)
		if p.y > 1.6:
			_strut(Vector3(p.x, DECK, p.z), p + Vector3(0, -0.12, 0), 0.22, _m.white, false)


# --- the Prize Hall --------------------------------------------------------------------------------------------------

func _hall() -> void:
	solid(Vector3(0, -DECK_T / 2.0, -278.0), Vector3(52, DECK_T, 40), _m.planks)
	for k in range(0, 4):
		for x: float in [-24.0, -16.0, -8.0, 0.0, 8.0, 16.0, 24.0]:
			_piling(Vector3(x, 0, -262.0 - k * 10.0))
	var h := 16.0
	solid(Vector3(-12.5, h / 2.0, -258.3), Vector3(19.0, h, 0.6), _m.hall)
	solid(Vector3(12.5, h / 2.0, -258.3), Vector3(19.0, h, 0.6), _m.hall)
	solid(Vector3(0, (5.0 + h) / 2.0, -258.3), Vector3(6.0, h - 5.0, 0.6), _m.hall)
	solid(Vector3(-21.7, h / 2.0, -278.0), Vector3(0.6, h, 40.0), _m.hall)
	solid(Vector3(21.7, h / 2.0, -278.0), Vector3(0.6, h, 40.0), _m.hall)
	solid(Vector3(0, h / 2.0, -297.7), Vector3(44.0, h, 0.6), _m.hall)
	solid(Vector3(0, h + 0.2, -278.0), Vector3(44.0, 0.4, 40.0), _m.roof)
	# Shut until Laffer's fight (WO-014 step 4).
	var shutter := block(Vector3(0, 2.5, -258.0), Vector3(6.0, 5.0, 0.3), Look.toon(Color("6a6a74"), 0.4))
	shutter.name = "HallShutter"
	_sign("CLOSED FOR STOCKTAKING", Vector3(0, 2.6, -257.8), 0.0, Look.DECENCY_CREAM, 28, false).name = "ShutterSign"
	if _have("prize_hall_front"):
		# The Edwardian front (sunburst gable, bulbs), over the front wall; its doorway cut over the shutter's.
		_dress("prize_hall_front", [Vector3(0, DECK, -257.2), 0.0, Vector3(44.6, 19.0, 1.6)])
		_sign("PRIZE HALL", Vector3(0, 9.0, -256.2), 0.0, Color(2.4, 1.9, 0.6), 96)
	else:
		_sign("PRIZE HALL", Vector3(0, 9.0, -257.95), 0.0, Color(2.4, 1.9, 0.6), 96)
	_light(Vector3(0, 7.0, -255.0), Color("ffc860"), 3.0, 12.0)
	_railing(Vector3(-26, DECK, -258), Vector3(-26, DECK, -298))
	_railing(Vector3(26, DECK, -258), Vector3(26, DECK, -298))


# --- the sea ---------------------------------------------------------------------------------------------------------

func _sea() -> void:
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(600, 700)
	water.mesh = plane
	water.position = Vector3(0, SEA, -150)
	water.material_override = Look.toon(Color("101c34"), 0.9)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	# In the sea: back to the last checkpoint, a little damp. Nothing lost.
	var splash := Area3D.new()
	splash.name = "Sea"
	splash.collision_layer = 0
	splash.collision_mask = 1
	var shape := BoxShape3D.new()
	shape.size = Vector3(600, 2, 700)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0, SEA - 1.4, -150)
	splash.add_child(col)
	add_child(splash)
	splash.body_entered.connect(func(b: Node) -> void:
		if b is Nim:
			nim.teleport(spawn_at, spawn_yaw)
			cam.set(&"yaw", spawn_yaw))


# --- people ----------------------------------------------------------------------------------------------------------

func _people() -> void:
	# The Midway's goons on their rounds, and one minding the tackle hut.
	_goon(&"m_rounds1", Vector3(3, 0.05, -10), [Vector3(3, 0, -10), Vector3(3, 0, -50)])
	_goon(&"m_rounds2", Vector3(-3, 0.05, -60), [Vector3(-3, 0, -60), Vector3(-3, 0, -104)])
	_goon(&"m_tackle", Vector3(9.0, 0.05, -64.0), [], PI / 2.0)
	# The bouncer at the Fun Palace door, looking down the Midway.
	_goon(&"bouncer", Vector3(0, 0.05, -110.0), [], PI, "badger_bouncer")
	# Inside the Fun Palace: one on his rounds, one by the office.
	_goon(&"p_rounds", Vector3(-4, 0.05, -118), [Vector3(-4, 0, -118), Vector3(-4, 0, -140)])
	_goon(&"p_office", Vector3(4.5, 0.05, -144.0), [], -PI / 2.0)
	# Under the pier: the lesson's four (Vesper takes the first, Nim the next three; step 2), and the landing crew.
	_goon(&"u_lesson1", Vector3(-3.0, SAND + 0.05, -30.0), [], PI / 2.0)
	_goon(&"u_lesson2", Vector3(-6.0, SAND + 0.05, -42.0), [], 0.0)
	_goon(&"u_lesson3", Vector3(0.0, SAND + 0.05, -50.0), [], -PI / 2.0)
	_goon(&"u_lesson4", Vector3(6.0, SAND + 0.05, -58.0), [], PI)
	_goon(&"u_crew1", Vector3(-12.0, SAND + 0.05, -100.0), [Vector3(-12, SAND, -100), Vector3(-4, SAND, -100)])
	_goon(&"u_crew2", Vector3(-6.0, SAND + 0.05, -110.0), [], PI / 2.0)
	_goon(&"u_crew3", Vector3(6.0, SAND + 0.05, -104.0), [], -PI / 2.0)
	# The fourth has bound himself already, practising (Key 2's joke): he's tied from the start.
	Game.set_flag("bound/pier/u_crew4")
	_goon(&"u_crew4", Vector3(12.0, SAND + 0.05, -108.0), [], PI / 2.0)
	# The prize counter's clerk (Key 7), behind the counter: tell him to kneel, then round the counter's end and up the
	# shelves for the top one. Standing, he'd watch her climb (and in the suit that costs Composure).
	var clerk := Staff.new()
	clerk.name = "Clerk"
	clerk.speaker = "Clerk"
	clerk.look_body = "meerkat_watch"   # the Pier doesn't use meerkats; he's the meek one
	clerk.kneel_line = "Oh. Oh, finally. Thank you, Mistress."   # OWNER REVIEW
	clerk.position = Vector3(-11.8, 0.05, -147.2)
	clerk.rotation.y = PI
	add_child(clerk)
	# Gulls: on posts down the Midway and on the coaster's station.
	_gull(Vector3(-7.0, DECK, -32.0), 0.0)
	_gull(Vector3(7.0, DECK, -72.0), PI)
	_gull(Vector3(-7.0, DECK, -100.0), 0.0)
	_gull(Vector3(30.5, DECK, -170.0), PI / 2.0)
	# The crowd on the Midway: knots of people at the stalls (walk among them in the suit and she's one of them).
	var colours := [Color("b08a6a"), Color("8a6a9a"), Color("6a8aa0"), Color("a07a5a"), Color("9a9a7a"), Color("7a9a8a")]
	var knots := [[Vector3(-7.5, 0, -27.0), 4], [Vector3(-7.5, 0, -33.0), 3], [Vector3(7.0, 0, -38.0), 4],
		[Vector3(-7.5, 0, -54.0), 3], [Vector3(7.0, 0, -76.0), 4], [Vector3(-7.5, 0, -94.0), 3], [Vector3(6.0, 0, -16.0), 3]]
	var i := 0
	for k: Array in knots:
		var c: Vector3 = k[0]
		for j in int(k[1]):
			var g := Guest.new()
			var a := TAU * j / float(k[1])
			g.position = c + Vector3(cos(a), 0, sin(a)) * 0.9
			g.look_yaw = atan2(c.x - g.position.x, c.z - g.position.z) + PI
			g.colour = colours[i % colours.size()]
			g.look_body = CIVILIANS[(i * 3 + 1) % CIVILIANS.size()]
			add_child(g)
			i += 1


func _goon(id: StringName, at: Vector3, route: Array, yaw := 0.0, body := "weasel_goon") -> Enemy:
	var g := Enemy.new()
	g.id = id
	g.name = "Goon_%s" % id
	g.body = body
	g.patrol = PackedVector3Array(route)
	g.position = at
	g.rotation.y = yaw
	add_child(g)
	return g


func _gull(at: Vector3, watch: float) -> Lookout:
	var bird := Lookout.new()
	bird.name = "Gull_%d" % get_child_count()
	bird.position = at
	bird.perch_height = 3.6
	bird.look_body = "gull_lookout"
	bird.watch_yaw = watch
	add_child(bird)
	return bird


# --- collectibles ----------------------------------------------------------------------------------------------------

func _collectibles() -> void:
	# The Coalition's collection tin, on the gate.
	tin(Vector3(5.5, DECK, 3.2), 0.0)
	# Keys placed in step 1: the prize counter's top shelf (7) and the wheel's crown (8). The rest come from their
	# scripts in step 2; Key 10 is paid by the five sleepers.
	key(&"pier_07", Vector3(-11.8, 3.3, -150.6))
	key(&"pier_08", Vector3(WHEEL.x + 3.6, WHEEL.y + 12.8, WHEEL.z))
	# The five prize winners, humming along with their plushies.
	sleeper(&"s1", Vector3(-20, 0.05, 16), PackedVector3Array([Vector3(-20, 0, 16), Vector3(10, 0, 16), Vector3(10, 0, 20), Vector3(-20, 0, 20)]),
		"otter_civilian", Color("c8a0d0"))
	sleeper(&"s2", Vector3(-4, 0.05, -22), PackedVector3Array([Vector3(-4, 0, -22), Vector3(-4, 0, -40), Vector3(0, 0, -40), Vector3(0, 0, -22)]),
		"hedgehog_civilian", Color("a0c0d8"))
	sleeper(&"s3", Vector3(4, 0.05, -60), PackedVector3Array([Vector3(4, 0, -60), Vector3(4, 0, -86), Vector3(1, 0, -86), Vector3(1, 0, -60)]),
		"fox_civilian", Color("e0c890"))
	sleeper(&"s4", Vector3(-10, 0.05, -120), PackedVector3Array([Vector3(-10, 0, -120), Vector3(-10, 0, -138), Vector3(-9.6, 0, -138), Vector3(-9.6, 0, -120)]),
		"hare_civilian", Color("a8d0a8"))
	sleeper(&"s5", Vector3(-15, 0.05, -196), PackedVector3Array([Vector3(-15, 0, -196), Vector3(-15, 0, -214), Vector3(-12, 0, -214), Vector3(-12, 0, -196)]),
		"otter_civilian", Color("d8b0a0"))
	# 100 contraband.
	# The promenade: on the beach huts' roofs (5).
	for i in 5:
		_cb(Vector3(22.0 + i * 8.0, 3.0, 9.5))
	# Under the pier (40): along the stringers, rows on the sand both sides, and the landing's stack.
	for z: float in [-25.0, -35.0, -45.0, -55.0, -65.0]:
		_cb(Vector3(-6.0, BEAM_Y + 0.05, z))
	for z: float in [-30.0, -50.0, -70.0, -80.0, -90.0]:
		_cb(Vector3(6.0, BEAM_Y + 0.05, z))
	for i in 10:
		_cb(Vector3(-18.5, SAND, -14.0 - i * 8.0))
		_cb(Vector3(18.5, SAND, -14.0 - i * 8.0))
	for i in 10:
		_cb(Vector3(-17.5 + (i % 5) * 1.6, SAND, -108.0 - float(i / 5) * 1.4))
	# The Midway (25): five on each of five counters.
	for st: Array in [[-1, -16.0], [-1, -74.0], [-1, -95.0], [1, -16.0], [1, -96.0]]:
		var x := 16.0 * float(st[0]) - float(st[0]) * 5.7
		for j in 5:
			_cb(Vector3(x, 1.0, float(st[1]) + 2.4 - j * 1.2))
	# The Fun Palace (12): cabinet tops, the prize counter, the office, the roof.
	for i in 4:
		_cb(Vector3(-13.0, 1.9, -120.0 - i * 4.0))
	for i in 4:
		_cb(Vector3(-15.8 + i * 2.6, 1.1, -145.1))
	_cb(Vector3(12.0, 0.8, -143.0))
	_cb(Vector3(14.0, DECK, -149.0))
	_cb(Vector3(-14.0, PALACE_H + 0.4, -140.0))
	_cb(Vector3(14.0, PALACE_H + 0.4, -116.0))
	# The pier's end (8): the wheel's step, the coaster station, the crown.
	for i in 3:
		_cb(Vector3(WHEEL.x - 3.3, 1.6, WHEEL.z - 1.2 + i * 1.2))
	for i in 3:
		_cb(Vector3(18.0 + i * 3.0, 1.4, -166.5))
	_cb(Vector3(WHEEL.x + 3.2, WHEEL.y + 12.8, WHEEL.z - 0.5))
	_cb(Vector3(WHEEL.x + 4.0, WHEEL.y + 12.8, WHEEL.z + 0.5))
	# The Prize Hall's stash (10), along its west wall, behind the shutter until the fight.
	for i in 10:
		_cb(Vector3(-20.0, DECK, -262.0 - i * 2.0))


func _cb(at: Vector3) -> void:
	_contraband += 1
	contraband(StringName("c%03d" % _contraband), at)


# --- the Keys' scripts (WO-014 step 2; levels/pier/keys/) ------------------------------------------------------------

const KEY_SCRIPTS := {
	"DashRace": "res://levels/pier/keys/dash_race.gd",
	"VesperLesson": "res://levels/pier/keys/vesper_lesson.gd",
	"Landing": "res://levels/pier/keys/landing.gd",
	"Gallery": "res://levels/pier/keys/gallery.gd",
	"Striker": "res://levels/pier/keys/striker.gd",
	"Pearl": "res://levels/pier/keys/pearl.gd",
	"Safe": "res://levels/pier/keys/safe.gd",
	"WheelVesper": "res://levels/pier/keys/wheel_vesper.gd",
	"Dipper": "res://levels/pier/keys/dipper.gd",
	"Laffer": "res://levels/pier/keys/laffer.gd",
}


func _keys() -> void:
	for n: String in KEY_SCRIPTS:
		var k := Node3D.new()
		k.set_script(load(KEY_SCRIPTS[n]))
		k.name = n
		add_child(k)


# --- places: zones, checkpoints, fast travel -------------------------------------------------------------------------

func _places() -> void:
	zone("The Promenade", Vector3(0, -0.5, 19), Vector3(140, 14, 30))
	zone("The Midway", Vector3(0, -0.2, -58), Vector3(32, 12, 108))
	zone("Under the Pier", Vector3(0, -9.5, -56), Vector3(140, 9.0, 120))
	zone("Laffer's Fun Palace", Vector3(0, -0.2, -132), Vector3(40, 12, 40))
	zone("The Big Dipper", Vector3(0, -0.2, -205), Vector3(80, 34, 106))
	zone("The Prize Hall", Vector3(0, -0.2, -278), Vector3(52, 20, 40))
	checkpoint_at(Vector3(0, DECK, 20), 0.0)
	checkpoint_at(Vector3(0, DECK, -2), 0.0)
	checkpoint_at(Vector3(-56, SAND, 1.5), PI / 2.0)
	checkpoint_at(Vector3(-9, SAND, -21), 0.0)
	checkpoint_at(Vector3(0, DECK, -60), 0.0)
	checkpoint_at(Vector3(4, DECK, -106), 0.0)
	checkpoint_at(Vector3(0, DECK, -160), 0.0)
	checkpoint_at(Vector3(0, DECK, -252), 0.0)
	travel_point(&"promenade", "The Promenade", Vector3(-4, DECK, 24))
	travel_point(&"midway", "The Midway", Vector3(-6, DECK, -46))
	travel_point(&"palace", "The Fun Palace", Vector3(8, DECK, -106))
	travel_point(&"end", "The Pier's End", Vector3(-6, DECK, -172))


