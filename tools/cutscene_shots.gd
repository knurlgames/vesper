extends SceneTree
## Frames of a cutscene, played for real (windowed; it needs a GPU), to frame its shots: a screenshot at the end of
## every step, and one mid-way through any step that moves the camera:
##   godot --path . -s tools/cutscene_shots.gd -- <scene.tscn> <cutscene.json> <out_dir> [flag ...]
## Flags are set before the scene loads (e.g. hub/prologue_done). The scene's own intro, if any, is skipped first.

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var scene_path: String = a[0]
	var cut: String = a[1]
	var out: String = a[2]
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await process_frame
	var game := root.get_node("/root/Game")
	var dialogue := root.get_node("/root/Dialogue")
	game.set(&"persist", false)
	game.call(&"set_setting", "age_confirmed", true)
	game.call(&"reset")
	for f in a.slice(3):
		game.call(&"set_flag", f)
	dialogue.set(&"skip_cutscenes", true)   # the scene's own intro, if it has one
	var level: Node = load(scene_path).instantiate()
	root.add_child(level)
	current_scene = level
	for i in 90:
		await process_frame
	dialogue.set(&"auto_advance", true)
	for i in 10:
		await process_frame
	dialogue.set(&"skip_cutscenes", false)   # (auto_advance stays on: a cutscene's lines go by at once)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(cut))
	var steps: Array = data.steps
	dialogue.cutscene_step.connect(func(i: int) -> void:
		root.get_texture().get_image().save_png("%s/step_%02d.png" % [out, i]))
	var playing := [true]
	var run := func() -> void:
		await dialogue.call(&"play_cutscene", cut)
		playing[0] = false
	run.call()
	# Mid-shot frames too (a moving shot's halfway).
	var n := 0
	while playing[0]:
		await create_timer(1.0).timeout
		root.get_texture().get_image().save_png("%s/t_%02d.png" % [out, n])
		n += 1
	print("cutscene shots: %d steps, %d timed frames in %s" % [steps.size(), n, out])
	quit()
