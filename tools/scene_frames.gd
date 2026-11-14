extends SceneTree
## Loads a scene with some flags set and films whatever cutscenes it plays by itself (a frame at each step, and one a
## second), for those built in code (a sister's homecoming sting, hub.gd _sting) (windowed; it needs a GPU):
##   godot --path . -s tools/scene_frames.gd -- <scene.tscn> <out_dir> <seconds> [flag | key=<world>/<id> ...]
## (a gate opening: key=hub/hub_10 hub/prologue_done; Swyne's cutaway: done/pier hub/prologue_done)

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[1]
	var secs := float(a[2])
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await process_frame
	var game := root.get_node("/root/Game")
	var dialogue := root.get_node("/root/Dialogue")
	game.set(&"persist", false)
	dialogue.set(&"auto_advance", OS.get_environment("FRAMES_TAP") != "")   # tap through the lines
	game.call(&"set_setting", "age_confirmed", true)
	game.call(&"reset")
	for f in a.slice(3):
		if f.begins_with("key="):
			var k := f.trim_prefix("key=").split("/")
			game.call(&"collect", &"key", StringName(k[0]), StringName(k[1]))
		else:
			game.call(&"set_flag", f)
	var n := [0]
	dialogue.cutscene_step.connect(func(i: int) -> void:
		n[0] += 1
		root.get_texture().get_image().save_png("%s/s%02d_step%02d.png" % [out, n[0], i]))
	var level: Node = load(a[0]).instantiate()
	root.add_child(level)
	current_scene = level
	var t := 0.0
	var k := 0
	while t < secs:
		await create_timer(1.0).timeout
		t += 1.0
		root.get_texture().get_image().save_png("%s/t%02d.png" % [out, k])
		k += 1
	print("scene frames: %d steps, %d timed in %s" % [n[0], k, out])
	quit()
