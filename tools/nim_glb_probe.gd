extends SceneTree
## Loads Nim's two GLBs and prints what the game will drive: animations, bones, meshes, blend shapes.
## godot --headless --path . -s tools/nim_glb_probe.gd

func _init() -> void:
	for outfit in ["garb", "suit"]:
		var path := "res://assets/characters/nim/nim_%s.glb" % outfit
		var packed: PackedScene = load(path)
		if packed == null:
			print("GLB ", outfit, " FAILED to load")
			continue
		var root := packed.instantiate()
		var ap: AnimationPlayer = root.find_child("AnimationPlayer", true, false)
		var names: PackedStringArray = ap.get_animation_list() if ap else PackedStringArray()
		print("GLB ", outfit, " animations ", names.size(), ": ", ", ".join(names))
		var sk: Skeleton3D = root.find_child("*", true, false) as Skeleton3D
		for n in root.find_children("*", "Skeleton3D", true, false):
			sk = n
		if sk:
			print("GLB ", outfit, " bones ", sk.get_bone_count())
		for m: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			var shapes := []
			if m.mesh is ArrayMesh:
				for i in (m.mesh as ArrayMesh).get_blend_shape_count():
					shapes.append((m.mesh as ArrayMesh).get_blend_shape_name(i))
			print("GLB ", outfit, " mesh ", m.name, " parent ", m.get_parent().name, " shapes ", shapes)
		root.free()
	quit()
