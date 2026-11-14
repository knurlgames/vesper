extends SceneTree
## WO-006's acceptance, with real input in the test course's club (lane J):
##   - The wardrobe puts her in the suit (cover intact, Composure full).
##   - A fight refused in the suit: X at the doorman does nothing (until her cover's blown, below).
##   - Blend in: strutting down the crowded corridor past security who know her face, nobody picks her out and her
##     Composure holds. Out of the crowd in his view, he starts to wonder.
##   - Commands: Kneel on a goon; Fetch (the bartender brings the key) and Open (he opens the back door) on staff; a
##     Fetch to a goon is above his tier: it fails and costs Composure.
##   - Cover blown (failed commands): the doorman comes for her, and now she fights (a strike staggers him).
##   - Recovered at a wardrobe round the corner: a fresh suit, cover back, and the doorman gives up.
##   - Blown again, and Hold the Room: he stands down, cover back.
##   - The fake trance (in the garb): she shuffles past the doorman's nose unnoticed; she runs, it breaks, he notices.
##   godot --headless --fixed-fps 60 --path . -s tools/social_probe.gd

const Driver := preload("res://tools/probe_driver.gd")
const X := 164.0

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
	await _wardrobe_in()
	await _fight_refused()
	await _blend_in()
	await _commands()
	await _blown_and_fight()
	await _wardrobe_recovery()
	await _hold_the_room()
	await _fake_trance()
	print("social probe: %d failures" % d.fails)
	quit(1 if d.fails else 0)


func suit() -> NimSuit:
	return d.nim.suit


func _goon(id: String) -> Enemy:
	return course.get_node("Goon_%s" % id) as Enemy


## Walks (or struts, with push under 0.6) to `to`; true if she got within 0.4 m.
func _walk_to(to: Vector3, push: float, timeout: float) -> bool:
	for i in int(timeout * 60.0):
		var at := d.nim.global_position
		if Vector2(at.x - to.x, at.z - to.z).length() < 0.4:
			d.stick(0, 0)
			return true
		d.steer(to - at, push)
		await physics_frame
	d.stick(0, 0)
	return false


func _use_wardrobe() -> void:
	await d.place(Vector3(X - 7.0, 0.05, 7.1), PI)   # facing it, at its front
	await d.tap(JOY_BUTTON_Y)
	await d.secs(1.3)


func _wardrobe_in() -> void:
	await _use_wardrobe()
	d.check(suit().in_suit() and not suit().cover_blown and is_equal_approx(suit().composure, 1.0),
		"wardrobe: Y puts her in the suit, cover intact, Composure full")


func _fight_refused() -> void:
	var g := _goon("j_doorman")   # at (X + 3.5, 0), looking +Z
	await d.place(g.global_position + Vector3(0, 0, 1.3), 0.0)
	# Without the crop: a fist, refused.
	var had_crop: bool = d.nim.knows(Lessons.CROP)
	d.nim.known[Lessons.CROP] = false
	var before := suit().composure
	await d.tap(JOY_BUTTON_X)
	await d.secs(0.5)
	d.check(g.state == Enemy.State.PATROL and not d.nim.combat.striking(),
		"in the suit, no crop, X at the doorman: she refuses (he's %s)" % Enemy.State.keys()[g.state])
	d.check(suit().composure < before and String(suit().get(&"slip")) == "Refusing a Fight",
		"and the attempt, in his sight, costs Composure, and the HUD says why (%.2f to %.2f, \"%s\")" % [before,
		suit().composure, suit().get(&"slip")])
	# With the crop: X in the suit is the crop, tapped (owner, Deck clip: a tap was a refused punch). No Composure, and
	# never at a goon.
	d.nim.known[Lessons.CROP] = true
	await d.secs(0.6)
	before = suit().composure
	await d.tap(JOY_BUTTON_X)
	await d.frames(2)
	var cracked: bool = d.nim.combat.get(&"_hit") == d.nim.combat.CROP_HIT
	await d.secs(0.6)
	d.check(cracked and suit().composure >= before - 0.001 and g.state == Enemy.State.PATROL,
		"with the crop, a tap of X in the suit cracks it: no Composure lost, the doorman untouched (%.2f to %.2f)" % [
		before, suit().composure])
	d.nim.known[Lessons.CROP] = had_crop


