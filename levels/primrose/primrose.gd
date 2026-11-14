class_name Primrose
extends BuiltWorld
## World 2, Primrose Close (docs/worlds/02_PRIMROSE_CLOSE.md; data/worlds/primrose.json). WO-015 step 1: the layout, all
## six areas, built in code with the painted shaders, at night in a light rain (Key 4 is the steeple "in the rain"),
## with everything a world has placed. Step 2: the Keys' scripts, Vesper's lesson and the curtain twitchers
## (levels/primrose/keys/, KEY_SCRIPTS). The demonstration party and Mrs Gander come in the next steps (WORK_ORDERS
## WO-015 "Build order").
##
## The Close runs north (-Z) from its entrance on Primrose Lane. The ground is y 0; pavements are 0.12 up, lawns 0.08.
## Sized by Banjo's lessons (DESIGN.md "Sizing"): one street you can see down end to end, the church's steeple the
## landmark from everywhere, every area a short walk off the street.
##
##   The Close          x -17..17   z 8..-113     the road (x -5..5) with pavements and lawns, seven houses a side
##                                               (the east side's fourth plot is Church Path), two more at the turning
##                                               head (z -90..-110), the Neighbourhood Watch hut and the postbox at
##                                               the entrance, the OLD QUARTER arch home at z 6
##   The Back Gardens   x ±24..±46  z -4..-88     behind the houses: fences between them (walk their tops), a washing
##                                               line down each side (x ±35, 2.4 m up), sheds, greenhouses, a paddling
##                                               pool, the delivery van stuck in number 9's garden (Key 8)
##   St. Prudence's     x 48..100   z 2..-90      the church hall (x 54..82, z -24..-52: bake sale, raffle, stage), its
##                                               bell tower and steeple on the north side (x 62..68, z -52..-58; a
##                                               marked climb to the belfry at 14 m, the spire to 24), the vicarage
##                                               (x 86..98), the churchyard; Church Path in from the Close at z -46
##   The Allotments     x -48..-96  z 6..-120     plots, sheds, polytunnels, the prize marrows (Key 5's stash), behind a
##                                               hedge at x -48 with its gap at z -112 (the first shortcut); in by
##                                               Allotment Lane from the entrance (z 2..6)
##   The Show Home      x -12..12   z -116..-136  Mrs Gander's house at the head of the Close; its living room is open
##                                               (the demonstration party, step 3)
##   The Conservatory   x -22..22   z -136..-176  her glass conservatory and topiary garden behind high hedges: closed
##     and Garden                                 (a locked back door) until the party's done (step 4's fight)

const SPAWN := Vector3(0, 0.05, 4.0)
const PAVE := 0.12
const LAWN := 0.08
const ROAD_W := 5.0
## The houses along the straight: plot k's middle is z = -10 - 12 k. Church Path takes the east side's plot 3.
const PLOT := 12.0
const PATH_Z := -46.0
## The bell tower: its outside north face is marked from the ground to the belfry floor.
const TOWER := Vector3(65.0, 0.0, -55.0)
const BELFRY := 14.0
const SPIRE := 24.0
const HALL_DOOR_Z := -46.0
## The washing lines' height: a jump up from a fence top (1.8) reaches them; from a lawn nothing does.
const LINE_Y := 3.7
## The neighbours (WO-014 step 6's people): tinted per person.
const CIVILIANS := ["otter_civilian", "hare_civilian", "fox_civilian", "hedgehog_civilian"]

## Lit net-curtain windows ([centre, outward normal]): the curtain twitchers (step 2 gives them eyes: garb gets
## spotted, the suit doesn't).
var curtains: Array = []

var _m := {}
var _contraband := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	world_id = &"primrose"
	load_data()
	_rng.seed = 22
	_materials()
	_environment()
	_ground()
	_close()
	_gardens()
	_church()
	_allotments()
	_show_home()
	_garden()
	_people()
	_collectibles()
	_places()
	_place_lamps()
	_place_dressing()
	_rain()
	_flush()
	arrival("start", SPAWN, 0.0)
	arrival("hub", SPAWN, 0.0)   # in from Primrose Lane, under the arch, facing up the Close
	spawn_player(SPAWN, 0.0)
	_keys()
	finish()


# --- materials and light ---------------------------------------------------------------------------------------------

func _materials() -> void:
	_m.tarmac = Look.painted(Look.Pattern.PLASTER, Color("2c2a32"), Color("121016"), {"wet": 0.85, "puddles": 0.4})
	_m.pave = Look.painted(Look.Pattern.FLAGSTONES, Color("5c5866"), Color("201c26"), {"wet": 0.8, "puddles": 0.3})
	_m.lawn = Look.painted(Look.Pattern.PLASTER, Color("3e5a34"), Color("142010"), {"wet": 0.4, "stroke": 0.3})
	_m.soil = Look.painted(Look.Pattern.PLASTER, Color("3a2c22"), Color("120c08"), {"wet": 0.6, "stroke": 0.25})
	_m.hedge = Look.painted(Look.Pattern.PLASTER, Color("2a4228"), Color("0c160a"), {"wet": 0.3, "stroke": 0.45, "scale": 2.2})
	_m.brick = Look.painted(Look.Pattern.BRICK, Color("7a4a3c"), Color("241614"), {"wet": 0.55})
	_m.brick2 = Look.painted(Look.Pattern.BRICK, Color("8a6248"), Color("2a1c14"), {"wet": 0.55})
	_m.render = Look.painted(Look.Pattern.PLASTER, Color("b8ac98"), Color("3a3428"), {"wet": 0.45})
	_m.render2 = Look.painted(Look.Pattern.PLASTER, Color("a8b0a0"), Color("2e342a"), {"wet": 0.45})
	_m.stone = Look.painted(Look.Pattern.BRICK, Color("6e6a64"), Color("201e1c"), {"wet": 0.6, "scale": 1.6})
	_m.climb = Look.painted(Look.Pattern.BRICK, Color("4f8a5a"), Color("173020"), {"wet": 0.5, "scale": 1.6})
	_m.slate = Look.painted(Look.Pattern.SLATE, Color("2e3444"), Color("0e1018"), {"wet": 0.9})
	_m.tile = Look.painted(Look.Pattern.SLATE, Color("5a3028"), Color("1a0c0a"), {"wet": 0.85})
	_m.planks = Look.painted(Look.Pattern.PLANKS, Color("5e4c40"), Color("1a120e"), {"wet": 0.3})
	_m.floor = Look.painted(Look.Pattern.PLANKS, Color("6a4e3a"), Color("20140c"), {"wet": 0.0})
	_m.hall_in = Look.painted(Look.Pattern.PLASTER, Color("8a8070"), Color("2a261e"), {"wet": 0.0})
	_m.carpet = Look.toon(Color("6a3a4a"))
	_m.fence = Look.toon(Color("6a5442"))
	_m.shed = Look.toon(Color("4a5a3a"))
	_m.white = Look.toon(Color("e8e0d0"), 0.2)
	_m.cream = Look.toon(Look.DECENCY_CREAM)
	_m.navy = Look.toon(Color("24304e"))
	_m.ink = Look.toon(Look.INK)
	_m.brass = Look.toon(Look.BRASS, 0.6)
	_m.red = Look.toon(Color("b02a2a"), 0.3)
	_m.door = Look.toon(Color("3a2a4a"))
	_m.glass = Look.toon(Color("0d1424"), 0.8)
	_m.greenhouse = Look.toon(Color("9ac8c0"), 0.9, 0.3)
	# Her conservatory's glass, see-through: the tantrum (the boss's third phase) is fought inside it, seen from out.
	var conserv := StandardMaterial3D.new()
	conserv.albedo_color = Color(0.7, 0.9, 0.88, 0.18)
	conserv.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	conserv.roughness = 0.05
	conserv.metallic_specular = 0.9
	conserv.cull_mode = BaseMaterial3D.CULL_DISABLED
	_m.conservatory = conserv
	_m.marrow = Look.toon(Color("4a7a30"), 0.2)
	_m.pool = Look.toon(Color("4aa0d8"), 0.6)
	_m.topiary = Look.painted(Look.Pattern.PLASTER, Color("2e5a2c"), Color("0c1a0a"), {"wet": 0.2, "stroke": 0.5, "scale": 2.6})
	_m.net = _unlit(Color(2.0, 1.7, 1.15))    # a lit net curtain: warm, soft
	_m.lamp = _unlit(Color(2.0, 1.4, 0.8))
	_m.stained = _unlit(Color(1.4, 0.6, 1.0))


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0e0c1e")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("3e3c6a")
	env.ambient_light_energy = 0.6
	env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color("201c3a")
	env.fog_density = 0.011
	env.fog_height = 1.0
	env.fog_height_density = 0.08
	env.glow_enabled = true
	env.glow_intensity = 0.75
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Look.MOON
	moon.light_energy = 0.5
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 60.0
	moon.rotation = Vector3(deg_to_rad(-50), deg_to_rad(-140), 0)
	add_child(moon)


# --- the ground ------------------------------------------------------------------------------------------------------

func _ground() -> void:
	# Tarmac everywhere (the road is the ground); pavements, lawns and beds sit on it.
	solid(Vector3(0, -0.5, -86.0), Vector3(204, 1, 200), _m.tarmac)   # x -102..102, z 14..-186


# --- the Close -------------------------------------------------------------------------------------------------------

