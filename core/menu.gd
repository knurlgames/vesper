class_name Menu
extends RefCounted
## Builds the game's menus the same way everywhere (WO-010; restyled 2026-11-13 on core/ui_kit.gd's Theme): a velvet card,
## a column of focusable controls. Every control works on a pad (D-pad or left stick to move, A to press, left and right
## on sliders and choices), on the keyboard (arrows or Tab, Enter or Space) and with the mouse. Settings controls read
## and write Game's settings directly, so a screen built from them needs no save code. Headings, buttons and settings'
## names are put in Title Case here (owner: "Keep all menu items and text as title cased").

const INK := UiKit.CREAM
const DIM := UiKit.DIM
const GOLD := UiKit.GOLD


## The Game autoload, found at run time: a probe that names Menu compiles before autoloads exist.
static func _game() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node(^"/root/Game")


## A centred card; returns its column to fill.
static func panel(parent: Control, width := 660.0) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override(&"panel", UiKit.card(18))
	center.add_child(p)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(width, 0)
	col.add_theme_constant_override(&"separation", 12)
	p.add_child(col)
	return col


static func heading(col: Control, text: String, size := 40) -> Label:
	var l := Label.new()
	l.text = UiKit.title_case(text)
	l.theme_type_variation = &"Heading"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override(&"font_size", size)
	col.add_child(l)
	# A thin gold rule under it.
	var rule := ColorRect.new()
	rule.color = Color(UiKit.GOLD_DEEP, 0.7)
	rule.custom_minimum_size = Vector2(0, 2)
	col.add_child(rule)
	return l


static func text(col: Control, body: String, size := 18, colour := DIM) -> Label:
	var l := Label.new()
	l.text = body
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", colour)
	col.add_child(l)
	return l


static func button(col: Control, label: String, on_press: Callable, height := 50.0) -> Button:
	var b := Button.new()
	b.text = UiKit.title_case(label)
	b.custom_minimum_size = Vector2(0, height)
	b.pressed.connect(on_press)
	col.add_child(b)
	return b


## An on/off setting.
static func toggle(col: Control, label: String, key: String) -> CheckButton:
	var c := CheckButton.new()
	c.text = UiKit.title_case(label)
	c.custom_minimum_size = Vector2(0, 46)
	c.add_theme_font_size_override(&"font_size", 20)
	c.button_pressed = bool(_game().get_setting(key))
	c.toggled.connect(func(on: bool) -> void: _game().set_setting(key, on))
	col.add_child(c)
	return c


## A number setting: left and right (or the mouse) move it.
static func slider(col: Control, label: String, key: String, lo: float, hi: float, step: float) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	col.add_child(row)
	var l := Label.new()
	l.text = UiKit.title_case(label)
	l.custom_minimum_size = Vector2(260, 0)
	l.add_theme_font_override(&"font", UiKit.bold())
	l.add_theme_font_size_override(&"font_size", 20)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(_game().get_setting(key))
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(0, 32)
	s.focus_mode = Control.FOCUS_ALL
	row.add_child(s)
	var v := Label.new()
	v.custom_minimum_size = Vector2(60, 0)
	v.add_theme_font_override(&"font", UiKit.display())
	v.add_theme_color_override(&"font_color", GOLD)
	v.text = "%.1f" % s.value
	row.add_child(v)
	s.value_changed.connect(func(x: float) -> void:
		v.text = "%.1f" % x
		_game().set_setting(key, x))
	return s


## A setting with a few named values: A, or left and right, cycle through them.
static func choice(col: Control, label: String, key: String, names: Array[String]) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_font_size_override(&"font_size", 20)
	var shown := UiKit.title_case(label)
	var paint := func() -> void:
		b.text = "%s:   ‹ %s ›" % [shown, names[clampi(int(_game().get_setting(key)), 0, names.size() - 1)]]
	paint.call()
	var step := func(d: int) -> void:
		_game().set_setting(key, posmod(int(_game().get_setting(key)) + d, names.size()))
		paint.call()
	b.pressed.connect(step.bind(1))
	b.gui_input.connect(func(e: InputEvent) -> void:
		if e.is_action_pressed(&"ui_right"):
			step.call(1)
			b.accept_event()
		elif e.is_action_pressed(&"ui_left"):
			step.call(-1)
			b.accept_event())
	col.add_child(b)
	return b


## Focus the first focusable control under `root` (call deferred: after the menu's in the tree).
static func focus_first(root: Node) -> void:
	for c in root.find_children("*", "Control", true, false):
		var ctl := c as Control
		if ctl.focus_mode == Control.FOCUS_ALL and ctl.is_visible_in_tree():
			ctl.grab_focus()
			return
