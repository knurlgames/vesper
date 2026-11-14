class_name Hub
extends BuiltWorld
## The hub: the Old Quarter around the Velvet Rope (DESIGN.md "The worlds"; WO-014 step 5), at night in the rain.
##
## Sized to Banjo's lessons (docs/STUDY.md §4, and the owner's "remember the sizing principles from Banjo"):
##   - mid-sized and grown by area, Tooie-style, with Kazooie's sense of a path: one square, one short street per world;
##   - small enough to hold in your head: the square is 40 m across (6 s at a run), the club on its north side is the
##     landmark from everywhere, and each world's door is at the end of a street you can see down;
##   - short walks: the club's door to the Pier's gate is about 70 m (about 12 s);
##   - fast travel from the start (the club, the seafront), a teacher (Vesper, in the club);
##   - the gates are characters you can read: each street ends at a rank door showing its Key count.
##
##   Rope Square      x -20..20, z -16..20      cobbles, the lamp cluster in the middle
##   The Velvet Rope  x -11..11, z -38..-16     the door on the square (Bastion); inside, the lounge (z -16..-30, the
##                                              sisters, the bar, the members' wardrobe) and, down a ramp, the dungeon
##                                              (floor y -1.6, the prologue)
##   Seafront Road    x 20..80, z -2..12        east to the sea wall and the Pier's gate (rank 1); a marked alley wall
##                                              up to the rooftops, and over them a hub Key (hub_07)
##   Street stubs     one per later world, each ending at its rank door: Primrose Lane (south), Hillside Road (the
##                    Retreat, south), Dock Street (west), Press Alley (west), Council Avenue (the Ball, north), Clock
##                    Tower Way (City Hall, north). Built out as their worlds come (WO-015 on).

## Rivet's rates for seized contraband (see _hand_in): a lure per 25, an upgrade per 100 (a world's worth).
const LURE_EVERY := 25
const UPGRADE_EVERY := 100
const STREET := 0.0
const DUNGEON := -1.6
const CEILING := 4.5
const CLUB_DOOR := Vector3(0.0, 0.05, -12.5)
## The vaults under the street behind the club (WO-014b): floor and ceiling heights.
const VAULT := -5.0
const VAULT_TOP := -1.5
## The rooms off the vaults' hall: west x -12..-4, east 4..12, each 7 m along the hall. `at` is the room's middle
## (where a client stands for a session), `sister` whose it is, its doorway on the hall at `at.z`. `spot` (optional)
## is where she stands, clear of the furniture; `far` (optional) is the outer wall's x, when the room's bigger.
const ROOMS := [
	{"id": &"parlour", "title": "THE PARLOUR", "sister": "Augusta", "at": Vector3(-8.0, VAULT, -51.5), "light": Color("ffb070"), "sessions": true},
	{"id": &"rope", "title": "THE ROPE ROOM", "sister": "Silke", "at": Vector3(-8.0, VAULT, -58.5), "light": Color("ff4060"), "sessions": true,
		"spot": Vector3(-8.4, VAULT, -60.6)},
	{"id": &"throne", "title": "THE THRONE ROOM", "sister": "Grizelda", "at": Vector3(-8.0, VAULT, -65.5), "light": Color("c070ff"), "sessions": true},
	# Twice the size (owner, Deck review 3: "the quiet room needs more space and not have everyone in there all
	# overlapping on the same couch"): it runs east under the street to x 20, a seat for everyone (QUIET_SEATS).
	{"id": &"quiet", "title": "THE QUIET ROOM", "sister": "Lull", "at": Vector3(12.0, VAULT, -51.5), "light": Color("80a0ff"), "sessions": false,
		"spot": Vector3(6.8, VAULT, -53.0), "far": 20.0},
	{"id": &"dash", "title": "DASH'S", "sister": "Dash", "at": Vector3(8.0, VAULT, -58.5), "light": Color("ffa040"), "sessions": true},
	{"id": &"workshop", "title": "WORKSHOP", "sister": "Rivet", "at": Vector3(8.0, VAULT, -65.5), "light": Color("e0e0ff"), "sessions": false},
]
## The changing screen in the vaults' hall, by the cross, its front to the hall (+X).
const SCREEN := Vector3(-3.15, VAULT, -68.4)
## The Backroom's middle (the map table), behind the end wall.
const BACKROOM := Vector3(1.0, VAULT, -74.8)
## The Quiet Room's seats (Meshy chaises, 2.0 x 0.89): [middle, the way it faces]. Four for clients' aftercare, one
## each (club_life); the last, NOOK, is where a scene on the cross ends (CrossScene._aftercare).
const QUIET_SEATS := [
	[Vector3(9.5, VAULT, -48.65), Vector3(0, 0, -1)], [Vector3(12.6, VAULT, -48.65), Vector3(0, 0, -1)],
	[Vector3(19.45, VAULT, -49.9), Vector3(-1, 0, 0)], [Vector3(19.45, VAULT, -53.1), Vector3(-1, 0, 0)],
	[Vector3(16.0, VAULT, -54.4), Vector3(0, 0, 1)],
]
const NOOK := 4
## How far in from a chaise's front edge someone sits (the sit-and-drink clip's hips land over the seat).
const SEAT_IN := 0.24
const SEAFRONT := Vector3(70.0, 0.05, 5.0)
const PROLOGUE_AT := Vector3(-4.0, DUNGEON + 0.05, -34.0)

## The later worlds' streets: [world, name, mouth on the square's edge, outward direction].
const STUBS := [
	[&"primrose", "PRIMROSE LANE", Vector3(-8, 0, 20), Vector3(0, 0, 1)],
	[&"retreat", "HILLSIDE ROAD", Vector3(10, 0, 20), Vector3(0, 0, 1)],
	[&"docks", "DOCK STREET", Vector3(-20, 0, -6), Vector3(-1, 0, 0)],
	[&"press", "PRESS ALLEY", Vector3(-20, 0, 10), Vector3(-1, 0, 0)],
	[&"ball", "COUNCIL AVENUE", Vector3(16, 0, -16), Vector3(0, 0, -1)],
	[&"city_hall", "CLOCK TOWER WAY", Vector3(-16, 0, -16), Vector3(0, 0, -1)],
]

var _m := {}
var _rng := RandomNumberGenerator.new()
## Every house's box, and the lit windows waiting for them all (`_place_windows`).
var _houses: Array[AABB] = []
var _steps: Array[int] = []
var _windows: Array = []


func _ready() -> void:
	world_id = &"hub"
	load_data()
	_rng.seed = 5
	_materials()
	_environment()
	_ground()
	_square()
	_club()
	_vaults()
	_seafront()
	for s: Array in STUBS:
		_stub(s[0], s[1], s[2], s[3])
	_people()
	_places()
	var life := Node.new()
	life.set_script(load("res://levels/hub/club_life.gd"))
	life.name = "ClubLife"
	add_child(life)
	var p := Node3D.new()
	p.set_script(load("res://levels/hub/prologue.gd"))
	p.name = "Prologue"
	add_child(p)
	_rain()
	_place_windows()
	_flush()
	arrival("club_door", CLUB_DOOR, 0.0)
	arrival("start", CLUB_DOOR, 0.0)
	arrival("seafront", SEAFRONT, -PI / 2.0)
	arrival("primrose", Vector3(-8.0, 0.05, 30.0), 0.0)   # back from Primrose Close: Primrose Lane, facing the square
	arrival("prologue", PROLOGUE_AT, -PI / 2.0)
	var first := not Game.has_flag("hub/prologue_done")
	spawn_player(PROLOGUE_AT if first else CLUB_DOOR, -PI / 2.0 if first else 0.0)
	finish()


# --- materials and light ---------------------------------------------------------------------------------------------

func _materials() -> void:
	_m.cobbles = Look.painted(Look.Pattern.COBBLES, Color("4a4658"), Color("15121c"), {"wet": 0.85, "puddles": 0.5})
	_m.flags = Look.painted(Look.Pattern.FLAGSTONES, Color("5c5866"), Color("201c26"), {"wet": 0.8, "puddles": 0.3})
	_m.brick = Look.painted(Look.Pattern.BRICK, Color("6a3c34"), Color("1e1418"), {"wet": 0.6})
	_m.brick_dark = Look.painted(Look.Pattern.BRICK, Color("3e3440"), Color("141018"), {"wet": 0.6})
	_m.plaster = Look.painted(Look.Pattern.PLASTER, Color("7a7266"), Color("201c22"), {"wet": 0.5})
	_m.plaster_blue = Look.painted(Look.Pattern.PLASTER, Color("4c5a66"), Color("161a20"), {"wet": 0.5})
	_m.club = Look.painted(Look.Pattern.PLASTER, Color("3a2a3e"), Color("140c16"), {"wet": 0.55})
	_m.club_in = Look.painted(Look.Pattern.PLASTER, Color("4a1e2c"), Color("1a0a10"), {"wet": 0.0})
	_m.dungeon = Look.painted(Look.Pattern.BRICK, Color("2e2428"), Color("0e0a0c"), {"wet": 0.1})
	_m.carpet = Look.toon(Color("5a1424"))
	_m.stone = Look.painted(Look.Pattern.FLAGSTONES, Color("3a3436"), Color("141012"), {"wet": 0.1})
	_m.slate = Look.painted(Look.Pattern.SLATE, Color("2e3444"), Color("0e1018"), {"wet": 0.9})
	_m.sill = Look.painted(Look.Pattern.PLASTER, Color("6a6470"), Color("201c26"), {"wet": 0.5})
	_m.climb = Look.painted(Look.Pattern.BRICK, Color("4f8a5a"), Color("173020"), {"wet": 0.5, "scale": 1.6})
	_m.ink = Look.toon(Look.INK)
	_m.brass = Look.toon(Look.BRASS, 0.7)
	_m.velvet = Look.toon(Look.VELVET, 0.25)
	_m.leather = Look.toon(Color("1c1418"), 0.6)
	_m.wood = Look.toon(Color("3a2218"))
	_m.rail = Look.toon(Color("d8d0c0"), 0.2)
	_m.lit = _unlit(Color("ffb862"))
	_m.glass = Look.toon(Color("0d1424"), 0.8)
	_m.lamp = _unlit(Color(2.0, 1.4, 0.8))


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
	env.fog_density = 0.02
	env.fog_height = 0.6
	env.fog_height_density = 0.1
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Look.MOON
	moon.light_energy = 0.45
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 45.0
	moon.rotation = Vector3(deg_to_rad(-58), deg_to_rad(-140), 0)
	add_child(moon)


