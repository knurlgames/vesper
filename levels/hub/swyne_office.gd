extends Node3D
## Councillor Swyne's office at City Hall, after hours (owner, 2026-11-14: "the Swyne cutaways"; Banjo's cuts back to
## the villain): a small set built far off the hub's map and hidden until a cutaway plays. After each world, the first
## time Nim's back at the club (hub.gd _welcome_home), the camera cuts here: Swyne at his desk with the evening paper,
## reading about the job the Claw just did, and getting angrier (data/dialogue/hub/swyne.dialogue: <world>,
## <world>_paper, <world>_rage). One template for every world; a world with no lines has no cutaway. "swyne/<world>"
## remembers it played.
##
## In his palette (cream, lilac, his pale blue; LIBERTIES.md): cream panelling, a lilac carpet, a portrait of himself,
## the Coalition's banner, a city's lights through the window, and a board of his chain, a red cross on each link the
## Claw has cut (one more goes on in the cutaway).

const DIALOGUE := "res://data/dialogue/hub/swyne.dialogue"
## Far off the map (beyond the fog from anywhere Nim can stand).
const AT := Vector3(-240.0, 0.0, -240.0)
const W := 9.0
const D := 7.0
const H := 4.2
## Where he stands, behind his desk, facing the room (+Z).
const SWYNE_AT := Vector3(0.0, 0.0, -2.35)
const DESK := Vector3(0.0, 0.0, -1.55)
const PAPER := Vector3(-0.15, 0.835, -1.3)
## His chain on the board (DESIGN.md "The worlds"): world -> the name on the card.
const CHAIN := [[&"pier", "LAFFER\nThe Pier"], [&"primrose", "MRS GANDER\nPrimrose Close"], [&"docks", "?\nThe Docks"],
	[&"retreat", "?\nThe Retreat"], [&"press", "?\nThe Press"], [&"ball", "?\nThe Ball"]]
## The evening paper's front page on his desk, by world (the papers in data/cutscenes/paper_<world>.json).
const HEADLINES := {&"pier": "SWYNE: \"FILTH ON\nOUR SEAFRONT\"", &"primrose": "A RECORD\nYEAR"}

var swyne: Talker
var _paper: Label3D
var _crosses := {}
var _m := {}


func _ready() -> void:
	position = AT
	visible = false
	_m.panel = Look.painted(Look.Pattern.PLASTER, Look.DECENCY_CREAM.darkened(0.15), Color("4a4038"), {"wet": 0.0})
	_m.dado = Look.painted(Look.Pattern.PLANKS, Color("5a3a2a"), Color("1c120c"), {"wet": 0.0})
	_m.carpet = Look.toon(Color("6a5880"))
	_m.ceiling = Look.toon(Look.DECENCY_CREAM.darkened(0.35))
	_m.wood = Look.toon(Color("4a2a1c"), 0.35)
	_m.brass = Look.toon(Look.BRASS, 0.7)
	_m.navy = Look.toon(Look.DECENCY_NAVY, 0.2)
	_m.cream = Look.toon(Look.DECENCY_CREAM, 0.1)
	_m.glass = Look.toon(Color("0e1630"), 0.8)
	_m.cork = Look.toon(Color("9a7a52"))
	_m.green = Look.toon(Color("2a6a44"), 0.5)
	_room()
	_furniture()
	_board()
	swyne = Talker.new()
	swyne.name = "Swyne"
	swyne.who = "swyne"
	swyne.greybox = false
	swyne.reach = 0.0
	swyne.position = SWYNE_AT
	swyne.rotation.y = PI
	add_child(swyne)


func _box(at: Vector3, size: Vector3, mat: Material, solid := false) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = at
	add_child(mi)
	if solid:   # (the ceiling: the hub's rain looks up from the camera and stops under a roof)
		var body := StaticBody3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		var col := CollisionShape3D.new()
		col.shape = shape
		body.add_child(col)
		body.position = at
		add_child(body)


func _label(text: String, at: Vector3, yaw: float, colour: Color, size: int, px := 0.006) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = px
	l.modulate = colour
	l.outline_size = 0
	l.shaded = true
	l.double_sided = false
	l.position = at
	l.rotation.y = yaw
	add_child(l)
	return l


