extends SceneTree
## Windowed shots of the club's scenes (WO-014b; owner, Deck review 3), each played with real input: the sisters'
## scenes in their rooms (the breathing ring, the colour question, the posture gauge, the knots going on Silke,
## Augusta's faults on her body), the cross from both sides (the form, the tray, the touch with its glow, the impact
## wound up and landing, holding still), aftercare in the Quiet Room's nook, and the Quiet Room with its seats.
##   godot --path . -s tools/club_shots.gd -- <dir>          (it needs a GPU; default dir .wip/club/shots)

const Driver := preload("res://tools/probe_driver.gd")

var out := "res://.wip/club/shots"
var d: Driver
var game: Node
var hub: Node
var life: Node


func _initialize() -> void:
	if OS.get_cmdline_user_args().size() > 0:
		out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	DisplayServer.window_set_size(Vector2i(1280, 800))
	await process_frame
	game = root.get_node("/root/Game")
	game.set(&"persist", false)
	game.call(&"set_setting", "age_confirmed", true)
	game.call(&"reset")
	game.call(&"set_flag", "hub/prologue_done")
	game.call(&"set_flag", "done/pier")
	hub = load("res://levels/hub/hub.tscn").instantiate()
	root.add_child(hub)
	current_scene = hub
	await physics_frame
	await physics_frame
	d = Driver.new(self, hub.get(&"nim"), hub.get(&"cam"))
	life = hub.get_node("ClubLife")
	await d.place(Vector3(0, -5.0, -52.0), PI)
	await d.secs(1.0)
	# SHOTS_ONLY=<text>: only the later scenes whose name has it in (a quick re-shoot).
	var only := OS.get_environment("SHOTS_ONLY")
	if only == "cuddle":
		await _cuddles()
		print("club shots: done, in ", out)
		quit()
		return
	if only == "":
		await _rooms()
		await _silke_switch()
		await _augusta_switch()
		await _silke_domme()
		await _augusta_domme()
	# The later four (core/rich_scenes_later.gd): a shot in each phase, named <sister>_<way>_<phase>.
	var later := {
		"grizelda_switch": [{"mouth": "bit"}, ["polish", "lace", "present", "care"]],
		"grizelda_domme": [{"mouth": "ball"}, ["orders", "answer", "sit"]],
		"lull_switch": [{}, ["senses", "count", "warmth"]],
		"lull_domme": [{"mouth": "tape"}, ["where", "ice"]],
		"dash_switch": [{}, ["drill", "wrestle"]],
		"dash_domme": [{}, ["hold_her", "tickle"]],
		"rivet_switch": [{"set": "full", "mouth": "tape"}, ["fitting", "test", "adjust"]],
		"rivet_domme": [{"set": "full"}, ["buckles", "signal"]],
	}
	for what: String in later:
		if only != "" and not only in what:
			continue
		var shots := {}
		for p: String in later[what][1]:
			shots[p] = "%s_%s" % [what, p]
		await _rich("club/scene/%s" % what, what.ends_with("switch"), later[what][0], shots)
	if only == "":
		await _cross_client()
		await _cross_augusta()
		await _cross_sub()
		await _quiet()
	print("club shots: done, in ", out)
	quit()


func _shot(name: String) -> void:
	await d.frames(3)
	var path := "%s/%s.png" % [out, name]
	root.get_texture().get_image().save_png(path)
	var where := []
	for c: Node in root.get_tree().get_nodes_in_group(&"club_client"):
		where.append("%s %s" % [c.get(&"phase"), (c as Node3D).global_position.snapped(Vector3.ONE * 0.1)])
	print("shot ", path, "   clients: ", ", ".join(where))


## A look from a fixed camera, then back to the player's.
func _look(name: String, from: Vector3, at: Vector3) -> void:
	var was := root.get_viewport().get_camera_3d()
	var cam := Camera3D.new()
	cam.fov = 60.0
	hub.add_child(cam)
	cam.global_position = from
	cam.look_at(at, Vector3.UP)
	cam.make_current()
	await _shot(name)
	cam.queue_free()
	if was:
		was.make_current()


func _rooms() -> void:
	await _look("room_rope", Vector3(-5.0, -3.4, -56.0), Vector3(-9.5, -4.2, -59.0))
	await _look("room_parlour", Vector3(-5.0, -3.4, -49.2), Vector3(-10.0, -4.4, -52.6))


