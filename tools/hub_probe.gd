extends SceneTree
## The hub (WO-014 step 5), with real input, from a new game:
##   - The prologue in the club's dungeon: Vesper's welcome; the guest comes down the ramp; a strike at his humming toy
##     wakes him, and that's her first Key (hub_10: rank 1); Vesper reads the tag; she's in the lounge after.
##   - Up the ramp, out of the club's door, across Rope Square and down Seafront Road to the Pier's gate: timed against
##     the sizing (club door to the gate in under 16 s at a run, docs/STUDY.md's Banjo lessons).
##   - The rooftop Key (hub_07): up the marked alley wall, over the roofs, along the wire to the harbour lamp.
##   - The later worlds' gates stay shut at rank 1; the Pier's opens; through it she's on the Pier, at the Old
##     Quarter's arch; back through the arch she's on Seafront Road. Fast travel points are found on the way.
##   godot --headless --fixed-fps 60 --path . -s tools/hub_probe.gd

const Driver := preload("res://tools/probe_driver.gd")
const HUB := "res://levels/hub/hub.tscn"
const PIER := "res://levels/pier/pier.tscn"
const DUNGEON := -1.6

var d: Driver
var level: Node
var game: Node
var dialogue: Node


func _initialize() -> void:
	await process_frame
	game = root.get_node("/root/Game")
	dialogue = root.get_node("/root/Dialogue")
	game.set(&"persist", false)
	game.call(&"set_setting", "age_confirmed", true)
	game.call(&"reset")
	level = load(HUB).instantiate()
	root.add_child(level)
	current_scene = level
	await physics_frame
	d = Driver.new(self, level.get(&"nim"), level.get(&"cam"))
	await _prologue()
	await _rooftops()
	await _vaults()
	await _rivet()
	await _to_the_pier()
	await _and_back()
	print("hub probe: %d failures" % d.fails)
	quit(1 if d.fails else 0)


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


func _push(dir: Vector3, cond: Callable, timeout: float) -> bool:
	var ok := await d.until(func() -> bool:
		if cond.call():
			return true
		if d.nim.state == Nim.State.CLIMB:
			d.stick(0, -1)
		else:
			d.steer(dir)
		return false, timeout)
	d.stick(0, 0)
	return ok


func _converse(what: String, timeout := 4.0) -> bool:
	var started := await d.until(func() -> bool: return dialogue.call(&"is_active"), timeout)
	var ended := started and await d.talk_through(60.0)
	d.check(started and ended, what)
	return started and ended


func _prologue() -> void:
	d.check(absf(d.nim.global_position.y - DUNGEON) < 0.3, "a new game starts in the club's dungeon %s" % d.at())
	await _converse("Vesper's welcome")
	await _converse("the guest comes down the ramp, humming", 6.0)
	var guest := level.get_node("Entranced_guest") as Node3D
	# From in front of him, a strike at the toy.
	var woke := false
	for i in 6:
		var f := -guest.global_basis.z
		await d.place(guest.global_position + f * 1.2, atan2(f.x, f.z))
		await d.tap(JOY_BUTTON_X)
		await d.secs(0.5)
		if game.call(&"has_collected", &"freed", &"hub", &"guest"):
			woke = true
			break
	d.check(woke, "a strike at his toy wakes him")
	d.check(game.call(&"has_collected", &"key", &"hub", &"hub_10") and game.call(&"rank") == 1,
		"and that's her first Key (hub_10): rank %d" % game.call(&"rank"))
	await _converse("Vesper reads the tag: Laffer's Fun Palace, the Pier", 4.0)
	var vesper := level.get_node("Prologue/Vesper") as Node3D
	# They walk up the ramp now (no teleports): wait for them to get there.
	var arrived := await d.until(func() -> bool:
		return not vesper.get(&"walking") and vesper.global_position.y > -0.5 \
			and Vector2(guest.global_position.x + 6.6, guest.global_position.z + 23.4).length() < 0.6, 45.0)
	d.check(game.call(&"has_flag", "hub/prologue_done") and arrived,
		"the prologue's done; the guest and Vesper walk up to the lounge (%s, %s)" % [vesper.global_position, guest.global_position])


