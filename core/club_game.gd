extends Node
## The sisters' scenes, in their own rooms (WO-014b, DESIGN.md "The Velvet Claw's house"; the owner: "allow yourself
## to Switch... the option to Domme a sister too"). Content lines: suggestive, clothed (swimwear at most),
## consensual: each opens with a check-in in its conversation, "red" always ends it well, aftercare after.
##
## Played on SceneHud's widgets and staged on the bodies (owner, Deck review 3: the text-and-timing version was
## "hard to play", and Nim's "binding" was crude rings round her middle, clipping):
##   silke switch: Silke ties Nim to the rope frame (wrists overhead to its beam, a chest harness). Breathe with her:
##     hold A to breathe in, let go to breathe out, keeping your ring on hers; keep the stick still. Her colour
##     question comes halfway (the D-pad: up green, right yellow, down red); hold B for red any time.
##   silke domme: Nim ties Silke: each knot a short D-pad sequence, and each one you finish goes on her (wrists, the
##     line to the beam, the harness, the ankles). Y checks in on her; she wants asking, halfway.
##   augusta switch: Nim holds a posture (hands behind her back) while it drifts: keep the needle in the green with
##     the stick, and her body sways with it.
##   augusta domme: Augusta holds the posture and gets it wrong, on her body (a dropped chin, shoulders up, fidgeting
##     hands, her weight on one foot); the D-pad corrects it. Y checks in.
##   grizelda switch: Grizelda on her throne, Nim kneeling at her boots: polish them. Circle the stick at the right
##     speed (the needle) and each spot comes up gleaming; she calls the next boot.
##   grizelda domme: Nim on the throne, Grizelda kneeling and defiant. Her will swings like a needle; say the word (A)
##     as it comes into the green and she obeys, a little more each time. Y checks in.
##   lull switch: blindfolded in the Quiet Room, Lull counts, slowly. A on each count, the stick still.
##   lull domme: Lull blindfolded, "I like not knowing where you'll be": the D-pad picks where Nim's hand goes next.
##     Don't repeat yourself, and don't rush; the pause is half of it.
##   dash switch: Dash's drill at her punch bag: she calls a direction, you hit it on the D-pad before the bar runs out.
##     It gets faster.
##   dash domme: hold Dash still while she wriggles (the needle). If she gets loose, A catches her.
##   rivet switch: Rivet fits her cuffs on Nim. The strap slides through its notches: A when it's snug, not tight.
##   rivet domme: Nim buckles Rivet's cuffs: line the strap up with the stick, A to fasten, then Y to check it, every
##     buckle ("I made them, so I'll know").
## A sister who's the sub changes into her swimwear for it, and back into her suit after (owner, Deck review 3).
## OWNER REVIEW: every line here.
## Emits finished({"ok", "stopped", "pushed", "mode", "sister"}); club_life frees it.

signal finished(result: Dictionary)

const SCENE_SECS := 30.0
const SAFEWORD_HOLD := 0.6
const KNOTS := 6
const CORRECTIONS := 8
const FAULT_SECS := 2.4
const BREATH := 5.0

## Who and what: set before it's added.
var hub: Node3D
var sister := ""
var mode: StringName = &"switch"

## Where it's at, for the HUD and the probes: "setup", "play", "colour" (she's asked), "done".
var stage := "setup"
var hud: SceneHud

var _nim: Node3D
var _held_here := false
var _sis: Talker
var _rig: RigGear        # the one tied or holding the posture
var _cam: Camera3D
var _was_cam: Camera3D
var _lines: Array[MeshInstance3D] = []
var _beam_y := 0.0
var _frame := Vector3.ZERO
var _t := 0.0
var _done := false
var _result := {}
var _score := 0.0
var _asked := false
var _check_t := 0.0
var _safe_t := 0.0
# breath
var _mine := 0.0
var _her := 0.0
# posture
var _balance := 0.0
var _drift := 0.0
# knots
var _seq: Array = []
var _seq_i := 0
var _knots := 0
# corrections
var _fault := -1
var _fault_t := 0.0
var _gap := 0.0
var _faults_done := 0
var _fault_w := [0.0, 0.0, 0.0, 0.0]
# the four later scenes
var _top_rig: RigGear     # the one leading, when they're posed too (seated, reaching)
var _reach := Vector3.INF
var _lowered: Array = []  # [body, how far] for those kneeling or seated, raised again after
var _count := 0           # done so far (spots, commands, counts, touches, calls, buckles)
var _phase_t := 0.0
var _angle := 0.0
var _spin := 0.0
var _boot := 0
var _shine := 0.0
var _will := 0.0
var _last_pick: Array[StringName] = []
var _since := 0.0
var _call: StringName = &""
var _call_t := 0.0
var _call_len := 1.4
var _loose := false
var _loose_t := 0.0
var _notch := 0.0
var _notch_dir := 1.0
var _target := 0.0
var _fastened := false
var _checked := 0
var _squirm := 0.0
var _jab_t := 0.0
var _held: Array[Node] = []   # the models held still for posing, let go after

## Each scene's title and how it goes, shown before it starts. OWNER REVIEW.
const INTROS := {
	"switch_silke": ["The rope frame", ["Silke ties your wrists up to the frame.", "Breathe with her: hold A to breathe in, let go to breathe out. Keep your ring on hers.",
		"Keep the stick still. She'll ask your colour halfway.", "Hold B any time: your word, and it stops."]],
	"domme_silke": ["You tie Silke", ["Each knot is four presses on the D-pad, in order. Each one you finish goes on her.",
		"Halfway, ask how she's doing: Y."]],
	"switch_augusta": ["Augusta's posture", ["Hands behind you, chin up. The pose drifts; lean it back with the stick.",
		"Keep the needle in the green. She'll ask your colour halfway.", "Hold B any time: your word."]],
	"domme_augusta": ["Correct Augusta's posture", ["She'll slip: chin, shoulders, hands, feet. Watch her.",
		"Fix it on the D-pad before the bar runs out: up chin, down shoulders, right hands, left feet.", "Halfway, ask how she is: Y."]],
	"switch_grizelda": ["Grizelda's boots", ["Kneel at her throne and polish. Circle the stick, steadily: the needle is your speed.",
		"In the green, the shine comes up. She'll tell you which boot.", "Hold B any time: your word."]],
	"domme_grizelda": ["The throne", ["Grizelda kneels; she won't make it easy. Her will swings like a needle.",
		"Say each order (A) as it comes into the green.", "Halfway, ask how she is: Y."]],
	"switch_lull": ["Lull counts", ["Blindfolded. She counts, slowly.", "Press A on each of her counts, and keep the stick still.",
		"Hold B any time: your word."]],
	"domme_lull": ["Where next", ["Lull's blindfolded. Pick where your hand goes with the D-pad.",
		"Never the same place twice, and never in a hurry: the waiting is half of it.", "Halfway, ask how she is: Y."]],
	"switch_dash": ["Dash's drill", ["She calls a direction. Hit it on the D-pad before the bar runs out.", "It gets faster.",
		"Hold B any time: your word."]],
	"domme_dash": ["Hold on to Dash", ["She wriggles. Lean against her with the stick to keep the needle in the green.",
		"If she slips loose, A catches her.", "Halfway, ask how she is: Y."]],
	"switch_rivet": ["Rivet's fitting", ["She's made you cuffs. Watch the strap tighten as it slides through its holes.",
		"Press A when it's snug: in the green. Not loose, not tight.", "Hold B any time: your word."]],
	"domme_rivet": ["Rivet's buckles", ["Line the strap up with its hole using the stick, and A fastens it.",
		"Then check it: Y. Every buckle. She made them, so she'll know."]],
}
## The ones that get a practice first (a feel for the timing; it doesn't count), and how long.
const PRACTICE := ["switch_silke", "switch_augusta", "switch_grizelda", "switch_lull", "domme_dash"]
const PRACTICE_SECS := 8.0
var _practice_t := 0.0

