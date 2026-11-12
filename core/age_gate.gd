extends CanvasLayer
## The age gate and content card, shown on first launch (Hud.age_gate). The world is paused behind it until she's
## confirmed 18 or older; the answer is a setting, so it's asked once per machine and "Erase progress" doesn't bring it
## back. Pad: the D-pad or stick picks a button, A presses it. Keys: arrows / Tab, then Enter or Space. Mouse: click.

signal confirmed

const SETTING := "age_confirmed"

# OWNER REVIEW: the whole card (title, body, button labels).
const TITLE := "Adults only"
const BODY := "Vesper's Kinky Kapers is a comedy for adults. It has crude humour and strong language, fetish clothing \
and BDSM themes (rope, leather, latex, collars, domination), hypnosis used by villains, and cartoon fighting.\n\n\
Nothing explicit is shown: no nudity and no sex.\n\n\
Every character is a grown adult.\n\n\
Are you 18 or older, and of age to play this where you live?"
const ENTER := "I'm 18 or older: enter"
const LEAVE := "Quit"

var enter_button: Button
var _was_paused := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_was_paused = get_tree().paused
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var shade := ColorRect.new()
	shade.color = Color("0d0810")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color("1c1220")
	box.border_color = Color("8a2b4a")
	box.set_border_width_all(2)
	box.set_corner_radius_all(6)
	box.set_content_margin_all(32)
	panel.add_theme_stylebox_override(&"panel", box)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(620, 0)
	col.add_theme_constant_override(&"separation", 18)
	panel.add_child(col)

	var title := Label.new()
	title.text = TITLE
	title.add_theme_font_size_override(&"font_size", 40)
	title.add_theme_color_override(&"font_color", Color("e8c27a"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var body := Label.new()
	body.text = BODY
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override(&"font_size", 20)
	body.add_theme_color_override(&"font_color", Color("efe4ea"))
	col.add_child(body)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 24)
	col.add_child(row)
	enter_button = _button(ENTER, row)
	var leave := _button(LEAVE, row)
	enter_button.pressed.connect(_on_enter)
	leave.pressed.connect(func() -> void: get_tree().quit())
	# Left and right walk between the two; nothing else on screen takes focus.
	enter_button.focus_neighbor_right = enter_button.get_path_to(leave)
	leave.focus_neighbor_left = leave.get_path_to(enter_button)
	enter_button.grab_focus.call_deferred()


func _button(text: String, parent: Control) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(220, 52)
	b.add_theme_font_size_override(&"font_size", 22)
	parent.add_child(b)
	return b


func _on_enter() -> void:
	Game.set_setting(SETTING, true)
	get_tree().paused = _was_paused
	confirmed.emit()
	queue_free()
