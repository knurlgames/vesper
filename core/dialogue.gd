extends CanvasLayer
## Conversations and cutscenes (autoload "Dialogue", WO-009). The box is ported from Nine Lives: the speaker's name in
## their colour (data/dialogue/speakers.json), typewriter text with inline tags, choices. The world pauses while
## anyone talks.
##
##   await Dialogue.run("res://data/dialogue/course/vesper.dialogue", "ceiling")
##   await Dialogue.play_cutscene("res://data/cutscenes/course_intro.json")
##
## A (jump), Y (interact) or Enter finishes the line or advances; up and down pick a choice. A button already held when
## a talk opens does nothing until it's let go, and presses in the first 0.4 s are ignored, so a jump never skips a
## conversation. The format is in docs/WRITING.md.
##
## A cutscene is JSON: {"steps": [...]}, each step one of
##   {"shot": {"from": [x,y,z], "look_at": [x,y,z], "secs": 1.5}}   the camera, moved there over secs (0 = cut)
##   {"move": {"node": "path/from/scene", "to": [x,y,z], "secs": 2}}  someone walks (glides) there
##   {"face": {"node": "...", "toward": [x,y,z]}}
##   {"say": {"file": "res://...dialogue", "label": "start"}}         a conversation
##   {"card": {"kind": "newspaper" | "radio", "masthead": "...", "title": "...", "body": "..."}}   A to go on
##   {"set": {"flag": "...", "value": true}}
##   {"wait": 0.5}
## The level's camera comes back at the end.

signal _done(token: int)
signal _card_closed

const SPEAKERS_PATH := "res://data/dialogue/speakers.json"
const ADVANCE: Array[StringName] = [&"jump", &"interact", &"ui_accept"]
const CPS := 40.0
## Settings > Text speed ("text_speed": Slow, Normal, Fast, Instant): letters a second; 0 shows the line whole. The
## punctuation breaths scale with it (none at Instant).
const TEXT_SPEEDS: Array[float] = [22.0, 40.0, 75.0, 0.0]
## The typewriter's breaths (seconds), after a mark followed by a space.
const PUNCT_BEAT := {",": 0.08, ";": 0.1, ":": 0.1, ".": 0.2, "!": 0.2, "?": 0.2, "…": 0.25}
const OPEN_GUARD := 0.4

## Tests: advance automatically and take choice `auto_choice` everywhere.
var auto_advance := false
var auto_choice := 0

var _speakers := {}
var _runner: DialogueRunner
var _line := {}
var _plain := ""
var _waits: Array = []
var _shown := 0.0
var _pause := 0.0
var _choice := 0
var _open_for := 0.0
var _held_before := false
var _token := 0
var _finished := {}
var _queue: Array = []
var _paused_by_us := false
var _in_cutscene := false

## The whole box: everything below is inside it. The card (_box) runs along the bottom; the portrait's medallion
## (_medal) stands up out of its left end, or its right end for Nim, like Banjo's; the name rides on a tab (_plate)
## along the card's top edge beside the portrait.
var _panel: Control
var _box: PanelContainer
var _plate: PanelContainer
var _pad_l: Control
var _pad_r: Control
var _medal: Control
var _disc: Panel
var _face: TextureRect
var _initial: Label
var _rim: Panel
## Which end the portrait's at (-1 left, 1 right, 0 none), whose it is, its mood, and its textures (cached by path).
var _side := 0
var _who_shown := ""
var _pid := ""
var _mood := "n"
var _tex := {}
var _blink_in := 3.0
var _blink_t := -1.0
var _bob := 0.0
var _hid_ui := false
## The typing blips (owner, 2026-11-13: "add the typing blips"; tailored per character later): one synthesized blip,
## pitched by the speaker's "pitch" in speakers.json, a little jitter, every other letter.
var _blip: AudioStreamPlayer
var _blip_pitch := 1.0
var _blip_gap := 0.0
var _blip_n := 0
var _name: Label
var _text: RichTextLabel
var _choices: VBoxContainer
var _more: Label
var _card: PanelContainer
var _card_open_for := 0.0
var _card_held := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	if FileAccess.file_exists(SPEAKERS_PATH):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SPEAKERS_PATH))
		_speakers = data if data is Dictionary else {}
	_build_cinema()   # under the box, so a line said in a cutscene sits over the bars
	_build()
	_panel.visible = false


func is_active() -> bool:
	return _runner != null or _in_cutscene


func busy() -> bool:
	return is_active()


func speaker(who: String) -> Dictionary:
	return _speakers.get(who, {})


## The speakers.json key of whoever's line is on screen ("" outside a conversation). CastModel plays "talk" on it.
func current_speaker() -> String:
	return String(_line.get("speaker", "")) if _runner != null else ""


