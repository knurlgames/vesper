extends SceneTree
## The Backroom's board (owner, 2026-11-13: the pinboard "Alongside" the gates): with real input, Y at the board opens
## Swyne's chain (the world paused), the Pier's card is open (her first rose), Primrose Close's names its roses, and A
## on the Pier takes her there.
##   godot --headless --fixed-fps 60 --path . -s tools/board_probe.gd

const Driver := preload("res://tools/probe_driver.gd")


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1280, 800)
	var game := root.get_node("/root/Game")
	game.set(&"persist", false)
	game.call(&"set_setting", "age_confirmed", true)
	game.call(&"reset")
	game.call(&"set_flag", "hub/prologue_done")
	game.call(&"collect", &"key", &"hub", &"hub_10")
	var hub: Node = load("res://levels/hub/hub.tscn").instantiate()
	root.add_child(hub)
	current_scene = hub
	await physics_frame
	await physics_frame
	var d := Driver.new(self, hub.get(&"nim"), hub.get(&"cam"))
	var board := hub.get_node("Board") as Node3D
	await d.place(board.global_position + Vector3(0, 0, 1.2), 0.0)
	await d.frames(3)
	await d.tap(JOY_BUTTON_Y)
	await d.frames(5)
	var layer: Node = board.get(&"_layer")
	d.check(layer != null and paused, "Y at the board opens Swyne's chain, the world paused")
	if layer:
		var rows: Array = layer.find_children("*", "Button", true, false)
		var texts: Array = rows.map(func(b: Button) -> String: return b.text)
		d.check(rows.size() == 7 and String(texts[0]).contains("OPEN") and String(texts[1]).to_lower().contains("6 roses"),
			"a card a world: the Pier open, Primrose Close at 6 roses (%s)" % str(texts))
		d.check(String(board.get(&"_status").text).begins_with("Open"), "the Pier's brief says it's open (%s)" % board.get(&"_status").text)
		await d.tap(JOY_BUTTON_A)
		var went := await d.until(func() -> bool: return current_scene != null and current_scene.scene_file_path.ends_with("pier.tscn"), 10.0)
		d.check(went, "A on the Pier takes her there (%s)" % (current_scene.scene_file_path if current_scene else "none"))
	print("board probe: %d failures" % d.fails)
	quit(1 if d.fails else 0)
