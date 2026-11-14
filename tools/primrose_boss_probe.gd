extends SceneTree
## Mrs Gander's fight in her garden (WO-015 step 4), with real input on a Close where the party's done (the garden door
## open), Nim with the crop and the Scold, the bulldogs and the Watch cleared off:
##   - in through her back door: it locks, and her welcome;
##   - the garden party: after her by her honks, three strikes (each time she runs to another hiding place), and a guest
##     struck by mistake undoes one;
##   - the sprinklers: the flood rises; up on the topiary, the crop cracks all six heads, and the water drains;
##   - the tantrum: a strike only makes it worse; the Scold freezes her, she sits down, a strike ties her;
##   - bound to her own bench, the order book, Grizelda's verdict, the paper; Primrose done.
## The steps are tools/primrose_steps.gd (primrose_flow plays them all in one game).
##   godot --headless --fixed-fps 60 --path . -s tools/primrose_boss_probe.gd

const Driver := preload("res://tools/probe_driver.gd")
const Steps := preload("res://tools/primrose_steps.gd")
const SCENE := "res://levels/primrose/primrose.tscn"

var d: Driver


func _initialize() -> void:
	await process_frame
	var game := root.get_node("/root/Game")
	game.set(&"persist", false)
	game.call(&"set_setting", "age_confirmed", true)
	game.call(&"reset")
	for f: String in ["primrose/party_done", "primrose/bells_rung", "primrose/lesson_done", "gear_crop", "gear_scold",
			"lesson_fetch_open"]:
		game.call(&"set_flag", f)
	var level: Node = load(SCENE).instantiate()
	root.add_child(level)
	current_scene = level
	await physics_frame
	d = Driver.new(self, level.get(&"nim"), level.get(&"cam"))
	var s := Steps.new(self, d, level)
	await s.clear_guards()
	await s.boss_enter()
	await s.boss_garden_party()
	await s.boss_sprinklers()
	await s.boss_tantrum()
	print("primrose boss probe: %d failures" % d.fails)
	quit(1 if d.fails else 0)