# --- the ground ------------------------------------------------------------------------------------------------------

## Everywhere but under the club, whose floors are its own (the dungeon is below street level).
func _ground() -> void:
	solid(Vector3(15, -0.5, 22), Vector3(150, 1, 76), _m.cobbles)          # z -16..60
	solid(Vector3(-35.5, -0.5, -38), Vector3(49, 1, 44), _m.cobbles)       # x -60..-11, z -60..-16
	solid(Vector3(50.5, -0.5, -38), Vector3(79, 1, 44), _m.cobbles)        # x 11..90
	# x -11..11, z -60..-38, behind the club: open over the stair annex down to the vaults (x -2..2, z -38..-48).
	solid(Vector3(-6.5, -0.5, -49), Vector3(9, 1, 22), _m.cobbles)
	solid(Vector3(6.5, -0.5, -49), Vector3(9, 1, 22), _m.cobbles)
	solid(Vector3(0, -0.5, -54), Vector3(4, 1, 12), _m.cobbles)


# --- Rope Square -----------------------------------------------------------------------------------------------------

func _square() -> void:
	# The lamp cluster in the middle: a plinth and four lamps, the square's own landmark.
	solid(Vector3(0, 0.5, 2), Vector3(2.4, 1.0, 2.4), _m.sill)
	solid(Vector3(0, 2.6, 2), Vector3(0.3, 3.2, 0.3), _m.ink)
	for d: Vector3 in [Vector3(0.7, 0, 0), Vector3(-0.7, 0, 0), Vector3(0, 0, 0.7), Vector3(0, 0, -0.7)]:
		deco(Vector3(0, 4.0, 2) + d, Vector3(0.35, 0.45, 0.35), _m.lamp)
	_light(Vector3(0, 4.3, 2), Look.SODIUM, 3.5, 14.0)
	# Benches, and lamps at the corners.
	for b: Vector3 in [Vector3(-6, 0, 2), Vector3(6, 0, 2)]:
		solid(b + Vector3(0, 0.25, 0), Vector3(0.6, 0.5, 1.8), _m.wood)
	for l: Vector3 in [Vector3(-17, 0, -13), Vector3(17, 0, -13), Vector3(-17, 0, 17), Vector3(17, 0, 17)]:
		_lamp(l)
	# The square's edges: terraces, gaps left for the club, Seafront Road and the six street stubs.
	for e: Array in [
		[Vector2(-28, -24), Vector2(-19, -16), 11.0, _m.brick], [Vector2(-13, -24), Vector2(-11, -16), 10.0, _m.plaster],
		[Vector2(11, -24), Vector2(13, -16), 10.0, _m.plaster], [Vector2(19, -24), Vector2(28, -16), 12.0, _m.brick_dark],
		[Vector2(20, -16), Vector2(28, -10), 12.0, _m.brick_dark],
		[Vector2(20, 20), Vector2(28, 28), 10.0, _m.plaster_blue],
		[Vector2(-28, 20), Vector2(-11, 28), 10.5, _m.brick], [Vector2(-5, 20), Vector2(7, 28), 9.0, _m.plaster_blue],
		[Vector2(13, 20), Vector2(20, 28), 11.0, _m.brick_dark],
		[Vector2(-28, -16), Vector2(-20, -9), 9.5, _m.plaster], [Vector2(-28, -3), Vector2(-20, 7), 11.0, _m.brick],
		[Vector2(-28, 13), Vector2(-20, 20), 10.0, _m.plaster_blue]]:
		_house(e[0], e[1], e[2], e[3])


# --- the Velvet Rope -------------------------------------------------------------------------------------------------