func _close() -> void:
	# Pavements down both sides of the road, and round the turning head.
	for s: float in [-1.0, 1.0]:
		_pave(Vector3(s * 6.5, 0, -42.0), Vector3(3.0, 0, 96.0))        # z 6..-90
		_pave(Vector3(s * 15.5, 0, -101.5), Vector3(3.0, 0, 23.0))      # the head's sides, z -90..-113
	_pave(Vector3(0, 0, -111.5), Vector3(28.0, 0, 3.0))                 # the head's north edge (x -14..14)
	# The entrance: a pavement across the mouth, Allotment Lane west from it, and the arch home.
	_pave(Vector3(-29.0, 0, 4.0), Vector3(42.0, 0, 4.0))                # x -50..-8, z 2..6
	_pave(Vector3(29.0, 0, 4.0), Vector3(42.0, 0, 4.0))                 # x 8..50: round to the churchyard
	_arch()
	_sign("PRIMROSE CLOSE", Vector3(-9.0, 2.4, 1.9), 0.0, Color("e8e0d0"), 30, false)
	solid(Vector3(-9.0, 1.2, 1.95), Vector3(0.12, 2.4, 0.12), _m.ink)
	deco(Vector3(-9.0, 2.4, 1.97), Vector3(2.4, 0.5, 0.06), _m.white)
	# The postbox and the Neighbourhood Watch hut, at the entrance's east corner (Vesper's lesson, step 2).
	if _has_prop("postbox"):
		_put("postbox", Vector3(7.4, PAVE, -3.0), -PI / 2.0)   # its slot to the road
	else:
		solid(Vector3(7.4, 0.75 + PAVE, -3.0), Vector3(0.6, 1.5, 0.6), _m.red)
	_watch_hut(Vector3(11.0, LAWN, -1.0))
	# Cars parked at the kerb, nose to tail with the traffic (left-hand side of the road): northbound on the west,
	# southbound on the east. A goon's beat runs 1 m inside them (x ±2.5), so they're cover, not walls in the way.
	for c: Array in [[-1.0, -40.0], [-1.0, -78.0], [1.0, -16.0], [1.0, -58.0]]:
		var s: float = c[0]
		_put("family_car", Vector3(s * 4.1, 0.0, c[1]), PI / 2.0 * s, Vector3(3.9, 1.75, 1.9))
	# The houses: seven a side along the road (number 1 at the entrance, odd west, even east), Church Path in the
	# east side's fourth plot, two at the turning head.
	var n := 1
	for k in 7:
		var z := -10.0 - PLOT * k
		_plot(-1.0, z, n)
		n += 2
	n = 2
	for k in 7:
		var z := -10.0 - PLOT * k
		if absf(z - PATH_Z) < 1.0:
			_church_path(z)
			continue
		_plot(1.0, z, n)
		n += 2
	_head_house(-1.0, 15)
	_head_house(1.0, 16)
	# Street lamps down the road and round the head.
	for z: float in [-4.0, -28.0, -52.0, -76.0]:
		for s: float in [-1.0, 1.0]:
			_lamp(Vector3(s * 7.6, PAVE, z - (6.0 if s > 0 else 0.0)))   # (east ones clear of Church Path's mouth)
	_lamp(Vector3(-15.0, PAVE, -110.0))
	_lamp(Vector3(15.0, PAVE, -110.0))


func _pave(at: Vector3, size: Vector3) -> void:
	solid(Vector3(at.x, PAVE / 2.0, at.z), Vector3(size.x, PAVE, size.z), _m.pave)


## A front plot on the west (side -1) or east (+1) of the road, centred on z: lawn, path, drive, the house, its
## SWYNE FOR DECENCY sign. Number 4 is Grizelda's old house, for sale (a wardrobe in its porch).
func _plot(side: float, z: float, number: int) -> void:
	var out := Vector3(-side, 0, 0)   # the house's front faces the road
	# The lawn (x ±8..±14), with the front path and the drive cut through it as pavement.
	solid(Vector3(side * 11.0, LAWN / 2.0, z + 1.6), Vector3(6.0, LAWN, 8.8), _m.lawn)
	solid(Vector3(side * 11.0, LAWN / 2.0, z - 5.4), Vector3(6.0, LAWN, 1.2), _m.lawn)
	_pave(Vector3(side * 11.0, 0, z - 3.9), Vector3(6.0, 0, 1.6))   # the drive / path to the door, z -3.1..-4.7
	var wall: Material = [_m.brick, _m.render, _m.brick2, _m.render2][(number / 2) % 4]
	_house(Vector3(side * 19.0, 0, z), out, 9.0, 10.0, 7.0, wall, -3.0 * side)   # its door at the path (z - 3.9)
	if number == 4:
		_sale_sign(Vector3(side * 9.2, LAWN, z + 3.0), out)
		wardrobe(Vector3(side * 13.4, PAVE, z - 3.9), PI / 2.0 if side > 0 else -PI / 2.0, "Wardrobe_number4")
	else:
		_lawn_sign(Vector3(side * 9.0, LAWN, z + 3.4), out)
	_sign(str(number), Vector3(side * 13.92, 2.9, z - 3.9 + 1.1), PI / 2.0 if side > 0 else -PI / 2.0, Color("e8d090"), 26, false)
	# The front garden's furniture, facing the road: the bin by the house, and (not every house the same) a gnome
	# and a bird bath on the lawn's far side, clear of the mowers' strips (x ±9.8..±12.2).
	var to_road := -side * PI / 2.0
	_put("wheelie_bin", Vector3(side * 13.4, LAWN, z - 5.4), to_road)
	if number % 3 != 0:
		_put("garden_gnome", Vector3(side * 13.1, LAWN, z + 5.3), to_road + 0.3 * side)
	if number % 3 != 1:
		_put("bird_bath", Vector3(side * 13.1, LAWN, z + 0.8), 0.0)


## One of the two houses at the turning head, facing in across it.
func _head_house(side: float, number: int) -> void:
	var out := Vector3(-side, 0, 0)
	solid(Vector3(side * 19.0, LAWN / 2.0, -101.0), Vector3(4.0, LAWN, 16.0), _m.lawn)     # x ±17..±21
	_house(Vector3(side * 26.0, 0, -101.0), out, 10.0, 10.0, 7.0, _m.brick if side < 0 else _m.render, -3.0 * side)
	_lawn_sign(Vector3(side * 18.0, LAWN, -96.0), out)
	_sign(str(number), Vector3(side * 20.92, 2.9, -99.0), PI / 2.0 if side > 0 else -PI / 2.0, Color("e8d090"), 26, false)
	# Its back garden: up to the hedge lane (west) or the churchyard (east).
	solid(Vector3(side * 37.5, LAWN / 2.0, -101.0), Vector3(13.0, LAWN, 16.0), _m.lawn)    # x ±31..±44


## A suburban semi: a box with a pitched roof, its front door and porch light toward `out`, net-curtained windows front
## and back (the lit ones go on the curtain twitchers' list).
func _house(c: Vector3, out: Vector3, w: float, d: float, h: float, wall: Material, door_at := -3.0,
		prop := "pr_semi_render") -> void:
	var along_x := absf(out.x) < 0.5   # its front faces ±Z, so its width runs along X
	var size := Vector3(w if along_x else d, h, d if along_x else w)
	# The brick houses are the red-brick semi; the rendered ones the pebbledash.
	if prop == "pr_semi_render" and (wall == _m.brick or wall == _m.brick2) and _has_prop("pr_semi_brick"):
		prop = "pr_semi_brick"
	if _has_prop(prop):
		_house_model(c, out, w, d, h, prop, door_at)
		return
	solid(c + Vector3(0, h / 2.0, 0), size, wall)
	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(d + 0.6, 2.6, w + 0.4)
	roof.mesh = prism
	roof.material_override = _m.tile if wall == _m.brick or wall == _m.brick2 else _m.slate
	roof.position = c + Vector3(0, h + 1.3, 0)
	roof.rotation.y = PI / 2.0 if along_x else 0.0   # the ridge runs along the front
	add_child(roof)
	deco(c + Vector3(0, h + 0.06, 0), Vector3(size.x + 0.3, 0.12, size.z + 0.3), _m.white)   # the eaves' board
	var across := Vector3(out.z, 0, -out.x)          # along the front
	var front := c + out * (d / 2.0)
	var back := c - out * (d / 2.0)
	# The door, a porch canopy and its light.
	var door := front + out * 0.03 + across * door_at
	deco(door + Vector3(0, 1.1, 0), _box(across, 1.0, 2.2, 0.04), _m.door)
	deco(door + out * 0.35 + Vector3(0, 2.45, 0), _box(across, 1.6, 0.12, 0.7), _m.white)
	deco(door + out * 0.1 + Vector3(0.0, 2.05, 0) + across * 0.7, Vector3(0.18, 0.24, 0.18), _m.lamp)
	# Windows: two down (beside the door), two up; the same at the back.
	for face: Array in [[front, out], [back, -out]]:
		var p: Vector3 = face[0]
		var o: Vector3 = face[1]
		for spot: Vector2 in [Vector2(1.4, 1.5), Vector2(-1.4, 1.5), Vector2(1.6, 4.6), Vector2(-1.6, 4.6)]:
			var at := p + o * 0.04 + across * spot.x + Vector3(0, spot.y, 0)
			var lit := _rng.randf() < 0.55
			deco(at, _box(across, 1.5, 1.3, 0.06), _m.net if lit else _m.glass)
			deco(at + o * 0.03 + Vector3(0, -0.72, 0), _box(across, 1.7, 0.1, 0.14), _m.white)   # the sill
			if lit:
				curtains.append([at, o])


## The Meshy house's windows ([across, up] in metres, in the model's frame at its built size; the front, then the back),
## measured off its orthographic renders (.wip/props/ortho/<prop>_front|back.png). The watching ones get a warm pane.
const HOUSE_WINDOWS := {
	"pr_semi_render": [[Vector2(-1.6, 5.25), Vector2(1.8, 5.25), Vector2(-1.56, 2.33)],
		[Vector2(1.83, 5.25), Vector2(-1.69, 5.25), Vector2(1.75, 2.33), Vector2(-1.7, 2.33)]],
	"pr_vicarage": [[Vector2(-3.39, 4.64), Vector2(0.0, 4.64), Vector2(3.39, 4.64), Vector2(-3.39, 1.83), Vector2(3.39, 1.83)], []],
	# (Its back is blank brick: its curtain twitchers are all on the front.)
	"pr_semi_brick": [[Vector2(-1.73, 5.0), Vector2(2.32, 5.0), Vector2(-1.61, 1.98)], []],
}
const HOUSE_BUILT := {"pr_semi_render": Vector3(9.2, 9.6, 10.2), "pr_vicarage": Vector3(12.2, 9.8, 10.2),
	"pr_semi_brick": Vector3(9.2, 9.6, 10.2)}


## A house as its Meshy model, over the greybox's collision box (its roof's top at h + 2.6, like the old prism). Its
## lit windows are the curtain twitchers' (the same rule as the boxes': about half of them).
func _house_model(c: Vector3, out: Vector3, w: float, d: float, h: float, prop: String, door_at: float) -> void:
	var along_x := absf(out.x) < 0.5
	_col(c + Vector3(0, h / 2.0, 0), Vector3(w if along_x else d, h, d if along_x else w), 1)
	var yaw := atan2(out.x, out.z)
	var built: Vector3 = HOUSE_BUILT[prop]
	var fit := Vector3(w + 0.2, h + 2.6, d + 0.2)
	var b := Basis(Vector3.UP, yaw)
	# The semi's door is on its right (+X): where the path comes in on the other side, it's the mirror image.
	var across := Vector3(out.z, 0, -out.x)
	var flip := prop.begins_with("pr_semi_") and (b * Vector3.RIGHT).dot(across * door_at) < 0.0 \
		and _has_prop(prop + "_m")
	_put(prop + ("_m" if flip else ""), c, yaw, fit)
	var k := Vector3(fit.x / built.x, fit.y / built.y, fit.z / built.z) * Vector3(-1.0 if flip else 1.0, 1.0, 1.0)
	for face in 2:
		var o := out if face == 0 else -out
		var z := (fit.z / 2.0 + 0.04) * (1.0 if face == 0 else -1.0)
		for s: Vector2 in HOUSE_WINDOWS[prop][face]:
			if _rng.randf() >= 0.55:
				continue
			var at := c + b * Vector3(s.x * k.x, s.y * k.y, z)
			deco(at, _box(Vector3(o.z, 0, -o.x), 1.4, 1.1, 0.04), _m.net)
			curtains.append([at, o])


