extends SceneTree
## Checks every exported cast GLB (WO-012, tools/cast_build.py) the way CastModel will use it: the four clips, the
## tail and ear bones, the mask node on a garb, and that CastModel loads, dresses and plays it.
## godot --headless --fixed-fps 60 --path . -s tools/cast_probe.gd
## Prints "CAST <file> ok" or what's wrong, then "CAST failures N".

const CLIPS := ["idle", "talk", "walk", "run"]
const MASKED := ["augusta", "silke", "dash", "rivet", "lull", "grizelda", "bastion"]

var failures := 0
var _models: Array = []
var _frames := 0


func _fail(msg: String) -> void:
	failures += 1
	print("CAST FAIL ", msg)


func _initialize() -> void:
	var found := 0
	for who in ["vesper", "augusta", "silke", "dash", "rivet", "lull", "grizelda", "bastion", "swyne"]:
		for outfit in (["garb"] if who == "swyne" else ["garb", "suit"]):
			var path := CastModel.path_for(who, outfit)
			if not ResourceLoader.exists(path):
				continue
			found += 1
			_check(who, outfit, path)
	print("CAST bodies ", found)


## CastModel loads in _ready, which a node added during _initialize only gets on the first frame.
func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false
	for cm: CastModel in _models:
		var ap: AnimationPlayer = cm.find_child("AnimationPlayer", true, false)
		if not cm.loaded:
			_fail("%s_%s CastModel didn't load" % [cm.who, cm.outfit])
		elif ap == null or ap.current_animation != "idle":
			_fail("%s_%s CastModel isn't playing idle (%s)" % [cm.who, cm.outfit, ap.current_animation if ap else "-"])
	print("CAST failures ", failures)
	quit(1 if failures else 0)
	return true


func _check(who: String, outfit: String, path: String) -> void:
	var tag := path.get_file()
	var root: Node3D = (load(path) as PackedScene).instantiate()
	var ap: AnimationPlayer = root.find_child("AnimationPlayer", true, false)
	if ap == null:
		_fail("%s no AnimationPlayer" % tag)
	else:
		for c in CLIPS:
			if not ap.has_animation(c):
				_fail("%s missing clip %s (has %s)" % [tag, c, ", ".join(ap.get_animation_list())])
	var sk: Skeleton3D = null
	for n in root.find_children("*", "Skeleton3D", true, false):
		sk = n
	var tail := 0
	var ears := 0
	if sk == null:
		_fail("%s no skeleton" % tag)
	else:
		for i in sk.get_bone_count():
			var b := sk.get_bone_name(i)
			if b.begins_with("tail."):
				tail += 1
			elif b.begins_with("ear."):
				ears += 1
	# Swyne has no tail. (Bastion's garb has her suit's, grafted: cast_build `graft`.)
	var tail_min := 0 if who == "swyne" else 3
	if who != "swyne" and (tail < tail_min or ears != 2):
		_fail("%s chains: tail %d ears %d" % [tag, tail, ears])
	var masks := root.find_children("*_Mask", "MeshInstance3D", true, false)
	var want_mask := outfit == "garb" and who in MASKED
	if want_mask and masks.is_empty():
		_fail("%s has no mask node" % tag)
	if not want_mask and not masks.is_empty():
		_fail("%s has a mask it shouldn't" % tag)
	var tris := 0
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			tris += (mi.mesh as ArrayMesh).surface_get_array_len(s) / 3 if (mi.mesh as ArrayMesh).surface_get_format(s) & Mesh.ARRAY_FORMAT_INDEX == 0 else (mi.mesh as ArrayMesh).surface_get_array_index_len(s) / 3
	if tris > 80000:
		_fail("%s is %d triangles, over the cast budget (80k)" % [tag, tris])
	# The face keys (cast_build `face`): on the body mesh, never the mask.
	var keyed := false
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh and not mi.name.ends_with("_Mask"):
			var have := [&"blink_L", &"blink_R", &"brow_up", &"brow_down"].all(
				func(k: StringName) -> bool: return mi.find_blend_shape_by_name(k) >= 0)
			keyed = keyed or have
	if not keyed:
		_fail("%s has no face keys (blink_L/R, brow_up, brow_down)" % tag)
	root.free()
	# Through CastModel, as the game uses it.
	var cm := CastModel.new()
	cm.who = who
	cm.outfit = outfit
	get_root().add_child(cm)
	_models.append(cm)
	print("CAST %s clips ok, tail %d, ears %d, mask %s, tris %d" % [tag, tail, ears, not masks.is_empty(), tris])
