extends RefCounted
## Primrose Close played step by step with real input, shared by the probes (WO-015): primrose_keys_probe and
## primrose_boss_probe run groups of these on a fresh Close; primrose_flow runs all of them in one game, from the hub.
## Each step checks what it should through the driver (d.check) and leaves Nim somewhere sensible. (The Pier's are
## tools/pier_steps.gd.) Outfits change by `outfit()` (the wardrobes are primrose_probe's), as the keys probe always did.

const Driver := preload("res://tools/probe_driver.gd")
const TOWER := Vector3(65.0, 0.0, -55.0)
const BELFRY := 14.0
const LINE_Y := 3.7
const SUIT := 1
const GARB := 0
## The topiary ball beside each sprinkler head (gander.gd's HEADS, 1.8 m east of each): its top, 3.08 up.
const PERCHES := [Vector3(-15.0, 3.1, -152.0), Vector3(5.0, 3.1, -152.0), Vector3(-5.0, 3.1, -160.0),
	Vector3(15.0, 3.1, -160.0), Vector3(-15.0, 3.1, -168.0), Vector3(5.0, 3.1, -168.0)]

var tree: SceneTree
var d: Driver
var level: Node
var game: Node
var dialogue: Node


func _init(t: SceneTree, driver: Driver, lvl: Node) -> void:
	tree = t
	d = driver
	level = lvl
	game = t.root.get_node("/root/Game")
	dialogue = t.root.get_node("/root/Dialogue")


# --- helpers ---------------------------------------------------------------------------------------------------------

## The bulldogs and the Watch's lookouts off the Close (the fights and the sight lines are other probes').
func clear_guards() -> void:
	for n: Node in level.find_children("*", "Enemy", true, false) + level.find_children("*", "Lookout", true, false):
		n.get_parent().remove_child(n)
		n.queue_free()
	await d.frames(5)


func has(id: StringName) -> bool:
	return game.call(&"has_collected", &"key", &"primrose", id)


func flag(f: String) -> bool:
	return game.call(&"has_flag", f)


func outfit(o: int) -> void:
	d.nim.suit.set_outfit(o)
	await d.frames(3)


## Stood at `at`, turned toward `look` (a short nudge of the stick, then still).
func stand(at: Vector3, look: Vector3) -> void:
	var to := look - at
	to.y = 0.0
	await d.place(at + Vector3(0, 0.05, 0), atan2(-to.x, -to.z))
	d.steer(to, 0.15)
	await d.frames(4)
	d.stick(0, 0)
	await d.frames(4)


func walk_to(target: Vector3, timeout := 20.0, near := 0.6) -> bool:
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
func converse(what: String, timeout := 4.0) -> bool:
	var started := await d.until(func() -> bool: return dialogue.call(&"is_active"), timeout)
	var ended := started and await d.talk_through(40.0)
	d.check(started and ended, what)
	return started and ended


## A deed's rose is tossed down: wait for it to land, and pick it up if she's moved off it.
func got(id: StringName, world: StringName = &"primrose") -> bool:
	var held := func() -> bool: return game.call(&"has_collected", &"key", world, id)
	if await d.until(held, 1.8):
		return true
	var rose := level.find_child("Key_%s" % id, true, false) as Node3D
	if rose:
		await walk_to(rose.global_position, 6.0, 0.3)
	return await d.until(held, 1.5)


## In the suit, the word on the D-pad and Y at whoever's in front.
func command(word: JoyButton) -> void:
	await d.tap(word)
	await d.frames(2)
	await d.tap(JOY_BUTTON_Y)
	await d.frames(2)


# --- the lesson and the Keys -------------------------------------------------------------------------------------------

