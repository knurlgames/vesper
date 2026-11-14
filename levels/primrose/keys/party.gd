extends "res://levels/primrose/keys/primrose_key.gd"
## Key 9: the demonstration party (worlds/02_PRIMROSE_CLOSE.md "The set piece"; WO-015 step 3). Tonight's consultant is
## held up; Nim takes her place, in the suit, in Mrs Gander's Show Home.
##   1. **Before it starts, in the world:** two husbands are under the ladies' feet and the kit cupboard's stuck. Fetch
##      gets one of them to bring in the consultant's bag from the step; Open gets the other to open the cupboard. Each
##      takes himself off to the pub after (out of the front door, on foot).
##   2. **The party** (a scene on its own camera, on SceneHud): four rounds. Each round a toy from the kit goes on the
##      coffee table and a lady asks about it: answer (the D-pad). Honest, unflustered advice is right; a hard sell or a
##      fluster costs Composure. Then swap the hypnotic one for a dud from her bag while nobody's looking: hold A while
##      every eye in the room is elsewhere. Seen at it costs a lot. Y passes the brochure round, once a round, and every
##      eye goes to it for a moment. Too slow, and the real one goes home with somebody.
##   3. **The end:** three swaps or more and her cover intact: the ladies love the honest advice the duds came with, and
##      Nim's booked for three more parties. Mrs Gander needs some air, in her garden, alone: her back door's unlocked
##      (the boss, step 4), the Key's tossed down, "primrose/party_done". Otherwise she calls it a night, and Nim can
##      try again (talk to her).
## Composure is Nim's own (NimSuit): blown, it's over. Suggestive only: product names, boxes, the ladies' faces.
## OWNER REVIEW: every line.

const GANDER_AT := Vector3(-9.3, 0.08, -126.6)
const NIM_AT := Vector3(1.4, 0.08, -121.7)
const TABLE := Vector3(0.0, 0.55, -124.0)
const BAG_AT := Vector3(0.7, 0.08, -117.0)   # just inside the front door, where she dropped it
const CUPBOARD := Vector3(-10.5, 0.08, -132.38)
const FRONT_DOOR := Vector3(0.0, 0.08, -116.0)
## The guests: [speaker, display, seat (body origin), facing, body, tint].
const GUESTS := [
	["Ashby", "Mrs Ashby", Vector3(-4.95, 0.08, -124.0), Vector3(1, 0, 0), "hare_civilian", Color("d0b8e0")],
	["Primm", "Mrs Primm", Vector3(4.95, 0.08, -124.0), Vector3(-1, 0, 0), "otter_civilian", Color("e0c8a8")],
	["Fairweather", "Mrs Fairweather", Vector3(0.0, 0.08, -128.95), Vector3(0, 0, 1), "hedgehog_civilian", Color("b8c8d8")],
]
## The kit, a toy a round: [product, box colour, who asks, the question, [label, answer, right?, her reply]...]. The
## label is what the D-pad shows (short, so it fits); Nim says the answer in full. Right is honest and unflustered (Nim
## knows this subject better than anyone in the Close); wrong is the hard sell (the Coalition's way) or a fluster.
## OWNER REVIEW.
const ROUNDS := [
	["THE GOOD NIGHT LAMB", Color("f0e8f0"), "Ashby", "And what does it do, exactly?", [
		["Start slow; say it out loud", "Whatever you ask of it. Start slowly, and say what you like out loud. It helps.", true,
			"Out loud. Goodness. ...Out loud."],
		["Swyne guarantees it!", "It changes lives! Councillor Swyne guarantees it!", false, "Does he. Personally?"],
		["It... hums?", "Oh, gosh. It... hums?", false, "We can hear that, dear."]]],
	["THE MORAL FIBRE", Color("c8a070"), "Primm", "Isn't that for horses?", [
		["For whoever's agreed to it", "It's for whoever's agreed to it. The agreeing is the important part.", true,
			"Agreed. Yes. I'll have to ask him, won't I."],
		["Only for the deserving", "Only for the deserving, Mrs Primm.", false, "I beg your pardon."],
		["Ha! Horses! Next!", "Ha! Horses! Yes! Next!", false, "I don't think it's for horses."]]],
	["THE CHAPERONE", Color("6a2a3e"), "Fairweather", "Won't I miss something, with that on?", [
		["That's the point; agree a word", "That's rather the point. Agree a word first, and it all stops the moment you say it.", true,
			"A word. Like a password. Oh, I'd like a password."],
		["Nothing worth seeing", "Nothing worth seeing, dear.", false, "Well, that's rude."],
		["You could peek?", "Um, maybe? You could peek?", false, "Then what's the point?"]]],
	["THE DECENCY DELUXE", Color("24304e"), "Gander", "Tell them about the Deluxe, dear. The councillors' wives can't get enough.", [
		["Start with the small one", "Honestly? Start with the small one. If it isn't fun, it isn't worth it.", true,
			"...Well. Honesty. How refreshing."],
		["Buy three!", "Buy three! One for every room!", false, "Three. Yes. Lovely."],
		["Rather not talk about it", "I'd rather not talk about the Deluxe.", false, "You're the consultant, dear."]]],
]
const SWAP_SECS := 1.1
const ROUND_SECS := 16.0
const SEEN_COST := 0.35
const WRONG_COST := 0.15
const RIGHT_GAIN := 0.1
const BROCHURE_SECS := 2.6