## Plays `label` of a .dialogue file (or a parsed DialogueScript). Await it. A call during a conversation queues.
func run(source: Variant, label: String = "start") -> void:
	var s: DialogueScript = source if source is DialogueScript else DialogueParser.parse_file(String(source))
	for e in s.errors:
		push_error(e)
	if not s.has_label(label):
		push_error("Dialogue: %s has no '%s'" % [s.source, label])
		return
	_token += 1
	var tok := _token
	_queue.append([s, label, tok])
	if _runner == null:
		_start_next()
	while not _finished.has(tok):
		await _done
	_finished.erase(tok)


func _start_next() -> void:
	var item: Array = _queue.pop_front()
	_runner = DialogueRunner.new(item[0], Game)
	_runner.set_meta(&"token", item[2])
	if not get_tree().paused:
		get_tree().paused = true
		_paused_by_us = true
	_held_before = ADVANCE.any(func(a: StringName) -> bool: return Input.is_action_pressed(a))
	_open_for = 0.0
	# The world's HUD steps aside while anyone talks (it showed through the card); back after, if it was up.
	var ui := _world_ui()
	if ui and ui.visible and not _panel.visible:
		ui.visible = false
		_hid_ui = true
	_panel.visible = true
	var first := _runner.start(item[1])
	if first.is_empty():
		_end()
	else:
		_show(first)


func _show(line: Dictionary) -> void:
	_line = line
	var who := String(line.speaker)
	var prof: Dictionary = _speakers.get(who, {})
	if who == "Narrator":
		_name.visible = false
	else:
		_name.visible = true
		_name.text = prof.get("name", who)
		_name.add_theme_color_override(&"font_color", Color(prof.get("color", "#f2e6c8")).lightened(0.35))
	_portrait(who, String(line.get("emotion", "neutral")), prof)
	_blip_pitch = float(prof.get("pitch", 1.0)) if who != "Narrator" else 0.0
	_blip_n = 0
	var tags := TextTags.parse(String(line.text))
	_plain = tags.text
	_waits = tags.events.filter(func(e: Dictionary) -> bool: return e.kind == "wait")
	_text.add_theme_color_override(&"default_color", Color("d8d0bc") if who == "Narrator" else Color("f6efe0"))
	_text.text = ("[i]%s[/i]" if who == "Narrator" else "%s") % _plain.replace("[", "[lb]")
	_text.visible_characters = 0
	_shown = 0.0
	_pause = 0.0
	_choice = 0
	for c in _choices.get_children():
		c.queue_free()
	_choices.visible = false


## The typing speed from Settings (letters a second; 0 for whole lines). The probes' auto_advance doesn't care.
func _cps() -> float:
	var game := get_node_or_null(^"/root/Game")
	var i := int(game.call(&"get_setting", "text_speed", 1)) if game else 1
	return TEXT_SPEEDS[clampi(i, 0, TEXT_SPEEDS.size() - 1)]


## A blip for the letters typed this frame: every other letter (not spaces or marks), no closer than BLIP_GAP apart,
## the speaker's pitch with a little jitter. The narrator types silently. Off in Settings ("text_blips").
const BLIP_GAP := 0.05


func _blips(from: int, to: int, delta: float) -> void:
	_blip_gap -= delta
	if _blip_pitch <= 0.0 or _blip == null or _cps() <= 0.0:
		return
	var game := get_node_or_null(^"/root/Game")
	if game and not bool(game.call(&"get_setting", "text_blips", true)):
		return
	for i in range(from, mini(to, _plain.length())):
		var ch := _plain[i]
		if ch == " " or PUNCT_BEAT.has(ch) or ch in "'\"-()":
			continue
		_blip_n += 1
		if _blip_n % 2 == 1 and _blip_gap <= 0.0:
			_blip.pitch_scale = _blip_pitch * randf_range(0.93, 1.07)
			_blip.play()
			_blip_gap = BLIP_GAP


## The blip itself: 55 ms of a soft tone (a sine with a little of its octave and fifth), a quick attack, a fast decay.
static func _blip_stream() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.055)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / rate
		var env := minf(t / 0.004, 1.0) * exp(-t * 55.0)
		var s := sin(TAU * 540.0 * t) * 0.7 + sin(TAU * 1080.0 * t) * 0.2 + sin(TAU * 810.0 * t) * 0.1
		data.encode_s16(i * 2, int(clampf(s * env, -1.0, 1.0) * 32767.0 * 0.8))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w


## The HUD's world readouts (Hud._world_ui), reached through the tree (autoloads can't name each other here).
func _world_ui() -> CanvasItem:
	var hud := get_node_or_null(^"/root/Hud")
	return hud.get(&"_world_ui") as CanvasItem if hud else null


# --- the portrait ------------------------------------------------------------------------------------------------------

const PORTRAITS := "res://assets/ui/portraits/%s_%s.png"
## The cast, whose portrait follows the outfit they're in (tools/portraits.gd renders each).
const CAST_PORTRAITS := ["nim", "vesper", "augusta", "silke", "dash", "rivet", "lull", "grizelda", "bastion"]
## A line's [emotion] to the portrait's face: brows up, brows down, or at rest.
const MOOD_OF := {"warm": "up", "happy": "up", "grin": "up", "laugh": "up", "shock": "up", "cold": "down",
	"sly": "down", "pleased": "up", "angry": "down"}


