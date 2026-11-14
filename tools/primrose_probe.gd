extends SceneTree
## Primrose Close's layout (WO-015 step 1), with real input:
##   - What's placed: 100 contraband, the tin, five neighbours mowing, three wardrobes, two shortcuts, the zones, two
##     fast travel points, the bulldogs and the Watch, every Key placed is one the world's data knows, and the garden's
##     back door is locked.
##   - The routes between the areas (goons and meerkats cleared off): up the Close to the turning head and into the Show
##     Home's living room; Church Path to St. Prudence's and in at its door; up the marked tower to the belfry, down the
##     bell rope inside and the door to the hall opened from the tower's side; from a lawn up onto a garden fence, along
##     its top, and up onto the washing line and along it; Allotment Lane into the allotments, the hedge gap opened
##     from their side and through to the Close; the garden behind the Show Home closed.
##   godot --headless --fixed-fps 60 --path . -s tools/primrose_probe.gd

const Driver := preload("res://tools/probe_driver.gd")
const SCENE := "res://levels/primrose/primrose.tscn"
## The level's constants (levels/primrose/primrose.gd), copied: naming its class here would compile it before the
## autoloads exist.
const TOWER := Vector3(65.0, 0.0, -55.0)
const BELFRY := 14.0
const LINE_Y := 3.7
const LAWN := 0.08

var d: Driver
var level: Node
var game: Node


func _initialize() -> void:
	await process_frame
	game = root.get_node("/root/Game")
	game.set(&"persist", false)
	game.call(&"set_setting", "age_confirmed", true)
	game.call(&"reset")
	# The routes, not the Keys: Vesper's already rung the bells (keys/steeple.gd's talk in the belfry would hold the climb
	# down the rope). primrose_keys_probe plays the Keys.
	game.call(&"set_flag", "primrose/bells_rung")
	level = load(SCENE).instantiate()
	root.add_child(level)
	current_scene = level
	await physics_frame
	d = Driver.new(self, level.get(&"nim"), level.get(&"cam"))
	_placed()
	_clear_guards()
	await d.frames(5)
	await _close()
	await _church_path()
	await _steeple()
	await _bell_rope()
	await _fence_and_line()
	await _allotments()
	await _garden_closed()
	await _both_ways()
	print("primrose probe: %d failures" % d.fails)
	quit(1 if d.fails else 0)


func _all(type: String) -> Array:
	return level.find_children("*", type, true, false)


func _placed() -> void:
	var pickups := _all("Pickup")
	var cb := pickups.filter(func(p: Pickup) -> bool: return p.kind == &"contraband")
	var tins := pickups.filter(func(p: Pickup) -> bool: return p.kind == &"tin")
	var keys := pickups.filter(func(p: Pickup) -> bool: return p.kind == &"key")
	var ids := {}
	for p: Pickup in cb:
		ids[p.id] = true
	d.check(cb.size() == 100 and ids.size() == 100, "100 contraband placed, 100 different ids (%d, %d)" % [cb.size(), ids.size()])
	d.check(tins.size() == 1, "the collection tin (%d)" % tins.size())
	var unknown := keys.filter(func(p: Pickup) -> bool: return WorldData.key(&"primrose", p.id).is_empty())
	d.check(keys.size() >= 1 and unknown.is_empty(), "%d Keys placed, all in the world's data" % keys.size())
	d.check(_all("Entranced").size() == 5, "five neighbours mowing (%d)" % _all("Entranced").size())
	d.check(_all("Wardrobe").size() == 3, "three wardrobes (%d)" % _all("Wardrobe").size())
	d.check(_all("ShortcutDoor").size() == 2, "two shortcuts (%d)" % _all("ShortcutDoor").size())
	d.check(_all("Zone").size() >= 6, "the zones (%d)" % _all("Zone").size())
	d.check(_all("TravelPoint").size() == 2, "two fast travel points (%d)" % _all("TravelPoint").size())
	d.check(_all("Enemy").size() >= 10 and _all("Lookout").size() >= 6,
		"bulldogs (%d) and the Watch (%d) on duty" % [_all("Enemy").size(), _all("Lookout").size()])
	d.check(level.get_node("GardenDoor").call(&"is_locked"), "the Show Home's back door to the garden is locked")
	d.check(level.get_node_or_null("Gate_hub") != null, "the OLD QUARTER arch takes her home")
	d.check((level.get(&"curtains") as Array).size() >= 20, "lit net curtains, for the twitchers (%d)" % (level.get(&"curtains") as Array).size())


