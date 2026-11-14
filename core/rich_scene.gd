extends "res://core/club_game.gd"
## Augusta's and Silke's scenes, both ways round, rebuilt to DESIGN "Richer scenes" (owner, 2026-11-13: "build Augusta
## and Silke first"; "let's incorporate gags into the scenes like in a true Domme fashion. Ball, bit, or tape gags").
## Grizelda's, Lull's, Dash's and Rivet's are core/rich_scenes_later.gd, built on this through its hooks (`_form_rows`,
## `_phase_list`, `_intro`, `_phase_start`, `_more_phase`, `_more_camera`, `_hand_rig`, `hint`).
##
## Every scene runs three acts:
##   1. Asking for it: her form (what's tied, how, and a gag or not: ball, bit or tape). A gag means a bell in the
##      sub's hand, and dropping it is her word (hold B, when it's Nim).
##   2. The scene: phases that change what you do and build, each with its own camera, each explained the first time.
##   3. Aftercare you take part in: water, a blanket, words, sitting close; she answers what you did.
## A feeling runs through it: Headspace when Nim's the sub (yield, and the screen softens round the one thing you're
## doing: the vignette, the panels fading back, the camera drawing in), Connection when she leads (read her body:
## her breathing, her hands, her glance; nothing is captioned for you). It's the score: a scene goes well on it.
##
##   silke switch:   offer each limb as she asks (the rope goes on as you do) / breathe with her / her colour /
##                   the line drawn up: breath and balance together / the release: wiggle your fingers for her
##   silke domme:    tie her, knot by knot (the pattern she asked for) / check her hands: one may have gone still
##                   (too tight; loosen it) / ask how she is / let her sit in it: praise her as she breathes out
##   augusta switch: positions as she calls them (attention, kneel, present, inspection: your body takes each) /
##                   hold it while she circles you: the drift, her crop under your chin, "eyes front" (don't move) /
##                   her colour / the book on your head, if you asked for it
##   augusta domme:  inspect her: nothing's captioned; watch her body and fix what slips; sometimes she's only
##                   testing whether you'll notice nothing is wrong / ask how she is / praise her as she breathes out
## `hint()` says what input is right just now: the probes follow it. OWNER REVIEW: every line here.

## Each sister's form: [row id, heading, [[value, label]...]]. Her limits (CrossScene.PROFILES) are skipped.
const FORMS := {
	"silke_switch": [["tie", "TIE", [["wrists", "Wrists"], ["chest", "Wrists and chest"], ["full", "Full: chest and ankles"]]],
		["mouth", "MOUTH", [["none", "Nothing"], ["ball", "Ball gag"], ["bit", "Bit gag"], ["tape", "Tape"]]],
		["how", "HOW", [["gentle", "Gentle"], ["firm", "Firm"]]]],
	"silke_domme": [["tie", "PATTERN", [["wrists", "Wrists"], ["chest", "Chest harness"], ["full", "The full tie"]]],
		["mouth", "MOUTH", [["none", "Nothing"], ["ball", "Ball gag"], ["bit", "Bit gag"], ["tape", "Tape"]]],
		["how", "HOW", [["gentle", "Gentle"], ["firm", "Firm"]]]],
	"augusta_switch": [["mouth", "MOUTH", [["none", "Nothing"], ["ball", "Ball gag"], ["bit", "Bit gag"], ["tape", "Tape"]]],
		["book", "THE BOOK", [["no", "Not tonight"], ["yes", "On my head"]]],
		["how", "HOW", [["gentle", "Gentle"], ["firm", "Strict"]]]],
	"augusta_domme": [["mouth", "MOUTH", [["none", "Nothing"], ["ball", "Ball gag"], ["bit", "Bit gag"], ["tape", "Tape"]]],
		["how", "HOW", [["gentle", "Gentle"], ["firm", "Strict"]]]],
}
## What she says to open the form, and the phases' intro cards: [title, [lines]].
const OPENERS := {
	"silke_switch": "What do you want tonight? Tell me, and I'll tie it.",
	"silke_domme": "Your rope, then. What are you tying, and how?",
	"augusta_switch": "Protocol, darling. Choose what you can hold, and I'll hold you to it.",
	"augusta_domme": "Inspect me, then. Choose what I wear for it.",
}
const PHASE_INTROS := {
	"offer": ["Offer yourself", ["Silke asks for each part of you in turn: listen.", "Left wrist: D-pad left. Right wrist: right. Arms up: up. Chest, ankles: down.",
		"The rope goes on as you give it."]],
	"breathe": ["Breathe with her", ["Hold A to breathe in, let go to breathe out: keep your ring on hers.", "Keep the stick still. Headspace grows as you do."]],
	"line": ["The line", ["She draws the line up: onto your toes.", "Keep breathing with her (A) AND keep your balance (stick): both at once."]],
	"release": ["The release", ["She unties you, piece by piece.", "Wiggle your fingers for her: left, right, left, right on the D-pad."]],
	"tie": ["Tie her", ["Each knot is a short D-pad sequence. Each one you finish goes on her.", "A slip is a knot pulled too tight: you'll need to find it after."]],
	"hands": ["Her hands", ["Watch her hands: the one that's gone still is too tight.", "Loosen it: D-pad left or right. Both moving: up, they're fine."]],
	"check": ["Ask her", ["She's gone quiet. Ask how she is: Y."]],
	"sit": ["Let her sit in it", ["Watch her breathe. Her chest rises, and falls.", "Praise her (Y) as she breathes out. Not in. Don't rush it."]],
	"positions": ["Positions", ["She calls a position; take it.", "Attention: up. Kneel: down. Present: right. Inspection: left."]],
	"hold": ["Hold it", ["She circles you. Keep the needle in the green with the stick.", "\"Chin.\": up, quickly. \"Eyes front.\": don't touch anything until she's done."]],
	"book": ["The book", ["A book on your head, and she'll make you work for it.", "Keep the needle in the green. If it tips too far, it falls."]],
	"inspect": ["Inspect her", ["Nothing's captioned: watch her. Turn the camera round her with the stick.",
		"Fix what slips: up chin, down shoulders, right hands, left feet.", "Sometimes nothing's wrong, and she's testing whether you'll notice. Then do nothing."]],
	"colour": ["", []],
}
const PHASES := {
	"silke_switch": ["offer", "breathe", "colour", "line", "release"],
	"silke_domme": ["tie", "hands", "check", "sit"],
	"augusta_switch": ["positions", "hold", "colour", "book"],
	"augusta_domme": ["inspect", "check", "sit"],
}
## Silke's asks, by what's tied: [action, what she says, what it does].
const OFFERS := {
	"wrists": [[&"word_left", "Left wrist.", "wrapL"], [&"word_right", "Right.", "wrapR"], [&"word_up", "Arms up. All the way.", "up"]],
	"chest": [[&"word_left", "Left wrist.", "wrapL"], [&"word_right", "Right.", "wrapR"], [&"word_up", "Arms up.", "up"],
		[&"word_down", "Breathe in. Hold it.", "chest"]],
	"full": [[&"word_left", "Left wrist.", "wrapL"], [&"word_right", "Right.", "wrapR"], [&"word_up", "Arms up.", "up"],
		[&"word_down", "Breathe in. Hold it.", "chest"], [&"word_down", "Feet together.", "ankles"]],
}
const POSITIONS := [[&"word_up", "Attention.", "stand"], [&"word_down", "Kneel.", "kneel"], [&"word_right", "Present.", "wrists"],
	[&"word_left", "Inspection.", "behind"]]