## At `stage` yet; a "how it goes" card on the way is shot once and passed with A.
func _at(g: Node, stage: String) -> bool:
	if g.get(&"stage") == "intro":
		if not _intro_shot:
			_intro_shot = true
			_shot("intro_card")
		d.tap(JOY_BUTTON_A)
		return false
	return g.get(&"stage") == stage


var _intro_shot := false


## Into the right thing for a scene: the two-piece to be the sub, the suit to lead.
func _dress(sub: bool) -> void:
	d.nim.model.call(&"wear_swim", sub)
	if not sub:
		d.nim.suit.set_outfit(1)
	await d.frames(2)


func _start(flag: String) -> Node:
	await _dress(flag.ends_with("switch") or flag.ends_with("_sub"))
	game.call(&"set_flag", flag)
	await d.until(func() -> bool: return life.get(&"_game") != null, 6.0)
	var g: Node = life.get(&"_game")
	await d.until(func() -> bool: return g.get(&"stage") == "intro", 6.0)
	await d.secs(0.4)
	if not _intro_shot:
		_intro_shot = true
		await _shot("intro_card")
	await d.tap(JOY_BUTTON_A)
	await d.until(func() -> bool: return g.get(&"stage") not in ["", "setup", "intro"], 6.0)
	if float(g.get(&"_practice_t")) > 0.0:
		await d.secs(0.5)
		g.call(&"_start_for_real")
	return g


func _close(g: Node) -> void:
	d.release_all()
	if is_instance_valid(g) and g.has_method(&"_end"):
		g.call(&"_end", {"ok": false})
	await d.until(func() -> bool: return life.get(&"_game") == null or bool(root.get_node("/root/Dialogue").call(&"is_active")), 8.0)
	await d.talk_through(20.0)
	await d.until(func() -> bool: return life.get(&"_game") == null, 10.0)
	await d.secs(0.5)


func _silke_switch() -> void:
	await _rich("club/scene/silke_switch", true, {"mouth": "tape", "tie": "full"},
		{"form": "silke_switch_form", "offer": "silke_switch_offer", "breathe": "silke_switch", "line": "silke_switch_line",
			"release": "silke_switch_release", "care": "silke_switch_care"})


func _augusta_switch() -> void:
	await _rich("club/scene/augusta_switch", true, {"mouth": "ball", "book": "yes"},
		{"positions": "augusta_switch", "hold": "augusta_switch_hold", "book": "augusta_switch_book"})


func _silke_domme() -> void:
	await _rich("club/scene/silke_domme", false, {"tie": "full"},
		{"tie": "silke_domme", "hands": "silke_domme_hands", "sit": "silke_domme_sit", "care": "silke_domme_care"})


func _augusta_domme() -> void:
	await _rich("club/scene/augusta_domme", false, {"mouth": "tape"},
		{"inspect": "augusta_domme", "sit": "augusta_domme_sit"})


## A rich scene (core/rich_scene.gd) played by its hint(), with a shot a few seconds into each phase named in `shots`
## (by stage: "form", "care", or a phase).
func _rich(flag: String, sub: bool, want: Dictionary, shots: Dictionary) -> void:
	await _dress(sub)
	game.call(&"set_flag", flag)
	await d.until(func() -> bool: return life.get(&"_game") != null, 6.0)
	var g: Node = life.get(&"_game")
	var buttons := {&"jump": JOY_BUTTON_A, &"interact": JOY_BUTTON_Y, &"crouch": JOY_BUTTON_B, &"word_up": JOY_BUTTON_DPAD_UP,
		&"word_down": JOY_BUTTON_DPAD_DOWN, &"word_right": JOY_BUTTON_DPAD_RIGHT, &"word_left": JOY_BUTTON_DPAD_LEFT}
	var taken := {}
	var since := {}
	var wait := 0
	var dialogue := root.get_node("/root/Dialogue")
	while life.get(&"_game") == g and is_instance_valid(g):
		await d.frames(1)
		if not is_instance_valid(g):
			break
		if dialogue.call(&"is_active"):
			wait -= 1
			if wait <= 0:
				d.tap(JOY_BUTTON_A)
				wait = 25
			continue
		var stage: String = g.get(&"stage")
		var key: String = stage if stage in ["form", "care"] else String(g.get(&"phase"))
		if stage == "form":
			for k: String in want:
				(g.get(&"picks") as Dictionary)[k] = want[k]
		since[key] = int(since.get(key, 0)) + 1
		if shots.has(key) and not taken.has(key) and stage != "intro" and since[key] > (20 if stage == "form" else 70):
			taken[key] = true
			await _shot(shots[key])
			if not is_instance_valid(g):
				break
		if g.get(&"_done") and stage != "care":
			d.release_all()
			continue
		var h: Dictionary = g.call(&"hint")
		if h.has("stick2"):
			d.stick((h.stick2 as Vector2).x, (h.stick2 as Vector2).y)
		elif h.has("stick"):
			d.stick(float(h.stick), 0.0)
		elif stage != "intro":
			d.stick(0.0, 0.0)
		if h.has("hold"):
			d.button(buttons[h.hold], h.on)
		wait -= 1
		if h.has("tap") and wait <= 0 and (stage != "form" or taken.has("form") or not shots.has("form")):
			d.tap(buttons[h.tap])
			wait = 6
	d.release_all()
	await d.secs(0.5)