func _club() -> void:
	var h := 13.6
	# The shell: walls 0.4 thick from the dungeon's floor up; the door (2 m wide, 2.8 tall) in the south face.
	solid(Vector3(-6.0, (h + DUNGEON) / 2.0, -16.2), Vector3(10.0, h - DUNGEON, 0.4), _m.club)
	solid(Vector3(6.0, (h + DUNGEON) / 2.0, -16.2), Vector3(10.0, h - DUNGEON, 0.4), _m.club)
	solid(Vector3(0, (2.8 + h) / 2.0, -16.2), Vector3(2.0, h - 2.8, 0.4), _m.club)
	# The north wall, with a doorway (x -1.5..1.5, 2.6 tall) from the dungeon to the stair down to the vaults.
	solid(Vector3(-6.25, (h + DUNGEON) / 2.0, -37.8), Vector3(9.5, h - DUNGEON, 0.4), _m.club)
	solid(Vector3(6.25, (h + DUNGEON) / 2.0, -37.8), Vector3(9.5, h - DUNGEON, 0.4), _m.club)
	solid(Vector3(0, (DUNGEON + 2.6 + h) / 2.0, -37.8), Vector3(3.0, h - DUNGEON - 2.6, 0.4), _m.club)
	solid(Vector3(-10.8, (h + DUNGEON) / 2.0, -27.0), Vector3(0.4, h - DUNGEON, 22.0), _m.club)
	solid(Vector3(10.8, (h + DUNGEON) / 2.0, -27.0), Vector3(0.4, h - DUNGEON, 22.0), _m.club)
	# Inside: the ceiling, the roof and its cornice; windows on the square.
	solid(Vector3(0, CEILING + 0.15, -27.0), Vector3(21.2, 0.3, 21.2), _m.club_in)
	solid(Vector3(0, h - 0.2, -27.0), Vector3(21.2, 0.38, 21.2), _m.slate)   # inside the walls: flush, they fought
	# The Velvet Rope's outside: the Meshy music hall (aubergine brick, stone trim, its arched windows lit) round the
	# walls, its doorway cut over the game's (props.py club_front). Without it, the cornice and the lit windows.
	if ResourceLoader.exists(PROP_PATH % "club_front"):
		props("club_front", [[Vector3(0, STREET, -27.0), 0.0]], false)   # (its built size: its walls are fitted to these)
	else:
		deco(Vector3(0, h + 0.15, -27.0), Vector3(22.6, 0.3, 22.6), _m.sill)
		for k in [1, 2, 3]:
			for i in 6:
				var x := -8.75 + i * 3.5
				if k == 1 and absf(x) < 2.0:
					continue
				_window(Vector3(x, k * 3.4 + 1.9, -16.0), i % 3 != 1)
	# The floors: the lounge at street level, cut for the ramp (x 6..9 from z -27.5 on); the dungeon 1.6 m down.
	solid(Vector3(-2.3, -0.5, -23.3), Vector3(16.56, 1.0, 13.8), _m.carpet)      # x -10.6..6, z -16.4..-30.2 (ends 2 cm in from the wall's)
	solid(Vector3(9.8, -0.5, -23.3), Vector3(1.56, 1.0, 13.8), _m.carpet)         # x 9..10.6
	solid(Vector3(7.5, -0.5, -21.95), Vector3(3.0, 1.0, 11.1), _m.carpet)         # x 6..9, z -16.4..-27.5
	solid(Vector3(0, DUNGEON - 0.5, -33.9), Vector3(21.2, 1.0, 7.4), _m.stone)    # z -30.2..-37.6
	solid(Vector3(7.5, DUNGEON - 0.5, -28.85), Vector3(3.0, 1.0, 2.7), _m.stone)  # under the ramp's foot
	# The ramp down, and the wall between the lounge and the dungeon (a doorway at the ramp).
	var run := 5.0
	var ang := atan2(-DUNGEON, run)
	# 4 cm proud of both floors: flush, its top edge met the lounge floor's edge and she snagged on the seam.
	_slab(Vector3(7.5, DUNGEON / 2.0 - 0.2 / cos(ang) + 0.04, -30.0), Vector3(3.0, 0.4, sqrt(run * run + DUNGEON * DUNGEON)),
		Basis(Vector3.RIGHT, -ang), _m.stone)
	solid(Vector3(-2.3, (CEILING + DUNGEON) / 2.0, -30.3), Vector3(16.6, CEILING - DUNGEON, 0.3), _m.club_in)
	solid(Vector3(9.8, (CEILING + DUNGEON) / 2.0, -30.3), Vector3(1.6, CEILING - DUNGEON, 0.3), _m.club_in)
	solid(Vector3(7.5, (2.4 + CEILING) / 2.0, -30.3), Vector3(3.0, CEILING - 2.4, 0.3), _m.club_in)
	# The lounge: the bar down the west wall, bottles, sofas, low tables, velvet drapes; warm light. The Meshy
	# furniture (owner, 2026-11-13: "the Velvet Rope also needs some art especially in the lobby where you enter")
	# keeps to the greybox's footprints: the guest's seat at the bar (prologue GUEST_SEAT, x -6.6), the way from the
	# door to the ramp (x 6..9), the changing screen (club_life SCREEN) all stay clear.
	_lounge()
	for x: float in [-8.5, -3.0, 3.0, 8.5]:
		deco(Vector3(x, 2.2, -16.65), Vector3(1.6, 4.4, 0.1), _m.velvet)
	_sign("THE VELVET ROPE", Vector3(0, 3.6, -29.95), 0.0, Color(2.2, 0.5, 0.8), 40)
	wardrobe(Vector3(10.2, STREET, -20.0), PI / 2.0, "Wardrobe_club")
	# The dungeon: brick and stone, red light, the Rope's tools on the walls (suggestive, never explicit).
	for side: float in [-1.0, 1.0]:   # the brick facing, either side of the doorway to the vaults
		deco(Vector3(side * 6.25, (CEILING + DUNGEON) / 2.0, -37.55), Vector3(9.4, CEILING - DUNGEON, 0.05), _m.dungeon)
	# A padded bench (the Meshy leather one over its box's collision); coiled rope hung on brass hooks.
	if ResourceLoader.exists(PROP_PATH % "padded_bench"):
		_col(Vector3(-6.0, DUNGEON + 0.45, -35.5), Vector3(2.2, 0.9, 1.0), 1)
		props("padded_bench", [[Vector3(-6.0, DUNGEON, -35.5), 0.0, Vector3(2.2, 0.95, 0.9)]], false)
	else:
		solid(Vector3(-6.0, DUNGEON + 0.45, -35.5), Vector3(2.2, 0.9, 1.0), _m.leather)
	var coils := []
	for i in 6:
		var x := -9.0 + i * 3.2
		if absf(x) < 2.0:
			continue   # the doorway
		coils.append([Vector3(x, DUNGEON + 1.9, -37.42), 0.0, Vector3(0.6, 1.0, 0.3)])
	if not props("rope_coil", coils, false):
		for c: Array in coils:
			var x: float = (c[0] as Vector3).x
			deco(Vector3(x, DUNGEON + 2.2, -37.3), Vector3(0.6, 0.6, 0.1), _m.velvet)       # coiled rope, hung up
			deco(Vector3(x, DUNGEON + 3.0, -37.3), Vector3(0.12, 0.12, 0.12), _m.brass)      # its hook
	for p: Vector3 in [Vector3(-5, DUNGEON + 3.5, -34), Vector3(4, DUNGEON + 3.5, -34)]:
		_light(p, Color("ff4060"), 2.0, 8.0)
	# The door outside: velvet in brass, a canopy, the name, the rope across on its posts, the plaque, red light.
	deco(Vector3(0, 1.4, -15.96), Vector3(2.2, 2.9, 0.1), _m.brass)
	solid(Vector3(0, 3.25, -15.1), Vector3(3.6, 0.35, 1.8), _m.velvet)
	_sign("THE VELVET ROPE", Vector3(0, 3.25, -14.18), 0.0, Color("f2c56a"), 30, false)
	_sign("Members.\nAnd those who ask nicely.", Vector3(1.9, 1.7, -15.7), 0.0, Color("e8d7c0"), 16, false)   # OWNER REVIEW
	# The Meshy posts carry their own rope, swagged toward +X: the left pair's ropes run outward from the door, the
	# right pair turned round to match (the way in, between x -1.9 and 1.9, stays open).
	if not props("rope_stanchion", [[Vector3(-3.4, STREET, -14.6), PI], [Vector3(-2.3, STREET, -14.6), PI],
			[Vector3(2.3, STREET, -14.6), 0.0], [Vector3(3.4, STREET, -14.6), 0.0]]):
		for x: float in [-1.9, 1.9]:
			solid(Vector3(x, 0.5, -14.6), Vector3(0.18, 1.0, 0.18), _m.brass)
		deco(Vector3(-2.6, 0.85, -14.6), Vector3(1.4, 0.07, 0.07), _m.velvet)
		deco(Vector3(2.6, 0.85, -14.6), Vector3(1.4, 0.07, 0.07), _m.velvet)
	# Potted palms either side of the door, under the canopy's light.
	props("potted_palm", [[Vector3(-4.6, STREET, -15.3), 0.4], [Vector3(4.9, STREET, -15.3), -0.8]], true, 0.012)
	_light(Vector3(0, 2.8, -14.8), Color("ff4060"), 2.2, 5.0)


## The lounge inside the door (x -10.6..10.6, z -16.4..-30): the bar and its back shelf down the west wall with
## stools, three Chesterfields round cocktail tables, chandeliers, the host's podium by the door, palms in the corners.
## Each prop falls back to the greybox if its GLB isn't built. Collision is the greybox's (bar, sofas, tables): the
## routes through the room were tuned round those.
func _lounge() -> void:
	# The bar: two 3 m counters end to end (x -9.6, z -19..-28), their fronts to the room (+X).
	if ResourceLoader.exists(PROP_PATH % "lounge_bar"):
		_col(Vector3(-9.6, 0.55, -23.5), Vector3(1.2, 1.1, 9.0), 1)
	else:
		solid(Vector3(-9.6, 0.55, -23.5), Vector3(1.2, 1.1, 9.0), _m.wood)
	# (A prop's front is its +Z: a yaw of +PI/2 turns it to +X, the room.)
	if not props("lounge_bar", [[Vector3(-9.6, 0, -20.5), PI / 2.0, Vector3(3.0, 1.1, 1.2)],
			[Vector3(-9.6, 0, -23.5), PI / 2.0, Vector3(3.0, 1.1, 1.2)], [Vector3(-9.6, 0, -26.5), PI / 2.0,
			Vector3(3.0, 1.1, 1.2)]], false):
		deco(Vector3(-9.6, 1.12, -23.5), Vector3(1.3, 0.06, 9.1), _m.brass)
	# The back shelf against the west wall behind it, bottles lit from above.
	if not props("bar_backshelf", [[Vector3(-10.35, 0, -20.6), PI / 2.0, Vector3(1.7, 2.6, 0.45)],
			[Vector3(-10.35, 0, -23.5), PI / 2.0, Vector3(1.7, 2.6, 0.45)], [Vector3(-10.35, 0, -26.4), PI / 2.0,
			Vector3(1.7, 2.6, 0.45)]], false):
		for i in 8:
			deco(Vector3(-10.45, 1.6 + float(i % 2) * 0.5, -19.8 - i * 1.0), Vector3(0.15, 0.4, 0.15), _m.glass)
	# Stools along the bar's front, leaving a gap where the guest waits for his tea (z -23.4).
	var stools := []
	for z: float in [-19.6, -20.8, -22.0, -24.8, -26.0, -27.2]:
		stools.append([Vector3(-8.55, 0, z), 0.0])
	props("bar_stool", stools, false)
	# Sofas round low tables: [where, which way it faces]. The greybox's seat and back stay as the collision.
	var groups := [[Vector3(-4, 0, -21), 0.0], [Vector3(3.5, 0, -22), 0.0], [Vector3(-4.5, 0, -27.5), 0.0]]
	var sofas := []
	var tables := []
	var have_sofa := ResourceLoader.exists(PROP_PATH % "lounge_sofa")
	var have_table := ResourceLoader.exists(PROP_PATH % "cocktail_table")
	for g: Array in groups:
		var s: Vector3 = g[0]
		if have_sofa:
			_col(s + Vector3(0, 0.25, 0), Vector3(2.6, 0.5, 1.0), 1)
			sofas.append([s + Vector3(0, 0, -0.1), 0.0, Vector3(2.6, 0.95, 1.0)])   # faces +Z (the table, the door)
		else:
			solid(s + Vector3(0, 0.25, 0), Vector3(2.6, 0.5, 1.0), _m.velvet)
			deco(s + Vector3(0, 0.7, -0.4), Vector3(2.6, 0.5, 0.2), _m.velvet)
		if have_table:
			_col(s + Vector3(0, 0.25, 1.5), Vector3(1.0, 0.5, 1.0), 1)
			tables.append([s + Vector3(0, 0, 1.5), 0.6, Vector3(1.0, 0.6, 1.0)])
		else:
			solid(s + Vector3(0, 0.25, 1.5), Vector3(1.2, 0.5, 0.8), _m.wood)
	props("lounge_sofa", sofas, false)
	props("cocktail_table", tables, false)
	# The host's podium just inside the door, east of it: the guest book (Bastion's, when he's in).
	props("door_podium", [[Vector3(2.4, 0, -17.4), PI]])
	# Palms in the corners by the windows.
	props("potted_palm", [[Vector3(9.6, 0, -17.4), 0.5], [Vector3(-9.6, 0, -29.2), 1.2], [Vector3(4.6, 0, -29.3), 2.0]])
	# Chandeliers over the sofas, each with its light; the room's warm fill as before if they're not built.
	var lamps := [Vector3(-4, CEILING, -22), Vector3(3.5, CEILING, -23), Vector3(-4.5, CEILING, -28.2)]
	var hung := []
	for p: Vector3 in lamps:
		hung.append([p - Vector3(0, 1.3, 0), 0.0])
	if props("chandelier", hung, false, 0.01, 1.4):
		for p: Vector3 in lamps:
			_light(p - Vector3(0, 1.0, 0), Color("ff9070"), 2.2, 9.0)
	else:
		for p: Vector3 in [Vector3(-5, 3.8, -20), Vector3(4, 3.8, -20), Vector3(0, 3.8, -27)]:
			_light(p, Color("ff9070"), 2.2, 9.0)


