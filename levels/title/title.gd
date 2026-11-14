extends Control
## The title screen (WO-010; rebuilt 2026-11-13, owner: "a proper title screen and then file load screen... a small
## cutscene that plays in the background with the working title 'Vesper's Kinky Kapers' listed and 'Press Any Button'.
## Then, the file select loads into a fun, interactive screen... each save is a location in that dungeon").
##
##   press   the rooftop cutscene loops behind the logo (levels/title/title_stage.gd); any button goes on
##   files   down to the vaults (levels/title/file_select.gd): Nim walks the corridor (left and right), A does what the
##           room's for, Y erases a save (asked twice), B goes back up to the roof:
##             The Quiet Room   content notes, and the extras (the cast stage, the Pier straight in)
##             The Rope Room, The Parlour, The Throne Room   saves 1 to 3: A plays (new or continued)
##             The Workshop     settings
##             The Front Door   quit (A twice)
##   content, extras   their cards, over the vaults
## Pad, keys and mouse throughout (the arrows and the card's buttons click). The age gate comes first on a new machine.
## Every name and button in Title Case.

const Stage := preload("res://levels/title/title_stage.gd")
const Vaults := preload("res://levels/title/file_select.gd")
## The rooms, left to right: [name, what it's for, the sister's line (empty save / a save in it, for the slots)].
## OWNER REVIEW: every line.
const ROOMS := [
	["The Quiet Room", "content", "Lull: \"Content notes, and a few things still in progress. Take your time.\""],
	["The Rope Room", "slot", "Silke: \"A new rope, a new start.\"", "Silke: \"Your knots are right where you left them.\""],
	["The Parlour", "slot", "Augusta: \"A fresh page, darling. Do write something scandalous.\"",
		"Augusta: \"Your bookmark's exactly where you left it. I checked.\""],
	["The Throne Room", "slot", "Grizelda: \"Nobody's sat here yet. Don't make it weird.\"",
		"Grizelda: \"Your boots are still by the door. Polished. Not by me.\""],
	["The Workshop", "settings", "Rivet: \"Settings! I've labelled every dial. Twice.\""],
	["The Front Door", "quit", "Dash: \"Leaving? Race you to the door!\""],
]
const FIRST_SLOT_ROOM := 1

