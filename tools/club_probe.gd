extends SceneTree
## The Velvet Rope's house (WO-014b), with real input:
##   - the vaults are alive: clients in a session, waiting, in aftercare from the start; new ones come in at the door,
##     change, and go down to wait;
##   - Nim's own session (in the suit): the check-in, then the cross (core/cross_scene.gd): agree the form, the
##     feather steered onto their sweet spot, a check-in on yellow: a good scene, and the hub's rose (hub_08);
##   - an impact they can't follow until their word, and B at once: stopped, a good ending;
##   - the same, carrying on through their word: it ends badly;
##   - Switch with Silke (the breathing game, green at the check-in): aftercare, and the hub's rose (hub_09);
##   - Domme Augusta (the corrections, and asking her how she is);
##   - Nim on the cross with Silke leading (no gag on Nim's form; green when asked; Silke walks back to her room);
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
	hub = load(HUB).instantiate()
	root.add_child(hub)
	current_scene = hub
	await physics_frame
	await physics_frame
	d = Driver.new(self, hub.get(&"nim"), hub.get(&"cam"))
	life = hub.get_node("ClubLife")
	await _alive()
	await _session_good()
	await _session_stopped()
	await _session_pushed()
	await _silke_switch()
	await _augusta_domme()
	await _augusta_switch()
	await _silke_cross_sub()
	await _grizelda_word()
	print("club probe: %d failures" % d.fails)
	quit(1 if d.fails else 0)


func _clients(phase := &"") -> Array:
	return get_nodes_in_group(&"club_client").filter(func(c: Node) -> bool:
		return phase == &"" or c.get(&"phase") == phase)


func _alive() -> void:
	await d.frames(5)
	d.check(_clients(&"to_session").size() + _clients(&"session").size() >= 1 and _clients(&"waiting").size() >= 1
		and _clients(&"to_aftercare").size() + _clients(&"aftercare").size() >= 1,
		"the vaults are busy from the start: a session, a client waiting, one in aftercare (%d clients)" % _clients().size())
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
	d.nim.suit.set_outfit(NimSuit.Outfit.SUIT)
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
	d.check(g != null and g is CanvasLayer and g.get(&"role") == "dom",
		"a waiting client: the check-in, then the cross, Nim leading (client %s, at %s, %s)" % [
		c, d.at(), (c as Node3D).global_position if c else Vector3.ZERO])
	if g == null or not g is CanvasLayer:
		return
	# Read them: the touch tools, steered onto their sweet spot; check in on yellow; enough while it's good.
	var r := await _drive_cross(g, func() -> String:
		if g.get(&"yellow") or float(g.get(&"strain")) >= 0.5:
			return "Check in"
		if int(g.get(&"rounds")) >= 4 and float(g.get(&"trust")) >= 0.6:
			return "That's enough"
		return "Feather", false)
	d.check(r.get("ok", false) and not r.get("pushed", true), "read and listened to: a good scene on the cross (%s)" % str(r))
	await _pick_up(&"hub_08")


## An impact tool they can't follow, round after round, until their word (or the bell): B stops it, and that's good.
func _session_stopped() -> void:
	await d.secs(1.0)
	await _start_session()
	var g: Node = life.get(&"_game")
	if g == null or not g is CanvasLayer:
		d.check(false, "a second session")
		return
	var r := await _drive_cross(g, func() -> String:
		return "Check in" if g.get(&"yellow") else _impact_in(g), false)
	d.check(r.get("ok", false) and r.get("stopped", false) and not r.get("pushed", true),
		"their word, and B the moment it came: stopped, and that's a good ending (%s)" % str(r))


## The same, but through yellow and on through their word: it ends badly.
func _session_pushed() -> void:
	await d.secs(1.0)
	await _start_session()
	var g: Node = life.get(&"_game")
	if g == null or not g is CanvasLayer:
		d.check(false, "a third session")
		return
	var r := await _drive_cross(g, func() -> String: return _impact_in(g), true)
	d.check(not r.get("ok", true) and r.get("pushed", false), "kept going through their word: it ends badly (%s)" % str(r))


