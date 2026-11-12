extends Level
## WO-003's test course: one lane per move, side by side, each running away from the camera (-Z) from a start at z 2.
## The probes (tools/walk_probe.gd, tools/climb_probe.gd) take every gap and climb here with real inputs, and the
## owner tunes the feel on the Deck. A pit floor at y -6 catches falls. Marked climbable surfaces are green lattice.
##
##   A  x 0    gaps: 2.5, 3.5 and 4.2 m
##   B  x 14   heights: blocks 1.0, 1.6 and 2.0 m
##   C  x 28   ledges: a 3 m wall, then 4 m more (jump, grab, pull up; shimmy)
##   D  x 42   a marked wall, 7 m: climb it, cross it, leap off it
##   E  x 56   a beam (8 m, 20 cm) and a wire (6 m, 5 cm), 3 m up
##   F  x 70   a crawlway (1.1 m clear), then a 6.5 m gap only a jump and a pounce cross
##   G  x 90   a walled yard: a checkpoint at its open end, three goons on patrol (WO-004)
##   H  x 112  a lone sentry facing away, and someone in a trance walking a loop (WO-004)
##   I  x 136  a guarded yard (WO-005): a 9 m wall shades a strip down its west side; lamps light the middle; a patrol, a
##             guard, a lookout on a post at the far end, a goon to drop on, and a dark shed by the gate to hide in
##   J  x 164  the club (WO-006): a street with a doorman goon and a wardrobe round a corner; inside, a bar with a
##             bartender, a key and a locked back door, a crowd lining the room, a goon on his rounds, and security who
##             know her face watching from the far corner
##   K  x 192  lessons and gear (WO-007): Vesper (Y teaches), a switch and a bell for the crop, a ceiling over a gap, a
##             marked tower to come down head first, a crate on a shelf to pull, a wardrobe and a councillor (the
##             signet), a rope anchor over a 12 m gap, then a goon to rope from range, two to Scold, a sleeper for the
##             pendant, and a guard to lure

const LANES := {&"A": 0.0, &"B": 14.0, &"C": 28.0, &"D": 42.0, &"E": 56.0, &"F": 70.0, &"G": 90.0, &"H": 112.0, &"I": 136.0,
	&"J": 164.0, &"K": 192.0}
const NAMES := {&"A": "Gaps", &"B": "Heights", &"C": "Ledges", &"D": "Climb", &"E": "Balance", &"F": "Crawl & pounce",
	&"G": "Fight & bind", &"H": "Unaware & entranced", &"I": "Stealth yard", &"J": "The club",
	&"K": "Lessons & gear"}
const HALF := 3.0       # half a lane's width
const PIT := -6.0

var _plank: ShaderMaterial
var _wall: ShaderMaterial
var _climb: ShaderMaterial
var _beam_mat: ShaderMaterial
## The course starts fresh once per launch (its goons unbound, its sleeper under again); reloads within a launch keep
## what happened, which is what the persistence probe checks.
static var _fresh_done := false


func _ready() -> void:
	_plank = Look.painted(Look.Pattern.FLAGSTONES, Color("6a6070"), Color("2a2430"), {"wet": 0.0})
	_wall = Look.painted(Look.Pattern.PLASTER, Color("5e5868"), Color("201c26"), {"wet": 0.0})
	_climb = Look.painted(Look.Pattern.BRICK, Color("4f8a5a"), Color("173020"), {"wet": 0.0, "scale": 1.6})
	_beam_mat = Look.toon(Color("a07a4a"))
	if not _fresh_done:
		_fresh_done = true
		Game.clear_world(world_id)
	_environment()
	block(Vector3(95, PIT - 0.5, -30), Vector3(230, 1, 92), Look.painted(Look.Pattern.FLAGSTONES, Color("2e2a36"), Color("16121c"), {"wet": 0.3}))
	_lane_a()
	_lane_b()
	_lane_c()
	_lane_d()
	_lane_e()
	_lane_f()
	_lane_g()
	_lane_h()
	_lane_i()
	_lane_j()
	_lane_k()
	for id: StringName in LANES:
		_sign(LANES[id], "%s  %s" % [id, NAMES[id]])
	spawn_player(start(&"A"), 0.0)
	# The course has every lesson and every piece of gear: it's for testing moves.
	for flag: String in Lessons.ALL:
		nim.known[flag] = true
	nim.gear.lures = 5


