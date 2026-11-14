class_name CrossScene
extends Node
## A scene on the cross (WO-014b; owner, 2026-11-12: "part of the Dom process has the option of the Sub on the cross
## where they can pick a gag, blindfold or not, collar or not etc. and have toys used on them"; "Nine Lives already
## has this sort of mini game... we can make this one bigger and better"). Its bones are Nine Lives' After Hours
## (lust/after_hours.gd: the form, gear built in code and hung on bones, the X pose by aiming bones, hold-still and
## brace), ported; none of its art. Bigger: Nim on either side of it, with clients or any sister.
##
## Shown on SceneHud's widgets and on the bodies (owner, Deck review 3: the typed-out version was hard to play): the
## form as rows of choices, the tray as cards, a needle to keep on their sweet spot (glowing on their body too), a ring
## closing on the beat. The one leading holds the tool in their hand and the arm swings with your timing; the one on
## the cross flinches as it lands and squirms with the touch.
##
## Content lines: suggestive, never explicit. Clothes stay on (swimwear at most: a sister on the cross changes into
## hers for it, and back into her suit after; owner, Deck review 3). The tools are sensation and impact only: feather,
## ice, a whisper, flogger, crop, paddle. Swyne's vibrating toys are the story's weapon and are never used in a scene.
## Negotiation first; the safeword (or the dropped bell) stops everything, and that's never wrong; aftercare every way
## it ends. OWNER REVIEW: every line here, the form's wording, and the trays.
##
## role "dom": Nim leads; `partner` (a ClubClient or a sister's Talker) is on the cross.
##   1. The form: their wants filled in, their limits struck out. A gag means the bell (their safeword's a dropped
##      bell). Agree, or "Not tonight".
##   2. Up to ROUNDS rounds from Nim's tray. A touch tool (feather, ice, whisper) is a steadiness game: keep your hand
##      on their drifting sweet spot. An impact tool (flogger, crop, paddle) is a rhythm: land each one on the beat.
##      Praise and Check in are always there. Each round moves their heat (they want it inside their band), their
##      strain, and their trust. Their cues say how it's landing: words, or the bell's hand if they're gagged.
##   3. "Yellow" (or fingers tight on the bell): slow down (a touch tool, praise, a check-in); an impact or more heat
##      costs their trust. Their word (or the bell dropping): stop, B, within RED_TIME. Stopping is a good ending.
## role "sub": Nim's on the cross and `partner` (a sister) leads. The form is Nim's (her muzzle stays: Rivet's filter,
##   never a gag). The sister picks from her tray; Nim holds still (the needle) or braces (A as it lands). Hold B for
##   her word, any time. The sister asks her colour after round three.
## Either way: aftercare in the Quiet Room's nook, then finished({"ok", "stopped", "pushed", "role", "rounds", "trust"}).

signal finished(result: Dictionary)

const ROUNDS := 6
const RED_TIME := 3.0
const SAFEWORD_HOLD := 0.6
## Aftercare on the chaise: how high the hip joints sit above the floor (Silke, who sat right, at 0.55), and the
## gap between two sitters as a multiple of their hip-joint widths summed (about where thighs and hips meet).
const SEAT_HIP := 0.55
const HIP_TOUCH := 1.7
## Where the cross stands (the vaults' hall end, in front of the fireplace), facing the hall (+Z).
const CROSS := Vector3(0.0, -5.0, -67.6)
const SUB_AT := CROSS + Vector3(0.0, 0.0, 0.34)
## Where the one leading stands: close enough to reach (front-right, as the camera sees it).
const TOP_AT := CROSS + Vector3(0.62, 0.0, 1.0)

const FORM := [
	{"id": "wrists", "head": "WRISTS", "options": [["rope", "Rope"], ["cuffs", "Leather cuffs"]]},
	{"id": "ankles", "head": "ANKLES", "options": [["free", "Free"], ["cuffed", "Cuffed"]]},
	{"id": "mouth", "head": "MOUTH", "options": [["none", "Nothing"], ["ball", "Ball gag"], ["bit", "Bit gag"], ["tape", "Tape"]]},
	{"id": "eyes", "head": "EYES", "options": [["open", "Open"], ["blindfold", "Blindfold"]]},
	{"id": "neck", "head": "NECK", "options": [["bare", "Bare"], ["collar", "Collar"]]},
	{"id": "how", "head": "HOW", "options": [["gentle", "Gentle"], ["firm", "Firm"]]},
]
## The tools: how much heat each brings, and which game it is.
const TOOLS := {
	"feather": {"text": "Feather", "power": 0.12, "kind": "touch"},
	"ice": {"text": "Ice", "power": 0.16, "kind": "touch"},
	"whisper": {"text": "Whisper", "power": 0.1, "kind": "touch"},
	"flogger": {"text": "Flogger", "power": 0.22, "kind": "impact", "beats": 4},
	"crop": {"text": "Crop", "power": 0.2, "kind": "impact", "beats": 3},
	"paddle": {"text": "Paddle", "power": 0.26, "kind": "impact", "beats": 3},
}
const TRAY: Array[String] = ["feather", "ice", "whisper", "flogger", "crop", "paddle"]
## The tray's cards: a tag and what it asks of you.
const CARDS := {
	"feather": ["touch", "Touch: follow their sweet spot with the stick."],
	"ice": ["touch", "Touch, and colder: follow their sweet spot with the stick."],
	"whisper": ["touch", "Close, and quiet: follow their sweet spot with the stick."],
	"flogger": ["impact", "Impact: land each one as the ring closes."],
	"crop": ["impact", "Impact, sharper: land each one as the ring closes."],
	"paddle": ["impact", "Impact, heavier: land each one as the ring closes."],
	"praise": ["care", "Praise: eases their strain, builds trust."],
	"check": ["care", "Check in: ask their colour. Always right on yellow."],
	"enough": ["end", "That's enough: end the scene here, kindly."],
}

