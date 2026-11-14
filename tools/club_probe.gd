extends SceneTree
## The Velvet Rope's house (WO-014b), with real input:
##   - the vaults are alive: clients in a session, waiting, in aftercare from the start; new ones come in at the door,
##     change, and go down to wait;
##   - Nim's own session (in the suit): the check-in, then the cross (core/cross_scene.gd): agree the form, the
##     feather steered onto their sweet spot, a check-in on yellow: a good scene, and the hub's rose (hub_08);
##   - an impact they can't follow until their word, and B at once: stopped, a good ending;
##   - the same, carrying on through their word: it ends badly;
##   - Silke and Augusta's rich scenes, both ways (core/rich_scene.gd, driven by its hint()): gags, every phase, bonds;
##     the changing screen first (asked in her garb, Silke waits);
##   - Nim on the cross with Silke leading (taped, the bell in her hand; green when asked; Silke walks back to her room);
##   - Nim on the cross with Grizelda, holding B for her word: stopped at once.
##   godot --headless --fixed-fps 60 --path . -s tools/club_probe.gd

const Driver := preload("res://tools/probe_driver.gd")
const HUB := "res://levels/hub/hub.tscn"

var d: Driver
var game: Node
var dialogue: Node
var hub: Node
var life: Node


func _initialize() -> void:
	await process_frame
	game = root.get_node("/root/Game")
	dialogue = root.get_node("/root/Dialogue")
	game.set(&"persist", false)
	game.call(&"set_setting", "age_confirmed", true)
	game.call(&"reset")
	game.call(&"set_flag", "hub/prologue_done")
	game.call(&"set_flag", "done/pier")   # Dash is home from the Pier, in her room
	hub = load(HUB).instantiate()
	root.add_child(hub)
	current_scene = hub
	await physics_frame
	await physics_frame
	d = Driver.new(self, hub.get(&"nim"), hub.get(&"cam"))
	life = hub.get_node("ClubLife")
	await _house()
	await _alive()
	await _session_good()
	await _session_stopped()
	await _session_pushed()
	await _silke_switch()
	await _augusta_domme()
	await _augusta_switch()
	await _silke_cross_sub()
	await _grizelda_word()
	await _augusta_cross_dom()
	await _aftercare_seats()
	await _later_scenes()
	await _later_edges()
	await _smith_story()
	print("club probe: %d failures" % d.fails)
	quit(1 if d.fails else 0)


## Into the right thing for a scene (Deck review 5): the two-piece to be the sub, the suit to lead.
func _dress(sub: bool) -> void:
	d.nim.model.call(&"wear_swim", sub)
	if not sub:
		d.nim.suit.set_outfit(NimSuit.Outfit.SUIT)
	await d.frames(2)


## A scene's "how it goes" card waits for A.
func _past_intro(g: Node) -> bool:
	if is_instance_valid(g) and g.get(&"stage") == "intro":
		d.tap(JOY_BUTTON_A)
		return true
	return false


func _clients(phase := &"") -> Array:
	return get_nodes_in_group(&"club_client").filter(func(c: Node) -> bool:
		return phase == &"" or c.get(&"phase") == phase)


## Deck review 3: the sisters in their Domme suits; no checkpoint flags anywhere inside the club.
func _house() -> void:
	var suits := true
	for s: String in ["Augusta", "Silke", "Grizelda", "Lull", "Rivet"]:
		var t := hub.get_node_or_null(s)
		if t == null or t.get(&"outfit") != "suit":
			suits = false
	d.check(suits, "the sisters are in their Domme suits in the club")
	var inside := []
	for c: Node in hub.find_children("*", "Checkpoint", true, false):
		var p := (c as Node3D).global_position
		if p.z < -14.0 and absf(p.x) < 21.0:
			inside.append(p)
	d.check(inside.is_empty(), "no checkpoint flags inside the club (%s)" % str(inside))


