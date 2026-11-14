extends SceneTree
## Primrose Close's Keys and Vesper's lesson (WO-015 step 2), each played with real input on a fresh Close (the bulldogs
## and the Watch cleared off, as pier_keys_probe does):
##   - Vesper's lesson at the Watch hut: in garb she sends Nim to change; in the suit she shows Fetch and Open on the
##     watchman, teaches them, and Nim does her turn (the thermos fetched, the postbox opened);
##   - Key 1, Grizelda's tea (passed with no slips: Composure kept) and the Scold; Key 2, the cake fetched; Key 3, the
##     raffle (a ticket, the drum stuffed while the vicar's turned away, the draw); Key 4, the belfry's bells; Key 5,
##     the marrows lifted and out of the Allotments; Key 6, the washing lines end to end; Key 7, the Watch captain's
##     logbook; Key 8, the van opened by its driver;
##   - the curtain twitchers: a lit window sees her in garb, never in the suit.
##   godot --headless --fixed-fps 60 --path . -s tools/primrose_keys_probe.gd

const Driver := preload("res://tools/probe_driver.gd")
const SCENE := "res://levels/primrose/primrose.tscn"
const TOWER := Vector3(65.0, 0.0, -55.0)
const BELFRY := 14.0
const LINE_Y := 3.7
const SUIT := 1
const GARB := 0

var d: Driver
var level: Node
var game: Node
var dialogue: Node


func _initialize() -> void:
	await process_frame
	game = root.get_node("/root/Game")
	dialogue = root.get_node("/root/Dialogue")
	game.set(&"persist", false)
	game.call(&"set_setting", "age_confirmed", true)
	game.call(&"reset")
	level = load(SCENE).instantiate()
	root.add_child(level)
	current_scene = level
	await physics_frame
	d = Driver.new(self, level.get(&"nim"), level.get(&"cam"))
	for n: Node in level.find_children("*", "Enemy", true, false) + level.find_children("*", "Lookout", true, false):
		n.get_parent().remove_child(n)
		n.queue_free()
	await d.frames(5)
	await _lesson()
	await _tea()
	await _cake()
	await _raffle()
	await _bells()
	await _stash()
	await _lines()
	await _logbook()
	await _van()
	await _curtains()
	await _party()
	var keys := 0
	for i in range(1, 10):
		if _has(StringName("primrose_%02d" % i)):
			keys += 1
	d.check(keys == 9, "Keys 1 to 9 all taken (%d)" % keys)
	print("primrose keys probe: %d failures" % d.fails)
	quit(1 if d.fails else 0)


# --- helpers ---------------------------------------------------------------------------------------------------------

func _has(id: StringName) -> bool:
	return game.call(&"has_collected", &"key", &"primrose", id)


func _flag(f: String) -> bool:
	return game.call(&"has_flag", f)


func _outfit(o: int) -> void:
	d.nim.suit.set_outfit(o)
	await d.frames(3)


## Stood at `at`, turned toward `look` (a short nudge of the stick, then still).
func _stand(at: Vector3, look: Vector3) -> void:
	var to := look - at
	to.y = 0.0
	await d.place(at + Vector3(0, 0.05, 0), atan2(-to.x, -to.z))
	d.steer(to, 0.15)
	await d.frames(4)
	d.stick(0, 0)
	await d.frames(4)


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


## A conversation starts (within `timeout`) and is read through, the first choice each time.
func _converse(what: String, timeout := 4.0) -> bool:
	var started := await d.until(func() -> bool: return dialogue.call(&"is_active"), timeout)
	var ended := started and await d.talk_through(40.0)
	d.check(started and ended, what)
	return started and ended


## A deed's rose is tossed down: wait for it to land, and pick it up if she's moved off it.
func _got(id: StringName) -> bool:
	if await d.until(func() -> bool: return _has(id), 1.8):
		return true
	var rose := level.find_child("Key_%s" % id, true, false) as Node3D
	if rose:
		await _walk_to(rose.global_position, 6.0, 0.3)
	return await d.until(func() -> bool: return _has(id), 1.5)


## In the suit, the word on the D-pad and Y at whoever's in front.
func _command(word: JoyButton) -> void:
	await d.tap(word)
	await d.frames(2)
	await d.tap(JOY_BUTTON_Y)
	await d.frames(2)


# --- the lesson and the Keys -------------------------------------------------------------------------------------------

