class_name CrossScene
extends CanvasLayer
## A scene on the cross (WO-014b; owner, 2026-11-12: "part of the Dom process has the option of the Sub on the cross
## where they can pick a gag, blindfold or not, collar or not etc. and have toys used on them"; "Nine Lives already
## has this sort of mini game... we can make this one bigger and better"). Its bones are Nine Lives' After Hours
## (lust/after_hours.gd: the form, gear built in code and hung on bones, the X pose by aiming bones, hold-still and
## brace), ported; none of its art. Bigger: Nim on either side of it, with clients or any sister.
##
## Content lines: suggestive, never explicit. Clothes stay on (swimwear at most). The tools are sensation and impact
## only: feather, ice, a whisper, flogger, crop, paddle. Swyne's vibrating toys are the story's weapon and are never
## used in a scene. Negotiation first; the safeword (or the dropped bell) stops everything, and that's never wrong;
## aftercare every way it ends. OWNER REVIEW: every line here, the form's wording, and the trays.
##
## role "dom": Nim leads; `partner` (a ClubClient or a sister's Talker) is on the cross.
##   1. The form: their wants filled in, their limits greyed out. A gag means the bell (their safeword's a dropped
##      bell). Agree, or "Not tonight".
##   2. Up to ROUNDS rounds from Nim's tray. A touch tool (feather, ice, whisper) is a steadiness game: keep your hand
##      on their drifting sweet spot. An impact tool (flogger, crop, paddle) is a rhythm: land each one on the beat.
##      Praise and Check in are always there. Each round moves their heat (they want it inside their band), their
##      strain, and their trust. Their cues say how it's landing: words, or the bell's hand if they're gagged.
##   3. "Yellow" (or fingers tight on the bell): slow down (a touch tool, praise, a check-in); an impact or more heat
##      costs their trust. Their word (or the bell dropping): stop, B, within RED_TIME. Stopping is a good ending.
## role "sub": Nim's on the cross and `partner` (a sister) leads. The form is Nim's (her muzzle stays: Rivet's filter,
##   never a gag). The sister picks from her tray; Nim holds still (left/right on the needle) or braces (A as it
##   lands). Hold B for her word, any time. The sister asks her colour after round three.
## Either way: aftercare, then finished({"ok", "stopped", "pushed", "role", "rounds", "trust"}).

signal finished(result: Dictionary)

const ROUNDS := 6
const RED_TIME := 3.0
const SAFEWORD_HOLD := 0.6
## Where the cross stands (the vaults' hall end, in front of the fireplace), facing the hall (+Z).
const CROSS := Vector3(0.0, -5.0, -67.6)
const SUB_AT := CROSS + Vector3(0.0, 0.0, 0.34)
const TOP_AT := CROSS + Vector3(0.95, 0.0, 1.55)