func _alive() -> void:
	await d.frames(5)
	d.check(_clients(&"to_session").size() + _clients(&"session").size() >= 1 and _clients(&"waiting").size() >= 1
		and _clients(&"to_aftercare").size() + _clients(&"aftercare").size() >= 1,
		"the vaults are busy from the start: a session, a client waiting, one in aftercare (%d clients)" % _clients().size())
	await d.secs(3.0)
	var adrift := _clients().filter(func(c: Node) -> bool:
		return c.get(&"phase") in [&"session", &"waiting", &"aftercare"] and absf((c as Node3D).global_position.y + 5.0) > 0.05)
	d.check(adrift.is_empty(), "the clients set down at the start stay on the vaults' floor (Deck review 3: they walked off through the ceiling) (%s)" % [
		adrift.map(func(c: Node) -> Vector3: return (c as Node3D).global_position)])
	var first := _clients().size()
	var came := await d.until(func() -> bool: return _clients().size() > first, 30.0)
	d.check(came, "a new client comes in at the door")
	var newest: Node = _clients()[-1]
	var down := await d.until(func() -> bool:
		return not is_instance_valid(newest) or newest.get(&"phase") in [&"waiting", &"to_session", &"session"], 60.0)
	d.check(down and is_instance_valid(newest) and (newest as Node3D).global_position.y < -4.5,
		"they change at the screen and go down to the vaults' hall (%s)" % (newest.get(&"phase") if is_instance_valid(newest) else "gone"))


## Into the suit, beside a waiting client, Y: the check-in, then Begin.
func _start_session() -> Node:
	await _dress(false)
	var found := [null]   # (a lambda captures locals by value)
	await d.until(func() -> bool:
		var w := _clients(&"waiting")
		if not w.is_empty():
			found[0] = w[0]
		return found[0] != null, 60.0)
	var c: Node3D = found[0]
	if c == null:
		return null
	c.set(&"t", 999.0)   # stay put for Nim
	var f := -(c.global_basis.z)
	await d.place(c.global_position + f * 1.2, atan2(-(c.global_position.x - (c.global_position + f * 1.2).x), -(c.global_position.z - (c.global_position + f * 1.2).z)))
	await d.frames(3)
	await d.tap(JOY_BUTTON_Y)
	await d.talk_through(30.0)
	await d.until(func() -> bool: return life.get(&"_game") != null, 3.0)
	return c


func _session_good() -> void:
	var c := await _start_session()
	var g: Node = life.get(&"_game")
	d.check(g != null and g.get(&"role") == "dom",
		"a waiting client: the check-in, then the cross, Nim leading (client %s, at %s, %s)" % [
		c, d.at(), (c as Node3D).global_position if c else Vector3.ZERO])
	if g == null or g.get(&"role") == null:
		return
	# Read them: the touch tools, steered onto their sweet spot; check in on yellow; enough while it's good.
	var r := await _drive_cross(g, func() -> String:
		if g.get(&"yellow") or float(g.get(&"strain")) >= 0.5:
			return "check"
		if int(g.get(&"rounds")) >= 4 and float(g.get(&"trust")) >= 0.6:
			return "enough"
		return "feather", false)
	d.check(r.get("ok", false) and not r.get("pushed", true), "read and listened to: a good scene on the cross (%s)" % str(r))
	await _pick_up(&"hub_08")


## An impact tool they can't follow, round after round, until their word (or the bell): B stops it, and that's good.
func _session_stopped() -> void:
	await d.secs(1.0)
	await _start_session()
	var g: Node = life.get(&"_game")
	if g == null or g.get(&"role") == null:
		d.check(false, "a second session")
		return
	var r := await _drive_cross(g, func() -> String:
		return "check" if g.get(&"yellow") else _impact_in(g), false)
	d.check(r.get("ok", false) and r.get("stopped", false) and not r.get("pushed", true),
		"their word, and B the moment it came: stopped, and that's a good ending (%s)" % str(r))


## The same, but through yellow and on through their word: it ends badly.
func _session_pushed() -> void:
	await d.secs(1.0)
	await _start_session()
	var g: Node = life.get(&"_game")
	if g == null or g.get(&"role") == null:
		d.check(false, "a third session")
		return
	var r := await _drive_cross(g, func() -> String: return _impact_in(g), true)
	d.check(not r.get("ok", true) and r.get("pushed", false), "kept going through their word: it ends badly (%s)" % str(r))


## The first impact tool on their tray (Pip's has none: ice, then).
func _impact_in(g: Node) -> String:
	var limits: Array = (g.get(&"profile") as Dictionary).get("limits", [])
	for t: String in ["flogger", "crop", "paddle"]:
		if not t in limits:
			return t
	return "ice"


