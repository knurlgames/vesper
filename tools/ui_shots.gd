extends SceneTree
## WO-010's UI screenshot probe (windowed; it needs a GPU): every screen, saved as a PNG.
##   godot --path . -s tools/ui_shots.gd -- <dir>
## title_press, title_files, title_extras, title_content, settings_controls, settings_camera, settings_display,
## settings_access, hud_garb, hud_suit, arrival, pause, pause_controls, paper.

var dir := ""
var game: Node
var hud: Node


func _initialize() -> void:
	dir = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://ui_shots"
	DirAccess.make_dir_recursive_absolute(dir)
	await process_frame
	game = root.get_node("/root/Game")
	hud = root.get_node("/root/Hud")
	game.set(&"persist", false)
	game.call(&"set_setting", "age_confirmed", true)
	game.call(&"reset")
	var title: Node = load("res://levels/title/title.tscn").instantiate()
	root.add_child(title)
	current_scene = title
	await shot("title_press", 40)
	title.call(&"show_files")
	await shot("title_files", 60)
	title.call(&"show_extras")
	await shot("title_extras")
	title.call(&"show_content")
	await shot("title_content")
	title.call(&"_back_to_files")
	var menu: SettingsMenu = hud.call(&"open_settings")
	for i in 4:
		menu.show_page(i)
		await shot(["settings_controls", "settings_camera", "settings_display", "settings_access"][i])
	menu.close()
	title.queue_free()
	var course: Node = load("res://levels/test_course/course.tscn").instantiate()
	root.add_child(course)
	current_scene = course
	await shot("arrival", 20)
	var nim: Node3D = course.get(&"nim")
	nim.call(&"teleport", course.get_node("Dash_k").global_position + Vector3(0, 0.05, 1.6), 0.0)
	await shot("hud_garb", 150)
	nim.get(&"suit").call(&"set_outfit", 1)
	nim.get(&"suit").set(&"composure", 0.6)
	nim.get(&"suit").emit_signal(&"composure_changed", 0.6, false, 1)
	hud.call(&"caption", "Staff", "Yes, Mistress.")
	await shot("hud_suit")
	hud.call(&"set_paused", true)
	await shot("pause")
	hud.call(&"_show_pause_help", true)
	await shot("pause_controls")
	hud.call(&"set_paused", false)
	var world: Node = load("res://levels/probe_world/probe_world.tscn").instantiate()
	course.queue_free()
	root.add_child(world)
	current_scene = world
	await shot("probe_world", 40)
	world.call(&"complete", false)
	await shot("paper", 20)
	print("ui shots in ", dir)
	quit()


func shot(name: String, wait := 15) -> void:
	for i in wait:
		await process_frame
	root.get_texture().get_image().save_png(dir.path_join(name + ".png"))
