extends SceneTree
## The prologue as a new game plays it, cutscenes and all (the lines advance themselves), a frame every 0.75 s until
## the guest's in the dungeon (windowed; it needs a GPU):  godot --path . -s tools/prologue_frames.gd -- <out_dir>

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await process_frame
	var game := root.get_node("/root/Game")
	var dialogue := root.get_node("/root/Dialogue")
	game.set(&"persist", false)
	game.call(&"set_setting", "age_confirmed", true)
	game.call(&"reset")
	dialogue.set(&"auto_advance", true)
	var hub: Node = load("res://levels/hub/hub.tscn").instantiate()
	root.add_child(hub)
	current_scene = hub
	var n := 0
	var t := 0.0
	while t < 42.0:
		await create_timer(0.75).timeout
		t += 0.75
		root.get_texture().get_image().save_png("%s/f_%02d.png" % [out, n])
		n += 1
		if hub.get_node_or_null("Prologue") and int(hub.get_node("Prologue").get(&"stage")) >= 1 and not dialogue.call(&"is_active"):
			break
	print("prologue frames: %d in %s" % [n, out])
	quit()
