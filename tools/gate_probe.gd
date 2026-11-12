extends SceneTree
## The age gate blocks until confirmed: on a fresh machine it's up and the world is paused, the stick does nothing,
## A on the pad confirms, and then the stick moves her.
##   godot --headless --fixed-fps 60 --path . -s tools/gate_probe.gd

const In := preload("res://tools/probe_input.gd")

var fails := 0


func _initialize() -> void:
	await process_frame
	var game := root.get_node("/root/Game")
	var hud := root.get_node("/root/Hud")
	game.set(&"persist", false)
	game.call(&"forget_setting", "age_confirmed")
	var scene: Node = load("res://main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 5:
		await physics_frame
	var nim: Node3D = scene.get(&"nim")
	var gate: Node = hud.get(&"gate")
	_check(gate != null and gate.is_inside_tree(), "the gate is up on first launch")
	_check(paused, "the world is paused behind it")

	var start := nim.global_position
	In.stick(JOY_AXIS_LEFT_Y, -1.0)
	for i in 30:
		await physics_frame
	_check(nim.global_position.distance_to(start) < 0.05, "the stick doesn't move her behind the gate")

	In.stick(JOY_AXIS_LEFT_Y, 0.0)   # let go, so the stick doesn't steer the gate's buttons
	await process_frame
	In.button(JOY_BUTTON_A, true)
	await process_frame
	In.button(JOY_BUTTON_A, false)
	for i in 3:
		await process_frame
	_check(not is_instance_valid(gate) or not gate.is_inside_tree(), "A on the pad closes the gate")
	_check(not paused, "the world runs again")
	_check(game.call(&"get_setting", "age_confirmed", false) == true, "the answer is remembered")

	start = nim.global_position
	In.stick(JOY_AXIS_LEFT_Y, -1.0)
	for i in 60:
		await physics_frame
	In.stick(JOY_AXIS_LEFT_Y, 0.0)
	var moved := nim.global_position.distance_to(start)
	_check(moved > 3.0, "then the stick moves her (%.1f m in 1 s)" % moved)

	# A second scene load doesn't ask again.
	scene.queue_free()
	await process_frame
	var again: Node = load("res://main.tscn").instantiate()
	root.add_child(again)
	for i in 3:
		await process_frame
	_check(hud.get(&"gate") == null or not is_instance_valid(hud.get(&"gate")), "it isn't asked twice")

	print("gate probe: %d failures" % fails)
	quit(1 if fails else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