func _lesson() -> void:
	var lesson: Node = level.get_node("VesperLesson")
	await _outfit(GARB)
	await _stand(Vector3(4.6, 0.12, 0.6), Vector3(7.6, 0.12, 0.6))
	await _converse("in her garb, Vesper sends her to change first")
	await _outfit(SUIT)
	await _stand(Vector3(5.0, 0.12, -1.0), Vector3(8.4, 0.12, -3.2))
	await _converse("in the suit: Vesper on the Watch, and she asks for the hut key")
	await _converse("he fetches it to her hand; she asks him to open the hut", 12.0)
	await _converse("he opens it; she teaches Fetch and Open", 12.0)
	d.check(d.nim.knows(Lessons.FETCH_OPEN) and (lesson.get(&"hut_door") as Door).is_open,
		"Nim knows Fetch and Open, and the hut's open")
	# Her turn, out of Vesper's reach (Y beside her would talk), the watchman in front.
	await _stand(Vector3(5.6, 0.12, -4.4), Vector3(8.4, 0.12, -3.2))
	await _command(JOY_BUTTON_DPAD_RIGHT)
	var fetched := await d.until(func() -> bool: return d.nim.suit.keys.has(&"thermos"), 12.0)
	d.check(fetched, "Fetch: the watchman brings her his thermos")
	await d.until(func() -> bool: return (lesson.get(&"watchman") as Staff).state == Staff.State.IDLE, 8.0)
	await _stand(Vector3(5.6, 0.12, -2.4), Vector3(8.4, 0.12, -3.2))
	await _command(JOY_BUTTON_DPAD_DOWN)
	var opened := await d.until(func() -> bool: return (lesson.get(&"postbox") as Door).is_open, 12.0)
	d.check(opened, "Open: he opens the postbox")
	await _converse("the forty invitations, and Vesper's piece", 6.0)
	d.check(_flag("primrose/lesson_done"), "the lesson's done")


func _tea() -> void:
	await _outfit(GARB)
	await _stand(Vector3(7.8, 0.08, -24.4), Vector3(9.4, 0.08, -24.4))
	await d.tap(JOY_BUTTON_Y)
	await _converse("Grizelda at number 4 sets the test")
	await _outfit(SUIT)
	await _stand(Vector3(10.0, 0.08, -19.6), Vector3(11.5, 0.08, -19.6))
	var c0: float = d.nim.suit.composure
	await d.tap(JOY_BUTTON_Y)
	await _converse("tea with the three ladies, poised throughout")
	await d.talk_through(10.0)   # (Grizelda's verdict follows straight on: often read through with the tea)
	d.check(await _got(&"primrose_01") and d.nim.knows(Lessons.SCOLD) and d.nim.suit.composure >= c0 - 0.01,
		"Key 1: Grizelda's test, Composure kept (%.2f), and the Scold" % d.nim.suit.composure)


func _cake() -> void:
	await _stand(Vector3(60.4, 0.12, -28.4), Vector3(62.4, 0.12, -28.9))
	await _command(JOY_BUTTON_DPAD_RIGHT)
	var got := await d.until(func() -> bool: return d.nim.suit.keys.has(&"cake"), 12.0)
	d.check(got, "Fetch: the stallholder brings her the reserved cake")
	await _converse("the cake's a box of toys with icing on it", 4.0)
	d.check(await _got(&"primrose_02"), "Key 2: the bake sale")


func _raffle() -> void:
	var r: Node = level.get_node("Raffle")
	# The vicar, from his table's east end (the drum out of reach).
	await _stand(Vector3(69.7, 0.12, -36.6), Vector3(68.0, 0.12, -37.0))
	await d.tap(JOY_BUTTON_Y)
	await _converse("a strip of raffle tickets: number forty-seven")
	# The drum, from the front, when he turns to count the float.
	await _stand(Vector3(68.0, 0.12, -34.1), Vector3(68.0, 0.12, -35.0))
	await d.until(func() -> bool: return not _flag("primrose/vicar_looking"), 10.0)
	await d.tap(JOY_BUTTON_Y)
	await _converse("while he's turned away, the drum stuffed with forty-sevens")
	d.check(_flag("primrose/stuffed"), "the draw's fixed")
	await _stand(Vector3(69.7, 0.12, -36.6), Vector3(68.0, 0.12, -37.0))
	await d.tap(JOY_BUTTON_Y)
	await _converse("the draw: all forty-sevens, and the vicar's relieved")
	d.check(await _got(&"primrose_03") and r != null, "Key 3: the raffle")