## Who's on the cross, as subs: what they ask for, what's off the table (form options and tools), the heat they like
## (a band), their word, and their voice. OWNER REVIEW.
const PROFILES := {
	"client": {"name": "A member's guest", "wants": {"wrists": "cuffs", "how": "gentle"}, "limits": ["crop", "paddle"],
		"band": [0.3, 0.7], "word": "pineapple"},   # "nothing sharp" (hub/sessions.dialogue): the flogger's soft
	"smith": {"name": "\"Mr Smith\"", "wants": {"mouth": "ball", "how": "firm", "neck": "collar"}, "limits": ["blindfold"],
		"band": [0.5, 1.0], "word": "decency",
		"open": "Firmly, please. I've been a very hypocritical man.", "after": "...I feel I've atoned. Same time next week?"},
	"pip": {"name": "Pip", "wants": {"wrists": "rope", "how": "gentle"},
		"limits": ["ball", "bit", "firm", "crop", "paddle", "flogger"], "band": [0.15, 0.45], "word": "teacup",
		"open": "Gently? I think I'd like the feather. Is that silly?", "after": "That was... I liked that. I really did."},
	"silke": {"name": "Silke", "wants": {"wrists": "rope", "how": "firm"}, "limits": ["bit"], "band": [0.45, 0.9],
		"word": "red", "open": "Rope, not cuffs. And tie the wrists properly; I'll be checking.",
		"after": "Your second knot slipped. ...I didn't mind."},
	"augusta": {"name": "Augusta", "wants": {"wrists": "cuffs", "neck": "collar", "how": "gentle"}, "limits": ["paddle"],
		"band": [0.3, 0.7], "word": "red", "open": "A collar, I think. And do stand up straight while you work, darling.",
		"after": "Lovely technique. Dreadful posture. I'll forgive you."},
	"grizelda": {"name": "Grizelda", "wants": {"wrists": "cuffs", "how": "firm"}, "limits": ["blindfold"],
		"band": [0.55, 1.0], "word": "red", "open": "Harder than you think. Then harder. I'll tell you how to do it.",
		"after": "Adequate. You may black my boots later. That's a compliment."},
	"dash": {"name": "Dash", "wants": {"how": "firm"}, "limits": ["ball", "bit"], "band": [0.4, 0.8], "word": "red",
		"open": "I'm going to wriggle. Like, a lot. That's not a colour, that's just me.",
		"after": "Okay. Okay okay okay. Again sometime? Not now. Sometime."},
	"lull": {"name": "Lull", "wants": {"eyes": "blindfold", "how": "gentle"}, "limits": ["crop", "paddle"],
		"band": [0.2, 0.55], "word": "red", "open": "Blindfold, please. I like not knowing where you'll be.",
		"after": "Mm. You were so quiet. I could hear you deciding."},
	"rivet": {"name": "Rivet", "wants": {"wrists": "cuffs", "ankles": "cuffed"}, "limits": ["ice"], "band": [0.35, 0.75],
		"word": "red", "open": "Cuffs. Check the buckles twice; I made them, so I'll know.",
		"after": "Buckles held. Good. ...So did I. Thanks."},
}
## A sister leading, when Nim's on the cross: her tray, what she says as she picks up each thing. OWNER REVIEW.
const TOPS := {
	"silke": {"tray": ["feather", "flogger", "ice", "whisper", "flogger"], "line": "Breathe. I've got you."},
	"augusta": {"tray": ["whisper", "feather", "crop", "whisper", "crop"], "line": "Chin up. You're doing beautifully."},
	"grizelda": {"tray": ["crop", "paddle", "whisper", "paddle", "crop"], "line": "Still. I said still. Better."},
	"dash": {"tray": ["feather", "flogger", "feather", "paddle", "feather"], "line": "Tickle round! ...Okay, serious one."},
	"lull": {"tray": ["whisper", "feather", "whisper", "ice", "whisper"], "line": "Mm. Listen to me. Only me."},
	"rivet": {"tray": ["ice", "flogger", "feather", "flogger", "ice"], "line": "Cold. Then not cold. Science."},
}

## Set before it's added.
var hub: Node3D
var role := "dom"
var partner: Node3D
var who := "client"   # the PROFILES / TOPS key
## A regular's step in their story (club_life.visits): Pip, from the third visit, asks for the flogger, gently.
var visit := 0

## Where it's at, for the probes: "form", "tray", "touch", "impact", "cue", "check", "red", "hold", "brace",
## "colour", "aftercare", "done".
var stage := ""
var tray_items: Array[String] = []
var tray_at := 0
var picks := {}
var profile := {}
var heat := 0.0
var strain := 0.0
var trust := 0.0
var rounds := 0
var pushed := false
var stopped := false
var yellow := false
var hud: SceneHud
var _red := false
var _done := false
var _nim: Node3D
var _sub_rig: RigGear
var _top_rig: RigGear
var _sub_model: Node
var _top_model: Node
var _bell: Node3D
var _cam: Camera3D
var _was_cam: Camera3D
var _tool: Node3D
var _glow: MeshInstance3D
var _safe_t := 0.0
var _spot := 0.0   # the touch game's sweet spot, and Nim's hand (-1..1)
var _hand := 0.0
var _flinch := 0.0
var _squirm := 0.0
## Where the hand that holds the tool is going (world), and how it's lerped there; INF: arm at rest.
var _reach := Vector3.INF
var _reach_now := Vector3.INF
var _lean := 0.0


func _ready() -> void:
	_nim = hub.get(&"nim")
	_nim.set_physics_process(false)
	_nim.set(&"velocity", Vector3.ZERO)
	hud = SceneHud.new()
	add_child(hud)
	Hud.show_world_ui(false)
	if role == "dom":
		profile = PROFILES.get(who, PROFILES["client"]).duplicate(true)
		if who == "pip" and visit >= 2:
			(profile.limits as Array).erase("flogger")
			profile.band = [0.2, 0.55]
			profile.open = "The flogger? Gently? Like weather. Nice weather."
		if who == "smith" and visit >= 2:
			profile.open = "No moustache tonight. Same as always, though. Firmly."
	else:
		# Nim's on the cross in her two-piece, no muzzle (Deck review 5), so any gag can be on her form.
		profile = {"name": "Nim", "wants": {}, "limits": [], "band": [0.3, 0.8], "word": "red"}
	_run.call_deferred()


func _run() -> void:
	hud.title = "The cross"
	hud.subtitle = ("You lead.   On the cross: %s" % _partner_name()) if role == "dom" else "%s leads. You're on the cross." % _partner_name()
	# 1. The form, talked through face to face at the cross.
	await hud.fade(true)
	_stand_by()
	_frame()
	await hud.fade(false)
	if not await _form():
		_say(_partner_name(), "Another time, then. Nothing owed.")
		await _wait(1.5)
		_finish({"ok": false, "declined": true})
		return
	await hud.fade(true)
	if role == "dom" and partner is Talker:
		(partner as Talker).dress("swim")   # the sub's in her swimwear (owner, Deck review 3)
	elif role == "sub":
		_nim_swim(true)                     # and so is Nim, when it's her (her two-piece)
	_tie_on()
	await hud.fade(false)
	hud.word = "the bell (dropped)" if gagged() else "\"%s\"" % profile.word
	if profile.has("open") and role == "dom":
		_say(_partner_name(), profile.open)
		await _wait(2.5)
	# 2. The rounds.
	if role == "dom":
		await _dom_rounds()
	else:
		await _sub_rounds()
	# 3. Aftercare, every way it ends.
	await _aftercare()


# --- the form ----------------------------------------------------------------------------------------------------------