## Who's talking, in the medallion: their portrait in their mood, at their end of the box (Nim's on the right). A new
## speaker pops in; the same one just changes face. No portrait for the narrator; their initial if there's no picture.
func _portrait(who: String, emotion: String, prof: Dictionary) -> void:
	if who == "Narrator":
		_side = 0
		_who_shown = ""
		_medal.visible = false
		_plate.visible = false
		_pad_l.visible = false
		_pad_r.visible = false
		return
	var side := 1 if who == "Nim" else -1
	_pid = _portrait_id(who, prof)
	_mood = MOOD_OF.get(emotion, "n")
	var tex := _portrait_tex(_pid, _mood)
	_face.texture = tex
	_face.flip_h = side < 0   # the portraits look to their left: turned in, toward the words
	_initial.visible = tex == null
	_initial.text = String(prof.get("name", who)).trim_prefix("\"").left(1)
	var col := Color(prof.get("color", "#a08a70"))
	var sb := _disc.get_theme_stylebox(&"panel") as StyleBoxFlat
	sb.bg_color = col.darkened(0.55)
	_initial.add_theme_color_override(&"font_color", col.lightened(0.3))
	_medal.visible = true
	_plate.visible = true
	_pad_l.visible = side < 0
	_pad_r.visible = side > 0
	if who != _who_shown or side != _side:
		_who_shown = who
		_side = side
		_medal.scale = Vector2(0.55, 0.55)
		_medal.modulate.a = 0.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_medal, ^"scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_medal, ^"modulate:a", 1.0, 0.12)
	_blink_in = randf_range(1.5, 4.0)
	_blink_t = -1.0


## Which portrait: speakers.json's "portrait" for a body; for the cast, the outfit they're in now (Nim from the
## player, the others from whoever's standing in the scene with that name), else their garb.
func _portrait_id(who: String, prof: Dictionary) -> String:
	if prof.has("portrait"):
		return String(prof.portrait)
	var low := who.to_lower()
	if not CAST_PORTRAITS.has(low):
		return ""
	var outfit := "garb"
	var scene := get_tree().current_scene
	if low == "nim":
		var nim: Node = scene.get(&"nim") if scene else null
		var suit: Object = nim.get(&"suit") if nim else null
		if suit and suit.has_method(&"in_two_piece") and bool(suit.call(&"in_two_piece")):
			outfit = "swim"
		elif suit and suit.has_method(&"in_suit") and bool(suit.call(&"in_suit")):
			outfit = "suit"
	elif scene:
		for t: Node in scene.find_children("*", "Talker", true, false):
			if String(t.get(&"who")) == low:
				outfit = String(t.get(&"outfit"))
				break
	var id := "%s_%s" % [low, outfit]
	return id if ResourceLoader.exists(PORTRAITS % [id, "n"]) else "%s_garb" % low


func _portrait_tex(id: String, mood: String) -> Texture2D:
	if id == "":
		return null
	for m: String in [mood, "n"]:
		var path := PORTRAITS % [id, m]
		if _tex.has(path):
			return _tex[path]
		if ResourceLoader.exists(path):
			_tex[path] = load(path)
			return _tex[path]
	return null


## Each frame: the medallion and the name tab placed against the box; a bob while the words roll out; a blink now
## and then (the blink frame, if the portrait has one).
func _place_portrait(delta: float, typing: bool) -> void:
	if _side == 0:
		return
	var r := _box.get_rect()
	_bob = _bob + delta * 13.0 if typing else move_toward(_bob, roundf(_bob / PI) * PI, delta * 13.0)
	var lift := -absf(sin(_bob)) * 5.0
	var m := _medal.size
	_medal.position = Vector2(r.position.x + 14.0 if _side < 0 else r.end.x - m.x - 14.0, r.position.y - 64.0 + lift)
	var p := _plate.get_combined_minimum_size()
	_plate.size = p
	_plate.position = Vector2(r.position.x + m.x + 26.0 if _side < 0 else r.end.x - m.x - 26.0 - p.x, r.position.y - p.y * 0.6)
	if _blink_t >= 0.0:
		_blink_t += delta
		if _blink_t > 0.13:
			_blink_t = -1.0
			_face.texture = _portrait_tex(_pid, _mood)
			_blink_in = randf_range(2.0, 5.0)
	else:
		_blink_in -= delta
		if _blink_in <= 0.0 and ResourceLoader.exists(PORTRAITS % [_pid, "blink"]):
			_blink_t = 0.0
			_face.texture = _portrait_tex(_pid, "blink")


func _show_choices() -> void:
	var list: Array = _line.get("choices", [])
	if list.is_empty() or _choices.visible:
		return
	_choices.visible = true
	for i in list.size():
		var l := Label.new()
		l.add_theme_font_size_override(&"font_size", 24)
		_choices.add_child(l)
	_paint_choices()