func _bells() -> void:
	await _outfit(GARB)
	await _stand(TOWER + Vector3(-1.0, BELFRY + 0.3, 0.6), TOWER + Vector3(1.6, BELFRY + 0.3, -1.6))
	await _converse("in the belfry: Vesper, \"Mind the bells\"")
	await _converse("the bells go off", 10.0)
	d.check(_flag("primrose/bells_rung"), "the bells rung")
	await _walk_to(TOWER + Vector3(-1.4, 0, -1.4), 5.0, 0.25)
	d.check(await d.until(func() -> bool: return _has(&"primrose_04"), 2.0), "Key 4: the steeple")


func _stash() -> void:
	await _stand(Vector3(-60.0, 0.0, -108.6), Vector3(-60.0, 0.0, -112.0))
	await d.tap(JOY_BUTTON_Y)
	await _converse("the marrows lifted: the stash under them")
	var ok := await _walk_to(Vector3(-51.6, 0, -105.0), 8.0)
	ok = ok and await _walk_to(Vector3(-51.6, 0, 3.0), 30.0)
	ok = ok and await _walk_to(Vector3(-44.0, 0, 4.0), 6.0)
	d.check(ok, "out of the Allotments by the lane %s" % d.at())
	d.check(await _got(&"primrose_05"), "Key 5: the allotment stash, out unseen")


func _lines() -> void:
	# Up on the west line at the gardens' south end, and along it to the north end: never a foot on a lawn.
	await d.place(Vector3(-35.0, LINE_Y + 0.05, -6.0), PI)
	await d.frames(10)
	d.check(level.get_node("WashingLines").get(&"running"), "on the line at the south end: the run's on")
	var ok := await d.until(func() -> bool:
		d.steer(Vector3(0, 0, -1), 0.7)
		return d.nim.global_position.z < -83.0 or (d.nim.is_on_floor() and d.nim.global_position.y < 0.5), 130.0)
	d.stick(0, 0)
	d.check(ok and d.nim.global_position.y > 1.4, "end to end on the washing line %s" % d.at())
	d.check(await _got(&"primrose_06"), "Key 6: the washing lines")


func _logbook() -> void:
	await _outfit(SUIT)
	await _stand(Vector3(10.6, 0.12, 1.4), Vector3(12.35, 0.08, 1.2))
	var c0: float = d.nim.suit.composure
	await d.tap(JOY_BUTTON_Y)
	await _converse("the Watch captain, as head office: no slips")
	d.check(await _got(&"primrose_07") and d.nim.suit.composure >= c0 - 0.01, "Key 7: the Watch's logbook")


func _van() -> void:
	var v: Node = level.get_node("Van")
	# In the van's garden (between the fences at z -52 and -64), the driver in front.
	await _stand(Vector3(-31.0, 0.08, -62.6), Vector3(-35.0, 0.08, -61.9))
	await _command(JOY_BUTTON_DPAD_DOWN)
	var opened := await d.until(func() -> bool: return (v.get(&"doors") as Door).is_open, 12.0)
	d.check(opened, "Open: the driver opens the van's back doors himself")
	d.check(await d.until(func() -> bool: return _has(&"primrose_08") or level.find_child("Key_primrose_08", true, false) != null, 5.0)
		and await _got(&"primrose_08"), "Key 8: the van")


