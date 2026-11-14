extends SceneTree
## Close-ups of Nim's model on its own, lit (windowed; it needs a GPU): her muzzle's grille and her chest harness's
## medallion, front and three-quarter, for checking what's painted on them (tools/nim_emblem.gd):
##   godot --path . -s tools/nim_closeups.gd -- <out_dir> [garb|swim]

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]
	var outfit: String = a[1] if a.size() > 1 else "garb"
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(900, 900))
	await process_frame
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("50505a")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("c8c0d0")
	env.environment.ambient_light_energy = 0.6
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-35), deg_to_rad(25), 0)
	sun.light_energy = 1.3
	world.add_child(sun)
	# Her real model (player/nim_model.gd: the dressing, the mask, the emblems), on a stand-in for Nim, turned to face
	# +Z like the GLB so the shots below line up.
	var holder := Node3D.new()
	holder.rotation.y = PI
	world.add_child(holder)
	var model := Node3D.new()
	model.set_script(load("res://player/nim_model.gd"))
	holder.add_child(model)
	await process_frame
	if outfit == "swim":
		model.call(&"wear_swim", true)
	for i in 10:
		await process_frame
	var cam := Camera3D.new()
	cam.fov = 30.0
	world.add_child(cam)
	cam.make_current()
	# The GLB faces +Z.
	var shots := {
		"grille_front": [Vector3(0, 1.47, 0.85), Vector3(0, 1.45, 0.3)],
		"grille_three": [Vector3(0.45, 1.55, 0.75), Vector3(0, 1.45, 0.32)],
		"medallion_front": [Vector3(0, 1.15, 0.95), Vector3(0, 1.12, 0.3)],
		"body": [Vector3(0.6, 1.3, 2.6), Vector3(0, 1.15, 0)],
	}
	for k: String in shots:
		cam.global_transform = Transform3D(Basis.IDENTITY, shots[k][0]).looking_at(shots[k][1], Vector3.UP)
		for i in 6:
			await process_frame
		root.get_texture().get_image().save_png("%s/%s_%s.png" % [out, outfit, k])
	print("closeups in %s" % out)
	quit()