func _paint_choices() -> void:
	var list: Array = _line.get("choices", [])
	for i in _choices.get_child_count():
		var l := _choices.get_child(i) as Label
		var on := i == _choice
		l.text = ("> " if on else "   ") + String(list[i].text)
		l.add_theme_color_override(&"font_color", Color("ffd890") if on else Color("bdb5a4"))


func _process(delta: float) -> void:
	if _in_cutscene and _runner == null and not (_card and _card.visible):
		_cutscene_input(delta)
	if _card and _card.visible:
		_card_input(delta)
		return
	if _runner == null:
		return
	_open_for += delta
	if _held_before and not ADVANCE.any(func(a: StringName) -> bool: return Input.is_action_pressed(a)):
		_held_before = false
	var total := _plain.length()
	var typing := _shown < total
	if typing:
		if _pause > 0.0:
			_pause -= delta
		else:
			var before := int(_shown)
			var cps := _cps()
			_shown = total if cps <= 0.0 else minf(total, _shown + cps * delta)
			for w: Dictionary in _waits:
				if int(w.at) > before and int(w.at) <= int(_shown):
					_shown = float(w.at)
					_pause = float(w.value)
					break
			_blips(before, int(_shown), delta)
			# The typewriter takes a breath at punctuation: a beat at a comma, longer at the end of a sentence.
			for i in range(before, int(_shown)):
				var ch := _plain[i]
				var next := _plain[i + 1] if i + 1 < total else " "
				if next != " ":
					continue
				var beat: float = PUNCT_BEAT.get(ch, 0.0) * (CPS / cps if cps > 0.0 else 0.0)
				if beat > 0.0:
					_shown = float(i + 1)
					_pause = maxf(_pause, beat)
					break
		_text.visible_characters = int(_shown)
	else:
		_show_choices()
	_place_portrait(delta, typing and _pause <= 0.0)
	_more.visible = not typing and _line.get("choices", []).is_empty()
	if auto_advance:
		_shown = total
		_text.visible_characters = -1
		_advance()
		return
	var has_choices := not (_line.get("choices", []) as Array).is_empty()
	if not typing and has_choices:
		var n := (_line.choices as Array).size()
		if Input.is_action_just_pressed(&"ui_down") or Input.is_action_just_pressed(&"move_down"):
			_choice = (_choice + 1) % n
			_paint_choices()
		elif Input.is_action_just_pressed(&"ui_up") or Input.is_action_just_pressed(&"move_up"):
			_choice = (_choice + n - 1) % n
			_paint_choices()
	if _open_for < OPEN_GUARD or _held_before:
		return
	if ADVANCE.any(func(a: StringName) -> bool: return Input.is_action_just_pressed(a)):
		if typing:
			_shown = total
			_text.visible_characters = -1
			_pause = 0.0
		else:
			_advance()


func _advance() -> void:
	var nxt: Dictionary
	if not (_line.get("choices", []) as Array).is_empty():
		nxt = _runner.choose(auto_choice if auto_advance else _choice)
	else:
		nxt = _runner.next()
	if nxt.is_empty():
		_end()
	else:
		_show(nxt)


func _end() -> void:
	var tok: int = _runner.get_meta(&"token")
	_runner = null
	_line = {}
	if not _queue.is_empty():
		_finished[tok] = true
		_done.emit(tok)
		_start_next()
		return
	_panel.visible = false
	_who_shown = ""   # the next conversation's first speaker pops in again
	if _hid_ui:
		_hid_ui = false
		var ui := _world_ui()
		if ui:
			ui.visible = true
	if _paused_by_us and not _in_cutscene:
		_paused_by_us = false
		get_tree().paused = false
	_finished[tok] = true
	_done.emit(tok)


# --- cutscenes -------------------------------------------------------------------------------------------------------

## Plays a cutscene file (or its parsed {"steps": [...]}). Await it. The level's camera comes back at the end.
## Cinematic (owner, 2026-11-13: "solid cinematic esque cutscenes"): letterbox bars slide in and out, the world HUD
## steps aside, and holding B (or Start) skips to the end: what's left is done at once (flags set, people moved,
## the camera's last place), nothing shown; its lines ("say") still play, to be read or tapped through.
## {"live": true} keeps the world running (people walk, rain falls) with Nim held still; otherwise it's paused.
## Steps besides those at the top of this file:
##   {"shot": {"node": "Dash", "from": [x,y,z], "look_at": [x,y,z], "secs": 3}}   from and look_at offsets from a node
##   {"track": {"node": "...", "offset": [x,y,z], "look": [x,y,z], "secs": 2}}  the camera rides with someone, in their
##                                                                              own frame (-Z is the way they face)
##   {"walk": {"node": "...", "to": [[x,y,z], ...], "speed": 1.6}}             walks them there (walk_path), not waited
##   {"fade": {"to": 1.0, "secs": 0.6}}       to black (1) or back (0)
##   {"caption": "text"}                       a line in the lower bar until the next caption ("" clears it)
##   {"fov": 40}
##   {"anim": {"node": "Nim", "clip": "bind"}}  a one-shot clip on someone's model
##   {"call": {"node": "Gander", "method": "tape_gag", "args": []}}   a scene node's method (always, even skipped)
signal cutscene_step(index: int)