## Where a lane's run starts (on its first surface).
func start(lane: StringName) -> Vector3:
	var top := 3.0 if lane == &"E" else 0.0
	return Vector3(LANES[lane], top + 0.05, 2.0)


## A platform from z0 to z1 (z0 > z1) whose top is at `top`, standing on the pit floor.
func plat(x: float, z0: float, z1: float, top: float, mat: Material = null, width := HALF * 2.0, layer := 1) -> StaticBody3D:
	var h := top - PIT
	var b: StaticBody3D = block(Vector3(x, PIT + h / 2.0, (z0 + z1) / 2.0), Vector3(width, h, z0 - z1), mat if mat else _plank)
	b.collision_layer = layer
	return b


func _lane_a() -> void:
	var x: float = LANES[&"A"]
	plat(x, 4.0, -10.0, 0.0)
	plat(x, -12.5, -16.5, 0.0)    # 2.5 m gap
	plat(x, -20.0, -24.0, 0.0)    # 3.5
	plat(x, -28.2, -34.0, 0.0)    # 4.2


func _lane_b() -> void:
	var x: float = LANES[&"B"]
	plat(x, 4.0, -32.0, 0.0)
	for step: Array in [[-6.0, 1.0], [-14.0, 1.6], [-22.0, 2.0]]:
		plat(x, step[0], step[0] - 3.0, step[1], _wall, HALF * 2.0 - 0.1)   # narrower than the floor: no coplanar sides


func _lane_c() -> void:
	var x: float = LANES[&"C"]
	plat(x, 4.0, -8.0, 0.0)
	plat(x, -8.0, -20.0, 3.0, _wall)    # a 3 m wall; its top is a terrace
	plat(x, -20.0, -28.0, 7.0, _wall)   # 4 m more


func _lane_d() -> void:
	var x: float = LANES[&"D"]
	plat(x, 4.0, -8.0, 0.0)
	# The marked wall: solid (layer 1) and climbable (layer 2). 7 m up to a roof.
	plat(x, -8.0, -16.0, 7.0, _climb, HALF * 2.0, 1 | 2)


func _lane_e() -> void:
	var x: float = LANES[&"E"]
	plat(x, 4.0, -4.0, 3.0)
	_beam(Vector3(x, 3.0, -8.0), 8.0, 0.2, false)
	plat(x, -12.0, -16.0, 3.0)
	_beam(Vector3(x, 3.0, -19.0), 6.0, 0.05, true)
	plat(x, -22.0, -28.0, 3.0)


func _lane_f() -> void:
	var x: float = LANES[&"F"]
	plat(x, 4.0, -14.0, 0.0)
	# The crawlway: a roof 1.1 m up from z -4 to -10, walled at the sides so it can't be walked round.
	block(Vector3(x, 1.1 + 0.95, -7.0), Vector3(HALF * 2.0, 1.9, 6.0), _wall)
	for side: float in [-1.0, 1.0]:
		block(Vector3(x + side * (HALF + 0.25), 1.5, -7.0), Vector3(0.5, 3.0, 6.0), _wall)
	plat(x, -20.5, -26.0, 0.0)    # 6.5 m gap