## The first impact tool on their tray (Pip's has none: ice, then).
func _impact_in(g: Node) -> String:
	var limits: Array = (g.get(&"profile") as Dictionary).get("limits", [])
	for t: String in ["flogger", "crop", "paddle"]:
		if not t in limits:
			return t.capitalize()
	return "Ice"


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
		var title := (g.get(&"_title") as Label).text
		var body := (g.get(&"_body") as Label).text
		if body.contains("stay with them"):
			d.stick(clampf((float(g.get(&"_spot")) - float(g.get(&"_hand"))) * 5.0, -1.0, 1.0), 0.0)
			return false
		d.stick(0.0, 0.0)
		if wait[0] > 0:
			return false
		if body.contains("STOP"):
			d.tap(JOY_BUTTON_A if push_on else JOY_BUTTON_B)
			wait[0] = 30
		elif title.begins_with("THE CROSS"):
			d.tap(JOY_BUTTON_A)   # agree to the form as it's filled in
			wait[0] = 10
		elif title.begins_with("Your tray") and body.contains("▶"):
			var at := body.substr(body.find("▶") + 2)
			var pick: String = want.call()
			d.tap(JOY_BUTTON_A if at.begins_with(pick) else JOY_BUTTON_DPAD_RIGHT)
			wait[0] = 8
		return false, 200.0)
	d.stick(0.0, 0.0)
	return result[0]


func _silke_switch() -> void:
	d.nim.suit.set_outfit(NimSuit.Outfit.GARB)
	var silke := hub.get_node("Silke") as Node3D
	await d.place(silke.global_position + (-(silke.global_basis.z)) * 1.3, 0.0)
	await d.frames(3)
	await d.tap(JOY_BUTTON_Y)
	var opened: bool = dialogue.call(&"is_active")
	await d.talk_through(30.0)   # Ask her for a scene, You lead
	await d.until(func() -> bool: return life.get(&"_game") != null, 4.0)
	var g: Node = life.get(&"_game")
	d.check(g != null and g.get(&"mode") == &"switch", "Silke: a scene, she leads (the check-in first) (talked %s, Nim %s, Silke %s, flag %s)" % [
		opened, d.at(), silke.global_position, game.call(&"get_flag", "club/scene/silke_switch")])
	if g == null:
		return
	var result := [{}]
	g.finished.connect(func(r: Dictionary) -> void: result[0] = r)
	await d.until(func() -> bool:
		if not result[0].is_empty():
			return true
		if not is_instance_valid(g) or g.get(&"_done"):
			return false
		var phase := fmod(float(g.get(&"_t")), 5.0) / 5.0
		d.button(JOY_BUTTON_A, phase < 0.5)
		if String((g.get(&"_cue") as Label).text).contains("Colour?"):
			d.tap(JOY_BUTTON_DPAD_UP)
		return false, 45.0)
	d.button(JOY_BUTTON_A, false)
	await d.talk_through(30.0)   # the aftercare
	var r: Dictionary = result[0]
	d.check(r.get("ok", false) and not r.get("stopped", true) and float(g.get(&"_score")) > 0.5 if is_instance_valid(g) else r.get("ok", false),
		"breathed with her, green at the check-in, aftercare (%s)" % str(r))
	await _pick_up(&"hub_09")


func _augusta_domme() -> void:
	var augusta := hub.get_node("Augusta") as Node3D
	await d.place(augusta.global_position + (-(augusta.global_basis.z)) * 1.3, 0.0)
	game.call(&"set_flag", "club/scene/augusta_domme")
	await d.until(func() -> bool: return life.get(&"_game") != null, 4.0)
	var g: Node = life.get(&"_game")
	d.check(g != null and g.get(&"mode") == &"domme" and g.get(&"sister") == "augusta", "Augusta: a scene, Nim leads")
	if g == null:
		return
	var result := [{}]
	g.finished.connect(func(r: Dictionary) -> void: result[0] = r)
	var buttons := {&"word_up": JOY_BUTTON_DPAD_UP, &"word_down": JOY_BUTTON_DPAD_DOWN, &"word_right": JOY_BUTTON_DPAD_RIGHT,
		&"word_left": JOY_BUTTON_DPAD_LEFT}
	await d.until(func() -> bool:
		if not result[0].is_empty():
			return true
		if not is_instance_valid(g) or g.get(&"_done"):
			return false
		if not g.get(&"_asked") and float(g.get(&"_check_t")) <= 0.0:
			d.tap(JOY_BUTTON_Y)
		var f: int = g.get(&"_fault")
		if f >= 0 and float(g.get(&"_fault_t")) < 2.0:
			d.tap(buttons[g.FAULTS[f][1]])
		return false, 60.0)
	await d.talk_through(30.0)
	var r: Dictionary = result[0]
	d.check(r.get("ok", false), "corrected her, and asked how she was (%s)" % str(r))


