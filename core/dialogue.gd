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

var _panel: PanelContainer
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
			_shown = minf(total, _shown + CPS * delta)
			for w: Dictionary in _waits:
				if int(w.at) > before and int(w.at) <= int(_shown):
					_shown = float(w.at)
					_pause = float(w.value)
					break
		_text.visible_characters = int(_shown)
	else:
		_show_choices()
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
	if _paused_by_us and not _in_cutscene:
		_paused_by_us = false
		get_tree().paused = false
	_finished[tok] = true
	_done.emit(tok)


# --- cutscenes -------------------------------------------------------------------------------------------------------

## Plays a cutscene file (or its parsed {"steps": [...]}). Await it. The world is paused throughout; the level's camera
## comes back at the end.
func play_cutscene(source: Variant) -> void:
	var data: Variant = source
	if source is String:
		data = JSON.parse_string(FileAccess.get_file_as_string(source)) if FileAccess.file_exists(source) else null
	if not data is Dictionary or not data.has("steps"):
		push_error("Dialogue: can't read cutscene %s" % str(source))
		return
	var scene := get_tree().current_scene
	var was_paused := get_tree().paused
	get_tree().paused = true
	_in_cutscene = true
	_paused_by_us = true
	var before := get_viewport().get_camera_3d()
	var cam := Camera3D.new()
	cam.process_mode = Node.PROCESS_MODE_ALWAYS
	scene.add_child(cam)
	if before:
		cam.global_transform = before.global_transform
		cam.fov = before.fov
	cam.make_current()
	for step: Dictionary in data["steps"]:
		await _step(step, scene, cam)
	if before and is_instance_valid(before):
		before.make_current()
	cam.queue_free()
	_in_cutscene = false
	_paused_by_us = false
	get_tree().paused = was_paused


func _step(step: Dictionary, scene: Node, cam: Camera3D) -> void:
	if step.has("shot"):
		var s: Dictionary = step["shot"]
		var to := Transform3D(Basis.IDENTITY, _v(s["from"])).looking_at(_v(s["look_at"]), Vector3.UP)
		var secs := float(s.get("secs", 0.0))
		if secs <= 0.0 or Game.get_setting("reduce_motion"):   # reduce motion: cuts, not camera moves
			cam.global_transform = to
		else:
			var tw := create_tween()
			tw.tween_property(cam, ^"global_transform", to, secs).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			await tw.finished
	elif step.has("move"):
		var m: Dictionary = step["move"]
		var n := scene.get_node_or_null(NodePath(m["node"])) as Node3D
		if n == null:
			push_error("Dialogue: cutscene has no node %s" % m["node"])
			return
		var to := _v(m["to"])
		var flat := Vector3(to.x - n.global_position.x, 0, to.z - n.global_position.z)
		if flat.length() > 0.05:
			n.rotation.y = atan2(-flat.x, -flat.z)
		var tw := create_tween()
		tw.tween_property(n, ^"global_position", to, float(m.get("secs", 1.0)))
		await tw.finished
	elif step.has("face"):
		var f: Dictionary = step["face"]
		var n := scene.get_node_or_null(NodePath(f["node"])) as Node3D
		if n:
			var d := _v(f["toward"]) - n.global_position
			n.rotation.y = atan2(-d.x, -d.z)
	elif step.has("say"):
		var s: Dictionary = step["say"]
		await run(String(s["file"]), String(s.get("label", "start")))
		get_tree().paused = true
	elif step.has("card"):
		_show_card(step["card"])
		await _card_closed
	elif step.has("set"):
		Game.set_flag(step["set"]["flag"], step["set"].get("value", true))
	elif step.has("wait"):
		await get_tree().create_timer(float(step["wait"]), true).timeout
	else:
		push_error("Dialogue: unknown cutscene step %s" % str(step))


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


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.12
	_panel.anchor_right = 0.88
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_top = -250.0
	_panel.offset_bottom = -28.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.06, 0.1, 0.94)
	sb.border_color = Look.VELVET.lightened(0.15)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	_panel.add_theme_stylebox_override(&"panel", sb)
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 8)
	_panel.add_child(v)
	_name = Label.new()
	_name.add_theme_font_size_override(&"font_size", 26)
	v.add_child(_name)
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
	_more.text = "..."
	_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_more.add_theme_color_override(&"font_color", Color("c9a447"))
	v.add_child(_more)
