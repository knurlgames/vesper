extends SceneTree
## WO-004's acceptance, with real input on the test course:
##   H: a sentry caught unaware is bound without a fight; strikes pass through someone in a trance (and Y can't bind
##      them); breaking their device from in front wakes them.
##   G: the checkpoint; a goon's punch costs health; downed, she's back at the checkpoint, healthy; lock-on; the combo
##      staggers, then knocks down; she fights and binds all three goons.
##   Then the course is reloaded, and reloaded again from a save: every bound goon is still bound, and the woken person
##   is still awake.
##   godot --headless --fixed-fps 60 --path . -s tools/combat_probe.gd

const Driver := preload("res://tools/probe_driver.gd")

var d: Driver
var course: Node
var game: Node


func _initialize() -> void:
	await process_frame
	game = root.get_node("/root/Game")
	game.set(&"persist", false)
	game.call(&"reset")
	game.call(&"set_setting", "age_confirmed", true)
	await _load()
	await _unaware()
	await _entranced()
	await _hurt_and_down()
	await _brawl()
	await _persist()
	print("combat probe: %d failures" % d.fails)
	quit(1 if d.fails else 0)


func _load() -> void:
	if course:
		course.queue_free()
		await process_frame
	course = load("res://levels/test_course/course.tscn").instantiate()
	root.add_child(course)
	current_scene = course
	await physics_frame
	var fails := d.fails if d else 0
	d = Driver.new(self, course.get(&"nim"), course.get(&"cam"))
	d.fails = fails


func _goon(id: String) -> Enemy:
	return course.get_node("Goon_%s" % id) as Enemy


func _strike_combo() -> void:
	for i in 3:
		await d.tap(JOY_BUTTON_X, 0.05)
		await d.secs(0.12)
	await d.secs(0.4)


# --- H -----------------------------------------------------------------------------------------------------------------

func _unaware() -> void:
	var sentry := _goon("sentry")
	# Behind him (he faces -X), crouched, and close.
	await d.place(sentry.global_position + Vector3(2.5, 0, 0), PI / 2.0)
	d.button(JOY_BUTTON_B, true)
	d.steer(Vector3.LEFT)
	await d.until(func() -> bool: return d.nim.global_position.x - sentry.global_position.x < 1.3, 3.0)
	d.stick(0, 0)
	d.button(JOY_BUTTON_B, false)
	await d.frames(3)
	d.check(sentry.state == Enemy.State.PATROL and sentry.can_bind(), "H: the sentry hasn't noticed her (suspicion %.2f)" % sentry.suspicion)
	await d.tap(JOY_BUTTON_Y)
	await d.secs(0.8)
	d.check(sentry.is_bound(), "H: Y binds him where he stands, no fight")
	d.check(game.call(&"has_flag", sentry.bound_flag()), "H: and the world remembers it (%s)" % sentry.bound_flag())


func _entranced() -> void:
	var p := course.get_node("Entranced_h1") as Entranced
	# Right behind them, facing them: their device is held out in front, past them.
	var behind := p.global_position - p.facing() * 1.0
	await d.place(behind, p.rotation.y)
	var before := p.global_position
	await _strike_combo()
	d.check(p.state == Entranced.State.ENTRANCED and p.device != null, "H: three strikes from behind pass through them (still under)")
	var drift := p.global_position.distance_to(before)
	d.check(drift < 1.3, "H: and don't shove them (moved %.2f m at their own pace)" % drift)
	await d.tap(JOY_BUTTON_Y)
	await d.secs(0.7)
	d.check(not d.nim.combat.binding() and p.state == Entranced.State.ENTRANCED, "H: Y can't bind them")
	# In front, facing them: one strike breaks the device.
	var front := p.global_position + p.facing() * 1.2
	await d.place(front, p.rotation.y + PI)
	await d.tap(JOY_BUTTON_X)
	await d.secs(0.4)
	d.check(p.state == Entranced.State.AWAKE and p.device == null, "H: a strike at the device, from in front, wakes them")
	d.check(game.call(&"count", &"freed", &"test") == 1, "H: counted as freed (1 of 5)")


# --- G -----------------------------------------------------------------------------------------------------------------