## A waiting client's session: the form, the tray, the feather on its sweet spot, the flogger wound up and landing,
## aftercare.
func _cross_client() -> void:
	var found := [null]   # (a lambda captures locals by value)
	await d.until(func() -> bool:
		for n: Node in root.get_tree().get_nodes_in_group(&"club_client"):
			if n.get(&"phase") == &"waiting":
				found[0] = n
				return true
		return false, 60.0)
	var c: Node3D = found[0]
	if c == null:
		print("no waiting client")
		return
	c.set(&"t", 999.0)
	await d.place(c.global_position + Vector3(0, 0, 1.2), 0.0)
	await _dress(false)
	game.call(&"set_flag", "club/session_go")
	await d.until(func() -> bool: return life.get(&"_game") != null, 6.0)
	var g: Node = life.get(&"_game")
	await d.until(func() -> bool: return _at(g, "form"), 4.0)
	await d.secs(0.4)
	await _shot("cross_form")
	await d.tap(JOY_BUTTON_A)
	await d.until(func() -> bool: return _at(g, "tray"), 6.0)
	await d.secs(0.5)
	await _shot("cross_tray")
	await d.tap(JOY_BUTTON_A)   # the feather
	await d.until(func() -> bool: return _at(g, "touch"), 3.0)
	await d.secs(1.5)
	await _shot("cross_touch")
	await d.until(func() -> bool: return _at(g, "tray"), 8.0)
	var items: Array = g.get(&"tray_items")
	var want := items.find("flogger")
	for i in maxi(want, 0):
		await d.tap(JOY_BUTTON_DPAD_RIGHT)
		await d.frames(4)
	await d.secs(0.3)
	await _shot("cross_tray_flogger")
	await d.tap(JOY_BUTTON_A)
	await d.until(func() -> bool: return _at(g, "impact"), 3.0)
	await d.until(func() -> bool: return float((g.get(&"hud").get(&"data") as Dictionary).get("t", 0.0)) > 0.5, 3.0)
	await _shot("cross_wind")
	await d.until(func() -> bool: return float((g.get(&"hud").get(&"data") as Dictionary).get("t", 0.0)) > 1.02, 3.0)
	await _shot("cross_land")
	# Enough: on to aftercare.
	await d.until(func() -> bool: return _at(g, "tray"), 15.0)
	items = g.get(&"tray_items")
	for i in items.find("enough"):
		await d.tap(JOY_BUTTON_DPAD_RIGHT)
		await d.frames(4)
	await d.tap(JOY_BUTTON_A)
	await d.until(func() -> bool: return _at(g, "aftercare"), 6.0)
	await d.secs(2.5)
	await _shot("cross_aftercare")
	await d.until(func() -> bool: return life.get(&"_game") == null, 20.0)
	await d.secs(1.0)


## Augusta on the cross: her swimwear, her collar.
func _cross_augusta() -> void:
	await _dress(false)
	game.call(&"set_flag", "club/cross/augusta_dom")
	await d.until(func() -> bool: return life.get(&"_game") != null, 6.0)
	var g: Node = life.get(&"_game")
	await d.until(func() -> bool: return _at(g, "form"), 4.0)
	(g.get(&"picks") as Dictionary)["mouth"] = "ball"
	(g.get(&"picks") as Dictionary)["eyes"] = "blindfold"
	await d.secs(0.3)
	await _shot("cross_augusta_form")
	await d.tap(JOY_BUTTON_A)
	await d.until(func() -> bool: return _at(g, "tray"), 6.0)
	await d.secs(0.8)
	await _shot("cross_augusta")
	var items: Array = g.get(&"tray_items")
	for i in items.find("enough"):
		await d.tap(JOY_BUTTON_DPAD_RIGHT)
		await d.frames(4)
	await d.tap(JOY_BUTTON_A)
	await d.until(func() -> bool: return life.get(&"_game") == null, 25.0)
	await d.secs(1.0)


