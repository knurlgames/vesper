extends RefCounted
## The Pier played step by step with real input, shared by the probes (WO-014): pier_keys_probe and pier_boss_probe
## run groups of these on a fresh Pier; pier_flow runs all of them in one game, from the prologue on. Each step
## checks what it should through the driver (d.check) and leaves Nim somewhere sensible.

const Driver := preload("res://tools/probe_driver.gd")
const SAND := -6.0
const BEAM_Y := -3.2
const WHEEL := Vector3(-24, 16, -205)

var tree: SceneTree
var d: Driver
var pier: Node
var game: Node
var dialogue: Node


func _init(t: SceneTree, driver: Driver, level: Node) -> void:
	tree = t
	d = driver
	pier = level
	game = t.root.get_node("/root/Game")
	dialogue = t.root.get_node("/root/Dialogue")


# --- helpers ---------------------------------------------------------------------------------------------------------

func remove(n: Node) -> void:
	if n:
		n.get_parent().remove_child(n)
		n.queue_free()


func goon(id: String) -> Enemy:
	return pier.get_node_or_null("Goon_%s" % id) as Enemy


func has_key(id: StringName) -> bool:
	return game.call(&"has_collected", &"key", &"pier", id)


## A deed's rose is tossed down from out of sight and lands after Pickup.TOSS_TIME: wait for it to land, and if she's
## moved on from where it fell, go and pick it up (as a player would, seeing it land).
## (The five-woken rose and a tin's are tossed down in front of her too: Game._earn, World._on_rose_earned. A tin's
## is the hub's.)
func got(id: StringName, secs := 3.0, world: StringName = &"pier") -> bool:
	var mine := func() -> bool: return game.call(&"has_collected", &"key", world, id)
	if await d.until(mine, 1.6):
		return true
	var rose := pier.get_node_or_null("Key_%s" % id) as Node3D
	if rose:
		await walk_to(rose.global_position, secs, 0.3)
	return await d.until(mine, 1.0)


func flag(f: String) -> bool:
	return game.call(&"has_flag", f)


func health() -> int:
	return d.nim.combat.health


func walk_to(target: Vector3, timeout := 20.0, near := 0.6) -> bool:
	var ok := await d.until(func() -> bool:
		var to := target - d.nim.global_position
		to.y = 0.0
		if to.length() < near:
			return true
		d.steer(to)
		return false, timeout)
	d.stick(0, 0)
	return ok


## Holds the stick toward `dir` (re-aimed every frame) until `cond`. On a wall the stick reads raw: up is up.
func push(dir: Vector3, cond: Callable, timeout: float, amount := 1.0) -> bool:
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


## Waits for a conversation to start, then reads it through (first choice each time).
func converse(what: String, timeout := 3.0) -> bool:
	var started := await d.until(func() -> bool: return dialogue.call(&"is_active"), timeout)
	var ended := started and await d.talk_through(40.0)
	d.check(started and ended, what)
	return started and ended


## A running jump toward `target`; true if she lands on something about `land_y` high.
func leap(target: Vector3, land_y: float) -> bool:
	var to := target - d.nim.global_position
	to.y = 0.0
	d.steer(to)
	await d.frames(3)
	await d.jump(0.4)
	var ok := await d.until(func() -> bool:
		var t := target - d.nim.global_position
		t.y = 0.0
		d.steer(t)
		return d.nim.is_on_floor() and d.nim.global_position.y > land_y - 0.3, 3.0)
	d.stick(0, 0)
	return ok


## Stood on a beam right over a goon: B drops her off its side (toward `side`), onto him.
func drop_on(g: Enemy, on_beam: Vector3, side: Vector3, what: String) -> void:
	var along := Vector3(-side.z, 0, side.x)
	if d.nim.global_position.distance_to(on_beam) > 0.5:
		await d.place(on_beam + Vector3(0, 0.05, 0), atan2(-along.x, -along.z))
	d.steer(side, 0.5)
	await d.frames(2)
	await d.tap(JOY_BUTTON_B)
	d.stick(0, 0)
	var got := await d.until(func() -> bool: return g.is_bound(), 3.0)
	d.check(got, "%s %s" % [what, d.at()])
	await d.secs(0.3)


