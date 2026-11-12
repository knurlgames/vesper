extends SceneTree
## WO-007's acceptance, with real input on the test course's lane K: a check for each lesson and each piece of gear.
##   - The ceiling crawl, unlearned (she can't grip), then taught by Vesper (Y), then across the gap under the ceiling.
##   - The headfirst descent: walking off the top of a marked tower, she goes down its face head first, fast.
##   - The crop: the claw can't reach the switch 3 m off or the bell 2.8 m up; the crop (hold X) hits both.
##   - The rope: pulls a crate off a shelf; swings across a 12 m gap from an anchor; binds a goon from 4.5 m away.
##   - The signet: a councillor won't kneel to the suit without it, and will with it.
##   - The Scold: freezes the two goons coming at her; a frozen goon can be bound.
##   - The pendant: wakes the sleeper 6 m away.
##   - A lure: thrown, it buzzes, and the guard leaves his post to see what it is.
## (Takedown from above, Fetch and Open, Hold the Room and the fake trance are in stealth_probe and social_probe.)
##   godot --headless --fixed-fps 60 --path . -s tools/gear_probe.gd

const Driver := preload("res://tools/probe_driver.gd")
const X := 192.0

var d: Driver
var course: Node
var game: Node


func _initialize() -> void:
	await process_frame
	game = root.get_node("/root/Game")
	game.set(&"persist", false)
	game.call(&"reset")
	game.call(&"set_setting", "age_confirmed", true)
	course = load("res://levels/test_course/course.tscn").instantiate()
	root.add_child(course)
	current_scene = course
	await physics_frame
	d = Driver.new(self, course.get(&"nim"), course.get(&"cam"))
	await _ceiling()
	await _headfirst()
	await _crop()
	await _pull()
	await _signet()
	await _swing()
	await _rope_bind()
	await _scold()
	await _pendant()
	await _lure()
	print("gear probe: %d failures" % d.fails)
	quit(1 if d.fails else 0)


func _goon(id: String) -> Enemy:
	return course.get_node("Goon_%s" % id) as Enemy


func _select(gear: String) -> void:
	for i in 4:
		if d.nim.gear.selected == gear:
			return
		await d.tap(JOY_BUTTON_DPAD_LEFT)


func _ceiling() -> void:
	d.nim.known[Lessons.CEILING] = false
	# Unlearned: a jump under the ceiling at A's far edge is just a jump.
	await d.place(Vector3(X, 0.05, -5.5), 0.0)
	var gripped := false
	d.button(JOY_BUTTON_A, true)
	for i in 50:
		await physics_frame
		gripped = gripped or d.nim.state == Nim.State.CEILING
	d.button(JOY_BUTTON_A, false)
	await d.secs(0.6)
	d.check(not gripped, "ceiling, unlearned: a jump under it is just a jump")
	# Vesper teaches it.
	await d.place(Vector3(X - 6.0, 0.05, 9.4), 0.0)
	await d.tap(JOY_BUTTON_Y)
	var read := await d.talk_through()
	d.check(read, "her lesson plays as a conversation, read through with A")
	d.check(d.nim.knows(Lessons.CEILING) and game.call(&"has_flag", Lessons.CEILING),
		"Vesper (Y) teaches the ceiling crawl, and Game remembers it")
	# Learned: jump, grip, crawl the 10 m under it across the gap, drop onto B.
	await d.place(Vector3(X, 0.05, -5.5), 0.0)
	d.button(JOY_BUTTON_A, true)
	var on := await d.until(func() -> bool: return d.nim.state == Nim.State.CEILING, 1.0)
	d.button(JOY_BUTTON_A, false)
	d.check(on, "ceiling, learned: a jump under it, and she grips it %s" % d.at())
	d.stick(0, -1)
	var across := await d.until(func() -> bool: return d.nim.global_position.z < -14.3, 8.0)
	await d.secs(0.5)
	d.stick(0, 0)
	d.check(across and d.nim.state == Nim.State.CEILING, "and crawls across the gap upside down %s" % d.at())
	await d.tap(JOY_BUTTON_B)
	await d.secs(0.8)
	d.check(d.nim.state == Nim.State.MOVE and d.nim.global_position.y > -0.1 and d.nim.is_on_floor(),
		"B drops her onto the far side %s" % d.at())


func _headfirst() -> void:
	# On top of the tower (top 6 m, x X+3..X+7, z -18..-22), walking north off its marked face.
	await d.place(Vector3(X + 5.0, 6.05, -20.5), PI)
	d.stick(0, -1)
	var gripped_at := -1
	var landed_at := -1
	for i in 4 * 60:
		await physics_frame
		if d.nim.state == Nim.State.CLIMB and gripped_at < 0:
			gripped_at = i
		if gripped_at >= 0 and d.nim.state == Nim.State.MOVE and d.nim.is_on_floor():
			landed_at = i
			break
	d.stick(0, 0)
	d.check(gripped_at >= 0, "headfirst: walking off the tower's top, she grips its face instead of falling")
	# The face is 6 m: a fall takes 0.6 s, the 2.5 m/s climb 2.4 s; head first at 4.5 m/s, about 1 s. She lands at the
	# foot of the face (z -18 plus her radius), not out in the yard.
	var secs := (landed_at - gripped_at) / 60.0
	var at_foot := absf(d.nim.global_position.z - (-17.62)) < 0.4
	d.check(landed_at > 0 and secs > 0.8 and secs < 1.8 and at_foot and d.nim.global_position.y < 0.1,
		"and comes down it head first, fast: %.2f s to the foot of the wall %s" % [secs, d.at()])