## G: a yard 20 m wide, walled waist-high on three sides, open at the near end. A checkpoint there; three goons patrol.
func _lane_g() -> void:
	var x: float = LANES[&"G"]
	plat(x, 4.0, -26.0, 0.0, null, 20.0)
	for side: float in [-1.0, 1.0]:
		block(Vector3(x + side * 10.25, 0.5, -11.0), Vector3(0.5, 1.0, 30.0), _wall)
	block(Vector3(x, 0.5, -26.25), Vector3(21.0, 1.0, 0.5), _wall)
	var cp := Checkpoint.new()
	cp.position = Vector3(x, 0.0, 2.0)
	add_child(cp)
	goon(&"g1", Vector3(x - 6, 0.05, -8), PackedVector3Array([Vector3(x - 6, 0, -8), Vector3(x + 6, 0, -8)]))
	goon(&"g2", Vector3(x + 6, 0.05, -15), PackedVector3Array([Vector3(x + 6, 0, -15), Vector3(x - 6, 0, -15)]))
	goon(&"g3", Vector3(x, 0.05, -22), PackedVector3Array([Vector3(x, 0, -22), Vector3(x, 0, -17)]))


## H: a sentry standing guard, facing away from where Nim comes in, and someone in a trance walking a loop past him.
func _lane_h() -> void:
	var x: float = LANES[&"H"]
	plat(x, 4.0, -20.0, 0.0, null, 16.0)
	goon(&"sentry", Vector3(x - 4.0, 0.05, -4.0), PackedVector3Array(), PI / 2.0)   # faces -X
	var e := Entranced.new()
	e.id = &"h1"
	e.position = Vector3(x + 3.0, 0.05, -8.0)
	e.loop = PackedVector3Array([Vector3(x + 3, 0, -8), Vector3(x + 3, 0, -16), Vector3(x + 6, 0, -16), Vector3(x + 6, 0, -8)])
	e.name = "Entranced_h1"
	add_child(e)


## I: the stealth yard. The moon comes from the south-west, so the 9 m wall down the west side shades a strip about 3 m
## wide along it: crouched in there she's all but invisible. The middle is lit by two lamps and patrolled; a guard
## stands at the far end looking back down the yard, with a lookout on a post behind him. A dark shed by the near
## end is somewhere to hide when it goes wrong.
func _lane_i() -> void:
	var x: float = LANES[&"I"]
	plat(x, 12.0, -42.0, 0.0, null, 22.0)
	block(Vector3(x - 11.5, 4.5, -15.0), Vector3(1.0, 9.0, 54.0), _wall)    # the west wall
	for z: float in [-10.0, -24.0]:
		_lamp_post(Vector3(x + 4.0, 0.0, z))
	goon(&"i_patrol", Vector3(x + 3.0, 0.05, -6.0), PackedVector3Array([Vector3(x + 3, 0, -6), Vector3(x + 3, 0, -28)]))
	goon(&"i_guard", Vector3(x - 2.0, 0.05, -33.0), PackedVector3Array(), PI)                   # looks back down the yard
	goon(&"i_drop", Vector3(x + 9.0, 0.05, -2.0), PackedVector3Array(), -PI / 2.0)             # faces the east edge
	var bird := Lookout.new()
	bird.name = "Lookout_i"
	bird.position = Vector3(x + 8.0, 0.0, -37.0)
	bird.watch_yaw = PI
	add_child(bird)
	# The shed: open to the north, 5 m deep, roofed.
	var sx := x + 6.0
	block(Vector3(sx, 1.4, 10.75), Vector3(5.0, 2.8, 0.5), _wall)            # back
	for side: float in [-1.0, 1.0]:
		block(Vector3(sx + side * 2.75, 1.4, 8.0), Vector3(0.5, 2.8, 6.0), _wall)
	block(Vector3(sx, 3.0, 8.0), Vector3(6.0, 0.4, 6.0), _wall)               # roof