## The order she calls them in.
const ORDER := [0, 1, 3, 2, 1, 3]
## What she says to each thing done for her in aftercare (water, blanket, words, sitting close).
const CARE := {
	"silke": {"water": "...Thanks. Slowly. I know.", "blanket": "Mm. Warm.", "words": "You were good. You're always good at this.",
		"close": "Stay. Just there."},
	"augusta": {"water": "Lovely. Tea would be lovelier. Later.", "blanket": "Oh, you are a dear.",
		"words": "Tell me again. I didn't hear it the first time. I did. Tell me anyway.", "close": "Closer. That's it."},
}

var picks := {}
## Headspace (Nim the sub) or Connection (Nim leading), 0..1.
var feel := 0.0
var phase := ""
var _phases: Array = []
var _pi := -1
var _ph_t := 0.0
var _explained := {}
var _gag := ""
var _bell_node: Node3D
var _neutral := {}
var _kneel_drop := 0.0
var _crop: Node3D
# phase state
var _ask := 0
var _ask_t := 0.0
var _wiggles := 0
var _tight := ""
var _hands_rounds := 0
var _praised := 0
var _prompt := ""          # "chin" / "eyes" / "": Augusta's interruptions while you hold
var _prompt_t := 0.0
var _next_prompt := 3.0
var _test := false
var _orbit := 0.0
var _book: Node3D
var _care_done := []
var _other := Vector3.ZERO      # where the one leading stands
var _hand_at := Vector3.INF     # where Nim's hand went to correct her, held a moment
var _hand_t := 0.0


func _key() -> String:
	return "%s_%s" % [sister, mode]


# --- the tables, overridable (core/rich_scenes_later.gd adds Grizelda's, Lull's, Dash's and Rivet's) ------------------

func _form_rows() -> Array:
	return FORMS[_key()]


func _opener() -> String:
	return OPENERS[_key()]


func _phase_list() -> Array:
	return PHASES[_key()]


## A phase's intro card: [title, [lines]], or [] for none.
func _intro(p: String) -> Array:
	return PHASE_INTROS.get(p, [])


func _care_lines() -> Dictionary:
	return CARE.get(sister, CARE["silke"])


## Hooks for the later scenes: a phase starting, its camera, its frame (true when it's over), and its hint.
func _phase_start(_p: String) -> void:
	pass


func _more_camera(_hall: Vector3) -> void:
	pass


func _more_phase(_delta: float) -> bool:
	return false


## Whose hand does the work, reaching for `_reach`: the leader's, unless it's Nim's at the work.
func _hand_rig() -> RigGear:
	return _top_rig


func _run() -> void:
	await hud.fade(true)
	_stage_rich()
	await hud.fade(false)
	# 1. Asking for it.
	if not await _ask_form():
		_say(sister.capitalize(), "Another time, then. Nothing owed.")
		await get_tree().create_timer(1.2).timeout
		_end({"ok": false, "declined": true})
		return
	await hud.fade(true)
	_dress_for_scene()
	await hud.fade(false)
	_say(sister.capitalize(), "Ready when you are." if mode == &"switch" else "Go on, then.")
	# 2. The scene.
	_phases = _phase_list().duplicate()
	if picks.get("book", "no") == "no":
		_phases.erase("book")
	_next_phase()


# --- staging -----------------------------------------------------------------------------------------------------------

## Both in her room: Silke's frame, Augusta's middle. Nobody's posed or tied yet: the scene does that, a piece at a
## time.
func _stage_rich() -> void:
	var r := _room()
	var at: Vector3 = r.at
	var side := signf(at.x)
	var hall := Vector3(-side, 0, 0)
	var sub: Node3D = _nim if _sub_is_nim() else _sis
	var top: Node3D = _sis if _sub_is_nim() else _nim
	if not _sub_is_nim() and _sis:
		_sis.dress("swim")
	_name_tags(false)
	_was_cam = get_viewport().get_camera_3d()
	if not sister in ["silke", "augusta"]:
		# The throne, the Quiet Room, the punch bag, the bench: placed and posed as before (ClubGame._stage_later).
		_stage_later(r, sub, top)
		_other = top.global_position if top else _frame
		if _rig:
			_neutral = _rig.snapshot()
		_clear_room(r)
		return
	_frame =Vector3(side * 9.4, at.y, at.z) if sister == "silke" else at + Vector3(side * 0.9, 0, 0)
	_other = _frame + hall * 1.35 + Vector3(0, 0, 0.7 if sister == "silke" else -0.8)
	_place(sub, _frame, _frame + hall)
	_place(top, _other, _frame)
	_rig = _pose(sub, "stand")
	if _rig:
		_neutral = _rig.snapshot()
	# Nim's held too when she leads, so her hand can go where the work is.
	if not _sub_is_nim():
		_top_rig = _pose(top, "stand")
	var cz := -2.0 if sister == "silke" else 1.9
	_camera(_frame + hall * 3.6 + Vector3(0, 1.62, cz), _frame + hall * 0.7 + Vector3(0, 0.62, -cz * 0.12))
	_clear_room(r)


## The form's choices go on: a gag and its bell, Augusta's crop in her hand.
func _dress_for_scene() -> void:
	_gag = String(picks.get("mouth", "none"))
	if _rig and _gag != "none":
		_rig.gag(_gag)
		_bell_node = _rig.bell("handR")
	if sister == "augusta" and mode == &"switch" and _sis and _sis.model:
		var sk: Skeleton3D = _sis.model.skeleton()
		if sk:
			var hand := RigGear.new(sk, _sis)
			_crop = hand.attach("handR", RigGear.tool_mesh("crop"), Vector3(0, 0.05, 0))


