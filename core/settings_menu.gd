class_name SettingsMenu
extends Control
## The settings screen (WO-010), from the title or the pause menu. Four pages:
##   Controls       every remappable action, its key and its pad button; pick one and press the new one
##   Camera         speed, invert X, invert Y
##   Display/sound  volume, fullscreen, the fps counter
##   Accessibility  subtitles, text size, reduce motion, reduce flashing
## Everything saves as it changes (Game settings). B (or Esc) goes back. Pad, keys and mouse all work.

signal closed

const PAGES := ["Controls", "Camera", "Display & sound", "Accessibility"]
## The Controls autoload's constants, by its script; its methods through the node, found at run time (a probe that
## names SettingsMenu compiles before autoloads exist).
const ControlsScript := preload("res://core/controls.gd")
const TEXT_SIZES: Array[String] = ["Small", "Medium", "Large"]
## Conversation typing speeds (Dialogue.TEXT_SPEEDS, letters a second); "Instant" shows each line whole.
const TEXT_SPEEDS: Array[String] = ["Slow", "Normal", "Fast", "Instant"]

var page := 0
## The action and device being rebound (the screen waits for the next key or button).
var capturing: StringName = &""
var capturing_pad := false
var _capture_t := 0.0
var _tabs: HBoxContainer
var _body: VBoxContainer
var _prompt: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.02, 0.07, 0.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var col := Menu.panel(self, 820.0)
	Menu.heading(col, "Settings")
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override(&"separation", 8)
	col.add_child(_tabs)
	for i in PAGES.size():
		var t := Button.new()
		t.text = UiKit.title_case(PAGES[i])
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.custom_minimum_size = Vector2(0, 40)
		t.pressed.connect(show_page.bind(i))
		_tabs.add_child(t)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override(&"separation", 8)
	_body.custom_minimum_size = Vector2(0, 420)
	col.add_child(_body)
	_prompt = Menu.text(col, "", 18, Menu.GOLD)
	Menu.button(col, "Back", close)
	show_page(0)
	(_tabs.get_child(0) as Button).grab_focus.call_deferred()


func show_page(i: int) -> void:
	page = i
	for c in _body.get_children():
		c.queue_free()
	for t in _tabs.get_child_count():
		(_tabs.get_child(t) as Button).add_theme_color_override(&"font_color", Menu.GOLD if t == i else Menu.DIM)
	match i:
		0:
			_controls_page()
		1:
			Menu.slider(_body, "Camera speed", "cam_speed", 0.3, 2.5, 0.1)
			Menu.toggle(_body, "Invert left and right", "invert_x")
			Menu.toggle(_body, "Invert up and down", "invert_y")
		2:
			Menu.slider(_body, "Volume", "volume", 0.0, 1.0, 0.1)
			Menu.toggle(_body, "Typing blips in conversations", "text_blips")
			Menu.toggle(_body, "Fullscreen", "fullscreen")
			Menu.toggle(_body, "Show the frame rate", "show_fps")
		3:
			Menu.toggle(_body, "Subtitles (what people say aloud)", "subtitles")
			Menu.toggle(_body, "Show the guide (what's next, and which way)", "show_guide")
			Menu.choice(_body, "Text size", "text_size", TEXT_SIZES)
			Menu.choice(_body, "Text speed", "text_speed", TEXT_SPEEDS)
			Menu.toggle(_body, "Reduce motion (cuts, not camera moves)", "reduce_motion")
			Menu.toggle(_body, "Reduce flashing", "reduce_flashing")


func _controls_page() -> void:
	var head := HBoxContainer.new()
	_body.add_child(head)
	for spec: Array in [["Action", 330], ["Keyboard / Mouse", 210], ["Pad", 210]]:
		var l := Label.new()
		l.text = spec[0]
		l.add_theme_font_override(&"font", UiKit.display())
		l.custom_minimum_size = Vector2(spec[1], 0)
		l.add_theme_color_override(&"font_color", Menu.GOLD)
		head.add_child(l)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 340)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_body.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for action in ControlsScript.REMAPPABLE:
		var row := HBoxContainer.new()
		row.name = String(action)
		list.add_child(row)
		var l := Label.new()
		l.text = UiKit.title_case(ControlsScript.ACTION_NAMES.get(action, String(action)))
		l.custom_minimum_size = Vector2(330, 0)
		l.add_theme_font_override(&"font", UiKit.bold())
		row.add_child(l)
		for pad: bool in [false, true]:
			var b := Button.new()
			b.name = "Pad" if pad else "Keys"
			b.text = _controls().glyph(action, pad)
			b.custom_minimum_size = Vector2(200, 34)
			b.pressed.connect(_begin_capture.bind(action, pad))
			row.add_child(b)
	Menu.button(_body, "Reset the controls", func() -> void:
		_controls().reset_bindings()
		show_page(0))


func _begin_capture(action: StringName, pad: bool) -> void:
	capturing = action
	capturing_pad = pad
	_capture_t = 0.0
	_prompt.text = "Press the new %s for \"%s\"  (wait 5 s to cancel)" % ["pad button" if pad else "key",
		ControlsScript.ACTION_NAMES.get(action, String(action))]


func _process(delta: float) -> void:
	if capturing != &"":
		_capture_t += delta
		if _capture_t > 5.0:
			_end_capture()


func _input(event: InputEvent) -> void:
	if capturing == &"":
		if event.is_action_pressed(&"ui_cancel"):
			close()
			get_viewport().set_input_as_handled()
		return
	if _capture_t < 0.2 or not event.is_pressed() or event.is_echo():
		return
	var ok := false
	if capturing_pad:
		ok = event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.6
			and (event.axis == JOY_AXIS_TRIGGER_LEFT or event.axis == JOY_AXIS_TRIGGER_RIGHT))
	else:
		ok = event is InputEventKey or event is InputEventMouseButton
	if not ok:
		return
	get_viewport().set_input_as_handled()
	var e: InputEvent = event.duplicate()
	if e is InputEventKey:
		var k := e as InputEventKey
		k.keycode = KEY_NONE
		k.pressed = false
	elif e is InputEventJoypadMotion:
		(e as InputEventJoypadMotion).axis_value = 1.0
	elif e is InputEventJoypadButton:
		(e as InputEventJoypadButton).pressed = false
	elif e is InputEventMouseButton:
		(e as InputEventMouseButton).pressed = false
	_controls().rebind(capturing, e)
	_end_capture()


func _end_capture() -> void:
	var action := capturing
	capturing = &""
	_prompt.text = ""
	show_page(0)
	# Back to the row just rebound.
	await get_tree().process_frame
	var row := _body.find_child(String(action), true, false)
	if row:
		(row.get_child(2 if capturing_pad else 1) as Control).grab_focus()



func _controls() -> Node:
	return get_node(^"/root/Controls")


func close() -> void:
	closed.emit()
	queue_free()