const FORM := [
	{"id": "wrists", "head": "WRISTS", "options": [["rope", "Rope"], ["cuffs", "Leather cuffs"]]},
	{"id": "ankles", "head": "ANKLES", "options": [["free", "Free"], ["cuffed", "Cuffed"]]},
	{"id": "mouth", "head": "MOUTH", "options": [["none", "Nothing"], ["ball", "Ball gag"], ["bit", "Bit gag"]]},
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

var picks := {}
var profile := {}
var heat := 0.0
var strain := 0.0
var trust := 0.0
var rounds := 0
var pushed := false
var stopped := false
var yellow := false
var _red := false
var _done := false
var _nim: Node3D
var _sub_model: Node        # the posed body's model (EnemyModel, CastModel or NimModel)
var _gear: Array[Node] = []
var _bell: Node3D
var _cam: Camera3D
var _was_cam: Camera3D
var _toy: Node3D
var _safe_t := 0.0
var _spot := 0.0   # the touch game's sweet spot, and Nim's hand (-1..1)
var _hand := 0.0
# UI
var _panel: PanelContainer
var _title: Label
var _body: Label
var _bar: Label
var _keys: Label
var _black: ColorRect


func _ready() -> void:
	layer = 7
	_nim = hub.get(&"nim")
	_nim.set_physics_process(false)
	_nim.set(&"velocity", Vector3.ZERO)
	_build_ui()
	if role == "dom":
		profile = PROFILES.get(who, PROFILES["client"]).duplicate(true)
	else:
		profile = {"name": "Nim", "wants": {}, "limits": ["ball", "bit"], "band": [0.3, 0.8], "word": "red"}
	_run.call_deferred()


func _run() -> void:
	# 1. The form.
	if not await _form():
		_say(_partner_name(), "Another time, then. Nothing owed.")
		await _wait(1.5)
		_finish({"ok": false, "declined": true})
		return
	await _fade(true)
	_tie_on()
	_frame()
	await _fade(false)
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

## Up/down a row, left/right its option, A agrees, B says "Not tonight". Their limits are shown, and skipped.
func _form() -> bool:
	for row: Dictionary in FORM:
		var want: String = profile.wants.get(row.id, row.options[0][0])
		picks[row.id] = want if not want in profile.limits else row.options[0][0]
	var at := 0
	_title.text = "THE CROSS: what happens, and what doesn't" if role == "dom" else "THE CROSS: your form"
	_keys.text = "↑↓ row   ←→ choose   %s agree   %s not tonight" % [Controls.glyph(&"jump"), Controls.glyph(&"crouch")]
	var stick_ready := true
	while true:
		var lines: Array[String] = []
		for i in FORM.size():
			var row: Dictionary = FORM[i]
			var opt := ""
			for o: Array in row.options:
				if o[0] == picks[row.id]:
					opt = o[1]
			var note := ""
			if role == "sub" and row.id == "mouth":
				note = "   (your muzzle stays: Rivet's filter)"
			lines.append("%s %-8s %s%s" % ["▶" if i == at else " ", row.head, opt, note])
		var limits: Array[String] = []
		for l: String in profile.limits:
			limits.append(l if not TOOLS.has(l) else TOOLS[l].text.to_lower())
		var word := "a dropped bell" if picks.mouth != "none" else "\"%s\"" % profile.word
		_body.text = "\n".join(lines) + "\n\n%s   Stops when: %s" % [
			"Their limits: %s." % (", ".join(limits) if not limits.is_empty() else "none stated") if role == "dom" else "",
			word]
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
			return true
		elif Input.is_action_just_pressed(&"crouch"):
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
	if partner is ClubClient:
		(partner as ClubClient).face_toward = Vector3.INF
		(partner as ClubClient).go([])
	_sub_model = _model_of(sub)
	if _sub_model == null:
		return
	_sub_model.call(&"hold", true)
	var sk: Skeleton3D = _sub_model.call(&"skeleton")
	if sk == null:
		return
	_pose_x(sk)
	var b := _bones(sk)
	var dark := Color("1c1418")
	var tan := Color("c8a070")
	var wrist_c := tan if picks.wrists == "rope" else dark
	for s in ["L", "R"]:
		_wear_band(sk, b["hand" + s], 0.044, wrist_c, picks.wrists == "cuffs")
		if picks.ankles == "cuffed":
			_wear_band(sk, b["foot" + s], 0.05, dark, true)
	var head := _head_frame(sk, b)
	if picks.neck == "collar":
		# Round the neck halfway up it, a little looser than the neck is thick.
		var up_neck := (_gpos(sk, b.head) - _gpos(sk, b.neck)).length() * 0.5
		_wear_band(sk, b.neck, head.neck_r, Color("2a0e18"), true, up_neck)
	# Head gear is a ring centred in the head at the height it sits, reaching round to just past the face.
	if picks.eyes == "blindfold":
		var eye_mid: Vector3 = head.eyes - head.fwd * head.reach * 0.55
		_wear_head(sk, b.head, head, _band_round(head.r * 1.3, head.reach * 0.72, 0.075, Color("1c1418")), eye_mid)
	match String(picks.mouth):
		"ball":
			_wear_head(sk, b.head, head, _gag(head, false), head.mouth - head.fwd * head.reach * 0.85)
		"bit":
			_wear_head(sk, b.head, head, _gag(head, true), head.mouth - head.fwd * head.reach * 0.85)
	if gagged():
		_bell = _make_bell()
		_attach(sk, b.handR, _bell, Vector3(0, 0, 0.04))


func _model_of(body: Node3D) -> Node:
	if body == _nim:
		return body.get(&"model")
	if body is ClubClient:
		return body.get(&"_look")
	if body is Talker:
		return body.get(&"model") if body.get(&"model") else body.get(&"look")
	return null


## The bones by role: Meshy's rigs (clients, the cast) or Nim's own.
func _bones(sk: Skeleton3D) -> Dictionary:
	if sk.find_bone("LeftArm") >= 0:
		return {"armL": "LeftArm", "forearmL": "LeftForeArm", "handL": "LeftHand", "armR": "RightArm",
			"forearmR": "RightForeArm", "handR": "RightHand", "thighL": "LeftUpLeg", "shinL": "LeftLeg",
			"footL": "LeftFoot", "thighR": "RightUpLeg", "shinR": "RightLeg", "footR": "RightFoot", "neck": "neck",
			"head": "Head", "head_end": "head_end", "front": "headfront"}
	return {"armL": "upper_arm.L", "forearmL": "forearm.L", "handL": "hand.L", "armR": "upper_arm.R",
		"forearmR": "forearm.R", "handR": "hand.R", "thighL": "thigh.L", "shinL": "shin.L", "footL": "foot.L",
		"thighR": "thigh.R", "shinR": "shin.R", "footR": "foot.R", "neck": "neck", "head": "head", "head_end": "",
		"front": ""}


func _gpos(sk: Skeleton3D, bone: String) -> Vector3:
	var i := sk.find_bone(bone)
	return (sk.global_transform * sk.get_bone_global_pose(i)).origin if i >= 0 else sk.global_position


## Arms up and out in an X, legs a little apart (After Hours' _pose_x): each bone turned to point the way it should,
## in world space, with "left" read off the body itself (its left arm's side).
func _pose_x(sk: Skeleton3D) -> void:
	sk.force_update_all_bone_transforms()
	var b := _bones(sk)
	var left := (_gpos(sk, b.armL) - _gpos(sk, b.armR))
	left.y = 0.0
	left = left.normalized()
	var up := 0.87   # about 50 degrees above level: the wrists at the cross's upper rings
	for s: Array in [["L", 1.0], ["R", -1.0]]:
		var side: Vector3 = left * float(s[1])
		var arm := side * cos(up) + Vector3.UP * sin(up)
		_aim(sk, b["arm" + s[0]], b["forearm" + s[0]], arm)
		_aim(sk, b["forearm" + s[0]], b["hand" + s[0]], arm)
		_aim(sk, b["thigh" + s[0]], b["shin" + s[0]], side * 0.22 + Vector3.DOWN)
		_aim(sk, b["shin" + s[0]], b["foot" + s[0]], side * 0.22 + Vector3.DOWN)


func _aim(sk: Skeleton3D, bone: String, child: String, dir: Vector3) -> void:
	var bi := sk.find_bone(bone)
	var ci := sk.find_bone(child)
	if bi < 0 or ci < 0:
		return
	sk.force_update_all_bone_transforms()
	var want := (sk.global_basis.inverse() * dir).normalized()
	var g := sk.get_bone_global_pose(bi)
	var now := (sk.get_bone_global_pose(ci).origin - g.origin).normalized()
	if now.length() < 0.5:
		return
	var turned := Transform3D(Basis(Quaternion(now, want)) * g.basis, g.origin)
	var p := sk.get_bone_parent(bi)
	var pg := sk.get_bone_global_pose(p) if p >= 0 else Transform3D()
	sk.set_bone_pose_rotation(bi, (pg.affine_inverse() * turned).basis.get_rotation_quaternion())


## The head in world space: its middle, which way the face points, its size; where the eyes and mouth are. Meshy's
## rigs carry headfront and head_end; Nim's own rig is measured from her head bone and her model's facing.
func _head_frame(sk: Skeleton3D, b: Dictionary) -> Dictionary:
	sk.force_update_all_bone_transforms()
	var head := _gpos(sk, b.head)
	var fwd := -(_sub_body().global_basis.z)
	# Nim's head bone sits low in a big head (her rig has no top or front bones): measured off her model.
	var top := head + Vector3.UP * 0.3
	var front := head + Vector3.UP * 0.12 + fwd * 0.3   # past her muzzle's goggles, so a blindfold goes over them
	var neck_r := 0.06
	var eye_up := 0.05   # her eyes sit higher in her head than the Meshy heads' do
	if b.front != "" and sk.find_bone(b.front) >= 0:
		front = _gpos(sk, b.front)
		top = _gpos(sk, b.head_end)
		neck_r = 0.0
		eye_up = 0.0
	var span := maxf((top - head).length(), 0.12)
	# Cartoon heads are big for their bones: the head's half-width is most of the way from its root to its top.
	var r := clampf(span * 0.55, 0.09, 0.18)
	var mid := head + Vector3.UP * span * 0.42
	var f := front - mid
	f.y = 0.0
	if f.length() < 0.02:
		f = fwd
	var reach := clampf(f.length(), r * 0.8, r * 2.2)
	if neck_r == 0.0:
		neck_r = r * 0.62
	f = f.normalized()
	return {"mid": mid, "fwd": f, "r": r, "reach": reach, "front": front, "neck_r": neck_r,
		# Eyes sit near the middle's height on every head here; the blindfold's tall enough to cover the spread.
		"eyes": mid + Vector3.UP * eye_up + f * reach * 0.55,
		"mouth": mid + Vector3.DOWN * span * 0.36 + f * reach * 0.85}


## A band round a bone (cuffs, rope, a collar), along the bone.
func _wear_band(sk: Skeleton3D, bone: String, radius: float, c: Color, buckle: bool, along := 0.0) -> void:
	var n := Node3D.new()
	var t := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = radius
	var tube := clampf(radius * 0.45, 0.016, 0.03)
	tm.outer_radius = radius + tube
	t.mesh = tm
	t.scale = Vector3(1.0, 1.6, 1.0)   # a cuff is wider than its tube is thick
	t.material_override = Look.toon(c, 0.3)
	n.add_child(t)
	if buckle:
		var bk := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.03, 0.03, 0.015)
		bk.mesh = bm
		bk.material_override = Look.toon(Look.BRASS, 0.7)
		bk.position = Vector3(0, 0, radius + tube)
		n.add_child(bk)
	_attach(sk, bone, n, Vector3(0, along, 0))