func gagged() -> bool:
	return _gag != "" and _gag != "none"


# --- act 1: the form ---------------------------------------------------------------------------------------------------

func _ask_form() -> bool:
	stage = "form"
	var rows: Array = _form_rows()
	var limits: Array = []
	if not _sub_is_nim():
		limits = (CrossScene.PROFILES.get(sister, {}) as Dictionary).get("limits", [])
	for row: Array in rows:
		picks[row[0]] = row[2][0][0]
	if mode == &"domme" and sister == "silke":
		picks["how"] = "firm"   # her wants, filled in
	_say(sister.capitalize(), _opener(), 4.0)
	hud.title = "Asking for it"
	hud.subtitle = "%s, %s" % [sister.capitalize(), "leading" if _sub_is_nim() else "for you to lead"]
	hud.word = "\"red\", or the bell if gagged"
	hud.prompts = [[&"word_up", "Row"], [&"word_right", "Choose"], [&"jump", "Agree"], [&"crouch", "Not tonight"]]
	hud.cue = "What happens, and what doesn't."
	var at := 0
	var ready := true
	await get_tree().process_frame
	while true:
		var shown: Array = []
		for row: Array in rows:
			var opts: Array = []
			for o: Array in row[2]:
				opts.append({"text": o[1], "on": o[0] == picks[row[0]], "limit": o[0] in limits})
			shown.append({"head": row[1], "opts": opts})
		var foot := "A gag means a bell in the sub's hand: dropping it is the word." if picks.get("mouth", "none") != "none" \
			else "The word is \"red\", always."
		hud.kind = "form"
		hud.data = {"rows": shown, "at": at, "foot": foot}
		await get_tree().process_frame
		var v := Input.get_axis(&"move_up", &"move_down")
		var h := Input.get_axis(&"move_left", &"move_right")
		var moved := absf(v) > 0.6 or absf(h) > 0.6
		if Input.is_action_just_pressed(&"word_down") or (v > 0.6 and ready):
			at = wrapi(at + 1, 0, rows.size())
		elif Input.is_action_just_pressed(&"word_up") or (v < -0.6 and ready):
			at = wrapi(at - 1, 0, rows.size())
		elif Input.is_action_just_pressed(&"word_right") or (h > 0.6 and ready):
			_cycle_pick(rows[at], 1, limits)
		elif Input.is_action_just_pressed(&"word_left") or (h < -0.6 and ready):
			_cycle_pick(rows[at], -1, limits)
		elif Input.is_action_just_pressed(&"jump"):
			hud.kind = ""
			return true
		elif Input.is_action_just_pressed(&"crouch"):
			hud.kind = ""
			return false
		ready = not moved
	return false


func _cycle_pick(row: Array, dir: int, limits: Array) -> void:
	var opts: Array = row[2]
	var i := 0
	for k in opts.size():
		if opts[k][0] == picks[row[0]]:
			i = k
	for n in opts.size():
		i = wrapi(i + dir, 0, opts.size())
		if not opts[i][0] in limits:
			picks[row[0]] = opts[i][0]
			return


# --- act 2: the phases -------------------------------------------------------------------------------------------------

func _next_phase() -> void:
	_pi += 1
	if _pi >= _phases.size():
		_finish_scene()
		return
	phase = _phases[_pi]
	_ph_t = 0.0
	_ask = 0
	_ask_t = 0.0
	_wiggles = 0
	_praised = 0
	_prompt = ""
	if phase == "colour":
		stage = "colour" if mode == &"switch" else "play"
		_say(sister.capitalize(), "Colour?")
		return
	# The first time: how it goes, and A to begin.
	var intro := _intro(phase)
	if not intro.is_empty() and not (intro[1] as Array).is_empty() and not _explained.has(phase):
		_explained[phase] = true
		stage = "intro"
		hud.title = intro[0]
		hud.subtitle = "How it goes"
		hud.kind = "intro"
		hud.cue = ""
		hud.data = {"lines": intro[1]}
		hud.prompts = [[&"jump", "Begin"]]
		await get_tree().process_frame
		while not Input.is_action_just_pressed(&"jump"):
			await get_tree().process_frame
		await get_tree().process_frame
	stage = phase
	_phase_camera()
	match phase:
		"tie":
			_new_knot()
		"hands":
			_new_hands()
		"positions":
			_ask = 0
			_ask_t = 2.6
		"hold":
			_circle_start()
	_phase_start(phase)


## Each phase's shot.
func _phase_camera() -> void:
	_cam_from = Vector3.INF
	_cam_look = Vector3.INF
	if _cam and _cam_home != Transform3D():
		_cam.global_transform = _cam_home
	if _rig == null:
		return
	var hall := _cam_home.origin - _frame
	hall.y = 0.0
	hall = hall.normalized()
	match phase:
		"breathe", "sit":
			# Her face and chest, close.
			_cam_from = _rig.pos("chest") + hall * 1.25 + Vector3.UP * 0.25 + hall.cross(Vector3.UP) * 0.45
			_cam_at = _rig.pos("neck")
		"hold", "book", "inspect":
			_cam_from = _frame + hall * 2.4 + Vector3.UP * 1.45 + hall.cross(Vector3.UP) * -0.9
			_cam_at = _frame + Vector3.UP * 1.0
	_more_camera(hall)


func _process(delta: float) -> void:
	if _done or stage in ["setup", "intro", "form"]:
		return
	_t += delta
	_ph_t += delta
	if _rig:
		_rig.restore()
	if _top_rig:
		_top_rig.restore()
	_reach = Vector3.INF
	if _gagged_word(delta):
		return
	if mode == &"switch" and not gagged() and _safeword(delta):
		return
	var done := false
	match phase:
		"offer": done = _offer(delta)
		"breathe": done = _breathe_rich(delta)
		"colour": done = _colour(delta)
		"line": done = _line(delta)
		"release": done = _release(delta)
		"tie": done = _tie_rich(delta)
		"hands": done = _hands(delta)
		"check": done = _ask_her(delta)
		"sit": done = _sit_in_it(delta)
		"positions": done = _positions(delta)
		"hold": done = _hold(delta)
		"book": done = _book_phase(delta)
		"inspect": done = _inspect(delta)
		_: done = _more_phase(delta)
	if _done:
		return
	_feel_show()
	var hand := _hand_rig()
	if hand and _reach != Vector3.INF:
		hand.reach(_reach)
	_follow_cam(delta)
	if _cam:
		_cam.fov = lerpf(_cam.fov, 55.0 - (12.0 * feel if mode == &"switch" else 0.0), clampf(delta * 1.5, 0.0, 1.0))
	if done:
		stage = "play"
		_next_phase()