func _clear_guards() -> void:
	for n: Node in _all("Enemy") + _all("Lookout"):
		n.get_parent().remove_child(n)
		n.queue_free()


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


func _close() -> void:
	await d.place(Vector3(0, 0.05, 3.0), 0.0)
	var ok := await _walk_to(Vector3(0, 0, -100.0), 25.0)
	d.check(ok, "up the Close to the turning head %s" % d.at())
	ok = await _walk_to(Vector3(0, 0, -118.0), 6.0, 0.4)
	ok = ok and await _walk_to(Vector3(-2.0, 0, -121.0), 6.0)
	d.check(ok, "and in at the Show Home's door to the living room %s" % d.at())


func _church_path() -> void:
	await d.place(Vector3(0, 0.05, -46.0), -PI / 2.0)
	var ok := await _walk_to(Vector3(50.0, 0, -46.0), 20.0)
	d.check(ok, "Church Path, from the Close to St. Prudence's porch %s" % d.at())
	ok = await _walk_to(Vector3(62.0, 0, -46.0), 6.0)
	d.check(ok, "and in at the hall's door %s" % d.at())


func _steeple() -> void:
	await d.place(TOWER + Vector3(0, 0.05, -4.2), 0.0)
	var up := await _push(Vector3(0, 0, 1), func() -> bool:
		return d.nim.state == Nim.State.MOVE and d.nim.is_on_floor() and d.nim.global_position.y > BELFRY - 0.1, 25.0)
	d.check(up, "up the tower's marked face into the belfry %s" % d.at())


func _bell_rope() -> void:
	var sc := level.get_node("Shortcut_bell_rope") as ShortcutDoor
	# From the belfry, into the rope's hole (x 66.4..67.6, z -53.8..-52.4), down the marked strip (the rope) inside.
	await d.place(TOWER + Vector3(0.6, BELFRY + 0.35, 2.0), -PI / 2.0)
	# Step in toward the rope; once she's on it, down (on a wall the stick's down is down).
	var down := await d.until(func() -> bool:
		if d.nim.is_on_floor() and d.nim.global_position.y < 0.5:
			return true
		if d.nim.state == Nim.State.CLIMB:
			d.stick(0, 1)
		elif d.nim.state == Nim.State.HANG:
			d.stick(0, 0)
			d.tap(JOY_BUTTON_B)   # caught the hole's edge: let go, down to the rope
		else:
			d.steer(Vector3(1, 0, 0), 0.6)
		return false, 30.0)
	d.stick(0, 0)
	var p := d.nim.global_position
	d.check(down and p.x > TOWER.x - 3.0 and p.x < TOWER.x + 3.0 and p.z < -52.0, "down the bell rope inside the tower %s" % d.at())
	var ok := await _walk_to(Vector3(TOWER.x, 0, -52.9), 5.0, 0.3)
	await d.tap(JOY_BUTTON_Y)
	await d.frames(4)
	d.check(ok and sc.is_open, "and the door to the hall opens from the tower's side")
	ok = await _walk_to(Vector3(TOWER.x, 0, -48.0), 5.0)
	d.check(ok, "and she walks through into the hall %s" % d.at())


func _fence_and_line() -> void:
	# On a west lawn, by the fence between two gardens (its top a beam at 1.8, along X at z -16).
	await d.place(Vector3(-30.0, LAWN + 0.05, -14.6), PI)
	d.steer(Vector3(0, 0, -1))
	await d.jump(0.5)
	var on := await d.until(func() -> bool: return d.nim.state == Nim.State.BALANCE and d.nim.global_position.y > 1.7, 3.0)
	d.stick(0, 0)
	d.check(on, "from the lawn up onto the garden fence's top %s" % d.at())
	var x0 := d.nim.global_position.x
	await _push(Vector3(-1, 0, 0), func() -> bool: return d.nim.global_position.x < -34.6 or d.nim.global_position.y < 1.6, 6.0)
	d.check(d.nim.global_position.y > 1.7 and x0 - d.nim.global_position.x > 4.0, "along the fence's top %s" % d.at())
	# Beside the washing line (x -35) on the fence: a jump up and across onto it, then along it. (Straight up from
	# under it, she'd hit her head on it.)
	await d.place(Vector3(-34.3, 1.85, -16.0), PI / 2.0)
	await d.frames(10)
	d.steer(Vector3(-1, 0, 0), 0.35)
	await d.jump(0.5)
	var line := await d.until(func() -> bool: return d.nim.state == Nim.State.BALANCE and d.nim.global_position.y > LINE_Y - 0.2, 3.0)
	d.check(line, "up off the fence onto the washing line %s" % d.at())
	var z0 := d.nim.global_position.z
	await _push(Vector3(0, 0, -1), func() -> bool: return false, 3.0)
	d.check(d.nim.global_position.y > LINE_Y - 0.2 and z0 - d.nim.global_position.z > 3.0, "and along the line, over the gardens %s" % d.at())


