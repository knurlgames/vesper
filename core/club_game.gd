extends CanvasLayer
## The club's games (WO-014b, DESIGN.md "The Velvet Rope's house"). Content lines: suggestive, clothed (swimwear at
## most), consensual: every one opens with a check-in in its conversation, and "red" always ends it well.
##
## mode &"client": Nim's session with a waiting client. Each beat they show a cue (eager, distracted, strained,
##   "yellow", their safeword); she answers: up Command, right Hold, down Praise, left Check in; B Stop. Pressing on
##   through "yellow" costs their trust; on their safeword she must stop (B, or check in) within RED_TIME, or it's
##   over, badly. Stopping is a good ending: "You stopped. That's the whole job."
## mode &"switch" / &"domme" with sister "silke" or "augusta" (the owner: "allow yourself to Switch... the option to
##   Domme a sister too"):
##   silke switch: rope over the sleeves; breathe with her (hold A as the ring grows, let go as it shrinks), keep the
##     stick still; she asks your colour halfway (up green, right yellow, down red).
##   silke domme: tie her knots: each a short D-pad sequence; Y checks in (she wants asking, halfway).
##   augusta switch: hold a posture: keep the drifting balance centred with the stick; she asks your colour halfway.
##   augusta domme: she holds a posture and gets it wrong; correct each fault (up chin, down shoulders, right hands,
##     left feet); Y checks in.
## Emits finished({"ok", "stopped", "pushed", "mode", "sister"}) and frees nothing itself (club_life does).

signal finished(result: Dictionary)

const BEAT := 3.2
const BEATS := 9
const RED_TIME := 3.0
const SCENE_SECS := 30.0

## Who and what: set before it's added.
var hub: Node3D
var client: ClubClient
var sister := ""
var mode: StringName = &"client"

var _nim: Node3D
var _panel: PanelContainer
var _title: Label
var _cue: Label
var _bars: Label
var _keys: Label
var _ring: Control
var _t := 0.0
var _beat_t := 0.0
var _beat := 0
var _done := false
var _result := {}
# client
var _engage := 0.4
var _strain := 0.1
var _trust := 0.0
var _cue_kind := &"eager"
var _red_t := -1.0
var _pushed := false
var _profile := {}
# scenes
var _score := 0.0
var _asked := false
var _check_due := false
var _check_t := 0.0
var _seq: Array = []
var _seq_i := 0
var _knots := 0
var _balance := 0.0
var _drift := 0.0
var _fault := -1
var _fault_t := 0.0
var _faults_done := 0
var _rings: Array[Node3D] = []

const PROFILES := {
	"client": {"safeword": "pineapple", "tolerance": 1.0, "name": "A member's guest"},
	"smith": {"safeword": "decency", "tolerance": 1.5, "name": "\"Mr Smith\""},
	"pip": {"safeword": "teacup", "tolerance": 0.6, "name": "Pip"},
}
const CUES := {
	&"eager": ["leans in, eyes bright", "can't stop smiling", "waits for your next word"],
	&"distracted": ["glances at the door", "fidgets with a strap", "is somewhere else in their head"],
	&"strained": ["breathing fast", "jaw tight", "very, very still"],
}
const FAULTS := [["Her chin's dropped.", &"word_up", "Chin up."], ["Her shoulders have crept up.", &"word_down", "Shoulders down."],
	["Her hands are fidgeting.", &"word_right", "Hands still."], ["Her weight's on one foot.", &"word_left", "Feet together."]]
const ARROWS := {&"word_up": "↑", &"word_right": "→", &"word_down": "↓", &"word_left": "←"}


func _ready() -> void:
	layer = 6
	_nim = hub.get(&"nim")
	_nim.set_physics_process(false)
	_nim.set(&"velocity", Vector3.ZERO)
	_build_ui()
	if mode == &"client":
		_profile = PROFILES.get(client.talk_as if client else "client", PROFILES["client"])
		_face(_nim, client.global_position if client else _nim.global_position)
		if client:
			client.face_toward = _nim.global_position
		_title.text = "A session: %s   (their word: \"%s\")" % [_profile.name, _profile.safeword]
		_keys.text = "↑ Command   → Hold   ↓ Praise   ← Check in   %s Stop" % Controls.glyph(&"crouch")
		_next_beat()
	else:
		_stage_scene()


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	match mode:
		&"client":
			_client(delta)
		&"switch":
			if sister == "silke":
				_breathe(delta)
			else:
				_posture(delta)
		&"domme":
			if sister == "silke":
				_knots_game(delta)
			else:
				_corrections(delta)