## Up/down a row, left/right its option, A agrees, B says "Not tonight". Their limits are shown struck out, and skipped.
func _form() -> bool:
	stage = "form"
	for row: Dictionary in FORM:
		var want: String = profile.wants.get(row.id, row.options[0][0])
		picks[row.id] = want if not want in profile.limits else row.options[0][0]
	var at := 0
	hud.prompts = [[&"word_up", "Row"], [&"word_right", "Choose"], [&"jump", "Agree"], [&"crouch", "Not tonight"]]
	hud.cue = "What happens, and what doesn't. Their wants are filled in." if role == "dom" else "Your form. Ask for what you want."
	var stick_ready := true
	while true:
		var rows: Array = []
		for row: Dictionary in FORM:
			var opts: Array = []
			for o: Array in row.options:
				opts.append({"text": o[1], "on": o[0] == picks[row.id], "limit": o[0] in profile.limits})
			var note := ""
			if role == "sub" and row.id == "mouth":
				note = "not tonight"
			rows.append({"head": row.head, "opts": opts, "note": note})
		var limits: Array[String] = []
		for l: String in profile.limits:
			limits.append(l if not TOOLS.has(l) else TOOLS[l].text.to_lower())
		var stops := "a dropped bell (they hold it)" if picks.mouth != "none" else "\"%s\"" % profile.word
		var foot := "Stops when they say %s." % stops if picks.mouth == "none" else "Gagged, so it stops at %s." % stops
		if role == "dom":
			foot = "Their limits: %s.   %s" % [", ".join(limits) if not limits.is_empty() else "none stated", foot]
		hud.kind = "form"
		hud.data = {"rows": rows, "at": at, "foot": foot}
		await get_tree().process_frame
		var stick := Input.get_axis(&"move_up", &"move_down")
		var side := Input.get_axis(&"move_left", &"move_right")
		var moved := absf(stick) > 0.6 or absf(side) > 0.6
		if Input.is_action_just_pressed(&"word_down") or (stick > 0.6 and stick_ready):
			at = wrapi(at + 1, 0, FORM.size())
		elif Input.is_action_just_pressed(&"word_up") or (stick < -0.6 and stick_ready):
			at = wrapi(at - 1, 0, FORM.size())
		elif Input.is_action_just_pressed(&"word_right") or (side > 0.6 and stick_ready):
			_cycle(FORM[at], 1)
		elif Input.is_action_just_pressed(&"word_left") or (side < -0.6 and stick_ready):
			_cycle(FORM[at], -1)
		elif Input.is_action_just_pressed(&"jump"):
			hud.kind = ""
			return true
		elif Input.is_action_just_pressed(&"crouch"):
			hud.kind = ""
			return false
		stick_ready = not moved
	return false


func _cycle(row: Dictionary, dir: int) -> void:
	var opts: Array = row.options
	var i := 0
	for k in opts.size():
		if opts[k][0] == picks[row.id]:
			i = k
	for n in opts.size():
		i = wrapi(i + dir, 0, opts.size())
		if not opts[i][0] in profile.limits:
			picks[row.id] = opts[i][0]
			return


func gagged() -> bool:
	return picks.get("mouth", "none") != "none"


# --- on the cross ------------------------------------------------------------------------------------------------------

func _sub_body() -> Node3D:
	return _nim if role == "sub" else partner


func _top_body() -> Node3D:
	return partner if role == "sub" else _nim


## Before the form: both by the cross, facing each other, the partner's walk stopped.
func _stand_by() -> void:
	_name_tags(false)
	if partner is Talker:
		(partner as Talker).stop_walk()
	if partner is ClubClient:
		(partner as ClubClient).go([])
		(partner as ClubClient).face_toward = Vector3.INF
	var sub_at := SUB_AT + Vector3(-0.2, 0.0, 0.75)
	for p: Array in [[_sub_body(), sub_at, TOP_AT], [_top_body(), TOP_AT, sub_at]]:
		var body: Node3D = p[0]
		body.global_position = p[1]
		var d: Vector3 = p[2] - p[1]
		body.rotation.y = atan2(-d.x, -d.z)
		if body is CharacterBody3D:
			(body as CharacterBody3D).velocity = Vector3.ZERO
		if body.has_method(&"reset_physics_interpolation"):
			body.reset_physics_interpolation()


func _tie_on() -> void:
	var sub := _sub_body()
	var top := _top_body()
	_name_tags(false)
	sub.global_position = SUB_AT
	sub.rotation.y = PI   # facing the hall (+Z): a body's front is -Z
	if sub is CharacterBody3D:
		(sub as CharacterBody3D).velocity = Vector3.ZERO
	if sub.has_method(&"reset_physics_interpolation"):
		sub.reset_physics_interpolation()
	top.global_position = TOP_AT
	var d := SUB_AT - TOP_AT
	top.rotation.y = atan2(-d.x, -d.z)
	if top.has_method(&"reset_physics_interpolation"):
		top.reset_physics_interpolation()
	if partner is ClubClient:
		(partner as ClubClient).face_toward = Vector3.INF
		(partner as ClubClient).go([])
	# The one leading is held too, so the arm with the tool can be moved by hand.
	_top_model = _model_of(top)
	if _top_model:
		_top_model.call(&"hold", true)
		var tsk: Skeleton3D = _top_model.call(&"skeleton")
		if tsk:
			_top_rig = RigGear.new(tsk, top)
			_top_rig.capture()
	_sub_model = _model_of(sub)
	if _sub_model == null:
		return
	_sub_model.call(&"hold", true)
	var sk: Skeleton3D = _sub_model.call(&"skeleton")
	if sk == null:
		return
	_sub_rig = RigGear.new(sk, sub)
	_sub_rig.pose_x()
	_sub_rig.capture()
	var r := _sub_rig
	for s in ["L", "R"]:
		var fl := (r.pos("hand" + s) - r.pos("forearm" + s)).length()
		if picks.wrists == "rope":
			r.wrap("forearm" + s, 0.042, fl * 0.86)
		else:
			r.band("hand" + s, 0.044, RigGear.LEATHER, true)
		if picks.ankles == "cuffed":
			r.band("foot" + s, 0.05, RigGear.LEATHER, true)
	var head := r.head_frame()
	if picks.neck == "collar":
		# Round the neck halfway up it, a little looser than the neck is thick.
		var up_neck := (r.pos("head") - r.pos("neck")).length() * 0.5
		r.band("neck", head.neck_r, Color("2a0e18"), true, up_neck)
	# Head gear is a ring centred in the head at the height it sits, reaching round to just past the face.
	if picks.eyes == "blindfold":
		var eye_mid: Vector3 = head.eyes - head.fwd * head.reach * 0.55
		r.wear("head", RigGear.oval(head.r * 1.3, head.reach * 0.72, 0.075, RigGear.LEATHER), eye_mid, head.fwd)
	r.gag(String(picks.mouth))   # ball, bit or tape (RigGear.gag)
	if gagged():
		_bell = r.bell("handR")
	# Where they want it, as a soft glow on their body (the touch game's sweet spot).
	_glow = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.07
	sm.height = 0.14
	_glow.mesh = sm
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	gm.albedo_color = Color(1.0, 0.35, 0.55, 0.55)
	gm.no_depth_test = true
	_glow.material_override = gm
	_glow.visible = false
	hub.add_child(_glow)


func _model_of(body: Node3D) -> Node:
	if body == _nim:
		return body.get(&"model")
	if body is ClubClient:
		return body.get(&"_look")
	if body is Talker:
		return body.get(&"model") if body.get(&"model") else body.get(&"look")
	return null




