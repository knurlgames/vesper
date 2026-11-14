extends SceneTree
## Grabbing a beam and pulling up onto it (owner, Deck review 4: "you cannot climb up on the small beams if you grab
## one", at the Big Dipper's catwalk). With real input, Nim drops beside a catwalk beam from either side, catches its
## edge, and A pulls her up: she must end on the beam, balancing, not fallen past it.
##   godot --headless --fixed-fps 60 --path . -s tools/beam_probe.gd

const Driver := preload("res://tools/probe_driver.gd")


func _initialize() -> void:
	await process_frame
	var game := root.get_node("/root/Game")
	game.set(&"persist", false)
	game.call(&"set_setting", "age_confirmed", true)
	game.call(&"reset")
	var pier: Node = load("res://levels/pier/pier.tscn").instantiate()
	root.add_child(pier)
	current_scene = pier
	await physics_frame
	await physics_frame
	var d := Driver.new(self, pier.get(&"nim"), pier.get(&"cam"))
	# The catwalk's level beam (dipper.gd: (24, 18, -205) to (17.5, 18, -205), 0.25 wide), from the south and the
	# north side, and a sloping one (13.2, 15.5, -211) to (7, 13, -219.6).
	var tries := [[Vector3(20.75, 18.0, -205.0), Vector3(0, 0, 1)], [Vector3(20.75, 18.0, -205.0), Vector3(0, 0, -1)],
		[Vector3(10.1, 14.25, -215.3), Vector3(0.81, 0, -0.58)]]
	for t: Array in tries:
		var top: Vector3 = t[0]
		var side: Vector3 = t[1]
		# Just off its side, her hands at its height, dropping; pushing in toward it.
		d.release_all()
		d.nim.teleport(top + side * 0.72 + Vector3.DOWN * 1.42, atan2(side.x, side.z))
		d.cam.set(&"yaw", atan2(side.x, side.z))
		d.steer(-side)
		var hung := false
		for i in 30:
			await d.frames(1)
			hung = hung or int(d.nim.get(&"state")) == 3   # State.HANG (pushing on, she pulls up by herself)
		await d.tap(JOY_BUTTON_A)
		await d.secs(1.0)
		d.release_all()
		await d.secs(0.5)
		var p: Vector3 = d.nim.global_position
		var off := Vector3(p.x - top.x, 0, p.z - top.z)
		off -= side * 0.0
		var on := absf(p.y - top.y) < 0.15 and absf(off.dot(side)) < 0.2
		d.check(hung and on, "caught the beam's edge from %s and pulled up onto it (hung %s, at %s, state %s)" % [
			side, hung, p.snapped(Vector3.ONE * 0.01), d.nim.get(&"state")])
	print("beam probe: %d failures" % d.fails)
	quit(1 if d.fails else 0)