const FAULTS := [["Her chin's dropped.", &"word_up", "Chin up."], ["Her shoulders have crept up.", &"word_down", "Shoulders down."],
	["Her hands are fidgeting.", &"word_right", "Hands still."], ["Her weight's on one foot.", &"word_left", "Feet together."]]
const WORDS: Array[StringName] = [&"word_up", &"word_right", &"word_down", &"word_left"]


func _ready() -> void:
	_nim = hub.get(&"nim")
	_nim.set_physics_process(false)
	_nim.set(&"velocity", Vector3.ZERO)
	# (Not airborne: with her body stopped, her model played the fall until something posed her.)
	var nm: Node = _nim.get(&"model")
	if nm and not bool(nm.get(&"held")):
		nm.call(&"hold", true)
		_held_here = true
	_sis = hub.get_node_or_null(NodePath(sister.capitalize())) as Talker
	hud = SceneHud.new()
	add_child(hud)
	Hud.show_world_ui(false)
	_run.call_deferred()


func _sub_is_nim() -> bool:
	return mode == &"switch"


func _run() -> void:
	await hud.fade(true)
	_stage_bodies()
	await hud.fade(false)
	# How it works, then A to begin (owner, Deck review 5: they "jump right into the mini-game").
	var key := "%s_%s" % [mode, sister]
	stage = "intro"
	hud.title = INTROS.get(key, ["", []])[0]
	hud.subtitle = "How it goes"
	hud.word = "\"red\"" if mode == &"switch" else "her word: \"red\""
	hud.kind = "intro"
	hud.cue = ""
	hud.data = {"lines": INTROS.get(key, ["", []])[1]}
	hud.prompts = [[&"jump", "Begin"]]
	await get_tree().process_frame
	while not Input.is_action_just_pressed(&"jump"):
		await get_tree().process_frame
	_say(sister.capitalize(), "Ready when you are." if mode == &"switch" else "Go on, then.")
	_check_t = SCENE_SECS * 0.5
	if key in PRACTICE:
		_practice_t = PRACTICE_SECS
		_check_t = INF
	stage = "play"
	if mode == &"domme" and sister == "silke":
		_new_knot()
	if mode == &"domme" and sister == "rivet":
		_asked = true   # checking every buckle is her check-in
	_target = randf_range(-0.4, 0.4)


# --- staging -----------------------------------------------------------------------------------------------------------

func _room() -> Dictionary:
	for r: Dictionary in Hub.ROOMS:
		if String(r.sister).to_lower() == sister:
			return r
	return Hub.ROOMS[0]


## Both into place in her room, the sub posed and tied, a camera on them.
func _stage_bodies() -> void:
	var r := _room()
	var at: Vector3 = r.at
	var side := signf(at.x)
	var hall := Vector3(-side, 0, 0)
	var sub: Node3D = _nim if _sub_is_nim() else _sis
	var top: Node3D = _sis if _sub_is_nim() else _nim
	if not _sub_is_nim() and _sis:
		_sis.dress("swim")   # the sub's in her swimwear (owner, Deck review 3)
	elif _sub_is_nim():
		_nim_swim(true)      # and so is Nim, when it's her (her two-piece)
	_name_tags(false)
	_was_cam = get_viewport().get_camera_3d()
	if sister in ["grizelda", "lull", "dash", "rivet"]:
		_stage_later(r, sub, top)
		_clear_room(r)
		return
	# Silke's: in the rope frame (against the outer wall, facing the hall); Augusta's: in the room's middle.
	_frame = Vector3(side * 9.4, at.y, at.z) if sister == "silke" else at + Vector3(side * 0.9, 0, 0)
	var other := _frame + hall * 1.35 + Vector3(0, 0, 0.7 if sister == "silke" else -0.8)
	_place(sub, _frame, _frame + hall)
	_place(top, other, _frame + Vector3(0, 0, 0))
	var sub_model := _model_of(sub)
	if sub_model:
		sub_model.call(&"hold", true)
		_held.append(sub_model)
		var sk: Skeleton3D = sub_model.call(&"skeleton")
		if sk:
			_rig = RigGear.new(sk, sub)
			if sister == "silke":
				_rig.pose_arms_up()
			else:
				_rig.pose_hands_behind()
			_rig.capture()
			if sister == "silke" and mode == &"switch":
				for k in 4:
					_tie(k)   # she's tied before the scene opens: the breathing is the scene
	# The camera: from the hall side, three-quarters on, both in the shot. Looking a little low, so the bodies sit in
	# the top of the frame, clear of the panel.
	var cz := -2.0 if sister == "silke" else 1.9
	_camera(_frame + hall * 3.6 + Vector3(0, 1.62, cz), _frame + hall * 0.7 + Vector3(0, 0.62, -cz * 0.12))
	_clear_room(r)


func _camera(from: Vector3, at: Vector3) -> void:
	_cam = Camera3D.new()
	_cam.fov = 55.0
	hub.add_child(_cam)
	_cam.global_position = from
	_cam.look_at(at, Vector3.UP)
	_cam.make_current()
	_cam_home = _cam.global_transform


## The scene's opening shot, to come back to for aftercare.
var _cam_home := Transform3D()


## A client in her room for a session steps out to aftercare (while it's black). In the Quiet Room, nobody's moved:
## they're on their own seats, out of the way.
func _clear_room(r: Dictionary) -> void:
	if r.id == &"quiet":
		return
	var life := get_parent()
	for c: Node in get_tree().get_nodes_in_group(&"club_client"):
		if Hub.room_at((c as Node3D).global_position) == r and life.has_method(&"_to_aftercare"):
			life.call(&"_to_aftercare", c, true)