# --- the vaults (WO-014b, DESIGN.md "The Velvet Rope's house") -------------------------------------------------------

## Down from the dungeon's north door: a stair annex (x -2..2, z -38..-48) to the vaults under the street behind the
## club. A hall (x -4..4) with three rooms each side (8 x 7 m), the fireplace at its end, and the Backroom behind,
## through a swung-open shelf in Rivet's workshop. Floor VAULT (5 m under the street), ceiling VAULT_TOP.
func _vaults() -> void:
	var vault := Look.painted(Look.Pattern.BRICK, Color("3a2a30"), Color("120a0e"), {"wet": 0.05})
	var floor_mat := Look.painted(Look.Pattern.FLAGSTONES, Color("2e2628"), Color("100c0e"), {"wet": 0.15})
	# The stair annex: walls, roof (a small outbuilding behind the club), the threshold, the ramp, its closed top end.
	for side: float in [-1.0, 1.0]:
		solid(Vector3(side * 1.8, (VAULT + 3.0) / 2.0, -43.0), Vector3(0.4, 3.0 - VAULT, 10.0), _m.club)
	solid(Vector3(0, 3.2, -43.0), Vector3(4.0, 0.4, 10.4), _m.slate)
	solid(Vector3(0, (VAULT_TOP + 3.0) / 2.0, -48.0), Vector3(3.96, 3.0 - VAULT_TOP, 0.4), _m.club)
	solid(Vector3(0, DUNGEON - 0.5, -37.9), Vector3(3.2, 1.0, 0.6), _m.stone)
	var run := 8.4
	var drop := DUNGEON - VAULT
	var ang := atan2(drop, run)
	_slab(Vector3(0, (DUNGEON + VAULT) / 2.0 - 0.2 / cos(ang) + 0.04, -38.2 - run / 2.0),
		Vector3(3.2, 0.4, sqrt(run * run + drop * drop)), Basis(Vector3.RIGHT, -ang), _m.stone)
	_light(Vector3(0, 1.2, -42.0), Color("ff4060"), 1.6, 6.0)
	# The vaults' shell: floor, ceiling, outer walls (the south one open where the annex comes in).
	solid(Vector3(0, VAULT - 0.5, -63.1), Vector3(24.8, 1.0, 33.4), floor_mat)        # z -46.4..-79.8
	solid(Vector3(0, VAULT_TOP + 0.2, -64.0), Vector3(24.8, 0.4, 32.0), vault)        # z -48..-80
	var vh := VAULT_TOP - VAULT
	var vm := (VAULT + VAULT_TOP) / 2.0
	solid(Vector3(-12.2, vm, -63.1), Vector3(0.4, vh, 33.4), vault)
	# East, the outer wall's open where the Quiet Room runs on under the street (z -48.2..-54.85, to x 20).
	solid(Vector3(12.2, vm, -47.3), Vector3(0.4, vh, 1.8), vault)
	solid(Vector3(12.2, vm, -67.325), Vector3(0.4, vh, 24.95), vault)
	for side: float in [-1.0, 1.0]:
		solid(Vector3(side * 7.2, vm, -48.0), Vector3(10.4, vh, 0.4), vault)
	solid(Vector3(16.4, VAULT - 0.5, -51.475), Vector3(8.0, 1.0, 7.35), floor_mat)
	solid(Vector3(16.4, VAULT_TOP + 0.2, -51.475), Vector3(8.0, 0.4, 7.35), vault)
	solid(Vector3(16.4, vm, -48.0), Vector3(8.0, vh, 0.4), vault)
	solid(Vector3(16.4, vm, -55.0), Vector3(8.0, vh, 0.3), vault)
	solid(Vector3(20.2, vm, -51.475), Vector3(0.4, vh, 7.35), vault)
	solid(Vector3(0, (VAULT + VAULT_TOP) / 2.0, -79.8), Vector3(24.8, VAULT_TOP - VAULT, 0.4), vault)
	# The hall's walls (x ±4) with a doorway into each room, the rooms' dividers, and the wall across the end.
	for side: float in [-1.0, 1.0]:
		var z := -48.2
		for r: Dictionary in ROOMS:
			if signf(r.at.x) != side:
				continue
			var door_z: float = r.at.z
			solid(Vector3(side * 4.0, (VAULT + VAULT_TOP) / 2.0, (z + door_z + 1.2) / 2.0),
				Vector3(0.3, VAULT_TOP - VAULT, absf(z - (door_z + 1.2))), vault)
			z = door_z - 1.2
		solid(Vector3(side * 4.0, (VAULT + VAULT_TOP) / 2.0, (z - 69.6) / 2.0), Vector3(0.3, VAULT_TOP - VAULT, absf(z + 69.6)), vault)
		for dz: float in [-55.0, -62.0]:
			solid(Vector3(side * 8.075, (VAULT + VAULT_TOP) / 2.0, dz), Vector3(7.85, VAULT_TOP - VAULT, 0.3), vault)
	# The end wall (z -69.6), whole but for the shelf door in the workshop (x 9.2..10.6).
	solid(Vector3(-1.4, (VAULT + VAULT_TOP) / 2.0, -69.75), Vector3(21.2, VAULT_TOP - VAULT, 0.3), vault)
	solid(Vector3(11.3, (VAULT + VAULT_TOP) / 2.0, -69.75), Vector3(1.4, VAULT_TOP - VAULT, 0.3), vault)
	solid(Vector3(9.9, (VAULT + 2.3 + VAULT_TOP) / 2.0, -69.75), Vector3(1.4, VAULT_TOP - VAULT - 2.3, 0.3), vault)
	# The swung-open shelf: a bookcase turned on its hinge, into the Backroom.
	var shelf := Node3D.new()
	add_child(shelf)
	block(Vector3(10.6, VAULT + 1.15, -70.4), Vector3(1.4, 2.3, 0.35), _m.wood, shelf, false).rotation.y = deg_to_rad(70.0)
	# The hall: a runner down the middle, sconces, the fireplace and the Rope's knot over it.
	deco(Vector3(0, VAULT + 0.01, -58.8), Vector3(2.4, 0.02, 20.6), _m.carpet)
	deco(Vector3(0, VAULT + 0.7, -69.45), Vector3(3.0, 1.4, 0.3), _m.ink)
	deco(Vector3(0, VAULT + 0.5, -69.25), Vector3(2.2, 0.9, 0.1), _unlit(Color(2.2, 0.9, 0.4)))
	deco(Vector3(0, VAULT + 1.5, -69.4), Vector3(3.6, 0.2, 0.5), _m.wood)
	_sign("THE VELVET ROPE", Vector3(0, VAULT + 2.6, -69.55), 0.0, Color(2.2, 0.5, 0.8), 30)
	_light(Vector3(0, VAULT + 1.0, -68.4), Color("ff8040"), 2.4, 8.0)
	for z: float in [-51.5, -58.5, -65.5]:   # low enough not to burn a spot on the ceiling
		_light(Vector3(0, VAULT + 2.0, z), Color("ff5a70"), 1.1, 6.5)
	# The cross (WO-014b, core/cross_scene.gd): at the hall's end in front of the fireplace, facing the hall, where
	# the members can watch. The model isn't solid; a thin board behind where the sub stands is.
	if not props("club_cross", [[CrossScene.CROSS, 0.0]], false, 0.012):
		for s: float in [-1.0, 1.0]:
			_strut(CrossScene.CROSS + Vector3(s * 0.75, 0.1, -0.1), CrossScene.CROSS + Vector3(-s * 0.75, 2.3, -0.1),
				0.16, _m.velvet, false)
	_col(CrossScene.CROSS + Vector3(0, 1.2, -0.28), Vector3(1.6, 2.4, 0.2), 1)
	for r: Dictionary in ROOMS:
		_room(r)
	_backroom()
	# The changing screen, by the cross (owner, Deck review 5): her two-piece to be the sub, her suit to lead.
	var screen := wardrobe(SCREEN, -PI / 2.0, "ChangingScreen")
	screen.set_meta(&"club_screen", true)
	for c in screen.get_children():
		if c is Label3D:
			(c as Label3D).text = "CHANGING SCREEN"