## A box `w` along `across`, `h` up, `t` thick (out from the face).
func _box(across: Vector3, w: float, h: float, t: float) -> Vector3:
	return Vector3(absf(across.x) * w + absf(across.z) * t, h, absf(across.z) * w + absf(across.x) * t)


func _lawn_sign(at: Vector3, out: Vector3) -> void:
	var yaw := atan2(out.x, out.z)
	solid(at + Vector3(0, 0.55, 0), Vector3(0.08, 1.1, 0.08), _m.fence)
	deco(at + Vector3(0, 1.15, 0) + out * 0.05, _box(Vector3(out.z, 0, -out.x), 1.1, 0.6, 0.04), _m.cream)
	_sign("SWYNE\nFOR DECENCY", at + Vector3(0, 1.15, 0) + out * 0.08, yaw, Color("24304e"), 16, false)


func _sale_sign(at: Vector3, out: Vector3) -> void:
	var yaw := atan2(out.x, out.z)
	solid(at + Vector3(0, 0.75, 0), Vector3(0.1, 1.5, 0.1), _m.white)
	deco(at + Vector3(0, 1.45, 0) + out * 0.06, _box(Vector3(out.z, 0, -out.x), 1.2, 0.7, 0.04), _m.red)
	_sign("FOR SALE", at + Vector3(0, 1.45, 0) + out * 0.09, yaw, Color("f0e8d8"), 20, false)


## A street lamp's foot: collected, then placed all at once (_place_lamps) as the Meshy lamp post, its lantern leaning
## out over the road; the box post and lantern if the prop isn't built.
func _lamp(at: Vector3) -> void:
	_lamps.append(at)


var _lamps: Array[Vector3] = []
## The prop's pole stands this far along its +X from its middle; its lantern hangs this far out on -X (props.py
## street_lamp: 1.84 m across, measured off the mesh).
const LAMP_POLE := 0.8


func _place_lamps() -> void:
	var items := []
	var lanterns: Array[Vector3] = []
	for at in _lamps:
		var road := Vector3(-signf(at.x) if absf(at.x) > 0.1 else 1.0, 0, 0)   # toward the road (or the path, at the church)
		var yaw := PI if road.x > 0.0 else 0.0                                 # the prop's -X (its lantern) toward it
		items.append([at - Basis(Vector3.UP, yaw) * Vector3(LAMP_POLE, 0, 0), yaw])
		lanterns.append(at + road * LAMP_POLE * 2.0 + Vector3(0, 4.6, 0))
		_col(at + Vector3(0, 2.0, 0), Vector3(0.2, 4.0, 0.2), 1)   # the pole
	if props("street_lamp", items, false):
		for p in lanterns:
			_light(p, Look.SODIUM, 2.6, 11.0)
		return
	for at in _lamps:
		deco(at + Vector3(0, 2.0, 0), Vector3(0.16, 4.0, 0.16), _m.ink)
		deco(at + Vector3(0, 4.1, 0), Vector3(0.36, 0.36, 0.36), _m.lamp)
		_light(at + Vector3(0, 4.0, 0), Look.SODIUM, 2.6, 11.0)


## Set dressing (WO-015 step 5's Meshy props), collected as the areas are built and placed in one MultiMesh per prop
## (_place_dressing). An item is [at, yaw] or [at, yaw, size]. Props that aren't built are simply left out.
var _dress := {}
## Dressing nothing should bump into (it's decoration on something solid already, or small enough to step past).
const DRESS_SOFT := ["folding_chair", "garden_gnome", "trestle_table", "raffle_drum", "floral_sofa", "garden_bench",
	"prize_marrow",
	# The buildings: shells over the greybox's own collision (their doorways, belfries and climbs are in that).
	"pr_semi_render", "pr_semi_render_m", "pr_semi_brick", "pr_semi_brick_m", "pr_vicarage", "pr_church_hall", "pr_show_home", "pr_spire", "pr_arch",
	"pr_watch_hut", "pr_greenhouse"]


func _put(prop: String, at: Vector3, yaw: float, size := Vector3.ZERO) -> void:
	if not _dress.has(prop):
		_dress[prop] = []
	(_dress[prop] as Array).append([at, yaw] if size == Vector3.ZERO else [at, yaw, size])


func _place_dressing() -> void:
	for p: String in _dress:
		props(p, _dress[p], not p in DRESS_SOFT)


## Whether a prop is built (so a greybox stand-in can step aside for it).
func _has_prop(prop: String) -> bool:
	return ResourceLoader.exists(PROP_PATH % prop)


## The OLD QUARTER arch over the Close's mouth: walk under it and she's back on Primrose Lane.
func _arch() -> void:
	if _has_prop("pr_arch"):
		# The brick arch, its piers over the old pillars' collision; the name on its keystone panel.
		for x: float in [-6.0, 6.0]:
			_col(Vector3(x, 2.6, 7.5), Vector3(0.8, 5.2, 0.8), 1)
		_put("pr_arch", Vector3(0, 0, 7.5), 0.0, Vector3(14.2, 7.4, 1.4))
		_sign("THE OLD QUARTER", Vector3(0, 6.6, 8.25), PI, Color(2.2, 1.6, 0.9), 40)
	else:
		for x: float in [-6.0, 6.0]:
			solid(Vector3(x, 2.6, 7.5), Vector3(0.8, 5.2, 0.8), _m.brick)
		deco(Vector3(0, 5.5, 7.5), Vector3(13.0, 0.7, 0.9), _m.brick)
		_sign("THE OLD QUARTER", Vector3(0, 5.5, 7.98), PI, Color(2.2, 1.6, 0.9), 44)
	var back := WorldGate.new()
	back.name = "Gate_hub"
	back.world = &"hub"
	back.arrival = "primrose"
	back.size = Vector3(11.0, 3.0, 1.5)
	back.position = Vector3(0, 0.0, 9.6)
	add_child(back)
	# The street's walls beyond the arch, so the way out is only through it.
	for s: float in [-1.0, 1.0]:
		solid(Vector3(s * 53.0, 1.5, 9.0), Vector3(94.0, 3.0, 0.6), _m.brick2)
	# The rest of the edge: high hedges round the whole of it.
	for s: float in [-1.0, 1.0]:
		solid(Vector3(s * 100.3, 1.75, -85.0), Vector3(0.6, 3.5, 188.0), _m.hedge)
	solid(Vector3(0, 1.75, -179.3), Vector3(201.2, 3.5, 0.6), _m.hedge)


## The Neighbourhood Watch hut: a little shed with a window and a noticeboard. Its key, and the shed it opens, are
## Vesper's lesson (step 2); its logbook is Key 7.
func _watch_hut(at: Vector3) -> void:
	# Paved round, level with the pavement (x 8..14, z 2..-4): the watchman fetches and opens for Vesper's lesson here,
	# and staff can't step up a kerb.
	_pave(Vector3(at.x, 0, at.z), Vector3(6.0, 0, 6.0))
	if _has_prop("pr_watch_hut"):
		# Its front (door, badge) to the road (-X), over the old box's collision.
		_col(at + Vector3(0, 1.2, 0), Vector3(2.6, 2.4, 2.2), 1)
		_put("pr_watch_hut", at + Vector3(0, PAVE - LAWN, 0), -PI / 2.0, Vector3(2.4, 2.9, 2.8))
		_sign("NEIGHBOURHOOD\nWATCH", at + Vector3(-1.48, 2.45, 0.5), -PI / 2.0, Color("f0e060"), 16, false)
	else:
		solid(at + Vector3(0, 1.2, 0), Vector3(2.6, 2.4, 2.2), _m.shed)
		deco(at + Vector3(0, 2.5, 0), Vector3(3.0, 0.2, 2.6), _m.planks)
		deco(at + Vector3(-1.33, 1.4, 0.3), Vector3(0.06, 0.8, 1.0), _m.net)
		deco(at + Vector3(-1.33, 1.0, -0.7), Vector3(0.05, 2.0, 0.8), _m.door)
		_sign("NEIGHBOURHOOD\nWATCH", at + Vector3(-1.36, 2.1, 0), -PI / 2.0, Color("f0e060"), 18, false)
	_light(at + Vector3(-2.0, 2.4, 0), Color("ffd890"), 1.4, 6.0)


## Church Path: from the Close's east pavement, between two gardens, to St. Prudence's porch.
func _church_path(z: float) -> void:
	_pave(Vector3(31.0, 0, z), Vector3(46.0, 0, 3.0))   # x 8..54
	for s: float in [-1.0, 1.0]:
		solid(Vector3(11.0, LAWN / 2.0, z + s * 4.0), Vector3(6.0, LAWN, 5.0), _m.lawn)
	_sign("CHURCH PATH", Vector3(8.6, 2.2, z + 2.2), PI / 2.0, Color("e8e0d0"), 20, false)
	solid(Vector3(8.6, 1.1, z + 2.3), Vector3(0.1, 2.2, 0.1), _m.ink)


# --- the Back Gardens ------------------------------------------------------------------------------------------------