## The meter on screen, and Headspace's softening.
func _feel_show() -> void:
	var label := "Headspace" if mode == &"switch" else "Connection"
	hud.meters = [{"name": label, "value": feel, "colour": SceneHud.ROSE if mode == &"switch" else SceneHud.GREEN}]
	hud.headspace = feel * 0.9 if mode == &"switch" else 0.0
	hud.word = "the bell" if gagged() else "\"red\""
	if not _sub_is_nim():
		hud.word = "her bell" if gagged() else "her word: \"red\""


func _grow(by: float) -> void:
	feel = clampf(feel + by, 0.0, 1.0)


## Gagged, Nim's word is the bell: hold B and it drops. It stops everything, and that's never wrong.
func _gagged_word(delta: float) -> bool:
	if not (gagged() and _sub_is_nim()):
		return false
	_safe_t = _safe_t + delta if Input.is_action_pressed(&"crouch") else 0.0
	hud.safeword_hold = clampf(_safe_t / SAFEWORD_HOLD, 0.0, 1.0)
	if _safe_t >= SAFEWORD_HOLD:
		_drop_bell()
		hud.pop("The bell drops", SceneHud.RED)
		_say(sister.capitalize(), "The bell. Good. I've got you. Everything stops.")
		_end({"ok": true, "stopped": true})
		return true
	return false


func _drop_bell() -> void:
	if not is_instance_valid(_bell_node):
		return
	var at := _bell_node.global_position
	_bell_node.get_parent().remove_child(_bell_node)
	hub.add_child(_bell_node)
	_bell_node.global_transform = Transform3D(Basis(), at)
	create_tween().tween_property(_bell_node, ^"global_position:y", _frame.y + 0.03, 0.35)


## Speech through a gag comes out muffled, its meaning in brackets.
func _say(who: String, text: String, secs := 2.6) -> void:
	var sub_name := "Nim" if _sub_is_nim() else sister.capitalize()
	if gagged() and who == sub_name and not _done:
		text = RigGear.muffle(text)
	super(who, text, secs)


# --- Silke, she leads --------------------------------------------------------------------------------------------------

## She asks for each part of Nim in turn; given, the rope goes on.
func _offer(delta: float) -> bool:
	_header("Offer yourself", "The rope goes on as you give it.")
	var asks: Array = OFFERS[picks.get("tie", "wrists")]
	if _ask >= asks.size():
		return true
	var a: Array = asks[_ask]
	if _ask_t <= 0.0:
		_ask_t = 3.2
		_say("Silke", a[1], 2.4)
	_ask_t -= delta
	var press := _pressed(WORDS)
	if press == a[0]:
		_offer_done(a[2])
		hud.pop("Given", SceneHud.GREEN)
		_grow(0.06)
		_ask += 1
		_ask_t = 0.0
	elif press != &"" or _ask_t <= 0.0:
		_say("Silke", "Other one. Listen to me.", 1.8)
		_grow(-0.03)
		_ask_t = 1.0
	hud.kind = "pads"
	hud.cue = "Silke: \"%s\"" % a[1]
	hud.data = {"up": ["Arms up", SceneHud.CREAM], "down": ["Chest / ankles", SceneHud.CREAM], "left": ["Left wrist", SceneHud.CREAM],
		"right": ["Right wrist", SceneHud.CREAM], "hot": "", "timer": clampf(_ask_t / 3.2, 0.0, 1.0)}
	hud.prompts = [[&"word_up", "What she asks for"]]
	_aim_cam(_rig.pos("chest") if _rig else _frame, 2.1)   # the whole of her, the rope going on
	return false


func _offer_done(what: String) -> void:
	if _rig == null:
		return
	match what:
		"wrapL":
			_rig.wrap("forearmL", 0.042, (_rig.pos("handL") - _rig.pos("forearmL")).length() * 0.86)
		"wrapR":
			_rig.wrap("forearmR", 0.042, (_rig.pos("handR") - _rig.pos("forearmR")).length() * 0.86)
		"up":
			_rig.reset_to(_neutral)
			_rig.pose_arms_up()
			_rig.capture()
			_tie(1)   # the line up to the beam
		"chest":
			_rig.harness()
		"ankles":
			_tie(3)


func _breathe_rich(delta: float) -> bool:
	_header("Breathe with her", "Hold A in, let go out. Stay with her.")
	var cycle := fmod(_ph_t, BREATH) / BREATH
	_her = 0.5 - 0.5 * cos(cycle * TAU)
	_mine = clampf(_mine + (1.0 if Input.is_action_pressed(&"jump") else -1.0) * delta / (BREATH * 0.5), 0.0, 1.0)
	var still := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down").length() < 0.3
	var sync := absf(_mine - _her) < 0.2 and still
	_grow((0.035 if sync else -0.02) * delta)
	hud.kind = "ring"
	hud.cue = "Breathe in..." if cycle < 0.5 else "...and out."
	hud.data = {"target": _her, "mine": _mine, "sync": sync, "label": "IN" if cycle < 0.5 else "OUT", "hers": "Silke's"}
	hud.prompts = [[&"jump", "Hold to breathe in"], [&"stick", "Keep still"]]
	_breath_pose()
	return _ph_t >= 18.0


## Her colour question, mid-scene. Gagged, it's a nod, a shake, or the bell.
func _colour(_delta: float) -> bool:
	if mode != &"switch":
		return true
	hud.kind = "pads"
	hud.cue = "%s asks your colour." % sister.capitalize()
	var g := gagged()
	hud.data = {"up": ["A nod (green)" if g else "Green", SceneHud.GREEN], "right": ["A so-so tilt (yellow)" if g else "Yellow", SceneHud.AMBER],
		"down": ["Red" if not g else "Hold B: the bell", SceneHud.RED], "hot": "", "timer": -1.0}
	hud.prompts = [[&"word_up", "Green"], [&"word_right", "Yellow"], [&"word_down" if not g else &"crouch", "Red"]]
	var a := _pressed([&"word_up", &"word_right", &"word_down"])
	match a:
		&"word_up":
			_say("Nim", "Green.")
			_say(sister.capitalize(), "Good. Stay with me.")
			_grow(0.08)
			return true
		&"word_right":
			_say("Nim", "Yellow.")
			_say(sister.capitalize(), "Yellow. I'll ease off. Thank you for telling me.")
			picks["how"] = "gentle"
			_grow(0.04)
			return true
		&"word_down":
			if not g:
				_say("Nim", "Red.")
				_end({"ok": true, "stopped": true})
	return false