## A room off the hall: its plaque over the door, its light, its furniture (a Meshy prop when there is one, boxes
## until then).
func _room(r: Dictionary) -> void:
	var at: Vector3 = r.at
	var side := signf(at.x)
	_sign(r.title, Vector3(side * 3.84, VAULT + 2.85, at.z), -side * PI / 2.0, Color("f2c56a"), 13, false)
	_light(Vector3(at.x, VAULT + 2.1, at.z), r.light, 1.4, 7.0)
	var back := Vector3(side * (float(r.get("far", 12.0)) - 1.0), VAULT, at.z)   # against its outer wall
	var face := -side * PI / 2.0                    # facing the hall
	match r.id:
		&"parlour":
			# Augusta's posture-and-protocol parlour (Deck review 3): her wingback armchair in the south-west corner, a
			# tea table beside it, a full-length mirror on its stand behind the posture spot, a bookcase and a standard
			# lamp north of it, a rug and the kneeling cushion. Each is a Meshy prop (`assets/props/parlour_*.glb`), the
			# boxes its fallback. All face the room. `wx(d)` is d metres in from the outer wall (its inner face is at
			# x = side * 12).
			var wx := func(d: float) -> float: return side * (12.0 - d)
			var y0 := VAULT
			var bz := -49.4
			var lz := -50.75
			var mz := -51.7
			var cz := -53.85
			var tz := -52.95
			var tx: float = wx.call(0.45)
			var on_floor := func(d: float, z: float) -> Vector3: return Vector3(wx.call(d), y0, z)
			var has_bookcase := props("parlour_bookcase", [[on_floor.call(0.27, bz), face]])
			var has_lamp := props("parlour_lamp", [[on_floor.call(0.32, lz), face]])
			var has_mirror := props("parlour_mirror", [[on_floor.call(0.36, mz), face]])
			var has_chair := props("parlour_armchair", [[on_floor.call(0.42, cz), face]])
			var has_table := props("parlour_tea_table", [[Vector3(tx, y0, tz), face]])
			var has_cushion := props("parlour_cushion", [[at + Vector3(0, 0.01, 0.6), face]], false)
			deco(at + Vector3(0, 0.005, 0), Vector3(3.2, 0.01, 2.6), Look.toon(Color("3a1620")))   # the rug
			if not has_bookcase:
				# Back, sides, top and plinth solid; shelves and books drawn (fronts inset, so no face meets a face of
				# another material in its plane).
				solid(Vector3(wx.call(0.02), y0 + 1.15, bz), Vector3(0.04, 2.3, 1.8), _m.wood)
				for s: float in [-1.0, 1.0]:
					solid(Vector3(wx.call(0.2), y0 + 1.15, bz + s * 0.875), Vector3(0.4, 2.3, 0.05), _m.wood)
				deco(Vector3(wx.call(0.22), y0 + 2.325, bz), Vector3(0.44, 0.05, 1.86), _m.wood)
				solid(Vector3(wx.call(0.21), y0 + 0.05, bz), Vector3(0.38, 0.1, 1.7), _m.wood)
				var book_mats: Array = [Look.toon(Color("5a1420")), Look.toon(Color("1e3a2c")), Look.toon(Color("1c2440")),
					Look.toon(Color("4a3020")), Look.toon(Color("8a6a30"))]
				var brng := RandomNumberGenerator.new()
				brng.seed = 31
				for shelf: float in [0.1, 0.55, 1.0, 1.45, 1.9]:
					if shelf > 0.1:
						deco(Vector3(wx.call(0.21), y0 + shelf - 0.015, bz), Vector3(0.34, 0.03, 1.7), _m.wood)
					var z := bz - 0.84
					while z < bz + 0.78:
						var w := brng.randf_range(0.035, 0.07)
						var h := brng.randf_range(0.22, 0.35)
						if brng.randf() > 0.12:   # a gap here and there
							deco(Vector3(wx.call(0.18), y0 + shelf + h / 2.0, z + w / 2.0), Vector3(0.26, h, w - 0.004),
								book_mats[brng.randi() % book_mats.size()])
						z += w
			if not has_lamp:
				deco(Vector3(wx.call(0.32), y0 + 0.025, lz), Vector3(0.26, 0.05, 0.26), _m.brass)
				deco(Vector3(wx.call(0.32), y0 + 0.825, lz), Vector3(0.04, 1.55, 0.04), _m.brass)
				deco(Vector3(wx.call(0.32), y0 + 1.54, lz), Vector3(0.12, 0.08, 0.12), _m.lit)
				deco(Vector3(wx.call(0.32), y0 + 1.69, lz), Vector3(0.36, 0.28, 0.36), _m.velvet)
			if not has_mirror:
				solid(Vector3(wx.call(0.35), y0 + 1.035, mz), Vector3(0.06, 1.83, 0.8), _m.brass)
				deco(Vector3(wx.call(0.39), y0 + 1.035, mz), Vector3(0.02, 1.67, 0.66), Look.toon(Color("28344a"), 0.95, 0.35))
				for s: float in [-1.0, 1.0]:
					deco(Vector3(wx.call(0.35), y0 + 0.03, mz + s * 0.32), Vector3(0.42, 0.06, 0.06), _m.brass)
					deco(Vector3(wx.call(0.35), y0 + 0.12, mz + s * 0.32), Vector3(0.03, 0.14, 0.03), _m.brass)
			if not has_chair:
				# Seat, back and arms solid; wings, brass trim and feet drawn.
				solid(Vector3(wx.call(0.57), y0 + 0.28, cz), Vector3(0.62, 0.36, 0.56), _m.velvet)
				solid(Vector3(wx.call(0.2), y0 + 0.7, cz), Vector3(0.2, 1.2, 0.8), _m.velvet)
				for s: float in [-1.0, 1.0]:
					solid(Vector3(wx.call(0.57), y0 + 0.38, cz + s * 0.34), Vector3(0.62, 0.56, 0.12), _m.velvet)
					deco(Vector3(wx.call(0.38), y0 + 1.0, cz + s * 0.35), Vector3(0.24, 0.5, 0.1), _m.velvet)
					deco(Vector3(wx.call(0.885), y0 + 0.38, cz + s * 0.34), Vector3(0.01, 0.5, 0.1), _m.brass)
					for d: float in [0.14, 0.84]:
						deco(Vector3(wx.call(d), y0 + 0.05, cz + s * 0.34), Vector3(0.06, 0.1, 0.06), _m.brass)
			if not has_table:
				# A brass tray, the pot, two cups.
				deco(Vector3(tx, y0 + 0.04, tz), Vector3(0.34, 0.08, 0.34), _m.wood)
				solid(Vector3(tx, y0 + 0.36, tz), Vector3(0.06, 0.56, 0.06), _m.wood)
				solid(Vector3(tx, y0 + 0.66, tz), Vector3(0.5, 0.04, 0.5), _m.wood)
				deco(Vector3(tx, y0 + 0.6875, tz), Vector3(0.34, 0.015, 0.24), _m.brass)
				deco(Vector3(tx, y0 + 0.75, tz - 0.04), Vector3(0.12, 0.11, 0.12), _m.brass)
				deco(Vector3(tx - side * 0.08, y0 + 0.77, tz - 0.04), Vector3(0.06, 0.025, 0.025), _m.brass)
				for dz: float in [0.06, 0.1]:
					deco(Vector3(tx + side * (dz - 0.08) * 1.4, y0 + 0.72, tz + 0.07), Vector3(0.05, 0.05, 0.05),
						Look.toon(Color("f4f1ea")))
			if not has_cushion:
				deco(at + Vector3(0, 0.025, 0.6), Vector3(0.76, 0.03, 0.76), _m.brass)   # on the rug, not in its plane
				deco(at + Vector3(0, 0.1, 0.6), Vector3(0.7, 0.12, 0.7), _m.velvet)
		&"rope":
			if not props("rope_frame", [[back + Vector3(-side * 1.6, 0, 0), face]]):
				for dz: float in [-1.0, 1.0]:
					solid(back + Vector3(-side * 1.6, 1.3, dz), Vector3(0.2, 2.6, 0.2), _m.wood)
				deco(back + Vector3(-side * 1.6, 2.6, 0), Vector3(0.2, 0.2, 2.2), _m.wood)
			for dz: float in [-2.4, 2.4]:
				deco(back + Vector3(side * 0.9, 1.6, dz), Vector3(0.1, 0.6, 0.6), _m.velvet)   # coils on the wall
		&"throne":
			if not props("club_throne", [[back + Vector3(-side * 0.2, 0, 0), face]]):
				solid(back + Vector3(0, 0.5, 0), Vector3(1.2, 1.0, 1.2), _m.velvet)
				deco(back + Vector3(side * 0.55, 1.4, 0), Vector3(0.2, 1.8, 1.26), _m.wood)
			deco(at + Vector3(-side * 0.6, 0.2, 0.0), Vector3(0.5, 0.4, 0.5), _m.wood)   # the boot-black stool
		&"quiet":
			# A chaise each (QUIET_SEATS), a rug down the middle, Lull's tea table by the door, soft light.
			var seats := []
			for s: Array in QUIET_SEATS:
				var f: Vector3 = s[1]
				seats.append([s[0], atan2(f.x, f.z)])
			if not props("chaise", seats):
				for s: Array in QUIET_SEATS:
					var f: Vector3 = s[1]
					var c: Vector3 = s[0]
					solid(c + Vector3(0, 0.3, 0), Vector3(absf(f.x) * 0.9 + absf(f.z) * 2.0, 0.6, absf(f.z) * 0.9 + absf(f.x) * 2.0), _m.velvet)
			deco(Vector3(13.0, VAULT + 0.01, -51.5), Vector3(10.0, 0.02, 2.6), Look.toon(Color("3a2a50")))   # the rug
			solid(Vector3(6.6, VAULT + 0.25, -54.0), Vector3(1.0, 0.5, 0.8), _m.wood)           # the tea table
			for p: Vector3 in [Vector3(14.6, VAULT + 0.15, -54.3), Vector3(18.5, VAULT + 0.15, -54.4), Vector3(16.0, VAULT + 0.15, -48.7)]:
				deco(p, Vector3(0.7, 0.3, 0.7), _m.velvet)                                       # floor cushions
			_light(Vector3(17.0, VAULT + 2.1, -51.5), r.light, 1.2, 7.0)
		&"dash":
			if not props("punch_bag", [[at + Vector3(side * 2.0, 0, 1.6), face]]):
				solid(at + Vector3(side * 2.0, 1.2, 1.6), Vector3(0.6, 1.4, 0.6), _m.leather)
			solid(back + Vector3(side * 0.2, 0.9, -2.6), Vector3(0.8, 1.8, 0.7), Look.toon(Color("d8d0c0")))   # her fridge
		&"workshop":
			if not props("workbench", [[back + Vector3(-side * 0.4, 0, 0), face]]):
				solid(back + Vector3(-side * 0.2, 0.5, 0), Vector3(1.0, 1.0, 2.6), _m.wood)
			deco(back + Vector3(side * 0.9, 1.8, 0), Vector3(0.1, 1.2, 2.6), _m.wood)   # the pegboard