var screen := ""
## The room Nim's at (the vaults), for the probes.
var room := 1
## The stick's latched direction in the vaults (-1, 0, 1): a push past STICK_PUSH steps one room; it rearms once the
## stick is back under STICK_REST.
const STICK_PUSH := 0.6
const STICK_REST := 0.3
var _stick_dir := 0
var stage: Node3D
var _view: SubViewport
var _ui: Control
var _fade: ColorRect
var _stage_box: Control
var _confirm := ""
var _t := 0.0
var _act_btn: Button
var _erase_btn: Button
var _busy := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Hud.show_world_ui(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("0e0a14")
	add_child(bg)
	# The 3D behind it all: its own world, in a SubViewport the size of the screen.
	var box := SubViewportContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.stretch = true
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_view = SubViewport.new()
	_view.own_world_3d = true
	_view.msaa_3d = Viewport.MSAA_2X
	box.add_child(_view)
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.draw.connect(_draw_ui)
	add_child(_ui)
	# The card's buttons and the arrows, for the mouse (the pad uses its own buttons: these take no focus).
	_act_btn = _mouse_button("Act", _act)
	_erase_btn = _mouse_button("Erase", _erase)
	_mouse_button("Prev", func() -> void: _walk(-1)).name = "Prev"
	_mouse_button("Next", func() -> void: _walk(1)).name = "Next"
	_stage_box = Control.new()   # menus over the vaults (content, extras)
	_stage_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage_box.mouse_filter = Control.MOUSE_FILTER_IGNORE   # (its menus take clicks; the empty screen mustn't)
	add_child(_stage_box)
	_fade = ColorRect.new()
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	Hud.age_gate()
	show_press()


func _mouse_button(node_name: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.name = node_name
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	b.modulate.a = 0.0   # (the card draws them; this takes the click)
	b.pressed.connect(on_press)
	add_child(b)
	return b


func _set_stage(s: Node3D) -> void:
	if stage:
		_view.remove_child(stage)
		stage.queue_free()
	stage = s
	_view.add_child(s)


func _fade_to(a: float, secs := 0.35) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, ^"color:a", a, secs)
	await tw.finished


# --- the screens -----------------------------------------------------------------------------------------------------

func show_press() -> void:
	screen = "press"
	_clear()
	if not (stage is Stage):
		_set_stage(Stage.new())


## Down to the vaults, at the room of the save in play.
func show_files() -> void:
	_busy = true
	await _fade_to(1.0)
	screen = "files"
	_clear()
	var v: Node3D = Vaults.new()
	_set_stage(v)
	room = FIRST_SLOT_ROOM + clampi(Game.slot - 1, 0, Game.SLOTS - 1)
	v.call(&"jump_to", room)
	for i in ROOMS.size():
		var r: Array = ROOMS[i]
		v.call(&"set_plaque", i, "Save %d" % (i - FIRST_SLOT_ROOM + 1) if r[1] == "slot" else String(r[0]))
	v.connect(&"arrived", func(i: int) -> void: room = i)
	await _fade_to(0.0)
	_busy = false


## Back up to the roof.
func show_roof() -> void:
	_busy = true
	await _fade_to(1.0)
	_set_stage(Stage.new())
	show_press()
	await _fade_to(0.0)
	_busy = false


func show_content() -> void:
	screen = "content"
	_clear()
	var col := Menu.panel(_stage_box, 700.0)
	Menu.heading(col, Hud.AgeGate.TITLE, 34)
	Menu.text(col, Hud.AgeGate.BODY, 18, Menu.INK)
	Menu.button(col, "Back", _back_to_files)
	Menu.focus_first.call_deferred(col)


func show_extras() -> void:
	screen = "extras"
	_clear()
	var col := Menu.panel(_stage_box, 460.0)
	Menu.heading(col, "The Quiet Room", 34)
	Menu.button(col, "Content notes", show_content).name = "Content"
	# A test scene, not the game: every cast body on screen with a frame-rate readout (levels/cast_stage).
	Menu.button(col, "Cast stage (perf test)", func() -> void: Game.travel(Game.CAST_STAGE)).name = "CastStage"
	Menu.button(col, "The Pier (straight in)", func() -> void: Game.travel(Game.SCENES[&"pier"], "start")).name = "Pier"
	Menu.button(col, "Back", _back_to_files).name = "Back"
	Menu.focus_first.call_deferred(col)


func _back_to_files() -> void:
	_clear()
	screen = "files"


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(Hud.gate) or Hud.settings_open() or _busy:
		return
	match screen:
		"press":
			var pressed := (event is InputEventJoypadButton or event is InputEventKey or event is InputEventMouseButton) \
				and event.is_pressed() and not event.is_echo()
			if pressed:
				get_viewport().set_input_as_handled()
				show_files()
		"files":
			# The stick sends a stream of motion events, and every one past the deadzone reads as a fresh press:
			# one push ran her to the end of the corridor (owner, on the Deck). A push is one room now; the stick
			# has to come back to the middle before it moves her again.
			if event is InputEventJoypadMotion:
				if event.axis == JOY_AXIS_LEFT_X:
					var dir := 0
					if absf(event.axis_value) > STICK_PUSH:
						dir = signi(int(signf(event.axis_value)))
					elif absf(event.axis_value) > STICK_REST:
						dir = _stick_dir   # in between: no change, so a wobble near the edge can't re-trigger
					if dir != 0 and dir != _stick_dir:
						_walk(dir)
					_stick_dir = dir
				get_viewport().set_input_as_handled()
				return
			if event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"move_left"):
				_walk(-1)
			elif event.is_action_pressed(&"ui_right") or event.is_action_pressed(&"move_right"):
				_walk(1)
			elif event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"jump"):
				_act()
			elif event.is_action_pressed(&"interact"):
				_erase()
			elif event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"crouch"):
				show_roof()
			else:
				return
			get_viewport().set_input_as_handled()
		"content", "extras":
			if event.is_action_pressed(&"ui_cancel"):
				get_viewport().set_input_as_handled()
				_back_to_files()


func _walk(d: int) -> void:
	if screen != "files":
		return
	_confirm = ""
	var to := clampi(room + d, 0, ROOMS.size() - 1)
	if to == room:
		return
	room = to
	stage.call(&"go_to", to)


## A on a room: what it's for.
func _act() -> void:
	if screen != "files" or bool(stage.get(&"walking")):
		return
	var r: Array = ROOMS[room]
	match r[1]:
		"content":
			show_extras()
		"slot":
			_play(room - FIRST_SLOT_ROOM + 1)
		"settings":
			Hud.open_settings(func() -> void: pass)
		"quit":
			if _confirm == "quit":
				get_tree().quit()
			else:
				_confirm = "quit"


## Y on a save's room: erase it (asked twice).
func _erase() -> void:
	if screen != "files" or ROOMS[room][1] != "slot":
		return
	var n := room - FIRST_SLOT_ROOM + 1
	if Game.slot_summary(n).is_empty():
		return
	if _confirm != "erase":
		_confirm = "erase"
		return
	_confirm = ""
	Game.erase_slot(n)