## Plays a scene on the cross with real input, `want` naming the tray item to pick each time; at their word, B (or,
## if `push_on`, A: carrying on). Returns the finished result.
func _drive_cross(g: Node, want: Callable, push_on: bool) -> Dictionary:
	var result := [{}]
	g.finished.connect(func(r: Dictionary) -> void: result[0] = r)
	var wait := [0]
	await d.until(func() -> bool:
		if not result[0].is_empty() or not is_instance_valid(g):
			return true
		wait[0] -= 1
		var stage: String = g.get(&"stage")
		if stage == "intro" and wait[0] <= 0:
			d.stick(0.0, 0.0)
			d.tap(JOY_BUTTON_A)
			wait[0] = 10
			return false
		if stage == "touch":
			d.stick(clampf((float(g.get(&"_spot")) - float(g.get(&"_hand"))) * 5.0, -1.0, 1.0), 0.0)
			return false
		d.stick(0.0, 0.0)
		if wait[0] > 0:
			return false
		if stage == "red":
			d.tap(JOY_BUTTON_A if push_on else JOY_BUTTON_B)
			wait[0] = 30
		elif stage == "form":
			d.tap(JOY_BUTTON_A)   # agree to the form as it's filled in
			wait[0] = 10
		elif stage == "tray":
			var items: Array = g.get(&"tray_items")
			var at: String = items[int(g.get(&"tray_at"))]
			var pick: String = want.call()
			d.tap(JOY_BUTTON_A if at == pick else JOY_BUTTON_DPAD_RIGHT)
			wait[0] = 8
		return false, 200.0)
	d.stick(0.0, 0.0)
	# A regular's story goes on in a short conversation after a good session.
	await d.secs(0.3)
	await d.talk_through(20.0)
	return result[0]


func _silke_switch() -> void:
	d.nim.suit.set_outfit(NimSuit.Outfit.GARB)
	var silke := hub.get_node("Silke") as Node3D
	await d.place(silke.global_position + (-(silke.global_basis.z)) * 1.3, 0.0)
	await d.frames(3)
	await d.tap(JOY_BUTTON_Y)
	var opened: bool = dialogue.call(&"is_active")
	await d.talk_through(30.0)   # Ask her for a scene, You lead
	# Deck review 5: in her garb, Silke sends her to change; in the two-piece and back beside her, it begins.
	await d.secs(0.5)
	var waits: bool = life.get(&"_game") == null and not (life.get(&"_pending") as Dictionary).is_empty()
	var screen := hub.get_node("ChangingScreen") as Node3D
	await d.place(screen.global_position + Vector3(1.2, 0.05, 0), PI / 2.0)
	await d.frames(3)
	await d.tap(JOY_BUTTON_Y)   # the screen's three
	await d.frames(5)
	await d.tap(JOY_BUTTON_DPAD_DOWN)
	await d.frames(3)
	await d.tap(JOY_BUTTON_DPAD_DOWN)
	await d.frames(3)
	await d.tap(JOY_BUTTON_A)   # the two-piece
	await d.secs(0.5)
	var dressed: bool = d.nim.suit.in_two_piece()
	var muzzle_off := true
	for m: Node3D in d.nim.model.get(&"_masks"):
		if is_instance_valid(m) and m.is_visible_in_tree():
			muzzle_off = false
	d.check(waits and dressed and muzzle_off,
		"asked in her garb, Silke waits; the changing screen puts her in the two-piece, muzzle off (waits %s, two-piece %s, muzzle off %s)" % [
		waits, dressed, muzzle_off])
	await d.place(silke.global_position + (-(silke.global_basis.z)) * 1.3, 0.0)
	await d.until(func() -> bool: return life.get(&"_game") != null, 4.0)
	var g: Node = life.get(&"_game")
	d.check(g != null and g.get(&"mode") == &"switch", "Silke: a scene, she leads (the check-in first) (talked %s, Nim %s, Silke %s, flag %s)" % [
		opened, d.at(), silke.global_position, game.call(&"get_flag", "club/scene/silke_switch")])
	if g == null:
		return
	var r := await _drive_rich(g, {"mouth": "tape", "tie": "chest"})
	d.check(r.ok and not r.stopped and float(r.get("feel", 0)) >= 0.35 and r.gag == "tape" and int(game.call(&"get_flag", "bond/silke", 0)) >= 1,
		"Silke leads, the rich scene: tape on Nim, offered, breathed, the line, released; aftercare; Headspace %.2f, bond %s (%s)" % [
		float(r.get("feel", 0)), game.call(&"get_flag", "bond/silke", 0), str(r)])
	await _pick_up(&"hub_09")