# --- the Keys --------------------------------------------------------------------------------------------------------

func lesson() -> void:
	# Walking in under the pier toward the four: Vesper stops her.
	await d.place(Vector3(-6.0, SAND + 0.05, -15.0), 0.0)
	d.steer(Vector3.FORWARD)
	var started := await d.until(func() -> bool: return dialogue.call(&"is_active"), 3.0)
	d.stick(0, 0)
	var shot := tree.root.get_viewport().get_camera_3d()
	d.check(started and shot != null and shot.name == "LessonShot",
		"Vesper stops her, and the lesson's own camera frames her and the smuggler (%s)" % (shot.name if shot else "none"))
	await converse("Vesper: stop there, watch the one under me")
	await converse("she drops onto him, binds him, and teaches the takedown from above", 4.0)
	var mark := goon("u_lesson1")
	d.check(mark.is_bound() and d.nim.knows(Lessons.TAKEDOWN_ABOVE) and flag(Lessons.TAKEDOWN_ABOVE),
		"the first smuggler is tied, and Nim knows the takedown from above")
	await drop_on(goon("u_lesson2"), Vector3(-6.0, BEAM_Y, -42.0), Vector3.RIGHT, "off the stringer onto the second")
	await drop_on(goon("u_lesson3"), Vector3(0.0, BEAM_Y, -50.0), Vector3.FORWARD, "off the cross-beam onto the third")
	await drop_on(goon("u_lesson4"), Vector3(6.0, BEAM_Y, -58.0), Vector3.LEFT, "off the other stringer onto the fourth")
	await converse("all three tied: Vesper's word, and she's off to the wheel")
	# She walks off down the sandbar now (no vanishing): she's gone when she's out of sight down there.
	var gone := await d.until(func() -> bool: return pier.get_node_or_null("VesperLesson/Vesper_lesson") == null, 25.0)
	d.check(flag("pier/lesson_done") and gone, "the lesson's done, and she walks off down the sandbar")


func landing() -> void:
	# The one on his rounds walks the line under the z -100 cross-beam (x -12 to -4): wait on the beam at x -8 and drop
	# as he comes under.
	var crew1 := goon("u_crew1")
	await d.place(Vector3(-8.0, BEAM_Y + 0.05, -100.0), PI / 2.0)
	await d.until(func() -> bool:
		var x := crew1.global_position.x
		return absf(x + 8.0) < 1.0 and signf(crew1.velocity.x) == signf(-8.0 - x), 15.0)
	await drop_on(crew1, Vector3(-8.0, BEAM_Y, -100.0), Vector3.BACK, "the landing: onto the one on his rounds")
	await drop_on(goon("u_crew2"), Vector3(-6.0, BEAM_Y, -110.0), Vector3.RIGHT, "the landing: onto the second")
	await drop_on(goon("u_crew3"), Vector3(6.0, BEAM_Y, -104.0), Vector3.LEFT, "the landing: onto the third")
	await converse("the fourth, tied up by himself, has a word")
	var keen := goon("u_crew4")
	await walk_to(keen.global_position + Vector3(-1.2, 0, 0), 8.0, 0.3)
	await d.secs(0.3)
	d.check(await got(&"pier_02"), "Key 2: the smugglers' landing")


