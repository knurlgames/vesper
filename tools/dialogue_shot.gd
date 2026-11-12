extends SceneTree
## Screenshots of the dialogue box (Dash, at his choice) and a newspaper card, over the test course (windowed):
##   godot --path . -s tools/dialogue_shot.gd -- <dir>

func _initialize() -> void:
	var dir: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://shots"
	DirAccess.make_dir_recursive_absolute(dir)
	await process_frame
	var game := root.get_node("/root/Game")
	var dialogue := root.get_node("/root/Dialogue")
	game.set(&"persist", false)
	game.call(&"set_setting", "age_confirmed", true)
	game.call(&"reset")
	var course: Node = load("res://levels/test_course/course.tscn").instantiate()
	root.add_child(course)
	current_scene = course
	var nim: Node3D = course.get(&"nim")
	nim.call(&"teleport", Vector3(199, 0.05, 10.5), 0.0)
	for i in 10:
		await process_frame
	dialogue.call(&"run", "res://data/dialogue/course/dash.dialogue", "start")
	for i in 3:   # three lines in: the choice
		for f in 90:
			await process_frame
		dialogue.call(&"_advance")
	for f in 120:
		await process_frame
	root.get_texture().get_image().save_png(dir.path_join("dialogue_box.png"))
	dialogue.set(&"auto_advance", true)
	for f in 10:
		await process_frame
	dialogue.set(&"auto_advance", false)
	dialogue.call(&"_show_card", {"kind": "newspaper", "title": "SWYNE VOWS: \"I WILL CLEAN UP OUR SEAFRONT\"",
		"body": "Councillor Swyne condemned \"the filth on our seafront\" last night and promised a full clean-up of the Pier's \"so-called amusements\". Asked about his own visits to the Pier, the Councillor said he had been \"inspecting\"."})
	for f in 20:
		await process_frame
	root.get_texture().get_image().save_png(dir.path_join("newspaper.png"))
	print("dialogue shots in ", dir)
	quit()