## A rich scene (core/rich_scene.gd) played with real input, following its hint(): `want` is set into its form before
## A agrees. Returns its result, plus "gag" and the phases seen.
func _drive_rich(g: Node, want: Dictionary, bend := Callable()) -> Dictionary:
	var result := [{}]
	g.finished.connect(func(r: Dictionary) -> void: result[0] = r)
	var buttons := {&"jump": JOY_BUTTON_A, &"interact": JOY_BUTTON_Y, &"crouch": JOY_BUTTON_B, &"word_up": JOY_BUTTON_DPAD_UP,
		&"word_down": JOY_BUTTON_DPAD_DOWN, &"word_right": JOY_BUTTON_DPAD_RIGHT, &"word_left": JOY_BUTTON_DPAD_LEFT}
	var seen := {}
	var gag := [""]
	var wait := [0]
	await d.until(func() -> bool:
		if not result[0].is_empty() or not is_instance_valid(g):
			return true
		var stage: String = g.get(&"stage")
		if dialogue.call(&"is_active"):
			wait[0] -= 1
			if wait[0] <= 0:
				d.tap(JOY_BUTTON_A)   # her lines after
				wait[0] = 25
			return false
		if g.get(&"_done") and stage != "care":
			d.release_all()
			return false
		seen[g.get(&"phase")] = true
		if stage == "form":
			for k: String in want:
				(g.get(&"picks") as Dictionary)[k] = want[k]
		if g.get(&"_gag") != "":
			gag[0] = g.get(&"_gag")
		var h: Dictionary = g.call(&"hint")
		if bend.is_valid():
			h = bend.call(g, h)
		if OS.get_environment("PROBE_TRACE") != "" and Engine.get_physics_frames() % 60 == 0:
			print("  rich: stage %s phase %s feel %.2f hint %s" % [stage, g.get(&"phase"), float(g.get(&"feel")), str(h)])
		if h.has("stick2"):
			d.stick((h.stick2 as Vector2).x, (h.stick2 as Vector2).y)
		elif h.has("stick"):
			d.stick(float(h.stick), 0.0)
		elif stage != "intro":
			d.stick(0.0, 0.0)
		if h.has("hold"):
			d.button(buttons[h.hold], h.on)
		wait[0] -= 1
		if h.has("tap") and wait[0] <= 0:
			d.tap(buttons[h.tap])
			wait[0] = 6
		return false, 220.0)
	d.release_all()
	await d.talk_through(30.0)   # her lines after
	var r: Dictionary = result[0].duplicate()
	r["gag"] = gag[0]
	r["seen"] = seen.keys()
	return r


func _augusta_domme() -> void:
	var augusta := hub.get_node("Augusta") as Node3D
	await d.place(augusta.global_position + (-(augusta.global_basis.z)) * 1.3, 0.0)
	await _dress(false)
	game.call(&"set_flag", "club/scene/augusta_domme")
	await d.until(func() -> bool: return life.get(&"_game") != null, 4.0)
	var g: Node = life.get(&"_game")
	d.check(g != null and g.get(&"mode") == &"domme" and g.get(&"sister") == "augusta", "Augusta: a scene, Nim leads")
	if g == null:
		return
	var worn := [""]
	create_timer(12.0).timeout.connect(func() -> void: worn[0] = augusta.get(&"outfit"))
	var r := await _drive_rich(g, {"mouth": "ball"})
	d.check(r.ok and r.gag == "ball" and "inspect" in r.seen and "sit" in r.seen,
		"Nim leads Augusta: a ball gag, the inspection (nothing captioned), asked her, praised her breathing; Connection %.2f (%s)" % [
		float(r.get("feel", 0)), str(r)])
	d.check(worn[0] == "swim" and augusta.get(&"outfit") == "suit", "Augusta's the sub: her swimwear for it, her suit after (%s, %s)" % [
		worn[0], augusta.get(&"outfit")])