func race() -> void:
	await d.place(Vector3(63.0, 0.05, 14.6), -PI / 2.0)
	await d.tap(JOY_BUTTON_Y)
	await converse("Dash offers the race, and Nim's on")
	d.check(flag("pier/race_on"), "the race is on: meet her at the gate")
	var ok := await walk_to(Vector3(10.0, 0, 14.0), 15.0)
	ok = ok and await walk_to(Vector3(-2.5, 0, 5.0), 8.0)
	d.check(ok, "Nim at the gate %s" % d.at())
	var r: Node = pier.get_node("DashRace")
	# She runs over from her hut (no teleport): the count waits for her.
	var go := await d.until(func() -> bool: return r.get(&"phase") == 3, 14.0)
	d.check(go, "Dash counts them in, and goes on two")
	for p: Vector3 in [Vector3(6.5, 0, -6.5), Vector3(8.5, 0, -10.0), Vector3(8.5, 0, -104.0), Vector3(18.0, 0, -110.0),
			Vector3(19.1, 0, -123.0)]:
		ok = ok and await walk_to(p, 20.0)
	ok = ok and await push(Vector3.LEFT, func() -> bool:
		return d.nim.state == Nim.State.MOVE and d.nim.is_on_floor() and d.nim.global_position.y > 9.0, 10.0)
	for p: Vector3 in [Vector3(10.0, 0, -126.0), Vector3(0.0, 0, -150.5), Vector3(0.0, 0, -156.0)]:
		ok = ok and await walk_to(p, 25.0)
	# The last stretch: crossing the line starts the conversation, which pauses the world.
	var dash_left := [0.0]
	ok = ok and await d.until(func() -> bool:
		if dialogue.call(&"is_active"):
			return true
		d.steer(Vector3(0, 0, -251.0) - d.nim.global_position)
		dash_left[0] = float(r.get(&"_length")) - float(r.get(&"_time"))
		return false, 25.0)
	d.stick(0, 0)
	d.check(ok, "over the Fun Palace's roof and over the line, with Dash %.1f s behind %s" % [dash_left[0], d.at()])
	await converse("she won: Dash let her, obviously, and hands over the crop")
	d.check(d.nim.knows(Lessons.CROP) and flag("pier/race_won"), "Nim has the crop")
	var p := d.nim.global_position
	await walk_to(Vector3(p.x, 0, p.z - 1.5), 4.0, 0.3)
	await d.secs(0.3)
	d.check(await got(&"pier_01"), "Key 1: beat Dash")


## Dash's way onto the west walkway, followed (owner, Deck review 3: "nearly impossible to climb"): hop the Midway's
## west rail onto the strip, up the crate (1 m) and the stack (2 m), and over the fence's capped top (3 m) down onto
## the walkway behind.
func fence() -> void:
	await d.place(Vector3(-14.0, 0.05, -109.0), PI / 2.0)
	var over_rail := await leap(Vector3(-17.6, 0, -109.6), 0.0)
	d.check(over_rail and d.nim.global_position.x < -16.2 and d.nim.global_position.y > -0.3,
		"over the Midway's west rail onto the strip by the fence %s" % d.at())
	await walk_to(Vector3(-18.5, 0, -109.4), 3.0, 0.25)
	var low := await _step_up(Vector3(-18.5, 1.0, -110.5))
	d.check(low, "up onto the crate (1 m) %s" % d.at())
	var high := await _step_up(Vector3(-18.5, 2.0, -111.5))
	d.check(high, "up onto the stack (2 m) %s" % d.at())
	var target := Vector3(-19.0, 0, -114.5)
	d.steer(target - d.nim.global_position)
	await d.frames(2)
	await d.jump(0.4)
	var over := await d.until(func() -> bool:
		d.steer(target - d.nim.global_position)
		return d.nim.is_on_floor() and d.nim.global_position.z < -112.8 and d.nim.global_position.y < 0.3, 6.0)
	d.stick(0, 0)
	var p := d.nim.global_position
	d.check(over and p.x > -20.0 and p.x < -18.0, "over the fence's cap and down onto the west walkway %s" % d.at())


## A hop up onto the top at `top` (a crate's), from beside it: up first, then steered over it until she's above it, then
## let go, so she stops there.
func _step_up(top: Vector3) -> bool:
	d.stick(0, 0)
	await d.frames(15)   # settled first: still sliding from the walk up, she drifts off the crate
	d.button(JOY_BUTTON_A, true)
	var held := [0]
	var ok := await d.until(func() -> bool:
		held[0] += 1
		if held[0] == 6:   # a short hop: a full one carries her past the crate
			d.button(JOY_BUTTON_A, false)
		var t := top - d.nim.global_position
		t.y = 0.0
		if t.length() > 0.2 and held[0] > 4:
			d.steer(t)
		else:
			d.stick(0, 0)
		return held[0] > 10 and d.nim.is_on_floor() and absf(d.nim.global_position.y - top.y) < 0.2, 3.0)
	d.button(JOY_BUTTON_A, false)
	d.stick(0, 0)
	await d.frames(10)
	return ok and absf(d.nim.global_position.y - top.y) < 0.2


