extends SceneTree
## Nim on the test course, climbing, with real input: catching a ledge, dropping from it, shimmying, pulling up (A and
## by pushing), a ledge that needs a jump to reach (C); climbing a marked wall up, across, down and off (D).
##   godot --headless --fixed-fps 60 --path . -s tools/climb_probe.gd

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
	await _ledges()
	await _climb()
	print("climb probe: %d failures" % d.fails)
	quit(1 if d.fails else 0)


func _hanging() -> bool:
	return d.nim.state == Nim.State.HANG


## Runs at the wall whose face is at `face_z` and jumps; true if she ends up hanging.
func _jump_at(face_z: float) -> bool:
	d.stick(0, -1)
	await d.until(func() -> bool: return d.nim.global_position.z <= face_z + 1.6, 4.0)
	d.button(JOY_BUTTON_A, true)
	var caught := await d.until(_hanging, 1.5)
	d.button(JOY_BUTTON_A, false)
	return caught


func _ledges() -> void:
	var x := 28.0
	# Catch the 3 m wall's ledge (face at z -8).
	await d.place(Vector3(x, 0.05, 2.0))
	var caught := await _jump_at(-8.0)
	d.stick(0, 0)
	d.check(caught and absf(d.nim.ledge_height() - 3.0) < 0.05, "C: a jump at the 3 m wall catches its ledge %s" % d.at())
	# B lets go.
	await d.secs(0.2)
	await d.tap(JOY_BUTTON_B)
	await d.secs(1.0)
	d.check(d.nim.state == Nim.State.MOVE and d.nim.global_position.y < 0.1, "C: B drops her from the ledge %s" % d.at())
	# Catch it again, shimmy right along it, then A pulls her up.
	caught = await _jump_at(-8.0)
	d.stick(0, 0)
	await d.secs(0.2)
	var x0 := d.nim.global_position.x
	d.stick(1, 0)
	await d.secs(1.0)
	d.stick(0, 0)
	var moved := d.nim.global_position.x - x0
	d.check(_hanging() and moved > 1.2, "C: shimmies right along the ledge (%.2f m)" % moved)
	d.stick(1, 0)
	await d.secs(2.0)
	d.stick(0, 0)
	d.check(_hanging() and d.nim.global_position.x < x + 3.0, "C: and stops where it ends %s" % d.at())
	await d.tap(JOY_BUTTON_A)
	await d.until(func() -> bool: return d.nim.state == Nim.State.MOVE, 1.0)
	await d.secs(0.3)
	d.check(absf(d.nim.global_position.y - 3.0) < 0.1 and d.nim.global_position.z < -8.0, "C: A pulls her up onto the top %s" % d.at())
	# The 4 m wall from the terrace (face at z -20): out of a standing reach, caught at the top of a jump; holding the
	# stick at it pulls her up.
	await d.place(Vector3(x, 3.05, -12.0))
	caught = await _jump_at(-20.0)
	d.check(caught and absf(d.nim.ledge_height() - 7.0) < 0.05, "C: the 4 m wall's ledge, caught at a jump's top %s" % d.at())
	d.stick(0, -1)
	await d.until(func() -> bool: return d.nim.global_position.y > 6.9 and d.nim.state == Nim.State.MOVE, 2.0)
	d.stick(0, 0)
	d.check(d.nim.global_position.y > 6.9, "C: holding the stick at the wall pulls her up %s" % d.at())


func _climbing() -> bool:
	return d.nim.state == Nim.State.CLIMB


func _climb() -> void:
	var x := 42.0
	# Up the marked wall (face at z -8, 7 m) and over the top.
	await d.place(Vector3(x, 0.05, 2.0))
	d.stick(0, -1)
	var on := await d.until(_climbing, 3.0)
	d.check(on, "D: pushing into the marked wall starts a climb %s" % d.at())
	var y0 := d.nim.global_position.y
	await d.secs(1.0)
	var rate := d.nim.global_position.y - y0
	d.check(absf(rate - 2.5) < 0.2, "D: climbs at 2.5 m/s (%.2f)" % rate)
	var over := await d.until(func() -> bool: return d.nim.state == Nim.State.MOVE and d.nim.global_position.y > 6.9, 4.0)
	d.stick(0, 0)
	d.check(over, "D: up 7 m and over the top %s" % d.at())

	# Across: on the wall, right moves her right, and she stops at its edge (x + 3).
	await d.place(Vector3(x, 0.05, -7.0))
	d.stick(0, -1)
	await d.until(_climbing, 2.0)
	await d.secs(0.6)
	d.stick(1, 0)
	await d.secs(0.8)
	var across := d.nim.global_position.x - x
	await d.secs(1.5)
	d.stick(0, 0)
	d.check(_climbing() and across > 1.5 and d.nim.global_position.x <= x + 3.0,
		"D: climbs across (%.2f m in 0.8 s) and holds at the edge %s" % [across, d.at()])

	# Down: the stick down climbs her back to the ground, and she's off the wall.
	d.stick(0, 1)
	var down := await d.until(func() -> bool: return d.nim.state == Nim.State.MOVE and d.nim.is_on_floor(), 3.0)
	d.stick(0, 0)
	d.check(down, "D: climbs down to the ground and steps off %s" % d.at())

	# Off: A on the wall leaps away from it.
	await d.place(Vector3(x, 0.05, -7.0))
	d.stick(0, -1)
	await d.until(_climbing, 2.0)
	await d.secs(0.8)
	d.stick(0, 0)
	await d.tap(JOY_BUTTON_A)
	await d.until(func() -> bool: return d.nim.is_on_floor(), 2.0)
	d.check(d.nim.state == Nim.State.MOVE and d.nim.global_position.z > -6.5, "D: A leaps off the wall %s" % d.at())
