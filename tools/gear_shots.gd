extends SceneTree
## The cross's gear on bodies, close up (windowed; it needs a GPU): for each body, held in the X, wrist and ankle
## cuffs, a collar and a tape (or ball) gag fitted as the cross fits them, shot from the front and the side:
##   godot --path . -s tools/gear_shots.gd -- <dir> [gag]
## Bodies: the clients' swimwear bodies, and Nim in her two-piece.

const BODIES := ["hedgehog_swim", "hare_swim", "fox_swim", "otter_swim", "laffer", "gander"]


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0] if a.size() > 0 else "res://.wip/gear"
	var gag: String = a[1] if a.size() > 1 else "tape"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	DisplayServer.window_set_size(Vector2i(900, 900))
	await process_frame
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.45, 0.43, 0.42)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.7, 0.4, 0)
	world.add_child(sun)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.current = true
	for b: String in BODIES + ["nim"]:
		var holder := Node3D.new()
		world.add_child(holder)
		var model: Node3D
		if b == "nim":
			model = load("res://player/nim_model.gd").new()
			holder.add_child(model)
			for i in 10:
				await process_frame
			model.call(&"wear_swim", true)
		else:
			var em := EnemyModel.new()
			em.body = b
			holder.add_child(em)
			model = em
		for i in 10:
			await process_frame
		model.call(&"hold", true)
		var sk: Skeleton3D = model.call(&"skeleton")
		if sk == null:
			print("no skeleton: ", b)
			holder.queue_free()
			continue
		var rig := RigGear.new(sk, holder)
		rig.pose_x()
		for limb: String in ["forearm", "shin"]:
			var tip := "hand" if limb == "forearm" else "foot"
			var ln := (rig.pos(tip + "L") - rig.pos(limb + "L")).length()
			var gs: Array[String] = []
			for k: float in [0.62, 0.72, 0.8, 0.88]:
				gs.append("%.3f" % rig.girth(limb + "L", ln * k, 0.0))
			print("girth %s %s: %s (length %.3f)" % [b, limb, ", ".join(gs), ln])
		for s in ["L", "R"]:
			rig.cuff("wrist" + s, RigGear.LEATHER)
			rig.cuff("ankle" + s, RigGear.LEATHER)
		var head := rig.head_frame()
		var up_neck := (rig.pos("head") - rig.pos("neck")).length() * 0.5
		rig.band("neck", head.neck_r, Color("2a0e18"), true, up_neck)
		rig.gag(gag)
		for i in 3:
			await process_frame
		var face: Vector3 = head.mid
		var fw: Vector3 = head.fwd
		var sd := Vector3.UP.cross(fw).normalized()
		for view: Array in [["front", fw], ["side", (sd + fw * 0.35).normalized()]]:
			cam.global_position = face + (view[1] as Vector3) * 0.9 + Vector3.UP * 0.05
			cam.look_at(face, Vector3.UP)
			for i in 3:
				await process_frame
			root.get_texture().get_image().save_png("%s/%s_%s_%s.png" % [out, b, gag, view[0]])
		var wrist := rig.pos("handL")
		cam.global_position = wrist + fw * 0.55
		cam.look_at(wrist, Vector3.UP)
		for i in 3:
			await process_frame
		root.get_texture().get_image().save_png("%s/%s_wrist.png" % [out, b])
		var foot := (rig.pos("footL") + rig.pos("footR")) / 2.0
		cam.global_position = foot + fw * 1.0 + sd * 0.5 + Vector3.UP * 0.35
		cam.look_at(foot + Vector3.UP * 0.1, Vector3.UP)
		for i in 3:
			await process_frame
		root.get_texture().get_image().save_png("%s/%s_ankles.png" % [out, b])
		print("gear shots: ", b)
		holder.queue_free()
		await process_frame
	quit()