func _blend_in() -> void:
	var guard := _goon("j_security")
	await d.place(Vector3(X, 0.05, -0.6), 0.0)
	var start := suit().composure
	var worst := 0.0
	var lowest := start
	var hidden := 0
	var frames := 0
	for target: Vector3 in [Vector3(X - 2.1, 0, -3.8), Vector3(X - 2.1, 0, -25.0)]:
		for i in 20 * 60:   # the strut's 2.4 m/s (it was 3.2); at half stick, 2.0
			var at := d.nim.global_position
			if Vector2(at.x - target.x, at.z - target.z).length() < 0.4:
				break
			d.steer(target - at, 0.5)
			await physics_frame
			worst = maxf(worst, guard.suspicion)
			lowest = minf(lowest, suit().composure)
			frames += 1
			if suit().hidden_in_crowd:
				hidden += 1
	d.stick(0, 0)
	d.check(d.nim.global_position.z < -24.5 and not suit().cover_blown and worst < 0.3 and lowest >= start - 0.01,
		"blend in: strutting down the crowd past security, unnoticed (his suspicion %.2f, Composure %.2f to %.2f) %s" % [
			worst, start, lowest, d.at()])
	d.check(hidden > frames * 0.7, "and she was lost in the crowd for most of it (%d of %d frames)" % [hidden, frames])
	# Out of the crowd, in his view: he starts to wonder. Then back in, and he forgets.
	# Past the end of the rows, then half a step east: just out of the crowd, about 9 m from him.
	await _walk_to(Vector3(X - 2.1, 0, -26.6), 0.5, 3.0)
	await _walk_to(Vector3(X - 1.1, 0, -26.6), 0.5, 3.0)
	await d.secs(0.1)
	var wondered := guard.suspicion
	await _walk_to(Vector3(X - 2.1, 0, -24.0), 0.5, 3.0)
	var forgot := await d.until(func() -> bool: return guard.suspicion <= 0.0, 6.0)
	d.check(wondered > 0.2 and forgot and not suit().cover_blown,
		"out of the crowd he wonders (%.2f); back in it, he forgets" % wondered)


func _commands() -> void:
	# Kneel: the goon on his rounds.
	var g := _goon("j_rounds")
	await d.place(g.global_position + Vector3(-2.5, 0, 0), -PI / 2.0)   # facing him (+X)
	d.lock_on(true)
	await d.frames(4)
	await d.tap(JOY_BUTTON_Y)
	d.lock_on(false)
	await d.frames(4)
	d.check(g.state == Enemy.State.KNEEL, "Kneel: the goon on his rounds kneels (%s)" % Enemy.State.keys()[g.state])
	# Fetch: the bartender brings the key from the counter.
	var barman := course.get_node("Bartender_j") as Staff
	await d.place(barman.global_position + Vector3(2.5, 0, 0), PI / 2.0)   # facing him (-X)
	await d.tap(JOY_BUTTON_DPAD_RIGHT)
	d.check(suit().word == &"fetch", "the D-pad picks Fetch")
	d.lock_on(true)
	await d.frames(4)
	await d.tap(JOY_BUTTON_Y)
	d.lock_on(false)
	var fetched := await d.until(func() -> bool: return suit().keys.has(&"back_room"), 12.0)
	d.check(fetched, "Fetch: the bartender brings her the key")
	# Open: he opens the back door.
	await d.until(func() -> bool: return barman.state == Staff.State.IDLE, 8.0)
	await d.place(barman.global_position + Vector3(2.5, 0, 0), PI / 2.0)
	await d.tap(JOY_BUTTON_DPAD_DOWN)
	await d.tap(JOY_BUTTON_Y)
	var door := course.get_node("BackDoor_j") as Door
	var opened := await d.until(func() -> bool: return door.is_open, 12.0)
	d.check(opened, "Open: he opens the back door")
	# Above his tier: Fetch to the doorman (a goon) fails, and costs her.
	await d.tap(JOY_BUTTON_DPAD_RIGHT)
	var doorman := _goon("j_doorman")
	await d.place(doorman.global_position + Vector3(0, 0, 2.0), 0.0)
	var before := suit().composure
	await d.tap(JOY_BUTTON_Y)
	await d.frames(4)
	d.check(suit().composure < before - 0.2 and doorman.state == Enemy.State.PATROL,
		"Fetch to a goon is above his tier: it fails (Composure %.2f to %.2f)" % [before, suit().composure])


## Fails commands at the doorman until her cover's blown.
func _blow_cover() -> void:
	var doorman := _goon("j_doorman")
	await d.place(doorman.global_position + Vector3(0, 0, 2.0), 0.0)
	if suit().word != &"fetch":
		await d.tap(JOY_BUTTON_DPAD_RIGHT)
	for i in 8:
		if suit().cover_blown:
			break
		await d.tap(JOY_BUTTON_Y)
		await d.frames(4)