## Grizelda's, Lull's, Dash's and Rivet's scenes: where each stands (or sits, or kneels), and the camera.
func _stage_later(r: Dictionary, sub: Node3D, top: Node3D) -> void:
	var at: Vector3 = r.at
	var side := signf(at.x)
	var hall := Vector3(-side, 0, 0)
	var y := Vector3(0, at.y, 0)
	match sister:
		"grizelda":
			# The throne against the outer wall, facing the hall: the one leading sits on it, the other kneels before.
			var throne := Vector3(side * 10.8, at.y, at.z)
			var seat := throne + hall * 0.2
			# The one on the throne has her feet up on its footstool, so her boots are in plain view; the one kneeling
			# is to the side of them, not in front (owner, Deck review 5: "the boots are occluded by the foot rest").
			var kneel := throne + hall * 1.2 + Vector3(0, 0, 0.62)
			_frame = kneel
			_place(top, seat, seat + hall)
			_place(sub, kneel, throne + hall * 1.0)
			_top_rig = _pose(top, "sit_up")
			_rig = _pose(sub, "kneel")
			# From the other side, a little low: the boots, her, and the one at her feet.
			_camera(throne + hall * 2.4 + Vector3(0, 1.3, -1.8), throne + hall * 0.95 + Vector3(0, 0.3, 0.25))
		"lull":
			# By the door end of the Quiet Room, clear of the seats, seen from the side.
			var p := Vector3(8.8, 0, -52.3) + y
			var o := Vector3(9.4, 0, -51.3) + y
			_frame = p
			_place(sub, p, o)
			_place(top, o, p)
			_rig = _pose(sub, "stand")
			_top_rig = _pose(top, "stand")
			_blindfold(_rig)
			_camera(Vector3(12.6, 1.6, -53.6) + y, Vector3(9.1, 0.6, -51.8) + y)
		"dash":
			var bag := at + Vector3(side * 2.0, 0, 1.6)
			if mode == &"switch":
				# Nim at the bag, Dash calling it beside her.
				var p := bag + hall * 1.5 + Vector3(0, 0, -0.1)
				_frame = p
				_place(sub, p, bag)
				_place(top, p + hall * 0.5 + Vector3(0, 0, -1.3), p)
				_rig = _pose(sub, "stand")
			else:
				# Dash held: her hands behind her, Nim behind her holding them.
				var p := at + Vector3(side * 1.0, 0, -0.3)
				_frame = p
				_place(sub, p, p + hall)
				_place(top, p - hall * 0.55, p + hall)
				_rig = _pose(sub, "behind")
				_top_rig = _pose(top, "stand")
			_camera(at + hall * 3.0 + Vector3(0, 1.6, 1.6), _frame + hall * 0.4 + Vector3(0, 0.6, 0.0))
		"rivet":
			# In front of her bench: the one being fitted offers her wrists; Rivet (or Nim) faces her.
			# Facing each other across the room's width, the camera from the hall side: neither hides the other.
			var p := at + Vector3(side * 0.5, 0, -0.5)
			var o := p + hall * 0.35 + Vector3(0, 0, 0.8)
			_frame = p
			_place(sub, p, o)
			_place(top, o, p)
			_rig = _pose(sub, "wrists")
			_top_rig = _pose(top, "stand")
			_camera(at + hall * 3.2 + Vector3(0, 1.6, -0.4), (p + o) / 2.0 + Vector3(0, 0.6, 0))


## Holds a body and poses it ("sit", "kneel", "stand", "behind", "wrists"), lowering it when it sits or kneels.
func _pose(body: Node3D, how: String) -> RigGear:
	var m := _model_of(body)
	if m == null:
		return null
	m.call(&"hold", true)
	_held.append(m)
	var sk: Skeleton3D = m.call(&"skeleton")
	if sk == null:
		return null
	var rig := RigGear.new(sk, body)
	var drop := 0.0
	match how:
		"sit":
			drop = rig.pose_sit()
		"sit_up":
			drop = rig.pose_sit(0.85)
		"kneel":
			drop = rig.pose_kneel()
			rig.pose_hands_behind()
		"behind":
			rig.pose_hands_behind()
		"wrists":
			rig.pose_wrists_out()
	if drop > 0.0:
		body.global_position.y -= drop
		_lowered.append([body, drop])
		if body.has_method(&"reset_physics_interpolation"):
			body.reset_physics_interpolation()
	rig.capture()
	return rig


func _blindfold(rig: RigGear) -> void:
	if rig == null:
		return
	var head := rig.head_frame()
	rig.wear("head", RigGear.oval(head.r * 1.3, head.reach * 0.72, 0.075, RigGear.LEATHER),
		head.eyes - head.fwd * head.reach * 0.55, head.fwd)


func _place(who: Node3D, at: Vector3, face: Vector3) -> void:
	if who == null:
		return
	if who is Talker:
		(who as Talker).stop_walk()
	who.global_position = at + Vector3(0, 0.02, 0)
	var d := face - at
	who.rotation.y = atan2(-d.x, -d.z)
	if who.has_method(&"reset_physics_interpolation"):
		who.reset_physics_interpolation()


func _model_of(body: Node3D) -> Node:
	return body.get(&"model") if body else null


## The rope on Silke's frame, a piece at a time (in the Domme scene, one per knot finished): wrists, the line up to the
## beam, the chest harness, the ankles.
func _tie(k: int) -> void:
	if _rig == null:
		return
	var fl := (_rig.pos("handL") - _rig.pos("forearmL")).length()
	var fr := (_rig.pos("handR") - _rig.pos("forearmR")).length()
	match k:
		0:
			_rig.wrap("forearmL", 0.042, fl * 0.86)
			_rig.wrap("forearmR", 0.042, fr * 0.86)
		1:
			_beam_y = _frame.y + 2.52
			var wrists := (_rig.pos("handL") + _rig.pos("handR")) / 2.0
			var line := RigGear.line_between(Vector3.ZERO, Vector3.UP, 0.012, Look.toon(RigGear.ROPE, 0.15))
			hub.add_child(line)
			RigGear.set_line(line, wrists, Vector3(wrists.x, _beam_y, wrists.z))
			_lines.append(line)
		2:
			_rig.harness()
		3:
			var sl := (_rig.pos("footL") - _rig.pos("shinL")).length()
			_rig.wrap("shinL", 0.05, sl * 0.8, 2)
			_rig.wrap("shinR", 0.05, sl * 0.8, 2)


## Nim's two-piece on or off (NimModel.wear_swim), during a fade.
func _nim_swim(on: bool) -> void:
	var m: Node = _nim.get(&"model")
	if m and m.has_method(&"wear_swim"):
		m.call(&"wear_swim", on)


func _name_tags(on: bool) -> void:
	if _sis:
		for c in _sis.get_children():
			if c is Label3D:
				(c as Label3D).visible = on


# --- each frame --------------------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _done or stage == "setup" or stage == "intro":
		return
	_t += delta
	if _practice_t > 0.0:
		_practice_t -= delta
		if _practice_t <= 0.0:
			_start_for_real()
	if _rig:
		_rig.restore()
	if _top_rig:
		_top_rig.restore()
	_reach = Vector3.INF
	if _safeword(delta):
		return
	match "%s_%s" % [mode, sister]:
		"switch_silke":
			_breathe(delta)
		"switch_augusta":
			_posture(delta)
		"domme_silke":
			_knots_game(delta)
		"domme_augusta":
			_corrections(delta)
		"switch_grizelda":
			_boots(delta)
		"domme_grizelda":
			_will_game(delta)
		"switch_lull":
			_counting(delta)
		"domme_lull":
			_where_next(delta)
		"switch_dash":
			_drill(delta)
		"domme_dash":
			_hold_dash(delta)
		"switch_rivet":
			_fitting(delta)
		"domme_rivet":
			_buckles(delta)
	# The hand that does the work: Nim's at Grizelda's boots and at Dash's bag; otherwise the leader's.
	var hand := _rig if (mode == &"switch" and sister in ["grizelda", "dash"]) else _top_rig
	if hand and _reach != Vector3.INF:
		hand.reach(_reach)
	if _practice_t > 0.0:
		hud.subtitle = "Practice: get the feel. It counts in %d." % ceili(_practice_t)
	_follow_cam(delta)