var gander: Talker
var guests: Array[Talker] = []
var husbands: Array = []   # (untyped: a husband gone to the pub is a freed object)
var bag: Node3D
var cupboard: Door

## Where it's at: "" (not started), "intro", "question", "swap", "done". For the HUD and the probes.
var stage := ""
var round_i := -1
var swaps := 0
var hud: SceneHud
var _rigs: Array = []        # the guests' RigGear, seated
var _eyes: Array = []        # per watcher (the three guests, then Gander): {watching, t}
var _answers: Array = []     # this round's answers, in the D-pad's order
var _swap_t := 0.0
var _round_t := 0.0
var _brochure := 0.0
var _brochure_used := false
var _seen_cool := 0.0
var _box: Node3D
var _cam: Camera3D
var _was_cam: Camera3D
var _nim_rig: RigGear
var _sent := {}


func _setup() -> void:
	for i in GUESTS.size():
		var g: Array = GUESTS[i]
		var f: Vector3 = g[3]
		var t := talker("Guest_" + String(g[0]), "party", "guest", g[2], atan2(-f.x, -f.z), "", "garb", g[1], g[5], true, g[4])
		guests.append(t)
	gander = talker("Gander", "party", "arrive", GANDER_AT, -PI / 2.0, "", "garb", "Mrs Gander", Color("e8e0d0"), true, "gander")
	gander.talked.connect(_on_gander)
	_seat_guests.call_deferred()
	if flag("party_done"):
		_after_party(false)
		return
	# Under their feet: two husbands. Fetch: the consultant's bag, from the step. Open: the kit cupboard.
	bag = fetch_box("ConsultantBag", &"consultant_bag", BAG_AT, Vector3(0.42, 0.3, 0.22), Color("4a1a2a"))
	cupboard = door("KitCupboard", CUPBOARD, CUPBOARD + Vector3(0, 0, 1.2), 1.8, 2.1)
	var h1 := staff("Husband_Ashby", "Mr Ashby", Vector3(7.4, 0.08, -119.4), PI / 2.0, "fox_civilian", "On my knees? In front of Marjorie?")
	h1.fetch_item = h1.get_path_to(bag)
	var h2 := staff("Husband_Primm", "Mr Primm", Vector3(-7.6, 0.08, -130.8), -PI / 2.0, "otter_civilian", "Is this part of the demonstration?")
	h2.door = h2.get_path_to(cupboard)
	husbands = [h1, h2]


## The guests on the sofas, posed sitting (held; their heads turn as they look about during the party).
func _seat_guests() -> void:
	await get_tree().process_frame
	for t: Talker in guests:
		var m: EnemyModel = t.look
		if m == null:
			_rigs.append(null)
			continue
		m.hold(true)
		var sk := m.skeleton()
		var rig: RigGear = RigGear.new(sk, t) if sk else null
		if rig:
			var drop := rig.pose_sit()
			rig.capture()
			t.global_position.y -= drop * 0.82   # (the sofa's a little higher than a chair's shin height)
		_rigs.append(rig)