## Head gear, level with the body and facing the way its face does, its middle at `at`.
func _wear_head(sk: Skeleton3D, bone: String, head: Dictionary, what: Node3D, at: Vector3) -> void:
	var i := sk.find_bone(bone)
	if i < 0:
		what.free()
		return
	var bg := sk.global_transform * sk.get_bone_global_pose(i)
	var f: Vector3 = head.fwd
	var basis := Basis.looking_at(-f, Vector3.UP)   # its +Z toward the face's front
	var a := BoneAttachment3D.new()
	a.bone_name = bone
	sk.add_child(a)
	a.add_child(what)
	what.transform = bg.affine_inverse() * Transform3D(basis, at)
	_gear.append(a)


## Hung on a bone, in metres, turned with the bone (its +Y along it), `offset` in that frame. Meshy's skeletons carry
## a 0.01 scale (their meshes are in centimetres), so the gear's set through the bone's inverse, never just
## positioned under it: a cuff simply parented there came out a hundredth of its size.
func _attach(sk: Skeleton3D, bone: String, what: Node3D, offset: Vector3) -> void:
	var i := sk.find_bone(bone)
	if i < 0:
		what.free()
		return
	sk.force_update_all_bone_transforms()
	var bg := sk.global_transform * sk.get_bone_global_pose(i)
	var basis := bg.basis.orthonormalized()
	var a := BoneAttachment3D.new()
	a.bone_name = bone
	sk.add_child(a)
	a.add_child(what)
	what.transform = bg.affine_inverse() * Transform3D(basis, bg.origin + basis * offset)
	_gear.append(a)