## The practice is over: the scene starts properly, from nothing (its clock, its score, its count).
func _start_for_real() -> void:
	_practice_t = 0.0
	_t = 0.0
	_score = 0.0
	_count = 0
	_shine = 0.0
	_scored = -1
	_mine = 0.0
	_balance = 0.0
	_drift = 0.0
	_loose = false
	_asked = false
	_check_t = SCENE_SECS * 0.5
	hud.pop("Now for real", SceneHud.GOLD)
	_say(sister.capitalize(), "Good. Now, properly.", 2.0)


## Hold B: red, from the one tied, any time. It stops everything, and that's never wrong.
func _safeword(delta: float) -> bool:
	if mode != &"switch":
		hud.safeword_hold = -1.0
		return false
	_safe_t = _safe_t + delta if Input.is_action_pressed(&"crouch") else 0.0
	hud.safeword_hold = clampf(_safe_t / SAFEWORD_HOLD, 0.0, 1.0)
	if _safe_t >= SAFEWORD_HOLD:
		_say("Nim", "Red.")
		_say(sister.capitalize(), "Red. Good. You said it, I heard it. I've got you.")
		_end({"ok": true, "stopped": true})
		return true
	return false


func _header(title: String, sub: String) -> void:
	hud.title = title
	hud.subtitle = sub
	hud.word = "\"red\""


## Halfway, the check-in: in a Switch she asks you (up green, right yellow, down red); in a Domme you ask her (Y).
## True while it holds the game.
func _check_in(delta: float) -> bool:
	if _asked:
		return false
	_check_t -= delta
	if _check_t > 0.0:
		return false
	if mode == &"switch":
		if stage != "colour":
			stage = "colour"
			_say(sister.capitalize(), "Colour?")
		hud.kind = "pads"
		hud.cue = "%s asks your colour." % sister.capitalize()
		hud.data = {"up": ["Green", SceneHud.GREEN], "right": ["Yellow", SceneHud.AMBER], "down": ["Red", SceneHud.RED],
			"hot": "", "timer": -1.0}
		hud.prompts = [[&"word_up", "Green"], [&"word_right", "Yellow"], [&"word_down", "Red"]]
		var a := _pressed([&"word_up", &"word_right", &"word_down"])
		if a == &"":
			return true
		_asked = true
		stage = "play"
		match a:
			&"word_up":
				_say("Nim", "Green.")
				_say(sister.capitalize(), "Good. Stay with me.")
			&"word_right":
				_say("Nim", "Yellow.")
				_say(sister.capitalize(), "Yellow. I'll ease off. Thank you for telling me.")
				_score += 0.1
			&"word_down":
				_say("Nim", "Red.")
				_end({"ok": true, "stopped": true})
				return true
		return false
	# Domme: she's waiting to be asked.
	if Input.is_action_just_pressed(&"interact"):
		_asked = true
		_say("Nim", "How are you doing?")
		_say(sister.capitalize(), "Green. ...Thank you for asking.")
		hud.pop("Checked in", SceneHud.GREEN)
		_score += 0.15
		return false
	if _check_t < -4.0:
		_asked = true
		_say(sister.capitalize(), "You forgot to ask me how I was. Ask, next time. Always.")
		hud.pop("Forgot to ask", SceneHud.RED)
		_score -= 0.15
	return false


## The Domme's Y prompt, lit once she's due a check-in.
func _domme_prompts(base: Array) -> Array:
	var p := base.duplicate()
	if not _asked:
		p.append([&"interact", "Check in" if _check_t > 0.0 else "Check in  (she's waiting)"])
	return p


func _breathe(delta: float) -> void:
	_header("The rope frame", "Silke ties you. Breathe with her.")
	hud.meters = [{"name": "With her", "value": clampf(_score * 1.4, 0.0, 1.0), "colour": SceneHud.ROSE}]
	if _check_in(delta):
		_breath_pose()
		return
	var cycle := fmod(_t, BREATH) / BREATH
	_her = 0.5 - 0.5 * cos(cycle * TAU)
	var holding := Input.is_action_pressed(&"jump")
	_mine = clampf(_mine + (1.0 if holding else -1.0) * delta / (BREATH * 0.5), 0.0, 1.0)
	var still := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down").length() < 0.3
	var sync := absf(_mine - _her) < 0.2 and still
	if sync:
		_score += delta / SCENE_SECS
	elif not still and randf() < delta * 0.6:
		_say("Silke", "Easy. I've got you.", 2.0)
	hud.kind = "ring"
	hud.cue = "Still, now." if not still else ("Breathe in..." if cycle < 0.5 else "...and out.")
	hud.data = {"target": _her, "mine": _mine, "sync": sync, "label": "IN" if cycle < 0.5 else "OUT", "hers": "Silke's"}
	hud.prompts = [[&"jump", "Hold to breathe in"], [&"stick", "Keep still"]]
	_breath_pose()
	if _t >= SCENE_SECS:
		_end({"ok": true, "stopped": false})


## Her chest rises with her own breath, a little.
func _breath_pose() -> void:
	if _rig:
		_rig.turn("chest", _rig.left(), -0.07 * _mine)
		_rig.turn("head", _rig.left(), -0.05 * _mine)


func _posture(delta: float) -> void:
	_header("Augusta's posture", "Hold it for her. Hands behind you, chin up.")
	hud.meters = [{"name": "Poise", "value": clampf(_score * 1.4, 0.0, 1.0), "colour": SceneHud.GOLD}]
	if _check_in(delta):
		_sway()
		return
	_drift = lerpf(_drift, randf_range(-1.0, 1.0), delta * 0.8)
	_balance += (_drift * 0.9 + Input.get_axis(&"move_left", &"move_right") * 1.6) * delta
	_balance = clampf(_balance, -1.0, 1.0)
	var good := absf(_balance) < 0.35
	if good:
		_score += delta / SCENE_SECS
	elif absf(_balance) > 0.9 and randf() < delta * 0.5:
		_say("Augusta", "And again. No hurry. You're doing beautifully.", 2.5)
	hud.kind = "gauge"
	hud.cue = "Centred. Hold it." if good else ("You're tipping left." if _balance < 0.0 else "You're tipping right.")
	hud.data = {"marker": _balance, "zone": Vector2(0.0, 0.35), "good": good, "left": "", "right": ""}
	hud.prompts = [[&"stick", "Lean back to the middle"]]
	_sway()
	if _t >= SCENE_SECS:
		_end({"ok": true, "stopped": false})


## Her body sways with the balance: hips one way, chest catching it.
func _sway() -> void:
	if _rig == null:
		return
	var f := _rig.fwd()
	_rig.turn("hips", f, -_balance * 0.2)
	_rig.turn("chest", f, _balance * 0.12)
	_rig.turn("head", _rig.left(), -0.08)


func _new_knot() -> void:
	_seq = []
	for i in 4:
		_seq.append(WORDS[randi() % 4])
	_seq_i = 0