## Up on her toes on the line: breath and balance together.
func _line(delta: float) -> bool:
	_header("The line", "Up on your toes. Breathe, and balance.")
	var cycle := fmod(_ph_t, BREATH) / BREATH
	_her = 0.5 - 0.5 * cos(cycle * TAU)
	_mine = clampf(_mine + (1.0 if Input.is_action_pressed(&"jump") else -1.0) * delta / (BREATH * 0.5), 0.0, 1.0)
	_drift = lerpf(_drift, randf_range(-1.0, 1.0), delta * (1.1 if picks.how == "firm" else 0.8))
	_balance = clampf(_balance + (_drift * 0.8 + Input.get_axis(&"move_left", &"move_right") * 1.6) * delta, -1.0, 1.0)
	var both := absf(_mine - _her) < 0.22 and absf(_balance) < 0.4
	_grow((0.04 if both else -0.025) * delta)
	hud.kind = "gauge"
	hud.cue = ("IN" if cycle < 0.5 else "OUT") + ("   (with her)" if absf(_mine - _her) < 0.22 else "   (catch her breath)")
	hud.data = {"marker": _balance, "zone": Vector2(0.0, 0.4), "good": both}
	hud.prompts = [[&"jump", "Breathe (hold in)"], [&"stick", "Balance"]]
	if _rig:
		_rig.turn("hips", _rig.fwd(), -_balance * 0.15)
	_breath_pose()
	return _ph_t >= 15.0


## The release: fingers, for her, left and right.
func _release(_delta: float) -> bool:
	_header("The release", "Wiggle your fingers for her.")
	var want: StringName = &"word_left" if _wiggles % 2 == 0 else &"word_right"
	if _pressed([want]) != &"":
		_wiggles += 1
		_grow(0.02)
	if _rig:
		_rig.turn("handL", _rig.left(), sin(_ph_t * 14.0) * 0.3 * float(_wiggles > 0))
		_rig.turn("handR", _rig.left(), -sin(_ph_t * 14.0) * 0.3 * float(_wiggles > 0))
	hud.kind = "pads"
	hud.cue = "\"Wiggle them for me. Good. Again.\""
	hud.data = {"left": ["Left", SceneHud.CREAM], "right": ["Right", SceneHud.CREAM], "hot": String(want), "timer": -1.0}
	hud.prompts = [[want, "Your fingers"]]
	if _wiggles >= 8:
		_say("Silke", "Good. All here. Every finger.", 2.0)
		return true
	return false


# --- Silke, Nim leads --------------------------------------------------------------------------------------------------

func _tie_count() -> int:
	return {"wrists": 3, "chest": 4, "full": 6}.get(picks.get("tie", "wrists"), 3)


var _slips := 0


func _tie_rich(_delta: float) -> bool:
	_header("Tie her", "%s, knot by knot." % {"wrists": "Her wrists", "chest": "A chest harness", "full": "The full tie"}.get(picks.get("tie", "wrists"), ""))
	var a := _pressed(WORDS)
	if a != &"":
		if a == _seq[_seq_i]:
			_seq_i += 1
			if _seq_i >= _seq.size():
				_tie_piece(_knots)
				_knots += 1
				_grow(0.07)
				hud.pop("Knot %d" % _knots, SceneHud.GOLD)
				_say("Silke", ["Neat.", "Mm. Firm, not tight.", "You've been practising."][_knots % 3], 1.8)
				if _knots >= _tie_count():
					# A knot with slips in it went on too tight: one hand, to find in the next phase.
					_tight = ("L" if randf() < 0.5 else "R") if _slips >= 2 else ""
					return true
				_new_knot()
		else:
			_slips += 1
			hud.pop("Slipped", SceneHud.RED)
			_say("Silke", "Other way. ...I can see it from here.", 1.8)
			_seq_i = 0
	hud.kind = "steps"
	hud.cue = "Knot %d of %d" % [mini(_knots + 1, _tie_count()), _tie_count()]
	hud.data = {"seq": _seq, "at": _seq_i, "knot": _knots, "of": _tie_count()}
	hud.prompts = [[&"word_up", "The D-pad, in order"]]
	_reach = (_rig.pos("handL") + _rig.pos("handR")) / 2.0 if _rig else Vector3.INF
	_aim_cam(_reach if _reach != Vector3.INF else _frame, 1.7)
	return false


## Her tie, piece by piece: wrists (and up to the beam), the harness, the ankles.
func _tie_piece(k: int) -> void:
	if _rig == null:
		return
	match k:
		0:
			_rig.wrap("forearmL", 0.042, (_rig.pos("handL") - _rig.pos("forearmL")).length() * 0.86)
		1:
			_rig.wrap("forearmR", 0.042, (_rig.pos("handR") - _rig.pos("forearmR")).length() * 0.86)
		2:
			_rig.reset_to(_neutral)
			_rig.pose_arms_up()
			_rig.capture()
			_tie(1)
		3:
			_rig.harness()
		4, 5:
			var s := "L" if k == 4 else "R"
			_rig.wrap("shin" + s, 0.05, (_rig.pos("foot" + s) - _rig.pos("shin" + s)).length() * 0.8, 2)


func _new_hands() -> void:
	if _hands_rounds > 0:
		_tight = "" if randf() < 0.4 else ("L" if randf() < 0.5 else "R")


## Her hands: the one that's gone still is too tight.
func _hands(_delta: float) -> bool:
	_header("Her hands", "Watch them.")
	if _rig:
		var l := _rig.left()
		if _tight != "L":
			_rig.turn("handL", l, sin(_ph_t * 9.0) * 0.35)
		if _tight != "R":
			_rig.turn("handR", l, sin(_ph_t * 9.0 + 1.3) * 0.35)
	var a := _pressed([&"word_left", &"word_right", &"word_up"])
	if a != &"":
		var right := (a == &"word_left" and _tight == "L") or (a == &"word_right" and _tight == "R") or (a == &"word_up" and _tight == "")
		if right:
			_grow(0.1)
			hud.pop("Right", SceneHud.GREEN)
			_say("Silke", "Mm. Better." if _tight != "" else "They're fine. You looked, though. Good.", 2.0)
		else:
			_grow(-0.06)
			hud.pop("Look again", SceneHud.AMBER)
			_say("Silke", "Not that one.", 1.6)
		_hands_rounds += 1
		_tight = ""
		if _hands_rounds >= 2:
			return true
		_new_hands()
	hud.kind = "pads"
	hud.cue = "Which hand's gone still?"
	hud.data = {"left": ["Loosen left", SceneHud.CREAM], "right": ["Loosen right", SceneHud.CREAM], "up": ["Both fine", SceneHud.CREAM],
		"hot": "", "timer": -1.0}
	hud.prompts = [[&"word_left", "Left"], [&"word_right", "Right"], [&"word_up", "Fine"]]
	_aim_cam((_rig.pos("handL") + _rig.pos("handR")) / 2.0 if _rig else _frame)
	return false


