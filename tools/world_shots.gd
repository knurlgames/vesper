extends SceneTree
## Screenshots of a level from set views (windowed; it needs a GPU), with the frame rate and draw calls at each:
##   godot --path . -s tools/world_shots.gd -- <scene> <dir>
## Each view puts Nim somewhere and sets the camera's yaw and pitch. The age gate is skipped (in memory only).

const VIEWS := {
	"res://main.tscn": [["room", Vector3(0, 0.1, 10), 0.0, -0.3]],
	"res://levels/test_course/course.tscn": [["lanes", Vector3(35, 0.05, 10), 0.0, -0.35], ["ledges", Vector3(28, 0.05, 1), 0.3, -0.2], ["balance", Vector3(56, 3.05, 0), 0.0, -0.3], ["yard", Vector3(90, 0.05, 1), 0.0, -0.3], ["sleeper", Vector3(115, 0.05, -2), 0.0, -0.25], ["yard_shade", Vector3(126.6, 0.05, 2), 0.0, -0.2], ["yard_lamps", Vector3(133, 0.05, 2), -0.2, -0.3], ["club_street", Vector3(164, 0.05, 9), 0.0, -0.25], ["club_crowd", Vector3(161.9, 0.05, -5), 0.0, -0.3], ["gear_a", Vector3(192, 0.05, 10), 0.0, -0.3], ["gear_rope", Vector3(192, 0.05, -24), 0.0, -0.15]],
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
