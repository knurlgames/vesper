extends SceneTree
## Nim on the test course, on foot, with real input: every gap (A), every height (B), the beam and the wire (E), the
## crawlway and the pounce gap (F), plus coyote time, the jump buffer, the short hop and the pounce's speed.
##   godot --headless --fixed-fps 60 --path . -s tools/walk_probe.gd

const Driver := preload("res://tools/probe_driver.gd")

var d: Driver
var course: Node


func _initialize() -> void:
	await process_frame
	var game := root.get_node("/root/Game")
	game.set(&"persist", false)
	game.call(&"set_setting", "age_confirmed", true)
	course = load("res://levels/test_course/course.tscn").instantiate()
	root.add_child(course)
	current_scene = course
	await physics_frame
	d = Driver.new(self, course.get(&"nim"), course.get(&"cam"))
	await _gaps()
	await _jump_feel()
	await _heights()
	await _balance()
	await _crawl()
	await _pounce_gap()
	print("walk probe: %d failures" % d.fails)
	quit(1 if d.fails else 0)


func _start(lane: StringName) -> Vector3:
	return course.call(&"start", lane)


## A: run, and jump at each edge (edges at z -10, -16.5 and -24).
func _gaps() -> void:
	await d.place(_start(&"A"))
	d.stick(0, -1)
	for edge: float in [-10.0, -16.5, -24.0]:
		await d.until(func() -> bool: return d.nim.global_position.z <= edge + 0.4, 6.0)
		await d.jump()
	await d.until(func() -> bool: return d.nim.global_position.z < -31.0, 4.0)
	d.stick(0, 0)
	var p := d.nim.global_position
	d.check(p.z < -31.0 and p.y > -0.1, "A: the 2.5, 3.5 and 4.2 m gaps %s" % d.at())


func _jump_feel() -> void:
	# Height: a held jump tops out at about 2.2 m, a tap at well under it.
	for hold: float in [0.4, 0.05]:
		await d.place(_start(&"A"))
		var top := 0.0
		var y0 := d.nim.global_position.y
		d.button(JOY_BUTTON_A, true)
		for i in 60:
			await physics_frame
			top = maxf(top, d.nim.global_position.y - y0)
			if i == int(hold * 60.0):
				d.button(JOY_BUTTON_A, false)
		d.button(JOY_BUTTON_A, false)
		if hold > 0.1:
			d.check(absf(top - 2.2) < 0.15, "a held jump is 2.2 m high (%.2f)" % top)
		else:
			d.check(top < 1.4, "a tapped jump is a hop (%.2f m)" % top)

	# Coyote time: off the edge, then A 3 frames (50 ms) later, still jumps.
	await d.place(Vector3(0, 0.05, -7.0))
	d.stick(0, -1)
	await d.until(func() -> bool: return not d.nim.is_on_floor(), 2.0)
	await d.frames(3)
	d.button(JOY_BUTTON_A, true)
	await d.frames(2)
	var vy := d.nim.velocity.y
	d.button(JOY_BUTTON_A, false)
	d.stick(0, 0)
	d.check(vy > 8.0, "coyote: A 50 ms after leaving the edge still jumps (vy %.1f)" % vy)

	# The buffer: A pressed just before landing jumps on landing.
	await d.place(_start(&"A"))
	await d.jump()
	await d.until(func() -> bool: return d.nim.velocity.y < 0.0 and d.nim.global_position.y < 0.5, 2.0)
	d.button(JOY_BUTTON_A, true)
	var rose := await d.until(func() -> bool: return d.nim.velocity.y > 8.0, 0.3)
	d.button(JOY_BUTTON_A, false)
	d.check(rose, "buffer: A just before landing jumps again on landing")

	# The pounce: 9 m/s.
	await d.place(_start(&"A"))
	d.stick(0, -1)
	await d.secs(0.4)
	await d.pounce()
	var v := Vector3(d.nim.velocity.x, 0, d.nim.velocity.z).length()
	d.stick(0, 0)
	d.check(absf(v - 9.0) < 0.2, "the pounce runs at 9 m/s (%.2f)" % v)