## A Domme asks. Gagged, she nods.
func _ask_her(_delta: float) -> bool:
	_header("Ask her", "She's gone quiet.")
	hud.kind = "text"
	hud.cue = "She's gone quiet. Ask how she is."
	hud.prompts = [[&"interact", "How are you doing?"]]
	if Input.is_action_just_pressed(&"interact"):
		_say("Nim", "How are you doing?")
		if gagged():
			_say(sister.capitalize(), "Green.", 2.0)
			hud.pop("A nod", SceneHud.GREEN)
		else:
			_say(sister.capitalize(), "Green. ...Thank you for asking.")
		_grow(0.12)
		return true
	if _ph_t > 8.0:
		_say(sister.capitalize(), "You forgot to ask me. Ask, next time. Always.")
		_grow(-0.1)
		return true
	return false


## Watch her breathe; praise her as she breathes out.
func _sit_in_it(_delta: float) -> bool:
	_header("Let her sit in it", "Watch her breathe.")
	var cycle := fmod(_ph_t, 4.4) / 4.4
	var out := cycle >= 0.5
	if _rig:
		var breath := 0.5 - 0.5 * cos(cycle * TAU)
		_rig.turn("chest", _rig.left(), -0.09 * breath)
		_rig.turn("head", _rig.left(), -0.05 * breath)
	if Input.is_action_just_pressed(&"interact"):
		if out:
			_praised += 1
			_grow(0.08)
			hud.pop("She melts", SceneHud.GREEN)
			_say("Nim", ["Good.", "That's it.", "Just like that.", "Perfect.", "So good."][mini(_praised - 1, 4)], 1.4)
		else:
			_grow(-0.04)
			hud.pop("Not yet", SceneHud.AMBER)
	hud.kind = "text"
	hud.cue = "She breathes out..." if out else "She breathes in."
	hud.prompts = [[&"interact", "Praise her"]]
	return _praised >= 5 or _ph_t > 40.0


# --- Augusta, she leads ------------------------------------------------------------------------------------------------

## Positions, as she calls them; Nim's body takes each.
func _positions(delta: float) -> bool:
	_header("Positions", "As she calls them.")
	if _ask >= ORDER.size():
		_nim_takes("behind")
		return true
	var p: Array = POSITIONS[ORDER[_ask]]
	_ask_t -= delta
	if _prompt != String(p[2]):
		_prompt = String(p[2])
		_say("Augusta", p[1], 1.8)
	var press := _pressed(WORDS)
	if press == p[0]:
		_nim_takes(p[2])
		_grow(0.07)
		hud.pop("Yes, Augusta", SceneHud.GREEN)
		_ask += 1
		_ask_t = 2.9 - 0.15 * _ask
		_prompt = ""
	elif press != &"" or _ask_t <= 0.0:
		_say("Augusta", "No, darling. %s" % p[1], 1.8)
		_grow(-0.04)
		_ask_t = 2.6
	hud.kind = "pads"
	hud.cue = "Augusta: \"%s\"" % p[1]
	hud.data = {"up": ["Attention", SceneHud.CREAM], "down": ["Kneel", SceneHud.CREAM], "right": ["Present", SceneHud.CREAM],
		"left": ["Inspection", SceneHud.CREAM], "hot": "", "timer": clampf(_ask_t / 2.9, 0.0, 1.0)}
	hud.prompts = [[&"word_up", "The position she calls"]]
	return false


## Nim into a position: from her neutral pose, kneeling lowered, the others standing.
func _nim_takes(how: String) -> void:
	if _rig == null:
		return
	_rig.reset_to(_neutral)
	if _kneel_drop > 0.0:
		_nim.global_position.y += _kneel_drop
		_kneel_drop = 0.0
	match how:
		"kneel":
			_kneel_drop = _rig.pose_kneel()
			_rig.pose_hands_behind()
			_nim.global_position.y -= _kneel_drop
		"wrists":
			_rig.pose_wrists_out()
		"behind":
			_rig.pose_hands_behind()
	_rig.capture()
	if _nim.has_method(&"reset_physics_interpolation"):
		_nim.reset_physics_interpolation()


## Augusta walks a slow circle round her.
func _circle_start() -> void:
	if _sis == null:
		return
	_circle()


func _circle() -> void:
	var pts: Array = []
	for i in 9:
		var a := i * TAU / 8.0 + 0.3
		pts.append(_frame + Vector3(cos(a), 0, sin(a)) * 1.35)
	await _sis.walk_path(pts, 0.85)
	if is_instance_valid(self) and phase == "hold" and not _done:
		_circle()