func _gardens() -> void:
	for side: float in [-1.0, 1.0]:
		var outer := side * 46.0
		# The lawns, a plot each, from the houses' backs (x ±24) to the back fence.
		for k in 7:
			var z := -10.0 - PLOT * k
			if side > 0 and absf(z - PATH_Z) < 1.0:
				continue
			solid(Vector3(side * 35.0, LAWN / 2.0, z), Vector3(21.8, LAWN, PLOT - 0.2), _m.lawn)   # short of the fences' faces
		# Fences between them, their tops a beam to walk; the back fence too.
		for k in 8:
			var z := -4.0 - PLOT * k
			if side > 0 and (absf(z - (PATH_Z + 6.0)) < 1.0 or absf(z - (PATH_Z - 6.0)) < 1.0):
				_fence(Vector3(side * 24.0, 0, z + (-4.5 if z > PATH_Z else 4.5)), Vector3(outer, 0, z + (-4.5 if z > PATH_Z else 4.5)))
				continue
			_fence(Vector3(side * 24.0, 0, z), Vector3(outer, 0, z))
		if side > 0:   # a gap where Church Path goes through to the churchyard
			_fence(Vector3(outer, 0, -4.0), Vector3(outer, 0, PATH_Z + 1.5))
			_fence(Vector3(outer, 0, PATH_Z - 1.5), Vector3(outer, 0, -88.0))
		else:
			_fence(Vector3(outer, 0, -4.0), Vector3(outer, 0, -88.0))
		# The washing line down the gardens: a wire 3.6 m up (clear of her head on a fence top, out of reach from the
		# lawn: up off a fence it is), on a pole in each garden.
		var line := Beam.new()
		line.length = 84.0
		line.width = 0.04
		line.wire = true
		line.material = _m.white
		line.position = Vector3(side * 35.0, LINE_Y, -46.0)
		line.rotation.y = PI / 2.0
		line.name = "WashingLine_%s" % ("west" if side < 0 else "east")
		add_child(line)
		for k in 7:
			var z := -10.0 - PLOT * k
			if side > 0 and absf(z - PATH_Z) < 1.0:
				continue   # not on Church Path
			_strut(Vector3(side * 35.0, 0, z), Vector3(side * 35.0, LINE_Y - 0.06, z), 0.08, _m.ink, true)   # just under it
		# Laundry on the lines: sheets and shirts, here and there (not solid).
		for k in 7:
			if _rng.randf() < 0.6:
				var z := -7.0 - PLOT * k
				deco(Vector3(side * 35.0, LINE_Y - 0.5, z), Vector3(0.04, 0.9, 1.2), [_m.white, _m.cream, _m.pool][k % 3])
	# Sheds (flat roofs to stand on), greenhouses, the paddling pool, the van.
	for sh: Array in [[-40.0, -34.0], [-41.0, -70.0], [38.0, -22.0], [41.0, -80.0]]:
		_shed(Vector3(sh[0], LAWN, sh[1]))
	wardrobe(Vector3(-41.0, LAWN, -67.6), PI, "Wardrobe_shed")   # beside the shed at (-41, -70): the garden shed
	for gh: Array in [[-30.0, -46.0], [30.0, -10.0], [30.0, -68.0]]:
		_greenhouse(Vector3(gh[0], LAWN, gh[1]))
	# The paddling pool, in number 12's garden (east, plot 5).
	var pool := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.6
	cyl.bottom_radius = 1.6
	cyl.height = 0.35
	pool.mesh = cyl
	pool.material_override = _m.pool
	pool.position = Vector3(32.0, LAWN + 0.17, -70.0 + 2.0)
	add_child(pool)
	_col(Vector3(32.0, LAWN + 0.17, -68.0), Vector3(3.0, 0.35, 3.0), 1)
	# The delivery van stuck in number 9's garden (west, plot 4: Key 8), its boxes of LITERATURE.
	var van := Vector3(-33.0, LAWN, -58.0)
	if _has_prop("delivery_van"):
		# The Meshy van, its nose (the prop's -X) to +Z where the box's windscreen was, fitted to the same 5 m by
		# 2.3 m by 2.8 m it always took up: its collision box is unchanged, so Key 8 plays as before.
		_col(van + Vector3(0, 1.55, 0), Vector3(2.3, 2.5, 5.0), 1)
		_put("delivery_van", van, PI / 2.0, Vector3(5.0, 2.8, 2.3))
		_sign("DECENCY\nDELIVERIES", van + Vector3(1.2, 1.7, -0.8), PI / 2.0, Color("24304e"), 22, false)
	else:
		solid(van + Vector3(0, 1.55, 0), Vector3(2.3, 2.5, 5.0), _m.cream)   # on its wheels, 0.3 up
		deco(van + Vector3(0, 1.8, 2.52), Vector3(2.1, 0.8, 0.04), _m.glass)
		deco(van + Vector3(1.17, 1.5, -0.5), Vector3(0.04, 0.8, 3.0), _m.navy)
		_sign("DECENCY\nDELIVERIES", van + Vector3(1.2, 1.5, -0.5), PI / 2.0, Color("24304e"), 22, false)
		for wz: float in [-1.6, 1.6]:
			for wx: float in [-1.0, 1.0]:
				deco(van + Vector3(wx * 1.15, 0.35, wz), Vector3(0.3, 0.7, 0.7), _m.ink)


## A garden fence from `a` to `b` (along X or Z), 1.65 m of boards and a beam on top to walk at 1.8.
func _fence(a: Vector3, b: Vector3) -> void:
	var mid := (a + b) / 2.0
	var along_x := absf(b.x - a.x) > absf(b.z - a.z)
	var length := absf(b.x - a.x) if along_x else absf(b.z - a.z)
	solid(Vector3(mid.x, 0.825, mid.z), Vector3(length if along_x else 0.1, 1.65, 0.1 if along_x else length), _m.fence)
	var top := Beam.new()
	top.length = length
	top.width = 0.15
	top.material = _m.planks
	top.position = Vector3(mid.x, 1.8, mid.z)
	top.rotation.y = 0.0 if along_x else PI / 2.0
	add_child(top)


func _shed(at: Vector3) -> void:
	solid(at + Vector3(0, 1.1, 0), Vector3(2.4, 2.2, 3.0), _m.shed)
	deco(at + Vector3(0, 2.26, 0), Vector3(2.7, 0.12, 3.3), _m.planks)
	deco(at + Vector3(1.23, 0.95, 0.6), Vector3(0.04, 1.9, 0.8), _m.door)


func _greenhouse(at: Vector3) -> void:
	# Glass on a low brick base; its roof's ridge solid enough to cross (step 2 cracks it under a heavy landing).
	if _has_prop("pr_greenhouse"):
		_col(at + Vector3(0, 0.25, 0), Vector3(3.0, 0.5, 4.0), 1)
		_put("pr_greenhouse", at, 0.0, Vector3(3.0, 3.2, 4.0))
		_col(at + Vector3(0, 1.4, 0), Vector3(3.0, 2.3, 4.0), 1)
		return
	solid(at + Vector3(0, 0.25, 0), Vector3(3.0, 0.5, 4.0), _m.brick)
	deco(at + Vector3(0, 1.4, 0), Vector3(2.9, 1.8, 3.9), _m.greenhouse)
	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(3.1, 0.9, 4.1)
	roof.mesh = prism
	roof.material_override = _m.greenhouse
	roof.position = at + Vector3(0, 2.75, 0)
	add_child(roof)
	_col(at + Vector3(0, 1.4, 0), Vector3(3.0, 2.3, 4.0), 1)


# --- St. Prudence's ---------------------------------------------------------------------------------------------------