func striker() -> void:
	await d.place(Vector3(13.4, 0.05, -41.0), PI / 2.0)
	var up := await push(Vector3.LEFT, func() -> bool:
		return d.nim.state == Nim.State.MOVE and d.nim.is_on_floor() and d.nim.global_position.y > 10.0, 10.0)
	d.check(up, "up the high striker to its cap %s" % d.at())
	await walk_to(Vector3(12.0, 0, -41.0), 2.0, 0.2)
	d.steer(Vector3.LEFT, 0.25)
	await d.frames(10)
	d.stick(0, 0)
	await d.tap(JOY_BUTTON_X, 0.45)
	var bell: CropTarget = pier.get_node("Striker/StrikerBell")
	var rang := await d.until(func() -> bool: return bell.struck, 1.5)
	await d.secs(0.4)
	await walk_to(Vector3(12.3, 0, -41.0), 2.0, 0.15)
	await d.secs(0.3)
	d.check(rang and await got(&"pier_04"), "Key 4: the bell cracked from the cap %s" % d.at())


## A crop flick shuts a gull up, for good (a gull of its own, so the step doesn't depend on the pier's).
func hush_a_gull() -> void:
	var gull := Lookout.new()
	gull.name = "Gull_probe"
	gull.perch_height = 3.6
	gull.position = Vector3(3.0, 0.0, -30.0)
	pier.add_child(gull)
	await d.place(Vector3(3.0, 0.05, -27.8), 0.0)
	await d.tap(JOY_BUTTON_X, 0.45)
	var hushed := await d.until(func() -> bool: return gull.hushed, 1.5)
	d.check(hushed and flag("hushed/pier/Gull_probe") and not gull.alarmed, "a crop flick shuts a gull up, for good")


func safe() -> void:
	await d.place(Vector3(15.6, 0.05, -148.2), -PI / 4.0)
	await d.tap(JOY_BUTTON_Y)
	await converse("the safe: Laffer's Coalition card, and a goon starts counting")
	var s: Node = pier.get_node("Safe")
	d.check(s.get(&"counting"), "the count's on")
	await walk_to(Vector3(6.8, 0, -144.9), 6.0, 0.3)
	await d.tap(JOY_BUTTON_Y)
	await d.frames(4)
	await walk_to(Vector3(4.0, 0, -144.9), 4.0)
	await d.secs(0.4)
	d.check(await got(&"pier_06"), "Key 6: out of the office before ten %s" % d.at())


## Key 8: a ride in a wheel car (not Vesper's) to the top, and a jump onto the crown; Vesper's in the car next to it.
func wheel() -> void:
	var w: Node3D = pier.get(&"wheel")
	var cars: Array = w.get(&"car_bodies")
	var low := -1
	for i in cars.size():
		if (cars[i] as Node).get_node_or_null("Vesper_wheel") != null:
			continue
		if low < 0 or (cars[i] as Node3D).global_position.y < (cars[low] as Node3D).global_position.y:
			low = i
	var car := cars[low] as Node3D
	await d.place(car.global_position + Vector3(0, 0.1, 0), -PI / 2.0)
	var top := await d.until(func() -> bool:
		var p := car.global_position - WHEEL
		return p.y > 11.0 and absf(p.z) < 0.6, 40.0)
	d.check(top, "a wheel car carries her to the top %s" % d.at())
	d.steer(Vector3.RIGHT)
	await d.jump()
	var got := await d.until(func() -> bool: return has_key(&"pier_08"), 3.0)
	d.stick(0, 0)
	d.check(got, "Key 8: the jump onto the crown %s" % d.at())
	await converse("Vesper, in the car next to it: \"You took your time.\"", 3.0)


