extends SceneTree
## A screenshot of the pause screen over the probe world, after picking up a Key, three contraband and the tin
## (windowed; it needs a GPU):  godot --path . -s tools/pause_shot.gd -- <out.png>

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://pause.png"
	await process_frame
	var game := root.get_node("/root/Game")
	game.set(&"persist", false)
	game.call(&"set_setting", "age_confirmed", true)
	game.call(&"reset")
	var world: Node = load("res://levels/probe_world/probe_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in 10:
		await process_frame
	game.call(&"collect", &"key", &"probe", &"probe_01")
	for i in 3:
		game.call(&"collect", &"contraband", &"probe", StringName("c%d" % i))
	game.call(&"collect", &"tin", &"pier", &"tin")
	game.call(&"collect", &"contraband", &"pier", &"c1")
	root.get_node("/root/Hud").call(&"set_paused", true)
	for i in 20:
		await process_frame
	root.get_texture().get_image().save_png(out)
	print("pause shot: ", out)
	quit()