func _church() -> void:
	# The churchyard: lawn round the hall, a low wall on the road side.
	solid(Vector3(74.0, LAWN / 2.0, -44.0), Vector3(52.0, LAWN, 92.0), _m.lawn)   # x 48..100, z 2..-90 (Church Path crosses it)
	# The hall: x 54..82, z -24..-52, walls 0.4, the door (3 m) in the west wall at Church Path, the bake sale, the
	# raffle, the stage at the east end; a gabled roof.
	var h := 7.0
	var x0 := 54.0
	var x1 := 82.0
	var z0 := -24.0
	var z1 := -52.0
	# (Under the Meshy hall, the walls are bare collision and the room's lined from inside: their painted outsides
	# poked through the model's walls, which sit in from its porch and buttresses.)
	var shell := _has_prop("pr_church_hall")
	var wall := func(at: Vector3, size: Vector3) -> void:
		if shell:
			_col(at, size, 1)
		else:
			solid(at, size, _m.stone)
	wall.call(Vector3((x0 + x1) / 2.0, h / 2.0, z0), Vector3(x1 - x0 + 0.4, h, 0.4))              # south
	wall.call(Vector3(x1, h / 2.0, (z0 + z1) / 2.0), Vector3(0.4, h, z0 - z1))  # east
	# North wall, with the bell tower's door (x 64..66) through to the tower.
	wall.call(Vector3((x0 + 64.0) / 2.0, h / 2.0, z1), Vector3(64.0 - x0, h, 0.4))
	wall.call(Vector3((66.0 + x1) / 2.0 + 0.2, h / 2.0, z1), Vector3(x1 - 66.0 + 0.4, h, 0.4))
	wall.call(Vector3(65.0, (2.6 + h) / 2.0, z1), Vector3(2.0, h - 2.6, 0.4))
	# West wall, with the door at Church Path (z -44.5..-47.5).
	wall.call(Vector3(x0, h / 2.0, (z0 + HALL_DOOR_Z + 1.5) / 2.0 - 0.1), Vector3(0.4, h, absf(z0 - (HALL_DOOR_Z + 1.5)) - 0.2))
	wall.call(Vector3(x0, h / 2.0, (HALL_DOOR_Z - 1.5 + z1) / 2.0), Vector3(0.4, h, absf((HALL_DOOR_Z - 1.5) - z1)))
	wall.call(Vector3(x0, (3.0 + h) / 2.0, HALL_DOOR_Z), Vector3(0.4, h - 3.0, 3.0))
	if shell:
		# The inside faces: north z1 + 0.2, south z0 - 0.2, west x0 + 0.2, east x1 - 0.2.
		lining(Rect2(x0 + 0.2, z1 + 0.2, x1 - x0 - 0.4, z0 - z1 - 0.4), 0.0, h, _m.stone,
			[["n", 64.0, 66.0, 2.6], ["w", HALL_DOOR_Z - 1.5, HALL_DOOR_Z + 1.5, 3.0]])
	# The floor, the ceiling, the roof.
	solid(Vector3((x0 + x1) / 2.0, 0.06, (z0 + z1) / 2.0), Vector3(x1 - x0 - 0.4, 0.12, z0 - z1 - 0.4), _m.floor)
	solid(Vector3((x0 + x1) / 2.0, h + 0.15, (z0 + z1) / 2.0), Vector3(x1 - x0 + 0.4, 0.3, z0 - z1 + 0.4), _m.hall_in)
	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(z0 - z1 + 1.2, 3.6, x1 - x0 + 1.0)
	roof.mesh = prism
	roof.material_override = _m.slate
	roof.position = Vector3((x0 + x1) / 2.0, h + 0.3 + 1.8, (z0 + z1) / 2.0)
	roof.rotation.y = PI / 2.0
	if _has_prop("pr_church_hall"):
		# The Meshy hall over the stone walls (their insides are the hall you walk round): its gable front to Church
		# Path, its door and the tower's door cut through (props.py pr_church_hall), its own roof for the prism.
		roof.free()
		_put("pr_church_hall", Vector3((x0 + x1) / 2.0, 0.0, (z0 + z1) / 2.0), -PI / 2.0)
	else:
		add_child(roof)
	# Its tall windows, lit, and a stained-glass one over the stage.
	if not shell:   # (the Meshy hall has its own gothic windows)
		for x in range(57, 81, 4):
			deco(Vector3(x, 3.6, z0 + 0.24), Vector3(1.0, 2.6, 0.06), _m.net)
		deco(Vector3(x1 + 0.24, 4.4, -38.0), Vector3(0.06, 3.2, 2.4), _m.stained)
	_sign("ST. PRUDENCE'S HALL", Vector3(x0 - 0.45, 4.0, HALL_DOOR_Z), -PI / 2.0, Color("e8e0d0"), 28, false)
	_sign("BAKE SALE & GRAND RAFFLE\nin aid of DECENCY", Vector3(x0 - 0.25, 5.4, -35.0), -PI / 2.0, Color("f0e060"), 18, false)
	# The porch, with the Coalition's collection tin on it (placed in _collectibles).
	deco(Vector3(x0 - 1.2, 3.2, HALL_DOOR_Z), Vector3(2.4, 0.2, 4.0), _m.slate)
	for dz: float in [-1.8, 1.8]:
		solid(Vector3(x0 - 2.2, 1.6, HALL_DOOR_Z + dz), Vector3(0.24, 3.2, 0.24), _m.white)
	# Inside: the bake sale's trestles, the raffle's table and drum, the stage at the east end, chairs.
	# (The Meshy trestles, cakes and all, over the same collision boxes the Keys were built round.)
	var trestles := _has_prop("trestle_table")
	for t: Array in [[60.0, -30.0], [60.0, -36.0], [68.0, -30.0]]:
		if trestles:
			_col(Vector3(t[0], 0.5, t[1]), Vector3(3.0, 0.8, 1.0), 1)
			_put("trestle_table", Vector3(t[0], 0.1, t[1]), 0.0, Vector3(3.0, 1.15, 1.05))
		else:
			solid(Vector3(t[0], 0.5, t[1]), Vector3(3.0, 0.8, 1.0), _m.white)
	_sign("BAKE SALE", Vector3(60.0, 1.6, -29.4), 0.0, Color("6a2a3e"), 22, false)
	solid(Vector3(68.0, 0.5, -36.0), Vector3(2.0, 0.8, 1.0), _m.navy)
	if _has_prop("raffle_drum"):
		_put("raffle_drum", Vector3(68.0, 0.9, -36.0), 0.0, Vector3(0.9, 0.75, 0.57))   # on the table, its crank to the hall
	else:
		deco(Vector3(68.0, 1.15, -36.0), Vector3(0.6, 0.5, 0.6), _m.brass)
	_sign("RAFFLE", Vector3(68.0, 1.75, -35.4), 0.0, Color("f0e060"), 22, false)
	solid(Vector3(78.5, 0.6, -38.0), Vector3(6.0, 1.2, 12.0), _m.floor)                       # the stage
	deco(Vector3(81.5, 3.6, -38.0), Vector3(0.2, 4.6, 12.0), _m.red)                           # its curtain
	var chairs := _has_prop("folding_chair")
	for r in 3:
		for c in 5:
			if chairs:
				_put("folding_chair", Vector3(66.0 + r * 1.6, 0.12, -42.0 - c * 1.2), PI / 2.0)   # facing the stage (+X)
			else:
				deco(Vector3(66.0 + r * 1.6, 0.45, -42.0 - c * 1.2), Vector3(0.5, 0.9, 0.5), _m.fence)
	for p: Vector3 in [Vector3(62, 5.6, -32), Vector3(74, 5.6, -32), Vector3(62, 5.6, -44), Vector3(74, 5.6, -44)]:
		_light(p, Color("ffd8a0"), 2.0, 10.0)
	_tower()
	_vicarage()
	# The road round to the churchyard from the entrance, and a lamp at the porch.
	_lamp(Vector3(50.0, PAVE, -41.0))


## The bell tower on the hall's north side, and its steeple: the landmark you see from everywhere. Its outside north
## face is marked from the ground to the belfry floor (14 m): climb it, pull up into the belfry (open on four sides:
## Key 4, and Vesper on the spire's base, step 2). Inside, a hole in the belfry's floor and the bell rope down a marked
## strip to the tower's ground floor, where the door through to the hall opens from the tower's side (the second
## shortcut).
func _tower() -> void:
	var c := TOWER
	var half := 3.0
	var t := 0.4
	# Four walls, hollow, up to the belfry floor.
	for s: float in [-1.0, 1.0]:
		solid(Vector3(c.x + s * (half - t / 2.0), BELFRY / 2.0, c.z), Vector3(t, BELFRY, half * 2.0), _m.stone)
	solid(Vector3(c.x, BELFRY / 2.0, c.z - (half - t / 2.0)), Vector3(half * 2.0 - 2.0 * t, BELFRY, t), _m.stone)
	# The south wall is the hall's north wall's neighbour: its doorway (x 64..66) lines up with the hall's.
	solid(Vector3(c.x - 1.9, BELFRY / 2.0, c.z + (half - t / 2.0)), Vector3(1.8, BELFRY, t), _m.stone)
	solid(Vector3(c.x + 1.9, BELFRY / 2.0, c.z + (half - t / 2.0)), Vector3(1.8, BELFRY, t), _m.stone)
	solid(Vector3(c.x, (2.6 + BELFRY) / 2.0, c.z + (half - t / 2.0)), Vector3(2.0, BELFRY - 2.6, t), _m.stone)
	# The marked climb on the outside north face, up to the belfry floor's top (so it ends in a pull-up).
	solid(Vector3(c.x, (BELFRY + 0.3) / 2.0, c.z - half - 0.1), Vector3(3.0, BELFRY + 0.3, 0.2), _m.climb, 1 | 2)
	# The belfry floor, with the rope's hole in the south-east corner (x 66.4..67.6, z -53.8..-52.4).
	var f := BELFRY + 0.15
	solid(Vector3(c.x - 0.8, f, c.z), Vector3(4.4, 0.3, 6.0), _m.planks)            # x 62..66.4
	solid(Vector3(c.x + 2.2, f, c.z - 0.9), Vector3(1.6, 0.3, 4.2), _m.planks)      # x 66.4..68, z -58..-53.8
	# A parapet round three sides (the north's open: it's where you climb in), so the belfry isn't walked off.
	# (On the floor's top, a little in from its edges: flush, they shared its faces.)
	var pz := BELFRY + 0.3 + 0.5
	solid(Vector3(c.x - (half - t / 2.0) + 0.02, pz, c.z), Vector3(t, 1.0, half * 2.0 - 0.04), _m.stone)
	solid(Vector3(c.x + (half - t / 2.0) - 0.02, pz, c.z), Vector3(t, 1.0, half * 2.0 - 0.04), _m.stone)
	solid(Vector3(c.x, pz, c.z + (half - t / 2.0) - 0.02), Vector3(half * 2.0 - 2.0 * t - 0.04, 1.0, t), _m.stone)
	# The bell rope: a marked strip on the tower's inside east wall, from the hole down to the ground floor.
	solid(Vector3(c.x + half - t - 0.1, (BELFRY - 0.1) / 2.0, c.z + 2.1), Vector3(0.2, BELFRY - 0.1, 1.2), _m.climb, 1 | 2)
	_strut(Vector3(c.x + 1.9, 1.0, c.z + 2.1), Vector3(c.x + 1.9, BELFRY + 3.0, c.z + 2.1), 0.05, _m.cream, false)
	# The belfry: four corner piers, the bells, a cornice; the spire on top.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			solid(Vector3(c.x + sx * 2.6, BELFRY + 0.3 + 2.0, c.z + sz * 2.6), Vector3(0.8, 4.0, 0.8), _m.stone)
	solid(Vector3(c.x, BELFRY + 4.5, c.z), Vector3(6.4, 0.6, 6.4), _m.stone)
	for b: Vector3 in [Vector3(-1.0, 0, -1.0), Vector3(1.0, 0, 1.0)]:
		var bell := MeshInstance3D.new()
		bell.name = "Bell_%d" % (0 if b.x < 0.0 else 1)   # rung by Key 4 (keys/steeple.gd)
		var bm := CylinderMesh.new()
		bm.top_radius = 0.35
		bm.bottom_radius = 0.7
		bm.height = 1.0
		bell.mesh = bm
		bell.material_override = _m.brass
		bell.position = Vector3(c.x + b.x, BELFRY + 3.3, c.z + b.z)
		add_child(bell)
	var spire := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.05
	cone.bottom_radius = 3.0
	cone.height = SPIRE - BELFRY - 4.8
	cone.radial_segments = 4
	spire.mesh = cone
	spire.material_override = _m.slate
	spire.rotation.y = PI / 4.0
	spire.position = Vector3(c.x, BELFRY + 4.8 + cone.height / 2.0, c.z)
	if _has_prop("pr_spire"):
		# The Meshy spire, pinnacles and weathercock, from the cornice to a little over SPIRE (the landmark).
		spire.free()
		_put("pr_spire", Vector3(c.x, BELFRY + 4.8, c.z), 0.0, Vector3(6.4, SPIRE - BELFRY - 3.0, 6.4))
	else:
		add_child(spire)
		deco(Vector3(c.x, SPIRE + 0.5, c.z), Vector3(0.12, 1.2, 0.12), _m.brass)
	_light(Vector3(c.x, BELFRY + 2.0, c.z), Color("ffd8a0"), 1.6, 7.0)
	# The door from the tower's ground floor to the hall: it opens from the tower's side (its back faces the tower).
	shortcut(&"bell_rope", Vector3(c.x, 0.0, -52.0), PI)


## The vicarage behind the hall: its back door's laundry is a wardrobe.
func _vicarage() -> void:
	_house(Vector3(92.0, 0, -33.0), Vector3(0, 0, 1), 12.0, 10.0, 7.0, _m.stone, -3.0, "pr_vicarage")
	solid(Vector3(92.0, 1.2, -26.9), Vector3(3.0, 2.4, 2.2), _m.white)              # the laundry lean-to
	wardrobe(Vector3(92.0, LAWN, -25.6), PI, "Wardrobe_laundry")
	_sign("THE VICARAGE", Vector3(86.0, 1.2, -27.0), 0.0, Color("e8e0d0"), 18, false)


# --- the Allotments --------------------------------------------------------------------------------------------------