## Key 10: the five prize winners, each woken with a strike at the plushie, from in front (garb: the suit won't).
func sleepers() -> void:
	for id: String in ["s1", "s2", "s3", "s4", "s5"]:
		var e := pier.get_node("Entranced_%s" % id) as Node3D
		var woke := false
		for i in 6:
			var f := -e.global_basis.z
			await d.place(e.global_position + f * 1.2, atan2(f.x, f.z))
			await d.tap(JOY_BUTTON_X)
			await d.secs(0.5)
			if game.call(&"has_collected", &"freed", &"pier", StringName(id)):
				woke = true
				break
		d.check(woke, "the prize winner %s woken" % id)
	d.check(await got(&"pier_10"), "Key 10: all five woken, and the rose tossed down for it picked up")


## The Coalition's collection tin on the gate: smashed, it pays the hub its Key.
func tin() -> void:
	await d.place(Vector3(5.5, 0.05, 4.4), 0.0)
	await d.tap(JOY_BUTTON_X)
	d.check(await got(&"tin_pier", 3.0, &"hub"), "the collection tin, smashed: the hub's rose (tin_pier) tossed down and picked up")


func dipper() -> void:
	var dip: Node = pier.get_node("Dipper")
	await d.place(Vector3(19.0, 1.45, -164.0), -PI / 2.0)
	var off := await d.until(func() -> bool: return dip.get(&"phase") == 1, 2.0)
	d.check(off, "the Big Dipper: the courier jumps a car with the ledger")
	var ok := await walk_to(Vector3(25.8, 0, -167.4), 6.0, 0.3)
	ok = ok and await walk_to(Vector3(25.8, 0, -198.6), 30.0, 0.4)
	d.check(ok and d.nim.global_position.y > 17.8, "up the catwalk beside the lift hill %s" % d.at())
	ok = await walk_to(Vector3(24.2, 0, -205.0), 5.0, 0.3)
	ok = ok and await walk_to(Vector3(17.8, 0, -205.0), 8.0, 0.3)
	d.check(ok and d.nim.global_position.y > 17.8, "out along the beam toward the first strut tower %s" % d.at())
	ok = await leap(Vector3(14.0, 0, -210.0), 15.5)
	d.check(ok, "the gap to the first strut tower %s" % d.at())
	ok = await walk_to(Vector3(13.0, 0, -211.2), 3.0, 0.3)
	ok = ok and await walk_to(Vector3(7.0, 0, -219.6), 12.0, 0.4)
	d.check(ok and absf(d.nim.global_position.y - 13.0) < 0.3, "down the beam to the second %s" % d.at())
	ok = await walk_to(Vector3(5.5, 0, -221.0), 3.0, 0.3)
	ok = ok and await leap(Vector3(2.8, 0, -226.5), 12.0)
	d.check(ok, "the gap to the switch tower %s" % d.at())
	await walk_to(Vector3(3.0, 0, -227.2), 3.0, 0.3)
	d.steer(Vector3(1.1, 0, -0.8), 0.25)
	await d.frames(10)
	d.stick(0, 0)
	await d.tap(JOY_BUTTON_X, 0.45)
	var cracked := await d.until(func() -> bool: return dip.get(&"diverted"), 1.5)
	d.check(cracked, "the points cracked with the crop: he's for the spur")
	ok = await walk_to(Vector3(1.5, 0, -225.2), 3.0, 0.3)
	ok = ok and await walk_to(Vector3(-5.2, 0, -199.6), 25.0, 0.4)
	ok = ok and await walk_to(Vector3(-6.0, 0, -197.0), 3.0, 0.3)
	d.check(ok and absf(d.nim.global_position.y - 10.4) < 0.3, "along to the platform by the spur's crest %s" % d.at())
	var car: Node3D = dip.get(&"car")
	# First, let him go: down the drop without her, and he laughs and goes round again, the points set back.
	var missed := await d.until(func() -> bool: return dip.get(&"phase") == 3, 60.0)
	missed = missed and await d.until(func() -> bool: return dip.get(&"phase") == 1, 20.0)
	d.check(missed and not dip.get(&"diverted") and not dip.get(&"on_spur"),
		"miss him, and he's round again with the points set back")
	await d.place(Vector3(3.0, 12.05, -227.2), atan2(-1.1, 0.8))   # facing the points
	d.steer(Vector3(1.1, 0, -0.8), 0.25)
	await d.frames(10)
	d.stick(0, 0)
	await d.tap(JOY_BUTTON_X, 0.45)
	cracked = await d.until(func() -> bool: return dip.get(&"diverted"), 1.5)
	d.check(cracked, "the points cracked again")
	await d.place(Vector3(-6.0, 10.45, -197.0), PI / 2.0)
	var coming := await d.until(func() -> bool:
		return dip.get(&"phase") == 3 and car.global_position.z > d.nim.global_position.z - 0.8, 60.0)
	d.check(coming, "his car stalls at the crest, then tips toward the drop")
	d.steer(Vector3.LEFT)
	await d.jump(0.3)
	var caught := await d.until(func() -> bool: return dip.get(&"phase") >= 4, 3.0)
	d.stick(0, 0)
	d.check(caught, "into his car, and he's tied %s" % d.at())
	await converse("the ledger (demonstration parties in Primrose Close), and the ride photo: she buys it", 4.0)
	d.check(d.nim.global_position.distance_to(car.global_position) < 1.5,
		"and she rides the car down beside him %s" % d.at())
	await d.secs(0.4)
	d.check(await got(&"pier_09") and flag("pier/ledger"), "Key 9: the Big Dipper, and the ledger")