## Probes set this (tools/probe_driver.gd): every cutscene skips straight to its end.
var skip_cutscenes := false
var _skip := false
var _skip_hold := 0.0
var _bars: Array[ColorRect] = []
var _fade: ColorRect
var _caption: Label
var _skip_hint: Label
const BAR := 0.11   # each bar, a share of the screen's height
const SKIP_HOLD := 0.7


func play_cutscene(source: Variant) -> void:
	var data: Variant = source
	if source is String:
		data = JSON.parse_string(FileAccess.get_file_as_string(source)) if FileAccess.file_exists(source) else null
	if not data is Dictionary or not data.has("steps"):
		push_error("Dialogue: can't read cutscene %s" % str(source))
		return
	var scene := get_tree().current_scene
	var live := bool(data.get("live", false))
	var was_paused := get_tree().paused
	_in_cutscene = true
	_skip = skip_cutscenes
	_skip_hold = 0.0
	var nim := scene.get(&"nim") as Node3D
	var held_nim := false
	if live:
		if nim and nim.is_physics_processing():
			nim.set_physics_process(false)
			if nim.get(&"velocity") != null:
				nim.set(&"velocity", Vector3.ZERO)
			held_nim = true
	else:
		get_tree().paused = true
		_paused_by_us = true
	var ui := _world_ui()
	var hid := ui != null and ui.visible
	if hid:
		ui.visible = false
	var before := get_viewport().get_camera_3d()
	var cam := Camera3D.new()
	cam.process_mode = Node.PROCESS_MODE_ALWAYS
	scene.add_child(cam)
	if before:
		cam.global_transform = before.global_transform
		cam.fov = before.fov
	cam.make_current()
	_letterbox(true)
	# Name tags and place names (the billboarded labels; painted signs aren't) step aside too.
	var tags: Array[Label3D] = []
	for l: Node in scene.find_children("*", "Label3D", true, false):
		var lab := l as Label3D
		if lab.visible and lab.billboard != BaseMaterial3D.BILLBOARD_DISABLED:
			lab.visible = false
			tags.append(lab)
	var steps: Array = data["steps"]
	for i in steps.size():
		if not is_instance_valid(scene) or not scene.is_inside_tree():
			break
		if OS.get_environment("CUTSCENE_TRACE") != "":
			print("cutscene %s step %d %s skip=%s" % [str(source).get_file(), i, (steps[i] as Dictionary).keys(), _skip])
		await _step(steps[i], scene, cam, live)
		cutscene_step.emit(i)
	_caption.text = ""
	_skip_hint.visible = false
	_letterbox(false)
	if _fade.color.a > 0.0:
		var tw := create_tween()
		tw.tween_property(_fade, ^"color:a", 0.0, 0.0 if _skip else 0.35)
	if before and is_instance_valid(before):
		before.make_current()
	if is_instance_valid(cam):
		cam.queue_free()
	for lab in tags:
		if is_instance_valid(lab):
			lab.visible = true
	if held_nim and is_instance_valid(nim):
		nim.set_physics_process(true)
	if hid and is_instance_valid(ui):
		ui.visible = true
	_in_cutscene = false
	_skip = false
	if not live:
		_paused_by_us = false
		get_tree().paused = was_paused