func _hurt_and_down() -> void:
	# Start at the yard's near edge and walk through the checkpoint toward the gate.
	await d.place(Vector3(90, 0.05, 3.8), 0.0)
	d.stick(0, -1)
	await d.secs(0.8)
	d.stick(0, 0)
	var cp: Vector3 = course.get(&"spawn_at")
	d.check(absf(cp.z - 2.0) < 0.2 and absf(cp.x - 90.0) < 0.2, "G: walking past the checkpoint makes it hers %s" % str(cp))
	# Stand in front of g1 and take a punch.
	var g := _goon("g1")
	await d.place(g.global_position - g.global_basis.z * 1.4, g.rotation.y + PI)
	var hp: int = d.nim.combat.health
	var hit := await d.until(func() -> bool: return d.nim.combat.health < hp, 4.0)
	d.check(hit, "G: a goon's punch costs her health (%d of %d)" % [d.nim.combat.health, NimCombat.MAX_HEALTH])
	# Down to one, then downed: back at the checkpoint, full health.
	d.nim.combat.health = 1
	await d.secs(1.2)
	var down := await d.until(func() -> bool: return d.nim.combat.is_down(), 4.0)
	d.check(down, "G: out of health, she's downed")
	await d.until(func() -> bool: return not d.nim.combat.is_down(), 3.0)
	await d.frames(2)
	var at := d.nim.global_position
	d.check(at.distance_to(cp) < 0.6 and d.nim.combat.health == NimCombat.MAX_HEALTH,
		"G: and back at the checkpoint, healthy %s, %d" % [d.at(), d.nim.combat.health])


func _brawl() -> void:
	var goons: Array[Enemy] = [_goon("g1"), _goon("g2"), _goon("g3")]
	var saw_lock := false
	var saw_stagger := false
	var saw_knockdown := false
	var t := 0.0
	while t < 60.0:
		var left := goons.filter(func(g: Enemy) -> bool: return not g.is_bound())
		if left.is_empty():
			break
		left.sort_custom(func(a: Enemy, b: Enemy) -> bool:
			return a.global_position.distance_to(d.nim.global_position) < b.global_position.distance_to(d.nim.global_position))
		var g: Enemy = left[0]
		saw_knockdown = saw_knockdown or g.state == Enemy.State.KNOCKDOWN
		d.lock_on(true)
		var to := g.global_position - d.nim.global_position
		if OS.has_environment("PROBE_TRACE"):
			print("%5.1f %s st=%s d=%.2f hp=%d nim=%s down=%s" % [t, g.id, Enemy.State.keys()[g.state], Vector2(to.x, to.z).length(),
				d.nim.combat.health, Nim.State.keys()[d.nim.state], d.nim.combat.is_down()])
			print("      busy=%s strike=%s v=%s at=%s g=%s stick=%s" % [d.nim.combat.busy(), d.nim.combat.striking(), d.nim.velocity, d.at(), g.global_position, Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")])
		if Vector2(to.x, to.z).length() > 1.6:
			d.steer(to)
			await d.frames(6)
			t += 0.1
			continue
		d.stick(0, 0)
		saw_lock = saw_lock or d.nim.combat.lock != null
		if g.can_bind() and g.state != Enemy.State.PATROL:
			d.lock_on(false)
			await d.tap(JOY_BUTTON_Y)
			await d.secs(0.75)
			t += 0.8
			continue
		await d.tap(JOY_BUTTON_X, 0.05)
		await d.secs(0.1)
		saw_stagger = saw_stagger or g.state == Enemy.State.STAGGER
		await d.tap(JOY_BUTTON_X, 0.05)
		await d.secs(0.1)
		await d.tap(JOY_BUTTON_X, 0.05)
		await d.secs(0.25)
		saw_knockdown = saw_knockdown or g.state == Enemy.State.KNOCKDOWN
		t += 0.6
	d.release_all()
	d.check(saw_lock, "G: LT locks on to the nearest goon")
	d.check(saw_stagger, "G: a strike staggers")
	d.check(saw_knockdown, "G: the third strike knocks him down")
	var bound := goons.filter(func(g: Enemy) -> bool: return g.is_bound()).size()
	d.check(bound == 3, "G: fought and bound all three goons (%d of 3, %.0f s)" % [bound, t])


# --- reloads -----------------------------------------------------------------------------------------------------------

func _persist() -> void:
	for how: String in ["a reload", "a save and load"]:
		if how == "a save and load":
			var saved: Dictionary = game.call(&"to_dict")
			game.call(&"reset")
			game.call(&"from_dict", JSON.parse_string(JSON.stringify(saved)))
		await _load()
		await d.frames(3)
		var still := 0
		for id: String in ["sentry", "g1", "g2", "g3"]:
			if _goon(id).is_bound():
				still += 1
		d.check(still == 4, "after %s, all four goons are still bound (%d)" % [how, still])
		var p := course.get_node("Entranced_h1") as Entranced
		d.check(p.state == Entranced.State.AWAKE, "after %s, the woken person is still awake" % how)