## A band round the head, level: an oval `side` wide each way and `front` long each way (the face is +Z), `tall` high.
func _band_round(side: float, front: float, tall: float, c: Color) -> Node3D:
	var n := Node3D.new()
	var s := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.0
	tm.outer_radius = 1.12
	tm.rings = 24
	s.mesh = tm
	# The torus's tube is 0.06 of a unit thick; scaled, it's an oval strap `tall` high.
	s.scale = Vector3(side, tall / 0.12, front)
	s.material_override = Look.toon(c, 0.3)
	n.add_child(s)
	return n


## A gag: its strap round the head at mouth height, reaching the mouth at the front, and the ball (or the bit) there.
func _gag(head: Dictionary, bit: bool) -> Node3D:
	var front: float = head.reach * 0.85 + 0.008
	var n := _band_round(head.r + 0.008, front, 0.022, Color("1c1418"))
	var piece := MeshInstance3D.new()
	if bit:
		var cm := CylinderMesh.new()
		cm.top_radius = 0.018
		cm.bottom_radius = 0.018
		cm.height = 0.13
		piece.mesh = cm
		piece.rotation.z = PI / 2.0
		piece.material_override = Look.toon(Color("1c1418"), 0.4)
	else:
		var sm := SphereMesh.new()
		sm.radius = 0.038
		sm.height = 0.076
		piece.mesh = sm
		piece.material_override = Look.toon(Look.VELVET, 0.6)
	piece.position = Vector3(0, 0, front)
	n.add_child(piece)
	return n


