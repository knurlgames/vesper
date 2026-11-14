extends SceneTree
## Out of bounds in the Velvet Rope (owner, Deck review 4: "clip out of bounds jumping up in the Velvet Rope": a jump
## by the lounge's wall caught the ceiling's top as a ledge and pulled her up onto it). With real input, Nim jumps at
## every wall of the lounge, the dungeon and the vaults, every few metres, and off the furniture, pushing on into the
## wall the whole time (the grab, the pull-up). She must end every try under the ceiling she started under.
##   godot --headless --fixed-fps 60 --path . -s tools/bounds_probe.gd

const Driver := preload("res://tools/probe_driver.gd")

var d: Driver


func _initialize() -> void:
	await process_frame
	var game := root.get_node("/root/Game")
	game.set(&"persist", false)
	game.call(&"set_setting", "age_confirmed", true)
	game.call(&"reset")
	game.call(&"set_flag", "hub/prologue_done")
	var hub: Node = load("res://levels/hub/hub.tscn").instantiate()
	root.add_child(hub)
	current_scene = hub
	await physics_frame
	await physics_frame
	d = Driver.new(self, hub.get(&"nim"), hub.get(&"cam"))
	hub.get_node("ClubLife").process_mode = Node.PROCESS_MODE_DISABLED   # no crowd in the way
	# [where she stands, the way she pushes, the ceiling's underside above her]
	var tries: Array = []
	# The lounge (floor 0, ceiling 4.5): its walls, from inside.
	for x in range(-9, 10, 2):
		tries.append([Vector3(x, 0.1, -17.0), Vector3(0, 0, 1), 4.5])
		tries.append([Vector3(x, 0.1, -29.6), Vector3(0, 0, -1), 4.5])
	for z in range(-28, -17, 2):
		tries.append([Vector3(-10.0, 0.1, z), Vector3(-1, 0, 0), 4.5])
		tries.append([Vector3(10.0, 0.1, z), Vector3(1, 0, 0), 4.5])
	# Off the furniture: the bar, the sofas' seats and the low tables, at the walls behind them.
	for p: Vector3 in [Vector3(-9.6, 1.2, -20.0), Vector3(-9.6, 1.2, -27.0), Vector3(-4.0, 0.6, -21.0),
			Vector3(3.5, 0.6, -22.0), Vector3(-4.5, 0.6, -27.5), Vector3(-4.0, 0.6, -19.5)]:
		for dir: Vector3 in [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
			tries.append([p, dir, 4.5])
	# The dungeon (floor -1.6, ceiling 4.5).
	for x in range(-9, 10, 3):
		tries.append([Vector3(x, -1.5, -36.9), Vector3(0, 0, -1), 4.5])
		tries.append([Vector3(x, -1.5, -31.0), Vector3(0, 0, 1), 4.5])
	# The vaults (floor -5, ceiling -1.5): the hall and every room.
	for z in range(-50, -69, 3):
		tries.append([Vector3(-3.4, -4.9, z), Vector3(-1, 0, 0), -1.5])
		tries.append([Vector3(3.4, -4.9, z), Vector3(1, 0, 0), -1.5])
	for r: Array in [[-8.0, -51.5], [-8.0, -58.5], [-8.0, -65.5], [12.0, -51.5], [8.0, -58.5], [8.0, -65.5]]:
		for dir: Vector3 in [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
			tries.append([Vector3(r[0], -4.9, r[1]), dir, -1.5])
	var bad: Array = []
	for t: Array in tries:
		var at: Vector3 = t[0]
		var dir: Vector3 = t[1]
		await d.place(at, atan2(-dir.x, -dir.z))
		await d.frames(2)
		d.steer(dir)
		d.button(JOY_BUTTON_A, true)
		await d.secs(0.45)
		d.button(JOY_BUTTON_A, false)
		await d.secs(0.5)
		await d.tap(JOY_BUTTON_A)   # pull up, if she's hanging
		await d.secs(1.2)
		d.release_all()
		var y: float = d.nim.global_position.y
		if y > float(t[2]) - 0.5:
			bad.append("from %s pushing %s: ended at %s" % [at, dir, d.nim.global_position.snapped(Vector3.ONE * 0.01)])
	d.check(bad.is_empty(), "%d jumps at the club's walls and furniture: never up onto or through a ceiling%s" % [
		tries.size(), "" if bad.is_empty() else "\n      " + "\n      ".join(bad)])
	print("bounds probe: %d failures" % d.fails)
	quit(1 if d.fails else 0)