func _light(at: Vector3, colour: Color, energy: float, reach: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = colour
	l.light_energy = energy
	l.omni_range = reach
	l.omni_attenuation = 1.3
	l.position = at
	add_child(l)
	return l


func _room() -> void:
	var hw := W / 2.0
	var hd := D / 2.0
	_box(Vector3(0, -0.1, 0), Vector3(W + 0.4, 0.2, D + 0.4), _m.carpet)
	_box(Vector3(0, H + 0.1, 0), Vector3(W + 0.4, 0.2, D + 0.4), _m.ceiling, true)
	# The side walls and the front (behind the camera), panelled: cream over a wooden dado.
	for s: float in [-1.0, 1.0]:
		_box(Vector3(s * (hw + 0.1), H / 2.0, 0), Vector3(0.2, H, D), _m.panel)
		_box(Vector3(s * (hw - 0.02), 0.55, 0), Vector3(0.06, 1.1, D), _m.dado)
		_box(Vector3(s * (hw - 0.04), 1.12, 0), Vector3(0.1, 0.06, D), _m.brass)
	_box(Vector3(0, H / 2.0, hd + 0.1), Vector3(W, H, 0.2), _m.panel)
	# The back wall, round a tall window onto the city at night.
	var win := Rect2(-1.7, 1.0, 3.4, 2.6)   # x, y, width, height
	var left := hw + win.position.x            # wall to the left of the window
	_box(Vector3(-hw + left / 2.0, H / 2.0, -hd - 0.1), Vector3(left, H, 0.2), _m.panel)
	_box(Vector3(hw - left / 2.0, H / 2.0, -hd - 0.1), Vector3(left, H, 0.2), _m.panel)
	_box(Vector3(0, win.position.y / 2.0, -hd - 0.1), Vector3(win.size.x, win.position.y, 0.2), _m.panel)
	var top := win.position.y + win.size.y
	_box(Vector3(0, (top + H) / 2.0, -hd - 0.1), Vector3(win.size.x, H - top, 0.2), _m.panel)
	_box(Vector3(0, 0.55, -hd + 0.02), Vector3(W, 1.1, 0.06), _m.dado)
	# The window: mullions, a sill, the dark glass, and the Old Quarter's lights beyond it.
	_box(Vector3(0, win.position.y + win.size.y / 2.0, -hd - 0.16), Vector3(win.size.x, win.size.y, 0.04), _m.glass)
	for x: float in [-1.7, -0.57, 0.57, 1.7]:
		_box(Vector3(x, win.position.y + win.size.y / 2.0, -hd - 0.08), Vector3(0.08, win.size.y, 0.1), _m.wood)
	for y: float in [win.position.y, win.position.y + win.size.y * 0.62, top]:
		_box(Vector3(0, y, -hd - 0.06), Vector3(win.size.x + 0.1, 0.08, 0.14), _m.wood)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(2.0, 1.5, 0.8)
	for i in 70:
		var at := Vector3(rng.randf_range(-6.0, 6.0), rng.randf_range(-3.0, 3.4), -hd - rng.randf_range(8.0, 30.0))
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.25, 0.3, 0.05) * (1.0 + absf(at.z + hd) / 20.0)
		mi.mesh = b
		mi.material_override = glow
		mi.position = at
		add_child(mi)
	# Heavy curtains either side (lilac), and a pelmet.
	for s: float in [-1.0, 1.0]:
		_box(Vector3(s * 2.1, 2.3, -hd + 0.15), Vector3(0.6, 3.4, 0.12), Look.toon(Color("8a74a8"), 0.2))
	_box(Vector3(0, 3.75, -hd + 0.15), Vector3(4.9, 0.32, 0.16), _m.wood)
	# A portrait of himself, life-size, in gilt (left wall), and the Coalition's banner (right wall). Its full name
	# goes on anything printed (DESIGN.md).
	_box(Vector3(-hw + 0.04, 2.45, -0.4), Vector3(0.08, 1.9, 1.5), _m.brass)
	_box(Vector3(-hw + 0.08, 2.45, -0.4), Vector3(0.04, 1.7, 1.3), Look.toon(Color("8a74a8"), 0.1))
	var face := Sprite3D.new()
	var tex_path := "res://assets/ui/portraits/swyne_up.png"
	if ResourceLoader.exists(tex_path):
		face.texture = load(tex_path)
		face.pixel_size = 1.25 / maxf(1.0, float(face.texture.get_width()))
		face.position = Vector3(-hw + 0.11, 2.4, -0.4)
		face.rotation.y = PI / 2.0
		face.shaded = true
		face.double_sided = false
		add_child(face)
	_label("COUNCILLOR SWYNE", Vector3(-hw + 0.11, 1.45, -0.4), PI / 2.0, Look.BRASS.lightened(0.3), 28)
	_box(Vector3(hw - 0.05, 2.6, -0.2), Vector3(0.04, 1.6, 2.6), _m.navy)
	_box(Vector3(hw - 0.05, 1.78, -0.2), Vector3(0.05, 0.06, 2.7), _m.brass)
	_label("THE DECENCY AND INTEGRITY\nCOALITION OF KINDNESS", Vector3(hw - 0.08, 2.95, -0.2), -PI / 2.0,
		Look.DECENCY_CREAM, 30)
	_label("FAMILIES  ·  FAITH  ·  FRESH AIR", Vector3(hw - 0.08, 2.2, -0.2), -PI / 2.0, Color("a8c8e8"), 22)
	# Lights: a cream ceiling light, a warm desk lamp, a cool spill from the window.
	_light(Vector3(0, H - 0.4, 0.6), Color("f2e6c8"), 1.1, 8.0)
	_light(Vector3(0.9, 1.35, -1.75), Color("ffc87a"), 1.3, 4.5)
	_light(Vector3(0, 2.2, -hd + 0.6), Color("8aa0e0"), 0.6, 4.0)
	_light(Vector3(2.4, 2.0, 2.4), Color("e0d0f0"), 0.5, 6.0)