func _physics_process(_delta: float) -> void:
	if stage != "" or flag("party_done") or husbands.is_empty():
		return
	# A husband who's done what he was told takes himself off to the pub.
	for o: Variant in husbands:
		if not is_instance_valid(o):
			continue   # (gone to the pub)
		var h := o as Staff
		if h.state in [Staff.State.FETCH_GO, Staff.State.FETCH_BRING, Staff.State.OPEN_GO]:
			_sent[h] = true
		elif h.state == Staff.State.RETURN and _sent.has(h):
			_sent.erase(h)
			_leave(h)
	var gone := husbands.all(func(h: Variant) -> bool: return not is_instance_valid(h) or (h as Node).has_meta(&"leaving"))
	set_flag("party_ready", gone and cupboard.is_open and nim().suit.keys.has(&"consultant_bag"))


func _leave(h: Staff) -> void:
	h.set_meta(&"leaving", true)
	h.set_physics_process(false)
	h.call(&"_say", ["I'll be at the pub. If anyone asks.", "Pub. Yes. Good idea. Mine."][husbands.find(h) % 2])
	var path := [h.global_position + Vector3(0, 0, 0), FRONT_DOOR + Vector3(0, 0, -1.0), FRONT_DOOR + Vector3(0, 0, 3.0),
		Vector3(0, 0.08, -106.0)]
	var model: Node = h.get(&"_look")
	for i in range(1, path.size()):
		var a: Vector3 = path[i - 1]
		var b: Vector3 = path[i]
		var to := b - a
		to.y = 0.0
		if to.length() > 0.05:
			h.rotation.y = atan2(-to.x, -to.z)
		if model:
			model.call(&"show_state", 0, 0.0, 2.0, 0.0)
		var tw := create_tween()
		tw.tween_property(h, ^"global_position", Vector3(b.x, h.global_position.y, b.z), to.length() / 2.0)
		await tw.finished
		if not is_instance_valid(h):
			return
	h.queue_free()


## Her "begin" sets "primrose/party_go" (talked names the label asked for, "arrive", not where it went).
func _on_gander(_which: String) -> void:
	if flag("party_go") and stage == "":
		clear("party_go")
		if nim().suit.cover_blown:
			Hud.note("Not like that: her cover's blown. A fresh suit first (number 4's porch).")
			return
		_party()


# --- the party ---------------------------------------------------------------------------------------------------------

func _party() -> void:
	var n := nim()
	n.set_physics_process(false)
	n.velocity = Vector3.ZERO
	Hud.show_world_ui(false)
	hud = SceneHud.new()
	add_child(hud)
	await hud.fade(true)
	n.global_position = NIM_AT + Vector3(0, 0.02, 0)
	var to_table := TABLE - NIM_AT
	n.rotation.y = atan2(-to_table.x, -to_table.z)   # facing the table and the far sofa
	_tags(false)
	if n.has_method(&"reset_physics_interpolation"):
		n.reset_physics_interpolation()
	var m: Node = n.get(&"model")
	if m and m.has_method(&"hold"):
		m.call(&"hold", true)
		var sk: Skeleton3D = m.call(&"skeleton")
		if sk:
			_nim_rig = RigGear.new(sk, n)
			_nim_rig.capture()
	_was_cam = get_viewport().get_camera_3d()
	_cam = Camera3D.new()
	_cam.fov = 58.0
	add_child(_cam)
	# From the front door's side, over Nim's shoulder: all three sofas, the table, Mrs Gander by the fire.
	_cam.global_position = Vector3(-1.4, 2.7, -117.0)
	_cam.look_at(Vector3(0.6, 0.5, -125.6), Vector3.UP)
	_cam.make_current()
	gander.global_position = Vector3(-7.8, 0.08, -126.0)
	_eyes = []
	for i in 4:
		_eyes.append({"watching": true, "t": randf_range(1.0, 2.0)})
	swaps = 0
	await hud.fade(false)
	stage = "intro"
	hud.title = "The demonstration party"
	hud.subtitle = "How it goes"
	hud.word = ""
	hud.kind = "intro"
	hud.data = {"lines": ["Four toys from the kit. A lady asks about each: answer her (the D-pad). Honest is right.",
		"Then swap the real toy for a dud from your bag: hold A, but only while every eye is elsewhere.",
		"Y passes the brochure round, once a toy: every eye on it, for a moment.", "Composure is everything. Blown, and it's over."]}
	hud.prompts = [[&"jump", "Begin"]]
	await get_tree().process_frame
	while not Input.is_action_just_pressed(&"jump"):
		await get_tree().process_frame
	await get_tree().process_frame
	await _say_line("Gander", "Ladies! Our consultant. Do be nice. She's ever so late.", 2.6)
	for r in ROUNDS.size():
		round_i = r
		await _round(ROUNDS[r])
		if n.suit.cover_blown:
			break
	await _end_party()