func lesson() -> void:
	var l: Node = level.get_node("VesperLesson")
	await outfit(GARB)
	await stand(Vector3(4.6, 0.12, 0.6), Vector3(7.6, 0.12, 0.6))
	await converse("in her garb, Vesper sends her to change first")
	await outfit(SUIT)
	await stand(Vector3(5.0, 0.12, -1.0), Vector3(8.4, 0.12, -3.2))
	await converse("in the suit: Vesper on the Watch, and she asks for the hut key")
	await converse("he fetches it to her hand; she asks him to open the hut", 12.0)
	await converse("he opens it; she teaches Fetch and Open", 12.0)
	d.check(d.nim.knows(Lessons.FETCH_OPEN) and (l.get(&"hut_door") as Door).is_open,
		"Nim knows Fetch and Open, and the hut's open")
	# Her turn, out of Vesper's reach (Y beside her would talk), the watchman in front.
	await stand(Vector3(5.6, 0.12, -4.4), Vector3(8.4, 0.12, -3.2))
	await command(JOY_BUTTON_DPAD_RIGHT)
	var fetched := await d.until(func() -> bool: return d.nim.suit.keys.has(&"thermos"), 12.0)
	d.check(fetched, "Fetch: the watchman brings her his thermos")
	await d.until(func() -> bool: return (l.get(&"watchman") as Staff).state == Staff.State.IDLE, 8.0)
	await stand(Vector3(5.6, 0.12, -2.4), Vector3(8.4, 0.12, -3.2))
	await command(JOY_BUTTON_DPAD_DOWN)
	var opened := await d.until(func() -> bool: return (l.get(&"postbox") as Door).is_open, 12.0)
	d.check(opened, "Open: he opens the postbox")
	await converse("the forty invitations, and Vesper's piece", 6.0)
	d.check(flag("primrose/lesson_done"), "the lesson's done")


func tea() -> void:
	await outfit(GARB)
	await stand(Vector3(7.8, 0.08, -24.4), Vector3(9.4, 0.08, -24.4))
	await d.tap(JOY_BUTTON_Y)
	await converse("Grizelda at number 4 sets the test")
	await outfit(SUIT)
	await stand(Vector3(10.0, 0.08, -19.6), Vector3(11.5, 0.08, -19.6))
	var c0: float = d.nim.suit.composure
	await d.tap(JOY_BUTTON_Y)
	await converse("tea with the three ladies, poised throughout")
	await d.talk_through(10.0)   # (Grizelda's verdict follows straight on: often read through with the tea)
	d.check(await got(&"primrose_01") and d.nim.knows(Lessons.SCOLD) and d.nim.suit.composure >= c0 - 0.01,
		"Key 1: Grizelda's test, Composure kept (%.2f), and the Scold" % d.nim.suit.composure)


func cake() -> void:
	await outfit(SUIT)
	await stand(Vector3(60.4, 0.12, -28.4), Vector3(62.4, 0.12, -28.9))
	await command(JOY_BUTTON_DPAD_RIGHT)
	var ok := await d.until(func() -> bool: return d.nim.suit.keys.has(&"cake"), 12.0)
	d.check(ok, "Fetch: the stallholder brings her the reserved cake")
	await converse("the cake's a box of toys with icing on it", 4.0)
	d.check(await got(&"primrose_02"), "Key 2: the bake sale")


func raffle() -> void:
	var r: Node = level.get_node("Raffle")
	# The vicar, from his table's east end (the drum out of reach).
	await stand(Vector3(69.7, 0.12, -36.6), Vector3(68.0, 0.12, -37.0))
	await d.tap(JOY_BUTTON_Y)
	await converse("a strip of raffle tickets: number forty-seven")
	# The drum, from the front, when he turns to count the float.
	await stand(Vector3(68.0, 0.12, -34.1), Vector3(68.0, 0.12, -35.0))
	await d.until(func() -> bool: return not flag("primrose/vicar_looking"), 10.0)
	await d.tap(JOY_BUTTON_Y)
	await converse("while he's turned away, the drum stuffed with forty-sevens")
	d.check(flag("primrose/stuffed"), "the draw's fixed")
	await stand(Vector3(69.7, 0.12, -36.6), Vector3(68.0, 0.12, -37.0))
	await d.tap(JOY_BUTTON_Y)
	await converse("the draw: all forty-sevens, and the vicar's relieved")
	d.check(await got(&"primrose_03") and r != null, "Key 3: the raffle")