func _make_bell() -> Node3D:
	var n := Node3D.new()
	var b := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.012
	cm.bottom_radius = 0.03
	cm.height = 0.045
	b.mesh = cm
	b.material_override = Look.toon(Look.BRASS, 0.9)
	n.add_child(b)
	return n


func _drop_bell() -> void:
	if not is_instance_valid(_bell):
		return
	var at := _bell.global_position
	_bell.get_parent().remove_child(_bell)
	hub.add_child(_bell)
	_bell.global_position = at
	var t := create_tween()
	t.tween_property(_bell, ^"global_position:y", CROSS.y + 0.03, 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_gear.append(_bell)


func _untie() -> void:
	for g in _gear:
		if is_instance_valid(g):
			g.queue_free()
	_gear.clear()
	if _sub_model and is_instance_valid(_sub_model):
		_sub_model.call(&"hold", false)
	_name_tags(true)


## A sister's "Name (Y)" tag hangs over her head: hidden for the scene, back after.
func _name_tags(on: bool) -> void:
	if partner is Talker and is_instance_valid(partner):
		for c in partner.get_children():
			if c is Label3D:
				(c as Label3D).visible = on


func _frame() -> void:
	_was_cam = get_viewport().get_camera_3d()
	_cam = Camera3D.new()
	hub.add_child(_cam)
	# From the front-left: the top stands front-right, so she's in the shot beside the cross, not in front of it.
	_cam.global_position = CROSS + Vector3(-1.7, 1.5, 3.1)
	_cam.look_at(CROSS + Vector3(0.3, 1.1, 0.4), Vector3.UP)
	_cam.make_current()


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
				await _wait(1.6)
			"check":
				await _check_in()
			_:
				if yellow and (TOOLS[pick].kind == "impact" or heat > float(profile.band[1])):
					pushed = true
					trust -= 0.2
					strain += 0.25
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
	var lo: float = profile.band[0]
	var hi: float = profile.band[1]
	yellow = false
	if strain >= 0.85:
		_red = true
		return
	if strain >= 0.6:
		yellow = true
		_body.text = "Their fingers tighten on the bell." if gagged() else "\"Yellow.\""
		_say_sub("" if gagged() else "Yellow...")
	elif heat < lo:
		_body.text = "They lean into it, wanting more." if not gagged() else "They push against the cuffs: more."
	elif heat <= hi:
		_body.text = "They're lost in it. Every breath slower."
		_say_sub("Mm..." if not gagged() else "")
	else:
		_body.text = "It's a lot. Their breathing's quick."
	_show_meters()
	await _wait(1.8)


## Their word, or the bell dropping: stop, now. B (or the check-in) within RED_TIME is right; anything else isn't.
func _red_moment() -> void:
	if gagged():
		_drop_bell()
		_body.text = "The bell drops.   STOP (%s)" % Controls.glyph(&"crouch")
	else:
		_say_sub("\"%s.\"" % String(profile.word).capitalize())
		_body.text = "They say their word.   STOP (%s)" % Controls.glyph(&"crouch")
	var t := RED_TIME
	while t > 0.0:
		await get_tree().process_frame
		t -= get_process_delta_time()
		if Input.is_action_just_pressed(&"crouch"):
			stopped = true
			Hud.note("You stopped the moment they asked. That's the whole job.", 5.0)
			return
		if _any_other_press():
			break
	pushed = true
	Hud.caption("Vesper", "You heard the word, and you kept going. That's the one thing we never do.", 6.0)   # OWNER REVIEW


func _any_other_press() -> bool:
	for a: StringName in [&"jump", &"strike", &"word_up", &"word_down", &"word_left", &"word_right", &"interact"]:
		if Input.is_action_just_pressed(a):
			return true
	return false


func _check_in() -> void:
	_say("Nim", "Colour?" if not gagged() else "Ring once for green. Twice if you need me to slow down.")
	await _wait(1.4)
	if strain >= 0.6 or yellow:
		_say_sub("Yellow." if not gagged() else "")
		_body.text = "\"Yellow.\" You ease off." if not gagged() else "Two rings. You ease off."
		trust += 0.15
		strain = maxf(strain - 0.28, 0.0)
		yellow = false
	else:
		_say_sub("Green." if not gagged() else "")
		_body.text = "\"Green.\"" if not gagged() else "One ring. Green."
		trust += 0.05
	await _wait(1.4)


## The touch: their sweet spot drifts as they move; keep your hand on it with the stick (Nine Lives' needle, the other
## way round: here Nim follows them). The score is the time on it.
func _touch(tool: String, seconds := 4.0) -> float:
	_show_toy(tool)
	var target := 0.0
	var aim := 0.0
	var x := 0.0
	var t := 0.0
	var on := 0.0
	var wander := 0.6 if picks.eyes == "open" else 0.85
	if who == "dash":
		wander += 0.4
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
		if absf(x - target) < 0.22:
			on += dt
		var line := ""
		for i in 31:
			var p := -1.0 + i / 15.0
			line += "◆" if absf(p - x) < 0.034 else ("○" if absf(p - target) < 0.22 else "·")
		_body.text = "%s: stay with them   [%s]" % [TOOLS[tool].text, line]
		if _toy:
			_toy.global_position = SUB_AT + Vector3(x * 0.3, 1.25 + sin(t * 3.0) * 0.08, 0.45)
	_hide_toy()
	return on / seconds


## The rhythm: a ring closes on the beat; A as it closes lands it. Early or late, it doesn't.
func _impact(tool: String) -> float:
	_show_toy(tool)
	var beats: int = TOOLS[tool].beats
	var hits := 0
	for n in beats:
		var period := randf_range(0.8, 1.15) * (1.15 if picks.how == "gentle" else 1.0)
		var t := 0.0
		var pressed := -1.0
		while t < period + 0.25:
			await get_tree().physics_frame
			t += 1.0 / 60.0
			if Input.is_action_just_pressed(&"jump") and pressed < 0.0:
				pressed = t
			var closing := clampf(1.0 - t / period, 0.0, 1.0)
			_body.text = "%s %d/%d:  %s  on the beat (%s)" % [TOOLS[tool].text, n + 1, beats,
				"(" + " ".repeat(int(closing * 12)) + "●" + " ".repeat(int(closing * 12)) + ")", Controls.glyph(&"jump")]
			if _toy:
				var up := clampf(t / period, 0.0, 1.0)
				_toy.global_position = TOP_AT + Vector3(-0.3, 1.2 + 0.5 * up, -0.4) if t < period else SUB_AT + Vector3(0.25, 1.0, 0.4)
		if absf(pressed - period) <= 0.16:
			hits += 1
			_say_sub("" if gagged() else ["Ah-", "Mm!", "Oh-"][randi() % 3], 0.8)
		await _wait(0.25)
	_hide_toy()
	return float(hits) / float(beats)


## The tray, on the left: up and down, A picks it.
func _choose(options: Array[String]) -> String:
	var at := 0
	var stick_ready := true
	while true:
		var lines: Array[String] = []
		for i in options.size():
			var o := options[i]
			var text: String = TOOLS[o].text if TOOLS.has(o) else {"praise": "Praise", "check": "Check in",
				"enough": "That's enough"}.get(o, o)
			lines.append(("▶ " if i == at else "   ") + text)
		_title.text = "Your tray   (round %d of %d)" % [rounds + 1, ROUNDS]
		_body.text = "    ".join(lines)
		_keys.text = "←→ choose   %s use" % Controls.glyph(&"jump")
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
	_title.text = "On the cross: %s leads" % _partner_name()
	_keys.text = "Hold %s for your word (\"red\"), any time" % Controls.glyph(&"crouch")
	for i in tray.size():
		if _red or _done:
			break
		var tool: String = tray[i]
		if picks.how == "gentle" and tool == "paddle":
			tool = "feather"
		_say(_partner_name(), top.line if i == 0 else "%s." % TOOLS[tool].text)
		await _wait(1.2)
		var q := 0.0
		if TOOLS[tool].kind == "touch":
			q = await _hold_still(tool)
		else:
			q = await _brace(tool)
		if _red:
			break
		trust += 0.12 * q
		rounds += 1
		if rounds == 3:
			await _asked_colour()
	if _red:
		stopped = true
		_say(_partner_name(), "Red. Good. You said it, I heard it. I've got you.")
		await _wait(2.0)


## Hold still: the needle's shoved about, left and right push it back (After Hours' _steady). The score is the time
## in the middle.
func _hold_still(tool: String, seconds := 4.0) -> float:
	var force: float = TOOLS[tool].power * (4.5 if picks.how == "firm" else 3.4)
	var x := 0.0
	var push := 0.0
	var aim := 0.0
	var next_push := 0.0
	var t := 0.0
	var inside := 0.0
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
		if absf(x) < 0.4:
			inside += dt
		var line := ""
		for i in 31:
			var p := -1.0 + i / 15.0
			line += "|" if absf(p - x) < 0.034 else ("-" if absf(p) < 0.4 else "·")
		_body.text = "%s: hold still   [%s]" % [TOOLS[tool].text, line]
	return inside / seconds


## Brace: it winds up and lands; A the moment it lands holds you still (After Hours' _brace).
func _brace(tool: String) -> float:
	var beats: int = TOOLS[tool].beats
	var held := 0
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
			_body.text = "%s %d/%d: brace as it lands (%s)   %s" % [TOOLS[tool].text, n + 1, beats, Controls.glyph(&"jump"),
				"..." if t < wind - 0.3 else "NOW" if t < wind + 0.15 else ""]
		if absf(pressed - wind) <= 0.2:
			held += 1
		await _wait(0.3)
	return float(held) / float(beats)


## Held B for long enough: her word. It stops everything, and that's never wrong.
func _safeword_held() -> bool:
	if Input.is_action_pressed(&"crouch"):
		_safe_t += 1.0 / 60.0
	else:
		_safe_t = 0.0
	if _safe_t >= SAFEWORD_HOLD:
		_red = true
	return _red


func _asked_colour() -> void:
	_say(_partner_name(), "Colour?")
	_body.text = "↑ Green   → Yellow   ↓ Red"
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

func _aftercare() -> void:
	var ok := not pushed and (stopped or (trust >= 0.45 and rounds >= 2) or role == "sub")
	await _fade(true)
	_untie()
	# Lull's room: a blanket, tea, a while.
	var sub := _sub_body()
	sub.global_position = Vector3(9.6, -5.0, -52.9)
	sub.rotation.y = -PI / 2.0
	var top := _top_body()
	top.global_position = Vector3(8.4, -5.0, -52.0)
	top.rotation.y = PI / 2.0
	if _cam:
		_cam.global_position = Vector3(6.0, -3.4, -51.0)
		_cam.look_at(Vector3(9.4, -4.0, -52.6), Vector3.UP)
	var blanket := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.7, 0.8, 0.5)
	blanket.mesh = bm
	blanket.material_override = Look.toon(Color("8a5a7a"))
	hub.add_child(blanket)
	blanket.global_position = sub.global_position + Vector3(0, 0.85, 0)
	await _fade(false)
	_title.text = "Aftercare"
	_keys.text = ""
	if role == "dom":
		_say("Nim", "Here. Blanket. Water. Take your time.")
		await _wait(2.0)
		_say(_partner_name(), profile.get("after", "Thank you. I needed that.") if not pushed
			else "...I said my word. I need a minute.")
	else:
		_say(_partner_name(), "Water. Blanket. Talk to me: how was that?")
		await _wait(2.2)
		_say("Nim", "Quiet. Good quiet." if not stopped else "Too much, for tonight. I'm all right.")
		await _wait(2.0)
		_say(_partner_name(), "Nothing's wrong. Sit with me a while.")
	await _wait(3.0)
	await _fade(true)
	blanket.queue_free()
	await _fade(false)
	_finish({"ok": ok, "stopped": stopped, "pushed": pushed})