func _step(step: Dictionary, scene: Node, cam: Camera3D, live := false) -> void:
	if step.has("shot"):
		var s: Dictionary = step["shot"]
		var base := Vector3.ZERO
		if s.has("node"):
			var n := _node(scene, s["node"]) as Node3D
			if n:
				base = n.global_position
		var to := Transform3D(Basis.IDENTITY, base + _v(s["from"])).looking_at(base + _v(s["look_at"]), Vector3.UP)
		var secs := float(s.get("secs", 0.0))
		if s.has("start_from"):   # a move that starts somewhere of its own (a cut, then the move)
			cam.global_transform = Transform3D(Basis.IDENTITY, base + _v(s["start_from"])).looking_at(
				base + _v(s.get("start_look", s["look_at"])), Vector3.UP)
		if secs <= 0.0 or _skip or Game.get_setting("reduce_motion"):   # reduce motion: cuts, not camera moves
			cam.global_transform = to
			if secs > 0.0:
				await _hold(secs)
		else:
			var from := cam.global_transform
			var t := 0.0
			while t < secs and not _skip:
				t += get_process_delta_time()
				var u := 0.5 - 0.5 * cos(PI * clampf(t / secs, 0.0, 1.0))
				cam.global_transform = from.interpolate_with(to, u)
				await get_tree().process_frame
			cam.global_transform = to
	elif step.has("track"):
		var s: Dictionary = step["track"]
		var n := _node(scene, s["node"]) as Node3D
		var t := 0.0
		var secs := float(s.get("secs", 2.0))
		while n and t < secs and not _skip:
			var xf := n.global_transform
			var eye := xf * _v(s.get("offset", [0, 1.6, -1.5]))
			var look := xf * _v(s.get("look", [0, 1.5, 0]))
			cam.global_transform = Transform3D(Basis.IDENTITY, eye).looking_at(look, Vector3.UP)
			t += get_process_delta_time()
			await get_tree().process_frame
	elif step.has("move"):
		var m: Dictionary = step["move"]
		var n := _node(scene, m["node"]) as Node3D
		if n == null:
			push_error("Dialogue: cutscene has no node %s" % m["node"])
			return
		var to := _v(m["to"])
		var flat := Vector3(to.x - n.global_position.x, 0, to.z - n.global_position.z)
		if flat.length() > 0.05:
			n.rotation.y = atan2(-flat.x, -flat.z)
		if _skip:
			n.global_position = to
			return
		var tw := create_tween()
		tw.tween_property(n, ^"global_position", to, float(m.get("secs", 1.0)))
		await tw.finished
	elif step.has("walk"):
		var w: Dictionary = step["walk"]
		var n := _node(scene, w["node"]) as Node3D
		var pts: Array[Vector3] = []
		for p: Array in w["to"]:
			pts.append(_v(p))
		if n and not pts.is_empty():
			if _skip or not n.has_method(&"walk_path"):
				n.global_position = pts[-1]
			else:
				n.call(&"walk_path", pts, float(w.get("speed", 1.6)))
	elif step.has("face"):
		var f: Dictionary = step["face"]
		var n := _node(scene, f["node"]) as Node3D
		if n:
			var d := _v(f["toward"]) - n.global_position
			n.rotation.y = atan2(-d.x, -d.z)
	elif step.has("say"):
		# Lines always play, skipped or not (a scene's words can set flags; skipping is for the camera work).
		var s: Dictionary = step["say"]
		await run(String(s["file"]), String(s.get("label", "start")))
		get_tree().paused = not live
	elif step.has("card"):
		if _skip:
			return
		_show_card(step["card"])
		await _card_closed
	elif step.has("set"):
		Game.set_flag(step["set"]["flag"], step["set"].get("value", true))
	elif step.has("wait"):
		await _hold(float(step["wait"]))
	elif step.has("fade"):
		var f: Dictionary = step["fade"]
		var to := float(f.get("to", 1.0))
		var secs := float(f.get("secs", 0.5))
		if _skip or secs <= 0.0:
			_fade.color.a = to
			return
		var tw := create_tween()
		tw.tween_property(_fade, ^"color:a", to, secs)
		while tw.is_running() and not _skip:
			await get_tree().process_frame
		_fade.color.a = to
	elif step.has("caption"):
		_caption.text = "" if _skip else String(step["caption"])
		_caption.modulate.a = 0.0
		if _caption.text != "":
			create_tween().tween_property(_caption, ^"modulate:a", 1.0, 0.4)
	elif step.has("fov"):
		cam.fov = float(step["fov"])
	elif step.has("anim"):
		# A one-shot clip on someone's model (Nim's `bind`, say): their node, or its `model`.
		var a: Dictionary = step["anim"]
		var n := _node(scene, a["node"])
		var m: Object = n.get(&"model") if n and n.get(&"model") != null else n
		if m and not _skip:
			if m.has_method(&"_play_once"):
				m.call(&"_play_once", StringName(a["clip"]))
			elif m.has_method(&"play_once"):
				m.call(&"play_once", StringName(a["clip"]))
	elif step.has("call"):
		# A method on a node in the scene (a boss's script taping its own mouth shut): always called, skipped or not.
		var c: Dictionary = step["call"]
		var n := _node(scene, c["node"])
		if n and n.has_method(StringName(c["method"])):
			var r: Variant = n.callv(StringName(c["method"]), c.get("args", []))
			if r is Signal:
				await r
	else:
		push_error("Dialogue: unknown cutscene step %s" % str(step))


## A cutscene's node: a path from the scene, or failing that, the first node anywhere in it with that name (the Keys'
## people live under their Key's node).
func _node(scene: Node, path: String) -> Node:
	var n := scene.get_node_or_null(NodePath(path))
	return n if n else scene.find_child(path, true, false)


## Waits `secs` (the world paused or not), or until the scene's skipped.
func _hold(secs: float) -> void:
	var t := 0.0
	while t < secs and not _skip:
		t += get_process_delta_time()
		await get_tree().process_frame