func _crop() -> void:
	var sw := course.get_node("Switch_k") as CropTarget
	var bell := course.get_node("Bell_k") as CropTarget
	# The claw: the switch is 3 m off, the bell 2.8 m up. Neither.
	await d.place(Vector3(X + 6.0, 0.05, 3.0), 0.0)
	await d.tap(JOY_BUTTON_X)
	await d.secs(0.5)
	await d.place(Vector3(X + 2.0, 0.05, 1.0), 0.0)
	await d.tap(JOY_BUTTON_X)
	await d.secs(0.5)
	d.check(not sw.struck and not bell.struck, "the claw reaches neither the switch 3 m off nor the bell 2.8 m up")
	# The crop: hold X.
	await d.place(Vector3(X + 6.0, 0.05, 3.0), 0.0)
	await d.tap(JOY_BUTTON_X, 0.5)
	await d.secs(0.6)
	d.check(sw.struck, "the crop (X held) flips the switch from 3 m")
	await d.place(Vector3(X + 2.0, 0.05, 1.0), 0.0)
	await d.tap(JOY_BUTTON_X, 0.5)
	await d.secs(0.6)
	d.check(bell.struck, "and rings the bell 2.8 m up")


func _pull() -> void:
	var crate := course.get_node("Crate_k") as Pullable
	var at := Vector3(X + 2.0, 0.05, -24.0)
	var to := crate.global_position - at
	await d.place(at, atan2(-to.x, -to.z))
	var before := crate.global_position.y
	await d.tap(JOY_BUTTON_RIGHT_SHOULDER)
	await d.secs(0.8)
	d.check(crate.pulled and crate.global_position.y < before - 2.0, "the rope (RB) pulls the crate off its shelf (%.1f m down)" % (before - crate.global_position.y))


func _signet() -> void:
	var c := course.get_node("Councillor_k") as Staff
	# Into the suit.
	await d.place(Vector3(X - 7.0, 0.05, -15.9), PI)
	await d.tap(JOY_BUTTON_Y)
	await d.secs(1.3)
	d.check(d.nim.suit.in_suit(), "the wardrobe: in the suit for the councillor")
	if d.nim.suit.word != &"kneel":
		await d.tap(JOY_BUTTON_DPAD_UP)
	d.nim.known[Lessons.SIGNET] = false
	await d.place(c.global_position + Vector3(0, 0, 2.0), 0.0)
	var before := d.nim.suit.composure
	await d.tap(JOY_BUTTON_Y)
	await d.frames(4)
	d.check(c.state != Staff.State.KNEEL and d.nim.suit.composure < before,
		"without the signet, the councillor won't kneel (and it costs her)")
	d.nim.known[Lessons.SIGNET] = true
	await d.tap(JOY_BUTTON_Y)
	await d.frames(4)
	d.check(c.state == Staff.State.KNEEL, "with Augusta's signet, he kneels")
	# Back into the garb for the rest.
	await d.place(Vector3(X - 7.0, 0.05, -15.9), PI)
	await d.tap(JOY_BUTTON_Y)
	await d.secs(1.3)


func _swing() -> void:
	# Run off B's end (z -30), jump, hold RB: catch the anchor over the gap, swing, let go, land on C (z -42).
	await d.place(Vector3(X, 0.05, -22.0), 0.0)
	d.stick(0, -1)
	await d.until(func() -> bool: return d.nim.global_position.z <= -29.4, 3.0)
	d.button(JOY_BUTTON_A, true)
	await d.frames(6)
	d.button(JOY_BUTTON_RIGHT_SHOULDER, true)
	var caught := await d.until(func() -> bool: return d.nim.state == Nim.State.SWING, 1.0)
	d.button(JOY_BUTTON_A, false)
	d.check(caught, "the rope catches the anchor over the gap %s" % d.at())
	# Let go on the far upswing.
	await d.until(func() -> bool: return d.nim.global_position.z < -38.0 and d.nim.velocity.y > 0.0, 4.0)
	d.button(JOY_BUTTON_RIGHT_SHOULDER, false)
	var landed := await d.until(func() -> bool: return d.nim.is_on_floor(), 3.0)
	d.stick(0, 0)
	d.check(landed and d.nim.global_position.y > -0.1 and d.nim.global_position.z < -42.0,
		"swings across the 12 m gap and lands on the far side %s" % d.at())


