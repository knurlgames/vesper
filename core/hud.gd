extends CanvasLayer
## Everything on screen that isn't the world (autoload "Hud", WO-010):
##
##   top left       health (her five), and the light readout (how lit she is: shadows are where she's safe)
##   top middle     the zone she's walked into; a world's arrival card
##   top right      the Banjo-style pop-up when she picks something up; the frame rate, if it's switched on
##   bottom left    the gear on LB; in the suit, Composure (and COVER BLOWN) and the Command word
##   bottom middle  what Y does here ("Y  Talk"), in the glyph of the device in use; short notes; captions
## and the pause screen (tallies, rank, and the menu: resume, the controls, settings, the last wardrobe, the club,
## quit), the pad-first chooser (fast travel), the settings screen, and the age gate. Settings (text size, fps,
## volume, fullscreen, subtitles) apply here as they change.

const AgeGate := preload("res://core/age_gate.gd")
const TEXT_SCALES := [0.85, 1.0, 1.2]
const BOX := Color(0.05, 0.03, 0.08, 0.72)

## The open age gate, or null.
var gate: AgeGate
var _world_ui: Control
var _hearts: HBoxContainer
var _light_box: Control
var _light_bar: ColorRect
var _suit_box: Control
var _composure_bar: ColorRect
var _composure_label: Label
var _word: Label
var _gear: Label
var _prompt: Label
var _note: Label
var _note_t := 0.0
var _caption: Label
var _caption_t := 0.0
var _zone: Label
var _zone_t := 0.0
var _arrival: Control
var _arrival_t := 0.0
var _counter: Label
var _counter_t := 0.0
var _fps: Label
var _pause: Control
var _pause_menu: VBoxContainer
var _pause_help: Control
var _resume: Button
var _tallies: Label
var _chooser: Control
var _settings: SettingsMenu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_build()
	_build_pause()
	Game.collected.connect(_on_collected)
	Game.settings_changed.connect(_apply_setting)
	for key: String in ["text_size", "show_fps", "volume", "fullscreen"]:
		_apply_setting(key)
	show_world_ui(false)


## Shows the age gate and content card if this machine hasn't confirmed yet. Levels and the title call it on start.
## Returns the gate, or null if it isn't needed.
func age_gate() -> AgeGate:
	if gate != null or Game.get_setting(AgeGate.SETTING, false):
		return gate
	gate = AgeGate.new()
	get_tree().root.add_child.call_deferred(gate)
	return gate


## The in-world HUD on or off (the title has none; screenshots can hide it).
func show_world_ui(on: bool) -> void:
	_world_ui.visible = on


# --- the readouts ----------------------------------------------------------------------------------------------------

func set_health(current: int, maximum: int) -> void:
	show_world_ui(true)
	while _hearts.get_child_count() < maximum:
		var h := Panel.new()
		h.custom_minimum_size = Vector2(26, 26)
		_hearts.add_child(h)
	for i in _hearts.get_child_count():
		var h := _hearts.get_child(i) as Panel
		h.visible = i < maximum
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(13)
		sb.bg_color = Look.VELVET.lightened(0.15) if i < current else Color(0.12, 0.08, 0.12, 0.9)
		sb.border_color = Color("f2c56a") if i < current else Color(0.3, 0.25, 0.3)
		sb.set_border_width_all(2)
		h.add_theme_stylebox_override(&"panel", sb)


## How lit Nim is, 0 (dark) to 1 (a lamp's pool).
func set_light(v: float) -> void:
	_light_bar.size.x = 120.0 * clampf(v, 0.0, 1.0)
	_light_bar.color = Color("3a3070").lerp(Color("ffc860"), clampf(v, 0.0, 1.0))


## The suit's Composure (shown only in the suit), and COVER BLOWN when it's gone.
func set_composure(value: float, blown: bool, outfit: int) -> void:
	_suit_box.visible = outfit == 1
	_composure_bar.size.x = 180.0 * clampf(value, 0.0, 1.0)
	_composure_bar.color = Color("c0283e") if blown else Color("e8d0e0")
	_composure_label.text = "COVER BLOWN" if blown else "Composure"
	_composure_label.add_theme_color_override(&"font_color", Color("ff6a6a") if blown else Menu.DIM)