func bells() -> void:
	await outfit(GARB)
	await stand(TOWER + Vector3(-1.0, BELFRY + 0.3, 0.6), TOWER + Vector3(1.6, BELFRY + 0.3, -1.6))
	await converse("in the belfry: Vesper, \"Mind the bells\"")
	await converse("the bells go off", 10.0)
	d.check(flag("primrose/bells_rung"), "the bells rung")
	await walk_to(TOWER + Vector3(-1.4, 0, -1.4), 5.0, 0.25)
	d.check(await d.until(func() -> bool: return has(&"primrose_04"), 2.0), "Key 4: the steeple")


func stash() -> void:
	await outfit(GARB)
	await stand(Vector3(-60.0, 0.0, -108.6), Vector3(-60.0, 0.0, -112.0))
	await d.tap(JOY_BUTTON_Y)
	await converse("the marrows lifted: the stash under them")
	var ok := await walk_to(Vector3(-51.6, 0, -105.0), 8.0)
	ok = ok and await walk_to(Vector3(-51.6, 0, 3.0), 30.0)
	ok = ok and await walk_to(Vector3(-44.0, 0, 4.0), 6.0)
	d.check(ok, "out of the Allotments by the lane %s" % d.at())
	d.check(await got(&"primrose_05"), "Key 5: the allotment stash, out unseen")


func lines() -> void:
	# Up on the west line at the gardens' south end, and along it to the north end: never a foot on a lawn.
	await d.place(Vector3(-35.0, LINE_Y + 0.05, -6.0), PI)
	await d.frames(10)
	d.check(level.get_node("WashingLines").get(&"running"), "on the line at the south end: the run's on")
	var ok := await d.until(func() -> bool:
		d.steer(Vector3(0, 0, -1), 0.7)
		return d.nim.global_position.z < -83.0 or (d.nim.is_on_floor() and d.nim.global_position.y < 0.5), 130.0)
	d.stick(0, 0)
	d.check(ok and d.nim.global_position.y > 1.4, "end to end on the washing line %s" % d.at())
	d.check(await got(&"primrose_06"), "Key 6: the washing lines")


func logbook() -> void:
	await outfit(SUIT)
	await stand(Vector3(10.6, 0.12, 1.4), Vector3(12.35, 0.08, 1.2))
	var c0: float = d.nim.suit.composure
	await d.tap(JOY_BUTTON_Y)
	await converse("the Watch captain, as head office: no slips")
	d.check(await got(&"primrose_07") and d.nim.suit.composure >= c0 - 0.01, "Key 7: the Watch's logbook")


func van() -> void:
	var v: Node = level.get_node("Van")
	await outfit(SUIT)
	# In the van's garden (between the fences at z -52 and -64), the driver in front.
	await stand(Vector3(-31.0, 0.08, -62.6), Vector3(-35.0, 0.08, -61.9))
	await command(JOY_BUTTON_DPAD_DOWN)
	var opened := await d.until(func() -> bool: return (v.get(&"doors") as Door).is_open, 12.0)
	d.check(opened, "Open: the driver opens the van's back doors himself")
	d.check(await d.until(func() -> bool: return has(&"primrose_08") or level.find_child("Key_primrose_08", true, false) != null, 5.0)
		and await got(&"primrose_08"), "Key 8: the van")


