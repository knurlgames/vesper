extends SceneTree
## The Pier's Keys and Vesper's lesson (WO-014 steps 2 and 3), each played with real input on a fresh Pier (the
## Midway's goons, the bouncer, the palace's two and the gulls cleared off; she's put in the suit for the suit Keys).
## The steps are tools/pier_steps.gd's:
##   - Vesper's lesson (her own camera on the drop); Key 2, the landing; Key 1, Dash's race and the crop;
##   - Key 4, the high striker; a gull hushed with the crop; Key 6, the safe; Key 9, the Big Dipper (a miss, then the
##     catch);
##   - in the suit: Key 3, the gallery; Key 5, Madame Pearl; Key 7, the clerk.
## (Key 8, Key 10 and the tin are pier_probe's and pier_flow's.)
##   godot --headless --fixed-fps 60 --path . -s tools/pier_keys_probe.gd

const Driver := preload("res://tools/probe_driver.gd")
const Steps := preload("res://tools/pier_steps.gd")
const PIER := "res://levels/pier/pier.tscn"


func _initialize() -> void:
	await process_frame
	var game := root.get_node("/root/Game")
	game.set(&"persist", false)
	game.call(&"set_setting", "age_confirmed", true)
	game.call(&"reset")
	var pier: Node = load(PIER).instantiate()
	root.add_child(pier)
	current_scene = pier
	await physics_frame
	var d := Driver.new(self, pier.get(&"nim"), pier.get(&"cam"))
	var s := Steps.new(self, d, pier)
	for id: String in ["m_rounds1", "m_rounds2", "m_tackle", "bouncer", "p_rounds", "p_office"]:
		s.remove(s.goon(id))
	for n: Node in pier.find_children("*", "Lookout", true, false):
		s.remove(n)
	await d.frames(5)
	await s.lesson()
	await s.landing()
	await s.race()
	await s.fence()
	await s.striker()
	await s.hush_a_gull()
	await s.safe()
	await s.dipper()
	d.nim.suit.set_outfit(NimSuit.Outfit.SUIT)
	await d.frames(5)
	await s.gallery()
	await s.pearl()
	await s.clerk()
	var keys := 0
	for i in range(1, 10):
		if s.has_key(StringName("pier_%02d" % i)):
			keys += 1
	d.check(keys == 8, "Keys 1 to 7 and 9 all taken (%d)" % keys)
	print("pier keys probe: %d failures" % d.fails)
	quit(1 if d.fails else 0)
