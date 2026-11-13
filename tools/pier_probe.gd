extends SceneTree
## The Pier's layout (WO-014 step 1), with real input:
##   - What's placed: 100 contraband, the tin, five sleepers, three wardrobes, three shortcuts, six zones, four fast
##     travel points, the goons and gulls, and every Key placed is one the world's data knows.
##   - The routes between the areas (goons and gulls cleared off, the crowd left in): the gate down the Midway to the
##     Fun Palace's door; the ramp to the beach; under the pier to the lifeguard hut; up a marked post onto a stringer
##     and along it; up the trapdoor's ladder into the tackle hut and the shortcut opened from inside; the walkway, the
##     marked wall to the roof, down the vent into the office and out by its door; off the roof's back onto the
##     platform and the fire door opened from there; into a Ferris wheel car, ridden to the top, and a jump to the
##     crown for Key 8.
##   godot --headless --fixed-fps 60 --path . -s tools/pier_probe.gd

const Driver := preload("res://tools/probe_driver.gd")
const PIER := "res://levels/pier/pier.tscn"
## The level's own constants (levels/pier/pier.gd), copied: naming its class here would compile it before the
## autoloads exist.
const SAND := -6.0
const BEAM_Y := -3.2
const PALACE_H := 9.0
const WHEEL := Vector3(-24, 16, -205)

var d: Driver
var pier: Node
var game: Node


func _initialize() -> void:
	await process_frame
	game = root.get_node("/root/Game")
	game.set(&"persist", false)
	game.call(&"set_setting", "age_confirmed", true)
	game.call(&"reset")
	# The routes, not the story: Vesper's lesson under the pier is done (tools/pier_keys_probe.gd plays it).
	game.call(&"set_flag", "pier/lesson_done")
	pier = load(PIER).instantiate()
	root.add_child(pier)
	current_scene = pier
	await physics_frame
	d = Driver.new(self, pier.get(&"nim"), pier.get(&"cam"))
	_placed()
	_clear_guards()
	await d.frames(5)
	await _midway()
	await _ramp_and_under()
	await _stringer()
	await _trapdoor()
	await _palace()
	await _fire_door()
	await _wheel()
	print("pier probe: %d failures" % d.fails)
	quit(1 if d.fails else 0)


func _all(type: String) -> Array:
	return pier.find_children("*", type, true, false)


func _placed() -> void:
	var pickups := _all("Pickup")
	var cb := pickups.filter(func(p: Pickup) -> bool: return p.kind == &"contraband")
	var tins := pickups.filter(func(p: Pickup) -> bool: return p.kind == &"tin")
	var keys := pickups.filter(func(p: Pickup) -> bool: return p.kind == &"key")
	d.check(cb.size() == 100, "100 contraband placed (%d)" % cb.size())
	var ids := {}
	for p: Pickup in cb:
		ids[p.id] = true
	d.check(ids.size() == 100, "with 100 different ids (%d)" % ids.size())
	d.check(tins.size() == 1, "the collection tin (%d)" % tins.size())
	var unknown := keys.filter(func(p: Pickup) -> bool: return WorldData.key(&"pier", p.id).is_empty())
	d.check(keys.size() >= 2 and unknown.is_empty(), "%d Keys placed, all in the world's data" % keys.size())
	d.check(_all("Entranced").size() == 5, "five sleepers (%d)" % _all("Entranced").size())
	d.check(_all("Wardrobe").size() == 3, "three wardrobes (%d)" % _all("Wardrobe").size())
	d.check(_all("ShortcutDoor").size() == 3, "three shortcuts (%d)" % _all("ShortcutDoor").size())
	d.check(_all("Zone").size() == 6, "six zones (%d)" % _all("Zone").size())
	d.check(_all("TravelPoint").size() == 4, "four fast travel points (%d)" % _all("TravelPoint").size())
	d.check(_all("Enemy").size() >= 12 and _all("Lookout").size() >= 4,
		"goons (%d) and gulls (%d) on duty" % [_all("Enemy").size(), _all("Lookout").size()])


