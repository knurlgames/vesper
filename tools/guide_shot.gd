extends SceneTree
## The guide in play (owner's playtest, 2026-11-13: "Need a guide or arrow to assist with story progression"), and the
## club's front door swinging open (windowed; it needs a GPU):  godot --path . -s tools/guide_shot.gd -- <out_dir>
## Shots: hub_start.png (the guest to wake), hub_door.png (Nim at the club's door), pier_start.png (the lesson).

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://guide"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	DisplayServer.window_set_size(Vector2i(1280, 800))
	await process_frame
	var game := root.get_node("/root/Game")
	game.set(&"persist", false)
	game.call(&"set_setting", "age_confirmed", true)
	game.call(&"reset")
	game.call(&"set_flag", "hub/prologue_done")
	var hub: Node = load("res://levels/hub/hub.tscn").instantiate()
	root.add_child(hub)
	current_scene = hub
	for i in 60:
		await process_frame
	_save(out + "/hub_start.png")
	var nim := hub.get(&"nim") as Node3D
	var door := hub.find_child("ClubDoor", true, false) as Node3D
	if nim and door:
		nim.global_position = door.global_position + Vector3(1.0, 0.1, 2.2)
		nim.look_at(door.global_position + Vector3(1.0, 1.0, 0), Vector3.UP)
		for i in 90:
			await process_frame
		_save(out + "/hub_door.png")
	else:
		print("no nim or door: ", nim, door)
	# The vaults with every sister away: the dark workshop, "OUT ON BUSINESS", Rivet's drop box.
	if nim:
		nim.global_position = Vector3(2.0, -4.95, -64.6)
		nim.look_at(Vector3(9.0, -4.95, -64.0), Vector3.UP)
		for i in 90:
			await process_frame
		_save(out + "/vaults_away.png")
	hub.queue_free()
	await process_frame
	var pier: Node = load("res://levels/pier/pier.tscn").instantiate()
	root.add_child(pier)
	current_scene = pier
	for i in 60:
		await process_frame
	_save(out + "/pier_start.png")
	quit()


func _save(path: String) -> void:
	root.get_texture().get_image().save_png(path)
	print("guide shot: ", path)