## Behind the shelf: the covert side. The map table, the pinboard of Swyne's chain (a card per world, red string),
## Vesper's desk.
func _backroom() -> void:
	var c := BACKROOM
	if not props("map_table", [[c, 0.0]]):
		solid(c + Vector3(0, 0.45, 0), Vector3(3.0, 0.9, 2.0), _m.wood)
		deco(c + Vector3(0, 0.91, 0), Vector3(2.6, 0.02, 1.6), Look.toon(Color("d8ccb0")))
	# The pinboard on the north wall: one card per link of the chain, joined by red string.
	deco(Vector3(c.x, VAULT + 1.9, -79.55), Vector3(7.0, 2.2, 0.08), Look.toon(Color("6a4a30")))
	for i in Game.WORLDS.size():
		var x := c.x - 3.0 + i * 1.0
		var y := VAULT + 1.5 + (0.5 if i % 2 == 0 else 0.0)
		deco(Vector3(x, y, -79.48), Vector3(0.6, 0.45, 0.02), Look.toon(Color("e8e0d0")))
		if i > 0:
			_strut(Vector3(x - 1.0, VAULT + 1.5 + (0.5 if (i - 1) % 2 == 0 else 0.0), -79.46), Vector3(x, y, -79.46),
				0.02, _m.velvet, false)
	_sign("SWYNE", Vector3(c.x, VAULT + 3.2, -79.5), 0.0, Color("e8e0d0"), 30, false)
	# Each card names its world, and says where she's at with it: a green OPEN, a red DONE across it, or its roses.
	for i in Game.WORLDS.size():
		var w: StringName = Game.WORLDS[i]
		var at := Vector3(c.x - 3.0 + i * 1.0, VAULT + 1.5 + (0.5 if i % 2 == 0 else 0.0), -79.46)
		var tag := Label3D.new()
		tag.text = Game.NAMES.get(w, String(w)).trim_prefix("The ")
		tag.font_size = 22
		tag.pixel_size = 0.0035
		tag.modulate = Color("2a1a14")
		tag.outline_size = 0
		tag.position = at + Vector3(0, 0.07, 0.01)
		tag.width = 150.0
		tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(tag)
		if w == &"hub":
			continue
		var state := Label3D.new()
		var done := Game.has_flag("done/%s" % w)
		var open := Game.world_open(w)
		state.text = "DONE" if done else ("OPEN" if open else "%d roses" % Game.RANK_KEYS[Game.RANK_WORLDS.find(w)])
		state.font_size = 26 if done or open else 18
		state.pixel_size = 0.0035
		state.modulate = Color("b01830") if done else (Color("1f7a3a") if open else Color("6a5a50"))
		state.outline_size = 0
		state.rotation.z = -0.25 if done else 0.0
		state.position = at + Vector3(0, -0.11, 0.012)
		add_child(state)
	# The board itself: Y at it briefs every world and takes her to an open one (levels/hub/backroom_board.gd).
	var board: Talker = (load("res://levels/hub/backroom_board.gd") as GDScript).new()
	board.name = "Board"
	board.display_name = "The board"
	board.reach = 2.4
	board.position = Vector3(c.x, VAULT, -78.4)
	add_child(board)
	# Vesper's desk, west; chairs round the table.
	solid(Vector3(-8.5, VAULT + 0.4, -75.0), Vector3(1.0, 0.8, 2.4), _m.wood)
	for p: Vector3 in [c + Vector3(-1.9, 0, 0), c + Vector3(1.9, 0, 0), c + Vector3(0, 0, 1.4)]:
		deco(p + Vector3(0, 0.25, 0), Vector3(0.5, 0.5, 0.5), _m.leather)
	_light(c + Vector3(0, 2.4, 0), Color("ffd8a0"), 2.2, 9.0)
	_light(Vector3(-8.5, VAULT + 2.0, -75.0), Color("a0c0ff"), 1.0, 5.0)


func _window(at: Vector3, lit: bool) -> void:
	deco(at + Vector3(0, 0, 0.03), Vector3(1.3, 1.9, 0.06), _m.ink)
	deco(at + Vector3(0, 0, 0.06), Vector3(1.1, 1.7, 0.06), _m.lit if lit else _m.glass)
	deco(at + Vector3(0, -0.95, 0.12), Vector3(1.4, 0.1, 0.2), _m.sill)


# --- Seafront Road ---------------------------------------------------------------------------------------------------

func _seafront() -> void:
	# Pavements along both sides.
	solid(Vector3(49, 0.06, -1.0), Vector3(58, 0.12, 2.0), _m.flags)
	solid(Vector3(49, 0.06, 11.0), Vector3(58, 0.12, 2.0), _m.flags)
	# The north row: four terraces with flat roofs (the rooftop route), alleys between; the south row, taller; and the
	# blocks behind both, taller again, closing it in.
	var north := [[20.0, 30.0, 8.5], [32.0, 44.0, 7.0], [46.0, 58.0, 7.5], [60.0, 72.0, 9.0]]
	var walls := [_m.brick, _m.plaster, _m.plaster_blue, _m.brick]
	for i in north.size():
		var r: Array = north[i]
		_house(Vector2(r[0], -10.0), Vector2(r[1], -2.0), r[2], walls[i], true, ROAD)
		_shop(Vector3((r[0] + r[1]) / 2.0, 0, -2.0), 0.0, ["CHANDLER", "OYSTERS", "ROOMS", "SHIPWRIGHT"][i])
	for r: Array in [[20.0, 34.0, 10.0], [36.0, 50.0, 9.0], [52.0, 64.0, 11.0], [66.0, 74.0, 8.0]]:
		_house(Vector2(r[0], 12.0), Vector2(r[1], 20.0), r[2], _m.brick_dark, false, ROAD)
	# The blocks behind face the rows' backs; seen over the rooftops, the near side is what matters.
	_house(Vector2(28.0, -24.0), Vector2(80.0, -10.0), 13.0, _m.brick_dark, false, ROAD)
	_house(Vector2(20.0, 20.0), Vector2(80.0, 30.0), 13.0, _m.brick_dark, false, ROAD)
	for a: float in [30.0, 44.0, 58.0]:
		solid(Vector3(a + 1.0, 6.0, -10.2), Vector3(2.0, 12.0, 0.4), _m.brick_dark)   # the alley's back
	_house(Vector2(74.0, 12.0), Vector2(80.0, 20.0), 8.0, _m.brick_dark, false, ROAD)
	# Lamps down the road.
	for x: float in [30.0, 46.0, 62.0]:
		_lamp(Vector3(x, 0, 11.3))
	# The marked wall in the middle alley (x 44..46): up to the rooftops.
	solid(Vector3(45.9, 3.75, -6.0), Vector3(0.2, 7.5, 6.0), _m.climb, 1 | 2)
	# Over the roofs: 46..58 (7.5 m), up to 60..72 (9 m), then a wire across to the harbour lamp's platform, where
	# the hub's rooftop Key waits.
	var wire := Beam.new()
	wire.length = 4.4
	wire.width = 0.05
	wire.wire = true
	wire.material = _m.ink
	wire.position = Vector3(74.0, 9.0, -6.0)
	add_child(wire)
	solid(Vector3(77.0, 4.5, -6.0), Vector3(2.0, 9.0, 2.0), _m.brick)
	deco(Vector3(77.0, 9.6, -6.0), Vector3(0.5, 0.8, 0.5), _m.lamp)
	_light(Vector3(77.0, 10.2, -6.0), Look.SODIUM, 2.0, 10.0)
	key(&"hub_07", Vector3(77.0, 9.0, -6.6))
	# The sea wall at the road's end, and the Pier's gate in it.
	solid(Vector3(80.4, 0.55, -4.75), Vector3(0.3, 1.1, 10.5), _m.rail)
	solid(Vector3(80.4, 0.55, 14.75), Vector3(0.3, 1.1, 10.5), _m.rail)
	for z: float in [1.0, 9.0]:
		solid(Vector3(79.0, 3.0, z), Vector3(1.0, 6.0, 1.0), Look.toon(Color("e8e0d0"), 0.2))
	deco(Vector3(79.0, 6.3, 5.0), Vector3(1.2, 0.8, 9.2), _m.velvet)
	_sign("THE PIER", Vector3(78.35, 6.3, 5.0), -PI / 2.0, Color(2.4, 0.6, 1.0), 64)
	_gate(&"pier", Vector3(79.0, STREET, 5.0), PI / 2.0, 7.0, 5.0)
	var into := WorldGate.new()
	into.name = "Gate_pier"
	into.world = &"pier"
	into.arrival = "hub"
	into.size = Vector3(2.0, 3.0, 7.0)
	into.position = Vector3(81.5, STREET, 5.0)
	add_child(into)
	# Beyond the wall, the sea, and the pier's lights far out on it.
	var sea := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	sea.mesh = plane
	sea.position = Vector3(180, -4.0, 5.0)
	sea.material_override = Look.toon(Color("101c34"), 0.9)
	add_child(sea)
	# 2 cm proud of the street (flush, it fought).
	solid(Vector3(86, -0.48, 5.0), Vector3(10, 1, 9.0), Look.painted(Look.Pattern.PLANKS, Color("5e4c40"), Color("1a120e"),
		{"wet": 0.8}))
	for i in 12:
		deco(Vector3(92 + i * 6.0, 0.6 + sin(i) * 0.3, 5.0 + (i % 3 - 1) * 2.5), Vector3(0.3, 0.3, 0.3), _m.lamp)


