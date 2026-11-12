extends SceneTree
## WO-005's acceptance, with real input in the test course's stealth yard (lane I):
##   - Unseen: crouched down the shaded strip by the west wall, past the patrol, the guard and the lookout, to the far
##     end, and nobody so much as wonders.
##   - The light meter: dark in the wall's shadow, middling in moonlight, bright in a lamp's pool.
##   - Hearing: sneaking up behind the guard he hears nothing; running, he turns to look.
##   - The takedown from above: off, landing beside a goon does nothing; on, landing on him binds him, chase or not.
##   - Spotted: walk into the lamplight, the yard comes after her; she runs for the shed and hides in the dark at the
##     back; they search, give up, and the yard calms down.
##   godot --headless --fixed-fps 60 --path . -s tools/stealth_probe.gd

const Driver := preload("res://tools/probe_driver.gd")
const X := 136.0

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
	await _unseen()
	await _light()
	await _hearing()
	await _drop_takedown()
	await _spotted_and_calm()
	print("stealth probe: %d failures" % d.fails)
	quit(1 if d.fails else 0)


func _goon(id: String) -> Enemy:
	return course.get_node("Goon_%s" % id) as Enemy


func _bird() -> Lookout:
	return course.get_node("Lookout_i") as Lookout


func _yard() -> Array:
	return [_goon("i_patrol"), _goon("i_guard"), _goon("i_drop")]


## Every goon in the yard on his rounds with nothing on his mind, and the lookout calm.
func _calm() -> bool:
	for g: Enemy in _yard():
		if g.is_bound():
			continue
		if g.state != Enemy.State.PATROL or g.suspicion > 0.0:
			return false
	return not _bird().alarmed and _bird().suspicion <= 0.0


func _unseen() -> void:
	await d.place(Vector3(X - 9.4, 0.05, 10.0), 0.0)
	d.button(JOY_BUTTON_B, true)
	d.stick(0, -1)
	var worst := 0.0
	var noticed := false
	var darkest := 1.0
	for i in 20 * 60:
		await physics_frame
		for g: Enemy in _yard():
			worst = maxf(worst, g.suspicion)
			noticed = noticed or g.state != Enemy.State.PATROL
		worst = maxf(worst, _bird().suspicion)
		darkest = minf(darkest, d.nim.light)
		if d.nim.global_position.z < -38.0:
			break
	d.stick(0, 0)
	d.button(JOY_BUTTON_B, false)
	d.check(d.nim.global_position.z < -38.0, "unseen: crouched down the shaded strip to the far end %s" % d.at())
	d.check(not noticed and worst < 0.15 and _bird().alarms == 0,
		"unseen: nobody noticed (highest suspicion %.2f, alarms %d)" % [worst, _bird().alarms])


func _light() -> void:
	var readings := {}
	for spot: Array in [["shadow", Vector3(X - 9.4, 0.05, -15.0)], ["moonlight", Vector3(X - 4.0, 0.05, 6.0)],
			["lamp", Vector3(X + 4.0, 0.05, -11.2)]]:
		await d.place(spot[1], 0.0)
		await d.secs(0.3)
		readings[spot[0]] = d.nim.light
	d.check(readings["shadow"] < 0.1 and readings["moonlight"] > 0.3 and readings["moonlight"] < 0.8 and readings["lamp"] > 0.85,
		"light: shadow %.2f, moonlight %.2f, lamp %.2f" % [readings["shadow"], readings["moonlight"], readings["lamp"]])
	await d.place(Vector3(X - 9.4, 0.05, 10.0), 0.0)
	await d.until(_calm, 30.0)