func _furniture() -> void:
	# The desk: mahogany, brass-edged, a leather top.
	_box(DESK + Vector3(0, 0.4, 0), Vector3(2.6, 0.8, 1.1), _m.wood)
	_box(DESK + Vector3(0, 0.81, 0), Vector3(2.66, 0.03, 1.16), _m.brass)
	_box(DESK + Vector3(0, 0.825, 0.05), Vector3(1.9, 0.01, 0.8), Look.toon(Color("1e3a30"), 0.4))
	# The banker's lamp, the in-tray, a nameplate facing the visitor.
	_box(DESK + Vector3(0.9, 0.84, 0.0), Vector3(0.22, 0.04, 0.16), _m.brass)
	_box(DESK + Vector3(0.9, 1.0, 0.0), Vector3(0.03, 0.3, 0.03), _m.brass)
	_box(DESK + Vector3(0.9, 1.17, 0.06), Vector3(0.42, 0.1, 0.2), _m.green)
	_box(DESK + Vector3(-0.95, 0.88, -0.15), Vector3(0.4, 0.1, 0.32), _m.wood)
	_box(DESK + Vector3(-0.95, 0.94, -0.15), Vector3(0.34, 0.02, 0.26), _m.cream)
	_box(DESK + Vector3(0, 0.87, 0.5), Vector3(0.6, 0.08, 0.04), _m.navy)
	_label("CLLR. SWYNE", DESK + Vector3(0, 0.87, 0.53), 0.0, Look.BRASS.lightened(0.4), 20, 0.003)
	# The evening paper, open on the desk, read the visitor's way up (the camera's close-up reads it).
	_box(PAPER, Vector3(0.66, 0.008, 0.46), Look.toon(Look.DECENCY_CREAM.darkened(0.3)))
	_paper = Label3D.new()
	_paper.font_size = 30
	_paper.pixel_size = 0.0022
	_paper.modulate = Color("1a1a24")
	_paper.outline_size = 0
	_paper.shaded = true
	_paper.double_sided = false
	_paper.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_paper.position = PAPER + Vector3(0, 0.006, 0.02)
	_paper.rotation = Vector3(-PI / 2.0, 0, 0)
	add_child(_paper)
	var mast := Label3D.new()
	mast.text = "THE EVENING PAW"
	mast.font_size = 22
	mast.pixel_size = 0.0022
	mast.modulate = Color("1a1a24")
	mast.outline_size = 0
	mast.shaded = true
	mast.double_sided = false
	mast.position = PAPER + Vector3(0, 0.006, -0.17)
	mast.rotation = Vector3(-PI / 2.0, 0, 0)
	add_child(mast)
	# His chair: the club's wingback (a Meshy prop), if it's there.
	_prop("parlour_armchair", SWYNE_AT + Vector3(0, 0, -0.55), 0.0)


## A Meshy prop (assets/props), dressed in the game's look, its own node (the hub's props() batch into the hub).
func _prop(prop_name: String, at: Vector3, yaw: float) -> void:
	var path := "res://assets/props/%s.glb" % prop_name
	if not ResourceLoader.exists(path):
		return
	var scene: Node3D = (load(path) as PackedScene).instantiate()
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		var src := mi.get_active_material(0)
		var tex: Texture2D = (src as BaseMaterial3D).albedo_texture if src is BaseMaterial3D else null
		mi.material_override = Look.toon(Color.WHITE, 0.0, 0.0, tex)
		mi.material_overlay = Look.outline(mi.get_aabb(), 0.012)
	scene.position = at
	scene.rotation.y = yaw
	add_child(scene)


