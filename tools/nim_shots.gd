extends SceneTree
## Nim's model in the test room, through the game's own camera and look (windowed; it needs a GPU):
##   godot --path . -s tools/nim_shots.gd -- <out_dir>
## Shots: standing in the garb (mask on), walking, running, the suit standing and strutting, and a close camera on
## each so the face and the mask read.

func _initialize() -> void:
	var dir: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://nim_shots"
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
	var model: Node = nim.get(&"model")
	print("nim shots: model loaded = ", model.get(&"loaded"))
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.current = true
	# The level's name banner sits over her face for its first seconds.
	for i in 300:
		await process_frame
	for outfit in [0, 1]:
		model.call(&"set_outfit", outfit)
		nim.set(&"velocity", Vector3.ZERO)
		for i in 30:
			await process_frame
		await _shot(cam, nim, 3.2, 1.0, "%s/%d_stand.png" % [dir, outfit])
		await _shot(cam, nim, 0.9, 1.6, "%s/%d_face.png" % [dir, outfit])
		# Moving: drive her velocity straight and let the clip follow it.
		for clip_speed in [[2.0, "walk"], [6.5, "run"]]:
			for i in 40:
				nim.set(&"velocity", -nim.global_basis.z * clip_speed[0])
				await physics_frame
			await _shot(cam, nim, 3.2, 1.0, "%s/%d_%s.png" % [dir, outfit, clip_speed[1]], true)
	quit()


func _shot(cam: Camera3D, nim: Node3D, dist: float, height: float, path: String, side := false) -> void:
	var front: Vector3 = -nim.global_basis.z
	var d := (front + nim.global_basis.x * (1.0 if side else 0.45)).normalized()
	cam.global_position = nim.global_position + d * dist + Vector3.UP * height
	cam.look_at(nim.global_position + Vector3.UP * (height * 0.9 if dist < 2.0 else 0.9))
	for i in 3:
		await process_frame
	root.get_texture().get_image().save_png(path)
	print("nim shot: ", path)