func gallery() -> void:
	var g: Node = pier.get_node("Gallery")
	await d.place(Vector3(-8.5, 0.05, -30.0), PI / 2.0)
	await d.tap(JOY_BUTTON_Y)
	await converse("the barker: six targets, thirty seconds")
	d.check(g.get(&"playing"), "the gallery's game is on")
	var c0: float = d.nim.suit.composure
	# Stand at the counter facing the rails, and crack the crop whenever a live target slides into the arc in front.
	await d.until(func() -> bool:
		if not g.get(&"playing"):
			return true
		var live: Array = (g.get(&"_targets") as Array).filter(func(t: Node3D) -> bool: return t.visible)
		var ahead := live.any(func(t: Node3D) -> bool: return absf(t.global_position.z - d.nim.global_position.z) < 1.2)
		d.button(JOY_BUTTON_X, ahead and not d.nim.combat.striking())
		return false, 34.0)
	d.release_all()
	d.check(flag("pier/gallery_won"), "all six cracked in time (%d hit)" % g.get(&"hits"))
	await converse("the prize is one of Swyne's toys: confiscated")
	d.check(absf(d.nim.suit.composure - c0) < 0.05 and not d.nim.suit.cover_blown,
		"a Domme's crop costs her no Composure (%.2f to %.2f)" % [c0, d.nim.suit.composure])
	await walk_to(Vector3(-8.0, 0, -30.0), 4.0, 0.3)
	await d.secs(0.3)
	d.check(await got(&"pier_03"), "Key 3: the shooting gallery")


func pearl() -> void:
	await d.place(Vector3(-12.6, 0.05, -57.0), PI / 2.0)
	var c0: float = d.nim.suit.composure
	await d.tap(JOY_BUTTON_Y)
	await converse("Madame Pearl: haggled in character, and a reading")
	d.check(flag("pier/pearl_sold") and d.nim.suit.composure >= c0 - 0.01 and not d.nim.suit.cover_blown,
		"the sale, with no slips (Composure %.2f)" % d.nim.suit.composure)
	await walk_to(Vector3(-11.4, 0, -57.0), 4.0, 0.3)
	await d.secs(0.3)
	d.check(await got(&"pier_05"), "Key 5: Madame Pearl")