func _allotments() -> void:
	# The hedge between the gardens and the allotments, with its gap (the shortcut) at the north end.
	solid(Vector3(-48.0, 1.1, -55.1), Vector3(1.0, 2.2, 110.2), _m.hedge)         # z 0..-110.2
	solid(Vector3(-48.0, 1.1, -116.4), Vector3(1.0, 2.2, 9.2), _m.hedge)          # z -111.8..-121
	shortcut(&"hedge_gap", Vector3(-48.0, 0.0, -111.0), -PI / 2.0)                 # front to the Close's side (+X)
	# The lane from the gap to the turning head, and a hedge along its north side.
	_pave(Vector3(-31.5, 0, -111.0), Vector3(32.0, 0, 3.0))                       # x -47.5..-15.5
	solid(Vector3(-31.5, 1.1, -113.0), Vector3(32.0, 2.2, 1.0), _m.hedge)
	solid(Vector3(-31.5, 1.1, -109.0), Vector3(19.0, 2.2, 1.0), _m.hedge)        # x -41..-22 (the head house's back)
	# The allotments' own fences: west and north.
	solid(Vector3(-96.0, 1.0, -58.0), Vector3(0.6, 2.0, 124.0), _m.hedge)
	solid(Vector3(-72.0, 1.0, -120.5), Vector3(48.0, 2.0, 1.0), _m.hedge)
	_sign("ALLOTMENTS\nmembers only", Vector3(-50.5, 2.4, 1.6), 0.0, Color("e8e0d0"), 20, false)
	# The plots: beds of soil in rows, a path between them.
	for row in 5:
		for col in 2:
			var c := Vector3(-60.0 - col * 22.0, 0, -12.0 - row * 20.0)
			solid(Vector3(c.x, 0.1, c.z), Vector3(16.0, 0.2, 14.0), _m.soil)
			for r in 4:
				deco(Vector3(c.x, 0.32, c.z - 5.0 + r * 3.3), Vector3(14.0, 0.25, 0.5), _m.marrow)
	# Sheds (one per pair of plots), polytunnels.
	# (The Meshy shed here, pitched roof and gingham curtains: the back gardens' keep their flat roofs to stand on.)
	for sz: float in [-22.0, -62.0, -102.0]:
		if _has_prop("garden_shed"):
			_put("garden_shed", Vector3(-71.0, 0.0, sz), PI / 2.0, Vector3(2.4, 2.6, 2.6))   # its door to the path (+X)
		else:
			_shed(Vector3(-71.0, 0.0, sz))
		_put("wheelbarrow", Vector3(-68.6, 0.0, sz + 2.6), 0.4)
	for pz: float in [-42.0, -82.0]:
		_polytunnel(Vector3(-71.0, 0, pz))
	# The prize marrows: the show bed by the north hedge, under its cloche of tarpaulin (Key 5's stash, step 2).
	var show := Vector3(-60.0, 0, -112.0)
	solid(show + Vector3(0, 0.15, 0), Vector3(8.0, 0.3, 4.0), _m.soil)
	for i in 3:
		if _has_prop("prize_marrow"):
			# On their straw, rosettes to the path; a bit bigger each, the middle one the champion.
			var big: float = [1.6, 2.0, 1.7][i]
			_put("prize_marrow", show + Vector3(-2.4 + i * 2.4, 0.3, 0), 0.0, Vector3(big, big * 0.32, big * 0.58))
			continue
		var m := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.4
		cap.height = 1.8
		m.mesh = cap
		m.material_override = _m.marrow
		m.rotation.z = PI / 2.0
		m.position = show + Vector3(-2.4 + i * 2.4, 0.7, 0)
		add_child(m)
	_sign("PRIZE MARROWS\ndo not touch", show + Vector3(0, 1.5, 2.1), 0.0, Color("e8e0d0"), 18, false)
	_light(Vector3(-71.0, 3.0, -60.0), Color("ffd890"), 1.6, 12.0)
	_light(Vector3(-60.0, 3.0, -108.0), Color("ffd890"), 1.4, 9.0)


func _polytunnel(at: Vector3) -> void:
	var m := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 2.2
	cyl.bottom_radius = 2.2
	cyl.height = 10.0
	m.mesh = cyl
	m.material_override = _m.greenhouse
	m.rotation.x = PI / 2.0
	m.position = at
	add_child(m)
	_col(at + Vector3(0, 1.1, 0), Vector3(4.4, 2.2, 10.0), 1)


# --- the Show Home ---------------------------------------------------------------------------------------------------

## Mrs Gander's house at the head of the Close: two storeys, its ground floor one open living room (the
## demonstration party, step 3), its back door to the conservatory locked until then.
func _show_home() -> void:
	var x0 := -12.0
	var x1 := 12.0
	var z0 := -116.0
	var z1 := -136.0
	var room := 3.4
	var h := 7.4
	var t := 0.4
	solid(Vector3(0, LAWN / 2.0, -114.5), Vector3(24.0, LAWN, 2.4), _m.lawn)
	# Ground floor walls: the front with its door (x -1..1), the sides, the back with the conservatory door. Under the
	# Meshy house they're bare collision, the living room lined from inside (as St. Prudence's).
	var shell := _has_prop("pr_show_home")
	var wall := func(at: Vector3, size: Vector3) -> void:
		if shell:
			_col(at, size, 1)
		else:
			solid(at, size, _m.render)
	wall.call(Vector3((x0 - 1.0) / 2.0, room / 2.0, z0), Vector3(-1.0 - x0, room, t))
	wall.call(Vector3((1.0 + x1) / 2.0, room / 2.0, z0), Vector3(x1 - 1.0, room, t))
	wall.call(Vector3(0, (2.4 + room) / 2.0, z0), Vector3(2.0, room - 2.4, t))
	for s: float in [-1.0, 1.0]:
		wall.call(Vector3(s * (x1 - t / 2.0), room / 2.0, (z0 + z1) / 2.0), Vector3(t, room, z0 - z1 - t))
	wall.call(Vector3((x0 - 1.0) / 2.0, room / 2.0, z1), Vector3(-1.0 - x0, room, t))
	wall.call(Vector3((1.0 + x1) / 2.0, room / 2.0, z1), Vector3(x1 - 1.0, room, t))
	wall.call(Vector3(0, (2.4 + room) / 2.0, z1), Vector3(2.0, room - 2.4, t))
	# The upper storey (solid), the roof.
	wall.call(Vector3(0, (room + h) / 2.0, (z0 + z1) / 2.0), Vector3(x1 - x0, h - room, z0 - z1 + t))
	if shell:
		# The room's inside faces (the walls are 0.4 thick, x1 inner at x1 - t, z0 at z0 - t / 2) and its ceiling.
		lining(Rect2(x0 + t, z1 + t / 2.0, x1 - x0 - 2.0 * t, z0 - z1 - t), 0.0, room, _m.render,
			[["s", -1.0, 1.0, 2.4], ["n", -1.0, 1.0, 2.4]])
		# A skin on the walls' outer faces, so where the model's facade is open between its porch and bays you see a
		# wall, not the living room (the doorways stay open).
		for zf: float in [z0 + t / 2.0 + 0.01, z1 - t / 2.0 - 0.01]:
			for seg: Vector2 in [Vector2(x0, -1.0), Vector2(1.0, x1)]:
				deco(Vector3((seg.x + seg.y) / 2.0, room / 2.0, zf), Vector3(seg.y - seg.x, room, 0.02), _m.render)
			deco(Vector3(0, (2.4 + room) / 2.0, zf), Vector3(2.0, room - 2.4, 0.02), _m.render)
		var lid := MeshInstance3D.new()
		var lq := QuadMesh.new()
		lq.size = Vector2(x1 - x0, z0 - z1)
		lid.mesh = lq
		lid.material_override = _m.render
		lid.rotation.x = PI / 2.0   # facing down
		lid.position = Vector3(0, room - 0.01, (z0 + z1) / 2.0)
		add_child(lid)
	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(z0 - z1 + 1.2, 3.2, x1 - x0 + 1.0)
	roof.mesh = prism
	roof.material_override = _m.tile
	roof.position = Vector3(0, h + 1.6, (z0 + z1) / 2.0)
	roof.rotation.y = PI / 2.0
	if _has_prop("pr_show_home"):
		# Her house as the Meshy show home over the walls (inside, the walls' own faces are the living room): its
		# front and back doors cut through to the game's (props.py pr_show_home).
		roof.free()
		_put("pr_show_home", Vector3(0, 0, (z0 + z1) / 2.0), 0.0)
	else:
		add_child(roof)
	# Inside: carpet, the living room's sofas round a coffee table, the kit cupboard, lamps.
	solid(Vector3(0, 0.04, (z0 + z1) / 2.0), Vector3(x1 - x0 - 2.0 * t, 0.08, z0 - z1 - 2.0 * t), _m.carpet)
	# The sofas round the coffee table (the party's guests sit on them, step 3): a seat at knee height on the carpet
	# (0.08), a back on the far side. The back's a little longer than the seat, so their ends share no face.
	for s: Array in [[Vector3(-5.0, 0, -124.0), Vector3(1, 0, 0)], [Vector3(5.0, 0, -124.0), Vector3(-1, 0, 0)],
			[Vector3(0, 0, -129.0), Vector3(0, 0, 1)]]:
		var at: Vector3 = s[0]
		var f: Vector3 = s[1]   # the way it faces (to the table)
		var along_z := absf(f.x) > 0.5
		var length := 4.0 if along_z else 5.0
		# (Both sunk a little into the carpet, by different amounts: no face shared with it or each other.)
		var seat := Vector3(0.82 if along_z else length, 0.44, length if along_z else 0.82)
		var back := Vector3(0.2 if along_z else length + 0.1, 0.96, length + 0.1 if along_z else 0.2)
		if _has_prop("floral_sofa"):
			# Her chintz sofas, two to a side (they're 2 m and 2.5 m), over the same seat and back the guests sit on.
			_col(at + f * 0.09 + Vector3(0, 0.06 + 0.22, 0), seat, 1)
			_col(at - f * 0.4 + Vector3(0, 0.04 + 0.48, 0), back, 1)
			var across := Vector3(f.z, 0, -f.x)
			var each := length / 2.0
			for k: float in [-0.5, 0.5]:
				_put("floral_sofa", at - f * 0.12 + across * each * k + Vector3(0, 0.06, 0), atan2(f.x, f.z),
					Vector3(each, 1.0, 1.05))
		else:
			solid(at + f * 0.09 + Vector3(0, 0.06 + 0.22, 0), seat, _m.cream)   # top at 0.5
			solid(at - f * 0.4 + Vector3(0, 0.04 + 0.48, 0), back, _m.cream)    # top at 1.0
	solid(Vector3(0, 0.3, -124.0), Vector3(2.4, 0.5, 1.4), _m.planks)               # the coffee table
	solid(Vector3(-10.5, 1.1, -133.0), Vector3(2.0, 2.2, 1.0), _m.navy)              # the kit cupboard (Open, step 3)
	_sign("PARTY\nKITS", Vector3(-10.5, 1.6, -132.45), 0.0, Color("e8e0d0"), 16, false)
	for lp: Vector3 in [Vector3(-5.0, 2.9, -121.0), Vector3(5.0, 2.9, -121.0), Vector3(0, 2.9, -130.0)]:
		_light(lp, Color("ffc890"), 2.4, 9.0)
	_living_room(x0, x1, z0, z1, t)