## A shop's front on a terrace whose face is at z `at.z`, facing -Z... or +Z by `yaw`: a lit window, a door, a sign.
func _shop(at: Vector3, yaw: float, name_text: String) -> void:
	var n := 1.0 if yaw == 0.0 else -1.0
	if not ResourceLoader.exists(PROP_PATH % "hub_facade_shop"):   # (the Meshy shopfronts have their own)
		deco(at + Vector3(-2.0, 1.4, 0.04 * n), Vector3(4.0, 1.8, 0.06), _m.lit)
		deco(at + Vector3(2.5, 1.2, 0.04 * n), Vector3(1.2, 2.4, 0.06), _m.wood)
	_sign(name_text, at + Vector3(0, 3.6, 0.3 * n), yaw, Color(2.0, 1.6, 0.9), 36)


# --- the later worlds' streets ---------------------------------------------------------------------------------------

## A short street from `mouth` (on the square's edge) out along `dir`: houses down both sides, and at its end the
## world's rank door with its name over it. The street's built out when its world is (WO-015 on).
func _stub(world: StringName, title: String, mouth: Vector3, dir: Vector3) -> void:
	var side := Vector3(dir.z, 0, -dir.x)
	var length := 14.0
	var half := 3.0
	# Its sides: 2 m house fronts (anything deeper would push into the club beside Council Avenue).
	for s: float in [-1.0, 1.0]:
		var c := mouth + dir * (length / 2.0) + side * s * (half + 1.0)
		var size := Vector3(absf(dir.x) * length + absf(side.x) * 2.0, 10.0, absf(dir.z) * length + absf(side.z) * 2.0)
		var a := Vector2(c.x - size.x / 2.0, c.z - size.z / 2.0)
		var b := Vector2(c.x + size.x / 2.0, c.z + size.z / 2.0)
		_house(a, b, 10.0 + s, _m.brick if s < 0.0 else _m.plaster, false, mouth + dir * (length / 2.0))
	var end := mouth + dir * (length + 2.0)
	var ea := Vector2(end.x - absf(side.x) * (half + 1.0) - absf(dir.x) * 2.0, end.z - absf(side.z) * (half + 1.0) - absf(dir.z) * 2.0)
	var eb := Vector2(end.x + absf(side.x) * (half + 1.0) + absf(dir.x) * 2.0, end.z + absf(side.z) * (half + 1.0) + absf(dir.z) * 2.0)
	_house(ea, eb, 12.0, _m.brick_dark, false, mouth)
	var door_at := mouth + dir * (length - 1.0)
	var yaw := atan2(dir.x, dir.z)
	_gate(world, door_at, yaw, half * 2.0, 4.5)
	_sign(title, door_at + Vector3(0, 4.6, 0) - dir * 0.2, yaw + PI, Color(2.0, 1.6, 0.9), 40)
	_sign(Game.NAMES[world], door_at + Vector3(0, 4.0, 0) - dir * 0.2, yaw + PI, Color("e8d7c0"), 26, false)
	var into := WorldGate.new()
	into.name = "Gate_%s" % world
	into.world = world
	into.position = door_at + dir * 1.2
	into.rotation.y = yaw
	add_child(into)


## A world's rank door across a street, its front toward the square (`yaw` turns its -Z front that way).
func _gate(world: StringName, at: Vector3, yaw: float, width: float, height: float) -> RankDoor:
	var d := RankDoor.new()
	d.keys_needed = Game.RANK_KEYS[Game.RANK_WORLDS.find(world)]
	d.width = width
	d.height = height
	d.name = "RankDoor_%s" % world
	d.position = at
	d.rotation.y = yaw
	add_child(d)
	return d


# --- buildings -------------------------------------------------------------------------------------------------------

## A terrace block from `a` to `b` (x, z corners), `h` tall: walls, bands, a cornice; a flat roof you can walk if
## `flat`, else a pitched slate one (drawn) over a flat top. A few windows lit on its faces.
##
## Terraces overlap and abut (the square's edges, the side streets, the blocks behind Seafront Road), and two walls
## in one plane facing the same way fight (owner's Deck clips: whole faces shimmered). So each house grows by its own
## few millimetres (6 mm a side and 1 cm up per step), a step no house it touches has: no two share a plane.
## tools/zfight_check.gd checks it.
## The Meshy buildings for the street blocks: [wall material -> prop]. A flat-roofed terrace (shops below) is the shop.
## Each block becomes a row of them, about FACADE_BAY wide, fronts to its street.
const FACADE_BAY := 7.0
## Seafront Road's middle: its rows front it.
const ROAD := Vector3(49, 0, 5)
var _facades := {}


func _facade_prop(wall: Material, flat: bool) -> String:
	if flat:
		return "hub_facade_shop"
	return "hub_facade_plaster" if wall == _m.plaster or wall == _m.plaster_blue else "hub_facade_brick"


## `toward`: a point on the street the block fronts (its front is the long side facing it).
func _house(a: Vector2, b: Vector2, h: float, wall: Material, flat := false, toward := Vector3(0, 0, 2)) -> void:
	var prop := _facade_prop(wall, flat)
	if ResourceLoader.exists(PROP_PATH % prop):
		_house_model(a, b, h, prop, toward)
		return
	_house_box(a, b, h, wall, flat)


func _house_model(a: Vector2, b: Vector2, h: float, prop: String, toward: Vector3) -> void:
	var size := Vector3(b.x - a.x, h, b.y - a.y)
	var c := Vector3((a.x + b.x) / 2.0, 0.0, (a.y + b.y) / 2.0)
	_col(c + Vector3(0, h / 2.0, 0), size, 1)
	_houses.append(AABB(c - Vector3(size.x, 0, size.z) / 2.0, size))
	_steps.append(0)
	# The front: the side the street point lies beyond (judged against the block's own half-sizes).
	var rel := toward - c
	var front := Vector3(signf(rel.x), 0, 0) if absf(rel.x) / size.x > absf(rel.z) / size.z else Vector3(0, 0, signf(rel.z))
	if front == Vector3.ZERO:
		front = Vector3(0, 0, 1)
	var along := Vector3(absf(front.z), 0, absf(front.x))
	var length := size.x if along.x > 0.5 else size.z
	var depth := size.z if along.x > 0.5 else size.x
	var n := maxi(1, roundi(length / FACADE_BAY))
	var bay := length / n
	var yaw := atan2(front.x, front.z)
	var list: Array = _facades.get_or_add(prop, [])
	for i in n:
		list.append([c + along * (-length / 2.0 + bay * (i + 0.5)), yaw, Vector3(bay, h, depth)])


func _place_facades() -> void:
	for p: String in _facades:
		props(p, _facades[p], false)
	_facades.clear()