## The gear on LB (and how many lures are left).
func set_gear(gear: String, lures: int) -> void:
	if gear == "":
		_gear.text = ""
		return
	_gear.text = "%s  %s%s" % [Controls.glyph(&"gear"), Lessons.NAMES.get(gear, gear),
		"  x%d" % lures if gear == Lessons.LURE else ""]


## The Command word the D-pad has picked.
func set_word(word: StringName) -> void:
	_word.text = "Command: %s" % String(word).capitalize()


## What Y does right now ("" for nothing), shown with the button for the device in use.
func set_prompt(what: String) -> void:
	_prompt.text = "" if what == "" else "%s   %s" % [Controls.glyph(&"interact"), what]


## A short notice: a locked door, a rule.
func note(text: String, secs := 3.5) -> void:
	_note.text = text
	_note_t = secs


## Something said aloud (a bark, a staff reply, a waking sleeper), if subtitles are on.
func caption(speaker: String, text: String, secs := 3.0) -> void:
	if not Game.get_setting("subtitles"):
		return
	_caption.text = text if speaker == "" else "%s:  %s" % [speaker, text]
	_caption_t = secs


## The name of the part of the world she's walked into (a Zone).
func zone(text: String) -> void:
	_zone.text = text
	_zone_t = 3.0


## A world's arrival card: its name, large, and a line under it, for a few seconds.
func arrival(title: String, subtitle := "", secs := 3.5) -> void:
	(_arrival.get_node("Title") as Label).text = title
	(_arrival.get_node("Sub") as Label).text = subtitle
	_arrival_t = secs
	_arrival.visible = true
	_arrival.modulate.a = 1.0


func arrival_showing() -> bool:
	return _arrival.visible and _arrival_t > 0.0


# --- pause, the chooser, settings ------------------------------------------------------------------------------------

func paused() -> bool:
	return _pause.visible


func set_paused(on: bool) -> void:
	_pause.visible = on
	get_tree().paused = on
	if on:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_tallies.text = _tally_text()
		_show_pause_help(false)
		_resume.grab_focus()


## A short pad-first list (fast travel): up and down pick, A takes it, B backs out. The world waits meanwhile.
func choose(title: String, options: Array[String], on_pick: Callable) -> void:
	if _chooser:
		_chooser.queue_free()
	_chooser = Control.new()
	_chooser.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_chooser)
	var col := Menu.panel(_chooser, 360.0)
	Menu.heading(col, title, 30)
	var first: Button = null
	for i in options.size():
		var b := Menu.button(col, options[i], func() -> void:
			_close_chooser()
			on_pick.call(i))
		if first == null:
			first = b
	get_tree().paused = true
	if first:
		first.grab_focus.call_deferred()


func choosing() -> bool:
	return _chooser != null


func _close_chooser() -> void:
	if _chooser:
		_chooser.queue_free()
		_chooser = null
	get_tree().paused = false


## The settings screen, over whatever's showing; `back` is called when it closes.
func open_settings(back: Callable = Callable()) -> SettingsMenu:
	if _settings:
		return _settings
	_settings = SettingsMenu.new()
	var over := CanvasLayer.new()
	over.layer = 40
	over.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(over)
	over.add_child(_settings)
	_settings.closed.connect(func() -> void:
		_settings = null
		over.queue_free()
		if back.is_valid():
			back.call())
	return _settings


func settings_open() -> bool:
	return _settings != null


func _process(delta: float) -> void:
	if _fps.visible:
		_fps.text = "%d fps" % Engine.get_frames_per_second()
	_note_t = _fade(_note, _note_t, delta, 2.0)
	_caption_t = _fade(_caption, _caption_t, delta, 2.0)
	_zone_t = _fade(_zone, _zone_t, delta, 1.0)
	_counter_t = _fade(_counter, _counter_t, delta, 2.0)
	if _arrival_t > 0.0:
		_arrival_t -= delta
		_arrival.modulate.a = clampf(_arrival_t, 0.0, 1.0)
		if _arrival_t <= 0.0:
			_arrival.visible = false