## The vaults (WO-014b): from the club's door, through the lounge and the dungeon, down the stair, into every room
## off the hall, and through the swung-open shelf in Rivet's workshop to the Backroom. On foot, timed (DESIGN: within
## about 30 s of the door).
func _vaults() -> void:
	await d.place(Vector3(0.0, 0.05, -15.0), PI)
	var t0 := Engine.get_physics_frames()   # game time (headless runs faster than real time)
	var ok := true
	for p: Vector3 in [Vector3(1.0, 0, -18.0), Vector3(6.6, 0, -18.6), Vector3(7.5, 0, -26.0), Vector3(7.5, 0, -33.0), Vector3(0.0, 0, -36.0),
			Vector3(0.0, 0, -40.0), Vector3(0.0, 0, -49.0)]:
		ok = ok and await _walk_to(p, 12.0)
	var secs := (Engine.get_physics_frames() - t0) / 60.0
	d.check(ok and d.nim.global_position.y < -4.5, "the door to the vaults' hall on foot: %.1f s (under 30) %s" % [secs, d.at()])
	d.check(secs < 30.0, "within 30 s of the door")
	for room: Vector3 in [Vector3(-8.0, 0, -51.5), Vector3(-8.0, 0, -58.5), Vector3(-8.0, 0, -65.5), Vector3(8.0, 0, -51.5),
			Vector3(8.0, 0, -58.5), Vector3(8.0, 0, -65.5)]:
		# Out through the doorway to the hall, along it, and in.
		var into := await _walk_to(Vector3(0.0, 0, d.nim.global_position.z), 10.0) \
			and await _walk_to(Vector3(0.0, 0, room.z), 10.0) and await _walk_to(room, 10.0)
		d.check(into, "into the room at %s %s" % [room, d.at()])
	ok = await _walk_to(Vector3(9.9, 0, -68.8), 8.0) and await _walk_to(Vector3(9.9, 0, -71.0), 6.0) \
		and await _walk_to(Vector3(4.0, 0, -75.0), 8.0)
	d.check(ok, "through the shelf in Rivet's workshop to the Backroom %s" % d.at())


## Rivet turns seized contraband into gear: 130 handed in is 5 lures and one upgrade (a health pip, the first).
func _rivet() -> void:
	for i in 130:
		game.call(&"collect", &"contraband", &"pier", StringName("probe_%d" % i))
	# Rivet's in her workshop in the vaults now (WO-014b): Hub.sister_spot is (9.8, -5, -66.9).
	await d.place(Vector3(8.8, -4.95, -65.9), atan2(-1.0, 1.0))
	await d.tap(JOY_BUTTON_Y)
	await _converse("Rivet: bring her the toys you seize")
	await d.secs(0.3)
	d.check(int(game.call(&"get_flag", "rivet/handed", 0)) == 130 and d.nim.gear.lures == 5
		and int(game.call(&"get_flag", "upgrade/health", 0)) == 1 and d.nim.combat.max_health == 6,
		"130 toys handed to Rivet: 5 lures and a sixth health pip (%d lures, %d pips)" % [d.nim.gear.lures,
			d.nim.combat.max_health])
	await d.tap(JOY_BUTTON_Y)
	await _converse("and again, with nothing new: nothing more")
	d.check(d.nim.gear.lures == 5 and d.nim.combat.max_health == 6, "a second visit pays nothing twice")


func _rooftops() -> void:
	await d.place(Vector3(45.0, 0.05, -6.0), -PI / 2.0)
	var up := await _push(Vector3.RIGHT, func() -> bool:
		return d.nim.state == Nim.State.MOVE and d.nim.is_on_floor() and d.nim.global_position.y > 7.3, 8.0)
	d.check(up, "up the marked alley wall to the rooftops %s" % d.at())
	var ok := await _walk_to(Vector3(57.4, 0, -6.0), 6.0, 0.3)
	d.steer(Vector3.RIGHT)
	await d.frames(4)
	await d.jump(0.4)
	ok = ok and await d.until(func() -> bool:
		d.steer(Vector3(62.0, 0, -6.0) - d.nim.global_position)
		return d.nim.is_on_floor() and d.nim.global_position.y > 8.8, 3.0)
	d.stick(0, 0)
	d.check(ok, "up onto the higher roof %s" % d.at())
	ok = await _walk_to(Vector3(71.6, 0, -6.0), 6.0, 0.3)
	ok = ok and await _walk_to(Vector3(76.6, 0, -6.0), 8.0, 0.3)
	ok = ok and await _walk_to(Vector3(77.0, 0, -6.6), 2.0, 0.2)
	await d.secs(0.3)
	d.check(ok and game.call(&"has_collected", &"key", &"hub", &"hub_07"), "along the wire to the harbour lamp: hub_07 %s" % d.at())