# --- a client --------------------------------------------------------------------------------------------------------

func _client(delta: float) -> void:
	var act := _pressed([&"word_up", &"word_right", &"word_down", &"word_left", &"crouch"])
	if _cue_kind == &"red":
		_red_t -= delta
		if act == &"crouch" or act == &"word_left":
			_end({"ok": true, "stopped": true})
			_say_client("Thank you. Thank you for stopping.")
			Hud.note("You stopped the moment they said it. That's the whole job.", 5.0)
			return
		if act != &"" or _red_t <= 0.0:
			_end({"ok": false, "stopped": false, "pushed": true})
			Hud.caption("Vesper", "You heard the word, and you kept going. That's the one thing we never do.", 6.0)   # OWNER REVIEW
			return
		_show()
		return
	if act == &"crouch":
		_end({"ok": _trust >= 0.5, "stopped": true})
		Hud.note("You ended it there. A good session ends whenever it ends." if _trust >= 0.5 else "Over early. They'll be back.", 4.0)
		return
	if act != &"":
		_answer(act)
		_next_beat()
		return
	_beat_t -= delta
	if _beat_t <= 0.0:
		# No answer: they drift.
		_engage -= 0.08
		_next_beat()
	_show()


func _answer(act: StringName) -> void:
	var tol: float = _profile.tolerance
	match act:
		&"word_up":
			_engage += 0.22
			_strain += 0.16 / tol
			if _cue_kind == &"yellow":
				_strain += 0.3 / tol
				_trust -= 0.25
				_pushed = true
				_say_client("I said yellow...")
		&"word_right":
			_engage += 0.07
			_strain -= 0.05
		&"word_down":
			_engage += 0.1
			_strain -= 0.12
			_say_client(["Thank you, Mistress.", "Oh.", "Mm."][randi() % 3])
		&"word_left":
			_strain -= 0.28
			_engage -= 0.04
			if _cue_kind == &"yellow":
				_trust += 0.15
				_say_client("Green again. Thank you for asking.")
			else:
				_say_client("Green. Very green.")
	_engage = clampf(_engage, 0.0, 1.0)
	_strain = clampf(_strain, 0.0, 1.0)


func _next_beat() -> void:
	_beat += 1
	_beat_t = BEAT
	if _strain < 0.6:
		_trust += _engage * 0.12
	# Some of it isn't up to her: the evening has its own weather.
	_strain = clampf(_strain + randf() * 0.06 / float(_profile.tolerance), 0.0, 1.0)
	if _beat > BEATS:
		var ok := _trust >= 0.5
		_end({"ok": ok, "stopped": false})
		Hud.note("A good session: they leave lighter than they came." if ok else "It never quite caught. That happens.", 5.0)
		return
	if _strain >= 0.85:
		_cue_kind = &"red"
		_red_t = RED_TIME
		_say_client("\"%s.\"" % String(_profile.safeword).capitalize())
	elif _strain >= 0.6:
		_cue_kind = &"yellow"
		_say_client("\"Yellow.\"")
	elif _engage < 0.3:
		_cue_kind = &"distracted"
	elif _engage > 0.55 and _strain > 0.4:
		_cue_kind = &"strained"
	else:
		_cue_kind = &"eager"
	_show()


func _show() -> void:
	var cue := ""
	match _cue_kind:
		&"red":
			cue = "They say their word: \"%s\".   STOP (%s) or check in (←): %.1f" % [_profile.safeword,
				Controls.glyph(&"crouch"), maxf(_red_t, 0.0)]
		&"yellow":
			cue = "\"Yellow.\"   Slow down: hold, praise, or check in."
		_:
			var list: Array = CUES[_cue_kind]
			cue = "They %s." % list[_beat % list.size()]
	_cue.text = cue
	_bars.text = "Into it  %s     Strain  %s     Trust  %s     (%d / %d)" % [_bar(_engage), _bar(_strain),
		_bar(clampf(_trust, 0.0, 1.0)), mini(_beat, BEATS), BEATS]


func _say_client(text: String) -> void:
	if client and is_instance_valid(client):
		client.say(text, 2.6)


# --- the sisters' scenes ---------------------------------------------------------------------------------------------