func _fade(l: CanvasItem, t: float, delta: float, rate: float) -> float:
	if t > 0.0:
		t -= delta
	l.modulate.a = clampf(t * rate, 0.0, 1.0)
	return t


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(gate) or _settings:
		return
	if _chooser:
		if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
			_close_chooser()
			get_viewport().set_input_as_handled()
		return
	# Only in a level (the title has its own menus).
	var scene := get_tree().current_scene
	if scene == null or scene.get(&"nim") == null:
		return
	if event.is_action_pressed(&"pause"):
		set_paused(not _pause.visible)
		get_viewport().set_input_as_handled()
	elif _pause.visible and event.is_action_pressed(&"ui_cancel"):
		if _pause_help.visible:
			_show_pause_help(false)
		else:
			set_paused(false)
		get_viewport().set_input_as_handled()


func _apply_setting(key: String) -> void:
	match key:
		"text_size":
			get_tree().root.content_scale_factor = TEXT_SCALES[clampi(int(Game.get_setting("text_size")), 0, 2)]
		"show_fps":
			_fps.visible = bool(Game.get_setting("show_fps"))
		"volume":
			AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(Game.get_setting("volume")), 0.0001)))
		"fullscreen":
			if DisplayServer.get_name() != "headless":
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if Game.get_setting("fullscreen")
					else DisplayServer.WINDOW_MODE_WINDOWED)


## Banjo-style: a pick-up shows its world's count for a moment, then gets out of the way.
func _on_collected(kind: StringName, world: StringName, _id: StringName) -> void:
	var names := {&"key": "Keys", &"contraband": "Contraband", &"freed": "Woken", &"tin": "Collection tin"}
	_counter.text = "%s  %d / %d\n%s" % [names.get(kind, String(kind)), Game.count(kind, world), Game.total(kind, world),
		Game.NAMES.get(world, String(world))]
	_counter_t = 3.0
	if kind == &"key":
		note("Keys: %d. Rank %d." % [Game.keys(), Game.rank()], 3.0)


## The pause screen's tallies: every world, Banjo-style, and her rank.
func _tally_text() -> String:
	var lines: Array[String] = []
	lines.append("%-22s %6s %10s %7s %5s" % ["", "Keys", "Contraband", "Woken", "Tin"])
	for w: StringName in Game.WORLDS:
		if w == &"city_hall":
			continue
		var wname: String = Game.NAMES.get(w, String(w))
		if not Game.world_open(w):
			lines.append("%-22s %s" % [wname, "locked"])
			continue
		lines.append("%-22s %6s %10s %7s %5s" % [wname,
			"%d/%d" % [Game.count(&"key", w), Game.total(&"key", w)],
			"%d/%d" % [Game.count(&"contraband", w), Game.total(&"contraband", w)] if Game.total(&"contraband", w) > 0 else "",
			"%d/%d" % [Game.count(&"freed", w), Game.total(&"freed", w)] if Game.total(&"freed", w) > 0 else "",
			("yes" if Game.count(&"tin", w) > 0 else "no") if Game.total(&"tin", w) > 0 else ""])
	var r := Game.rank()
	var next := "" if r >= Game.RANK_KEYS.size() else "  (next at %d)" % Game.RANK_KEYS[r]
	lines.append("")
	lines.append("Keys: %d.  Rank %d%s" % [Game.keys(), r, next])
	return "\n".join(lines)


## Every control, for the device in use, from the bindings as they are now (remaps included).
func _help_text() -> String:
	var pad := Controls.using_pad
	var lines: Array[String] = ["Move: %s    Camera: %s" % ["left stick" if pad else "WASD", "right stick" if pad else "mouse"]]
	for action in Controls.REMAPPABLE:
		lines.append("%-30s %s" % [Controls.ACTION_NAMES.get(action, String(action)), Controls.glyph(action, pad)])
	lines.append("")
	lines.append("Climb: push into marked walls.  Ledges: jump to catch, A pulls up, B lets go.")
	lines.append("In the suit: the stick part-way (or crouch) is a strut.  Y beside things: talk, change, travel.")
	return "\n".join(lines)