## Augusta leads: positions as she calls them, holding while she circles, her colour, the book.
func _augusta_switch() -> void:
	await d.secs(0.5)
	await _dress(true)
	game.call(&"set_flag", "club/scene/augusta_switch")
	await d.until(func() -> bool: return life.get(&"_game") != null, 4.0)
	var g: Node = life.get(&"_game")
	d.check(g != null and g.get(&"mode") == &"switch" and g.get(&"sister") == "augusta", "Augusta: a scene, she leads")
	if g == null:
		return
	var r := await _drive_rich(g, {"book": "yes"})
	d.check(r.ok and "positions" in r.seen and "hold" in r.seen and "book" in r.seen and absf(d.nim.global_position.y + 5.0) < 0.1,
		"Augusta leads: positions, holding while she circles, the book; Headspace %.2f; Nim back on her feet (%s)" % [
		float(r.get("feel", 0)), str(r)])
	# And Silke, with Nim leading: the tie, her hands, asking, letting her sit in it.
	await d.secs(0.5)
	var silke := hub.get_node("Silke") as Node3D
	await d.place(silke.global_position + (-(silke.global_basis.z)) * 1.3, 0.0)
	await _dress(false)
	game.call(&"set_flag", "club/scene/silke_domme")
	await d.until(func() -> bool: return life.get(&"_game") != null, 4.0)
	g = life.get(&"_game")
	if g == null:
		d.check(false, "Silke: a scene, Nim leads")
		return
	r = await _drive_rich(g, {"tie": "full"})
	d.check(r.ok and "tie" in r.seen and "hands" in r.seen and "sit" in r.seen,
		"Nim leads Silke: the full tie, her hands checked, asked, praised; Connection %.2f (%s)" % [float(r.get("feel", 0)), str(r)])


## Nim on the cross, Silke leading: agree to the form, take what comes, green when she asks. Aftercare after, and
## Silke walks back to her room.
func _silke_cross_sub() -> void:
	await d.secs(1.0)
	await _dress(true)
	game.call(&"set_flag", "club/cross/silke_sub")
	await d.until(func() -> bool: return life.get(&"_game") != null, 4.0)
	var g: Node = life.get(&"_game")
	d.check(g != null and g.get(&"role") == "sub" and g.get(&"who") == "silke",
		"Silke: the cross, Nim on it, Silke leading")
	if g == null or g.get(&"role") == null:
		return
	# In her two-piece Nim can be gagged on the cross (2026-11-13): tape, here, and the bell in her hand.
	var limits: Array = (g.get(&"profile") as Dictionary).get("limits", [])
	d.check(not "tape" in limits and not "ball" in limits, "Nim's form on the cross can take a gag, tape included (limits %s)" % str(limits))
	var result := [{}]
	g.finished.connect(func(r: Dictionary) -> void: result[0] = r)
	var asked := [false]
	var belled := [false]
	await d.until(func() -> bool:
		if not result[0].is_empty() or not is_instance_valid(g):
			return true
		if _past_intro(g):
			return false
		var stage: String = g.get(&"stage")
		if stage != "form" and is_instance_valid(g.get(&"_bell")):
			belled[0] = true
		if stage == "form":
			(g.get(&"picks") as Dictionary)["mouth"] = "tape"
			d.tap(JOY_BUTTON_A)
		elif stage == "colour":
			asked[0] = true
			d.tap(JOY_BUTTON_DPAD_UP)
		elif stage == "brace":
			var t: float = (g.get(&"hud").get(&"data") as Dictionary).get("t", 0.0)   # (untyped: SceneHud names autoloads)
			if t > 0.97 and t < 1.03:
				d.tap(JOY_BUTTON_A)
		return false, 120.0)
	var r: Dictionary = result[0]
	d.check(r.get("ok", false) and not r.get("stopped", true) and asked[0] and int(r.get("rounds", 0)) >= 5 and belled[0],
		"taped, the bell in her hand: held still and braced, a nod when she asked, aftercare (%s)" % str(r))
	var silke := hub.get_node("Silke") as Node3D
	var hub_script: GDScript = load("res://levels/hub/hub.gd")   # (named, it drags the autoloads into a probe's compile)
	var home: Vector3 = hub_script.sister_spot(hub_script.ROOMS[1])
	var walls := await _walk_watched(silke, home)
	d.check(walls == "", "Silke walks back to her room afterwards, through the doorways (%s)" % walls)