## Augusta leads: hold the posture (counter the drift with the stick), green when she asks.
func _augusta_switch() -> void:
	await d.secs(0.5)
	game.call(&"set_flag", "club/scene/augusta_switch")
	await d.until(func() -> bool: return life.get(&"_game") != null, 4.0)
	var g: Node = life.get(&"_game")
	d.check(g != null and g.get(&"mode") == &"switch" and g.get(&"sister") == "augusta", "Augusta: a scene, she leads")
	if g == null:
		return
	var result := [{}]
	g.finished.connect(func(r: Dictionary) -> void: result[0] = r)
	await d.until(func() -> bool:
		if not result[0].is_empty():
			return true
		if not is_instance_valid(g) or g.get(&"_done"):
			return false
		d.stick(clampf(-float(g.get(&"_balance")) * 3.0, -1.0, 1.0), 0.0)
		if String((g.get(&"_cue") as Label).text).contains("Colour?"):
			d.tap(JOY_BUTTON_DPAD_UP)
		return false, 45.0)
	d.stick(0, 0)
	var score: float = g.get(&"_score") if is_instance_valid(g) else 1.0
	await d.talk_through(30.0)
	var r: Dictionary = result[0]
	d.check(r.get("ok", false) and score > 0.5, "held her posture, centred, green at the check-in (%s, poise %.2f)" % [str(r), score])


## Nim on the cross, Silke leading: agree to the form, take what comes, green when she asks. Aftercare after, and
## Silke walks back to her room.
func _silke_cross_sub() -> void:
	await d.secs(1.0)
	game.call(&"set_flag", "club/cross/silke_sub")
	await d.until(func() -> bool: return life.get(&"_game") != null, 4.0)
	var g: Node = life.get(&"_game")
	d.check(g != null and g is CanvasLayer and g.get(&"role") == "sub" and g.get(&"who") == "silke",
		"Silke: the cross, Nim on it, Silke leading")
	if g == null or not g is CanvasLayer:
		return
	var limits: Array = (g.get(&"profile") as Dictionary).get("limits", [])
	d.check("ball" in limits and "bit" in limits, "Nim's muzzle stays: no gag on her form")
	var result := [{}]
	g.finished.connect(func(r: Dictionary) -> void: result[0] = r)
	var asked := [false]
	await d.until(func() -> bool:
		if not result[0].is_empty() or not is_instance_valid(g):
			return true
		var title := (g.get(&"_title") as Label).text
		var body := (g.get(&"_body") as Label).text
		if title.begins_with("THE CROSS"):
			d.tap(JOY_BUTTON_A)
		elif body.contains("Green"):
			asked[0] = true
			d.tap(JOY_BUTTON_DPAD_UP)
		elif body.contains("brace") and body.contains("NOW"):
			d.tap(JOY_BUTTON_A)
		return false, 120.0)
	var r: Dictionary = result[0]
	d.check(r.get("ok", false) and not r.get("stopped", true) and asked[0] and int(r.get("rounds", 0)) >= 5,
		"held still and braced, green when she asked, aftercare (%s)" % str(r))
	var silke := hub.get_node("Silke") as Node3D
	var hub_script: GDScript = load("res://levels/hub/hub.gd")   # (named, it drags the autoloads into a probe's compile)
	var home: Vector3 = hub_script.sister_spot(hub_script.ROOMS[1])
	var back := await d.until(func() -> bool: return silke.global_position.distance_to(home) < 0.3, 30.0)
	d.check(back, "Silke walks back to her room afterwards (at %s)" % silke.global_position)


## Nim on the cross with Grizelda: Nim holds B for her word, and it stops at once, kindly.
func _grizelda_word() -> void:
	await d.secs(1.0)
	game.call(&"set_flag", "club/cross/grizelda_sub")
	await d.until(func() -> bool: return life.get(&"_game") != null, 4.0)
	var g: Node = life.get(&"_game")
	if g == null or not g is CanvasLayer:
		d.check(false, "Grizelda: the cross, Nim on it")
		return
	var result := [{}]
	g.finished.connect(func(r: Dictionary) -> void: result[0] = r)
	await d.until(func() -> bool:
		if not result[0].is_empty() or not is_instance_valid(g):
			return true
		var title := (g.get(&"_title") as Label).text
		if title.begins_with("THE CROSS"):
			d.tap(JOY_BUTTON_A)
		elif int(g.get(&"rounds")) >= 1:
			d.button(JOY_BUTTON_B, true)   # her word
		return false, 90.0)
	d.button(JOY_BUTTON_B, false)
	var r: Dictionary = result[0]
	d.check(r.get("ok", false) and r.get("stopped", false), "held B for her word: stopped at once, aftercare, and that counts (%s)" % str(r))


## A tossed rose: let it land, step onto it.
func _pick_up(id: StringName) -> void:
	await d.secs(1.5)
	var rose := hub.get_node_or_null("Key_%s" % id) as Node3D
	if rose:
		await d.place(rose.global_position + Vector3(0, 0.05, 0), 0.0)
	var got := await d.until(func() -> bool: return game.call(&"has_collected", &"key", &"hub", id), 2.0)
	d.check(got, "the hub's rose for it (%s), tossed down and picked up" % id)