func _play(n: int) -> void:
	if n != Game.slot:
		Game.use_slot(n)
	_busy = true
	await _fade_to(1.0, 0.5)
	Game.travel(Game.START_SCENE)


## Out with the old menu, at once: one rebuilt in the same frame mustn't find (or focus) the old one's nodes.
func _clear() -> void:
	for c in _stage_box.get_children():
		_stage_box.remove_child(c)
		c.queue_free()


# --- drawing the logo and the cards --------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	_ui.queue_redraw()
	_place_mouse_buttons()


func _draw_ui() -> void:
	var vp := _ui.size
	if screen == "press":
		# A dusk over the top of the shot, and the bottom: the logo and the prompt read over any of it.
		_shade(Rect2(0, 0, vp.x, vp.y * 0.5), 0.62, 0.0)
		_shade(Rect2(0, vp.y * 0.7, vp.x, vp.y * 0.3), 0.0, 0.6)
		_draw_logo(vp, Vector2(vp.x / 2.0, vp.y * 0.24), 1.0)
		var a := 0.55 + 0.45 * sin(_t * 3.2)
		UiKit.text(_ui, UiKit.display(), Vector2(0, vp.y * 0.86), "Press Any Button", 34, Color(UiKit.CREAM, a),
			HORIZONTAL_ALIGNMENT_CENTER, vp.x, 10)
		UiKit.text(_ui, UiKit.bold(), Vector2(0, vp.y - 18), "Adults Only.  A Working Title.", 14, Color(UiKit.DIM, 0.8),
			HORIZONTAL_ALIGNMENT_CENTER, vp.x, 4)
	elif screen == "files":
		_shade(Rect2(0, 0, vp.x, 140), 0.5, 0.0)
		_draw_logo(vp, Vector2(200, 62), 0.42)
		_draw_header(vp)
		_draw_card(vp)


## A dark band fading from `top` alpha to `bottom`.
func _shade(r: Rect2, top: float, bottom: float) -> void:
	var c0 := Color(0.04, 0.02, 0.07, top)
	var c1 := Color(0.04, 0.02, 0.07, bottom)
	_ui.draw_polygon(PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y)]),
		PackedColorArray([c0, c0, c1, c1]))


## The logo (UiKit.draw_logo, shared with the store art), bobbing gently.
func _draw_logo(_vp: Vector2, c: Vector2, s: float) -> void:
	UiKit.draw_logo(_ui, c + Vector2(0, sin(_t * 1.4) * 4.0 * s), s, _t)


func _draw_header(vp: Vector2) -> void:
	var w := 420.0
	var r := Rect2(vp.x - w - 24, 20, w, 54)
	var n := r.size.y * 0.35
	var pts := PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0), r.end - Vector2(n, r.size.y / 2.0),
		r.end, r.position + Vector2(0, r.size.y), r.position + Vector2(n, r.size.y / 2.0)])
	_ui.draw_colored_polygon(pts, Color(UiKit.VELVET, 0.92))
	pts.append(pts[0])
	_ui.draw_polyline(pts, UiKit.GOLD, 2.0, true)
	UiKit.text(_ui, UiKit.display(), Vector2(r.position.x, r.position.y + 39), "Choose a Room", 32, UiKit.GOLD,
		HORIZONTAL_ALIGNMENT_CENTER, w, 8)