## Watches someone walk to `home`: "" if they got there without going through a wall (the hall's walls at x ±4 have a
## doorway at each room's z), else what went wrong.
func _walk_watched(body: Node3D, home: Vector3) -> String:
	var hub_script: GDScript = load("res://levels/hub/hub.gd")
	var bad := [""]
	var prev := [body.global_position]
	var back := await d.until(func() -> bool:
		var p := body.global_position
		if (absf(prev[0].x) < 4.0) != (absf(p.x) < 4.0) and p.y < -4.0:
			var door := false
			for r: Dictionary in hub_script.ROOMS:
				if absf(p.z - float(r.at.z)) < 1.1:
					door = true
			if not door and bad[0] == "":
				bad[0] = "through the hall's wall at %s" % p
		prev[0] = p
		return p.distance_to(home) < 0.3, 75.0)
	if not back:
		return "never got home (at %s)" % body.global_position
	return bad[0]


## Nim leads, Augusta on the cross: into her swimwear for it, her suit after, and home through the doorways.
func _augusta_cross_dom() -> void:
	await d.secs(1.0)
	var augusta := hub.get_node("Augusta") as Node3D
	await _dress(false)
	game.call(&"set_flag", "club/cross/augusta_dom")
	await d.until(func() -> bool: return life.get(&"_game") != null, 4.0)
	var g: Node = life.get(&"_game")
	if g == null:
		d.check(false, "Augusta: the cross, Nim leading")
		return
	var worn := [""]
	g.finished.connect(func(_r: Dictionary) -> void: pass)
	var r := await _drive_cross(g, func() -> String:
		if g.get(&"stage") == "tray":
			worn[0] = augusta.get(&"outfit")
		return "enough" if int(g.get(&"rounds")) >= 2 else "feather", false)
	# Deck review 4: she sits on in the nook a while (seated, lowered onto the chaise, not to be talked to), still in
	# her swimwear; then up, into her suit, and home.
	var sat: bool = augusta.global_position.y < -5.2 and not augusta.is_in_group(&"talker") and augusta.get(&"outfit") == "swim"
	d.check(worn[0] == "swim" and sat, "Augusta on the cross in her swimwear, and after it she sits on in the nook a while (y %.2f, %s; %s)" % [
		augusta.global_position.y, augusta.get(&"outfit"), str(r)])
	var hub_script: GDScript = load("res://levels/hub/hub.gd")
	var walls := await _walk_watched(augusta, hub_script.sister_spot(hub_script.ROOMS[0]))
	d.check(walls == "" and augusta.get(&"outfit") == "suit" and augusta.is_in_group(&"talker"),
		"then she changes back into her suit and walks to the Parlour through the doorways (%s, %s)" % [walls, augusta.get(&"outfit")])


## The Quiet Room: everyone in aftercare on a seat of their own.
func _aftercare_seats() -> void:
	# Everyone in a session finishes it now, so the seats fill.
	for c: Node in _clients(&"session"):
		c.set(&"t", 0.1)
	var full := await d.until(func() -> bool:
		for c: Node in _clients(&"session"):
			c.set(&"t", minf(float(c.get(&"t")), 0.1))
		return _clients(&"aftercare").size() >= 2, 150.0)
	var at: Array = _clients(&"aftercare").map(func(c: Node) -> Vector3: return (c as Node3D).global_position)
	var apart := true
	for i in at.size():
		for j in range(i + 1, at.size()):
			if (at[i] as Vector3).distance_to(at[j]) < 1.0:
				apart = false
	d.check(full and apart, "clients in aftercare each have their own seat in the Quiet Room (%s)" % str(at))


