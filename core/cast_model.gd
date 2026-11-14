class_name CastModel
extends Node3D
## A supporting-cast member's model (WO-012): assets/characters/<who>/<who>_<outfit>.glb, built by
## tools/cast_build.py from Meshy's rig (ART_DIRECTION.md, "The supporting cast"). Every GLB carries the same clips:
## idle, talk, walk, run. Shared by Talker and LessonGiver, which keep their greybox capsule when the GLB is missing.
##
## - Idle by default; "talk" while a conversation shows one of their lines (Dialogue.current_speaker()).
## - walk / run by `speed` (m/s), for anyone a script moves.
## - A garb's mask (`<body>_Mask` on the head bone) is worn with the garb, conversations and cutscenes included
##   (owner, Deck review 3: popping it off and on to talk looked odd).
##
## Runs while the tree is paused (Dialogue pauses the world), so they still talk and breathe in a conversation.
## Reaches Dialogue at runtime with get_node_or_null: a probe compiles this before autoloads exist.

## Lower-case name: the folder and file prefix ("vesper", "augusta", ... "swyne").
@export var who := "vesper"
## "garb", "suit" or "swim" (the sisters, downstairs in the vaults). Swyne has one outfit; his file is swyne.glb.
@export var outfit := "garb"
## Wear the garb's mask when not in conversation.
@export var masked := true
## The speakers.json key whose lines make them talk (defaults to `who` capitalised).
@export var speaker := ""

## Feet speed in m/s at speed scale 1, so a moving clip matches the ground.
const CLIP_SPEED := {&"walk": 1.3, &"run": 4.5}
## Nim's own model, for her head and mask scale when she's worn here (it has no class_name).
const NimModelScript := preload("res://player/nim_model.gd")
const BLEND := 0.2
const RIM := 0.12
const OUTLINE_WIDTH := 0.008

## The face keys (tools/cast_face.py): blink_L/R, brow_up, brow_down. A blink every BLINK_EVERY seconds or so; while
## talking, the brows lift on emphasis. Some faces hold a resting expression (brow_down) all the time.
const BLINK_EVERY := Vector2(2.0, 5.5)
const BLINK_TIME := 0.16
const EMPHASIS_EVERY := Vector2(1.2, 2.6)
const EMPHASIS_TIME := 0.5
## Per character: the resting frown (brow_down) and how high the brows lift on emphasis.
const FACE_STYLE := {
	"vesper": {"rest": 0.0, "lift": 0.45},     # calm, exact: the smallest lift
	"augusta": {"rest": 0.0, "lift": 0.8},
	"silke": {"rest": 0.15, "lift": 0.35},     # silent and exact
	"dash": {"rest": 0.0, "lift": 1.0},
	"rivet": {"rest": 0.2, "lift": 0.7},       # sardonic
	"lull": {"rest": 0.0, "lift": 0.6},
	"grizelda": {"rest": 0.7, "lift": 0.0},    # grumpy: never lifts, frowns harder instead
	"bastion": {"rest": 0.3, "lift": 0.3},
	"swyne": {"rest": 0.0, "lift": 0.9},       # pompous
}

## Set by whoever moves them.
var speed := 0.0
## Held for a scene on the cross (hold()).
var held := false
## Talk without a conversation (the cast stage sets it while Nim stands near, to show the talk clip and brows).
var demo_talk := false
var loaded := false

var _model: Node3D
var _player: AnimationPlayer
var _mask: Node3D
var _clip := &""
var _face: MeshInstance3D
var _keys := {}
var _blink_in := 0.0
var _blink_t := -1.0
var _emph_in := 0.0
var _emph_t := -1.0


static func path_for(p_who: String, p_outfit: String) -> String:
	if p_who == "swyne":
		return "res://assets/characters/swyne/swyne.glb"
	return "res://assets/characters/%s/%s_%s.glb" % [p_who, p_who, p_outfit]


static func exists(p_who: String, p_outfit: String) -> bool:
	return ResourceLoader.exists(path_for(p_who, p_outfit))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if speaker == "":
		speaker = who.capitalize()
	var path := path_for(who, outfit)
	if not ResourceLoader.exists(path):
		return
	var packed: PackedScene = load(path)
	_model = packed.instantiate()
	_model.rotation.y = PI   # the GLB faces +Z; a character's front is -Z, like Nim's
	add_child(_model)
	_dress(_model)
	_player = _model.find_child("AnimationPlayer", true, false)
	# Nim, worn as a cast model (the title's cutscene and the file select): her head shrunk to sit with the cast's, her
	# muzzle less so, as her own model does (player/nim_model.gd HEAD_SCALE, MASK_SCALE).
	var nim_head := NimModelScript.HEAD_SCALE if who == "nim" else 1.0
	if who == "nim":
		for sk: Skeleton3D in _model.find_children("*", "Skeleton3D", true, false):
			var hs := BoneScale.new()
			hs.bone_name = &"head"
			hs.factor = nim_head
			sk.add_child(hs)
	for mi: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		if mi.name.ends_with("_Mask"):
			_mask = mi
			if who == "nim":
				var k := NimModelScript.MASK_SCALE / nim_head
				mi.transform = Transform3D(mi.transform.basis.scaled(Vector3.ONE * k), mi.transform.origin * k)
		elif mi.mesh and mi.find_blend_shape_by_name(&"blink_L") >= 0:
			_face = mi
	if _face:
		for k in [&"blink_L", &"blink_R", &"brow_up", &"brow_down"]:
			_keys[k] = _face.find_blend_shape_by_name(k)
	_blink_in = randf_range(0.5, BLINK_EVERY.y)
	if _player:
		for clip in [&"idle", &"idle_garb", &"idle_suit", &"talk", &"walk", &"run"]:
			if _player.has_animation(clip):
				_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	loaded = true
	_update(0.0)