## His chain, pinned on the back wall right of the window: a card a link, a red cross on each the Claw has cut.
func _board() -> void:
	var c := Vector3(3.15, 2.35, -D / 2.0 + 0.03)
	_box(c, Vector3(1.7, 1.2, 0.04), _m.cork)
	_box(c + Vector3(0, 0, -0.01), Vector3(1.8, 1.3, 0.04), _m.wood)
	for i in CHAIN.size():
		var at := c + Vector3(-0.55 + (i % 3) * 0.55, 0.27 - (i / 3) * 0.55, 0.03)
		_box(at, Vector3(0.44, 0.4, 0.01), _m.cream)
		_label(String(CHAIN[i][1]), at + Vector3(0, 0, 0.01), 0.0, Color("1a1a24"), 26, 0.0022)
		var x := _label("X", at + Vector3(0, 0, 0.02), 0.0, Color(1.6, 0.15, 0.15), 120, 0.004)
		x.visible = Game.has_flag("done/%s" % CHAIN[i][0])
		_crosses[CHAIN[i][0]] = x


## Whether `world` has a cutaway to play: its lines are written, it's done, and it hasn't played.
func due(world: StringName) -> bool:
	return Game.has_flag("done/%s" % world) and not Game.has_flag("swyne/%s" % world) and _lines().has_label(String(world))


var _script: DialogueScript


func _lines() -> DialogueScript:
	if _script == null:
		_script = DialogueParser.parse_file(DIALOGUE)
	return _script


## The cutaway for `world` (about 25 s; its lines always play, the camera work skips). Called by the hub.
func cutaway(world: StringName) -> void:
	var w := String(world)
	if Dialogue.skip_cutscenes:   # (probes: his lines set nothing, so they're skipped too)
		cross(w)
		Game.set_flag("swyne/%s" % w)
		return
	_paper.text = HEADLINES.get(world, "")
	var x: Label3D = _crosses.get(world)
	if x:
		x.visible = false
	visible = true
	var o := AT
	var p := func(v: Vector3) -> Array: return [o.x + v.x, o.y + v.y, o.z + v.z]
	var face := SWYNE_AT + Vector3(0, 1.75, 0)
	var steps := [
		{"fade": {"to": 1.0, "secs": 0}},
		# A wide from the door's corner: the desk, the window, the banner.
		{"shot": {"from": p.call(Vector3(3.4, 2.5, 3.1)), "look_at": p.call(Vector3(-0.3, 1.5, -2.2))}},
		{"fade": {"to": 0.0, "secs": 0.6}},
		{"caption": "City Hall. Councillor Swyne, working late."},
		{"shot": {"from": p.call(Vector3(2.7, 2.3, 2.4)), "look_at": p.call(Vector3(-0.2, 1.45, -2.2)), "secs": 2.6}},
		{"caption": ""},
		# Over the desk to him, pleased with himself.
		{"shot": {"from": p.call(Vector3(0.9, 1.45, 0.9)), "look_at": p.call(face + Vector3(0, -0.75, 0))}},
		{"say": {"file": DIALOGUE, "label": w}},
		# The paper, close.
		{"shot": {"start_from": p.call(PAPER + Vector3(0.05, 0.85, 0.35)), "start_look": p.call(PAPER),
			"from": p.call(PAPER + Vector3(0.0, 0.62, 0.22)), "look_at": p.call(PAPER + Vector3(0, 0, -0.02)), "secs": 2.0}},
		{"say": {"file": DIALOGUE, "label": w + "_paper"}},
		# A slow push in on him as he works it out.
		{"shot": {"start_from": p.call(Vector3(0.5, 1.65, 0.4)), "start_look": p.call(face + Vector3(0, -0.5, 0)),
			"from": p.call(Vector3(0.25, 1.7, -0.9)), "look_at": p.call(face + Vector3(0, -0.4, 0)), "secs": 5.0}},
		{"say": {"file": DIALOGUE, "label": w + "_rage"}},
		# The board: another link crossed off.
		{"shot": {"from": p.call(Vector3(1.9, 2.2, -1.2)), "look_at": p.call(Vector3(3.15, 2.35, -3.4))}},
		{"call": {"node": "SwyneOffice", "method": "cross", "args": [w]}},
		{"wait": 1.2},
		{"fade": {"to": 1.0, "secs": 0.5}},
	]
	await Dialogue.play_cutscene({"live": true, "steps": steps})
	visible = false
	Game.set_flag("swyne/%s" % w)


## His board gets its red cross (a pop): awaitable; at once if the cutscene's being skipped.
func cross(world: String) -> Signal:
	var x: Label3D = _crosses.get(StringName(world))
	if x == null:
		return get_tree().process_frame
	x.visible = true
	if Dialogue.get(&"_skip"):
		return get_tree().process_frame
	x.scale = Vector3.ONE * 2.2
	var tw := create_tween()
	tw.tween_property(x, ^"scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tw.finished
