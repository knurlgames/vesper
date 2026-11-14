extends SceneTree
## WO-008's acceptance, with real input in the probe world (levels/probe_world):
##   - Every collectible: Keys and contraband (walked into), the collection tin (struck: it pays a hub Key), and five
##     people woken (all five pay the world's Key 10).
##   - Ranks: the rank door stays shut at 3 Keys and opens at 4; the rank counts up.
##   - The shortcut is bolted from its front and opens from behind; a zone names itself; two fast travel points are
##     found, and one sends her to the other; the wardrobe is remembered; a goon is bound.
##   - Saving: everything autosaves to a file; Game is wiped and reloaded from it, the world reloads, and all of it is
##     still so. Slot 2 is empty; back in slot 1, it's all there.
##   - The pause screen's tallies show it.
##   godot --headless --fixed-fps 60 --path . -s tools/world_probe.gd

const Driver := preload("res://tools/probe_driver.gd")
const SAVE := "user://probe_world_save.json"

var d: Driver
var world: Node
var game: Node
var hud: Node


func _initialize() -> void:
	await process_frame
	game = root.get_node("/root/Game")
	hud = root.get_node("/root/Hud")
	game.set(&"persist", false)
	game.call(&"set_setting", "age_confirmed", true)   # in memory only, before saving is switched on
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	game.set(&"save_path", SAVE)
	game.set(&"persist", true)
	game.set(&"slot", 1)
	game.call(&"reset")
	await _load()
	await _collectibles()
	await _rank_door()
	await _shortcut_zone_travel()
	await _wardrobe_and_goon()
	var before := _snapshot()
	await _reload_from_file()
	_compare(before)
	await _slots(before)
	_pause_tallies()
	game.set(&"persist", false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("world probe: %d failures" % d.fails)
	quit(1 if d.fails else 0)


func _load() -> void:
	if world:
		world.queue_free()
		await process_frame
	world = load("res://levels/probe_world/probe_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await physics_frame
	var fails := d.fails if d else 0
	d = Driver.new(self, world.get(&"nim"), world.get(&"cam"))
	d.fails = fails


func _count(kind: StringName, w := &"probe") -> int:
	return game.call(&"count", kind, w)


func _collectibles() -> void:
	# Walk into the first Key and the three contraband (they sit in a row at z 14).
	await d.place(Vector3(-4, 0.05, 15.5), 0.0)
	d.stick(0, -1)
	await d.secs(0.4)
	d.stick(0, 0)
	await d.place(Vector3(2.5, 0.05, 14), -PI / 2.0)   # facing +X, along the row
	d.stick(0, -1)
	await d.secs(0.8)
	d.stick(0, 0)
	d.check(_count(&"key") == 1 and _count(&"contraband") == 3, "walked into a Key and three contraband (%d, %d)" % [_count(&"key"), _count(&"contraband")])
	# The tin: struck, not walked into. It pays a hub Key.
	await d.place(Vector3(-8, 0.05, 15.2), 0.0)
	await d.tap(JOY_BUTTON_X)
	await d.secs(0.5)
	d.check(_count(&"tin") == 1 and await _take_rose(&"hub", &"tin_probe"),
		"the collection tin, smashed: the hub's rose (tin_probe) tossed down and picked up")
	# Five people in a trance in a row at z 6, facing -Z: from in front, a strike at each one's toy.
	for i in 5:
		await d.place(Vector3(-12 + i * 6, 0.05, 6 - 1.2), PI)
		await d.tap(JOY_BUTTON_X)
		await d.secs(0.45)
	d.check(_count(&"freed") == 5, "five people woken (%d)" % _count(&"freed"))
	d.check(await _take_rose(&"probe", &"probe_10"), "and all five pay the world's Key 10: a rose tossed down, picked up")


## A rose earned without a pickup (a tin, five woken) is tossed down in front of her: let it land, step onto it.
func _take_rose(w: StringName, id: StringName) -> bool:
	await d.secs(1.5)
	var rose := world.get_node_or_null("Key_%s" % id) as Node3D
	if rose:
		await d.place(rose.global_position + Vector3(0, 0.05, 0), 0.0)
	return await d.until(func() -> bool: return game.call(&"has_collected", &"key", w, id), 1.5)


func _rank_door() -> void:
	var door := world.get_node("RankDoor") as RankDoor
	await d.place(Vector3(0, 0.05, -16.5), 0.0)
	await d.secs(0.5)
	var keys: int = game.call(&"keys")
	d.check(keys == 3 and not door.is_open, "the rank door (4 Keys) stays shut at %d" % keys)
	# The second Key, then back to the door.
	await d.place(Vector3(8, 0.05, -12.5), 0.0)
	d.stick(0, -1)
	await d.secs(0.4)
	d.stick(0, 0)
	await d.place(Vector3(0, 0.05, -16.5), 0.0)
	var opened := await d.until(func() -> bool: return door.is_open, 2.0)
	d.check(opened and game.call(&"keys") == 4, "at 4 Keys it opens as she comes up")
	d.check(game.call(&"rank") == 1, "and she's rank %d (thresholds %s)" % [game.call(&"rank"), str(game.get(&"RANK_KEYS"))])
	await d.secs(1.0)
	d.stick(0, -1)
	var through := await d.until(func() -> bool: return d.nim.global_position.z < -21.0, 2.0)
	d.stick(0, 0)
	d.check(through, "and she walks through")


func _shortcut_zone_travel() -> void:
	var sc := world.get_node("Shortcut_east_gate") as ShortcutDoor
	# From its front (the far side, z < -10): bolted.
	await d.place(Vector3(20, 0.05, -11.3), PI)
	await d.tap(JOY_BUTTON_Y)
	await d.frames(4)
	d.check(not sc.is_open, "the shortcut is bolted from its front")
	# From behind (z > -10): it opens, for good.
	await d.place(Vector3(20, 0.05, -8.7), 0.0)
	await d.tap(JOY_BUTTON_Y)
	await d.frames(4)
	d.check(sc.is_open and game.call(&"has_flag", "shortcut/probe/east_gate"), "and opens from behind, for good")
	# The zone named itself when she walked in (she's been in it all along; walk out and back in).
	await d.place(Vector3(0, 0.05, 25), 0.0)
	await d.secs(0.2)
	d.stick(0, -1)
	await d.secs(1.0)
	d.stick(0, 0)
	var zl: Node = hud.get(&"_zone")
	d.check(zl != null and zl.get(&"text") == "The Probe Yard", "walking into the yard names it on the HUD")
	# Fast travel: walk past both points, then Y at "Gate" and pick "Yard".
	for p: Vector3 in [Vector3(-20, 0.05, 18), Vector3(20, 0.05, 18)]:
		await d.place(p, 0.0)
		await d.frames(4)
	var a := world.get_node("Travel_gate") as TravelPoint
	var b := world.get_node("Travel_yard") as TravelPoint
	d.check(a.found and b.found, "walking past fast travel points finds them")
	await d.place(Vector3(-20, 0.05, 17.4), 0.0)
	await d.tap(JOY_BUTTON_Y)
	await process_frame
	d.check(hud.call(&"choosing"), "Y at one lists where she can go")
	await d.tap(JOY_BUTTON_DPAD_DOWN)
	await d.tap(JOY_BUTTON_A)
	# The rose cyclone wraps her up, she's moved, and it sinks away there (about 2.2 s): then she's free.
	var arrived := await d.until(func() -> bool:
		return d.nim.global_position.distance_to(b.global_position) < 2.5 and d.nim.is_physics_processing(), 4.0)
	d.check(arrived and not paused, "picking \"Yard\": a cyclone of roses, and she's there %s" % d.at())


func _wardrobe_and_goon() -> void:
	await d.place(Vector3(-20, 0.05, -2.9), PI)
	await d.tap(JOY_BUTTON_Y)
	await d.secs(1.3)
	var lw: Dictionary = game.get(&"last_wardrobe")
	d.check(lw.get("scene", "") == world.scene_file_path, "the wardrobe is remembered for \"Back to the last wardrobe\"")
	await d.place(Vector3(-20, 0.05, -2.9), PI)
	await d.tap(JOY_BUTTON_Y)   # back into the garb
	await d.secs(1.3)
	var g := world.get_node("Goon_guard") as Enemy
	await d.place(g.global_position + Vector3(-1.4, 0, 0), -PI / 2.0)
	await d.tap(JOY_BUTTON_Y)
	await d.secs(0.8)
	d.check(g.is_bound(), "a goon bound")


## Everything a save should keep, as plain values.
func _snapshot() -> Dictionary:
	return {"keys": game.call(&"keys"), "probe_keys": _count(&"key"), "contraband": _count(&"contraband"),
		"freed": _count(&"freed"), "tin": _count(&"tin"), "hub_keys": _count(&"key", &"hub"), "rank": game.call(&"rank"),
		"shortcut": game.call(&"has_flag", "shortcut/probe/east_gate"), "bound": game.call(&"has_flag", "bound/probe/guard"),
		"travel": game.call(&"has_flag", "travel/probe/yard"), "wardrobe": (game.get(&"last_wardrobe") as Dictionary).has("scene")}


## A restart: Game forgets everything, reads the file, and the world loads again.
func _reload_from_file() -> void:
	d.check(FileAccess.file_exists(SAVE), "everything autosaved to %s" % SAVE)
	game.call(&"from_dict", {})
	d.check(game.call(&"keys") == 0, "(Game wiped: %d Keys)" % game.call(&"keys"))
	game.call(&"load_game")
	await _load()
	await d.frames(5)


func _compare(before: Dictionary) -> void:
	var after := _snapshot()
	d.check(after == before, "reloaded from the file: %s" % str(after))
	var left := 0
	for p: Node in get_nodes_in_group(&"pickup"):
		left += 1
	d.check(left == 0, "every collected pickup stays collected (%d still lying about)" % left)
	d.check((world.get_node("Shortcut_east_gate") as ShortcutDoor).is_open, "the shortcut is still open")
	d.check((world.get_node("Goon_guard") as Enemy).is_bound(), "the goon is still bound")
	var awake := 0
	for e: Node in get_nodes_in_group(&"entranced"):
		if e.get(&"state") == Entranced.State.AWAKE:
			awake += 1
	d.check(awake == 5, "all five are still awake (%d)" % awake)
	d.check((world.get_node("Travel_yard") as TravelPoint).found, "the fast travel points are still found")


func _slots(before: Dictionary) -> void:
	game.call(&"use_slot", 2)
	d.check(game.call(&"keys") == 0 and game.get(&"slot") == 2, "slot 2 is a new game (%d Keys)" % game.call(&"keys"))
	var s1: Dictionary = game.call(&"slot_summary", 1)
	d.check(s1.get("keys", -1) == before["keys"], "slot 1's summary shows its %d Keys" % s1.get("keys", -1))
	game.call(&"use_slot", 1)
	d.check(_snapshot() == before, "back in slot 1, it's all there")


func _pause_tallies() -> void:
	var text: String = hud.call(&"_tally_text")
	d.check(text.contains("Velvet Roses: %d." % game.call(&"keys")) and text.contains("The Velvet Claw"),
		"the pause screen tallies it (hub line and %d roses)" % game.call(&"keys"))