## The game's look (ART_DIRECTION §4): the toon ramp with each surface's own texture, an ink outline, a light rim.
## Only brass shines.
func _dress(root: Node) -> void:
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		var is_mask := mi.name.ends_with("_Mask")
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i)
			var colour := Color.WHITE
			var tex: Texture2D = null
			if src is BaseMaterial3D:
				colour = (src as BaseMaterial3D).albedo_color
				tex = (src as BaseMaterial3D).albedo_texture
			mi.set_surface_override_material(i, Look.toon(colour, 0.5 if is_mask else 0.0, RIM, tex))
		# A mask is a thin open shell: an inverted hull 8 mm out would sit in front of its own face and ink it over.
		if not is_mask:
			mi.material_overlay = Look.outline(mi.get_aabb(), OUTLINE_WIDTH)


func _process(delta: float) -> void:
	if loaded and not held:
		_update(delta)


## Held still for a scene on the cross (core/cross_scene.gd): her own clips stop, frozen on idle, so her bones can be
## posed by hand; false gives her back her clips.
func hold(on: bool) -> void:
	held = on
	if _player == null:
		return
	if on:
		_player.play(_idle())
		_player.seek(0.0, true)
		_player.pause()
	else:
		var sk := skeleton()
		if sk:
			sk.reset_bone_poses()
		_player.play(_idle())


## The idle clip: "idle", or the outfit's own (Nim's GLBs, worn as a cast model on the title: "idle_garb").
func _idle() -> StringName:
	if _player == null or _player.has_animation(&"idle"):
		return &"idle"
	var own := StringName("idle_" + outfit)
	return own if _player.has_animation(own) else &"idle_garb"


func skeleton() -> Skeleton3D:
	return _model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D if _model else null


func _update(_delta: float) -> void:
	var dlg: Node = get_node_or_null(^"/root/Dialogue")
	var in_talk: bool = dlg != null and dlg.call(&"is_active")
	if _mask:
		# Worn through conversations too (owner, Deck review 3: "stop removing the masks during dialogues... have them
		# talk and use the animation as is without removing the mask").
		_mask.visible = masked and outfit == "garb"
	if _player == null:
		return
	var want := &"idle"
	if (in_talk and String(dlg.call(&"current_speaker")) == speaker) or (demo_talk and speed <= 0.2):
		want = &"talk"
	elif speed > 2.5:
		want = &"run"
	elif speed > 0.2:
		want = &"walk"
	if want == &"idle" or not _player.has_animation(want):
		want = _idle()
	if want != _clip or not _player.is_playing():
		_clip = want
		_player.play(want, BLEND)
	_player.speed_scale = speed / CLIP_SPEED[want] if CLIP_SPEED.has(want) else 1.0
	_update_face(_delta, want == &"talk")


func _update_face(delta: float, talking: bool) -> void:
	if _face == null:
		return
	var style: Dictionary = FACE_STYLE.get(who, {"rest": 0.0, "lift": 0.6})
	# Blink: shut fast, open a little slower.
	var shut := 0.0
	if _blink_t >= 0.0:
		_blink_t += delta
		var u := _blink_t / BLINK_TIME
		shut = clampf(u / 0.4, 0.0, 1.0) if u < 0.4 else clampf((1.0 - u) / 0.6, 0.0, 1.0)
		if u >= 1.0:
			_blink_t = -1.0
			_blink_in = randf_range(BLINK_EVERY.x, BLINK_EVERY.y)
	else:
		_blink_in -= delta
		if _blink_in <= 0.0:
			_blink_t = 0.0
	# Emphasis while talking: the brows lift and settle (Grizelda's frown deepens instead).
	var emph := 0.0
	if talking:
		if _emph_t >= 0.0:
			_emph_t += delta
			emph = sin(clampf(_emph_t / EMPHASIS_TIME, 0.0, 1.0) * PI)
			if _emph_t >= EMPHASIS_TIME:
				_emph_t = -1.0
				_emph_in = randf_range(EMPHASIS_EVERY.x, EMPHASIS_EVERY.y)
		else:
			_emph_in -= delta
			if _emph_in <= 0.0:
				_emph_t = 0.0
	else:
		_emph_t = -1.0
	var lift: float = style["lift"]
	var rest: float = style["rest"]
	_set_key(&"blink_L", shut)
	_set_key(&"blink_R", shut)
	_set_key(&"brow_up", emph * lift)
	_set_key(&"brow_down", clampf(rest + (emph * 0.3 if lift == 0.0 else -emph * rest), 0.0, 1.0))


func _set_key(key: StringName, value: float) -> void:
	var i: int = _keys.get(key, -1)
	if i >= 0:
		_face.set_blend_shape_value(i, value)