## Nim on the cross with Grizelda: Nim holds B for her word, and it stops at once, kindly.
func _grizelda_word() -> void:
	await d.secs(1.0)
	await _dress(true)
	game.call(&"set_flag", "club/cross/grizelda_sub")
	await d.until(func() -> bool: return life.get(&"_game") != null, 4.0)
	var g: Node = life.get(&"_game")
	if g == null or g.get(&"role") == null:
		d.check(false, "Grizelda: the cross, Nim on it")
		return
	var result := [{}]
	g.finished.connect(func(r: Dictionary) -> void: result[0] = r)
	await d.until(func() -> bool:
		if not result[0].is_empty() or not is_instance_valid(g):
			return true
		if _past_intro(g):
			return false
		if g.get(&"stage") == "form":
			d.tap(JOY_BUTTON_A)
		elif int(g.get(&"rounds")) >= 1:
			d.button(JOY_BUTTON_B, true)   # her word
		return false, 90.0)
	d.button(JOY_BUTTON_B, false)
	var r: Dictionary = result[0]
	d.check(r.get("ok", false) and r.get("stopped", false), "held B for her word: stopped at once, aftercare, and that counts (%s)" % str(r))


## Grizelda's, Lull's, Dash's and Rivet's rich scenes (core/rich_scenes_later.gd), both ways round, each played with
## real input by its hint() to a good end, through every phase; Nim's back on the floor after, and the sister home.
func _later_scenes() -> void:
	# [what's set on the form, the phases it must go through]
	var scenes := {
		"grizelda_switch": [{"mouth": "bit"}, ["polish", "lace", "present"]],
		"grizelda_domme": [{}, ["orders", "answer", "check", "sit"]],
		"lull_switch": [{}, ["senses", "count", "warmth"]],
		"lull_domme": [{"mouth": "tape"}, ["where", "ice", "check", "sit"]],
		"dash_switch": [{}, ["drill", "wrestle"]],
		"dash_domme": [{"word": "Pineapple"}, ["hold_her", "tickle", "check", "sit"]],
		"rivet_switch": [{"set": "full"}, ["fitting", "test", "adjust"]],
		"rivet_domme": [{"set": "full"}, ["buckles", "signal", "check", "sit"]],
	}
	var hub_script: GDScript = load("res://levels/hub/hub.gd")
	for what: String in scenes:
		await d.secs(0.5)
		var sister := what.get_slice("_", 0)
		await _dress(what.ends_with("switch"))
		game.call(&"set_flag", "club/scene/%s" % what)
		await d.until(func() -> bool: return life.get(&"_game") != null, 4.0)
		var g: Node = life.get(&"_game")
		if g == null:
			d.check(false, "%s: the scene starts" % what)
			continue
		var r := await _drive_rich(g, scenes[what][0])
		var missing: Array = (scenes[what][1] as Array).filter(func(p: String) -> bool: return not p in r.get("seen", []))
		d.check(missing.is_empty() and float(r.get("feel", 0.0)) >= 0.35,
			"%s: every phase played (missing %s), feel %.2f" % [what, str(missing), float(r.get("feel", 0.0))])
		var home: Vector3 = Vector3.ZERO
		for room: Dictionary in hub_script.ROOMS:
			if String(room.sister).to_lower() == sister:
				home = hub_script.sister_spot(room)
		var s := hub.get_node(sister.capitalize()) as Node3D
		var back := await d.until(func() -> bool: return s.global_position.distance_to(home) < 0.3, 30.0)
		d.check(r.get("ok", false) and not r.get("stopped", true) and absf(d.nim.global_position.y + 5.0) < 0.1 and back
			and s.get(&"outfit") == "suit",
			"%s: played to a good end, Nim on the floor after, %s home in her suit (%s, Nim y %.2f, %s at %s)" % [
			what, sister, str(r), d.nim.global_position.y, s.get(&"outfit"), s.global_position])