func _knots_game(delta: float) -> void:
	_header("You tie Silke", "Knot by knot. She'll tell you if it's wrong.")
	hud.word = "her word: \"red\""
	hud.meters = [{"name": "Her trust", "value": clampf(_score, 0.0, 1.0), "colour": SceneHud.ROSE}]
	_check_in(delta)
	if _done:
		return
	var a := _pressed(WORDS)
	if a != &"":
		if a == _seq[_seq_i]:
			_seq_i += 1
			if _seq_i >= _seq.size():
				_tie(_knots % 4)
				_knots += 1
				_score += 0.12
				hud.pop("Knot %d" % _knots, SceneHud.GOLD)
				_say("Silke", ["Neat.", "Mm. Firm, not tight. Good.", "You've been practising."][_knots % 3], 2.0)
				if _knots >= KNOTS:
					_end({"ok": true, "stopped": false})
					return
				_new_knot()
		else:
			hud.pop("Wrong way", SceneHud.RED)
			_say("Silke", "Other way. ...I can see it from here.", 2.0)
			_seq_i = 0
	hud.kind = "steps"
	hud.cue = "Knot %d of %d" % [mini(_knots + 1, KNOTS), KNOTS] if _asked or _check_t > 0.0 else "She glances at you. Ask how she is."
	hud.data = {"seq": _seq, "at": _seq_i, "knot": _knots, "of": KNOTS}
	hud.prompts = _domme_prompts([[&"word_up", "The D-pad, in order"]])


func _corrections(delta: float) -> void:
	_header("Correct Augusta's posture", "Watch her. Fix what slips.")
	hud.word = "her word: \"red\""
	hud.meters = [{"name": "Approval", "value": clampf(_score, 0.0, 1.0), "colour": SceneHud.GOLD}]
	_check_in(delta)
	if _done:
		return
	# Her faults show on her body, easing in and out.
	for i in 4:
		_fault_w[i] = move_toward(_fault_w[i], 1.0 if i == _fault else 0.0, delta * 3.0)
	_show_faults()
	if _fault < 0:
		_gap -= delta
		if _gap <= 0.0:
			_fault = randi() % FAULTS.size()
			_fault_t = FAULT_SECS
	else:
		_fault_t -= delta
		var a := _pressed(WORDS)
		var f: Array = FAULTS[_fault]
		if a == f[1]:
			_say("Nim", f[2], 1.5)
			hud.pop("Good", SceneHud.GREEN)
			_score += 0.1
			_next_fault()
		elif a != &"" or _fault_t <= 0.0:
			var wrong: String = "That was my %s, darling. You fixed something else." % ["chin", "shoulders", "hands", "feet"][_fault]
			_say("Augusta", wrong if a != &"" else "Too slow. I'd have noticed, if I were you.", 2.5)
			hud.pop("Wrong" if a != &"" else "Too slow", SceneHud.RED)
			_next_fault()
		if _faults_done >= CORRECTIONS:
			_end({"ok": true, "stopped": false})
			return
	hud.kind = "pads"
	hud.cue = (FAULTS[_fault][0] if _fault >= 0 else "She holds it.") if _asked or _check_t > 0.0 else "She glances at you. Ask how she is."
	hud.data = {"up": ["Chin up", SceneHud.CREAM], "down": ["Shoulders down", SceneHud.CREAM], "right": ["Hands still", SceneHud.CREAM],
		"left": ["Feet together", SceneHud.CREAM], "hot": "", "timer": _fault_t / FAULT_SECS if _fault >= 0 else -1.0}
	hud.prompts = _domme_prompts([])


func _next_fault() -> void:
	_faults_done += 1
	_fault = -1
	_gap = 0.7


func _show_faults() -> void:
	if _rig == null:
		return
	var l := _rig.left()
	var f := _rig.fwd()
	_rig.turn("head", l, 0.42 * _fault_w[0])                       # the chin drops
	_rig.turn("shoulderL", f, -0.3 * _fault_w[1])                  # the shoulders creep up
	_rig.turn("shoulderR", f, 0.3 * _fault_w[1])
	_rig.turn("forearmL", l, sin(_t * 9.0) * 0.35 * _fault_w[2])  # the hands fidget
	_rig.turn("forearmR", l, -sin(_t * 9.0 + 1.0) * 0.35 * _fault_w[2])
	_rig.turn("hips", f, 0.16 * _fault_w[3])                       # her weight on one foot
	_rig.turn("chest", f, -0.1 * _fault_w[3])


# --- Grizelda ----------------------------------------------------------------------------------------------------------

## Polishing speed: radians a second of stick circling that sits in the middle of the green.
const BOOT_SPIN := 5.5
const BOOT_LINES := ["Hm. Adequate.", "Other boot.", "You missed a spot. ...No. You didn't. Carry on.", "Better.",
	"The heel. Yes. The heel."]
## Nim's word, and Grizelda's answer, for each step of the throne scene.
const COMMANDS := [["Kneel up.", "...Fine."], ["Eyes down.", "Hmph."], ["Hands behind you.", "They were already."],
	["Still.", "I am still. I'm always still."], ["Thank me.", "...Thank you. Mistress. Don't get used to it."]]


## Polish her boots: circle the stick. The needle is how fast; in the green, the spot comes up.
func _boots(delta: float) -> void:
	_header("Grizelda's boots", "Kneel. Polish. She inspects.")
	hud.meters = [{"name": "Shine", "value": (_count + _shine) / 6.0, "colour": SceneHud.GOLD}]
	if _check_in(delta):
		return
	var v := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if v.length() > 0.4:
		var a := v.angle()
		_spin = lerpf(_spin, absf(wrapf(a - _angle, -PI, PI)) / maxf(delta, 0.001), clampf(delta * 6.0, 0.0, 1.0))
		_angle = a
	else:
		_spin = lerpf(_spin, 0.0, clampf(delta * 4.0, 0.0, 1.0))
	# Just under a turn a second is right (it was one and a half: "insanely difficult", Deck review 5).
	var marker := clampf(_spin / BOOT_SPIN, 0.0, 2.0) - 1.0
	var good := absf(marker) < 0.4
	if good:
		_shine += delta / 2.2
	elif marker > 0.6 and randf() < delta * 0.5:
		_say("Grizelda", "Gently. It's leather, not a floor.", 2.0)
	if _shine >= 1.0:
		_shine = 0.0
		_count += 1
		_score += 1.0 / 6.0
		_boot = 1 - _boot
		hud.pop("Gleaming", SceneHud.GOLD)
		_say("Grizelda", BOOT_LINES[_count % BOOT_LINES.size()], 2.2)
		if _count >= 6:
			_end({"ok": true, "stopped": false})
			return
	hud.kind = "gauge"
	hud.cue = "The %s boot. %s" % ["left" if _boot == 0 else "right",
		"Steady circles." if good else ("Faster." if marker < 0.0 else "Slower.")]
	hud.data = {"marker": marker, "zone": Vector2(0.0, 0.4), "good": good, "left": "too slow", "right": "too fast"}
	hud.prompts = [[&"stick", "Circle the stick"]]
	if _top_rig:
		var foot := _top_rig.pos("footL" if _boot == 0 else "footR")
		_reach = foot + Vector3.UP * 0.1 + Vector3(cos(_angle), 0.0, sin(_angle)) * 0.05