## The bars in (or out), over a third of a second.
func _letterbox(on: bool) -> void:
	var h := get_viewport().get_visible_rect().size.y * BAR
	for i in _bars.size():
		var bar := _bars[i]
		var tw := create_tween()
		tw.tween_property(bar, ^"custom_minimum_size:y", h if on else 0.0, 0.0 if _skip else 0.35) \
			.set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(bar, ^"size:y", h if on else 0.0, 0.0 if _skip else 0.35).set_trans(Tween.TRANS_SINE)


## Hold B (crouch), Start or Escape to skip: the hint shows how long's left to hold.
func _cutscene_input(delta: float) -> void:
	var held := Input.is_action_pressed(&"crouch") or Input.is_action_pressed(&"pause") or Input.is_action_pressed(&"ui_cancel")
	_skip_hold = _skip_hold + delta if held else 0.0
	if _skip_hold >= SKIP_HOLD:
		_skip = true
	var any := held or Input.is_action_pressed(&"jump") or Input.is_action_pressed(&"interact")
	if any and not _skip:
		_skip_hint.visible = true
	var pips := int(clampf(_skip_hold / SKIP_HOLD, 0.0, 1.0) * 6.0)
	_skip_hint.text = "Hold %s to skip  %s" % [Controls.glyph(&"crouch"), "●".repeat(pips) + "○".repeat(6 - pips)]


func _build_cinema() -> void:
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_left = 0.0
		bar.anchor_right = 1.0
		bar.anchor_top = 0.0 if top else 1.0
		bar.anchor_bottom = 0.0 if top else 1.0
		bar.grow_vertical = Control.GROW_DIRECTION_END if top else Control.GROW_DIRECTION_BEGIN
		add_child(bar)
		_bars.append(bar)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)
	_caption = Label.new()
	_caption.anchor_left = 0.1
	_caption.anchor_right = 0.9
	_caption.anchor_top = 1.0 - BAR
	_caption.anchor_bottom = 1.0
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.add_theme_font_override(&"font", UiKit.display())
	_caption.add_theme_font_size_override(&"font_size", 30)
	_caption.add_theme_color_override(&"font_color", UiKit.CREAM)
	_caption.add_theme_color_override(&"font_outline_color", UiKit.INK)
	_caption.add_theme_constant_override(&"outline_size", 6)
	add_child(_caption)
	_skip_hint = Label.new()
	_skip_hint.anchor_left = 1.0
	_skip_hint.anchor_right = 1.0
	_skip_hint.anchor_top = 0.0
	_skip_hint.anchor_bottom = 0.0
	_skip_hint.offset_left = -360.0
	_skip_hint.offset_right = -24.0
	_skip_hint.offset_top = 18.0
	_skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skip_hint.add_theme_font_size_override(&"font_size", 18)
	_skip_hint.add_theme_color_override(&"font_color", UiKit.DIM)
	_skip_hint.visible = false
	add_child(_skip_hint)


func _v(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])


## A newspaper's front page or a radio bulletin, full screen. A (or Y, or Enter) to go on.
func _show_card(c: Dictionary) -> void:
	if _card:
		_card.queue_free()
	var paper: bool = c.get("kind", "newspaper") == "newspaper"
	_card = PanelContainer.new()
	_card.anchor_left = 0.18
	_card.anchor_right = 0.82
	_card.anchor_top = 0.12
	_card.anchor_bottom = 0.88
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("efe4c8") if paper else Color("1a1420")
	sb.border_color = Color("1f2a4a") if paper else Color("c9a447")
	sb.set_border_width_all(4)
	sb.set_content_margin_all(36)
	_card.add_theme_stylebox_override(&"panel", sb)
	add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 18)
	_card.add_child(col)
	var ink := Color("1a1a24") if paper else Color("f2e6c8")
	var mast := Label.new()
	mast.text = c.get("masthead", "THE EVENING PAW" if paper else "RADIO PURRLANDS")
	mast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mast.add_theme_font_size_override(&"font_size", 26)
	mast.add_theme_color_override(&"font_color", ink.lerp(Color("8a2b4a"), 0.0 if paper else 0.6))
	col.add_child(mast)
	var title := Label.new()
	title.text = c.get("title", "")
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 44 if paper else 34)
	title.add_theme_color_override(&"font_color", ink)
	col.add_child(title)
	var body := Label.new()
	body.text = c.get("body", "")
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override(&"font_size", 22)
	body.add_theme_color_override(&"font_color", ink)
	col.add_child(body)
	var more := Label.new()
	more.text = "(A)"
	more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	more.add_theme_color_override(&"font_color", ink.lerp(Color("c9a447"), 0.5))
	col.add_child(more)
	_card_open_for = 0.0
	_card_held = ADVANCE.any(func(a: StringName) -> bool: return Input.is_action_pressed(a))


func _card_input(delta: float) -> void:
	_card_open_for += delta
	if _card_held and not ADVANCE.any(func(a: StringName) -> bool: return Input.is_action_pressed(a)):
		_card_held = false
	if auto_advance or (_card_open_for >= OPEN_GUARD and not _card_held \
			and ADVANCE.any(func(a: StringName) -> bool: return Input.is_action_just_pressed(a))):
		_card.queue_free()
		_card = null
		_card_closed.emit()