## The roads the good play doesn't take: Grizelda's "Again." when the shine wasn't good enough (a second polish and
## presenting), and tickling on past Dash's word (the biggest drop in Connection, and it still ends).
func _later_edges() -> void:
	await d.secs(0.5)
	await _dress(true)
	game.call(&"set_flag", "club/scene/grizelda_switch")
	await d.until(func() -> bool: return life.get(&"_game") != null, 4.0)
	var g: Node = life.get(&"_game")
	if g == null:
		d.check(false, "Grizelda: the scene starts again")
		return
	var again := [false]
	var r := await _drive_rich(g, {}, func(s: Node, h: Dictionary) -> Dictionary:
		if s.get(&"phase") == "present" and not s.get(&"_again"):
			s.set(&"_polish_q", 0.3)   # a streaky shine
		if s.get(&"_again"):
			again[0] = true
		return h)
	d.check(again[0] and r.get("ok", false), "Grizelda: a streaky shine gets \"Again.\", another polish and presenting, and it still ends well (%s)" % str(r))
	await d.secs(0.5)
	await _dress(false)
	game.call(&"set_flag", "club/scene/dash_domme")
	await d.until(func() -> bool: return life.get(&"_game") != null, 4.0)
	g = life.get(&"_game")
	if g == null:
		d.check(false, "Dash: the scene starts again")
		return
	var drop := [0.0]
	var before := [0.0]
	var ignored := [false]
	r = await _drive_rich(g, {"word": "Uncle"}, func(s: Node, h: Dictionary) -> Dictionary:
		if s.get(&"phase") == "tickle" and s.get(&"_mercy") and not ignored[0] and float(s.get(&"_mercy_t")) > 0.2:
			ignored[0] = true
			before[0] = float(s.get(&"feel"))
			return {"tap": &"jump"}   # on past her word
		if ignored[0] and drop[0] == 0.0 and s.get(&"phase") == "tickle":
			drop[0] = before[0] - float(s.get(&"feel"))
		return h)
	d.check(ignored[0] and drop[0] >= 0.1 and r.has("feel"),
		"Dash: tickling on past \"Uncle\" costs Connection (%.2f) and she says why (%s)" % [drop[0], str(r)])


## Mr Smith's story: a good session moves it on a step (and the next check-in changes); the fourth hands Nim the Coalition's
## committee roll.
func _smith_story() -> void:
	await d.secs(1.0)
	for step: int in [0, 3]:
		game.call(&"set_flag", "regular/smith", step)
		await _dress(false)
		var found := [null]
		await d.until(func() -> bool:
			for c: Node in _clients(&"waiting"):
				found[0] = c
				return true
			return false, 60.0)
		var c: Node3D = found[0]
		if c == null:
			d.check(false, "a client to be Mr Smith")
			return
		c.set(&"regular", &"smith")
		c.set(&"talk_as", "smith")
		c.set(&"t", 999.0)
		await d.frames(2)
		var ask := c.get_node_or_null("Ask")
		d.check(ask != null and String(ask.get(&"label")) == "smith_%d_suit" % step,
			"Mr Smith's check-in follows his story (step %d: %s)" % [step, ask.get(&"label") if ask else "none"])
		await d.place(c.global_position + (-(c.global_basis.z)) * 1.2, 0.0)
		await d.frames(3)
		await d.tap(JOY_BUTTON_Y)
		await d.talk_through(30.0)
		await d.until(func() -> bool: return life.get(&"_game") != null, 4.0)
		var g: Node = life.get(&"_game")
		if g == null:
			d.check(false, "Mr Smith's session starts")
			return
		var r := await _drive_cross(g, func() -> String:
			if g.get(&"yellow") or float(g.get(&"strain")) >= 0.5:
				return "check"
			if int(g.get(&"rounds")) >= 4 and float(g.get(&"trust")) >= 0.6:
				return "enough"
			return "feather", false)
		await d.talk_through(30.0)
		await d.secs(0.5)
		d.check(r.get("ok", false) and int(game.call(&"get_flag", "regular/smith", 0)) == step + 1,
			"a good session with Mr Smith moves his story on (%d to %s; %s)" % [step, game.call(&"get_flag", "regular/smith", 0), str(r)])
	d.check(game.call(&"has_flag", "intel/coalition_roll"), "his last visit: the Coalition's committee roll (intel/coalition_roll)")


## A tossed rose: let it land, step onto it.
func _pick_up(id: StringName) -> void:
	await d.secs(1.5)
	var rose := hub.get_node_or_null("Key_%s" % id) as Node3D
	if rose:
		await d.place(rose.global_position + Vector3(0, 0.05, 0), 0.0)
	var got := await d.until(func() -> bool: return game.call(&"has_collected", &"key", &"hub", id), 2.0)
	d.check(got, "the hub's rose for it (%s), tossed down and picked up" % id)