## On the throne, Grizelda kneeling: her will swings like a needle; say the word (A) as it comes into the green.
func _will_game(delta: float) -> void:
	_header("The throne", "Yours, tonight. Make her mean it.")
	hud.word = "her word: \"red\""
	hud.meters = [{"name": "Obedience", "value": _count / float(COMMANDS.size()), "colour": SceneHud.GOLD}]
	_check_in(delta)
	if _done:
		return
	var zone := 0.2 + _count * 0.03
	_will = sin(_t * (1.7 - _count * 0.15) + sin(_t * 0.7) * 1.2)
	var good := absf(_will) < zone
	if Input.is_action_just_pressed(&"jump"):
		var c: Array = COMMANDS[mini(_count, COMMANDS.size() - 1)]
		_say("Nim", c[0], 1.8)
		if good:
			_count += 1
			_score += 0.18
			hud.pop("She obeys", SceneHud.GREEN)
			_say("Grizelda", c[1], 2.4)
			if _count >= COMMANDS.size():
				_end({"ok": true, "stopped": false})
				return
		else:
			hud.pop("She laughs", SceneHud.AMBER)
			_say("Grizelda", ["Hm. Again. Mean it.", "Was that an order? It sounded like a question.", "No."][randi() % 3], 2.2)
			_score -= 0.04
	hud.kind = "gauge"
	hud.cue = "Next: \"%s\"" % COMMANDS[mini(_count, COMMANDS.size() - 1)][0]
	hud.data = {"marker": _will, "zone": Vector2(0.0, zone), "good": good, "left": "defiant", "right": "defiant"}
	hud.prompts = _domme_prompts([[&"jump", "Say it"]])
	if _rig:
		_rig.turn("head", Vector3.UP, _will * 0.4 * (1.0 - _count / 5.0))
		if _count >= 2:
			_rig.turn("head", _rig.left(), 0.25)


# --- Lull --------------------------------------------------------------------------------------------------------------

const LULL_BEAT := 2.4
const LULL_COUNTS := 12
const NUMBERS := ["One.", "Two.", "Three.", "Four.", "Five.", "Six.", "Seven.", "Eight.", "Nine.", "Ten.", "Eleven.", "Twelve."]
## Where Nim's hand goes on Lull, by the D-pad, and what she says to it.
const SPOTS := {&"word_up": ["Her cheek", "Oh. There."], &"word_right": ["Her wrist", "Mm. My pulse is telling on me."],
	&"word_down": ["Her back", "Ah... I didn't hear you move."], &"word_left": ["Her shoulder", "Mm. Stay."]}
var _scored := -1


## Blindfolded, Lull counting slowly: A on each count, the stick still.
func _counting(delta: float) -> void:
	_header("Lull counts", "Blindfolded. Listen for her. A on each count.")
	hud.meters = [{"name": "Calm", "value": clampf(_score, 0.0, 1.0), "colour": SceneHud.ICE}]
	if _check_in(delta):
		return
	var k := int(_t / LULL_BEAT)
	var progress := fmod(_t, LULL_BEAT) / LULL_BEAT
	if k > _count and k <= LULL_COUNTS:
		_count = k
		_say("Lull", NUMBERS[k - 1], 1.6)
	var still := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down").length() < 0.3
	if Input.is_action_just_pressed(&"jump"):
		var near := k if progress < 0.5 else k + 1
		var off := absf(_t - near * LULL_BEAT)
		if near >= 1 and near <= LULL_COUNTS and near != _scored and off <= 0.35 and still:
			_scored = near
			_score += 1.0 / LULL_COUNTS
			hud.pop("Mm", SceneHud.ICE)
		else:
			hud.pop("Not yet" if off > 0.35 else "Still...", SceneHud.AMBER)
	if not still and randf() < delta * 0.5:
		_say("Lull", "Shh. Still. Only listen.", 2.0)
	if _t >= LULL_BEAT * (LULL_COUNTS + 0.5):
		_end({"ok": true, "stopped": false})
		return
	hud.kind = "beat"
	hud.cue = "Listen..." if still else "Still, now."
	hud.data = {"t": progress, "window": 0.35 / LULL_BEAT, "n": _count, "of": LULL_COUNTS}
	hud.prompts = [[&"jump", "On her count"], [&"stick", "Keep still"]]
	if _rig:
		_reach = _rig.pos("armR") + Vector3.UP * 0.06   # her hand on Nim's shoulder


## Lull blindfolded: the D-pad picks where Nim's hand goes next. New places, and never in a hurry.
func _where_next(delta: float) -> void:
	_header("Where next", "Lull's blindfolded. She likes not knowing.")
	hud.word = "her word: \"red\""
	hud.meters = [{"name": "Anticipation", "value": clampf(_score, 0.0, 1.0), "colour": SceneHud.ICE}]
	_check_in(delta)
	if _done:
		return
	_since += delta
	var a := _pressed(WORDS)
	if a != &"":
		if _since < 1.0:
			hud.pop("Too soon", SceneHud.AMBER)
			_say("Lull", "Slower... let me wonder.", 2.0)
			_score -= 0.04
		elif a in _last_pick:
			hud.pop("She knew", SceneHud.AMBER)
			_say("Lull", "Mm. There again.", 1.8)
			_score += 0.02
		else:
			hud.pop("She shivers", SceneHud.GREEN)
			_say("Lull", SPOTS[a][1], 2.2)
			_score += 0.13
		_count += 1
		var picks: Array[StringName] = [a]
		if not _last_pick.is_empty():
			picks.append(_last_pick[0])
		_last_pick = picks
		_since = 0.0
		_call = a
		_jab_t = 1.6
		if _count >= 8:
			_end({"ok": true, "stopped": false})
			return
	_jab_t -= delta
	hud.kind = "pads"
	hud.cue = ("Wait... let her wonder." if _since < 1.2 else "Now. Somewhere new.") if _asked or _check_t > 0.0 \
		else "She tilts her head. Ask how she is."
	hud.data = {"up": [SPOTS[&"word_up"][0], SceneHud.CREAM], "right": [SPOTS[&"word_right"][0], SceneHud.CREAM],
		"down": [SPOTS[&"word_down"][0], SceneHud.CREAM], "left": [SPOTS[&"word_left"][0], SceneHud.CREAM],
		"hot": String(_call) if _jab_t > 0.0 else "", "timer": clampf(_since / 4.0, 0.0, 1.0)}
	hud.prompts = _domme_prompts([[&"word_up", "Where your hand goes"]])
	if _rig and _jab_t > 0.0:
		var f := _rig.fwd()
		match _call:
			&"word_up":
				_reach = _rig.pos("head") + f * 0.1 - _rig.left() * 0.08
			&"word_right":
				_reach = _rig.pos("handR")
			&"word_down":
				_reach = _rig.pos("chest") - f * 0.12
			_:
				_reach = _rig.pos("armL") + Vector3.UP * 0.06


# --- Dash --------------------------------------------------------------------------------------------------------------

const CALLS := {&"word_up": "High!", &"word_right": "Right!", &"word_down": "Low!", &"word_left": "Left!"}
const DRILL := 16