func _finish(result: Dictionary) -> void:
	if _done:
		return
	_done = true
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
	_panel.visible = false
	if result.ok and not result.get("declined", false):
		Game.earn_rose(&"hub", &"hub_08" if who in ["client", "smith", "pip"] else &"hub_09")
		Hud.note("THE CROSS\nRounds: %d   Trust: %s\n%s" % [rounds, "■".repeat(int(clampf(trust, 0, 1) * 10)),
			"Stopped the moment it was asked. That counts most." if stopped else "A good scene, start to finish."], 6.0)
	finished.emit(result)


# --- small things ------------------------------------------------------------------------------------------------------

func _partner_name() -> String:
	return String(profile.get("name", "")) if role == "dom" else who.capitalize()


func _say(speaker: String, text: String, secs := 2.6) -> void:
	if text != "":
		Hud.caption(speaker, text, secs)


func _say_sub(text: String, secs := 2.2) -> void:
	if text == "":
		return
	if role == "dom" and partner is ClubClient:
		(partner as ClubClient).say(text, secs)
	else:
		_say("Nim" if role == "sub" else _partner_name(), text, secs)


func _show_meters() -> void:
	if role != "dom":
		_bar.text = ""
		return
	_bar.text = "Heat %s   Strain %s   Trust %s" % [_meter(heat / 1.2), _meter(strain), _meter(clampf(trust, 0.0, 1.0))]