## Hold it while she circles: the drift, her crop under your chin, and "eyes front" (don't move at all).
func _hold(delta: float) -> bool:
	_header("Hold it", "She circles you. Hold.")
	_drift = lerpf(_drift, randf_range(-1.0, 1.0), delta * (1.0 if picks.how == "firm" else 0.7))
	var stick := Input.get_axis(&"move_left", &"move_right")
	_balance = clampf(_balance + (_drift * 0.85 + stick * 1.6) * delta, -1.0, 1.0)
	var good := absf(_balance) < 0.35
	_next_prompt -= delta
	if _prompt == "" and _next_prompt <= 0.0:
		_prompt = "chin" if randf() < 0.55 else "eyes"
		_prompt_t = 1.3 if _prompt == "chin" else 1.6
		_say("Augusta", "Chin." if _prompt == "chin" else "Eyes front. Don't you move.", 1.6)
		if _prompt == "eyes":
			_balance = clampf(_balance + randf_range(-0.25, 0.25), -1.0, 1.0)   # the lure: you want to correct it
	if _prompt != "":
		_prompt_t -= delta
		if _prompt == "chin" and Input.is_action_just_pressed(&"word_up"):
			_grow(0.06)
			hud.pop("Chin up", SceneHud.GREEN)
			_prompt = ""
		elif _prompt == "eyes" and (absf(stick) > 0.3 or _pressed(WORDS) != &""):
			_grow(-0.08)
			hud.pop("You moved", SceneHud.RED)
			_say("Augusta", "I said don't move, darling.", 1.6)
			_prompt = ""
		elif _prompt_t <= 0.0:
			if _prompt == "chin":
				_grow(-0.05)
				hud.pop("Too slow", SceneHud.AMBER)
			else:
				_grow(0.08)
				hud.pop("Perfectly still", SceneHud.GREEN)
			_prompt = ""
		if _prompt == "":
			_next_prompt = randf_range(2.2, 3.6)
	elif good:
		_grow(0.02 * delta)
	hud.kind = "gauge"
	hud.cue = {"chin": "\"Chin.\"", "eyes": "\"Eyes front.\"  Don't move.", "": "Centred. Hold it." if good else "You're tipping."}[_prompt]
	hud.data = {"marker": _balance, "zone": Vector2(0.0, 0.35), "good": good}
	hud.prompts = [[&"stick", "Balance"], [&"word_up", "Chin (when she says)"]]
	_sway()
	if _ph_t >= 22.0:
		if _sis:
			_sis.stop_walk()
			_place(_sis, _other, _frame)
		return true
	return false


func _book_phase(delta: float) -> bool:
	_header("The book", "On your head. Don't you drop it.")
	if _book == null and _rig:
		var head := _rig.head_frame()
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.26, 0.055, 0.19)
		b.mesh = bm
		b.material_override = Look.toon(Color("6a1a24"))
		_book = _rig.wear("head", b, (head.mid as Vector3) + Vector3.UP * float(head.r) * 1.75, head.fwd)
	_drift = lerpf(_drift, randf_range(-1.2, 1.2), delta * 1.1)
	_balance = clampf(_balance + (_drift * 1.0 + Input.get_axis(&"move_left", &"move_right") * 1.7) * delta, -1.0, 1.0)
	var good := absf(_balance) < 0.3
	_grow((0.03 if good else -0.01) * delta)
	if absf(_balance) >= 0.95:
		_grow(-0.1)
		hud.pop("The book!", SceneHud.RED)
		_say("Augusta", "And again. No hurry.", 1.8)
		_balance = 0.0
	hud.kind = "gauge"
	hud.cue = "Steady..." if good else "It's sliding."
	hud.data = {"marker": _balance, "zone": Vector2(0.0, 0.3), "good": good}
	hud.prompts = [[&"stick", "Balance"]]
	_sway()
	return _ph_t >= 14.0


# --- Augusta, Nim leads ------------------------------------------------------------------------------------------------

## Inspect her: nothing captioned. Fix what slips; some of the time nothing has, and she's testing you.
func _inspect(delta: float) -> bool:
	_header("Inspect her", "Watch her.")
	_orbit += Input.get_axis(&"move_left", &"move_right") * delta * 1.4
	if _cam:
		var hall := _cam_home.origin - _frame
		hall.y = 0.0
		var r := hall.length() * 0.75
		var a := atan2(hall.z, hall.x) + _orbit
		_cam_from = _frame + Vector3(cos(a), 0, sin(a)) * r + Vector3.UP * 1.5
		_cam_at = _frame + Vector3.UP * 1.0
	for i in 4:
		_fault_w[i] = move_toward(_fault_w[i], 1.0 if i == _fault else 0.0, delta * 3.0)
	_show_faults()
	if _rig and _test:
		_rig.turn("head", Vector3.UP, sin(_ph_t * 1.5) * 0.4)   # a glance: is she watching you watch her?
	if _fault < 0 and not _test:
		_gap -= delta
		if _gap <= 0.0:
			_test = randf() < 0.25
			_fault = -1 if _test else randi() % FAULTS.size()
			_fault_t = FAULT_SECS + 0.6
	else:
		_fault_t -= delta
		var a := _pressed(WORDS)
		if _test:
			if a != &"":
				_grow(-0.07)
				hud.pop("Nothing was wrong", SceneHud.AMBER)
				_say("Augusta", "Nothing was wrong, darling. You fixed thin air.", 2.0)
				_end_fault()
			elif _fault_t <= 0.0:
				_grow(0.1)
				hud.pop("She was testing you", SceneHud.GREEN)
				_say("Augusta", "...Good. Nothing was wrong. You noticed that, too.", 2.2)
				_end_fault()
		elif a == FAULTS[_fault][1]:
			_grow(0.08)
			hud.pop("Fixed", SceneHud.GREEN)
			_say("Nim", FAULTS[_fault][2], 1.4)
			_hand_at = _fault_point(_fault)
			_hand_t = 1.1
			_end_fault()
		elif a != &"" or _fault_t <= 0.0:
			_grow(-0.05)
			hud.pop("Missed it", SceneHud.AMBER)
			_end_fault()
	_hand_t -= delta
	if _hand_t > 0.0:
		_reach = _hand_at   # her hand on the part she's put right
	hud.kind = "pads"
	hud.cue = "Watch her."
	hud.data = {"up": ["Chin up", SceneHud.CREAM], "down": ["Shoulders down", SceneHud.CREAM], "right": ["Hands still", SceneHud.CREAM],
		"left": ["Feet together", SceneHud.CREAM], "hot": "", "timer": -1.0}
	hud.prompts = [[&"stick", "Walk round her"], [&"word_up", "Correct her"]]
	return _faults_done >= CORRECTIONS


func _end_fault() -> void:
	_faults_done += 1
	_fault = -1
	_test = false
	_gap = 0.9


## Where Nim's hand goes to correct a fault: her chin, her shoulder, her hands, her knee.
func _fault_point(i: int) -> Vector3:
	if _rig == null:
		return Vector3.INF
	return [_rig.pos("head") + _rig.fwd() * 0.12, _rig.pos("shoulderR"), _rig.pos("handR"), _rig.pos("shinR")][i]


# --- the end -----------------------------------------------------------------------------------------------------------

func _finish_scene() -> void:
	# Standing again before the untie (a kneel is let go here, not by the base's raise).
	if _kneel_drop > 0.0:
		_nim.global_position.y += _kneel_drop
		_kneel_drop = 0.0
	if _sis:
		_sis.stop_walk()
	_end({"ok": feel >= 0.35, "stopped": false, "feel": feel})