## J: the club. The street (z 12 to -2) has a doorman goon by the door and a wardrobe tucked behind a wall, out of his
## sight. The room (z -2 to -30, 4 m walls): the bar and the bartender down the west side with a key on the counter
## and a locked back door in the north wall; two rows of guests making a crowded corridor down the middle; a goon on
## his rounds to the east; and security who know her face in the north-east corner, watching the room.
func _lane_j() -> void:
	var x: float = LANES[&"J"]
	var w0 := x - 11.0
	var w1 := x + 11.0
	plat(x, 12.0, -31.0, 0.0, null, 22.0)
	var club := Look.painted(Look.Pattern.PLASTER, Color("4a2e3e"), Color("1a0e16"), {"wet": 0.0})
	# The room's walls; the street door is a 4 m gap in the south wall, the back door a gap in the north.
	block(Vector3(w0 - 0.25, 2.0, -16.0), Vector3(0.5, 4.0, 28.5), club)
	block(Vector3(w1 + 0.25, 2.0, -16.0), Vector3(0.5, 4.0, 28.5), club)
	block(Vector3((w0 + x - 2.0) / 2.0, 2.0, -2.25), Vector3(x - 2.0 - w0, 4.0, 0.5), club)
	block(Vector3((x + 2.0 + w1) / 2.0, 2.0, -2.25), Vector3(w1 - x - 2.0, 4.0, 0.5), club)
	var back_x := x - 8.0
	block(Vector3((w0 + back_x - 0.8) / 2.0, 2.0, -30.25), Vector3(back_x - 0.8 - w0, 4.0, 0.5), club)
	block(Vector3((back_x + 0.8 + w1) / 2.0, 2.0, -30.25), Vector3(w1 - back_x - 0.8, 4.0, 0.5), club)
	var back := Door.new()
	back.name = "BackDoor_j"
	back.position = Vector3(back_x, 0.0, -30.25)
	back.rotation.y = PI   # its front faces into the room
	add_child(back)
	# The bar: a counter down the west wall, a key on it, the bartender in front.
	block(Vector3(w0 + 0.8, 0.55, -16.0), Vector3(1.2, 1.1, 16.0), Look.toon(Color("3a2218")))
	var key := KeyItem.new()
	key.id = &"back_room"
	key.name = "Key_j"
	key.position = Vector3(w0 + 0.9, 1.25, -20.0)
	add_child(key)
	var barman := Staff.new()
	barman.name = "Bartender_j"
	barman.position = Vector3(w0 + 3.0, 0.05, -14.0)
	barman.rotation.y = -PI / 2.0   # faces the room
	add_child(barman)
	barman.fetch_item = barman.get_path_to(key)
	barman.door = barman.get_path_to(back)
	# The crowd: two rows of guests facing each other, a corridor 2.8 m wide down the middle (x - 2.1).
	var colours := [Color("b08a6a"), Color("8a6a9a"), Color("6a8aa0"), Color("a07a5a"), Color("9a9a7a")]
	var i := 0
	for z in range(0, 13):
		for side: float in [-1.0, 1.0]:
			var g := Guest.new()
			g.position = Vector3(x - 2.1 + side * 1.4, 0.0, -3.6 - z * 1.8)
			g.look_yaw = -PI / 2.0 if side < 0.0 else PI / 2.0
			g.colour = colours[i % colours.size()]
			add_child(g)
			i += 1
	goon(&"j_rounds", Vector3(x + 4.0, 0.05, -8.0), PackedVector3Array([Vector3(x + 4, 0, -8), Vector3(x + 4, 0, -18)]))
	var guard := goon(&"j_security", Vector3(w1 - 3.0, 0.05, -27.0), PackedVector3Array(), atan2(0.6, -0.8))
	guard.knows_her = true
	# The street: the doorman by the door, and a wall with a wardrobe tucked behind it, out of his sight.
	goon(&"j_doorman", Vector3(x + 3.5, 0.05, 0.0), PackedVector3Array(), PI)   # looks down the street
	block(Vector3(x - 6.25, 1.5, 4.0), Vector3(9.5, 3.0, 0.5), club)
	var robe := Wardrobe.new()
	robe.name = "Wardrobe_j"
	robe.position = Vector3(x - 7.0, 0.0, 6.0)
	robe.rotation.y = PI   # its front faces the street (+Z), its back to the wall
	add_child(robe)


