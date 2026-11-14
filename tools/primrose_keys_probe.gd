extends SceneTree
## Primrose Close's Keys and Vesper's lesson (WO-015 step 2), each played with real input on a fresh Close (the bulldogs
## and the Watch cleared off, as pier_keys_probe does):
##   - Vesper's lesson at the Watch hut: in garb she sends Nim to change; in the suit she shows Fetch and Open on the
##     watchman, teaches them, and Nim does her turn (the thermos fetched, the postbox opened);
##   - Key 1, Grizelda's tea (passed with no slips: Composure kept) and the Scold; Key 2, the cake fetched; Key 3, the
##     raffle (a ticket, the drum stuffed while the vicar's turned away, the draw); Key 4, the belfry's bells; Key 5,
##     the marrows lifted and out of the Allotments; Key 6, the washing lines end to end; Key 7, the Watch captain's
##     logbook; Key 8, the van opened by its driver; Key 9, the party, a bad one first;
##   - the curtain twitchers: a lit window sees her in garb, never in the suit.
## The steps are tools/primrose_steps.gd (primrose_flow plays them all in one game).
##   godot --headless --fixed-fps 60 --path . -s tools/primrose_keys_probe.gd

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
	var level: Node = load(SCENE).instantiate()
	root.add_child(level)
	current_scene = level
	await physics_frame
	d = Driver.new(self, level.get(&"nim"), level.get(&"cam"))
	var s := Steps.new(self, d, level)
	await s.clear_guards()
	await s.lesson()
	await s.tea()
	await s.cake()
	await s.raffle()
	await s.bells()
	await s.stash()
	await s.lines()
	await s.logbook()
	await s.van()
	await s.curtains()
	await s.party(true)
	var keys := 0
	for i in range(1, 10):
		if s.has(StringName("primrose_%02d" % i)):
			keys += 1
	d.check(keys == 9, "Keys 1 to 9 all taken (%d)" % keys)
	print("primrose keys probe: %d failures" % d.fails)
	quit(1 if d.fails else 0)