func _meter(v: float) -> String:
	var n := int(round(clampf(v, 0.0, 1.0) * 10.0))
	return "■".repeat(n) + "□".repeat(10 - n)


func _show_toy(tool: String) -> void:
	if tool == "whisper":
		return
	_toy = Node3D.new()
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	match tool:
		"feather":
			bm.size = Vector3(0.05, 0.35, 0.02)
			mi.material_override = Look.toon(Color("e8c8e8"))
		"ice":
			bm.size = Vector3(0.07, 0.07, 0.07)
			mi.material_override = Look.toon(Color(0.8, 0.95, 1.0), 0.8)
		"flogger":
			bm.size = Vector3(0.05, 0.5, 0.05)
			mi.material_override = Look.toon(Color("1c1418"), 0.3)
		"paddle":
			bm.size = Vector3(0.12, 0.45, 0.03)
			mi.material_override = Look.toon(Color("3a2218"))
		_:
			bm.size = Vector3(0.02, 0.65, 0.02)
			mi.material_override = Look.toon(Color("2a1a14"))
	mi.mesh = bm
	_toy.add_child(mi)
	hub.add_child(_toy)
	_toy.global_position = TOP_AT + Vector3(0, 1.2, 0)


func _hide_toy() -> void:
	if is_instance_valid(_toy):
		_toy.queue_free()
	_toy = null


func _wait(secs: float) -> void:
	await get_tree().create_timer(secs).timeout


func _fade(to_black: bool) -> void:
	var t := create_tween()
	t.tween_property(_black, ^"color:a", 1.0 if to_black else 0.0, 0.4)
	await t.finished


func _build_ui() -> void:
	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 0)
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.08
	_panel.anchor_right = 0.92
	_panel.anchor_top = 0.6
	_panel.anchor_bottom = 0.96
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.05, 0.09, 0.9)
	sb.border_color = Color("c9a447")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(14)
	_panel.add_theme_stylebox_override(&"panel", sb)
	add_child(_panel)
	var box := VBoxContainer.new()
	_panel.add_child(box)
	_title = Label.new()
	_title.add_theme_color_override(&"font_color", Color("f2c56a"))
	box.add_child(_title)
	_body = Label.new()
	_body.add_theme_font_size_override(&"font_size", 22)
	box.add_child(_body)
	_bar = Label.new()
	box.add_child(_bar)
	_keys = Label.new()
	_keys.add_theme_color_override(&"font_color", Color("b8a8c0"))
	box.add_child(_keys)
