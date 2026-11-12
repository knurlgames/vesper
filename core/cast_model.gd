class_name CastModel
extends Node3D
## A supporting-cast member's model (WO-012): assets/characters/<who>/<who>_<outfit>.glb, built by
## tools/cast_build.py from Meshy's rig (ART_DIRECTION.md, "The supporting cast"). Every GLB carries the same clips:
## idle, talk, walk, run. Shared by Talker and LessonGiver, which keep their greybox capsule when the GLB is missing.
##
## - Idle by default; "talk" while a conversation shows one of their lines (Dialogue.current_speaker()).
## - walk / run by `speed` (m/s), for anyone a script moves.
## - A garb's mask (`<body>_Mask` on the head bone) is worn while covert and off in conversation and cutscenes
##   (ART_DIRECTION: "Off for dialogue and cutscenes. Worn with the night garb only").
##
## Runs while the tree is paused (Dialogue pauses the world), so they still talk and breathe in a conversation.
## Reaches Dialogue at runtime with get_node_or_null: a probe compiles this before autoloads exist.

## Lower-case name: the folder and file prefix ("vesper", "augusta", ... "swyne").
@export var who := "vesper"
## "garb" or "suit". Swyne has one outfit; his file is swyne.glb.
@export var outfit := "garb"
## Wear the garb's mask when not in conversation.
@export var masked := true
## The speakers.json key whose lines make them talk (defaults to `who` capitalised).
@export var speaker := ""

## Feet speed in m/s at speed scale 1, so a moving clip matches the ground.
const CLIP_SPEED := {&"walk": 1.3, &"run": 4.5}
const BLEND := 0.2
const RIM := 0.12
const OUTLINE_WIDTH := 0.008

## Set by whoever moves them.
var speed := 0.0
var loaded := false

var _model: Node3D
var _player: AnimationPlayer
var _mask: Node3D
var _clip := &""


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
	for mi: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		if mi.name.ends_with("_Mask"):
			_mask = mi
	if _player:
		for clip in [&"idle", &"talk", &"walk", &"run"]:
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
	if loaded:
		_update(delta)


func _update(_delta: float) -> void:
	var dlg: Node = get_node_or_null(^"/root/Dialogue")
	var in_talk: bool = dlg != null and dlg.call(&"is_active")
	if _mask:
		_mask.visible = masked and outfit == "garb" and not in_talk
	if _player == null:
		return
	var want := &"idle"
	if in_talk and String(dlg.call(&"current_speaker")) == speaker:
		want = &"talk"
	elif speed > 2.5:
		want = &"run"
	elif speed > 0.2:
		want = &"walk"
	if not _player.has_animation(want):
		want = &"idle"
	if want != _clip or not _player.is_playing():
		_clip = want
		_player.play(want, BLEND)
	_player.speed_scale = speed / CLIP_SPEED[want] if CLIP_SPEED.has(want) else 1.0