func _rope_bind() -> void:
	var g := _goon("k_rope")   # faces -Z; behind him is +Z
	# The swing's landing may have made him wonder: let him settle first.
	await d.place(Vector3(X - 8.0, 0.05, -43.0), 0.0)
	d.button(JOY_BUTTON_B, true)
	await d.until(func() -> bool: return g.state == Enemy.State.PATROL and g.suspicion <= 0.0, 20.0)
	await d.place(g.global_position + Vector3(0, 0, 3.3), 0.0)
	d.button(JOY_BUTTON_B, true)
	await d.frames(10)
	if OS.has_environment("PROBE_TRACE"):
		print("rope: goon %s susp %.2f bindable %s, nim %s floor %s busy %s" % [Enemy.State.keys()[g.state], g.suspicion,
			g.bindable_from(d.nim.global_position), d.at(), d.nim.is_on_floor(), d.nim.combat.busy()])
	await d.tap(JOY_BUTTON_RIGHT_SHOULDER)
	d.button(JOY_BUTTON_B, false)
	await d.secs(0.8)
	d.check(g.is_bound(), "the rope (RB) binds an unaware goon from 3.3 m behind him (the claw's Bind reaches 1.8)")


func _scold() -> void:
	var a := _goon("k_scold1")
	var b := _goon("k_scold2")
	await _select(Lessons.SCOLD)
	d.check(d.nim.gear.selected == Lessons.SCOLD, "D-pad left picks the Scold")
	# Stand where they can see her; when they're on their way and close, Scold.
	await d.place(Vector3(X - 5.0, 0.05, -46.0), PI)
	await d.until(func() -> bool:
		return a.hunting() and b.hunting() and a.global_position.distance_to(d.nim.global_position) < 6.0 \
			and b.global_position.distance_to(d.nim.global_position) < 7.5, 6.0)
	if OS.has_environment("PROBE_TRACE"):
		print("scold: a %s %.1f m, b %s %.1f m, gear %s" % [Enemy.State.keys()[a.state], a.global_position.distance_to(d.nim.global_position),
			Enemy.State.keys()[b.state], b.global_position.distance_to(d.nim.global_position), d.nim.gear.selected])
	await d.tap(JOY_BUTTON_LEFT_SHOULDER)
	await d.frames(3)
	d.check(a.state == Enemy.State.FROZEN and b.state == Enemy.State.FROZEN, "the Scold (LB) freezes both goons coming at her")
	var p := a.global_position
	await d.secs(1.0)
	d.check(a.global_position.distance_to(p) < 0.1, "frozen, they don't move")
	# A frozen goon can be bound.
	await d.place(a.global_position + Vector3(0, 0, 1.2), 0.0)
	await d.tap(JOY_BUTTON_Y)
	await d.secs(0.8)
	d.check(a.is_bound(), "and a frozen goon can be bound")
	# Tidy up the other before he thaws.
	if not b.is_bound():
		await d.place(b.global_position + Vector3(0, 0, 1.2), 0.0)
		if b.state == Enemy.State.FROZEN:
			await d.tap(JOY_BUTTON_Y)
			await d.secs(0.8)


func _pendant() -> void:
	var p := course.get_node("Entranced_k1") as Entranced
	await _select(Lessons.PENDANT)
	await d.place(Vector3(X - 6.0, 0.05, -58.0), 0.0)
	await d.tap(JOY_BUTTON_LEFT_SHOULDER)
	await d.frames(3)
	d.check(p.state == Entranced.State.AWAKE and not d.nim.suit.faking_trance,
		"the pendant (LB) wakes the sleeper %.1f m away" % p.global_position.distance_to(d.nim.global_position))


func _lure() -> void:
	var g := _goon("k_lure")   # at (X+6, -60), looks -X
	var home := g.global_position
	await _select(Lessons.LURE)
	var left: int = d.nim.gear.lures
	await d.place(Vector3(X + 8.0, 0.05, -67.0), PI)   # south of him, out of his view, facing north
	await d.tap(JOY_BUTTON_LEFT_SHOULDER)
	d.check(d.nim.gear.lures == left - 1, "a lure (LB) is thrown (%d left)" % d.nim.gear.lures)
	var drawn := await d.until(func() -> bool:
		return g.state == Enemy.State.SEARCH and g.global_position.distance_to(home) > 2.0, 6.0)
	if OS.has_environment("PROBE_TRACE"):
		for l: Node in get_nodes_in_group(&"lure"):
			print("lure at %s buzzing %s; guard %s susp %.2f last_seen %s" % [(l as Node3D).global_position, l.get(&"buzzing"),
				Enemy.State.keys()[g.state], g.suspicion, g.last_seen])
	d.check(drawn, "it buzzes where it lands, and the guard leaves his post to look (%s, %.1f m off)" % [Enemy.State.keys()[g.state], g.global_position.distance_to(home)])
	d.check(g.suspicion < 1.0 and not g.hunting() or g.state == Enemy.State.SEARCH, "and he never saw her")