## Key 9, the demonstration party: the husbands sent off with Fetch and Open, Mrs Gander's go-ahead, then the party
## played by its hint() (answers, the brochure, the swaps). Her back door's unlocked after.
func _party() -> void:
	var p: Node = level.get_node("Party")
	await _outfit(SUIT)
	var h1 := level.find_child("Husband_Ashby", true, false) as Staff
	var h2 := level.find_child("Husband_Primm", true, false) as Staff
	await _stand(Vector3(4.4, 0.08, -119.6), h1.global_position)
	await _command(JOY_BUTTON_DPAD_RIGHT)
	var bag := await d.until(func() -> bool: return d.nim.suit.keys.has(&"consultant_bag"), 15.0)
	d.check(bag, "Fetch: Mr Ashby brings in the consultant's bag from the step")
	await _stand(Vector3(-5.0, 0.08, -131.4), h2.global_position)
	await _command(JOY_BUTTON_DPAD_DOWN)
	var ready := await d.until(func() -> bool: return _flag("primrose/party_ready"), 15.0)
	d.check(ready and (p.get(&"cupboard") as Door).is_open, "Open: Mr Primm opens the kit cupboard, and both men are off to the pub")
	var left := await d.until(func() -> bool: return level.find_child("Husband_*", true, false) == null, 15.0)
	d.check(left, "the husbands walk out of the front door and away")
	# A bad party first: the hard sell every time, and swapping in plain sight. Her cover goes, and Mrs Gander calls it
	# a night; nothing's won, and she can be asked again.
	await _stand(Vector3(-7.6, 0.08, -126.6), Vector3(-9.3, 0.08, -126.6))
	await d.tap(JOY_BUTTON_Y)
	await _converse("Mrs Gander: the men are out, the kit's open; the party begins")
	var bad := await _play_party(p, true)
	d.check(bad.started and bad.done and not _flag("primrose/party_done") and d.nim.suit.cover_blown
		and (p.get(&"gander") as Talker).label == "again",
		"a bad party (the hard sell, swaps seen): her cover's blown, Mrs Gander calls it a night, no Key")
	# A fresh suit (number 4's porch, as the note says: the change restores her cover), and again.
	await _outfit(SUIT)
	d.nim.suit.set(&"cover_blown", false)
	d.nim.suit.set(&"composure", 1.0)
	await _stand(Vector3(-7.6, 0.08, -126.6), Vector3(-9.3, 0.08, -126.6))
	await d.tap(JOY_BUTTON_Y)
	await _converse("asked again: \"this time, dear, sell something\"")
	var good := await _play_party(p, false)
	d.check(good.started and good.done and _flag("primrose/party_done") and int(p.get(&"swaps")) >= 3,
		"the party: four toys, honest answers, %d swaps unseen; booked for three more (lowest Composure %.2f)" % [
		int(p.get(&"swaps")), good.low])
	d.check(level.get_node_or_null("GardenDoor") == null, "Mrs Gander's off to her garden: the back door's unlocked")
	d.check(await _got(&"primrose_09"), "Key 9: the demonstration party")


## The party played to its end by its hint(), or (`bad`) the wrong answer every time and A held through every swap.
## Returns {started, done, low (the lowest Composure)}.
func _play_party(p: Node, bad: bool) -> Dictionary:
	var buttons := {&"jump": JOY_BUTTON_A, &"interact": JOY_BUTTON_Y, &"word_up": JOY_BUTTON_DPAD_UP,
		&"word_right": JOY_BUTTON_DPAD_RIGHT, &"word_down": JOY_BUTTON_DPAD_DOWN}
	var started := await d.until(func() -> bool: return p.get(&"stage") != "", 5.0)
	var low := [1.0]
	var wait := [0]
	var done := await d.until(func() -> bool:
		var stage: String = p.get(&"stage")
		if dialogue.call(&"is_active"):
			wait[0] -= 1
			if wait[0] <= 0:
				d.tap(JOY_BUTTON_A)
				wait[0] = 25
			return false
		if stage == "":
			return true
		low[0] = minf(low[0], d.nim.suit.composure)
		var h: Dictionary = p.call(&"hint")
		if bad:
			if stage == "question" and h.has("tap"):
				# The first answer that isn't the right one.
				for k in 3:
					if not (p.get(&"_answers") as Array)[k][2]:
						h = {"tap": [&"word_up", &"word_right", &"word_down"][k]}
						break
			elif stage == "swap":
				h = {"hold": &"jump", "on": int(Engine.get_physics_frames() / 30) % 2 == 0}   # pressed, again and again
		if OS.get_environment("PROBE_TRACE") != "" and Engine.get_physics_frames() % 60 == 0:
			print("  party: stage %s round %d swaps %d hint %s" % [stage, int(p.get(&"round_i")), int(p.get(&"swaps")), str(h)])
		if h.has("hold"):
			d.button(buttons[h.hold], h.on)
		wait[0] -= 1
		if h.has("tap") and wait[0] <= 0:
			d.tap(buttons[h.tap])
			wait[0] = 8
		return false, 150.0)
	d.release_all()
	await d.talk_through(20.0)
	return {"started": started, "done": done, "low": low[0]}


## A lit window: in front of it, in the suit nothing happens; in her garb, it twitches.
func _curtains() -> void:
	var c: Node = level.get_node("Curtains")
	var w: Array = (level.get(&"curtains") as Array)[0]
	var at: Vector3 = w[0]
	var out: Vector3 = w[1]
	var spot := at + out * 2.4
	spot.y = 0.1
	await _outfit(SUIT)
	await _stand(spot, at)
	var t0: int = c.get(&"twitches")
	await d.secs(2.0)
	d.check(int(c.get(&"twitches")) == t0, "in front of a lit window in the suit: no twitch")
	await _outfit(GARB)
	var twitched := await d.until(func() -> bool: return int(c.get(&"twitches")) > t0, 4.0)
	d.check(twitched, "in her garb: the curtain twitches (at %s, window %s)" % [d.at(), at])
