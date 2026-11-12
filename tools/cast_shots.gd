extends SceneTree
## The cast's exported models in the game's own look (windowed; it needs a GPU):
##   godot --path . -s tools/cast_shots.gd -- <out_dir> [who_outfit ...]
## Each body stands in the test room beside Nim's spawn: a full-body shot, a face shot (mask on), a shot with the
## mask off, then talk, walk and run.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0] if args.size() > 0 else "user://cast_shots"
	DirAccess.make_dir_recursive_absolute(dir)
	root.size = Vector2i(1280, 800)
	await process_frame
	var game := root.get_node("/root/Game")
	game.set(&"persist", false)
	game.call(&"set_setting", "age_confirmed", true)
	game.call(&"reset")
	var world: Node = load("res://main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in 20:
		await process_frame
	var nim: Node3D = root.get_tree().get_first_node_in_group(&"player")
	nim.visible = false
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.current = true
	var bodies: Array = args.slice(1) if args.size() > 1 else []
	if bodies.is_empty():
		for who in ["vesper", "augusta", "silke", "dash", "rivet", "lull", "grizelda", "bastion", "swyne"]:
			for outfit in (["garb"] if who == "swyne" else ["garb", "suit"]):
				if CastModel.exists(who, outfit):
					bodies.append("%s_%s" % [who, outfit])
	for b: String in bodies:
		var parts := b.split("_")
		var cm := CastModel.new()
		cm.who = parts[0]
		cm.outfit = parts[1] if parts.size() > 1 else "garb"
		world.add_child(cm)
		cm.global_position = nim.global_position + Vector3(0, 0, 0)
		cm.global_rotation = nim.global_rotation
		for i in 20:
			await process_frame
		var player: AnimationPlayer = cm.find_child("AnimationPlayer", true, false)
		await _shot(cam, cm, 3.4, 1.0, "%s/%s_stand.png" % [dir, b])
		await _shot(cam, cm, 1.0, 1.55, "%s/%s_face.png" % [dir, b])
		cm.masked = false
		await _shot(cam, cm, 1.0, 1.55, "%s/%s_face_unmasked.png" % [dir, b])
		cm.masked = true
		for clip in ["talk", "walk", "run"]:
			cm.set_process(false)
			player.play(clip)
			for i in 14:
				await process_frame
			await _shot(cam, cm, 3.4, 1.0, "%s/%s_%s.png" % [dir, b, clip], clip != "talk")
		cm.queue_free()
		await process_frame
	quit()


func _shot(cam: Camera3D, who: Node3D, dist: float, height: float, path: String, side := false) -> void:
	var front: Vector3 = -who.global_basis.z
	var d := (front + who.global_basis.x * (1.0 if side else 0.45)).normalized()
	cam.global_position = who.global_position + d * dist + Vector3.UP * height
	cam.look_at(who.global_position + Vector3.UP * (height * 0.97 if dist < 2.0 else 0.9))
	for i in 3:
		await process_frame
	root.get_texture().get_image().save_png(path)
	print("cast shot: ", path)