## Key 9, the demonstration party: the husbands sent off with Fetch and Open, Mrs Gander's go-ahead, then the party
## played by its hint() (answers, the brochure, the swaps). With `bad_first`, a bad party first (the hard sell every
## time, swapping in plain sight: her cover goes, Mrs Gander calls it a night, nothing won), then the good one. Her
## back door's unlocked after.
func party(bad_first := true) -> void:
	var p: Node = level.get_node("Party")
	await outfit(SUIT)
	var h1 := level.find_child("Husband_Ashby", true, false) as Staff
	var h2 := level.find_child("Husband_Primm", true, false) as Staff
	await stand(Vector3(4.4, 0.08, -119.6), h1.global_position)
	await command(JOY_BUTTON_DPAD_RIGHT)
	var bag := await d.until(func() -> bool: return d.nim.suit.keys.has(&"consultant_bag"), 15.0)
	d.check(bag, "Fetch: Mr Ashby brings in the consultant's bag from the step")
	await stand(Vector3(-5.0, 0.08, -131.4), h2.global_position)
	await command(JOY_BUTTON_DPAD_DOWN)
	var ready := await d.until(func() -> bool: return flag("primrose/party_ready"), 15.0)
	d.check(ready and (p.get(&"cupboard") as Door).is_open, "Open: Mr Primm opens the kit cupboard, and both men are off to the pub")
	var left := await d.until(func() -> bool: return level.find_child("Husband_*", true, false) == null, 15.0)
	d.check(left, "the husbands walk out of the front door and away")
	if bad_first:
		await stand(Vector3(-7.6, 0.08, -126.6), Vector3(-9.3, 0.08, -126.6))
		await d.tap(JOY_BUTTON_Y)
		await converse("Mrs Gander: the men are out, the kit's open; the party begins")
		var bad := await play_party(p, true)
		d.check(bad.started and bad.done and not flag("primrose/party_done") and d.nim.suit.cover_blown
			and (p.get(&"gander") as Talker).label == "again",
			"a bad party (the hard sell, swaps seen): her cover's blown, Mrs Gander calls it a night, no Key")
		# A fresh suit (number 4's porch, as the note says: the change restores her cover), and again.
		await outfit(SUIT)
		d.nim.suit.set(&"cover_blown", false)
		d.nim.suit.set(&"composure", 1.0)
	await stand(Vector3(-7.6, 0.08, -126.6), Vector3(-9.3, 0.08, -126.6))
	await d.tap(JOY_BUTTON_Y)
	await converse("asked again: \"this time, dear, sell something\"" if bad_first else
		"Mrs Gander: the men are out, the kit's open; the party begins")
	var good := await play_party(p, false)
	d.check(good.started and good.done and flag("primrose/party_done") and int(p.get(&"swaps")) >= 3,
		"the party: four toys, honest answers, %d swaps unseen; booked for three more (lowest Composure %.2f)" % [
		int(p.get(&"swaps")), good.low])
	d.check(not level.get_node("GardenDoor").call(&"is_locked"), "Mrs Gander's off to her garden: the back door's unlocked")
	d.check(await got(&"primrose_09"), "Key 9: the demonstration party")


## The party played to its end by its hint(), or (`bad`) the wrong answer every time and A held through every swap.
## Returns {started, done, low (the lowest Composure)}.
func play_party(p: Node, bad: bool) -> Dictionary:
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
func curtains() -> void:
	var c: Node = level.get_node("Curtains")
	var w: Array = (level.get(&"curtains") as Array)[0]
	var at: Vector3 = w[0]
	var out: Vector3 = w[1]
	var spot := at + out * 2.4
	spot.y = 0.1
	await outfit(SUIT)
	await stand(spot, at)
	var t0: int = c.get(&"twitches")
	await d.secs(2.0)
	d.check(int(c.get(&"twitches")) == t0, "in front of a lit window in the suit: no twitch")
	await outfit(GARB)
	var twitched := await d.until(func() -> bool: return int(c.get(&"twitches")) > t0, 4.0)
	d.check(twitched, "in her garb: the curtain twitches (at %s, window %s)" % [d.at(), at])


## Key 10: the five neighbours mowing in a trance, each woken by a strike at the toy in their hands, from in front
## (they keep walking their loops: found where they are each try).
func sleepers() -> void:
	await outfit(GARB)
	for i in 5:
		var id := StringName("n%d" % (i + 1))
		var e := level.get_node_or_null("Entranced_%s" % id) as Node3D
		var woke := false
		for k in 8:
			if e == null:
				break
			var f := -e.global_basis.z
			f.y = 0.0
			f = f.normalized()
			await d.place(e.global_position + f * 1.1 + Vector3(0, 0.05, 0), atan2(f.x, f.z))
			await d.tap(JOY_BUTTON_X)
			await d.secs(0.5)
			if game.call(&"has_collected", &"freed", &"primrose", id):
				woke = true
				break
		d.check(woke, "the neighbour %s woken from the mowing" % id)
	d.check(await got(&"primrose_10"), "Key 10: all five woken, and the rose tossed down for it picked up")