## K: every lesson and piece of gear, a station each, down three platforms: A (z 12 to -6), B (z -14 to -30) and C
## (z -42 to -72), with a ceilinged gap between A and B and a rope gap between B and C.
func _lane_k() -> void:
	var x: float = LANES[&"K"]
	plat(x, 12.0, -6.0, 0.0, null, 20.0)
	plat(x, -14.0, -30.0, 0.0, null, 20.0)
	plat(x, -42.0, -72.0, 0.0, null, 20.0)
	# A: Vesper, teaching the ceiling crawl and the headfirst descent (her lines: data/dialogue/course/vesper.dialogue).
	var vesper := LessonGiver.new()
	vesper.name = "Vesper_k"
	vesper.lesson = Lessons.CEILING
	vesper.dialogue_file = "res://data/dialogue/course/vesper.dialogue"
	vesper.dialogue_label = "ceiling"
	vesper.position = Vector3(x - 6.0, 0.0, 8.0)
	add_child(vesper)
	# A: Dash (a conversation added without code: data/dialogue/course/dash.dialogue) and a newsstand (a cutscene).
	var dash := Talker.new()
	dash.name = "Dash_k"
	dash.file = "res://data/dialogue/course/dash.dialogue"
	dash.display_name = "Dash"
	dash.colour = Color("e8a030")
	dash.who = "dash"
	dash.position = Vector3(x + 7.0, 0.0, 9.0)
	add_child(dash)
	var stand := Talker.new()
	stand.name = "Newsstand_k"
	stand.cutscene = "res://data/cutscenes/course_paper.json"
	stand.display_name = "Newsstand"
	stand.colour = Look.DECENCY_CREAM
	stand.position = Vector3(x + 3.0, 0.0, 10.0)
	add_child(stand)
	# A: the crop. A switch on a post 3 m off, a bell hung 2.8 m up.
	var post := block(Vector3(x + 6.0, 0.6, -0.15), Vector3(0.2, 1.2, 0.2), _beam_mat, self, false)
	post.name = "SwitchPost_k"
	var sw := CropTarget.new()
	sw.name = "Switch_k"
	sw.kind = CropTarget.Kind.SWITCH
	sw.position = Vector3(x + 6.0, 1.3, 0.0)
	add_child(sw)
	block(Vector3(x + 2.0, 1.6, -0.6), Vector3(0.15, 3.2, 0.15), _beam_mat, self, false)
	block(Vector3(x + 2.0, 3.2, -0.3), Vector3(0.15, 0.15, 0.7), _beam_mat, self, false)
	var bell := CropTarget.new()
	bell.name = "Bell_k"
	bell.kind = CropTarget.Kind.BELL
	bell.position = Vector3(x + 2.0, 2.8, 0.0)
	add_child(bell)
	# The ceiling over the A-B gap: a slab 3 m wide whose underside is 2.6 m up, marked (layer 3).
	var slab: StaticBody3D = block(Vector3(x, 2.8, -10.0), Vector3(3.0, 0.4, 10.0), _climb)
	slab.collision_layer = 1 | 4
	# B: a marked tower to come down head first (its north face, toward A, is the one to come down).
	var tower: StaticBody3D = block(Vector3(x + 5.0, 3.0, -20.0), Vector3(4.0, 6.0, 4.0), _climb)
	tower.collision_layer = 1 | 2
	# B: a crate on a shelf, for the rope to pull down.
	block(Vector3(x + 6.0, 1.5, -27.0), Vector3(3.0, 3.0, 2.0), _wall)
	var crate := Pullable.new()
	crate.name = "Crate_k"
	crate.position = Vector3(x + 6.0, 3.0, -26.6)
	add_child(crate)
	# B: a wardrobe, and a councillor who answers to nobody without the signet.
	var robe := Wardrobe.new()
	robe.name = "Wardrobe_k"
	robe.position = Vector3(x - 7.0, 0.0, -17.0)
	robe.rotation.y = PI
	add_child(robe)
	var councillor := Staff.new()
	councillor.name = "Councillor_k"
	councillor.powerful = true
	councillor.colour = Look.DECENCY_CREAM
	councillor.position = Vector3(x - 4.0, 0.05, -25.0)
	councillor.rotation.y = PI
	add_child(councillor)
	# The rope gap, B to C: 12 m, an anchor over the middle.
	block(Vector3(x, 7.2, -36.0), Vector3(6.0, 0.3, 0.3), _beam_mat, self, false)
	var anchor := SwingAnchor.new()
	anchor.name = "Anchor_k"
	anchor.position = Vector3(x, 6.5, -36.0)
	add_child(anchor)
	# C: a goon facing away (the rope binds him from range); two standing guard facing back up the lane (the Scold); a
	# sleeper walking a loop (the pendant); a guard looking west (the lure).
	goon(&"k_rope", Vector3(x + 6.0, 0.05, -46.0), PackedVector3Array(), 0.0)
	goon(&"k_scold1", Vector3(x - 6.0, 0.05, -50.0), PackedVector3Array(), PI)
	goon(&"k_scold2", Vector3(x - 4.0, 0.05, -54.0), PackedVector3Array(), PI)
	goon(&"k_lure", Vector3(x + 6.0, 0.05, -60.0), PackedVector3Array(), PI / 2.0)
	var sleeper := Entranced.new()
	sleeper.id = &"k1"
	sleeper.name = "Entranced_k1"
	sleeper.position = Vector3(x - 6.0, 0.05, -66.0)
	sleeper.loop = PackedVector3Array([Vector3(x - 6, 0, -66), Vector3(x - 6, 0, -63)])
	add_child(sleeper)