## Both into the sister's room, facing; rope over the sleeves for the one being tied.
func _stage_scene() -> void:
	var s := hub.get_node_or_null(NodePath(sister.capitalize())) as Node3D
	var room: Dictionary = {}
	for r: Dictionary in Hub.ROOMS:
		if String(r.sister).to_lower() == sister:
			room = r
	if not room.is_empty():
		_nim.global_position = room.at + Vector3(0, 0.05, 0)
	if s:
		_face(_nim, s.global_position)
		_face(s, _nim.global_position)
	var tied: Node3D = _nim if (mode == &"switch") == (sister == "silke") else s
	if sister == "silke" and tied:
		for y: float in [0.95, 1.15, 1.35]:
			var ring := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = 0.24
			torus.outer_radius = 0.28
			ring.mesh = torus
			ring.material_override = Look.toon(Look.VELVET, 0.0, 0.35)
			ring.position.y = y
			tied.add_child(ring)
			_rings.append(ring)
	var who := sister.capitalize()
	match "%s_%s" % [mode, sister]:
		"switch_silke":
			_title.text = "Silke ties you (your word: \"red\")"
			_keys.text = "Hold %s as the ring grows; let go as it shrinks. Keep the stick still." % Controls.glyph(&"jump")
		"switch_augusta":
			_title.text = "Augusta's posture (your word: \"red\")"
			_keys.text = "Keep yourself centred with the stick. Breathe."
		"domme_silke":
			_title.text = "You tie Silke (her word: \"red\")"
			_keys.text = "Each knot: the arrows, in order.   %s Check in" % Controls.glyph(&"interact")
			_new_knot()
		"domme_augusta":
			_title.text = "Correct Augusta's posture (her word: \"red\")"
			_keys.text = "↑ Chin up   ↓ Shoulders down   → Hands still   ← Feet together   %s Check in" % Controls.glyph(&"interact")
	_check_t = SCENE_SECS * 0.5
	Hud.caption(who, "Ready when you are." if mode == &"switch" else "Go on, then.", 2.5)


## Halfway, the check-in: in a Switch she asks you (up green, right yellow, down red); in a Domme you must ask her (Y).
func _check_in(delta: float) -> bool:
	if _asked:
		return false
	_check_t -= delta
	if _check_t > 0.0:
		return false
	if mode == &"switch":
		_cue.text = "%s: \"Colour?\"   ↑ Green   → Yellow   ↓ Red" % sister.capitalize()
		var a := _pressed([&"word_up", &"word_right", &"word_down"])
		if a == &"":
			return true
		_asked = true
		match a:
			&"word_up":
				Hud.caption(sister.capitalize(), "Good. Stay with me.", 2.5)
			&"word_right":
				Hud.caption(sister.capitalize(), "Yellow. I'll ease off. Thank you for telling me.", 3.0)
				_score += 0.1
			&"word_down":
				_end({"ok": true, "stopped": true})
				return true
		return false
	# Domme: she's waiting to be asked.
	if Input.is_action_just_pressed(&"interact"):
		_asked = true
		Hud.caption(sister.capitalize(), "Green. ...Thank you for asking.", 2.5)
		_score += 0.15
		return false
	if _check_t < -4.0:
		_asked = true
		Hud.caption(sister.capitalize(), "You forgot to ask me how I was. Ask, next time. Always.", 3.5)
		_score -= 0.15
	return false


func _breathe(delta: float) -> void:
	if _check_in(delta):
		return
	var phase := fmod(_t, 5.0) / 5.0
	var growing := phase < 0.5
	var holding := Input.is_action_pressed(&"jump")
	var still := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down").length() < 0.3
	if holding == growing and still:
		_score += delta / SCENE_SECS
	elif not still and randf() < delta:
		Hud.caption("Silke", "Easy. I've got you.", 2.0)
	_cue.text = ("Breathe in..." if growing else "...and out.") + ("" if still else "   (still, now)")
	_ring.custom_minimum_size = Vector2.ONE * (60.0 + 80.0 * sin(phase * PI))
	_bars.text = "With her  %s" % _bar(clampf(_score * 1.4, 0.0, 1.0))
	if _t >= SCENE_SECS:
		_end({"ok": true, "stopped": false})


func _posture(delta: float) -> void:
	if _check_in(delta):
		return
	_drift = lerpf(_drift, randf_range(-1.0, 1.0), delta * 0.8)
	_balance += (_drift * 0.9 + Input.get_axis(&"move_left", &"move_right") * 1.6) * delta
	_balance = clampf(_balance, -1.0, 1.0)
	if absf(_balance) < 0.35:
		_score += delta / SCENE_SECS
	elif absf(_balance) > 0.9 and randf() < delta * 0.5:
		Hud.caption("Augusta", "And again. No hurry. You're doing beautifully.", 2.5)
	var bar := ""
	for i in 21:
		bar += "|" if i == int(round((_balance + 1.0) * 10.0)) else ("." if absf(i - 10) > 3 else "-")
	_cue.text = "Centre:  [%s]" % bar
	_bars.text = "Poise  %s" % _bar(clampf(_score * 1.4, 0.0, 1.0))
	if _t >= SCENE_SECS:
		_end({"ok": true, "stopped": false})