## B: up onto blocks 1.0, 1.6 and 2.0 m high (faces at z -6, -14, -22), over each and down.
func _heights() -> void:
	await d.place(_start(&"B"))
	d.stick(0, -1)
	for face: float in [-6.0, -14.0, -22.0]:
		await d.until(func() -> bool: return d.nim.global_position.z <= face + 1.6, 6.0)
		await d.jump()
	await d.until(func() -> bool: return d.nim.global_position.z < -28.0, 8.0)
	d.stick(0, 0)
	var p := d.nim.global_position
	d.check(p.z < -28.0 and absf(p.y) < 0.1, "B: over the 1.0, 1.6 and 2.0 m blocks %s" % d.at())


## E: the beam, a platform, the wire, the far platform. Slow on them, and never off.
func _balance() -> void:
	await d.place(_start(&"E"))
	d.stick(0, -1)
	var fastest := 0.0
	var balanced := 0
	var lowest := 99.0
	for i in 15 * 60:
		await physics_frame
		lowest = minf(lowest, d.nim.global_position.y)
		if d.nim.state == Nim.State.BALANCE:
			balanced += 1
			fastest = maxf(fastest, Vector3(d.nim.velocity.x, 0, d.nim.velocity.z).length())
		if d.nim.global_position.z < -25.0:
			break
	d.stick(0, 0)
	d.check(d.nim.global_position.z < -25.0 and lowest > 2.9, "E: across the beam and the wire without falling %s" % d.at())
	d.check(balanced > 60 * 5 and fastest < 2.1, "E: balancing on them, at 2 m/s (%.1f s, top %.2f m/s)" % [balanced / 60.0, fastest])
	# A beam's sideways: push across it and she stays on.
	await d.place(Vector3(56, 3.05, -6.0))
	d.stick(1, 0)
	await d.secs(1.0)
	d.stick(0, 0)
	await d.secs(0.3)
	d.check(d.nim.global_position.y > 2.9, "E: pushing sideways on the beam doesn't tip her off %s" % d.at())
	# The magnet: dropped just off the wire's line, she lands on it.
	await d.place(Vector3(56.3, 3.6, -19.0))
	await d.secs(0.6)
	d.check(d.nim.global_position.y > 2.9 and d.nim.state == Nim.State.BALANCE, "E: falling near the wire catches it %s" % d.at())


## F: the crawlway is 1.1 m high: blocked standing, through crouched.
func _crawl() -> void:
	await d.place(_start(&"F"))
	d.stick(0, -1)
	await d.secs(1.5)
	d.check(d.nim.global_position.z > -4.0, "F: standing, the crawlway stops her %s" % d.at())
	d.button(JOY_BUTTON_B, true)
	var through := await d.until(func() -> bool: return d.nim.global_position.z < -10.6, 5.0)
	d.button(JOY_BUTTON_B, false)
	d.stick(0, 0)
	d.check(through, "F: crouched (B), she crawls through %s" % d.at())


## F: the 6.5 m gap (edge at z -14). A jump alone falls short; a jump and a pounce cross.
func _pounce_gap() -> void:
	for with_pounce: bool in [false, true]:
		await d.place(Vector3(70, 0.05, -11.0))
		d.stick(0, -1)
		await d.secs(0.3)
		await d.until(func() -> bool: return d.nim.global_position.z <= -13.6, 2.0)
		d.button(JOY_BUTTON_A, true)
		await d.secs(0.3)
		if with_pounce:
			await d.pounce()
		await d.secs(0.2)
		d.button(JOY_BUTTON_A, false)
		await d.until(func() -> bool: return d.nim.is_on_floor(), 1.5)
		d.stick(0, 0)
		await d.secs(0.3)
		var p := d.nim.global_position
		if with_pounce:
			d.check(p.y > -0.1 and p.z < -20.5, "F: a jump and a pounce cross the 6.5 m gap %s" % d.at())
		else:
			d.check(p.y < -1.0, "F: a jump alone falls short of it %s" % d.at())