## The Coalition's collection tin on the church porch: smashed, it pays the hub its rose.
func tin() -> void:
	await outfit(GARB)
	var t: Node3D = null
	for p: Node in level.find_children("*", "Pickup", true, false):
		if p.get(&"kind") == &"tin":
			t = p as Node3D
	d.check(t != null, "the collection tin is on the porch")
	if t == null:
		return
	var at := t.global_position
	# From whichever side is clear (the porch's walls are on some): a strike, until it breaks.
	for away: Vector3 in [Vector3(-1, 0, 0), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		if not is_instance_valid(t) or game.call(&"has_collected", &"tin", &"primrose", &"tin"):
			break
		await stand(Vector3(at.x, 0.0, at.z) + away * 1.1, at)
		await d.tap(JOY_BUTTON_X)
		await d.secs(0.5)
	d.check(await got(&"tin_primrose", &"hub"), "the collection tin, smashed: the hub's rose (tin_primrose)")


# --- Mrs Gander --------------------------------------------------------------------------------------------------------

func boss() -> Node:
	return level.get_node("Gander")


func phase() -> int:
	return int(boss().get(&"phase"))


func boss_enter() -> void:
	await outfit(GARB)
	d.check(not level.get_node("GardenDoor").call(&"is_locked"), "after the party, her back door's open")
	await d.place(Vector3(0, 0.1, -132.0), PI)
	var ok := await d.until(func() -> bool:
		if dialogue.call(&"is_active"):
			return true
		d.steer(Vector3(0, 0, -1))
		return false, 8.0)
	d.stick(0, 0)
	d.check(ok, "through her back door into the garden: her welcome")
	await d.talk_through(30.0)
	d.check((boss().get(&"_lock") as LockDoor).is_locked(), "the door's locked behind her")
	# Out of the conservatory by its glass door, between the swans, onto the lawn.
	d.check(await walk_to(Vector3(0.0, 0, -148.5), 8.0), "out through the conservatory's glass door, onto the lawn")


func boss_garden_party() -> void:
	var b := boss()
	var g: Node3D = b.get(&"gander")
	var guest: Node3D = (b.get(&"_guests") as Array)[0][0]
	# A guest first, by mistake: one hit undone (from none, so none).
	var guest_ok := await d.until(func() -> bool:
		var to := guest.global_position - d.nim.global_position
		to.y = 0.0
		if to.length() > 1.2:
			d.steer(to)
			return false
		d.steer(to, 0.15)
		return true, 15.0)
	d.stick(0, 0)
	await d.frames(3)
	await d.tap(JOY_BUTTON_X)
	await d.secs(0.6)
	d.check(guest_ok, "a guest in a trance struck by mistake (Gander laughs; nothing gained)")
	var h0: int = d.nim.combat.health
	# [where she was a second ago, frames left of side-stepping] (round the topiary when she's stuck on it)
	var stuck := [d.nim.global_position, 0]
	var ok := await d.until(func() -> bool:
		if phase() != 2:
			return true
		if b.get(&"_running"):
			d.button(JOY_BUTTON_X, false)
			d.stick(0, 0)
			return false
		var to := g.global_position - d.nim.global_position
		to.y = 0.0
		if Engine.get_physics_frames() % 60 == 0:
			if (stuck[0] as Vector3).distance_to(d.nim.global_position) < 0.3 and to.length() > 1.6:
				stuck[1] = 30
			stuck[0] = d.nim.global_position
		if int(stuck[1]) > 0:
			stuck[1] = int(stuck[1]) - 1
			d.steer(to.normalized().cross(Vector3.UP) + to.normalized() * 0.2)
			d.button(JOY_BUTTON_X, false)
			return false
		if to.length() > 1.4:
			d.steer(to)
			d.button(JOY_BUTTON_X, false)
		else:
			d.steer(to, 0.15)
			d.button(JOY_BUTTON_X, not d.nim.combat.striking())
		return false, 120.0)
	d.release_all()
	d.check(ok and phase() >= 3, "the garden party: after her by the honks, three strikes (health %d to %d)" % [h0, d.nim.combat.health])


func boss_sprinklers() -> void:
	var b := boss()
	var risen := await d.until(func() -> bool: return float(b.get(&"_water_y")) > 0.4, 10.0)
	d.check(risen, "the flood: the water's up")
	# Stood in it a while: it knocks the wind out of her.
	await d.place(Vector3(-10.0, 0.1, -156.0), 0.0)
	# (Healed first: she waits out the rising water on the lawn now the conservatory's glass is solid, and comes in
	# low; downed here, she'd be put back outside at full health and the check would read nonsense.)
	d.nim.combat.health = d.nim.combat.max_health
	var h0: int = d.nim.combat.health
	await d.secs(2.8)
	d.check(d.nim.combat.health < h0, "stood in the flood, it hurts (health %d to %d)" % [h0, d.nim.combat.health])
	# Round them all, and round again for any still standing (a swing can land in a honk's knock-back: a few frames'
	# difference in how long the club took first, the hub's gate scene, and one head was left).
	for i in PERCHES.size() * 2:
		if phase() != 3:
			break
		await d.place(PERCHES[i % PERCHES.size()], -PI / 2.0)   # on the ball, facing east to the head beside it
		await d.frames(6)
		d.steer(Vector3(1, 0, 0), 0.12)
		await d.frames(3)
		d.stick(0, 0)
		d.button(JOY_BUTTON_X, true)   # held: the crop
		await d.secs(0.6)
		d.button(JOY_BUTTON_X, false)
		await d.secs(0.5)
	d.check(int(b.get(&"heads_out")) == 6 and phase() == 4,
		"up on the topiary, the crop cracks all six heads (%d)" % int(b.get(&"heads_out")))
	var drained := await d.until(func() -> bool: return float(b.get(&"_water_y")) < 0.05, 6.0)
	d.check(drained, "and the water drains")


func boss_tantrum() -> void:
	var b := boss()
	await d.until(func() -> bool: return not b.get(&"_running"), 8.0)
	var g: Node3D = b.get(&"gander")
	await d.place(Vector3(0.0, 0.1, -148.5), 0.0)
	await d.frames(4)
	# A strike first: you don't fight a tantrum.
	await walk_to(g.global_position, 6.0, 1.3)
	d.steer(g.global_position - d.nim.global_position, 0.15)
	await d.tap(JOY_BUTTON_X)
	await d.secs(0.5)
	d.check(not b.get(&"_sitting") and phase() == 4, "a strike at a tantrum does nothing (but make it worse)")
	await d.tap(JOY_BUTTON_LEFT_SHOULDER)   # the Scold
	var sat := await d.until(func() -> bool: return b.get(&"_sitting"), 5.0)
	d.check(sat, "the Scold: she freezes mid-throw, then sits down on her own")
	await walk_to(g.global_position, 4.0, 1.2)
	d.steer(g.global_position - d.nim.global_position, 0.15)
	await d.tap(JOY_BUTTON_X)
	var tied := await d.until(func() -> bool: return phase() == 5, 3.0)
	d.check(tied, "a strike, and she's tied")
	for i in 80:
		if flag("done/primrose") and not dialogue.call(&"is_active"):
			break
		if dialogue.call(&"is_active"):
			await d.talk_through(30.0)
		else:
			await d.secs(0.25)
	d.check(flag("primrose/gander_bound") and flag("primrose/order_book") and flag("done/primrose"),
		"bound to her own bench, the order book, Grizelda's verdict, the paper: Primrose Close is done")
	d.check(g.global_position.distance_to(Vector3(0.0, 0.9, -173.5)) < 0.2, "she's on her bench, under her sign %s" % g.global_position)