func _lamp_post(at: Vector3) -> void:
	var post := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.06
	cyl.bottom_radius = 0.1
	cyl.height = 3.2
	post.mesh = cyl
	post.position = at + Vector3.UP * 1.6
	post.material_override = Look.toon(Look.INK)
	add_child(post)
	collider(at + Vector3.UP * 1.6, Vector3(0.3, 3.2, 0.3))
	var flame := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.18
	s.height = 0.36
	flame.mesh = s
	var hot := StandardMaterial3D.new()
	hot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hot.albedo_color = Color(2.4, 1.5, 0.7)
	flame.material_override = hot
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.position = at + Vector3.UP * 3.35
	add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = Look.SODIUM
	light.light_energy = 3.0
	light.omni_range = 9.0
	light.position = at + Vector3.UP * 3.35
	add_child(light)


func goon(id: StringName, at: Vector3, route: PackedVector3Array, yaw := 0.0) -> Enemy:
	var g := Enemy.new()
	g.id = id
	g.name = "Goon_%s" % id
	g.patrol = route
	g.position = at
	g.rotation.y = yaw
	add_child(g)
	return g


func _beam(centre: Vector3, length: float, width: float, wire: bool) -> Beam:
	var b := Beam.new()
	b.length = length
	b.width = width
	b.wire = wire
	b.material = _beam_mat
	b.position = centre
	b.rotation.y = PI / 2.0   # its line runs along -Z
	add_child(b)
	return b


func _sign(x: float, text: String) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 64
	l.pixel_size = 0.01
	l.outline_size = 12
	l.modulate = Color("f2e6c8")
	l.outline_modulate = Look.INK
	l.position = Vector3(x, 9.0, 0.0)   # overhead: out of the camera's way on the raised lanes
	l.double_sided = false
	add_child(l)


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("141024")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("6a6494")
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("1e1a3a")
	env.fog_density = 0.008
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var moon := DirectionalLight3D.new()
	moon.light_color = Look.MOON
	moon.light_energy = 1.0
	moon.shadow_enabled = true
	moon.rotation = Vector3(deg_to_rad(-55), deg_to_rad(-30), 0)
	add_child(moon)