func _house_box(a: Vector2, b: Vector2, h: float, wall: Material, flat := false) -> void:
	# The smallest step no house it touches has taken.
	var footprint := AABB(Vector3(a.x, 0.0, a.y), Vector3(b.x - a.x, h, b.y - a.y)).grow(0.1)
	var taken := {}
	for k in _houses.size():
		if _houses[k].intersects(footprint):
			taken[_steps[k]] = true
	var n := 0
	while taken.has(n):
		n += 1
	h += 0.01 * n
	var size := Vector3(b.x - a.x + 0.012 * n, h, b.y - a.y + 0.012 * n)
	var c := Vector3((a.x + b.x) / 2.0, h / 2.0, (a.y + b.y) / 2.0)
	_houses.append(AABB(c - size / 2.0, size))
	_steps.append(n)
	solid(c, size, wall)
	var k := 1
	while k * 3.4 < h - 1.0:
		deco(Vector3(c.x, k * 3.4, c.z), Vector3(size.x + 0.24, 0.18, size.z + 0.24), _m.sill)
		k += 1
	deco(Vector3(c.x, h + 0.15, c.z), Vector3(size.x + 0.5, 0.3, size.z + 0.5), _m.sill)
	if not flat:
		var roof := MeshInstance3D.new()
		var prism := PrismMesh.new()
		var along_x := size.x >= size.z
		prism.size = Vector3(size.z if along_x else size.x, 2.4, size.x if along_x else size.z)
		roof.mesh = prism
		roof.material_override = _m.slate
		roof.position = Vector3(c.x, h + 0.3 + 1.2, c.z)
		roof.rotation.y = PI / 2.0 if along_x else 0.0
		add_child(roof)
	# A lit window here and there on the long faces (both sides; the ones you can't see cost nothing much).
	var along := size.x >= size.z
	var length := size.x if along else size.z
	var count := int(length / 3.0)
	for f: float in [-1.0, 1.0]:
		for i in count:
			for row in int((h - 1.5) / 3.4):
				if _rng.randf() > 0.3:
					continue
				# A flat-roofed terrace has shops on its ground floor: no upstairs window over a shop's door or window.
				if flat and row == 0:
					continue
				var t := (i + 0.5) / count - 0.5
				var p := Vector3(c.x + (t * length if along else f * (size.x / 2.0 + 0.04)), 2.0 + row * 3.4,
					c.z + (f * (size.z / 2.0 + 0.04) if along else t * length))
				_windows.append([p, Vector3(1.0 if along else 0.06, 1.5, 0.06 if along else 1.0), _houses.size() - 1])


## The lit windows, once every house is up: none on a face buried in a neighbour (its edge fought that wall).
func _place_windows() -> void:
	_place_facades()
	for w: Array in _windows:
		var p: Vector3 = w[0]
		var hidden := false
		for k in _houses.size():
			if k != w[2] and _houses[k].grow(0.1).has_point(p):
				hidden = true
				break
		if not hidden:
			deco(p, w[1], _m.lit)
	_windows.clear()


func _lamp(at: Vector3) -> void:
	solid(at + Vector3(0, 1.7, 0), Vector3(0.18, 3.4, 0.18), _m.ink)
	deco(at + Vector3(0, 3.5, 0), Vector3(0.4, 0.4, 0.4), _m.lamp)
	_light(at + Vector3(0, 3.4, 0), Look.SODIUM, 3.0, 11.0)


# --- people and places -----------------------------------------------------------------------------------------------

func _people() -> void:
	var on_door := Talker.new()
	on_door.name = "Bastion"
	on_door.file = "res://data/dialogue/hub/club.dialogue"
	on_door.label = "bastion"
	on_door.who = "bastion"
	on_door.outfit = "garb"
	on_door.display_name = "Bastion"
	on_door.position = Vector3(3.6, STREET, -13.8)
	on_door.rotation.y = PI
	add_child(on_door)
	# The sisters, each in her room in the vaults (WO-014b; Vesper's place is the prologue's until it's done: see
	# prologue.gd). Dash is at the Pier until it's done.
	for r: Dictionary in ROOMS:
		var who: String = String(r.sister).to_lower()
		if who == "dash" and not Game.has_flag("done/pier"):
			continue
		var t := Talker.new()
		t.name = r.sister
		t.file = "res://data/dialogue/hub/club.dialogue"
		t.label = who
		t.who = who
		# Always the Domme suit in the club (owner, Deck review 3); her swimwear only on the cross as the sub
		# (CrossScene._dress).
		t.outfit = "suit" if CastModel.exists(who, "suit") else "garb"
		t.display_name = r.sister
		t.position = sister_spot(r)
		var to: Vector3 = r.at - t.position
		t.rotation.y = atan2(-to.x, -to.z)
		add_child(t)
		if who == "rivet":
			t.talked.connect(_hand_in)


## Where a room's sister stands: her `spot`, or by her furniture, toward the outer wall, a little up the room.
static func sister_spot(r: Dictionary) -> Vector3:
	if r.has("spot"):
		return r.spot
	var at: Vector3 = r.at
	return at + Vector3(signf(at.x) * 1.8, 0.0, -1.4)


## Where someone sits on the Quiet Room's seat `i` (over its seat, facing out), and a point in front to face.
static func seat_spot(i: int) -> Vector3:
	var s: Array = QUIET_SEATS[i]
	return (s[0] as Vector3) + (s[1] as Vector3) * (0.443 - SEAT_IN)


static func seat_facing(i: int) -> Vector3:
	var s: Array = QUIET_SEATS[i]
	return seat_spot(i) + (s[1] as Vector3) * 2.0


## The room (a ROOMS entry) a point in the vaults is in, or {} in the hall or elsewhere.
static func room_at(p: Vector3) -> Dictionary:
	if p.y > VAULT + 1.0 or absf(p.x) < 4.15:
		return {}
	for r: Dictionary in ROOMS:
		if signf(float(r.at.x)) == signf(p.x) and absf(p.z - float(r.at.z)) < 3.4:
			return r
	return {}


## A walk from one place in the vaults to another that keeps to the floor: out through a room's doorway into the hall,
## along it, and in through the other's (owner, Deck review 3: a sister walking back from the Quiet Room went through
## its wall). The points carry the floor's height; `from` itself isn't in it.
static func route(from: Vector3, to: Vector3) -> Array:
	var a := room_at(from)
	var b := room_at(to)
	var pts: Array = []
	if not a.is_empty() and a == b:
		return [to]
	for r: Dictionary in [a, b]:
		if r.is_empty():
			continue
		var side := signf(float(r.at.x))
		var inside := Vector3(side * 4.9, VAULT, float(r.at.z))
		var hall := Vector3(side * 2.6, VAULT, float(r.at.z))
		pts.append_array([inside, hall] if r == a else [hall, inside])
	pts.append(to)
	return pts


## Seized contraband, handed to Rivet (owner, 2026-11-12: "Rivet turns it into gear"). Talking to her hands in all of
## it seized since last time. She guts the toys: every LURE_EVERY seized is a lure (Game flag "gear/lures"), and every
## UPGRADE_EVERY an upgrade, alternating one more health pip ("upgrade/health") and a steadier Composure
## ("upgrade/composure": slips cost a quarter less each). Counted on the running total ("rivet/handed"), so nothing's
## lost between visits.
func _hand_in(_which: String) -> void:
	var seized := Game.count(&"contraband")
	var before := int(Game.get_flag("rivet/handed", 0))
	if seized <= before:
		if seized == 0:
			Hud.caption("Rivet", "Bring me Swyne's toys when you seize them. Gutted, they're good for something.", 4.0)
		return
	Game.set_flag("rivet/handed", seized)
	Hud.caption("Rivet", "%d of Swyne's toys. I'll have the receivers out of them by morning." % (seized - before), 4.0)
	var lures := seized / LURE_EVERY - before / LURE_EVERY
	var lines: Array[String] = []
	if lures > 0:
		var total := int(Game.get_flag("gear/lures", 0)) + lures
		Game.set_flag("gear/lures", total)
		if nim:
			nim.gear.lures = total
		lines.append("Lures: +%d, %d in all (thrown toys that buzz; goons go to look)." % [lures, total])
	for i in seized / UPGRADE_EVERY - before / UPGRADE_EVERY:
		var health := int(Game.get_flag("upgrade/health", 0))
		var steady := int(Game.get_flag("upgrade/composure", 0))
		if health <= steady:
			Game.set_flag("upgrade/health", health + 1)
			if nim:
				nim.combat.add_upgrade()
			lines.append("Upgrade: one more health pip.")
		else:
			Game.set_flag("upgrade/composure", steady + 1)
			lines.append("Upgrade: a steadier Composure. Every slip in the suit costs a quarter less.")
	var next_lure := (seized / LURE_EVERY + 1) * LURE_EVERY
	var next_up := (seized / UPGRADE_EVERY + 1) * UPGRADE_EVERY
	lines.append("Seized in all: %d. Next lure at %d, next upgrade at %d." % [seized, next_lure, next_up])
	Hud.note("\n".join(lines), 7.0)


func _places() -> void:
	zone("Rope Square", Vector3(0, -0.2, 2), Vector3(40, 10, 36))
	zone("The Velvet Rope", Vector3(0, -0.2, -23.3), Vector3(21, 4.6, 13.6))
	zone("The Dungeon", Vector3(0, DUNGEON - 0.2, -34.0), Vector3(21, 5.6, 7.2))
	zone("The Vaults", Vector3(0, VAULT - 0.2, -58.8), Vector3(24, 3.4, 21.6))
	zone("The Backroom", Vector3(0, VAULT - 0.2, -74.7), Vector3(24, 3.4, 9.6))
	zone("Seafront Road", Vector3(50, -0.2, 5), Vector3(60, 14, 14))
	# None inside the club (owner, Deck review 3: the flags in the dungeon and the vaults "look odd and misplaced"):
	# nothing in there can down her, and the door's is a short walk up.
	checkpoint_at(CLUB_DOOR, 0.0)
	checkpoint_at(Vector3(66, STREET, 5.0), -PI / 2.0)
	# Beside the ways everyone walks (they're found within 3 m): just out of the club's door, and the road's sea end.
	travel_point(&"club", "The Velvet Rope", Vector3(-2.4, STREET, -12.4))
	travel_point(&"seafront", "Seafront Road", Vector3(68.0, STREET, 7.2))