func _hearing() -> void:
	var g := _goon("i_guard")   # stands at (X - 2, -33) looking +Z: behind him is -Z
	# Sneaking up from 6 m behind: silent.
	await d.place(g.global_position + Vector3(0, 0, -6.5), PI)
	d.button(JOY_BUTTON_B, true)
	d.stick(0, -1)
	await d.secs(1.2)
	d.stick(0, 0)
	d.button(JOY_BUTTON_B, false)
	await d.frames(5)
	d.check(g.state == Enemy.State.PATROL, "hearing: sneaking up behind the guard, he hears nothing (%s)" % Enemy.State.keys()[g.state])
	# Running past behind him: he turns to look.
	await d.place(g.global_position + Vector3(-5, 0, -4.5), -PI / 2.0)
	d.stick(0, -1)
	var heard := await d.until(func() -> bool: return g.state == Enemy.State.SUSPICIOUS or g.state == Enemy.State.SEARCH, 1.5)
	d.stick(0, 0)
	d.check(heard, "hearing: running behind him, he hears her and turns (%s)" % Enemy.State.keys()[g.state])
	# Out of there, into the shade, and wait for the yard to settle.
	await d.place(Vector3(X - 9.4, 0.05, -20.0), 0.0)
	d.button(JOY_BUTTON_B, true)
	var settled := await d.until(_calm, 40.0)
	d.button(JOY_BUTTON_B, false)
	d.check(settled, "hearing: and he goes back to his post")


func _drop_takedown() -> void:
	var g := _goon("i_drop")
	d.nim.can_drop_takedown = false
	await d.place(g.global_position + Vector3(-0.8, 4.5, 0.0), -PI / 2.0)
	await d.until(func() -> bool: return d.nim.is_on_floor(), 2.0)
	await d.secs(0.8)
	d.check(not g.is_bound(), "from above, unlearned: landing beside him doesn't bind him (%s)" % Enemy.State.keys()[g.state])
	d.nim.can_drop_takedown = true
	await d.place(g.global_position + Vector3(-0.5, 4.5, 0.0), -PI / 2.0)
	var was: String = Enemy.State.keys()[g.state]
	await d.until(func() -> bool: return d.nim.is_on_floor(), 2.0)
	await d.secs(0.7)
	d.check(g.is_bound(), "from above, learned: landing on him binds him, even mid-%s" % was)
	await d.place(Vector3(X - 9.4, 0.05, -20.0), 0.0)
	d.button(JOY_BUTTON_B, true)
	await d.until(_calm, 40.0)
	d.button(JOY_BUTTON_B, false)


func _spotted_and_calm() -> void:
	# Stroll into the lamplight in front of the patrol.
	var p := _goon("i_patrol")
	await d.place(Vector3(X + 1.0, 0.05, -12.0), 0.0)
	var spotted := await d.until(func() -> bool:
		return _yard().any(func(g: Enemy) -> bool: return g.state == Enemy.State.CHASE or g.state == Enemy.State.FIGHT), 6.0)
	d.check(spotted, "spotted: standing in the lamplight, the yard comes for her (patrol %s)" % Enemy.State.keys()[p.state])
	# Run for the shed (its mouth faces north at z 5, x X+6) and hide at the back, crouched.
	var shed := Vector3(X + 6.0, 0.0, 9.6)
	d.steer(Vector3(X + 6.0, 0, 3.0) - d.nim.global_position)
	await d.until(func() -> bool: return d.nim.global_position.z > 2.5, 4.0)
	for i in 120:
		d.steer(shed - d.nim.global_position)
		await physics_frame
		if Vector2(d.nim.global_position.x - shed.x, d.nim.global_position.z - shed.z).length() < 0.4:
			break
	d.stick(0, 0)
	d.button(JOY_BUTTON_B, true)
	var lost := await d.until(func() -> bool:
		return not _yard().any(func(g: Enemy) -> bool: return g.state == Enemy.State.CHASE or g.state == Enemy.State.FIGHT), 10.0)
	d.check(lost, "escaped: in the dark at the back of the shed, they lose her %s" % d.at())
	var calm := await d.until(_calm, 60.0)
	d.button(JOY_BUTTON_B, false)
	var states := _yard().map(func(g: Enemy) -> String: return Enemy.State.keys()[g.state])
	d.check(calm and d.nim.combat.health > 0, "calm: the yard settles back to its rounds (%s; lookout %s)" % [str(states), "calm" if not _bird().alarmed else "alarmed"])