## The routes are about the layout: the goons and gulls step aside.
func _clear_guards() -> void:
	for n: Node in _all("Enemy") + _all("Lookout"):
		n.get_parent().remove_child(n)
		n.queue_free()


## Steers her toward `target` (on the ground plane) until she's within `near`; true if she got there in time.
func _walk_to(target: Vector3, timeout := 20.0, near := 0.6) -> bool:
	var ok := await d.until(func() -> bool:
		var to := target - d.nim.global_position
		to.y = 0.0
		if to.length() < near:
			return true
		d.steer(to)
		return false, timeout)
	d.stick(0, 0)
	return ok


## Holds the stick toward world direction `dir` (re-aimed every frame, as the camera swings) until `cond`. On a wall the
## stick isn't camera-relative: up is up, so that's where it's held.
func _push(dir: Vector3, cond: Callable, timeout: float, amount := 1.0) -> bool:
	var ok := await d.until(func() -> bool:
		if cond.call():
			return true
		if d.nim.state == Nim.State.CLIMB:
			d.stick(0, -1)
		else:
			d.steer(dir, amount)
		return false, timeout)
	d.stick(0, 0)
	return ok


func _midway() -> void:
	await d.place(Vector3(8.5, 0.05, -4.0), 0.0)
	var ok := await _walk_to(Vector3(8.5, 0, -106.0), 25.0)
	d.check(ok, "the Midway, gate to the Fun Palace's door, on foot %s" % d.at())


func _ramp_and_under() -> void:
	await d.place(Vector3(-40.0, 0.05, 7.0), PI)
	var ok := await _walk_to(Vector3(-40.0, 0, 4.6), 5.0, 0.3)
	ok = ok and await _walk_to(Vector3(-56.0, 0, 3.2), 10.0)
	d.check(ok and absf(d.nim.global_position.y - SAND) < 0.2, "down the ramp to the beach %s" % d.at())
	for p: Vector3 in [Vector3(-20, 0, -2.0), Vector3(-6.0, 0, -6.0), Vector3(-6.0, 0, -21.0), Vector3(-9.5, 0, -21.0)]:
		ok = ok and await _walk_to(p, 15.0)
	d.check(ok and absf(d.nim.global_position.y - SAND) < 0.2, "under the pier to the lifeguard hut %s" % d.at())


func _stringer() -> void:
	# The marked post at (-7, -16), from its west face, then a step east onto the stringer at x -6.
	await d.place(Vector3(-8.2, SAND + 0.05, -16.0), -PI / 2.0)
	var up := await _push(Vector3.RIGHT, func() -> bool:
		return d.nim.state == Nim.State.MOVE and d.nim.is_on_floor() and d.nim.global_position.y > BEAM_Y - 0.1, 8.0)
	d.check(up, "up the marked post to the beams %s" % d.at())
	var on := await _push(Vector3.RIGHT, func() -> bool: return d.nim.state == Nim.State.BALANCE, 3.0, 0.6)
	d.check(on, "onto the stringer, tail out %s" % d.at())
	var z0 := d.nim.global_position.z
	await _push(Vector3.FORWARD, func() -> bool: return false, 4.0)
	var went := z0 - d.nim.global_position.z
	d.check(went > 5.0 and d.nim.global_position.y > BEAM_Y - 0.2, "and along it, %.1f m out over the sand %s" % [went, d.at()])


func _trapdoor() -> void:
	var sc := pier.get_node("Shortcut_trapdoor") as ShortcutDoor
	# Up the ladder board under the hatch (its face at x 14.6, facing -X).
	await d.place(Vector3(13.9, SAND + 0.05, -59.0), -PI / 2.0)
	var up := await _push(Vector3.RIGHT, func() -> bool:
		return d.nim.state == Nim.State.MOVE and d.nim.is_on_floor() and d.nim.global_position.y > -0.1, 8.0)
	d.check(up and d.nim.global_position.x > 11.2, "up the trapdoor's ladder into the tackle hut %s" % d.at())
	var ok := await _walk_to(Vector3(11.8, 0, -59.0), 4.0, 0.3)
	await d.tap(JOY_BUTTON_Y)
	await d.frames(4)
	d.check(ok and sc.is_open, "and the hut's door, bolted inside, opens from there")
	ok = await _walk_to(Vector3(8.0, 0, -59.0), 4.0)
	d.check(ok, "and she walks out onto the Midway %s" % d.at())