func clerk() -> void:
	var c: Staff = pier.get_node("Clerk")
	await d.place(Vector3(-11.8, 0.05, -143.4), 0.0)
	d.lock_on(true)
	await d.frames(4)
	await d.tap(JOY_BUTTON_Y)
	d.lock_on(false)
	await d.frames(4)
	d.check(c.state == Staff.State.KNEEL, "the clerk kneels (%s)" % Staff.State.keys()[c.state])
	var c0: float = d.nim.suit.composure
	var ok := await walk_to(Vector3(-5.3, 0, -143.4), 6.0)
	ok = ok and await walk_to(Vector3(-5.3, 0, -148.8), 6.0)
	ok = ok and await walk_to(Vector3(-6.6, 0, -149.2), 4.0, 0.25)
	ok = ok and await push(Vector3.FORWARD, func() -> bool:
		return d.nim.state == Nim.State.MOVE and d.nim.is_on_floor() and d.nim.global_position.y > 3.2, 8.0)
	d.check(ok, "round the counter and up the prize wall's ladder %s" % d.at())
	await walk_to(Vector3(-11.8, 0, -150.6), 6.0, 0.3)
	await d.secs(0.3)
	d.check(has_key(&"pier_07") and not d.nim.suit.cover_blown,
		"Key 7: off the top shelf, with nobody watching (Composure %.2f to %.2f)" % [c0, d.nim.suit.composure])


# --- Laffer ----------------------------------------------------------------------------------------------------------

func boss() -> Node:
	return pier.get_node("Laffer")


func boss_phase() -> int:
	return boss().get(&"phase")


func boss_enter(test_retry := true) -> void:
	var b := boss()
	d.check(not pier.get_node("HallDoors").call(&"is_locked") and pier.get_node_or_null("ShutterSign") == null,
		"with the ledger, the Prize Hall's doors swing open")
	await d.place(Vector3(0.0, 0.05, -254.0), 0.0)
	await walk_to(Vector3(0.0, 0, -264.0), 6.0)
	await converse("in, and Laffer's welcome")
	d.check(pier.get_node("HallDoors").call(&"is_locked") and boss_phase() == 2, "the door locks behind her; the Cackling Crane")
	if not test_retry:
		return
	# Downed in the fight, she's put back at the checkpoint outside: the door opens and the phase waits.
	await d.place(Vector3(0.0, 0.05, -252.0), 0.0)
	await d.frames(5)
	d.check(not pier.get_node("HallDoors").call(&"is_locked") and boss_phase() == 1, "out of the fight, the door opens")
	await walk_to(Vector3(0.0, 0, -264.0), 6.0)
	await d.frames(5)
	d.check(boss_phase() == 2 and not dialogue.call(&"is_active"), "back in, the Cackling Crane again (no second welcome)")


func boss_claw() -> void:
	var b := boss()
	# Side-step: when it shakes, run.
	await walk_to(Vector3(-6.0, 0, -276.0), 6.0)
	var h0 := health()
	var aimed := await d.until(func() -> bool: return b.get(&"claw_state") == 1, 15.0)
	await walk_to(d.nim.global_position + Vector3(4.0, 0, 0), 2.0, 0.4)
	var stuck := await d.until(func() -> bool: return b.get(&"claw_state") == 3, 3.0)
	d.check(aimed and stuck and health() == h0, "the claw shakes and drops where she was: side-stepped (health %d)" % health())
	# Stand still under it this time.
	await d.until(func() -> bool: return b.get(&"claw_state") == 0, 8.0)
	await d.until(func() -> bool: return b.get(&"claw_state") == 3, 15.0)
	d.check(health() == h0 - 1, "stood under it, she's hit (health %d)" % health())
	# Stuck: up its cable and onto the bridge.
	await d.secs(1.0)
	var cable: Node3D = b.get(&"cable")
	var at := cable.global_position
	var ok := await walk_to(Vector3(at.x, 0, at.z + 0.8), 4.0, 0.3)
	ok = ok and await push(Vector3.FORWARD, func() -> bool:
		return d.nim.state == Nim.State.MOVE and d.nim.is_on_floor() and d.nim.global_position.y > 13.3, 10.0)
	d.check(ok, "up the stuck claw's cable to the crane's bridge %s" % d.at())
	var bz: float = b.get(&"_bridge_z")
	ok = await walk_to(Vector3(d.nim.global_position.x, 0, bz), 3.0, 0.25)
	# Onto the gallery he flees (a conversation starts, and the walk stops there).
	ok = ok and await d.until(func() -> bool:
		if dialogue.call(&"is_active"):
			return true
		d.steer(Vector3(20.3, 0, bz) - d.nim.global_position)
		return false, 15.0)
	d.stick(0, 0)
	d.check(ok and d.nim.global_position.x > 19.0, "along the bridge to his gallery %s" % d.at())
	await converse("he's off down the chute")
	d.check(boss_phase() == 3, "whack-a-goon")