func _drop_bell() -> void:
	if not is_instance_valid(_bell):
		return
	var at := _bell.global_position
	var holder := _bell.get_parent()
	holder.remove_child(_bell)
	hub.add_child(_bell)
	_bell.global_transform = Transform3D(Basis(), at)   # (off the bone: its scale goes with it)
	var t := create_tween()
	t.tween_property(_bell, ^"global_position:y", CROSS.y + 0.03, 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


func _untie() -> void:
	_hide_tool()
	if _sub_rig:
		_sub_rig.clear()
	if _top_rig:
		_top_rig.clear()
	if is_instance_valid(_bell):
		_bell.queue_free()
	if is_instance_valid(_glow):
		_glow.queue_free()
	for m in [_sub_model, _top_model]:
		if m and is_instance_valid(m):
			m.call(&"hold", false)
	_sub_rig = null
	_top_rig = null
	_name_tags(true)


## A sister's name tag hangs over her head: hidden for the scene, back after.
func _name_tags(on: bool) -> void:
	if partner is Talker and is_instance_valid(partner):
		for c in partner.get_children():
			if c is Label3D:
				(c as Label3D).visible = on


func _frame() -> void:
	_was_cam = get_viewport().get_camera_3d()
	_cam = Camera3D.new()
	_cam.fov = 55.0
	hub.add_child(_cam)
	# From the front-left: the one leading stands front-right, so both are in the shot, the cross between.
	# Looking a little low, so the bodies sit in the top of the frame, clear of the panel.
	_cam.global_position = CROSS + Vector3(-1.5, 1.7, 3.5)
	_cam.look_at(CROSS + Vector3(0.3, 0.62, 0.5), Vector3.UP)
	_cam.make_current()


# --- the bodies, every frame -------------------------------------------------------------------------------------------

## Aftercare with a sister: [the one who was on the cross, the other, the way from the first to the second].
var _cuddle: Array = []
var _cuddle_t := 0.0


## Leaning into each other on the chaise, breathing, a nuzzle now and then: her head on the other's shoulder and a
## hand on her knee; the other's arm round her, head tipped in to hers.
func _cuddle_pose(t: float) -> void:
	var s: RigGear = _cuddle[0]
	var top: RigGear = _cuddle[1]
	var to: Vector3 = _cuddle[2]
	s.restore()
	top.restore()
	var toward := Vector3.UP.cross(to).normalized()    # tipping about this leans toward the other
	var away := -toward
	var breath := sin(t * 1.3)
	s.turn("spine", toward, 0.1)
	s.turn("chest", toward, 0.1)
	s.turn("chest", s.left(), -0.03 * breath)
	s.turn("head", toward, 0.38 + sin(t * 0.7) * 0.05)
	# Her hand on the other's knee (the arm on the other's side).
	var near := "L" if s.left().dot(to) > 0.0 else "R"
	var knee := top.pos("shin" + ("L" if top.left().dot(-to) > 0.0 else "R"))
	s.reach(knee + Vector3.UP * 0.08, near)
	# The other's arm round her, to her far shoulder.
	var round_side := "L" if top.left().dot(-to) > 0.0 else "R"
	var far: Vector3 = s.pos("armL") if s.pos("armL").distance_to(top.pos("chest")) > s.pos("armR").distance_to(top.pos("chest")) \
		else s.pos("armR")
	# Round behind her, not across her front (owner: "her arm appears in front of her sister"): the upper arm back
	# along the chaise toward her, then the forearm in to her far shoulder from behind.
	var back := -top.fwd()
	top.aim("arm" + round_side, "forearm" + round_side, -to * 0.6 + back * 0.45 + Vector3.DOWN * 0.3)
	var elbow := top.pos("forearm" + round_side)
	var hold_at := far + Vector3.UP * 0.03 + back * 0.06
	top.aim("forearm" + round_side, "hand" + round_side, hold_at - elbow)
	top.turn("chest", away, 0.06)
	top.turn("chest", top.left(), -0.03 * sin(t * 1.3 + 0.8))
	top.turn("head", away, 0.22 + sin(t * 0.55 + 1.0) * 0.06)


func _process(delta: float) -> void:
	if not _cuddle.is_empty():
		_cuddle_t += delta
		_cuddle_pose(_cuddle_t)
	_flinch = move_toward(_flinch, 0.0, delta * 3.0)
	if _sub_rig:
		_sub_rig.restore()
		var l := _sub_rig.left()
		var f := _sub_rig.fwd()
		_sub_rig.turn("hips", f, _squirm * 0.14)
		_sub_rig.turn("chest", l, -_flinch * 0.16)
		_sub_rig.turn("head", l, -_flinch * 0.2)
	if _top_rig:
		_top_rig.restore()
		if _lean != 0.0:
			_top_rig.turn("chest", _top_rig.left(), _lean)
		if _reach != Vector3.INF:
			_reach_now = _reach if _reach_now == Vector3.INF else _reach_now.lerp(_reach, clampf(delta * 14.0, 0.0, 1.0))
			_top_rig.reach(_reach_now)
		else:
			_reach_now = Vector3.INF


## A point on the body on the cross: across its middle by `x` (-1..1, the camera's left to right), up by `y`.
func _on_body(x: float, y := 0.0) -> Vector3:
	if _sub_rig == null:
		return SUB_AT + Vector3(x * 0.2, 1.0 + y, 0.2)
	return (_sub_rig.pos("spine") + _sub_rig.pos("hips")) / 2.0 + Vector3(x * 0.2, y, 0.0) + _sub_rig.fwd() * 0.17


## Where the hand winds up to, before an impact lands: up and back over the shoulder.
func _wind_point() -> Vector3:
	if _top_rig == null:
		return TOP_AT + Vector3(0.2, 1.9, 0.2)
	var right := -_top_rig.left()
	return _top_rig.pos("armR") + Vector3.UP * 0.42 + right * 0.22 - _top_rig.fwd() * 0.12


func _show_tool(tool: String) -> void:
	_hide_tool()
	if tool == "whisper" or _top_rig == null:
		return
	_tool = RigGear.tool_mesh(tool)
	_top_rig.attach("handR", _tool, Vector3(0, 0.05, 0))


func _hide_tool() -> void:
	if is_instance_valid(_tool):
		var holder := _tool.get_parent()
		if holder is BoneAttachment3D:
			holder.queue_free()
		else:
			_tool.queue_free()
	_tool = null
	_reach = Vector3.INF
	_lean = 0.0


# --- Nim leads ---------------------------------------------------------------------------------------------------------

func _dom_rounds() -> void:
	var tray: Array[String] = []
	for t in TRAY:
		if not t in profile.limits:
			tray.append(t)
	tray.append_array(["praise", "check", "enough"])
	while rounds < ROUNDS and not _done:
		var pick := await _choose(tray)
		if _red or pick == "":
			break
		match pick:
			"enough":
				break
			"praise":
				strain = maxf(strain - 0.12, 0.0)
				trust += 0.2 if picks.neck == "collar" else 0.1
				_say("Nim", ["Good. So good.", "That's it. Just like that.", "Perfect."][randi() % 3])
				_say_sub(["Mm.", "Thank you.", "..."][randi() % 3])
				hud.pop("Trust +", SceneHud.GREEN)
				_lean = 0.12
				await _wait(1.6)
				_lean = 0.0
			"check":
				await _check_in()
			_:
				if yellow and (TOOLS[pick].kind == "impact" or heat > float(profile.band[1])):
					pushed = true
					trust -= 0.2
					strain += 0.25
					hud.pop("Pushed past yellow", SceneHud.RED)
				var q := 0.0
				if TOOLS[pick].kind == "touch":
					q = await _touch(pick)
				else:
					q = await _impact(pick)
				if _red:
					break
				_land(pick, q)
				rounds += 1
				await _cue()
		if _red:
			await _red_moment()
			return


## A tool's effect: heat for the touch, strain for what didn't land, trust while they're in their band.
func _land(tool: String, q: float) -> void:
	var power: float = TOOLS[tool].power * (1.3 if picks.how == "firm" else 1.0)
	if picks.eyes == "blindfold" and TOOLS[tool].kind == "touch":
		q = minf(q + 0.15, 1.0)   # anticipation: not knowing where you'll be
	heat += power * (0.5 + q)
	strain = clampf(strain + power * (1.0 - q) * 1.3 + maxf(heat - float(profile.band[1]), 0.0) * 0.5, 0.0, 1.0)
	if heat >= float(profile.band[0]) and heat <= float(profile.band[1]):
		trust += 0.12 * (0.5 + q)
	heat = maxf(heat - 0.05, 0.0)


## How it's landing: words, or the bell's hand when they're gagged.
func _cue() -> void:
	stage = "cue"
	var lo: float = profile.band[0]
	var hi: float = profile.band[1]
	yellow = false
	if strain >= 0.85:
		_red = true
		return
	hud.kind = "text"
	hud.cue_colour = SceneHud.CREAM
	if strain >= 0.6:
		yellow = true
		hud.cue = "Their fingers tighten on the bell: yellow." if gagged() else "\"Yellow.\"  Slow down."
		hud.cue_colour = SceneHud.AMBER
		_say_sub("" if gagged() else "Yellow...")
	elif heat < lo:
		hud.cue = "They lean into it, wanting more." if not gagged() else "They push against the cuffs: more."
	elif heat <= hi:
		hud.cue = "They're lost in it. Every breath slower."
		hud.cue_colour = SceneHud.GREEN
		_say_sub("Mm..." if not gagged() else "")
	else:
		hud.cue = "It's a lot. Their breathing's quick."
		hud.cue_colour = SceneHud.AMBER
	hud.prompts = []
	_show_meters()
	await _wait(1.8)
	hud.cue_colour = SceneHud.CREAM


## Their word, or the bell dropping: stop, now. B within RED_TIME is right; anything else isn't.
func _red_moment() -> void:
	stage = "red"
	_hide_tool()
	hud.kind = "text"
	hud.cue_colour = SceneHud.RED
	if gagged():
		_drop_bell()
		hud.cue = "The bell drops. Stop."
	else:
		_say_sub("\"%s.\"" % String(profile.word).capitalize())
		hud.cue = "They say their word. Stop."
	hud.prompts = [[&"crouch", "Stop, now"]]
	var t := RED_TIME
	while t > 0.0:
		await get_tree().process_frame
		t -= get_process_delta_time()
		if Input.is_action_just_pressed(&"crouch"):
			stopped = true
			hud.pop("Stopped", SceneHud.GREEN)
			_say("Nim", "Stopping. I've got you.")
			hud.cue_colour = SceneHud.CREAM
			return
		if _any_other_press():
			break
	pushed = true
	hud.cue_colour = SceneHud.CREAM
	_say("Vesper", "You heard the word, and you kept going. That's the one thing we never do.", 5.0)   # OWNER REVIEW


func _any_other_press() -> bool:
	for a: StringName in [&"jump", &"strike", &"word_up", &"word_down", &"word_left", &"word_right", &"interact"]:
		if Input.is_action_just_pressed(a):
			return true
	return false


func _check_in() -> void:
	stage = "check"
	hud.kind = "text"
	hud.prompts = []
	_say("Nim", "Colour?" if not gagged() else "Ring once for green. Twice if you need me to slow down.")
	hud.cue = "You ask."
	_lean = 0.1
	await _wait(1.4)
	if strain >= 0.6 or yellow:
		_say_sub("Yellow." if not gagged() else "")
		hud.cue = "\"Yellow.\" You ease off." if not gagged() else "Two rings. You ease off."
		hud.pop("Trust +", SceneHud.GREEN)
		trust += 0.15
		strain = maxf(strain - 0.28, 0.0)
		yellow = false
	else:
		_say_sub("Green." if not gagged() else "")
		hud.cue = "\"Green.\"" if not gagged() else "One ring. Green."
		trust += 0.05
	_show_meters()
	await _wait(1.4)
	_lean = 0.0


## The first time each kind comes up in a scene: how it goes, and A to begin (owner, Deck review 5: the games "jump
## right into the mini-game and don't give much time to adjust or learn"). OWNER REVIEW.
const EXPLAIN := {
	"touch": ["A touch", ["Their sweet spot drifts; it glows on them, and on the bar.", "Follow it with the stick: keep your marker in the glow.",
		"The longer you stay on it, the better it lands."]],
	"impact": ["An impact", ["A ring closes on the mark, once for each stroke.", "Press A as it meets the mark: early or late, it doesn't land well.",
		"After \"yellow\", an impact pushes them. Slow down instead."]],
	"hold": ["Holding still", ["You're pushed about; the needle shows how far.", "Push back with the stick and keep it in the green.",
		"Hold B any time: your word, and it stops."]],
	"brace": ["Bracing", ["She winds up; a ring closes as it lands.", "Press A as it meets the mark, and you take it still.",
		"Hold B any time: your word."]],
}
var _explained := {}


func _explain(kind: String) -> void:
	if _explained.has(kind):
		return
	_explained[kind] = true
	var was := [hud.title, hud.subtitle, hud.cue]
	stage = "intro"
	hud.title = EXPLAIN[kind][0]
	hud.subtitle = "How it goes"
	hud.kind = "intro"
	hud.cue = ""
	hud.data = {"lines": EXPLAIN[kind][1]}
	hud.prompts = [[&"jump", "Begin"]]
	await get_tree().process_frame
	while not Input.is_action_just_pressed(&"jump"):
		await get_tree().process_frame
	await get_tree().process_frame   # (that press isn't the game's first)
	hud.title = was[0]
	hud.subtitle = was[1]


## The touch: their sweet spot drifts as they move; keep your hand on it with the stick (Nine Lives' needle, the other
## way round: here Nim follows them). The score is the time on it.
func _touch(tool: String, seconds := 4.0) -> float:
	await _explain("touch")
	stage = "touch"
	_show_tool(tool)
	var target := 0.0
	var aim := 0.0
	var x := 0.0
	var t := 0.0
	var on := 0.0
	var wander := 0.6 if picks.eyes == "open" else 0.85
	if who == "dash":
		wander += 0.4
	hud.kind = "gauge"
	hud.cue = "%s: stay on their sweet spot." % TOOLS[tool].text
	hud.prompts = [[&"stick", "Follow it"]]
	if is_instance_valid(_glow):
		_glow.visible = true
	while t < seconds:
		await get_tree().physics_frame
		var dt := 1.0 / 60.0
		t += dt
		if randf() < dt * 1.2:
			aim = randf_range(-wander, wander)
		target = move_toward(target, aim, dt * 0.9)
		x = clampf(x + Input.get_axis(&"move_left", &"move_right") * dt * 1.6, -1.0, 1.0)
		_spot = target
		_hand = x
		var good := absf(x - target) < 0.22
		if good:
			on += dt
		hud.data = {"marker": x, "target": target, "target_w": 0.22, "good": good, "zone": Vector2(target, 0.22)}
		_squirm = lerpf(_squirm, target * 0.6, dt * 3.0)
		var wob := sin(t * 3.0) * 0.06
		if is_instance_valid(_glow):
			_glow.global_position = _on_body(target, 0.05)
			(_glow.material_override as StandardMaterial3D).albedo_color.a = 0.35 + (0.35 if good else 0.0)
		if tool == "whisper":
			_lean = 0.22
		else:
			_reach = _on_body(x, wob) + (_sub_rig.fwd() if _sub_rig else Vector3.BACK) * 0.05
		_show_meters()
	if is_instance_valid(_glow):
		_glow.visible = false
	_squirm = 0.0
	hud.pop("Perfect" if on / seconds > 0.8 else ("Good" if on / seconds > 0.5 else "Lost them"),
		SceneHud.GREEN if on / seconds > 0.5 else SceneHud.AMBER)
	_hide_tool()
	return on / seconds


## The rhythm: a ring closes on the beat; A as it closes lands it. Early or late, it doesn't.
func _impact(tool: String) -> float:
	await _explain("impact")
	stage = "impact"
	_show_tool(tool)
	var beats: int = TOOLS[tool].beats
	var hits := 0
	hud.kind = "beat"
	hud.cue = "%s: land each one as the ring closes." % TOOLS[tool].text
	hud.prompts = [[&"jump", "Land it"]]
	for n in beats:
		var period := randf_range(0.8, 1.15) * (1.15 if picks.how == "gentle" else 1.0)
		var t := 0.0
		var pressed := -1.0
		var landed := false
		while t < period + 0.25:
			await get_tree().physics_frame
			t += 1.0 / 60.0
			if Input.is_action_just_pressed(&"jump") and pressed < 0.0:
				pressed = t
			hud.data = {"t": t / period, "window": 0.16 / period, "n": n, "of": beats, "verb": "On the ring: %s" % Controls.glyph(&"jump")}
			# The arm: wound up over the shoulder as the ring closes, and swung in as it lands.
			if t < period - 0.1:
				_reach = _wind_point()
			else:
				_reach = _on_body(0.55, -0.12)
			if not landed and t >= period:
				landed = true
		var off := pressed - period
		if pressed >= 0.0 and absf(off) <= 0.16:
			hits += 1
			_flinch = 1.0
			hud.pop("Perfect!" if absf(off) <= 0.06 else "Good", SceneHud.GREEN if absf(off) <= 0.06 else SceneHud.GOLD)
			_say_sub("" if gagged() else ["Ah-", "Mm!", "Oh-"][randi() % 3], 0.8)
		else:
			_flinch = 0.35
			hud.pop("Missed" if pressed < 0.0 else ("Early" if off < 0.0 else "Late"), SceneHud.AMBER)
		_show_meters()
		await _wait(0.25)
	_hide_tool()
	return float(hits) / float(beats)


## The tray, as cards: left and right, A picks it.
func _choose(options: Array[String]) -> String:
	stage = "tray"
	tray_items = options
	var at := 0
	var stick_ready := true
	hud.cue = "Round %d of %d. What next?" % [rounds + 1, ROUNDS]
	hud.prompts = [[&"stick", "Choose"], [&"jump", "Use it"]]
	while true:
		tray_at = at
		var items: Array = []
		for o in options:
			var label: String = TOOLS[o].text if TOOLS.has(o) else {"praise": "Praise", "check": "Check in",
				"enough": "Enough"}.get(o, o)
			var tag: String = CARDS[o][0]
			var col := SceneHud.ROSE if tag == "touch" else (SceneHud.RED if tag == "impact" else (SceneHud.GREEN if tag == "care" else SceneHud.SOFT))
			if o == "ice":
				col = SceneHud.ICE
			items.append({"id": o, "name": label, "tag": tag, "colour": col})
		var note: String = CARDS[options[at]][1]
		if yellow and (options[at] in TOOLS and (TOOLS[options[at]].kind == "impact")):
			note = "They said yellow. An impact now would push them."
		hud.kind = "cards"
		hud.data = {"items": items, "at": at, "note": note}
		_show_meters()
		await get_tree().process_frame
		var side := Input.get_axis(&"move_left", &"move_right")
		if Input.is_action_just_pressed(&"word_right") or (side > 0.6 and stick_ready):
			at = wrapi(at + 1, 0, options.size())
		elif Input.is_action_just_pressed(&"word_left") or (side < -0.6 and stick_ready):
			at = wrapi(at - 1, 0, options.size())
		elif Input.is_action_just_pressed(&"jump"):
			return options[at]
		stick_ready = absf(side) < 0.3
	return ""


# --- Nim on the cross --------------------------------------------------------------------------------------------------

func _sub_rounds() -> void:
	var top: Dictionary = TOPS.get(who, TOPS["silke"])
	var tray: Array = top.tray
	for i in tray.size():
		if _red or _done:
			break
		var tool: String = tray[i]
		if picks.how == "gentle" and tool == "paddle":
			tool = "feather"
		hud.subtitle = "%s leads. Round %d of %d." % [_partner_name(), i + 1, tray.size()]
		hud.kind = "text"
		hud.cue = "She picks up the %s." % TOOLS[tool].text.to_lower() if tool != "whisper" else "She leans in close."
		hud.prompts = [[&"crouch", "Hold: drop the bell" if gagged() else "Hold: your word"]]
		_say(_partner_name(), top.line if i == 0 else "%s." % TOOLS[tool].text)
		_show_tool(tool)
		if await _wait_or_word(1.2):
			break
		var q := 0.0
		if TOOLS[tool].kind == "touch":
			q = await _hold_still(tool)
		else:
			q = await _brace(tool)
		_hide_tool()
		if _red:
			break
		trust += 0.12 * q
		rounds += 1
		if rounds == 3:
			await _asked_colour()
	hud.safeword_hold = -1.0
	if _red:
		stopped = true
		_hide_tool()
		hud.kind = "text"
		hud.cue = "The bell drops. Everything stops." if gagged() else "Red. Everything stops."
		if gagged():
			_drop_bell()
		hud.prompts = []
		_say(_partner_name(), "Red. Good. You said it, I heard it. I've got you.")
		await _wait(2.0)


## Waits, but her word (B held) cuts it short. True if she said it.
func _wait_or_word(secs: float) -> bool:
	var t := 0.0
	while t < secs:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		if _safeword_held():
			return true
	return false


## Hold still: you're shoved about, and the stick pushes back (After Hours' _steady). The score is the time in the
## middle.
func _hold_still(tool: String, seconds := 4.0) -> float:
	await _explain("hold")
	stage = "hold"
	var force: float = TOOLS[tool].power * (4.5 if picks.how == "firm" else 3.4)
	var x := 0.0
	var push := 0.0
	var aim := 0.0
	var next_push := 0.0
	var t := 0.0
	var inside := 0.0
	hud.kind = "gauge"
	hud.cue = "%s: hold still." % TOOLS[tool].text
	hud.prompts = [[&"stick", "Push back to the middle"], [&"crouch", "Hold: drop the bell" if gagged() else "Hold: your word"]]
	while t < seconds:
		await get_tree().physics_frame
		if _safeword_held():
			return 0.0
		var dt := 1.0 / 60.0
		t += dt
		next_push -= dt
		if next_push <= 0.0:
			aim = randf_range(0.5, 1.0) * force * (1.0 if randf() < 0.5 else -1.0)
			next_push = randf_range(0.5, 1.0)
		push = move_toward(push, aim, dt * 3.0)
		x = clampf(x + (push - Input.get_axis(&"move_left", &"move_right") * 1.7 - x * 0.9) * dt * 1.3, -1.0, 1.0)
		var good := absf(x) < 0.4
		if good:
			inside += dt
		hud.data = {"marker": x, "zone": Vector2(0.0, 0.4), "good": good}
		_squirm = x
		if tool == "whisper":
			_lean = 0.22
		else:
			_reach = _on_body(push * 0.8, sin(t * 2.5) * 0.08)
	_squirm = 0.0
	hud.pop("Still as stone" if inside / seconds > 0.75 else ("Steady" if inside / seconds > 0.45 else "Wriggly"),
		SceneHud.GREEN if inside / seconds > 0.45 else SceneHud.AMBER)
	return inside / seconds


## Brace: it winds up and lands; A the moment it lands holds you still (After Hours' _brace).
func _brace(tool: String) -> float:
	await _explain("brace")
	stage = "brace"
	var beats: int = TOOLS[tool].beats
	var held := 0
	hud.kind = "beat"
	hud.cue = "%s: brace as it lands." % TOOLS[tool].text
	hud.prompts = [[&"jump", "Brace"], [&"crouch", "Hold: drop the bell" if gagged() else "Hold: your word"]]
	for n in beats:
		var wind := randf_range(0.7, 1.3) + (0.2 if picks.how == "gentle" else 0.0)
		var t := 0.0
		var pressed := -1.0
		while t < wind + 0.3:
			await get_tree().physics_frame
			if _safeword_held():
				return 0.0
			t += 1.0 / 60.0
			if Input.is_action_just_pressed(&"jump") and pressed < 0.0:
				pressed = t
			hud.data = {"t": t / wind, "window": 0.2 / wind, "n": n, "of": beats, "verb": "Brace on the ring: %s" % Controls.glyph(&"jump")}
			_reach = _wind_point() if t < wind - 0.1 else _on_body(0.55, -0.12)
		var off := pressed - wind
		_flinch = 0.45 if pressed >= 0.0 and absf(off) <= 0.2 else 1.0
		if pressed >= 0.0 and absf(off) <= 0.2:
			held += 1
			hud.pop("Braced", SceneHud.GREEN)
		else:
			hud.pop("Missed" if pressed < 0.0 else ("Early" if off < 0.0 else "Late"), SceneHud.AMBER)
		await _wait(0.3)
	return float(held) / float(beats)


## Held B for long enough: her word. It stops everything, and that's never wrong.
func _safeword_held() -> bool:
	if Input.is_action_pressed(&"crouch"):
		_safe_t += 1.0 / 60.0
	else:
		_safe_t = 0.0
	hud.safeword_hold = clampf(_safe_t / SAFEWORD_HOLD, 0.0, 1.0)
	if _safe_t >= SAFEWORD_HOLD:
		_red = true
	return _red


func _asked_colour() -> void:
	stage = "colour"
	_hide_tool()
	_say(_partner_name(), "Colour?")
	hud.kind = "pads"
	hud.cue = "%s asks your colour." % _partner_name()
	hud.data = {"up": ["Green", SceneHud.GREEN], "right": ["Yellow", SceneHud.AMBER], "down": ["Red", SceneHud.RED],
		"hot": "", "timer": -1.0}
	hud.prompts = [[&"word_up", "Green"], [&"word_right", "Yellow"], [&"word_down", "Red"]]
	while true:
		await get_tree().process_frame
		if Input.is_action_just_pressed(&"word_up"):
			_say("Nim", "Green.")
			_say(_partner_name(), "Good. Stay with me.")
			break
		if Input.is_action_just_pressed(&"word_right"):
			_say("Nim", "Yellow.")
			_say(_partner_name(), "Yellow. I'll ease off. Thank you for telling me.")
			picks.how = "gentle"
			break
		if Input.is_action_just_pressed(&"word_down"):
			_say("Nim", "Red.")
			_red = true
			break
	await _wait(1.5)


# --- after -------------------------------------------------------------------------------------------------------------

## In the Quiet Room's nook (Hub.QUIET_SEATS[NOOK]): a blanket round the one who was on the cross, water, a while.
func _aftercare() -> void:
	stage = "aftercare"
	var ok := not pushed and (stopped or (trust >= 0.45 and rounds >= 2) or role == "sub")
	await _wait(0.6)
	await hud.fade(true)
	_untie()
	hud.kind = ""
	hud.meters = []
	hud.word = ""
	hud.safeword_hold = -1.0
	hud.title = "Aftercare"
	hud.subtitle = "The Quiet Room"
	var seat: Array = Hub.QUIET_SEATS[Hub.NOOK]
	var c: Vector3 = seat[0]
	var f: Vector3 = seat[1]
	var across := Vector3(f.z, 0, -f.x)
	var sub := _sub_body()
	var top := _top_body()
	# The holds from the cross are let go; sitting holds them again, in a new pose. Name tags stay off for the scene.
	_sub_model = null
	_top_model = null
	_name_tags(false)
	# Side by side on the nook's chaise, facing the room, its own knit throw over the end. No blanket built on her: the
	# shawl round her "displayed oddly" (owner, Deck review 4), and a throw on her lap read as a card.
	var front := f * (0.443 - Hub.SEAT_IN)
	# With a sister, they sit close and cuddle while they talk (owner, Deck review 5: "They are Sisters who love and
	# care for each other. Right now, they are sitting so stiff"). With a client, Nim sits near, not on them.
	var close := 0.31 if partner is Talker else 0.48
	var sub_sit := _sit(sub, c + front - across * close, f)
	var top_sit := _sit(top, c + front + across * close, f)
	if partner is Talker and not sub_sit.is_empty() and not top_sit.is_empty():
		# Hip to hip: the gap from their own widths, so a slim sister isn't left a hand's width off (owner, on Rivet:
		# "they aren't touching at all").
		var half := (float(sub_sit.hip_w) + float(top_sit.hip_w)) * HIP_TOUCH * 0.5
		for pair: Array in [[sub_sit, -1.0], [top_sit, 1.0]]:
			var b: Node3D = pair[0].body
			var y := b.global_position.y
			b.global_position = c + front + across * half * float(pair[1])
			b.global_position.y = y
			if b.has_method(&"reset_physics_interpolation"):
				b.reset_physics_interpolation()
		var to: Vector3 = (top_sit.body as Node3D).global_position - (sub_sit.body as Node3D).global_position
		to.y = 0.0
		_cuddle = [sub_sit.rig, top_sit.rig, to.normalized()]
		_cuddle_t = 0.0
	if _cam:
		_cam.global_position = c + f * 3.3 + across * 0.7 + Vector3(0, 1.45, 0)
		_cam.look_at(c + f * 0.45 + Vector3(0, 0.55, 0), Vector3.UP)
	await hud.fade(false)
	if role == "dom":
		_say("Nim", "Here. Blanket. Water. Take your time.")
		await _wait(2.0)
		_say(_partner_name(), profile.get("after", "Thank you. I needed that.") if not pushed
			else "...I said my word. I need a minute.", 3.4)
	else:
		_say(_partner_name(), "Water. Blanket. Talk to me: how was that?")
		await _wait(2.2)
		_say("Nim", "Quiet. Good quiet." if not stopped else "Too much, for tonight. I'm all right.")
		await _wait(2.0)
		_say(_partner_name(), "Nothing's wrong. Sit with me a while.")
	await _wait(4.0)
	await hud.fade(true)
	# Nim gets up; a sister stays sitting a while, and club_life lets her go later (out of her swimwear once nobody's
	# looking, then home): owner, Deck review 4, "have the Sister who participated sit in Aftercare for a bit more
	# before changing back and walking back to their room".
	var result := {"ok": ok, "stopped": stopped, "pushed": pushed}
	# Out of the cuddle: she's left sitting as she sat.
	for r in _cuddle.slice(0, 2):
		(r as RigGear).restore()
	_cuddle = []
	for s: Dictionary in [sub_sit, top_sit]:
		if s.is_empty():
			continue
		if s.body == _nim:
			_stand(s, f)   # (in her two-piece still, if she was the sub: she changes back at the screen)
		elif s.body is Talker:
			result["linger"] = {"rig": s.rig, "drop": s.drop, "swim": role == "dom"}
	_finish(result)
	await hud.fade(false)


## Sat on the chaise at `at`, facing `f`: a client with their tea (their own sitting clip); anyone else held and posed
## seated, lowered onto the seat. Returns {body, rig, drop}, or {} for a client.
func _sit(body: Node3D, at: Vector3, f: Vector3) -> Dictionary:
	body.global_position = at
	body.rotation.y = atan2(-f.x, -f.z)
	if body.has_method(&"reset_physics_interpolation"):
		body.reset_physics_interpolation()
	if body is ClubClient:
		(body as ClubClient).go([])
		(body as ClubClient).face_toward = at + f * 2.0
		(body as ClubClient).pose(&"drink")
		return {}
	var m := _model_of(body)
	if m == null:
		return {}
	m.call(&"hold", true)
	var sk: Skeleton3D = m.call(&"skeleton")
	if sk == null:
		return {}
	var rig := RigGear.new(sk, body)
	sk.force_update_all_bone_transforms()
	# The hip joints (where the thighs hinge), not the hips bone: Nim's sits level with them, the cast's well above.
	var hip := rig.pos("thighL").y - body.global_position.y
	var hip_w := (rig.pos("thighL") - rig.pos("thighR")).length()
	rig.pose_sit()
	# Hips onto the seat whatever her legs: lowering by the thigh sat the long-legged right and sank the short ones into
	# the cushion (owner, on Rivet: "embedded in the couch").
	var drop := maxf(hip - SEAT_HIP, 0.0)
	rig.capture()
	body.global_position.y -= drop
	if body.has_method(&"reset_physics_interpolation"):
		body.reset_physics_interpolation()
	return {"body": body, "rig": rig, "drop": drop, "model": m, "hip_w": hip_w}


## Up off the chaise, a step out into the room.
func _stand(s: Dictionary, f: Vector3) -> void:
	var body: Node3D = s.body
	(s.rig as RigGear).clear()
	(s.model as Node).call(&"hold", false)
	body.global_position += Vector3.UP * float(s.drop) + f * 0.55
	if body.has_method(&"reset_physics_interpolation"):
		body.reset_physics_interpolation()


func _finish(result: Dictionary) -> void:
	if _done:
		return
	_done = true
	stage = "done"
	result["role"] = role
	result["who"] = who
	result["rounds"] = rounds
	result["trust"] = trust
	result["ok"] = result.get("ok", false)
	result["stopped"] = result.get("stopped", false)
	result["pushed"] = result.get("pushed", false)
	_untie()
	if _was_cam and is_instance_valid(_was_cam):
		_was_cam.make_current()
	if _cam:
		_cam.queue_free()
	_nim.set_physics_process(true)
	hud.kind = ""
	hud.title = ""
	hud.meters = []
	Hud.show_world_ui(true)
	if result.ok and not result.get("declined", false):
		Game.earn_rose(&"hub", &"hub_08" if who in ["client", "smith", "pip"] else &"hub_09")
		Hud.note("THE CROSS\nRounds: %d\n%s" % [rounds,
			"Stopped the moment it was asked. That counts most." if stopped else "A good scene, start to finish."], 6.0)
	finished.emit(result)


# --- small things ------------------------------------------------------------------------------------------------------

## Nim's two-piece on or off (NimModel.wear_swim), during a fade.
func _nim_swim(on: bool) -> void:
	var m: Node = _nim.get(&"model")
	if m and m.has_method(&"wear_swim"):
		m.call(&"wear_swim", on)


func _partner_name() -> String:
	return String(profile.get("name", "")) if role == "dom" else who.capitalize()


func _say(speaker: String, text: String, secs := 2.6) -> void:
	if text == "":
		return
	var sub_speaks := (role == "sub" and speaker == "Nim") or (role == "dom" and speaker == _partner_name())
	if sub_speaks and gagged() and stage != "aftercare":
		text = RigGear.muffle(text)
	hud.say(speaker, text, secs)


func _say_sub(text: String, secs := 2.2) -> void:
	if text == "":
		return
	if role == "dom" and partner is ClubClient:
		(partner as ClubClient).say(RigGear.muffle(text) if gagged() and stage != "aftercare" else text, secs)
	_say("Nim" if role == "sub" else _partner_name(), text, secs)


func _show_meters() -> void:
	if role != "dom":
		hud.meters = [{"name": "Trust", "value": clampf(trust, 0.0, 1.0), "colour": SceneHud.GREEN}]
		return
	var band: Array = profile.band
	hud.meters = [
		{"name": "Heat", "value": heat / 1.2, "band": Vector2(float(band[0]) / 1.2, float(band[1]) / 1.2), "colour": SceneHud.ROSE},
		{"name": "Strain", "value": strain, "colour": SceneHud.AMBER if strain < 0.6 else SceneHud.RED},
		{"name": "Trust", "value": clampf(trust, 0.0, 1.0), "colour": SceneHud.GREEN},
	]


func _wait(secs: float) -> void:
	await get_tree().create_timer(secs).timeout