## Every sister's aftercare on the chaise, both ways round (SHOTS_ONLY=cuddle): straight to it (Enough when Nim leads,
## her word when she's on the cross), a shot a few seconds in: cuddle_<sister>_<dom|sub>.
func _cuddles() -> void:
	# SHOTS_SISTER=<name>[,<role>]: just her (a quick look).
	var just := OS.get_environment("SHOTS_SISTER").split(",")
	for sister: String in ["silke", "augusta", "grizelda", "lull", "dash", "rivet"]:
		if just[0] != "" and sister != just[0]:
			continue
		for role: String in ["dom", "sub"]:
			if just.size() > 1 and role != just[1]:
				continue
			await _dress(role == "sub")
			game.call(&"set_flag", "club/cross/%s_%s" % [sister, role])
			if not await d.until(func() -> bool: return life.get(&"_game") != null, 6.0):
				print("no cross for ", sister, " ", role)
				continue
			var g: Node = life.get(&"_game")
			await d.until(func() -> bool: return _at(g, "form"), 4.0)
			await d.tap(JOY_BUTTON_A)
			if role == "dom":
				await d.until(func() -> bool: return _at(g, "tray"), 8.0)
				var items: Array = g.get(&"tray_items")
				for i in items.find("enough"):
					await d.tap(JOY_BUTTON_DPAD_RIGHT)
					await d.frames(4)
				await d.tap(JOY_BUTTON_A)
			else:
				await d.until(func() -> bool: return _at(g, "hold") or _at(g, "brace"), 10.0)
				d.button(JOY_BUTTON_B, true)
			await d.until(func() -> bool: return _at(g, "aftercare"), 12.0)
			d.button(JOY_BUTTON_B, false)
			await d.secs(3.0)
			await _shot("cuddle_%s_%s" % [sister, role])
			await d.until(func() -> bool:
				if root.get_node("/root/Dialogue").call(&"is_active"):
					d.tap(JOY_BUTTON_A)
				return life.get(&"_game") == null, 40.0)
			await d.secs(1.0)


## Nim on the cross, Silke leading: holding still, bracing, her word.
func _cross_sub() -> void:
	await _dress(true)
	game.call(&"set_flag", "club/cross/silke_sub")
	await d.until(func() -> bool: return life.get(&"_game") != null, 6.0)
	var g: Node = life.get(&"_game")
	await d.until(func() -> bool: return _at(g, "form"), 4.0)
	await d.secs(0.3)
	await _shot("cross_sub_form")
	await d.tap(JOY_BUTTON_A)
	await d.until(func() -> bool: return _at(g, "hold"), 8.0)
	await d.secs(1.5)
	await _shot("cross_sub_hold")
	await d.until(func() -> bool: return _at(g, "brace"), 12.0)
	await d.until(func() -> bool: return float((g.get(&"hud").get(&"data") as Dictionary).get("t", 0.0)) > 0.6, 3.0)
	await _shot("cross_sub_brace")
	d.button(JOY_BUTTON_B, true)
	await d.secs(0.35)
	await _shot("cross_sub_word")
	await d.until(func() -> bool: return _at(g, "aftercare"), 8.0)
	d.button(JOY_BUTTON_B, false)
	await d.secs(2.5)
	await _shot("cross_sub_aftercare")
	await d.until(func() -> bool: return life.get(&"_game") == null, 20.0)
	await d.secs(1.0)


func _quiet() -> void:
	await d.until(func() -> bool:
		return root.get_tree().get_nodes_in_group(&"club_client").filter(func(c: Node) -> bool:
			return c.get(&"phase") == &"aftercare").size() >= 2, 90.0)
	await _look("quiet", Vector3(5.2, -3.0, -49.0), Vector3(15.0, -4.6, -52.0))
	await _look("quiet_east", Vector3(13.0, -3.2, -50.0), Vector3(19.5, -4.4, -51.5))