## Dressing the living room so it reads from inside: a rug, the fireplace on the west wall with her sign over the
## mantel, standard lamps lit warm, net curtains on the front windows, the kit cupboard's shelf of boxes.
func _living_room(x0: float, x1: float, z0: float, z1: float, t: float) -> void:
	deco(Vector3(0, 0.1, -124.0), Vector3(8.0, 0.02, 6.0), _m.red)                    # the rug, on the carpet
	# The fireplace against the west wall (its inside face at x0 + t), the mantel, the glow, her sign above it.
	var wx := x0 + t
	solid(Vector3(wx + 0.32, 0.6, -125.0), Vector3(0.6, 1.2, 2.4), _m.stone)   # 2 cm off the wall (the carpet's edge)
	deco(Vector3(wx + 0.62, 0.45, -125.0), Vector3(0.04, 0.6, 1.2), _unlit(Color(2.4, 1.0, 0.4)))
	deco(Vector3(wx + 0.4, 1.28, -125.0), Vector3(0.8, 0.12, 2.8), _m.planks)
	deco(Vector3(wx + 0.03, 2.2, -125.0), Vector3(0.04, 0.9, 2.4), _m.cream)
	_sign("SWYNE\nFOR DECENCY", Vector3(wx + 0.06, 2.2, -125.0), PI / 2.0, Color("24304e"), 26, false)
	for dz: float in [-0.9, 0.9]:
		deco(Vector3(wx + 0.4, 1.5, -125.0 + dz), Vector3(0.16, 0.32, 0.16), _m.brass)   # candlesticks
	_light(Vector3(wx + 1.0, 0.7, -125.0), Color("ff9050"), 1.2, 4.0)
	# Standard lamps, lit, in two corners.
	for lp: Vector3 in [Vector3(-9.6, 0, -118.6), Vector3(9.6, 0, -131.0)]:
		deco(lp + Vector3(0, 0.85, 0), Vector3(0.08, 1.7, 0.08), _m.brass)
		deco(lp + Vector3(0, 1.85, 0), Vector3(0.6, 0.4, 0.6), _m.net)
		_light(lp + Vector3(0, 1.8, 0), Color("ffc080"), 1.4, 5.0)
	# Net curtains on the front windows, seen from inside (the inside face of the front wall is at z0 - t / 2).
	for x: float in [-7.5, -4.0, 4.0, 7.5]:
		deco(Vector3(x, 1.7, z0 - t / 2.0 - 0.04), Vector3(1.6, 1.3, 0.06), _m.net)
	# Party kits stacked on top of the cupboard, and a banner over the back wall.
	for i in 3:
		deco(Vector3(-10.5 - 0.6 + i * 0.6, 2.42, -133.0), Vector3(0.5, 0.4, 0.6), _m.cream)
	deco(Vector3(0, 2.7, z1 + t / 2.0 + 0.04), Vector3(6.0, 0.6, 0.04), _m.cream)
	_sign("THE DECENCY HOME COLLECTION", Vector3(0, 2.7, z1 + t / 2.0 + 0.07), 0.0, Color("24304e"), 24, false)
	for s: float in [-1.0, 1.0]:
		deco(Vector3(s * 3.0, 0.45, -124.0), Vector3(0.6, 0.7, 0.6), _m.cream)             # pouffes by the sofas
	deco(Vector3(0, 0.62, -124.0), Vector3(0.4, 0.2, 0.3), _m.navy)                      # a kit, open on the table
	# Outside: lit windows, the sign she made herself, her lamps.
	if not _has_prop("pr_show_home"):
		for x: float in [-7.5, -4.0, 4.0, 7.5]:
			deco(Vector3(x, 1.7, z0 + 0.24), Vector3(1.6, 1.3, 0.06), _m.net)
			deco(Vector3(x, 4.9, z0 + 0.24), Vector3(1.4, 1.2, 0.06), _m.net)
	_sign("THE SHOW HOME\nby appointment", Vector3(0, 4.0, z0 + 0.75), 0.0, Color(2.2, 1.9, 0.9), 34)
	_lawn_sign(Vector3(6.0, LAWN, -114.0), Vector3(0, 0, 1))
	# The back door to the conservatory: locked until the party's done (WO-015 step 3 sets primrose/party_done).
	if not Game.has_flag("primrose/party_done"):
		var lock := block(Vector3(0, 1.2, z1), Vector3(2.0, 2.4, t), _m.door, self, true)
		lock.name = "GardenDoor"


# --- the Conservatory and Garden -------------------------------------------------------------------------------------

## Behind the Show Home: her topiary garden in high hedges, the glass conservatory, the sprinklers' heads, her bench and
## the sign (the boss, step 4). Only through her back door.
func _garden() -> void:
	solid(Vector3(0, LAWN / 2.0, -156.0), Vector3(44.0, LAWN, 40.0), _m.lawn)     # x -22..22, z -136..-176
	solid(Vector3(-22.5, 1.75, -156.0), Vector3(1.0, 3.5, 41.0), _m.hedge)
	solid(Vector3(22.5, 1.75, -156.0), Vector3(1.0, 3.5, 41.0), _m.hedge)
	solid(Vector3(0, 1.75, -176.5), Vector3(46.0, 3.5, 1.0), _m.hedge)
	for s: float in [-1.0, 1.0]:
		solid(Vector3(s * 17.15, 1.75, -136.35), Vector3(9.5, 3.5, 0.6), _m.hedge)   # from the house's corners to the side hedges
	# The conservatory: glass on a white frame (its posts solid), against the house's back.
	var cz := -142.0
	deco(Vector3(0, 1.8, cz), Vector3(15.8, 3.6, 7.8), _m.conservatory)
	for x: float in [-8.0, 8.0]:
		for z: float in [-138.2, -145.9]:
			solid(Vector3(x, 1.9, z), Vector3(0.2, 3.8, 0.2), _m.white)
	deco(Vector3(0, 3.9, cz), Vector3(16.4, 0.2, 8.4), _m.white)
	# Topiary: cones and balls in rows, tall enough to climb onto (step 4: out of the water).
	for row in 3:
		for col in 4:
			var at := Vector3(-15.0 + col * 10.0, LAWN, -152.0 - row * 8.0)
			if (row + col) % 2 == 0:
				solid(at + Vector3(0, 0.6, 0), Vector3(1.6, 1.2, 1.6), _m.topiary)
				var ball := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = 1.0
				sm.height = 2.0
				ball.mesh = sm
				ball.material_override = _m.topiary
				ball.position = at + Vector3(0, 2.1, 0)
				add_child(ball)
				_col(at + Vector3(0, 2.1, 0), Vector3(1.6, 1.8, 1.6), 1)
			else:
				var cone := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = 0.05
				cm.bottom_radius = 1.0
				cm.height = 3.0
				cone.mesh = cm
				cone.material_override = _m.topiary
				cone.position = at + Vector3(0, 1.5, 0)
				add_child(cone)
				_col(at + Vector3(0, 1.0, 0), Vector3(1.4, 2.0, 1.4), 1)
			deco(at + Vector3(2.5, 0.12, 2.5), Vector3(0.2, 0.24, 0.2), _m.brass)   # a sprinkler head
	# Her bench under the sign she made herself (the punchline, step 4), and the sprinklers' control box.
	if _has_prop("garden_bench"):
		_col(Vector3(0, 0.45, -173.5), Vector3(3.0, 0.9, 0.9), 1)
		_put("garden_bench", Vector3(0, LAWN, -173.5), 0.0, Vector3(3.0, 1.0, 0.9))
	else:
		solid(Vector3(0, 0.45, -173.5), Vector3(3.0, 0.9, 0.9), _m.white)
	# Swans either side of her bench, and a pair guarding the conservatory's doors.
	for sw: Array in [[-3.2, -173.6, 0.0], [3.2, -173.6, 0.0], [-2.6, -146.8, PI], [2.6, -146.8, PI]]:
		_put("topiary_swan", Vector3(sw[0], LAWN, sw[1]), sw[2] + (0.5 if sw[0] < 0 else -0.5))
	deco(Vector3(0, 2.6, -175.6), Vector3(3.6, 1.0, 0.1), _m.cream)
	_sign("SWYNE FOR DECENCY", Vector3(0, 2.6, -175.5), 0.0, Color("24304e"), 26, false)
	solid(Vector3(20.5, 0.7, -140.0), Vector3(1.0, 1.4, 0.8), _m.navy)
	_light(Vector3(0, 3.0, -142.0), Color("d0f0e0"), 1.6, 10.0)
	_light(Vector3(0, 3.5, -162.0), Color("a0c0ff"), 1.4, 14.0)


# --- people ----------------------------------------------------------------------------------------------------------