func _say_line(who: String, text: String, secs := 2.4) -> void:
	hud.say(who, text, secs)
	await get_tree().create_timer(minf(secs, 2.2)).timeout


func _round(r: Array) -> void:
	# The box on the coffee table, named.
	_box = Node3D.new()
	add_child(_box)
	_box.global_position = TABLE + Vector3(0, 0.0, 0.25)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.5, 0.26, 0.34)
	mi.mesh = bm
	mi.material_override = Look.toon(r[1])
	mi.position.y = 0.13
	_box.add_child(mi)
	var label := Label3D.new()
	label.text = r[0]
	label.font_size = 18
	label.pixel_size = 0.004
	label.modulate = Color("f0e0b0")
	label.outline_size = 6
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 0.42
	_box.add_child(label)
	hud.title = "Toy %d of %d" % [round_i + 1, ROUNDS.size()]
	hud.subtitle = String(r[0]).capitalize()
	# 1. The question.
	stage = "question"
	var asker: String = r[2]
	await _say_line(asker, r[3], 3.2)
	_answers = (r[4] as Array).duplicate()
	_answers.shuffle()
	var keys := [&"word_up", &"word_right", &"word_down"]
	var picked := -1
	while picked < 0:
		hud.kind = "pads"
		hud.cue = "Answer her."
		hud.data = {"up": [_answers[0][0], SceneHud.CREAM], "right": [_answers[1][0], SceneHud.CREAM],
			"down": [_answers[2][0], SceneHud.CREAM], "hot": "", "timer": -1.0}
		hud.prompts = [[&"word_up", "Your answer"]]
		_meters()
		await get_tree().process_frame
		for k in 3:
			if Input.is_action_just_pressed(keys[k]):
				picked = k
	var a: Array = _answers[picked]
	hud.kind = "text"
	hud.cue = ""
	hud.prompts = []
	await _say_line("Nim", a[1], 3.2)
	if a[2]:
		_gain(RIGHT_GAIN)
		hud.pop("They lean in", SceneHud.GREEN)
	else:
		nim().suit.call(&"_spend", WRONG_COST)
		hud.pop("A look goes round", SceneHud.AMBER)
	await _say_line(asker, a[3], 2.6)
	if nim().suit.cover_blown:
		_box.queue_free()
		return
	# 2. The swap.
	stage = "swap"
	_swap_t = 0.0
	_round_t = ROUND_SECS
	_brochure = 0.0
	_brochure_used = false
	_seen_cool = 0.0
	var swapped := false
	var armed := false
	while true:
		var dt := get_process_delta_time()
		await get_tree().process_frame
		_round_t -= dt
		_brochure -= dt
		_seen_cool -= dt
		_look_about(dt)
		var anyone := _anyone_watching()
		var glance := _glancing()
		# A fresh press: A still held from the last swap (or an answer) doesn't count, or it's "seen" on the first frame.
		if not Input.is_action_pressed(&"jump"):
			armed = true
		var holding := armed and Input.is_action_pressed(&"jump")
		if Input.is_action_just_pressed(&"interact") and not _brochure_used:
			_brochure_used = true
			_brochure = BROCHURE_SECS
			hud.say("Nim", "Do pass the brochure round, ladies. Page four.", 2.0)
		if holding and anyone and _seen_cool <= 0.0:
			_seen()
		elif holding and not anyone and not glance:
			_swap_t += dt
		if _nim_rig:
			_nim_rig.restore()
			if holding:
				_nim_rig.reach(_box.global_position + Vector3(0, 0.15, 0))
		if _swap_t >= SWAP_SECS:
			swapped = true
			swaps += 1
			hud.pop("Swapped", SceneHud.GOLD)
			break
		if _round_t <= 0.0 or nim().suit.cover_blown:
			break
		hud.kind = "text"
		hud.cue = ("Someone's watching. Wait." if anyone else ("Someone's glancing back..." if glance
			else "Every eye's elsewhere. Now.")) + ("   (swapping)" if _swap_t > 0.0 else "")
		hud.prompts = [[&"jump", "Hold to swap"]] + ([] if _brochure_used else [[&"interact", "The brochure"]])
		_meters()
	if _nim_rig:
		_nim_rig.restore()
	if not swapped and not nim().suit.cover_blown:
		hud.pop("The real one goes home", SceneHud.RED)
		await _say_line(asker, "Oh, I'll take this one. The demonstration model.", 2.2)
		nim().suit.call(&"_spend", 0.1)
	_box.queue_free()
	await get_tree().create_timer(0.5).timeout


