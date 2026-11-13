extends SceneTree
## Laffer's fight in the Prize Hall (WO-014 step 4), with real input on a fresh Pier with the ledger (the pier's own
## goons and gulls cleared off). The steps are tools/pier_steps.gd's:
##   - in, the door locks, Laffer's welcome; downed and back in (the door opens, the phase waits, no second welcome);
##   - the Claw: a drop side-stepped, a drop taken; the stuck claw's cable climbed, the bridge walked to his gallery;
##   - whack-a-goon: three hits at the hatches, following the gull's calls; goons came up;
##   - the prize mountain: the toy, the steps through the boxes, the pounce; the rosette, Vesper, the paper.
##   godot --headless --fixed-fps 60 --path . -s tools/pier_boss_probe.gd

const Driver := preload("res://tools/probe_driver.gd")
const Steps := preload("res://tools/pier_steps.gd")
const PIER := "res://levels/pier/pier.tscn"


func _initialize() -> void:
	await process_frame
	var game := root.get_node("/root/Game")
	game.set(&"persist", false)
	game.call(&"set_setting", "age_confirmed", true)
	game.call(&"reset")
	game.call(&"set_flag", "pier/ledger")
	var pier: Node = load(PIER).instantiate()
	root.add_child(pier)
	current_scene = pier
	await physics_frame
	var d := Driver.new(self, pier.get(&"nim"), pier.get(&"cam"))
	var s := Steps.new(self, d, pier)
	for n: Node in pier.find_children("*", "Enemy", true, false) + pier.find_children("*", "Lookout", true, false):
		s.remove(n)
	await d.frames(5)
	await s.boss_enter()
	await s.boss_claw()
	await s.boss_whack()
	await s.boss_mountain()
	print("pier boss probe: %d failures" % d.fails)
	quit(1 if d.fails else 0)