func _people() -> void:
	# The bulldog delivery men on their rounds: the road, the gardens, the hall, the allotments, the head.
	_goon(&"c_road1", Vector3(2.5, 0.05, -10), [Vector3(2.5, 0, -10), Vector3(2.5, 0, -60)])
	_goon(&"c_road2", Vector3(-2.5, 0.05, -95), [Vector3(-2.5, 0, -95), Vector3(-2.5, 0, -40)])
	_goon(&"c_head", Vector3(0, 0.05, -108.5), [], PI)
	_goon(&"g_west", Vector3(-30.0, LAWN + 0.05, -16), [Vector3(-30, LAWN, -16), Vector3(-30, LAWN, -84)])
	_goon(&"g_east", Vector3(40.0, LAWN + 0.05, -84), [Vector3(40, LAWN, -84), Vector3(40, LAWN, -56)])
	_goon(&"h_porch", Vector3(51.5, 0.05, -42.5), [], -PI / 2.0)
	_goon(&"h_inside", Vector3(72.0, 0.17, -28.0), [Vector3(72, 0.12, -28), Vector3(72, 0.12, -48)])
	_goon(&"a_rounds", Vector3(-60.0, 0.05, -2.0), [Vector3(-60, 0, -2), Vector3(-82, 0, -2), Vector3(-82, 0, -100), Vector3(-60, 0, -100)])
	_goon(&"a_marrows", Vector3(-55.0, 0.05, -108.0), [], PI / 2.0)
	_goon(&"v_back", Vector3(96.0, LAWN + 0.05, -44.0), [Vector3(96, LAWN, -44), Vector3(96, LAWN, -20)])
	# The Neighbourhood Watch: meerkats on their posts and porches. They don't fight; they raise the alarm (step 2:
	# the phone tree).
	_watch(Vector3(9.0, LAWN, -6.0), PI / 4.0, 2.2)          # by the hut, watching the road
	_watch(Vector3(-13.0, PAVE, -51.0), -PI / 2.0, 0.6)       # number 9's porch
	_watch(Vector3(13.0, PAVE, -74.0), PI / 2.0, 0.6)         # number 12's porch
	_watch(Vector3(-46.0, 0.0, -6.0), 0.0, 2.4)               # over the hedge, by the allotment gate
	_watch(Vector3(52.0, LAWN, -22.0), PI / 2.0, 2.2)         # the churchyard's corner
	_watch(Vector3(8.0, PAVE, -110.0), 0.0, 2.2)              # the head, watching the Show Home's door


func _goon(id: StringName, at: Vector3, route: Array, yaw := 0.0) -> Enemy:
	var g := Enemy.new()
	g.id = id
	g.name = "Goon_%s" % id
	g.body = "bulldog_goon"
	g.patrol = PackedVector3Array(route)
	g.position = at
	g.rotation.y = yaw
	add_child(g)
	return g


func _watch(at: Vector3, watch: float, perch: float) -> Lookout:
	var m := Lookout.new()
	m.name = "Watch_%d" % get_child_count()
	m.position = at
	m.perch_height = perch
	m.look_body = "meerkat_watch"
	m.watch_yaw = watch
	add_child(m)
	return m


# --- collectibles ----------------------------------------------------------------------------------------------------

func _collectibles() -> void:
	# The Coalition's collection tin, on the church porch.
	tin(Vector3(52.2, 0.0, HALL_DOOR_Z + 1.2), -PI / 2.0)
	# Keys placed in step 1: the belfry (4: the steeple, climbed in the rain). The rest come from their scripts in
	# step 2 (1 Grizelda's test at number 4, 2 the bake sale, 3 the raffle, 5 the allotment stash, 6 the washing
	# lines, 7 the Watch's logbook, 8 the van), the party (9, step 3); Key 10 is paid by the five neighbours.
	key(&"primrose_04", Vector3(TOWER.x - 1.4, BELFRY + 0.3, TOWER.z - 1.4))
	# The five neighbours who bought early, mowing the same strip of lawn, over and over.
	var mowers := [[-11.0, -22.0, "hare_civilian", Color("c8a0d0")], [11.0, -10.0, "otter_civilian", Color("a0c0d8")],
		[-11.0, -70.0, "fox_civilian", Color("e0c890")], [11.0, -82.0, "hedgehog_civilian", Color("a8d0a8")],
		[-19.0, -101.0, "otter_civilian", Color("d8b0a0")]]
	for i in mowers.size():
		var m: Array = mowers[i]
		var x: float = m[0]
		var z: float = m[1]
		var w := 1.2 if absf(x) < 15.0 else 1.0
		sleeper(StringName("n%d" % (i + 1)), Vector3(x - w, LAWN + 0.05, z + 2.5),
			PackedVector3Array([Vector3(x - w, LAWN, z + 2.5), Vector3(x - w, LAWN, z - 2.5), Vector3(x + w, LAWN, z - 2.5),
			Vector3(x + w, LAWN, z + 2.5)]), m[2], m[3])
	# 100 contraband: boxes of "literature" and party kits.
	# On the porches of the Close (12): a box by each door but number 4's, and the two at the head.
	for k in 6:
		_cb(Vector3(-13.6, PAVE, -10.0 - PLOT * k - 5.0))
	for k in 7:
		var z := -10.0 - PLOT * k
		if absf(z - PATH_Z) < 1.0 or k == 1:
			continue
		_cb(Vector3(13.6, PAVE, z - 5.0))
	# Along the garden fences' tops (14): two on each side's middle fences.
	for k in range(1, 8):
		_cb(Vector3(-30.0, 1.85, -4.0 - PLOT * k))
		_cb(Vector3(42.0 if k != 4 else 28.0, 1.85, -4.0 - PLOT * k))
	# On the sheds' roofs (8) and by the greenhouses (6).
	for sh: Array in [[-40.0, -34.0], [-41.0, -70.0], [38.0, -22.0], [41.0, -80.0]]:
		_cb(Vector3(sh[0] - 0.5, LAWN + 2.32, sh[1]))
		_cb(Vector3(sh[0] + 0.5, LAWN + 2.32, sh[1]))
	for gh: Array in [[-30.0, -46.0], [30.0, -10.0], [30.0, -68.0]]:
		_cb(Vector3(gh[0] + 2.0, LAWN, gh[1] + 2.6))
		_cb(Vector3(gh[0] - 2.0, LAWN, gh[1] + 2.6))
	# The van's load (6), stacked by its open side.
	for i in 6:
		_cb(Vector3(-31.4, LAWN + (i / 3) * 0.6, -60.0 + (i % 3) * 1.0))
	# St. Prudence's (16): the bake sale's tables, the raffle, the stage, the belfry, the vicarage step.
	for t: Array in [[60.0, -30.0], [60.0, -36.0], [68.0, -30.0]]:
		for j in 3:
			_cb(Vector3(t[0] - 1.0 + j, 0.9, t[1]))
	for j in 4:
		_cb(Vector3(77.0 + (j % 2), 1.2, -34.0 - j * 2.0))
	_cb(Vector3(TOWER.x + 1.4, BELFRY + 0.3, TOWER.z + 1.4))
	_cb(Vector3(TOWER.x - 1.4, BELFRY + 0.3, TOWER.z + 1.4))
	_cb(Vector3(92.0, LAWN, -24.6))
	# The allotments (30): the stash under the prize marrows (20, Key 5), and along the plots (10).
	for i in 20:
		_cb(Vector3(-63.5 + (i % 10) * 0.75, 0.3, -110.5 - float(i / 10) * 1.0))
	for row in 5:
		_cb(Vector3(-51.5, 0.0, -12.0 - row * 20.0))
		_cb(Vector3(-90.0, 0.0, -12.0 - row * 20.0))
	# The Watch hut's roof (2), the head (2), the Show Home's lawn (2).
	_cb(Vector3(10.5, LAWN + 2.6, -1.0))
	_cb(Vector3(11.5, LAWN + 2.6, -1.0))
	_cb(Vector3(-15.5, PAVE, -96.0))
	_cb(Vector3(15.5, PAVE, -106.0))
	_cb(Vector3(-9.0, LAWN, -114.4))
	_cb(Vector3(9.0, LAWN, -114.4))
	while _contraband < 100:
		# Any short of a hundred: along Allotment Lane.
		_cb(Vector3(-12.0 - (_contraband % 18) * 2.0, PAVE, 3.0))


func _cb(at: Vector3) -> void:
	_contraband += 1
	contraband(StringName("c%03d" % _contraband), at)


# --- the Keys' scripts (WO-015 step 2; levels/primrose/keys/) --------------------------------------------------------

const KEY_SCRIPTS := {
	"VesperLesson": "res://levels/primrose/keys/vesper_lesson.gd",
	"GrizeldaTest": "res://levels/primrose/keys/grizelda_test.gd",
	"BakeSale": "res://levels/primrose/keys/bake_sale.gd",
	"Raffle": "res://levels/primrose/keys/raffle.gd",
	"Steeple": "res://levels/primrose/keys/steeple.gd",
	"Stash": "res://levels/primrose/keys/stash.gd",
	"WashingLines": "res://levels/primrose/keys/washing_lines.gd",
	"Logbook": "res://levels/primrose/keys/logbook.gd",
	"Van": "res://levels/primrose/keys/van.gd",
	"Curtains": "res://levels/primrose/keys/curtains.gd",
	"Party": "res://levels/primrose/keys/party.gd",   # Key 9, the set piece (step 3)
	"Gander": "res://levels/primrose/keys/gander.gd",   # the boss (step 4)
}


func _keys() -> void:
	for n: String in KEY_SCRIPTS:
		var k := Node3D.new()
		k.set_script(load(KEY_SCRIPTS[n]))
		k.name = n
		add_child(k)
	# The dialogue asks "primrose/in_suit" (the tea, the stall, the Watch captain): kept up to date.
	var n := nim as Nim
	if n:
		Game.set_flag("primrose/in_suit", n.suit.in_suit())
		n.suit.outfit_changed.connect(func(_o: int) -> void: Game.set_flag("primrose/in_suit", n.suit.in_suit()))


# --- places: zones, checkpoints, fast travel -------------------------------------------------------------------------

func _places() -> void:
	zone("The Close", Vector3(0, -0.2, -52.0), Vector3(34, 12, 122))
	zone("The Back Gardens", Vector3(-35.0, -0.2, -46.0), Vector3(22, 10, 84))
	zone("The Back Gardens", Vector3(35.0, -0.2, -46.0), Vector3(22, 10, 84))
	zone("St. Prudence's", Vector3(74.0, -0.2, -44.0), Vector3(52, 30, 92))
	zone("The Allotments", Vector3(-72.0, -0.2, -58.0), Vector3(48, 10, 126))
	zone("The Show Home", Vector3(0, -0.2, -126.0), Vector3(24, 10, 20))
	zone("The Conservatory and Garden", Vector3(0, -0.2, -156.0), Vector3(44, 12, 40))
	checkpoint_at(Vector3(0, 0, 2.0), 0.0)
	checkpoint_at(Vector3(0, 0, -100.0), 0.0)
	checkpoint_at(Vector3(49.0, LAWN, -49.0), PI / 2.0)
	checkpoint_at(Vector3(-56.0, 0, 0.0), PI / 2.0)
	checkpoint_at(Vector3(-35.0, LAWN, -28.0), 0.0)
	checkpoint_at(Vector3(35.0, LAWN, -60.0), 0.0)
	checkpoint_at(Vector3(0, 0, -138.5), PI)   # just inside the garden's door (step 4's fight)
	travel_point(&"close", "The Close", Vector3(-6.5, PAVE, -2.0))
	travel_point(&"church", "St. Prudence's", Vector3(50.5, LAWN, -38.0))