## Who's looking where. A watcher looks at Nim a while, then away (her tea, her neighbour, the window), and back.
## The brochure has every eye for a moment.
func _look_about(dt: float) -> void:
	for i in _eyes.size():
		var e: Dictionary = _eyes[i]
		e.t -= dt
		if e.t <= 0.0:
			e.watching = not e.watching
			e.t = randf_range(1.4, 2.8) if e.watching else randf_range(1.2, 2.6)
		var looking: bool = e.watching and _brochure <= 0.0 or _seen_cool > 0.0
		if i < _rigs.size() and _rigs[i]:
			var rig: RigGear = _rigs[i]
			rig.restore()
			if not looking:
				rig.turn("head", Vector3.UP, 0.9 if i % 2 == 0 else -0.9)
				rig.turn("head", rig.left(), 0.25)   # and down: at her tea, at the brochure
		elif i == 3 and is_instance_valid(gander):
			var to := (NIM_AT - gander.global_position) if looking else Vector3(-1, 0, 0.3)
			gander.rotation.y = lerp_angle(gander.rotation.y, atan2(-to.x, -to.z), clampf(dt * 6.0, 0.0, 1.0))


func _anyone_watching() -> bool:
	if _seen_cool > 0.0:
		return true
	if _brochure > 0.0:
		return false
	return _eyes.any(func(e: Dictionary) -> bool: return e.watching)


## A tell before anyone looks back (GLANCE seconds of it): the swap waits, and nothing's lost. The brochure's end too.
const GLANCE := 0.45


func _glancing() -> bool:
	if _brochure > 0.0:
		return _brochure < GLANCE
	return _eyes.any(func(e: Dictionary) -> bool: return not e.watching and e.t < GLANCE)


## How long until the first of them looks back (the brochure, while it lasts).
func _away_left() -> float:
	if _brochure > 0.0:
		return _brochure
	var left := INF
	for e: Dictionary in _eyes:
		if e.watching:
			return 0.0
		left = minf(left, e.t)
	return left


func _seen() -> void:
	if OS.get_environment("PROBE_TRACE") != "":
		print("  party: SEEN (round %d, brochure %.2f, eyes %s)" % [round_i, _brochure, str(_eyes)])
	_swap_t = 0.0
	_seen_cool = 1.6
	nim().suit.call(&"_spend", SEEN_COST)
	hud.pop("Seen!", SceneHud.RED)
	var who: String = ["Ashby", "Primm", "Fairweather", "Gander"][randi() % 4]
	hud.say(who, "What's that in your bag, dear?", 1.8)
	hud.say("Nim", "Spare batteries.", 1.8)


