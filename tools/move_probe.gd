extends SceneTree
## The greybox capsule moves on the pad and on the keyboard: the stick and WASD run her the way the camera looks, A and
## Space jump, B and C slow her to a sneak, the right stick turns the camera, Start and Esc pause.
##   godot --headless --fixed-fps 60 --path . -s tools/move_probe.gd

const In := preload("res://tools/probe_input.gd")
const SPAWN := Vector3(0, 0.1, 10)

var fails := 0
var nim: CharacterBody3D
var cam: Node3D


func _initialize() -> void:
	await process_frame
	var game := root.get_node("/root/Game")
	game.set(&"persist", false)
	game.call(&"set_setting", "age_confirmed", true)
	var scene: Node = load("res://main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 5:
		await physics_frame
	nim = scene.get(&"nim")
	cam = scene.get(&"cam")

	# Run: up on the stick or W goes where the camera looks, at any camera angle.
	for yaw: float in [0.0, PI / 2.0, -2.3]:
		await _run("stick up", yaw, func(on: bool) -> void: In.stick(JOY_AXIS_LEFT_Y, -1.0 if on else 0.0))
		await _run("W", yaw, func(on: bool) -> void: In.key(KEY_W, on))
	await _run("stick right", 0.0, func(on: bool) -> void: In.stick(JOY_AXIS_LEFT_X, 1.0 if on else 0.0), Vector3.RIGHT)
	await _run("D", 0.0, func(on: bool) -> void: In.key(KEY_D, on), Vector3.RIGHT)

	# Jump.
	await _jump("A", func(on: bool) -> void: In.button(JOY_BUTTON_A, on))
	await _jump("Space", func(on: bool) -> void: In.key(KEY_SPACE, on))

	# Sneak: slower than a run.
	var run := await _distance(func(on: bool) -> void: In.stick(JOY_AXIS_LEFT_Y, -1.0 if on else 0.0))
	In.button(JOY_BUTTON_B, true)
	var sneak := await _distance(func(on: bool) -> void: In.stick(JOY_AXIS_LEFT_Y, -1.0 if on else 0.0))
	In.button(JOY_BUTTON_B, false)
	_check(sneak < run * 0.6, "B sneaks (%.1f m against %.1f running)" % [sneak, run])
	In.key(KEY_C, true)
	sneak = await _distance(func(on: bool) -> void: In.key(KEY_W, on))
	In.key(KEY_C, false)
	_check(sneak < run * 0.6, "C sneaks (%.1f m)" % sneak)

	# Camera: the right stick and the arrow keys turn it.
	for name: String in ["right stick", "right arrow"]:
		var before: float = cam.get(&"yaw")
		if name == "right stick":
			In.stick(JOY_AXIS_RIGHT_X, 1.0)
		else:
			In.key(KEY_RIGHT, true)
		for i in 30:
			await process_frame
		In.stick(JOY_AXIS_RIGHT_X, 0.0)
		In.key(KEY_RIGHT, false)
		var turned := absf(angle_difference(before, cam.get(&"yaw")))
		_check(turned > 0.3, "%s turns the camera (%.2f rad)" % [name, turned])

	# Pause: Start and Esc, each on and off.
	for p: Array in [["Start", func(on: bool) -> void: In.button(JOY_BUTTON_START, on)],
			["Esc", func(on: bool) -> void: In.key(KEY_ESCAPE, on)]]:
		await _tap(p[1])
		_check(paused, "%s pauses" % p[0])
		await _tap(p[1])
		_check(not paused, "%s resumes" % p[0])

	# Every action the design names has a pad binding and a key or mouse binding.
	for action: StringName in root.get_node("/root/Controls").get(&"ACTIONS"):
		var pad := false
		var keys := false
		for e in InputMap.action_get_events(action):
			pad = pad or e is InputEventJoypadButton or e is InputEventJoypadMotion
			keys = keys or e is InputEventKey or e is InputEventMouseButton
		if not (pad and keys):
			_check(false, "%s is bound on pad and keys" % action)
	print("move probe: %d failures" % fails)
	quit(1 if fails else 0)


func _place(yaw: float) -> void:
	nim.global_position = SPAWN
	nim.velocity = Vector3.ZERO
	cam.set(&"yaw", yaw)
	# She's placed just above the floor: wait until she's on it, or a jump press finds her in the air.
	for i in 30:
		await physics_frame
		if nim.is_on_floor():
			break


## Holds an input for a second and checks she ran at least 4 m, the way `want` is (the camera's forward by default).
func _run(name: String, yaw: float, hold: Callable, want := Vector3.ZERO) -> void:
	await _place(yaw)
	var start := nim.global_position
	hold.call(true)
	for i in 60:
		await physics_frame
	hold.call(false)
	var d := nim.global_position - start
	d.y = 0.0
	var dir: Vector3 = cam.call(&"forward") if want == Vector3.ZERO else want
	var along := d.dot(dir)
	_check(along > 4.0 and d.length() - along < 0.5, "%s runs her the right way at yaw %.1f (%.1f m)" % [name, yaw, along])


func _jump(name: String, press: Callable) -> void:
	await _place(0.0)
	var floor_y := nim.global_position.y
	var top := floor_y
	await _tap(press)
	for i in 40:
		await physics_frame
		top = maxf(top, nim.global_position.y)
	_check(top - floor_y > 0.5, "%s jumps (a tap is a hop: %.2f m high)" % [name, top - floor_y])


func _distance(hold: Callable) -> float:
	await _place(0.0)
	var start := nim.global_position
	hold.call(true)
	for i in 30:
		await physics_frame
	hold.call(false)
	return nim.global_position.distance_to(start)


func _tap(press: Callable) -> void:
	press.call(true)
	await physics_frame
	await process_frame
	press.call(false)
	await physics_frame
	await process_frame


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