func _show_pause_help(on: bool) -> void:
	_pause_help.visible = on
	_pause_menu.visible = not on
	if on:
		(_pause_help.get_node("Text") as Label).text = _help_text()
		(_pause_help.get_node("Back") as Button).grab_focus()
	else:
		_resume.grab_focus()


func _to_last_wardrobe() -> void:
	set_paused(false)
	var lw := Game.last_wardrobe
	if lw.is_empty():
		note("No wardrobe yet.")
		return
	var scene := get_tree().current_scene
	var at := Vector3(lw["pos"][0], lw["pos"][1], lw["pos"][2])
	if scene and scene.scene_file_path == lw["scene"] and scene.get(&"nim"):
		scene.get(&"nim").call(&"teleport", at + Vector3.UP * 0.05, float(lw["yaw"]))
	else:
		Game.travel(lw["scene"], "@wardrobe")


func _to_club() -> void:
	set_paused(false)
	Game.travel(Game.SCENES[&"hub"], "club_door")


func _to_title() -> void:
	set_paused(false)
	show_world_ui(false)
	Game.travel("res://levels/title/title.tscn")


# --- building it -----------------------------------------------------------------------------------------------------

func _label(parent: Node, size: int, c: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", c)
	l.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override(&"outline_size", 6)
	parent.add_child(l)
	return l


func _box(parent: Node, at: Vector2, size: Vector2, anchor := Vector2.ZERO) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = BOX
	sb.set_corner_radius_all(6)
	p.add_theme_stylebox_override(&"panel", sb)
	p.anchor_left = anchor.x
	p.anchor_right = anchor.x
	p.anchor_top = anchor.y
	p.anchor_bottom = anchor.y
	p.offset_left = at.x
	p.offset_top = at.y
	p.offset_right = at.x + size.x
	p.offset_bottom = at.y + size.y
	parent.add_child(p)
	return p


func _build() -> void:
	_world_ui = Control.new()
	_world_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_world_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_world_ui)
	# Top left: health, then light.
	var top := _box(_world_ui, Vector2(16, 16), Vector2(196, 74))
	_hearts = HBoxContainer.new()
	_hearts.position = Vector2(12, 10)
	_hearts.add_theme_constant_override(&"separation", 8)
	top.add_child(_hearts)
	_light_box = Control.new()
	_light_box.position = Vector2(12, 46)
	top.add_child(_light_box)
	var lbl := _label(_light_box, 15, Menu.DIM)
	lbl.text = "Light"
	lbl.position = Vector2(0, -2)
	var frame := ColorRect.new()
	frame.color = Color(0.02, 0.01, 0.04, 0.9)
	frame.position = Vector2(48, 2)
	frame.size = Vector2(124, 14)
	_light_box.add_child(frame)
	_light_bar = ColorRect.new()
	_light_bar.position = Vector2(2, 2)
	_light_bar.size = Vector2(0, 10)
	frame.add_child(_light_bar)
	# Bottom left: in the suit, Composure and the Command word; the gear under it.
	_suit_box = _box(_world_ui, Vector2(16, -128), Vector2(240, 66), Vector2(0, 1))
	_composure_label = _label(_suit_box, 16, Menu.DIM)
	_composure_label.position = Vector2(12, 4)
	var cframe := ColorRect.new()
	cframe.color = Color(0.02, 0.01, 0.04, 0.9)
	cframe.position = Vector2(12, 26)
	cframe.size = Vector2(184, 12)
	_suit_box.add_child(cframe)
	_composure_bar = ColorRect.new()
	_composure_bar.position = Vector2(2, 2)
	_composure_bar.size = Vector2(0, 8)
	cframe.add_child(_composure_bar)
	_word = _label(_suit_box, 16, Color("f0d8e8"))
	_word.position = Vector2(12, 42)
	_suit_box.visible = false
	_gear = _label(_world_ui, 18, Color("d8e8f0"))
	_gear.anchor_top = 1.0
	_gear.anchor_bottom = 1.0
	_gear.offset_left = 22
	_gear.offset_top = -50
	# Bottom middle: the Y prompt, notes and captions.
	_prompt = _centred(_world_ui, 24, Color("f6efe0"), -150)
	_note = _centred(_world_ui, 22, Color("ffe6b0"), -200)
	_caption = _centred(_world_ui, 22, Color("f2e6c8"), -96)
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Top: the zone and the arrival card; top right, the pick-up pop-up and the frame rate.
	_zone = _centred(_world_ui, 30, Color("ffd890"), 0, 0.0)
	_zone.offset_top = 24
	_zone.offset_bottom = 64
	_arrival = Control.new()
	_arrival.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_arrival.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrival.visible = false
	add_child(_arrival)
	var at := _centred(_arrival, 56, Color("f2c56a"), 0, 0.28)
	at.name = "Title"
	var sub := _centred(_arrival, 22, Color("f2e6c8"), 70, 0.28)
	sub.name = "Sub"
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_counter = _label(_world_ui, 26, Color("f6efe0"))
	_counter.anchor_left = 1.0
	_counter.anchor_right = 1.0
	_counter.offset_left = -420
	_counter.offset_right = -20
	_counter.offset_top = 40
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_counter.modulate.a = 0.0
	_fps = _label(self, 16, Color(1, 1, 1, 0.7))
	_fps.anchor_left = 1.0
	_fps.anchor_right = 1.0
	_fps.offset_left = -90.0
	_fps.offset_top = 8.0


