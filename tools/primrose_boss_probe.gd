extends SceneTree
## Mrs Gander's fight in her garden (WO-015 step 4), with real input on a Close where the party's done (the garden door
## open), Nim with the crop and the Scold, the bulldogs and the Watch cleared off:
##   - in through her back door: it locks, and her welcome;
##   - the garden party: after her by her honks, three strikes (each time she runs to another hiding place), and a guest
##     struck by mistake undoes one;
##   - the sprinklers: the flood rises; up on the topiary, the crop cracks all six heads, and the water drains;
##   - the tantrum: a strike only makes it worse; the Scold freezes her, she sits down, a strike ties her;
##   - bound to her own bench, the order book, Grizelda's verdict, the paper; Primrose done.
##   godot --headless --fixed-fps 60 --path . -s tools/primrose_boss_probe.gd

const Driver := preload("res://tools/probe_driver.gd")
const SCENE := "res://levels/primrose/primrose.tscn"
const LAWN := 0.08
## The topiary ball beside each sprinkler head (gander.gd's HEADS, 1.8 m east of each): its top, 3.08 up.
const PERCHES := [Vector3(-15.0, 3.1, -152.0), Vector3(5.0, 3.1, -152.0), Vector3(-5.0, 3.1, -160.0),
	Vector3(15.0, 3.1, -160.0), Vector3(-15.0, 3.1, -168.0), Vector3(5.0, 3.1, -168.0)]

var d: Driver
var level: Node
var game: Node
var dialogue: Node
var boss: Node


func _initialize() -> void:
	await process_frame
	game = root.get_node("/root/Game")
	dialogue = root.get_node("/root/Dialogue")
	game.set(&"persist", false)
	game.call(&"set_setting", "age_confirmed", true)
	game.call(&"reset")
	for f: String in ["primrose/party_done", "primrose/bells_rung", "primrose/lesson_done", "gear_crop", "gear_scold",
			"lesson_fetch_open"]:
		game.call(&"set_flag", f)
	level = load(SCENE).instantiate()
	root.add_child(level)
	current_scene = level
	await physics_frame
	d = Driver.new(self, level.get(&"nim"), level.get(&"cam"))
	for n: Node in level.find_children("*", "Enemy", true, false) + level.find_children("*", "Lookout", true, false):
		n.get_parent().remove_child(n)
		n.queue_free()
	boss = level.get_node("Gander")
	await d.frames(5)
	await _enter()
	await _garden_party()
	await _sprinklers()
	await _tantrum()
	print("primrose boss probe: %d failures" % d.fails)
	quit(1 if d.fails else 0)


func _phase() -> int:
	return int(boss.get(&"phase"))


func _flag(f: String) -> bool:
	return game.call(&"has_flag", f)


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


func _enter() -> void:
	d.check(level.get_node_or_null("GardenDoor") == null, "after the party, her back door's open")
	await d.place(Vector3(0, 0.1, -132.0), PI)
	var ok := await d.until(func() -> bool:
		if dialogue.call(&"is_active"):
			return true
		d.steer(Vector3(0, 0, -1))
		return false, 8.0)
	d.stick(0, 0)
	d.check(ok, "through her back door into the garden: her welcome")
	await d.talk_through(30.0)
	d.check((boss.get(&"_lock") as StaticBody3D).collision_layer == 1, "the door's locked behind her")


