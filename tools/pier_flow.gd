extends SceneTree
## WO-014's flow probe: the vertical slice in one game, from a new game, with real input throughout.
##   1. The prologue in the club's dungeon: the guest woken, her first Key, the tag.
##   2. Out of the club, across the square, down Seafront Road, through the Pier's gate.
##   3. On the Pier, every Key (tools/pier_steps.gd): the lesson, the landing (2), Dash's race (1), the striker (4), the
##      safe (6), the wheel (8), the five sleepers (10), the tin, the Big Dipper (9); into the suit at Dash's hut;
##      the gallery (3), Pearl (5), the clerk (7); back into the garb at the Fun Palace's locker; Laffer.
##   4. Home through the Old Quarter's arch: with the Pier's Keys she's rank 2, and Primrose Lane's gate opens.
## The Pier's goons and gulls that no Key needs are cleared off (the fights are combat_probe's and stealth_probe's);
## the Keys' own goons stay. The time printed is game time (60 frames a second).
##   godot --headless --fixed-fps 60 --path . -s tools/pier_flow.gd

const Driver := preload("res://tools/probe_driver.gd")
const Steps := preload("res://tools/pier_steps.gd")
const HUB := "res://levels/hub/hub.tscn"
const PIER := "res://levels/pier/pier.tscn"

var d: Driver
var game: Node
var dialogue: Node
var fails := 0
var frames := 0


func _initialize() -> void:
	await process_frame
	game = root.get_node("/root/Game")
	dialogue = root.get_node("/root/Dialogue")
	game.set(&"persist", false)
	game.call(&"set_setting", "age_confirmed", true)
	game.call(&"reset")
	physics_frame.connect(func() -> void: frames += 1)
	var hub: Node = load(HUB).instantiate()
	root.add_child(hub)
	current_scene = hub
	await physics_frame
	d = Driver.new(self, hub.get(&"nim"), hub.get(&"cam"))
	await _prologue(hub)
	await _to_the_pier()
	await _the_pier()
	await _home()
	print("pier flow: %d failures, %.0f s of game time" % [d.fails, frames / 60.0])
	quit(1 if d.fails else 0)


## A new scene's Nim and camera, keeping the failures counted so far.
func _rebind() -> Node:
	var level := current_scene
	await physics_frame
	await physics_frame
	var f := d.fails
	d = Driver.new(self, level.get(&"nim"), level.get(&"cam"))
	d.fails = f
	return level


func _travelled_to(path: String) -> bool:
	return await d.until(func() -> bool:
		return current_scene != null and current_scene.scene_file_path == path and current_scene.get(&"nim") != null, 10.0)


func _prologue(hub: Node) -> void:
	var s := Steps.new(self, d, hub)
	await s.converse("the prologue: Vesper's welcome")
	await s.converse("the guest comes down the ramp, humming", 6.0)
	var guest := hub.get_node("Entranced_guest") as Node3D
	var woke := false
	for i in 6:
		var f := -guest.global_basis.z
		await d.place(guest.global_position + f * 1.2, atan2(f.x, f.z))
		await d.tap(JOY_BUTTON_X)
		await d.secs(0.5)
		if game.call(&"has_collected", &"freed", &"hub", &"guest"):
			woke = true
			break
	d.check(woke and game.call(&"rank") == 1, "the guest woken: her first Key, rank 1")
	await s.converse("Vesper reads the tag: the Pier", 4.0)
	# The guest and Vesper walk up the ramp to the lounge: let them go first.
	var vesper := hub.get_node("Prologue/Vesper") as Node3D
	d.check(await d.until(func() -> bool:
		return not vesper.get(&"walking") and vesper.global_position.y > -0.5 \
			and Vector2(guest.global_position.x + 6.6, guest.global_position.z + 23.4).length() < 0.6, 45.0),
		"the guest and Vesper walk up to the lounge")


func _to_the_pier() -> void:
	var hub := current_scene
	var s := Steps.new(self, d, hub)
	var ok := true
	for p: Vector3 in [Vector3(7.5, 0, -33.4), Vector3(7.5, 0, -26.0), Vector3(1.0, 0, -18.0), Vector3(0.0, 0, -12.0),
			Vector3(20.0, 0, 5.0), Vector3(76.0, 0, 5.0)]:
		ok = ok and await s.walk_to(p, 20.0)
	d.check(ok, "out of the club and down Seafront Road to the Pier's gate %s" % d.at())
	d.steer(Vector3.RIGHT)
	var there := await _travelled_to(PIER)
	d.stick(0, 0)
	d.check(there, "through the gate: the Pier")


func _the_pier() -> void:
	var pier := await _rebind()
	var s := Steps.new(self, d, pier)
	for id: String in ["m_rounds1", "m_rounds2", "m_tackle", "bouncer", "p_rounds", "p_office"]:
		s.remove(s.goon(id))
	for n: Node in pier.find_children("*", "Lookout", true, false):
		s.remove(n)
	await d.frames(5)
	await s.lesson()
	await s.landing()
	await s.race()
	await s.striker()
	await s.safe()
	await s.wheel()
	await s.sleepers()
	await s.tin()
	await s.dipper()
	# Into the suit at Dash's hut (its front faces the promenade, +Z).
	await d.place(Vector3(60.0, 0.05, 14.0), 0.0)
	await d.tap(JOY_BUTTON_Y)
	await d.secs(1.4)
	d.check(d.nim.suit.in_suit(), "into the Domme suit at Dash's hut")
	await d.secs(0.5)
	await s.gallery()
	await s.pearl()
	await s.clerk()
	# Back into the garb at the Fun Palace's staff locker (its front faces into the room, +X).
	await d.place(Vector3(-15.9, 0.05, -116.0), PI / 2.0)
	await d.tap(JOY_BUTTON_Y)
	await d.secs(1.4)
	d.check(not d.nim.suit.in_suit(), "back into the garb at the staff locker")
	await s.boss_enter(false)
	await s.boss_claw()
	await s.boss_whack()
	await s.boss_mountain()
	var keys := 0
	for i in range(1, 11):
		if s.has_key(StringName("pier_%02d" % i)):
			keys += 1
	d.check(keys == 10, "all ten of the Pier's Keys (%d)" % keys)
	d.check(game.call(&"keys") == 12, "twelve Keys in all: the Pier's ten, the guest's, the tin's (%d)" % game.call(&"keys"))


func _home() -> void:
	await d.place(Vector3(-64.0, 0.05, 17.0), -PI / 2.0)
	d.steer(Vector3.LEFT)
	var back := await _travelled_to(HUB)
	d.stick(0, 0)
	d.check(back, "home through the Old Quarter's arch")
	if not back:
		return
	var hub := await _rebind()
	var s := Steps.new(self, d, hub)
	d.check(game.call(&"rank") == 2, "rank 2 (%d)" % game.call(&"rank"))
	await d.place(Vector3(-8.0, 0.05, 24.0), PI)
	var gate := hub.get_node("RankDoor_primrose") as RankDoor
	await s.walk_to(Vector3(-8.0, 0, 30.0), 6.0)
	var opened := await d.until(func() -> bool: return gate.is_open, 3.0)
	d.check(opened, "and Primrose Lane's gate opens for her (6 Keys)")
