extends SceneTree
## Fast travel, filmed (windowed; it needs a GPU): a travel point's petal bed close up, then a trip from the club's
## door to Seafront Road through the rose cyclone, a frame every 0.1 s:
##   godot --path . -s tools/travel_shots.gd -- <out_dir>

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await process_frame
	var game := root.get_node("/root/Game")
	root.get_node("/root/Dialogue").set(&"skip_cutscenes", true)
	game.set(&"persist", false)
	game.call(&"set_setting", "age_confirmed", true)
	game.call(&"reset")
	for f: String in ["hub/prologue_done", "visited/hub", "travel/hub/club", "travel/hub/seafront", "gate/pier"]:
		game.call(&"set_flag", f)
	var level: Node = load("res://levels/hub/hub.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	for i in 60:
		await process_frame
	var nim: Node3D = level.get(&"nim")
	var club := level.get_node("Travel_club") as Node3D
	var sea := level.get_node("Travel_seafront") as Node3D
	# The bed, close, with a fixed camera.
	var cam := Camera3D.new()
	level.add_child(cam)
	cam.global_transform = Transform3D(Basis.IDENTITY, club.global_position + Vector3(1.8, 1.4, 2.2)).looking_at(
		club.global_position + Vector3(0, 0.2, 0), Vector3.UP)
	cam.make_current()
	nim.call(&"teleport", club.global_position + Vector3(-1.5, 0.05, 1.5), 0.0)
	for k in 3:
		await create_timer(0.7).timeout
		root.get_texture().get_image().save_png("%s/bed_%d.png" % [out, k])
	# The trip, from her own follow camera.
	nim.call(&"teleport", club.global_position + Vector3(0, 0.05, 0), 0.0)
	cam.queue_free()
	(level.get(&"cam") as Node3D).find_child("*", true, false)
	for c: Camera3D in level.find_children("*", "Camera3D", true, false):
		if c != cam:
			c.make_current()
	await create_timer(0.8).timeout
	var done := [false]
	var go := func() -> void:
		await RoseCyclone.travel(nim, sea.global_position + Vector3.UP * 0.05, sea.rotation.y)
		done[0] = true
	go.call()
	var k := 0
	while not done[0] and k < 60:
		root.get_texture().get_image().save_png("%s/trip_%02d.png" % [out, k])
		k += 1
		await create_timer(0.1).timeout
	root.get_texture().get_image().save_png("%s/trip_%02d.png" % [out, k])
	print("travel shots: %d trip frames in %s" % [k + 1, out])
	quit()
