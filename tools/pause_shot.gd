extends SceneTree
## Screenshots of the pause screen over the Pier, with some of the Pier's and the hub's tallies collected: the pause
## screen (the world's name, the area, the tallies in its corners), then each Level Totals page (windowed; it needs
## a GPU):  godot --path . -s tools/pause_shot.gd -- <out_dir>
## Shots: pause.png, totals_<n>.png.

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://pause"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	DisplayServer.window_set_size(Vector2i(1280, 800))
	await process_frame
	var game := root.get_node("/root/Game")
	game.set(&"persist", false)
	game.call(&"set_setting", "age_confirmed", true)
	game.call(&"reset")
	game.call(&"set_flag", "hub/prologue_done")
	game.call(&"set_flag", "visited/hub")
	for i in 7:
		game.call(&"collect", &"key", &"hub", StringName("hub_%02d" % (i + 1)))
	game.call(&"collect", &"freed", &"hub", &"guest")
	for i in 4:
		game.call(&"collect", &"key", &"pier", StringName("pier_%02d" % (i + 1)))
	for i in 37:
		game.call(&"collect", &"contraband", &"pier", StringName("c%d" % i))
	game.call(&"collect", &"freed", &"pier", &"s1")
	game.call(&"collect", &"freed", &"pier", &"s2")
	game.call(&"collect", &"tin", &"pier", &"tin")
	var world: Node = load("res://levels/pier/pier.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in 30:
		await process_frame
	var hud := root.get_node("/root/Hud")
	hud.call(&"zone", "The Boardwalk")
	hud.call(&"set_paused", true)
	for i in 20:
		await process_frame
	_save(out + "/pause.png")
	hud.call(&"show_totals", true)
	var totals: Node = hud.get(&"_totals")
	for p in int(totals.call(&"page_count")):
		totals.call(&"show_page", p)
		for i in 6:
			await process_frame
		_save(out + "/totals_%d.png" % p)
	quit()


func _save(path: String) -> void:
	root.get_texture().get_image().save_png(path)
	print("pause shot: ", path)
