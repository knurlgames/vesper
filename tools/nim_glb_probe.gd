extends SceneTree
## Loads Nim's GLBs (the garb, the suit, and the two-piece the club's scenes put her in) and prints what the game will
## drive: animations, bones, meshes, blend shapes. Checks each has the same clips and bones as the garb, the face keys
## and (garb and two-piece) the muzzle node.
## godot --headless --path . -s tools/nim_glb_probe.gd

const MUZZLED := ["garb", "swim"]

var fails := 0


func _init() -> void:
	var clips_ref := PackedStringArray()
	var bones_ref := 0
	for outfit in ["garb", "suit", "swim"]:
		var path := "res://assets/characters/nim/nim_%s.glb" % outfit
		var packed: PackedScene = load(path)
		if packed == null:
			_fail("%s didn't load" % outfit)
			continue
		var root := packed.instantiate()
		var ap: AnimationPlayer = root.find_child("AnimationPlayer", true, false)
		var names: PackedStringArray = ap.get_animation_list() if ap else PackedStringArray()
		print("GLB ", outfit, " animations ", names.size(), ": ", ", ".join(names))
		var sk: Skeleton3D = null
		for n in root.find_children("*", "Skeleton3D", true, false):
			sk = n
		if sk:
			print("GLB ", outfit, " bones ", sk.get_bone_count())
		var mask := false
		var face := false
		for m: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			var shapes := []
			if m.mesh is ArrayMesh:
				for i in (m.mesh as ArrayMesh).get_blend_shape_count():
					shapes.append((m.mesh as ArrayMesh).get_blend_shape_name(i))
			mask = mask or m.name.ends_with("_Mask")
			face = face or "blink_L" in shapes
			print("GLB ", outfit, " mesh ", m.name, " parent ", m.get_parent().name, " shapes ", shapes)
		if outfit == "garb":
			clips_ref = names
		elif names.size() != clips_ref.size():
			_fail("%s has %d clips, the garb %d" % [outfit, names.size(), clips_ref.size()])
		if sk:
			for b in ["upper_arm.L", "forearm.R", "hand.R", "chest", "spine", "hips", "head", "thigh.L", "shin.R", "tail.1"]:
				if sk.find_bone(b) < 0:
					_fail("%s has no bone %s" % [outfit, b])
		else:
			_fail("%s has no skeleton" % outfit)
		if not face:
			_fail("%s has no face keys" % outfit)
		if mask != (outfit in MUZZLED):
			_fail("%s: muzzle node %s" % [outfit, mask])
		root.free()
	print("GLB failures ", fails)
	quit(1 if fails else 0)


func _fail(what: String) -> void:
	fails += 1
	print("FAIL  ", what)