## The box, Banjo-style (owner, 2026-11-13: "a sleek Banjo style with a portrait of who is talking and a typewriter
## roll out"): a low velvet card across the bottom, the speaker's portrait standing up out of one end in a gold-rimmed
## medallion, their name on a tab along the card's top edge, the words typed out.
const MEDAL := 232.0


func _build() -> void:
	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_blip = AudioStreamPlayer.new()
	_blip.stream = _blip_stream()
	_blip.volume_db = -9.0
	_blip.max_polyphony = 2
	add_child(_blip)
	_box = PanelContainer.new()
	_box.anchor_left = 0.07
	_box.anchor_right = 0.93
	_box.anchor_top = 1.0
	_box.anchor_bottom = 1.0
	_box.offset_top = -222.0
	_box.offset_bottom = -26.0
	# The game's card (core/ui_kit.gd): velvet, a gold rim.
	var sb := UiKit.card(22, 0.95)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 26
	sb.content_margin_bottom = 14
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 4)
	_box.add_theme_stylebox_override(&"panel", sb)
	_panel.add_child(_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 0)
	_box.add_child(row)
	# Room in the card for the portrait at whichever end it's on.
	_pad_l = Control.new()
	_pad_l.custom_minimum_size = Vector2(MEDAL - 10.0, 0)
	row.add_child(_pad_l)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	_pad_r = Control.new()
	_pad_r.custom_minimum_size = Vector2(MEDAL - 10.0, 0)
	row.add_child(_pad_r)
	# The medallion: a disc in the speaker's colour, the portrait clipped to it, a gold rim over the edge.
	_medal = Control.new()
	_medal.size = Vector2(MEDAL, MEDAL)
	_medal.pivot_offset = Vector2(MEDAL, MEDAL) / 2.0
	_medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_medal)
	_disc = Panel.new()
	_disc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_disc.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var disc_sb := StyleBoxFlat.new()
	disc_sb.bg_color = UiKit.PLUM_LIGHT
	disc_sb.set_corner_radius_all(int(MEDAL / 2.0))
	disc_sb.anti_aliasing = true
	_disc.add_theme_stylebox_override(&"panel", disc_sb)
	_medal.add_child(_disc)
	# A soft light behind the head, so dark fur still reads on a dark disc.
	var glow := Panel.new()
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.offset_left = MEDAL * 0.18
	glow.offset_right = -MEDAL * 0.18
	glow.offset_top = MEDAL * 0.08
	glow.offset_bottom = -MEDAL * 0.28
	var glow_sb := StyleBoxFlat.new()
	glow_sb.bg_color = Color(1, 0.92, 0.8, 0.16)
	glow_sb.set_corner_radius_all(int(MEDAL / 2.0))
	glow_sb.shadow_color = Color(1, 0.92, 0.8, 0.12)
	glow_sb.shadow_size = 24
	glow.add_theme_stylebox_override(&"panel", glow_sb)
	_disc.add_child(glow)
	_face = TextureRect.new()
	_face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_disc.add_child(_face)
	_initial = Label.new()
	_initial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_initial.add_theme_font_override(&"font", UiKit.display())
	_initial.add_theme_font_size_override(&"font_size", 110)
	_disc.add_child(_initial)
	_rim = Panel.new()
	_rim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var rim_sb := StyleBoxFlat.new()
	rim_sb.draw_center = false
	rim_sb.set_corner_radius_all(int(MEDAL / 2.0))
	rim_sb.set_border_width_all(6)
	rim_sb.border_color = UiKit.GOLD
	rim_sb.anti_aliasing = true
	rim_sb.shadow_color = Color(0, 0, 0, 0.5)
	rim_sb.shadow_size = 8
	_rim.add_theme_stylebox_override(&"panel", rim_sb)
	_medal.add_child(_rim)
	# The name tab.
	_plate = PanelContainer.new()
	var plate_sb := UiKit.flat(UiKit.VELVET, UiKit.GOLD, 3, 12, Vector4(18, 4, 18, 6))
	_plate.add_theme_stylebox_override(&"panel", plate_sb)
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_plate)
	_name = Label.new()
	_name.add_theme_font_override(&"font", UiKit.display())
	_name.add_theme_font_size_override(&"font_size", 28)
	_name.add_theme_color_override(&"font_outline_color", UiKit.INK)
	_name.add_theme_constant_override(&"outline_size", 6)
	_plate.add_child(_name)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.add_theme_font_size_override(&"normal_font_size", 25)
	_text.add_theme_font_size_override(&"italics_font_size", 25)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_text)
	_choices = VBoxContainer.new()
	v.add_child(_choices)
	_more = Label.new()
	_more.text = "»"
	_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_more.add_theme_color_override(&"font_color", UiKit.GOLD)
	v.add_child(_more)
