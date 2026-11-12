extends Control
## The title screen (WO-010), the game's first scene. The age gate comes first on a new machine. Then:
##   press any button, then
##   Continue          the slot in play, where it left off (shown if that slot has a game in it)
##   Saves             three slots: play one (new or continued), or erase one (asked twice)
##   Settings          the settings screen (core/settings_menu.gd)
##   Content           the content card again
##   Quit
## Pad, keys and mouse throughout. A game starts in Game.START_SCENE until the prologue exists (WO-014).

var screen := ""
var _stage: Control
var _press: Label
var _confirm_erase := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Hud.show_world_ui(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("0e0a14")
	add_child(bg)
	var band := ColorRect.new()   # a velvet band behind the name
	band.anchor_right = 1.0
	band.anchor_top = 0.16
	band.anchor_bottom = 0.36
	band.color = Look.VELVET.darkened(0.45)
	add_child(band)
	var name_label := Label.new()
	name_label.text = "Vesper's Kinky Kapers"
	name_label.anchor_right = 1.0
	name_label.anchor_top = 0.18
	name_label.anchor_bottom = 0.30
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override(&"font_size", 64)
	name_label.add_theme_color_override(&"font_color", Color("f2c56a"))
	name_label.add_theme_color_override(&"font_outline_color", Look.INK)
	name_label.add_theme_constant_override(&"outline_size", 10)
	add_child(name_label)
	var working := Label.new()
	working.text = "(working title)"
	working.anchor_right = 1.0
	working.anchor_top = 0.29
	working.anchor_bottom = 0.34
	working.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	working.add_theme_color_override(&"font_color", Menu.DIM)
	add_child(working)
	_stage = Control.new()
	_stage.anchor_right = 1.0
	_stage.anchor_top = 0.38
	_stage.anchor_bottom = 1.0
	add_child(_stage)
	_press = Label.new()
	_press.anchor_right = 1.0
	_press.anchor_top = 0.6
	_press.anchor_bottom = 0.7
	_press.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_press.add_theme_font_size_override(&"font_size", 28)
	_press.add_theme_color_override(&"font_color", Menu.INK)
	add_child(_press)
	Hud.age_gate()
	show_press()


func show_press() -> void:
	screen = "press"
	_clear()
	_press.visible = true
	_press.text = "Press %s" % ("A" if Controls.using_pad else "Enter")


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(Hud.gate) or Hud.settings_open():
		return
	if screen == "press":
		var pressed := (event is InputEventJoypadButton or event is InputEventKey or event is InputEventMouseButton) \
			and event.is_pressed() and not event.is_echo()
		if pressed:
			get_viewport().set_input_as_handled()
			show_main()
	elif event.is_action_pressed(&"ui_cancel") and screen != "main":
		get_viewport().set_input_as_handled()
		show_main()


func show_main() -> void:
	screen = "main"
	_clear()
	var col := Menu.panel(_stage, 420.0)
	if not Game.slot_summary(Game.slot).is_empty():
		Menu.button(col, "Continue  (slot %d)" % Game.slot, _play.bind(Game.slot)).name = "Continue"
	Menu.button(col, "Saves", show_slots).name = "Saves"
	Menu.button(col, "Settings", func() -> void: Hud.open_settings(show_main)).name = "Settings"
	Menu.button(col, "Content", show_content).name = "Content"
	Menu.button(col, "Quit", func() -> void: get_tree().quit()).name = "Quit"
	Menu.focus_first.call_deferred(col)


func show_slots() -> void:
	screen = "slots"
	_clear()
	var col := Menu.panel(_stage, 640.0)
	Menu.heading(col, "Saves", 32)
	for n in range(1, Game.SLOTS + 1):
		var row := HBoxContainer.new()
		row.name = "Slot%d" % n
		row.add_theme_constant_override(&"separation", 10)
		col.add_child(row)
		var s := Game.slot_summary(n)
		var play := Button.new()
		play.name = "Play"
		play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		play.custom_minimum_size = Vector2(0, 52)
		play.add_theme_font_size_override(&"font_size", 20)
		play.text = "Slot %d   %s" % [n, "empty: a new game" if s.is_empty() else "%d Keys   %s" % [s["keys"], _when(s["saved_at"])]]
		play.pressed.connect(_play.bind(n))
		row.add_child(play)
		if not s.is_empty():
			var erase := Button.new()
			erase.name = "Erase"
			erase.custom_minimum_size = Vector2(130, 52)
			erase.text = "Sure?" if _confirm_erase == n else "Erase"
			erase.pressed.connect(_erase.bind(n))
			row.add_child(erase)
	Menu.button(col, "Back", show_main)
	Menu.focus_first.call_deferred(col)


func show_content() -> void:
	screen = "content"
	_clear()
	var col := Menu.panel(_stage, 660.0)
	Menu.heading(col, Hud.AgeGate.TITLE, 32)
	Menu.text(col, Hud.AgeGate.BODY, 18, Menu.INK)
	Menu.button(col, "Back", show_main)
	Menu.focus_first.call_deferred(col)


func _play(n: int) -> void:
	if n != Game.slot:
		Game.use_slot(n)
	Game.travel(Game.START_SCENE)


func _erase(n: int) -> void:
	if _confirm_erase != n:
		_confirm_erase = n
		show_slots()
		var row := _stage.find_child("Slot%d" % n, true, false)
		if row:
			(row.get_node("Erase") as Button).grab_focus.call_deferred()
		return
	_confirm_erase = 0
	Game.erase_slot(n)
	show_slots()


func _when(stamp: String) -> String:
	return stamp.replace("T", " ").substr(0, 16)


## Out with the old screen, at once: a screen rebuilt in the same frame mustn't find (or focus) the old one's nodes.
func _clear() -> void:
	_press.visible = false
	for c in _stage.get_children():
		_stage.remove_child(c)
		c.queue_free()
