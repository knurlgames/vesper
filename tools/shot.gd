extends SceneTree
## Screenshots of the test room (windowed; it needs a GPU):
##   godot --path . -s tools/shot.gd -- <dir>
## Writes <dir>/gate.png (the age gate on first launch) and <dir>/room.png (the room behind it, confirmed).

const In := preload("res://tools/probe_input.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0] if args.size() > 0 else "user://shots"
	DirAccess.make_dir_recursive_absolute(dir)
	await process_frame
	var game := root.get_node("/root/Game")
	game.set(&"persist", false)
	game.call(&"forget_setting", "age_confirmed")
	var scene: Node = load("res://main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 20:
		await process_frame
	root.get_texture().get_image().save_png(dir.path_join("gate.png"))
	In.button(JOY_BUTTON_A, true)
	await process_frame
	In.button(JOY_BUTTON_A, false)
	for i in 30:
		await process_frame
	root.get_texture().get_image().save_png(dir.path_join("room.png"))
	print("shots in ", dir)
	quit()