## The room's card: its name, its sister's word, the save in it, and what the buttons do here.
func _draw_card(vp: Vector2) -> void:
	if screen != "files":
		return
	var r: Array = ROOMS[room]
	var walking := bool(stage.get(&"walking")) if stage else false
	var w := minf(720.0, vp.x - 60.0)
	var box := Rect2(vp.x / 2.0 - w / 2.0, vp.y - 222, w, 196)
	_ui.draw_style_box(UiKit.card(18, 0.9), box)
	var title: String = r[0]
	var sub := ""
	var lines: Array[String] = []
	var acts: Array = []   # [action, label]
	match r[1]:
		"slot":
			var n: int = room - FIRST_SLOT_ROOM + 1
			var s := Game.slot_summary(n)
			sub = "Save %d" % n
			if s.is_empty():
				lines = [r[2], "Empty. A new game starts here."]
				acts = [[&"jump", "New Game"]]
			else:
				lines = [r[3], "%d Velvet Roses   ·   Rank %d   ·   %d World%s Done" % [s["keys"], s["rank"], s["done"],
					"" if s["done"] == 1 else "s"], "Saved %s" % _when(s["saved_at"])]
				acts = [[&"jump", "Continue"], [&"interact", "Erase  (Are You Sure?)" if _confirm == "erase" else "Erase"]]
		"content":
			lines = [r[2]]
			acts = [[&"jump", "Look Around"]]
		"settings":
			lines = [r[2]]
			acts = [[&"jump", "Settings"]]
		"quit":
			lines = [r[2]]
			acts = [[&"jump", "Quit  (Press Again)" if _confirm == "quit" else "Quit to Desktop"]]
	var a := 0.5 if walking else 1.0
	UiKit.text(_ui, UiKit.display(), box.position + Vector2(26, 46), title, 36, Color(UiKit.GOLD, a))
	if sub != "":
		UiKit.text(_ui, UiKit.display(), Vector2(box.position.x, box.position.y + 44), sub, 22, Color(UiKit.DIM, a),
			HORIZONTAL_ALIGNMENT_RIGHT, box.size.x - 26, 6)
	for i in lines.size():
		var font: Font = UiKit.bold() if i == 0 else UiKit.text_font()
		UiKit.text(_ui, font, box.position + Vector2(26, 82 + i * 28.0), lines[i], 19 if i == 0 else 18,
			Color(UiKit.CREAM if i == 0 else UiKit.DIM, a), HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 52, 4)
	# The prompts along the bottom: the room's actions, then moving and going back.
	var x := box.position.x + 26
	var y := box.end.y - 26
	acts.append([&"move_right", "Walk"])
	acts.append([&"crouch", "Back"])
	for i in acts.size():
		var act: Array = acts[i]
		var gw := 0.0
		if act[0] == &"move_right":
			gw = UiKit.draw_glyph(_ui, Vector2(x, y), &"ui_left" if InputMap.has_action(&"ui_left") else &"move_left", 30.0)
			gw += 4.0 + UiKit.draw_glyph(_ui, Vector2(x + gw + 4.0, y), &"ui_right" if InputMap.has_action(&"ui_right") else &"move_right", 30.0)
		else:
			gw = UiKit.draw_glyph(_ui, Vector2(x, y), act[0], 30.0)
		UiKit.text(_ui, UiKit.display(), Vector2(x + gw + 8, y + 8), act[1], 21, UiKit.CREAM)
		var tw := UiKit.display().get_string_size(act[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
		if i == 0:
			_act_btn.position = Vector2(x - 4, y - 18)
			_act_btn.size = Vector2(gw + tw + 20, 36)
		if act[0] == &"interact":
			_erase_btn.position = Vector2(x - 4, y - 18)
			_erase_btn.size = Vector2(gw + tw + 20, 36)
		x += gw + tw + 34
	# The arrows at the sides, for the mouse (and a hint that there's more that way).
	for d: int in [-1, 1]:
		var to := room + d
		if to < 0 or to >= ROOMS.size():
			continue
		var cx := 40.0 if d < 0 else vp.x - 40.0
		var cy := vp.y * 0.45
		var bump := sin(_t * 4.0) * 4.0 * d
		var tip := Vector2(cx + bump + d * 16.0, cy)
		var pts := PackedVector2Array([tip, tip + Vector2(-d * 30.0, -24.0), tip + Vector2(-d * 30.0, 24.0)])
		_ui.draw_colored_polygon(pts, Color(UiKit.GOLD, 0.85))
		pts.append(pts[0])
		_ui.draw_polyline(pts, UiKit.INK, 3.0, true)
		# Its caption, kept on the screen: left-aligned from the left edge, right-aligned to the right one.
		if d < 0:
			UiKit.text(_ui, UiKit.bold(), Vector2(10, cy + 46), ROOMS[to][0], 15, UiKit.DIM, HORIZONTAL_ALIGNMENT_LEFT, 180, 4)
		else:
			UiKit.text(_ui, UiKit.bold(), Vector2(vp.x - 190, cy + 46), ROOMS[to][0], 15, UiKit.DIM, HORIZONTAL_ALIGNMENT_RIGHT, 180, 4)


func _place_mouse_buttons() -> void:
	var vp := _ui.size
	var on := screen == "files"
	_act_btn.visible = on
	_erase_btn.visible = on and ROOMS[room][1] == "slot" and not Game.slot_summary(room - FIRST_SLOT_ROOM + 1).is_empty()
	var prev := get_node("Prev") as Button
	var next := get_node("Next") as Button
	prev.visible = on and room > 0
	next.visible = on and room < ROOMS.size() - 1
	prev.position = Vector2(4, vp.y * 0.45 - 40)
	prev.size = Vector2(80, 80)
	next.position = Vector2(vp.x - 84, vp.y * 0.45 - 40)
	next.size = Vector2(80, 80)


func _when(stamp: String) -> String:
	if stamp.length() < 16:
		return stamp
	var months := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	var m := clampi(int(stamp.substr(5, 2)) - 1, 0, 11)
	return "%d %s %s, %s" % [int(stamp.substr(8, 2)), months[m], stamp.substr(0, 4), stamp.substr(11, 5)]