## Dash's drill: she calls it, you hit it on the D-pad before the bar runs out. Faster as it goes.
func _drill(delta: float) -> void:
	_header("Dash's drill", "She calls it. You hit it.")
	hud.meters = [{"name": "Pace", "value": _count / float(DRILL), "colour": SceneHud.AMBER}]
	if _check_in(delta):
		return
	_jab_t -= delta
	if _call == &"":
		_gap -= delta
		if _gap <= 0.0:
			_call = WORDS[randi() % 4]
			_call_len = lerpf(1.5, 0.7, clampf(_count / float(DRILL), 0.0, 1.0))
			_call_t = _call_len
			_say("Dash", CALLS[_call], 0.9)
	else:
		_call_t -= delta
		var a := _pressed(WORDS)
		if a == _call:
			_count += 1
			_score += 1.0 / DRILL
			hud.pop("Hit!", SceneHud.GREEN)
			_jab_t = 0.25
			_next_call()
		elif a != &"" or _call_t <= 0.0:
			_calls_missed()
		if _count >= DRILL:
			_end({"ok": true, "stopped": false})
			return
	hud.kind = "pads"
	hud.cue = "Go!" if _call != &"" else "Ready..."
	hud.data = {"up": ["High", SceneHud.CREAM], "right": ["Right", SceneHud.CREAM], "down": ["Low", SceneHud.CREAM],
		"left": ["Left", SceneHud.CREAM], "hot": String(_call), "timer": _call_t / _call_len if _call != &"" else -1.0}
	hud.prompts = [[&"word_up", "What she calls"]]
	if _rig and _jab_t > 0.0:
		var bag := _frame + _rig.fwd() * 0.9 + Vector3.UP * 1.15
		_reach = bag + {&"word_up": Vector3.UP * 0.25, &"word_down": Vector3.DOWN * 0.3,
			&"word_left": _rig.left() * 0.2, &"word_right": -_rig.left() * 0.2}.get(_call if _call != &"" else &"word_up", Vector3.ZERO)


func _next_call() -> void:
	_call = &""
	_gap = 0.3


func _calls_missed() -> void:
	hud.pop("Too slow" if _call_t <= 0.0 else "Miss", SceneHud.AMBER)
	_say("Dash", ["Faster! ...Okay, slower.", "Other way! Your other way!", "Ha! Again!"][randi() % 3], 1.6)
	_next_call()


## Hold Dash still: she wriggles (the needle). If she gets loose, A catches her.
func _hold_dash(delta: float) -> void:
	_header("Hold on to Dash", "She wriggles. A lot. That's not a colour, that's just her.")
	hud.word = "her word: \"red\""
	hud.meters = [{"name": "Steady", "value": clampf(_score * 1.3, 0.0, 1.0), "colour": SceneHud.AMBER}]
	_check_in(delta)
	if _done:
		return
	if _loose:
		_loose_t -= delta
		if Input.is_action_just_pressed(&"jump"):
			_loose = false
			_balance = 0.0
			hud.pop("Caught!", SceneHud.GREEN)
			_say("Dash", "Hey! ...Okay. Good catch.", 1.8)
			_score += 0.04
		elif _loose_t <= 0.0:
			_loose = false
			_balance = 0.0
			hud.pop("She's off", SceneHud.AMBER)
			_say("Dash", "Ha! Free! ...Okay, okay. Back. I'm back.", 2.2)
			_score -= 0.06
		hud.kind = "text"
		hud.cue = "She's loose! Catch her!"
		hud.prompts = [[&"jump", "Catch her"]]
	else:
		_drift = lerpf(_drift, randf_range(-1.7, 1.7), delta * 1.6)
		_balance = clampf(_balance + (_drift * 1.1 + Input.get_axis(&"move_left", &"move_right") * 1.9) * delta, -1.0, 1.0)
		var good := absf(_balance) < 0.35
		if good:
			_score += delta / SCENE_SECS
		if absf(_balance) >= 1.0:
			_loose = true
			_loose_t = 0.9
			hud.pop("Loose!", SceneHud.RED)
		hud.kind = "gauge"
		hud.cue = "Hold her." if good else "She's getting away..."
		hud.data = {"marker": _balance, "zone": Vector2(0.0, 0.35), "good": good}
		hud.prompts = _domme_prompts([[&"stick", "Lean against her"]])
	if _t >= SCENE_SECS:
		_end({"ok": true, "stopped": false})
		return
	if _rig:
		_rig.turn("hips", _rig.fwd(), _balance * 0.28)
		_rig.turn("chest", _rig.fwd(), -_balance * 0.18)
		_reach = (_rig.pos("handL") + _rig.pos("handR")) / 2.0


# --- Rivet -------------------------------------------------------------------------------------------------------------

const BUCKLES := [["handL", "left wrist"], ["handR", "right wrist"], ["footL", "left ankle"], ["footR", "right ankle"]]


## The strap being worked on: on the limb from the moment it's that buckle's turn, sized every frame (owner, Deck
## review 5: "you cannot really see or enjoy the cuffs being tightened").
var _strap: Node3D
var _strap_i := -1


func _strap_for(i: int) -> Node3D:
	if _rig == null or i >= BUCKLES.size():
		return null
	if _strap_i != i:
		var role: String = BUCKLES[i][0]
		# ("footL" is an ankle, "handR" a wrist: on the shin's or forearm's end, fitted to the limb.)
		_strap = _rig.cuff(("ankle" if role.begins_with("foot") else "wrist") + role.right(1), RigGear.LEATHER)
		_strap_i = i
	return _strap


## Fit 0 (hanging loose) to 1 (pulled tight): the strap's size on the limb.
func _fit_strap(i: int, fit: float) -> void:
	var s := _strap_for(i)
	if s:
		var k := lerpf(1.75, 1.0, clampf(fit, 0.0, 1.0))   # (pulled tight: the cuff's fitted size, on the skin)
		s.scale = Vector3(k, 1.0, k)


## The camera comes in on the buckle being worked: the wrists from the side, the ankles from low down.
func _aim_cam(at: Vector3, far := 1.05) -> void:
	# The way out to the hall, from the scene's opening shot (not from where the camera's got to: that drifted).
	var from := _cam_home.origin if _cam_home != Transform3D() else (_cam.global_position if _cam else _frame + Vector3.BACK)
	var hall := from - _frame
	hall.y = 0.0
	hall = hall.normalized()
	var low := at.y < _frame.y + 0.5
	_cam_from = at + hall * far + Vector3.UP * (0.45 if low else 0.22) + hall.cross(Vector3.UP) * 0.35 * far
	_cam_at = at


var _cam_from := Vector3.INF
var _cam_at := Vector3.INF
var _cam_look := Vector3.INF


func _follow_cam(delta: float) -> void:
	if _cam == null or _cam_from == Vector3.INF:
		return
	var t := clampf(delta * 3.0, 0.0, 1.0)
	_cam.global_position = _cam.global_position.lerp(_cam_from, t)
	_cam_look = _cam_at if _cam_look == Vector3.INF else _cam_look.lerp(_cam_at, t)
	_cam.look_at(_cam_look, Vector3.UP)


func _buckle_at() -> Vector3:
	if _rig == null:
		return _frame + Vector3.UP
	return _rig.pos(BUCKLES[mini(_count, BUCKLES.size() - 1)][0])