## Act 3: aftercare you take part in, then her lines (hub/sessions.dialogue), and back to the room.
func _after() -> void:
	await get_tree().create_timer(0.8).timeout
	await hud.fade(true)
	if is_instance_valid(_crop):
		var holder := _crop.get_parent()
		(holder if holder is BoneAttachment3D else _crop).queue_free()
	for r: RigGear in [_rig, _top_rig]:
		if r:
			r.clear()
	for m in _held:
		if is_instance_valid(m):
			m.call(&"hold", false)
	# Up off their knees (or the throne), onto the floor.
	for l: Array in _lowered:
		var body: Node3D = l[0]
		if is_instance_valid(body):
			body.global_position.y += float(l[1])
			if body == _nim and sister == "grizelda" and mode == &"domme":
				body.global_position += -body.global_basis.z * 0.3   # (a step forward, off the throne's seat)
			if body.has_method(&"reset_physics_interpolation"):
				body.reset_physics_interpolation()
	_lowered = []
	for l in _lines:
		if is_instance_valid(l):
			l.queue_free()
	hud.blind = 0.0
	if is_instance_valid(_bell_node):
		_bell_node.queue_free()   # (off its bone, if it was dropped; with the rig's gear, if not)
	hud.headspace = 0.0
	hud.meters = []
	_cam_from = Vector3.INF
	if _cam and _cam_home != Transform3D():
		_cam.global_transform = _cam_home
		_cam.fov = 55.0
	await hud.fade(false)
	if not _result.get("declined", false):
		await _care()
	await hud.fade(true)
	if _sis and not _sub_is_nim():
		_sis.dress("suit")
	await hud.fade(false)
	if _result.ok and not _result.get("declined", false):
		Game.earn_rose(&"hub", &"hub_09")
		Game.set_flag("bond/%s" % sister, int(Game.get_flag("bond/%s" % sister, 0)) + 1)
	if not _result.get("declined", false):
		var label := "%s_%s_%s" % [sister, mode, "red" if _result.stopped else "after"]
		await Dialogue.run("res://data/dialogue/hub/sessions.dialogue", label)
	_name_tags(true)
	if _was_cam and is_instance_valid(_was_cam):
		_was_cam.make_current()
	if _cam:
		_cam.queue_free()
	_nim.set_physics_process(true)
	Hud.show_world_ui(true)
	finished.emit(_result)


## Two things done for her (or for Nim, by her: when Nim was the sub, she chooses what she'd like).
func _care() -> void:
	stage = "care"
	hud.title = "Aftercare"
	hud.subtitle = "What she needs" if not _sub_is_nim() else "What you'd like"
	hud.word = ""
	var lines: Dictionary = _care_lines()
	var acts := {&"word_up": "water", &"word_right": "blanket", &"word_down": "words", &"word_left": "close"}
	var labels := {"water": "Water", "blanket": "A blanket", "words": "Words", "close": "Sit close"}
	_care_done = []
	while _care_done.size() < 2:
		var data := {"hot": "", "timer": -1.0}
		for a: StringName in acts:
			var what: String = acts[a]
			data[String(a).trim_prefix("word_")] = [labels[what], SceneHud.DIM if what in _care_done else SceneHud.CREAM]
		hud.kind = "pads"
		hud.cue = "Take care of her." if not _sub_is_nim() else "She asks what you'd like."
		hud.data = data
		hud.prompts = [[&"word_up", "Choose"]]
		await get_tree().process_frame
		var p := _pressed(acts.keys())
		if p != &"" and not acts[p] in _care_done:
			_care_done.append(acts[p])
			if _sub_is_nim():
				_say(sister.capitalize(), {"water": "Here. Sip.", "blanket": "There. Warm?", "words": "You were wonderful. I mean it.",
					"close": "Come here."}[acts[p]], 2.4)
			else:
				_say("Nim", {"water": "Here. Water.", "blanket": "Blanket. Come here.", "words": "You were lovely. Thank you.",
					"close": "I'm here."}[acts[p]], 1.8)
				await get_tree().create_timer(1.0).timeout
				_say(sister.capitalize(), lines[acts[p]], 2.6)
			await get_tree().create_timer(1.6).timeout
	hud.kind = ""


## What input is right just now, for the probes: {"tap": action} / {"hold": action, "on": bool} / {"stick": x}.
func hint() -> Dictionary:
	match stage:
		"form", "intro":
			return {"tap": &"jump"}
		"colour":
			return {"tap": &"word_up"}
		"care":
			for a: StringName in [&"word_up", &"word_right", &"word_down", &"word_left"]:
				var acts := {&"word_up": "water", &"word_right": "blanket", &"word_down": "words", &"word_left": "close"}
				if not acts[a] in _care_done:
					return {"tap": a}
	match phase:
		"offer":
			var asks: Array = OFFERS[picks.get("tie", "wrists")]
			return {"tap": asks[mini(_ask, asks.size() - 1)][0]} if _ask_t < 2.6 else {}
		"breathe":
			return {"hold": &"jump", "on": fmod(_ph_t, BREATH) / BREATH < 0.5}
		"line":
			return {"hold": &"jump", "on": fmod(_ph_t, BREATH) / BREATH < 0.5, "stick": clampf(-_balance * 3.0 - _drift * 0.5, -1.0, 1.0)}
		"release":
			return {"tap": &"word_left" if _wiggles % 2 == 0 else &"word_right"}
		"tie":
			return {"tap": _seq[_seq_i]} if not _seq.is_empty() else {}
		"hands":
			return {"tap": {"L": &"word_left", "R": &"word_right", "": &"word_up"}[_tight]} if _ph_t > 0.6 else {}
		"check":
			return {"tap": &"interact"}
		"sit":
			return {"tap": &"interact"} if fmod(_ph_t, 4.4) / 4.4 > 0.6 and fmod(_ph_t, 1.0) < 0.05 else {}
		"positions":
			var p: Array = POSITIONS[ORDER[mini(_ask, ORDER.size() - 1)]]
			return {"tap": p[0]} if _ask_t < 2.4 and _prompt == String(p[2]) else {}
		"hold":
			if _prompt == "chin":
				return {"tap": &"word_up"}
			if _prompt == "eyes":
				return {"stick": 0.0}
			return {"stick": clampf(-_balance * 3.0 - _drift * 0.5, -1.0, 1.0)}
		"book":
			return {"stick": clampf(-_balance * 3.0 - _drift * 0.6, -1.0, 1.0)}
		"inspect":
			if _test or _fault < 0:
				return {}
			return {"tap": FAULTS[_fault][1]} if _fault_t < FAULT_SECS else {}
	return {}
