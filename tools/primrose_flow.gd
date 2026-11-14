extends SceneTree
## WO-015's flow probe: Primrose Close in one game, from the hub with the Pier done (pier_flow plays the Pier), with
## real input throughout:
##   1. Out of the club's door and down Primrose Lane, through its gate (rank 2): the Close.
##   2. Every Key (tools/primrose_steps.gd): Vesper's lesson; Grizelda's tea (1, the Scold); the cake (2); the raffle
##      (3); the logbook (7); the van (8); the belfry (4); the stash (5); the washing lines (6); the five neighbours
##      (10); the tin; the demonstration party (9); then Mrs Gander, all three phases, and Primrose is done.
##   3. Home under the arch: Grizelda's home (core/sisters.gd), her room lit, the guide says to welcome her, and her
##      homecoming; the Roses open the Docks' gate.
## The bulldogs and the Watch's lookouts are cleared off (the fights and sight lines are other probes'); outfits change
## by Steps.outfit() (the wardrobes are primrose_probe's). The time printed is game time (60 frames a second).
##   godot --headless --fixed-fps 60 --path . -s tools/primrose_flow.gd

const Driver := preload("res://tools/probe_driver.gd")
const Steps := preload("res://tools/primrose_steps.gd")
const HUB := "res://levels/hub/hub.tscn"
const PRIMROSE := "res://levels/primrose/primrose.tscn"

var d: Driver
var game: Node
var dialogue: Node
var frames := 0


func _initialize() -> void:
	await process_frame
	game = root.get_node("/root/Game")
	dialogue = root.get_node("/root/Dialogue")
	game.set(&"persist", false)
	game.call(&"set_setting", "age_confirmed", true)
	game.call(&"reset")
	_after_the_pier()
	physics_frame.connect(func() -> void: frames += 1)
	var hub: Node = load(HUB).instantiate()
	root.add_child(hub)
	current_scene = hub
	await physics_frame
	d = Driver.new(self, hub.get(&"nim"), hub.get(&"cam"))
	await d.secs(0.5)
	await _to_primrose()
	await _the_close()
	await _home()
	print("primrose flow: %d failures, %.0f s of game time" % [d.fails, frames / 60.0])
	quit(1 if d.fails else 0)


## Where pier_flow leaves her: the prologue done, the Pier done (its ten Keys, the guest's, the tin's), the crop and
## the takedown from above learned, Dash home and welcomed.
func _after_the_pier() -> void:
	for f: String in ["hub/prologue_done", "visited/hub", "visited/pier", "done/pier", "pier/lesson_done",
			"pier/race_won", Lessons.CROP, Lessons.TAKEDOWN_ABOVE, "home/dash", "back/dash", "swyne/pier"]:
		game.call(&"set_flag", f)
	for i in range(1, 11):
		game.call(&"collect", &"key", &"pier", StringName("pier_%02d" % i))
	game.call(&"collect", &"key", &"hub", &"hub_10")
	game.call(&"collect", &"key", &"hub", &"tin_pier")


## A new scene's Nim and camera, keeping the failures counted so far.
func _rebind() -> Node:
	var level := current_scene
	await physics_frame
	await physics_frame
	var f := d.fails
	d = Driver.new(self, level.get(&"nim"), level.get(&"cam"))
	d.fails = f
	return level


## Walks her along `dir` until the game's moved on to `scene` (the old Nim goes with the old level, so this stops
## steering her the moment she's gone).
func _cross(dir: Vector3, scene: String) -> bool:
	var t := 0.0
	while t < 12.0:
		if current_scene != null and current_scene.scene_file_path == scene and current_scene.get(&"nim") != null:
			d.stick(0, 0)
			return true
		if is_instance_valid(d.nim) and d.nim.is_inside_tree():
			d.steer(dir)
		await physics_frame
		t += 1.0 / 60.0
	d.stick(0, 0)
	return false


func _to_primrose() -> void:
	var hub := current_scene
	var s := Steps.new(self, d, hub)
	var ok := true
	for p: Vector3 in [Vector3(0.0, 0, -9.0), Vector3(-8.0, 0, 8.0), Vector3(-8.0, 0, 26.0)]:
		ok = ok and await s.walk_to(p, 20.0)
	d.check(ok, "out of the club's door, across the square to Primrose Lane %s" % d.at())
	var gate := hub.get_node("RankDoor_primrose") as RankDoor
	await s.walk_to(Vector3(-8.0, 0, 30.0), 6.0)   # up to the gate (as pier_flow checks it)
	d.check(await d.until(func() -> bool: return gate.is_open, 3.0), "Primrose Lane's gate opens for her (rank %d)" % game.call(&"rank"))
	d.check(await _cross(Vector3(0, 0, 1), PRIMROSE), "through the gate: Primrose Close")


func _the_close() -> void:
	var level := await _rebind()
	var s := Steps.new(self, d, level)
	await s.clear_guards()
	await s.lesson()
	await s.tea()
	await s.cake()
	await s.raffle()
	await s.logbook()
	await s.van()
	await s.bells()
	await s.stash()
	await s.lines()
	await s.sleepers()
	await s.tin()
	await s.party(false)
	await s.boss_enter()
	await s.boss_garden_party()
	await s.boss_sprinklers()
	await s.boss_tantrum()
	var keys := 0
	for i in range(1, 11):
		if s.has(StringName("primrose_%02d" % i)):
			keys += 1
	d.check(keys == 10, "all ten of Primrose Close's Keys (%d)" % keys)
	d.check(game.call(&"keys") == 23, "twenty-three Keys in all: the Pier's twelve, the Close's ten, its tin (%d)" % game.call(&"keys"))


func _home() -> void:
	# Out of Gander's garden (her gate's open now she's bound) and back to the Close's mouth, then under the arch.
	await d.place(Vector3(0, 0.05, 6.0), PI)
	var back := await _cross(Vector3(0, 0, 1), HUB)
	d.check(back, "home under the arch, onto Primrose Lane")
	if not back:
		return
	var hub := await _rebind()
	await d.secs(0.5)
	var griz := hub.get_node_or_null("Grizelda") as Node3D
	d.check(griz != null and game.call(&"has_flag", "back/grizelda"), "Grizelda's home from the Close (her room's lit)")
	var goal := String(root.get_node("/root/Hud").call(&"goal_text"))
	d.check(goal.begins_with("Grizelda is home"), "the guide: welcome her back (%s)" % goal)
	if griz:
		await d.place(griz.global_position + (griz.global_basis.z * 1.3) + Vector3(0, 0.05, 0),
			atan2(-griz.global_basis.z.x, -griz.global_basis.z.z))
		await d.tap(JOY_BUTTON_Y)
		var s := Steps.new(self, d, hub)
		await s.converse("Grizelda's homecoming: \"Shoes. Wipe.\"")
		d.check(game.call(&"has_flag", "home/grizelda"), "welcomed home (home/grizelda)")
	d.check(game.call(&"world_open", &"docks") and game.call(&"world_open", &"retreat"),
		"rank %d: the Docks' and the Retreat's gates open" % game.call(&"rank"))