## A label centred across the screen, `from` pixels from the bottom (or from `anchor_y` down, if given).
func _centred(parent: Node, size: int, c: Color, from: float, anchor_y := 1.0) -> Label:
	var l := _label(parent, size, c)
	l.anchor_left = 0.15
	l.anchor_right = 0.85
	l.anchor_top = anchor_y
	l.anchor_bottom = anchor_y
	l.offset_top = from - 40.0
	l.offset_bottom = from
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_pause() -> void:
	# Its own layer, over everything else on the HUD, with a dark backdrop so the tallies read over any world.
	var over := CanvasLayer.new()
	over.layer = 20
	add_child(over)
	_pause = Control.new()
	_pause.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.visible = false
	over.add_child(_pause)
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.02, 0.07, 0.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(center)
	var stack := VBoxContainer.new()
	center.add_child(stack)
	_pause_menu = VBoxContainer.new()
	_pause_menu.add_theme_constant_override(&"separation", 10)
	stack.add_child(_pause_menu)
	Menu.heading(_pause_menu, "Paused", 44)
	_tallies = Label.new()
	_tallies.add_theme_font_size_override(&"font_size", 18)
	_tallies.add_theme_color_override(&"font_color", Menu.INK)
	var mono := SystemFont.new()   # monospaced, so the columns line up (Consolas on Windows, DejaVu on the Deck)
	mono.font_names = PackedStringArray(["Consolas", "DejaVu Sans Mono", "Liberation Mono", "monospace"])
	_tallies.add_theme_font_override(&"font", mono)
	_pause_menu.add_child(_tallies)
	_resume = Menu.button(_pause_menu, "Resume", set_paused.bind(false))
	Menu.button(_pause_menu, "Controls", _show_pause_help.bind(true))
	Menu.button(_pause_menu, "Settings", func() -> void: open_settings(func() -> void: _resume.grab_focus()))
	Menu.button(_pause_menu, "Back to the last wardrobe", _to_last_wardrobe)
	Menu.button(_pause_menu, "Return to the club", _to_club)
	Menu.button(_pause_menu, "Title screen", _to_title)
	Menu.button(_pause_menu, "Quit to desktop", func() -> void: get_tree().quit())
	_pause_help = VBoxContainer.new()
	_pause_help.visible = false
	stack.add_child(_pause_help)
	Menu.heading(_pause_help, "Controls", 36)
	var help := Label.new()
	help.name = "Text"
	help.add_theme_font_override(&"font", mono)
	help.add_theme_font_size_override(&"font_size", 18)
	help.add_theme_color_override(&"font_color", Menu.INK)
	_pause_help.add_child(help)
	var back := Menu.button(_pause_help, "Back", _show_pause_help.bind(false))
	back.name = "Back"
