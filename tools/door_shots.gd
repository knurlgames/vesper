extends SceneTree
## The door audit's doors, shut and then opened (windowed; it needs a GPU):
##   godot --path . -s tools/door_shots.gd -- <out_dir>      (ONLY=<view> for one)
## Each view: a scene, flags, a camera (from, look at), and optionally a node to open (found anywhere by name) and the
## method that opens it: a frame before, and one after it's swung.

const VIEWS := [
	["prize_hall", "res://levels/pier/pier.tscn", [], Vector3(3.0, 2.4, -249.5), Vector3(0, 2.2, -258.3), "HallDoors", "unlock"],
	["prize_hall_in", "res://levels/pier/pier.tscn", [], Vector3(1.6, 2.4, -265.0), Vector3(0, 2.2, -258.3), "HallDoors", "unlock"],
	["pearl_curtain", "res://levels/pier/pier.tscn", [], Vector3(-6.0, 1.9, -59.8), Vector3(-9.3, 1.3, -57.0), "", ""],
	["seafront", "res://levels/hub/hub.tscn", ["hub/prologue_done"], Vector3(26.0, 3.0, 5.0), Vector3(60.0, 3.0, 4.0), "", ""],
	["club_emblem", "res://levels/hub/hub.tscn", ["hub/prologue_done"], Vector3(1.5, 2.2, -8.5), Vector3(0, 3.4, -16.0), "", ""],
	["hall_emblem", "res://levels/hub/hub.tscn", ["hub/prologue_done"], Vector3(0.8, -3.2, -64.5), Vector3(0, -2.9, -69.5), "", ""],
	["calling_card", "res://levels/pier/pier.tscn", ["bound/pier/m_tackle"], Vector3(6.0, 2.3, -61.5), Vector3(8.2, 0.2, -64.0), "", ""],
	["nim_grille", "res://levels/hub/hub.tscn", ["hub/prologue_done"], Vector3(0.25, 1.48, -13.05), Vector3(0, 1.42, -12.5), "", ""],
	["nim_chest", "res://levels/hub/hub.tscn", ["hub/prologue_done"], Vector3(0.3, 1.2, -13.35), Vector3(0, 1.1, -12.5), "", ""],
	["fun_palace", "res://levels/pier/pier.tscn", [], Vector3(6.0, 2.2, -103.0), Vector3(0, 2.4, -111.5), "", ""],
	["office_door", "res://levels/pier/pier.tscn", [], Vector3(3.0, 1.8, -140.5), Vector3(6.0, 1.2, -144.9), "office", "_open_now"],
	["garden_door", "res://levels/primrose/primrose.tscn", [], Vector3(0.6, 1.7, -129.5), Vector3(0, 1.2, -137.0), "GardenDoor", "unlock"],
	["conservatory", "res://levels/primrose/primrose.tscn", ["primrose/party_done"], Vector3(3.5, 2.0, -152.5), Vector3(0, 1.5, -145.5), "", ""],
	["hut_door", "res://levels/primrose/primrose.tscn", [], Vector3(6.6, 1.7, -3.2), Vector3(9.55, 1.1, -1.7), "HutDoor", "open"],
	["van_doors", "res://levels/primrose/primrose.tscn", [], Vector3(-30.8, 1.9, -65.5), Vector3(-33.0, 1.3, -60.6), "VanDoors", "open"],
	["backroom_shelf", "res://levels/hub/hub.tscn", ["hub/prologue_done"], Vector3(7.6, -3.4, -74.2), Vector3(10.0, -4.0, -69.8), "", ""],
	["primrose_gate", "res://levels/hub/hub.tscn", ["hub/prologue_done"], Vector3(-6.0, 2.4, 22.0), Vector3(-8.0, 2.2, 33.0), "RankDoor_primrose", "open"],
]


func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await process_frame
	var game := root.get_node("/root/Game")
	root.get_node("/root/Dialogue").set(&"skip_cutscenes", true)
	game.set(&"persist", false)
	game.call(&"set_setting", "age_confirmed", true)
	var only := OS.get_environment("ONLY")   # a view's name, to take just that one
	for v: Array in VIEWS:
		if only != "" and v[0] != only:
			continue
		game.call(&"reset")
		for f: String in v[2] + ["visited/pier", "visited/primrose", "visited/hub"]:   # (no arrival scenes: they pause)
			game.call(&"set_flag", f)
		var level: Node = load(v[1]).instantiate()
		root.add_child(level)
		current_scene = level
		for i in 40:
			await process_frame
		var hud := root.get_node_or_null("/root/Hud") as CanvasItem
		if hud:
			hud.visible = false
		var cam := Camera3D.new()
		level.add_child(cam)
		cam.global_transform = Transform3D(Basis.IDENTITY, v[3]).looking_at(v[4], Vector3.UP)
		cam.make_current()
		for i in 10:
			await process_frame
		root.get_texture().get_image().save_png("%s/%s_a.png" % [out, v[0]])
		if v[5] != "":
			var n := level.find_child(v[5], true, false)
			if n == null:   # a shortcut is named by its id
				for s: Node in level.find_children("*", "ShortcutDoor", true, false):
					if String(s.get(&"id")) == v[5]:
						n = s
			if n and n.has_method(StringName(v[6])):
				n.callv(StringName(v[6]), [true] if v[6] in ["unlock", "_open_now"] else [])
			else:
				print("no %s.%s" % [v[5], v[6]])
			await create_timer(2.2).timeout
			root.get_texture().get_image().save_png("%s/%s_b.png" % [out, v[0]])
		if hud:
			hud.visible = true
		level.queue_free()
		await process_frame
		await process_frame
	print("door shots in %s" % out)
	quit()