func boss_whack() -> void:
	var b := boss()
	# Off the gallery's edge to the floor.
	var bz: float = b.get(&"_bridge_z")
	var off_z := bz + 3.0 if bz < -270.0 else bz - 3.0
	await walk_to(Vector3(20.3, 0, off_z), 4.0, 0.4)
	await walk_to(Vector3(16.0, 0, off_z), 4.0, 0.4)
	await d.until(func() -> bool: return d.nim.is_on_floor() and d.nim.global_position.y < 0.5, 4.0)
	var ok := await d.until(func() -> bool:
		if boss_phase() != 3:
			return true
		# The goons that come up are cleared off (this is about Laffer; the fights are combat_probe's).
		for n: Node in pier.find_children("Goon_hall_*", "Enemy", true, false):
			remove(n)
		if not b.get(&"_hinted") and not b.get(&"_laffer_up"):
			d.stick(0, 0)
			return false
		var h: int = b.get(&"_next_hatch") if not b.get(&"_laffer_up") else b.get(&"_last_hatch")
		var spot: Vector3 = b.call(&"_hatch", h)
		var to := spot - d.nim.global_position
		to.y = 0.0
		if to.length() > 1.2:
			d.steer(to)
			d.button(JOY_BUTTON_X, false)
		else:
			d.steer(to, 0.2)
			d.button(JOY_BUTTON_X, b.get(&"_laffer_up") and not d.nim.combat.striking())
		return false, 90.0)
	d.release_all()
	d.check(ok and b.get(&"hits") >= 3, "hit him three times as he pops up (%d)" % b.get(&"hits"))
	d.check(b.get(&"goons_spawned") >= 1, "goons came up the hatches (%d)" % b.get(&"goons_spawned"))


func boss_mountain() -> void:
	var b := boss()
	d.check(boss_phase() == 4, "the prize mountain")
	await walk_to(Vector3(2.0, 0, -279.0), 6.0)
	await converse("the toy: \"...Huh.\"")
	var h0 := health()
	# Up the steps: run at each one and jump.
	var top := await d.until(func() -> bool:
		if d.nim.global_position.y > 7.4 and d.nim.is_on_floor():
			return true
		d.steer(Vector3(2.0, 0, -296.0) - d.nim.global_position)
		if d.nim.is_on_floor():
			d.button(JOY_BUTTON_A, true)
		else:
			d.button(JOY_BUTTON_A, d.nim.velocity.y > 0.0)
		return false, 30.0)
	d.release_all()
	d.check(top, "up the prize mountain through the boxes (health %d to %d) %s" % [h0, health(), d.at()])
	var laffer: Node3D = b.get(&"laffer")
	d.steer(laffer.global_position - d.nim.global_position)
	await d.frames(3)
	await d.pounce()
	var caught := await d.until(func() -> bool: return boss_phase() == 5, 2.0)
	d.stick(0, 0)
	d.check(caught, "a pounce at the top: he's tied")
	await converse("the WINNER rosette", 6.0)
	# Then Vesper at the door, and the morning paper: read on until it's all done.
	for i in 60:
		if flag("done/pier") and not dialogue.call(&"is_active"):
			break
		if dialogue.call(&"is_active"):
			await d.talk_through(30.0)
		else:
			await d.secs(0.25)
	d.check(flag("done/pier") and flag("pier/laffer_bound"), "the Pier's done")
	d.check(not pier.get_node("HallDoors").call(&"is_locked") and pier.get_node_or_null("Laffer/Vesper_hall") != null,
		"the door's open, and Vesper waits by it")