func _new_knot() -> void:
	_seq = []
	for i in 4:
		_seq.append([&"word_up", &"word_right", &"word_down", &"word_left"][randi() % 4])
	_seq_i = 0


func _knots_game(delta: float) -> void:
	_check_in(delta)
	if _done:
		return
	var a := _pressed([&"word_up", &"word_right", &"word_down", &"word_left"])
	if a != &"":
		if a == _seq[_seq_i]:
			_seq_i += 1
			if _seq_i >= _seq.size():
				_knots += 1
				_score += 0.12
				Hud.caption("Silke", ["Neat.", "Mm. Firm, not tight. Good.", "You've been practising."][_knots % 3], 2.0)
				if _knots >= 6:
					_end({"ok": true, "stopped": false})
					return
				_new_knot()
		else:
			Hud.caption("Silke", "Other way. ...I can see it from here.", 2.0)
			_seq_i = 0
	var shown := ""
	for i in _seq.size():
		shown += ("[%s]" if i == _seq_i else " %s ") % ARROWS[_seq[i]]
	_cue.text = "Knot %d of 6:   %s" % [_knots + 1, shown]
	_bars.text = "Her trust  %s" % _bar(clampf(_score, 0.0, 1.0))


func _corrections(delta: float) -> void:
	_check_in(delta)
	if _done:
		return
	if _fault < 0:
		_fault = randi() % FAULTS.size()
		_fault_t = 2.4
	_fault_t -= delta
	var a := _pressed([&"word_up", &"word_right", &"word_down", &"word_left"])
	var f: Array = FAULTS[_fault]
	if a == f[1]:
		Hud.caption("Nim", f[2], 1.5)
		_score += 0.1
		_faults_done += 1
		_fault = -1
	elif a != &"" or _fault_t <= 0.0:
		var wrong: String = "That was my %s, darling. You fixed something else." % ["chin", "shoulders", "hands", "feet"][_fault]
		Hud.caption("Augusta", wrong if a != &"" else "Too slow. I'd have noticed, if I were you.", 2.5)
		_faults_done += 1
		_fault = -1
	if _faults_done >= 8:
		_end({"ok": true, "stopped": false})
		return
	_cue.text = f[0] if _fault >= 0 else ""
	_bars.text = "Her approval  %s     (%d / 8)" % [_bar(clampf(_score, 0.0, 1.0)), _faults_done]


# --- shared ----------------------------------------------------------------------------------------------------------

func _pressed(actions: Array) -> StringName:
	for a: StringName in actions:
		if Input.is_action_just_pressed(a):
			return a
	return &""


func _bar(v: float) -> String:
	var n := int(round(v * 10.0))
	return "■".repeat(n) + "□".repeat(10 - n)


func _face(who: Node3D, at: Vector3) -> void:
	if who == null:
		return
	var d := at - who.global_position
	who.rotation.y = atan2(-d.x, -d.z)


func _end(result: Dictionary) -> void:
	if _done:
		return
	_done = true
	result["mode"] = mode
	result["sister"] = sister
	result["ok"] = result.get("ok", false)
	result["stopped"] = result.get("stopped", false)
	result["pushed"] = result.get("pushed", _pushed)
	_result = result
	for r in _rings:
		if is_instance_valid(r):
			r.queue_free()
	_panel.visible = false
	_nim.set_physics_process(true)
	_after.call_deferred()


## The reward, and aftercare (a conversation), then hand back.
func _after() -> void:
	if _result.ok:
		if mode == &"client":
			Game.earn_rose(&"hub", &"hub_08")
		else:
			Game.earn_rose(&"hub", &"hub_09")
	if mode != &"client":
		var label := "%s_%s_%s" % [sister, mode, "red" if _result.stopped else "after"]
		await Dialogue.run("res://data/dialogue/hub/sessions.dialogue", label)
	finished.emit(_result)


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.15
	_panel.anchor_right = 0.85
	_panel.anchor_top = 0.66
	_panel.anchor_bottom = 0.95
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
	_cue = Label.new()
	_cue.add_theme_font_size_override(&"font_size", 26)
	box.add_child(_cue)
	_bars = Label.new()
	box.add_child(_bars)
	_keys = Label.new()
	_keys.add_theme_color_override(&"font_color", Color("b8a8c0"))
	box.add_child(_keys)
	_ring = Control.new()
	box.add_child(_ring)