func _garden_party() -> void:
	var g: Node3D = boss.get(&"gander")
	var guest: Node3D = (boss.get(&"_guests") as Array)[0][0]
	# A guest first, by mistake: one hit undone (from none, so none).
	var guest_ok := await d.until(func() -> bool:
		var to := guest.global_position - d.nim.global_position
		to.y = 0.0
		if to.length() > 1.2:
			d.steer(to)
			return false
		d.steer(to, 0.15)
		return true, 15.0)
	d.stick(0, 0)
	await d.frames(3)
	await d.tap(JOY_BUTTON_X)
	await d.secs(0.6)
	d.check(guest_ok, "a guest in a trance struck by mistake (Gander laughs; nothing gained)")
	var h0: int = d.nim.combat.health
	# [where she was a second ago, frames left of side-stepping] (round the topiary when she's stuck on it)
	var stuck := [d.nim.global_position, 0]
	var ok := await d.until(func() -> bool:
		if _phase() != 2:
			return true
		if boss.get(&"_running"):
			d.button(JOY_BUTTON_X, false)
			d.stick(0, 0)
			return false
		var to := g.global_position - d.nim.global_position
		to.y = 0.0
		if Engine.get_physics_frames() % 60 == 0:
			if (stuck[0] as Vector3).distance_to(d.nim.global_position) < 0.3 and to.length() > 1.6:
				stuck[1] = 30
			stuck[0] = d.nim.global_position
		if int(stuck[1]) > 0:
			stuck[1] = int(stuck[1]) - 1
			d.steer(to.normalized().cross(Vector3.UP) + to.normalized() * 0.2)
			d.button(JOY_BUTTON_X, false)
			return false
		if to.length() > 1.4:
			d.steer(to)
			d.button(JOY_BUTTON_X, false)
		else:
			d.steer(to, 0.15)
			d.button(JOY_BUTTON_X, not d.nim.combat.striking())
		return false, 120.0)
	d.release_all()
	d.check(ok and _phase() >= 3, "the garden party: after her by the honks, three strikes (health %d to %d)" % [h0, d.nim.combat.health])


func _sprinklers() -> void:
	var risen := await d.until(func() -> bool: return float(boss.get(&"_water_y")) > 0.4, 10.0)
	d.check(risen, "the flood: the water's up")
	# Stood in it a while: it knocks the wind out of her.
	await d.place(Vector3(-10.0, 0.1, -156.0), 0.0)
	var h0: int = d.nim.combat.health
	await d.secs(2.8)
	d.check(d.nim.combat.health < h0, "stood in the flood, it hurts (health %d to %d)" % [h0, d.nim.combat.health])
	for i in PERCHES.size():
		if _phase() != 3:
			break
		await d.place(PERCHES[i], -PI / 2.0)   # on the ball, facing east to the head beside it
		await d.frames(6)
		d.steer(Vector3(1, 0, 0), 0.12)
		await d.frames(3)
		d.stick(0, 0)
		d.button(JOY_BUTTON_X, true)   # held: the crop
		await d.secs(0.6)
		d.button(JOY_BUTTON_X, false)
		await d.secs(0.5)
	d.check(int(boss.get(&"heads_out")) == 6 and _phase() == 4,
		"up on the topiary, the crop cracks all six heads (%d)" % int(boss.get(&"heads_out")))
	var drained := await d.until(func() -> bool: return float(boss.get(&"_water_y")) < 0.05, 6.0)
	d.check(drained, "and the water drains")


func _tantrum() -> void:
	await d.until(func() -> bool: return not boss.get(&"_running"), 8.0)
	var g: Node3D = boss.get(&"gander")
	await d.place(Vector3(0.0, 0.1, -148.5), 0.0)
	await d.frames(4)
	# A strike first: you don't fight a tantrum.
	await _walk_to(g.global_position, 6.0, 1.3)
	d.steer(g.global_position - d.nim.global_position, 0.15)
	await d.tap(JOY_BUTTON_X)
	await d.secs(0.5)
	d.check(not boss.get(&"_sitting") and _phase() == 4, "a strike at a tantrum does nothing (but make it worse)")
	await d.tap(JOY_BUTTON_LEFT_SHOULDER)   # the Scold
	var sat := await d.until(func() -> bool: return boss.get(&"_sitting"), 5.0)
	d.check(sat, "the Scold: she freezes mid-throw, then sits down on her own")
	await _walk_to(g.global_position, 4.0, 1.2)
	d.steer(g.global_position - d.nim.global_position, 0.15)
	await d.tap(JOY_BUTTON_X)
	var tied := await d.until(func() -> bool: return _phase() == 5, 3.0)
	d.check(tied, "a strike, and she's tied")
	for i in 80:
		if _flag("done/primrose") and not dialogue.call(&"is_active"):
			break
		if dialogue.call(&"is_active"):
			await d.talk_through(30.0)
		else:
			await d.secs(0.25)
	d.check(_flag("primrose/gander_bound") and _flag("primrose/order_book") and _flag("done/primrose"),
		"bound to her own bench, the order book, Grizelda's verdict, the paper: Primrose Close is done")
	d.check(g.global_position.distance_to(Vector3(0.0, 0.9, -173.5)) < 0.2, "she's on her bench, under her sign %s" % g.global_position)
