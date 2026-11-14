extends SceneTree
## Dash's race after a reload (owner, Deck review 4: saved and quit mid-race, and back on the Pier "there is no way to
## restart the race"). With the race left running in the save, the Pier loads with Dash at her hut offering a
## rematch, and talking to her (real input) starts one.
##   godot --headless --fixed-fps 60 --path . -s tools/race_reload_probe.gd

const Driver := preload("res://tools/probe_driver.gd")


func _initialize() -> void:
	await process_frame
	var game := root.get_node("/root/Game")
	game.set(&"persist", false)
	game.call(&"set_setting", "age_confirmed", true)
	game.call(&"reset")
	game.call(&"set_flag", "pier/race_on")   # a race running when the game was saved
	var pier: Node = load("res://levels/pier/pier.tscn").instantiate()
	root.add_child(pier)
	current_scene = pier
	await physics_frame
	await physics_frame
	var d := Driver.new(self, pier.get(&"nim"), pier.get(&"cam"))
	d.check(not game.call(&"has_flag", "pier/race_on") and game.call(&"has_flag", "pier/race_lost"),
		"a race left running in the save is over when the Pier loads: a rematch")
	var dash := pier.find_child("Dash", true, false) as Node3D
	await d.place(dash.global_position + (-(dash.global_basis.z)) * 1.3, 0.0)
	await d.frames(3)
	await d.tap(JOY_BUTTON_Y)
	await d.talk_through(10.0)   # "Back for more?" and its first choice, "Again."
	await d.secs(0.5)
	d.check(game.call(&"has_flag", "pier/race_on"), "talking to Dash starts the rematch (race_on %s)" % game.call(&"has_flag", "pier/race_on"))
	print("race reload probe: %d failures" % d.fails)
	quit(1 if d.fails else 0)
