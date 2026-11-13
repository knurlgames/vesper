extends SceneTree
## Screenshots of a level from set views (windowed; it needs a GPU), with the frame rate and draw calls at each:
##   godot --path . -s tools/world_shots.gd -- <scene> <dir>
## Each view puts Nim somewhere and sets the camera's yaw and pitch. The age gate is skipped (in memory only).

const VIEWS := {
	"res://main.tscn": [["room", Vector3(0, 0.1, 10), 0.0, -0.3]],
	"res://levels/test_course/course.tscn": [["lanes", Vector3(35, 0.05, 10), 0.0, -0.35], ["ledges", Vector3(28, 0.05, 1), 0.3, -0.2], ["balance", Vector3(56, 3.05, 0), 0.0, -0.3], ["yard", Vector3(90, 0.05, 1), 0.0, -0.3], ["sleeper", Vector3(115, 0.05, -2), 0.0, -0.25], ["yard_shade", Vector3(126.6, 0.05, 2), 0.0, -0.2], ["yard_lamps", Vector3(133, 0.05, 2), -0.2, -0.3], ["club_street", Vector3(164, 0.05, 9), 0.0, -0.25], ["club_crowd", Vector3(161.9, 0.05, -5), 0.0, -0.3], ["gear_a", Vector3(192, 0.05, 10), 0.0, -0.3], ["gear_rope", Vector3(192, 0.05, -24), 0.0, -0.15]],
	"res://levels/cast_stage/cast_stage.tscn": [["start", Vector3(0, 0.05, 9), 0.0, -0.25],
		["dais", Vector3(1.6, 0.05, -3.2), 0.0, -0.1], ["garbs", Vector3(-3, 0.05, -1), 0.95, -0.15],
		["suits", Vector3(3, 0.05, -1), -0.95, -0.15], ["high", Vector3(0, 0.05, 12), 0.0, -0.7],
		["enemies", Vector3(0, 0.05, 8.0), PI, -0.12], ["goon", Vector3(-7, 0.05, 11.5), 0.6, -0.15],
		["far", Vector3(0, 0.05, 17), 0.0, -0.2]],
	"res://levels/pier/pier.tscn": [
		["promenade", Vector3(0, 0.05, 26), 0.0, -0.2],
		["huts", Vector3(18, 0.05, 16), -1.2, -0.25],
		["gate", Vector3(0, 0.05, 12), 0.0, -0.1],
		["midway", Vector3(0, 0.05, -10), 0.0, -0.15],
		["crowd", Vector3(-2, 0.05, -21), 0.5, -0.15],
		["sleeper", Vector3(-1.5, 0.05, -17.5), 0.35, -0.05],
		["prom_dress", Vector3(-38, 0.05, 13), 0.2, -0.2],
		["tent", Vector3(-10.4, 0.05, -57), PI / 2.0, -0.15],
		["prizes", Vector3(-11.8, 0.05, -141.5), 0.0, 0.0],
		["striker", Vector3(4, 0.05, -36), -1.1, -0.1],
		["under", Vector3(-6, -5.95, -8), 0.0, -0.05],
		["landing", Vector3(-8, -5.95, -92), 0.4, -0.15],
		["palace", Vector3(0, 0.05, -96), 0.0, -0.1],
		["palace_in", Vector3(0, 0.05, -116), 0.2, -0.2],
		["roof", Vector3(10, 9.45, -122), 0.3, -0.35],
		["wheel", Vector3(-6, 0.05, -170), 0.6, 0.15],
		["dipper", Vector3(8, 0.05, -158), -0.5, 0.05],
		["dipper_top", Vector3(25.3, 18.05, -201), 0.9, -0.25],
		["dipper_switch", Vector3(2.8, 12.05, -226), PI * 0.9, -0.3],
		["hall", Vector3(0, 0.05, -240), 0.0, -0.05],
		["hall_in", Vector3(-8, 0.05, -262), -0.3, 0.1],
		["hall_mountain", Vector3(4, 0.05, -276), 0.15, 0.05],
	],
	"res://levels/hub/hub.tscn": [
		["square", Vector3(0, 0.05, 16), 0.0, -0.15],
		["club_door", Vector3(0, 0.05, -10), 0.0, -0.05],
		["lounge", Vector3(4, 0.05, -18), 0.6, -0.2],
		["dungeon", Vector3(-6, -1.55, -32), -1.2, -0.2],
		["seafront", Vector3(24, 0.05, 5), -PI / 2.0, -0.1],
		["pier_gate", Vector3(66, 0.05, 5), -PI / 2.0, -0.05],
		["rooftops", Vector3(48, 7.55, -6), -PI / 2.0, -0.25],
		["stub", Vector3(-8, 0.05, 14), PI, -0.05],
		["vaults_hall", Vector3(0, -4.95, -49.0), 0.0, -0.1],
		["vaults_rope", Vector3(-4.6, -4.95, -58.5), PI / 2.0, -0.15],
		["vaults_quiet", Vector3(4.6, -4.95, -51.5), -PI / 2.0, -0.15],
		["backroom", Vector3(6.0, -4.95, -71.5), 0.6, -0.3],
	],
	"res://levels/style_test/corner.tscn": [
		# [name, Nim's position, camera yaw, camera pitch]
		["start", Vector3(-10, 0.17, 12), -PI / 4.0, -0.25],
		["club_door", Vector3(10.5, 0.17, -4.0), 0.0, -0.12],
		["crossroads_low", Vector3(-2, 0.05, 2), -PI / 4.0, 0.05],
		["square", Vector3(-6.5, 0.17, 4.5), PI * 0.75, -0.3],
		["poster", Vector3(-15.6, 0.17, -5.4), 0.35, -0.05],
		["high", Vector3(-4, 0.05, 6), -PI / 4.0, -0.9],
	],
}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if args.size() > 0 else "res://levels/style_test/corner.tscn"
	var dir: String = args[1] if args.size() > 1 else "user://shots"
	DirAccess.make_dir_recursive_absolute(dir)
	await process_frame
	var game := root.get_node("/root/Game")
	game.set(&"persist", false)
	game.call(&"set_setting", "age_confirmed", true)
	game.call(&"set_flag", "hub/prologue_done")   # the hub's views, without Vesper's welcome over them
	game.call(&"set_flag", "pier/lesson_done")    # nor her lesson, which pauses the Pier mid-shots
	var hud := root.get_node("/root/Hud")
	var scene: Node = load(path).instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 30:
		await process_frame
	var nim: CharacterBody3D = scene.get(&"nim")
	var cam: Node3D = scene.get(&"cam")
	for v: Array in VIEWS.get(path, []):
		nim.global_position = v[1]
		nim.velocity = Vector3.ZERO
		nim.rotation.y = v[2]
		nim.reset_physics_interpolation()
		cam.set(&"yaw", v[2])
		cam.set(&"pitch", v[3])
		cam.global_position = v[1] + Vector3.UP * 1.3
		for i in 60:   # settle and compile shaders before timing
			await process_frame
		var t0 := Time.get_ticks_usec()
		for i in 120:
			await process_frame
		var fps := 120.0 / ((Time.get_ticks_usec() - t0) / 1000000.0)
		var calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		var prims := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		root.get_texture().get_image().save_png(dir.path_join("%s.png" % v[0]))
		print("%-16s %4.0f fps  %4d draw calls  %7d tris" % [v[0], fps, calls, prims])
	quit()