func _gain(by: float) -> void:
	var s: Node = nim().suit
	s.set(&"composure", minf(1.0, float(s.get(&"composure")) + by))
	s.emit_signal(&"composure_changed", s.get(&"composure"), s.get(&"cover_blown"), s.get(&"outfit"))


func _meters() -> void:
	# Their eyes: a full red bar watching you, a short green one looking elsewhere.
	var names := ["Ashby", "Primm", "Fairweather", "Gander"]
	var m := [{"name": "Composure", "value": float(nim().suit.composure), "colour": SceneHud.GOLD}]
	if stage == "swap":
		for i in _eyes.size():
			var e: Dictionary = _eyes[i]
			var looking: bool = (e.watching and _brochure <= 0.0) or _seen_cool > 0.0
			var turning: bool = not looking and (_brochure < GLANCE if _brochure > 0.0 else e.t < GLANCE)
			m.append({"name": names[i], "value": 1.0 if looking else (0.5 if turning else 0.12),
				"colour": SceneHud.RED if looking else (SceneHud.AMBER if turning else SceneHud.GREEN)})
	hud.meters = m


func _end_party() -> void:
	stage = "done"
	hud.kind = ""
	hud.meters = []
	var ok: bool = swaps >= 3 and not nim().suit.cover_blown
	await hud.fade(true)
	_close_scene()
	await hud.fade(false)
	if ok:
		await talk("party", "punchline")
		set_flag("party_done")
		_after_party(true)
		award(&"primrose_09", NIM_AT + Vector3(1.4, 0, 0))
	else:
		await talk("party", "fail")
		gander.label = "again"
	hud.queue_free()
	hud = null
	stage = ""


## The guests' and Mrs Gander's name tags: hidden for the party's own camera.
func _tags(on: bool) -> void:
	for t: Talker in guests + [gander]:
		if is_instance_valid(t):
			for c in t.get_children():
				if c is Label3D:
					(c as Label3D).visible = on


func _close_scene() -> void:
	_tags(true)
	var n := nim()
	var m: Node = n.get(&"model")
	if _nim_rig:
		_nim_rig.clear()
		_nim_rig = null
	if m and m.has_method(&"hold"):
		m.call(&"hold", false)
	if _was_cam and is_instance_valid(_was_cam):
		_was_cam.make_current()
	if _cam:
		_cam.queue_free()
		_cam = null
	n.set_physics_process(true)
	Hud.show_world_ui(true)


## Mrs Gander needs some air, in her garden, alone: the back door's unlocked, and she's gone through it (step 4's fight
## is out there).
func _after_party(walk: bool) -> void:
	var lock := level.get_node_or_null("GardenDoor")
	if lock:
		lock.queue_free()
	for t: Talker in guests:
		t.label = "after"
	if not is_instance_valid(gander):
		return
	if not walk:
		gander.queue_free()
		return
	await gander.walk_path([Vector3(-3.0, 0.08, -133.0), Vector3(0.0, 0.08, -135.0), Vector3(0.0, 0.08, -140.0)], 1.8)
	if is_instance_valid(gander):
		gander.queue_free()


## What input is right just now, for the probes: {"tap": action} / {"hold": action, "on": bool}.
func hint() -> Dictionary:
	match stage:
		"intro":
			return {"tap": &"jump"}
		"question":
			if hud and hud.kind == "pads":
				for k in 3:
					if _answers[k][2]:
						return {"tap": [&"word_up", &"word_right", &"word_down"][k]}
			return {}
		"swap":
			# The brochure first (a sure window), then hold while nobody's looking.
			if not _brochure_used:
				return {"hold": &"jump", "on": false, "tap": &"interact"}
			# Only when the room stays away long enough to finish (a player learns the same from the bars).
			if not _anyone_watching() and not _glancing() and _away_left() > SWAP_SECS - _swap_t + 0.1:
				return {"hold": &"jump", "on": true}
			return {"hold": &"jump", "on": false}
	return {}