func _allotments() -> void:
	var gap := level.get_node("Shortcut_hedge_gap") as ShortcutDoor
	await d.place(Vector3(-10.0, 0.17, 4.0), -PI / 2.0)
	var ok := await _walk_to(Vector3(-55.0, 0, 4.0), 12.0)
	ok = ok and await _walk_to(Vector3(-55.0, 0, -100.0), 25.0)
	d.check(ok, "Allotment Lane into the allotments %s" % d.at())
	ok = await _walk_to(Vector3(-49.0, 0, -111.0), 8.0, 0.3)
	await d.tap(JOY_BUTTON_Y)
	await d.frames(4)
	d.check(ok and gap.is_open, "the hedge gap opens from the allotments' side")
	ok = await _walk_to(Vector3(-30.0, 0, -111.0), 8.0)
	ok = ok and await _walk_to(Vector3(0, 0, -100.0), 10.0)
	d.check(ok, "and through it, along the lane to the turning head %s" % d.at())


## Out under the OLD QUARTER arch to Primrose Lane in the hub, and back in through its gate (six roses: rank 2).
func _both_ways() -> void:
	for id: StringName in [&"hub_10", &"hub_07"]:
		game.call(&"collect", &"key", &"hub", id)
	for id: StringName in [&"pier_01", &"pier_02", &"pier_03", &"pier_04"]:
		game.call(&"collect", &"key", &"pier", id)
	game.call(&"set_flag", "hub/prologue_done")
	await d.place(Vector3(0, 0.05, 6.0), PI)
	var out := await _cross(Vector3(0, 0, 1), "hub.tscn")
	await d.frames(10)
	var hub := current_scene
	var hn: Node3D = hub.get(&"nim") if out else null
	d.check(out and hn.global_position.distance_to(Vector3(-8.0, 0.05, 30.0)) < 1.5,
		"under the arch: back on Primrose Lane in the hub (%s)" % (hn.global_position if hn else "no"))
	if not out:
		return
	d = Driver.new(self, hn as Nim, hub.get(&"cam"))
	var back := await _cross(Vector3(0, 0, 1), "primrose.tscn")
	await d.frames(10)
	var pn: Node3D = current_scene.get(&"nim") if back else null
	d.check(back and pn.global_position.distance_to(Vector3(0, 0.05, 4.0)) < 1.5,
		"and through Primrose Lane's gate, back in at the Close's mouth (%s)" % (pn.global_position if pn else "no"))


## Walks her along `dir` until the game's moved on to `scene` (the old Nim's freed with the old level, so this stops
## steering her the moment she's gone).
func _cross(dir: Vector3, scene: String) -> bool:
	var t := 0.0
	while t < 12.0:
		if _in(scene):
			d.stick(0, 0)
			return true
		if is_instance_valid(d.nim) and d.nim.is_inside_tree():
			d.steer(dir)
		await physics_frame
		t += 1.0 / 60.0
	d.stick(0, 0)
	return false


func _in(scene: String) -> bool:
	return current_scene != null and current_scene.scene_file_path.ends_with(scene) and current_scene.get(&"nim") != null


func _garden_closed() -> void:
	await d.place(Vector3(0, 0.1, -130.0), PI)
	await _push(Vector3(0, 0, -1), func() -> bool: return false, 3.0)
	d.check(d.nim.global_position.z > -136.4, "the garden's closed until the party: she can't get past the back door %s" % d.at())