## Rivet fits her cuffs on Nim: the strap slides through its notches; A when it's snug.
func _fitting(delta: float) -> void:
	_header("Rivet's fitting", "She made you cuffs. Tell her when they're right.")
	hud.meters = [{"name": "Fit", "value": _count / 4.0, "colour": SceneHud.GOLD}]
	if _check_in(delta):
		return
	_notch += _notch_dir * delta * (0.9 + _count * 0.15)
	if absf(_notch) >= 1.0:
		_notch = clampf(_notch, -1.0, 1.0)
		_notch_dir = -_notch_dir
	var good := absf(_notch - _target) < 0.18
	_fit_strap(_count, (_notch + 1.0) / 2.0)   # it tightens and loosens on her as it slides
	_aim_cam(_buckle_at())
	if Input.is_action_just_pressed(&"jump"):
		if good:
			_count += 1   # (the strap stays as it is, snug; the next one comes on)
			_score += 0.25
			hud.pop("Snug", SceneHud.GREEN)
			_say("Rivet", ["Snug. Good.", "Holds. Don't pull on it. ...You pulled on it.", "That one's perfect. I'm a genius.",
				"Last one. There."][mini(_count - 1, 3)], 2.0)
			_target = randf_range(-0.45, 0.45)
			if _count >= 4:
				_end({"ok": true, "stopped": false})
				return
		else:
			hud.pop("Too tight" if _notch > _target else "Too loose", SceneHud.AMBER)
			_say("Rivet", "Too tight. I'll let it out. Say when." if _notch > _target else "Loose. You'd slip that. Say when.", 2.0)
	hud.kind = "gauge"
	hud.cue = "The %s. Say when it's snug." % BUCKLES[mini(_count, 3)][1]
	hud.data = {"marker": _notch, "zone": Vector2(_target, 0.18), "good": good, "left": "loose", "right": "tight"}
	hud.prompts = [[&"jump", "That's it"]]
	_reach = _buckle_at()


## Nim buckles Rivet's cuffs: line the strap up, A to fasten, then Y to check it. Every buckle.
func _buckles(delta: float) -> void:
	_header("Rivet's buckles", "Fasten each one. Then check it. She'll know.")
	hud.word = "her word: \"red\""
	hud.meters = [{"name": "Her trust", "value": clampf(_score, 0.0, 1.0), "colour": SceneHud.GREEN}]
	if not _fastened:
		_target = sin(_t * 0.8 + _count * 1.7) * 0.55
		_notch = Input.get_axis(&"move_left", &"move_right")
		var good := absf(_notch - _target) < 0.16
		# The strap draws in on her as it lines up with its hole, loose while it doesn't.
		_fit_strap(_count, 0.2 + 0.6 * clampf(1.0 - absf(_notch - _target) / 0.8, 0.0, 1.0))
		if Input.is_action_just_pressed(&"jump"):
			if good:
				_fit_strap(_count, 0.82)
				_fastened = true
				_phase_t = 0.0
				hud.pop("Fastened", SceneHud.GOLD)
			else:
				hud.pop("Off the hole", SceneHud.AMBER)
				_say("Rivet", "That's not the hole. Look at it.", 1.8)
		hud.kind = "gauge"
		hud.cue = "The %s: line the strap up." % BUCKLES[mini(_count, 3)][1]
		hud.data = {"marker": _notch, "target": _target, "target_w": 0.16, "zone": Vector2(_target, 0.16), "good": good}
		hud.prompts = [[&"stick", "Line it up"], [&"jump", "Fasten"]]
	else:
		_phase_t += delta
		var checked := Input.is_action_just_pressed(&"interact")
		var skipped := _pressed(WORDS) != &"" or Input.is_action_just_pressed(&"jump") or _phase_t > 4.0
		if checked:
			_checked += 1
			_score += 0.25
			hud.pop("Checked", SceneHud.GREEN)
			_say("Nim", "Checking it.", 1.2)
			_say("Rivet", ["Holds.", "Good. Twice, though.", "...Yes. That's how you do it.", "All four. I'm impressed. Don't tell anyone."][mini(_checked - 1, 3)], 2.0)
		elif skipped:
			hud.pop("Unchecked", SceneHud.RED)
			_say("Rivet", "You didn't check that one. I made them, so I'll know.", 2.4)
			_score -= 0.1
		if checked or skipped:
			_count += 1
			_fastened = false
			if _count >= 4:
				_end({"ok": true, "stopped": false})
				return
		hud.kind = "text"
		hud.cue = "Fastened. Now check it."
		hud.prompts = [[&"interact", "Check it"]]
	_reach = _buckle_at()
	_aim_cam(_buckle_at())


# --- shared ------------------------------------------------------------------------------------------------------------

func _pressed(actions: Array) -> StringName:
	for a: StringName in actions:
		if Input.is_action_just_pressed(a):
			return a
	return &""


func _say(who: String, text: String, secs := 2.6) -> void:
	hud.say(who, text, secs)
	# She talks with her talk clip when she's free to (not when she's the one held in a pose).
	if who != "Nim" and _sis and _sis.model and _sub_is_nim():
		_sis.model.demo_talk = true
		get_tree().create_timer(minf(secs, 2.0)).timeout.connect(func() -> void:
			if is_instance_valid(_sis) and _sis.model:
				_sis.model.demo_talk = false)


func _end(result: Dictionary) -> void:
	if _done:
		return
	_done = true
	stage = "done"
	result["mode"] = mode
	result["sister"] = sister
	result["ok"] = result.get("ok", false)
	result["stopped"] = result.get("stopped", false)
	result["pushed"] = result.get("pushed", false)
	_result = result
	_after.call_deferred()


## Untied, back to herself; the reward, and aftercare (a conversation), then hand back.
func _after() -> void:
	await get_tree().create_timer(1.0).timeout
	await hud.fade(true)
	hud.kind = ""
	hud.title = ""
	hud.meters = []
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
	for l in _lines:
		if is_instance_valid(l):
			l.queue_free()
	if _sis and not _sub_is_nim():
		_sis.dress("suit")
	# (Nim stays in her two-piece: she changes back at the screen, or pulls her garb on going upstairs.)
	# The aftercare's talked through on the scene's own camera, back at its opening shot of the two of them: the follow
	# camera, squeezed in behind Nim by the room's wall, gave a "massive zoom" on the sister (owner, Deck review 5).
	_cam_from = Vector3.INF
	if _cam and _cam_home != Transform3D():
		_cam.global_transform = _cam_home
	await hud.fade(false)
	if _result.ok:
		Sisters.earn_rose(sister)   # her Rose, the first good scene with her at home
	var label := "%s_%s_%s" % [sister, mode, "red" if _result.stopped else "after"]
	await Dialogue.run("res://data/dialogue/hub/sessions.dialogue", label)
	_name_tags(true)
	if _was_cam and is_instance_valid(_was_cam):
		_was_cam.make_current()
	if _cam:
		_cam.queue_free()
	var nm: Node = _nim.get(&"model")
	if _held_here and nm and bool(nm.get(&"held")):
		nm.call(&"hold", false)
	_nim.set_physics_process(true)
	Hud.show_world_ui(true)
	finished.emit(_result)   # (club_life walks her back to her place)