func _palace() -> void:
	var office := pier.get_node("Shortcut_office") as ShortcutDoor
	await d.place(Vector3(14.0, 0.05, -104.0), PI)
	var ok := await _walk_to(Vector3(18.0, 0, -110.0), 6.0)
	ok = ok and await _walk_to(Vector3(19.1, 0, -123.0), 8.0)
	d.check(ok, "round the Fun Palace's corner and down its east walkway %s" % d.at())
	var up := await _push(Vector3.LEFT, func() -> bool:
		return d.nim.state == Nim.State.MOVE and d.nim.is_on_floor() and d.nim.global_position.y > PALACE_H, 10.0)
	d.check(up, "up the marked wall onto the roof %s" % d.at())
	ok = await _walk_to(Vector3(12.0, 0, -140.0), 10.0)
	ok = ok and await _walk_to(Vector3(12.0, 0, -146.0), 4.0, 0.3)
	# Dropping in, she catches the vent's edge; B lets go.
	if await d.until(func() -> bool: return d.nim.state == Nim.State.HANG, 1.0):
		await d.secs(0.2)
		await d.tap(JOY_BUTTON_B)
	await d.until(func() -> bool: return d.nim.is_on_floor() and d.nim.global_position.y < 0.5, 3.0)
	var p := d.nim.global_position
	d.check(ok and p.y < 0.5 and p.x > 6.0 and p.z < -138.0, "down the vent into the back office %s" % d.at())
	ok = await _walk_to(Vector3(6.8, 0, -144.9), 6.0, 0.3)
	await d.tap(JOY_BUTTON_Y)
	await d.frames(4)
	d.check(ok and office.is_open, "out by the office door, bolted inside")


func _fire_door() -> void:
	var fire := pier.get_node("Shortcut_fire_door") as ShortcutDoor
	await d.place(Vector3(-2.0, PALACE_H + 0.45, -146.0), PI)
	var ok := await _walk_to(Vector3(-2.0, 0, -154.0), 6.0)
	await d.until(func() -> bool: return d.nim.is_on_floor() and d.nim.global_position.y < 0.5, 3.0)
	d.check(ok and d.nim.global_position.y < 0.5, "off the roof's back onto the coaster's end of the pier %s" % d.at())
	ok = await _walk_to(Vector3(-2.0, 0, -152.8), 4.0, 0.3)
	await d.tap(JOY_BUTTON_Y)
	await d.frames(4)
	d.check(ok and fire.is_open, "the fire door opens from the platform side")


func _wheel() -> void:
	var wheel: Node3D = pier.get(&"wheel")
	var cars: Array = wheel.get(&"car_bodies")
	# The car at the bottom now: she's put in it, and rides.
	var low := 0
	for i in cars.size():
		if (cars[i] as Node3D).global_position.y < (cars[low] as Node3D).global_position.y:
			low = i
	var car := cars[low] as Node3D
	await d.place(car.global_position + Vector3(0, 0.1, 0), -PI / 2.0)
	await d.secs(3.0)
	var rel := d.nim.global_position - car.global_position
	d.check(absf(rel.x) < 1.2 and absf(rel.z) < 0.9 and rel.y > -0.1 and rel.y < 0.4,
		"she rides a wheel car (%.2f, %.2f, %.2f from its floor)" % [rel.x, rel.y, rel.z])
	# Up to the top: when her car is at the crown's line, a jump east onto it takes Key 8.
	var top := await d.until(func() -> bool:
		var p := car.global_position - WHEEL
		return p.y > 11.0 and absf(p.z) < 0.6, 40.0)
	d.check(top, "the car carries her to the top %s" % d.at())
	d.steer(Vector3.RIGHT)
	await d.jump()
	var got := await d.until(func() -> bool: return game.call(&"has_collected", &"key", &"pier", &"pier_08"), 3.0)
	d.stick(0, 0)
	d.check(got, "a jump from the top car onto the crown takes Key 8 %s" % d.at())