func _blown_and_fight() -> void:
	var doorman := _goon("j_doorman")
	await _blow_cover()
	await d.frames(10)
	d.check(suit().cover_blown and doorman.hunting(), "cover blown: the doorman comes for her (%s)" % Enemy.State.keys()[doorman.state])
	await d.tap(JOY_BUTTON_X)
	var staggered := await d.until(func() -> bool: return doorman.state == Enemy.State.STAGGER, 0.6)
	d.check(staggered, "and now she fights: a strike staggers him")


func _wardrobe_recovery() -> void:
	var doorman := _goon("j_doorman")
	# Round the east end of the wall, then back along it to the wardrobe, out of his sight.
	await _walk_to(Vector3(X - 1.3, 0, 7.2), 1.0, 4.0)
	await _walk_to(Vector3(X - 7.0, 0, 7.1), 1.0, 3.0)
	d.steer(Vector3(0, 0, -1))   # face it
	await d.frames(3)
	d.stick(0, 0)
	await d.tap(JOY_BUTTON_Y)
	await d.secs(1.3)
	d.check(suit().in_suit() and not suit().cover_blown and is_equal_approx(suit().composure, 1.0),
		"wardrobe: a fresh suit, cover back, Composure full")
	var calm := await d.until(func() -> bool: return doorman.state == Enemy.State.PATROL, 25.0)
	d.check(calm and not suit().cover_blown, "and the doorman gives up and goes back to the door (%s)" % Enemy.State.keys()[doorman.state])


func _hold_the_room() -> void:
	var doorman := _goon("j_doorman")
	await _blow_cover()
	await d.frames(10)
	var after := doorman.hunting()
	d.button(JOY_BUTTON_Y, true)
	await d.secs(1.2)
	d.button(JOY_BUTTON_Y, false)
	await d.frames(4)
	d.check(after and not doorman.hunting() and not suit().cover_blown,
		"Hold the Room: blown again, she holds Y and stares him down (%s, cover %s)" % [Enemy.State.keys()[doorman.state], "back" if not suit().cover_blown else "blown"])


func _fake_trance() -> void:
	var doorman := _goon("j_doorman")
	await d.until(func() -> bool: return doorman.state == Enemy.State.PATROL, 15.0)
	await _use_wardrobe()   # into the night garb
	d.check(not suit().in_suit(), "the wardrobe again: back in the night garb")
	if d.nim.gear.selected != Lessons.PENDANT:
		# The gear wheel: hold LB till it opens, point the stick at the pendant, let go.
		d.button(JOY_BUTTON_LEFT_SHOULDER, true)
		await d.until(func() -> bool: return d.nim.gear.wheel_open, 2.0)
		var items: Array = d.nim.gear.wheel_items
		var a := items.find(Lessons.PENDANT) * TAU / maxi(items.size(), 1)
		d.stick(sin(a), -cos(a))
		await d.frames(6)
		d.button(JOY_BUTTON_LEFT_SHOULDER, false)
		d.stick(0, 0)
		await d.frames(4)
	await d.tap(JOY_BUTTON_LEFT_SHOULDER)
	await d.frames(3)   # (LB acts as it's let go)
	d.check(suit().faking_trance, "LB: the pendant's fake trance")
	# Shuffle across in front of him, 2 m off his nose.
	await d.place(doorman.global_position + Vector3(-3.0, 0, 2.0), -PI / 2.0)
	await d.tap(JOY_BUTTON_LEFT_SHOULDER)   # a place clears nothing, but be sure it's on
	await d.frames(3)
	if not suit().faking_trance:
		await d.tap(JOY_BUTTON_LEFT_SHOULDER)
		await d.frames(3)
	var worst := 0.0
	for i in 180:
		d.steer(Vector3(1, 0, 0), 0.4)
		await physics_frame
		worst = maxf(worst, doorman.suspicion)
	d.stick(0, 0)
	d.check(suit().faking_trance and worst <= 0.0, "faking a trance, she shuffles past his nose unnoticed (suspicion %.2f)" % worst)
	d.steer(Vector3(-1, 0, 0), 1.0)
	var noticed := await d.until(func() -> bool: return doorman.suspicion > 0.0, 2.0)
	d.stick(0, 0)
	d.check(not suit().faking_trance and noticed, "she runs: the trance breaks, and he notices her")