func _to_the_pier() -> void:
	# From the dungeon: up the ramp and out.
	await d.place(Vector3(3.0, DUNGEON + 0.05, -34.0), -PI / 2.0)
	var ok := true
	for p: Vector3 in [Vector3(7.5, 0, -33.4), Vector3(7.5, 0, -26.0), Vector3(1.0, 0, -18.0), Vector3(0.0, 0, -15.0)]:
		ok = ok and await _walk_to(p, 10.0)
		if not ok:
			print("  stuck short of ", p, " at ", d.at(), " v ", d.nim.velocity, " floor ", d.nim.is_on_floor(), " wall ", d.nim.is_on_wall())
			for i in d.nim.get_slide_collision_count():
				var c := d.nim.get_slide_collision(i)
				print("    hit ", c.get_collider(), " at ", c.get_position(), " n ", c.get_normal())
			break
	d.check(ok and d.nim.global_position.y > -0.1, "up the ramp and through the lounge to the door %s" % d.at())
	# The door to the gate, timed.
	var t0 := 0
	var frames := [0]
	ok = true
	for p: Vector3 in [Vector3(0.0, 0, -12.0), Vector3(20.0, 0, 5.0), Vector3(76.0, 0, 5.0)]:
		ok = ok and await d.until(func() -> bool:
			frames[0] += 1
			var to := p - d.nim.global_position
			to.y = 0.0
			if to.length() < 0.8:
				return true
			d.steer(to)
			return false, 20.0)
	d.stick(0, 0)
	var secs: float = (frames[0] - t0) / 60.0
	d.check(ok and secs < 16.0, "the club's door to the Pier's gate: %.1f s at a run (under 16)" % secs)
	# The later worlds' gates are shut at rank 1; the Pier's is open.
	var shut := ["primrose", "retreat", "docks", "press", "ball", "city_hall"].all(func(w: String) -> bool:
		return not (level.get_node("RankDoor_%s" % w) as RankDoor).is_open)
	var pier_gate := level.get_node("RankDoor_pier") as RankDoor
	await d.until(func() -> bool: return pier_gate.is_open, 2.0)
	d.check(shut and pier_gate.is_open, "the Pier's gate opens at rank 1; the six later ones stay shut")
	for tp: String in ["Travel_club", "Travel_seafront"]:
		d.check((level.get_node(tp) as TravelPoint).found, "%s found on the way" % tp)
	# Through it: the Pier.
	d.steer(Vector3.RIGHT)
	var there := await d.until(func() -> bool:
		return current_scene != null and current_scene.scene_file_path == PIER and current_scene.get(&"nim") != null, 10.0)
	d.stick(0, 0)
	d.check(there, "through the gate, she's on the Pier")


func _and_back() -> void:
	level = current_scene
	await physics_frame
	await physics_frame
	var fails_before := d.fails
	d = Driver.new(self, level.get(&"nim"), level.get(&"cam"))
	d.fails = fails_before
	d.check(d.nim.global_position.distance_to(Vector3(-64.0, 0.05, 17.0)) < 1.5, "in at the Old Quarter's arch %s" % d.at())
	d.steer(Vector3.LEFT)
	var back := await d.until(func() -> bool:
		return current_scene != null and current_scene.scene_file_path == HUB and current_scene.get(&"nim") != null, 10.0)
	d.stick(0, 0)
	d.check(back, "back through the arch to the Old Quarter")
	if back:
		level = current_scene
		await physics_frame
		await physics_frame
		var n: Node3D = level.get(&"nim")
		d.check(n.global_position.distance_to(Vector3(70.0, 0.05, 5.0)) < 1.5, "on Seafront Road (%.1f, %.1f)" % [n.global_position.x, n.global_position.z])
