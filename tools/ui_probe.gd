extends SceneTree
## WO-010's acceptance: every screen works on the pad, the keys and the mouse (real input events throughout).
##   - The title: any button past "press start"; the D-pad and A through the menu; the mouse clicks "Content"; Esc
##     comes back.
##   - Settings: A flips a toggle (invert X); the D-pad moves a slider (camera speed); Enter starts a remap and a key
##     press rebinds Jump; a mouse click on Back closes it. Text size and subtitles apply.
##   - Saves: A plays slot 1, and the level starts with its arrival card and the HUD; erasing a slot asks twice.
##   - The HUD: the Y prompt names what Y does, in the glyph of the device in use ("Y" on the pad, "E" on keys); the
##     suit shows Composure.
##   - Pause: Start opens it; the Controls page lists the bindings (the remap included); Settings opens from it; B
##     backs out of each.
##   - A world's end: the probe world's paper card plays, and A closes it.
##   godot --headless --fixed-fps 60 --path . -s tools/ui_probe.gd

const Driver := preload("res://tools/probe_driver.gd")
const In := preload("res://tools/probe_input.gd")

var fails := 0
var game: Node
var hud: Node
var controls: Node
var dialogue: Node


func _initialize() -> void:
	await process_frame
	game = root.get_node("/root/Game")
	hud = root.get_node("/root/Hud")
	controls = root.get_node("/root/Controls")
	dialogue = root.get_node("/root/Dialogue")
	game.set(&"persist", false)
	game.call(&"set_setting", "age_confirmed", true)
	game.call(&"reset")
	# Headless, the window is 64x64: lay screens out (and take clicks) at the game's real size.
	root.size = Vector2i(1280, 800)
	await frames(2)
	await _title()
	await _settings()
	await _content_by_mouse()
	await _play_slot()
	await _hud()
	await _pause()
	await _paper()
	await _erase()
	controls.call(&"reset_bindings")
	print("ui probe: %d failures" % fails)
	quit(1 if fails else 0)


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("%s  %s" % ["ok  " if ok else "FAIL", what])


func frames(n: int) -> void:
	for i in n:
		await process_frame


func tap_pad(b: JoyButton) -> void:
	In.button(b, true)
	await frames(2)
	In.button(b, false)
	await frames(3)


func tap_key(k: Key) -> void:
	In.key(k, true)
	await frames(2)
	In.key(k, false)
	await frames(3)


func click(c: Control) -> void:
	await frames(3)   # let a rebuilt screen lay itself out before taking the button's position
	var at := c.get_global_rect().get_center()   # viewport coordinates: what a mouse event carries
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	Input.parse_input_event(move)
	await frames(2)
	if OS.has_environment("PROBE_TRACE"):
		print("click %s at %s (rect %s, hovered %s)" % [c.name, at, c.get_global_rect(), root.gui_get_hovered_control()])
	for down: bool in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = at
		e.global_position = at
		Input.parse_input_event(e)
		await frames(2)
	await frames(3)


func focused() -> Control:
	return root.gui_get_focus_owner()


func _title() -> void:
	var title: Node = load("res://levels/title/title.tscn").instantiate()
	root.add_child(title)
	current_scene = title
	await frames(5)
	check(title.get(&"screen") == "press", "the title opens on \"press start\"")
	await tap_pad(JOY_BUTTON_A)
	await frames(3)
	check(title.get(&"screen") == "main", "A on the pad: the main menu")
	var f := focused()
	check(f != null and f.name == "Saves", "with \"Saves\" focused (no game yet, so no Continue): %s" % (f.name if f else "nothing"))
	await tap_pad(JOY_BUTTON_DPAD_DOWN)
	f = focused()
	check(f != null and f.name == "Settings", "the D-pad moves down to \"Settings\"")


func _settings() -> void:
	await tap_pad(JOY_BUTTON_A)
	await frames(5)
	check(hud.call(&"settings_open"), "A opens the settings")
	var menu: SettingsMenu = hud.get(&"_settings")
	# The Camera page, by pad: right along the tabs, A.
	await tap_pad(JOY_BUTTON_DPAD_RIGHT)
	await tap_pad(JOY_BUTTON_A)
	await frames(3)
	check(menu.page == 1, "the D-pad and A switch to the Camera page")
	var sliders := menu.find_children("*", "HSlider", true, false)
	var toggles := menu.find_children("*", "CheckButton", true, false)
	var speed := sliders[0] as HSlider
	speed.grab_focus()
	await frames(2)
	var before: float = game.call(&"get_setting", "cam_speed")
	await tap_pad(JOY_BUTTON_DPAD_RIGHT)
	check(float(game.call(&"get_setting", "cam_speed")) > before, "the D-pad nudges the camera speed up (%.1f to %.1f)" % [before, game.call(&"get_setting", "cam_speed")])
	(toggles[0] as Control).grab_focus()
	await frames(2)
	await tap_pad(JOY_BUTTON_A)
	check(game.call(&"get_setting", "invert_x") == true, "A flips \"Invert left and right\"")
	# Controls page by keyboard: focus the Controls tab, Enter; then Enter on Jump's key, and press U.
	(menu.get(&"_tabs").get_child(0) as Control).grab_focus()
	await tap_key(KEY_ENTER)
	await frames(3)
	check(menu.page == 0, "Enter switches to the Controls page")
	var row: Node = menu.find_child("jump", true, false)
	(row.get_node("Keys") as Control).grab_focus()
	await frames(2)
	await tap_key(KEY_ENTER)
	check(menu.capturing == &"jump", "Enter on Jump's key waits for a new one")
	await frames(20)
	await tap_key(KEY_U)
	await frames(3)
	var has_u := false
	var has_space := false
	for e in InputMap.action_get_events(&"jump"):
		if e is InputEventKey:
			has_u = has_u or e.physical_keycode == KEY_U
			has_space = has_space or e.physical_keycode == KEY_SPACE
	check(has_u and not has_space and (game.call(&"get_setting", "bindings") as Dictionary).has("jump"),
		"pressing U rebinds Jump to U (Space is gone, and it's saved)")
	var pad_still := false
	for e in InputMap.action_get_events(&"jump"):
		pad_still = pad_still or (e is InputEventJoypadButton and e.button_index == JOY_BUTTON_A)
	check(pad_still, "and the pad's A is untouched")
	# Accessibility, then the mouse on Back.
	menu.show_page(3)
	await frames(3)
	var size_btn: Button = null
	for b in menu.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with("Text size"):
			size_btn = b
	size_btn.grab_focus()
	await tap_pad(JOY_BUTTON_DPAD_RIGHT)
	check(is_equal_approx(root.content_scale_factor, 1.2), "text size: the D-pad makes it Large (scale %.2f)" % root.content_scale_factor)
	game.call(&"set_setting", "text_size", 1)
	var back: Button = null
	for b in menu.find_children("*", "Button", true, false):
		if (b as Button).text == "Back":
			back = b
	await click(back)
	await frames(3)
	check(not hud.call(&"settings_open"), "a mouse click on Back closes the settings")


func _content_by_mouse() -> void:
	var title := current_scene
	var content: Button = title.find_child("Content", true, false)
	await click(content)
	await frames(3)
	check(title.get(&"screen") == "content", "a mouse click on \"Content\" shows the content card")
	await tap_key(KEY_ESCAPE)
	await frames(3)
	check(title.get(&"screen") == "main", "Esc comes back to the main menu")


func _play_slot() -> void:
	var title := current_scene
	(title.find_child("Saves", true, false) as Control).grab_focus()
	await tap_pad(JOY_BUTTON_A)
	await frames(3)
	check(title.get(&"screen") == "slots", "A on \"Saves\": the three slots")
	var play: Button = title.find_child("Slot1", true, false).get_node("Play")
	check(play.text.contains("empty"), "slot 1 is empty: \"%s\"" % play.text)
	play.grab_focus()
	await tap_pad(JOY_BUTTON_A)
	for i in 30:
		await process_frame
	check(current_scene != null and current_scene.scene_file_path == game.get(&"START_SCENE"), "A on slot 1 starts the game")
	await frames(5)
	check(hud.call(&"arrival_showing"), "with the world's arrival card")


func _hud() -> void:
	# A new game starts in the hub's prologue (Vesper's welcome is already under way: read it through). These checks
	# want Dash on the test course.
	for i in 40:
		if not dialogue.call(&"is_active"):
			break
		await frames(28)
		await tap_pad(JOY_BUTTON_A)
	var level: Node = load("res://levels/test_course/course.tscn").instantiate()
	current_scene.queue_free()
	await frames(2)
	root.add_child(level)
	current_scene = level
	await frames(10)
	var nim: Node3D = level.get(&"nim")
	var world_ui: Control = hud.get(&"_world_ui")
	var hearts: Node = hud.get(&"_hearts")
	check(world_ui.visible and hearts.get_child_count() == 5, "the HUD is up: five health")
	var dash: Node3D = level.get_node("Dash_k")
	nim.call(&"teleport", dash.global_position + Vector3(0, 0.05, 1.5), 0.0)
	await frames(4)
	await tap_pad(JOY_BUTTON_DPAD_LEFT)   # any pad press: the pad's in use
	await frames(3)
	var prompt: String = hud.get(&"_prompt").text
	check(prompt.begins_with("Y") and prompt.contains("Talk"), "beside Dash, the prompt says \"%s\" (pad)" % prompt)
	await tap_key(KEY_9)   # a key nobody uses: the keyboard's in use
	await frames(3)
	prompt = hud.get(&"_prompt").text
	check(prompt.begins_with("E") and prompt.contains("Talk"), "and \"%s\" on the keyboard" % prompt)
	nim.get(&"suit").call(&"set_outfit", 1)
	await frames(3)
	check((hud.get(&"_suit_box") as Control).visible, "in the suit, Composure shows")
	nim.get(&"suit").call(&"set_outfit", 0)
	hud.call(&"caption", "Staff", "At once.")
	check((hud.get(&"_caption") as Label).text.contains("At once."), "a caption shows with subtitles on")
	game.call(&"set_setting", "subtitles", false)
	hud.call(&"caption", "Staff", "Of course.")
	check(not (hud.get(&"_caption") as Label).text.contains("Of course."), "and not with them off")
	game.call(&"set_setting", "subtitles", true)


func _pause() -> void:
	await tap_pad(JOY_BUTTON_START)
	await frames(3)
	check(hud.call(&"paused") and paused, "Start pauses")
	var f := focused()
	check(f != null and f.text == "Resume", "with Resume focused")
	await tap_pad(JOY_BUTTON_DPAD_DOWN)
	await tap_pad(JOY_BUTTON_A)
	await frames(3)
	var help: Control = hud.get(&"_pause_help")
	var help_text: String = help.get_node("Text").text
	check(help.visible and help_text.contains("Jump"), "Controls lists the bindings")
	await tap_key(KEY_9)
	help_text = hud.call(&"_help_text")
	check(help_text.contains("Jump") and help_text.contains(" U"), "including the remap (Jump on U)")
	await tap_pad(JOY_BUTTON_B)
	await frames(3)
	check(not help.visible and (hud.get(&"_pause_menu") as Control).visible, "B goes back to the pause menu")
	f = focused()
	await tap_pad(JOY_BUTTON_DPAD_DOWN)
	await tap_pad(JOY_BUTTON_DPAD_DOWN)
	await tap_pad(JOY_BUTTON_A)
	await frames(4)
	check(hud.call(&"settings_open"), "Settings opens from the pause menu")
	await tap_pad(JOY_BUTTON_B)
	await frames(4)
	check(not hud.call(&"settings_open") and hud.call(&"paused"), "B closes it, back to pause")
	await tap_pad(JOY_BUTTON_START)
	await frames(3)
	check(not hud.call(&"paused") and not paused, "Start resumes")


func _paper() -> void:
	var world: Node = load("res://levels/probe_world/probe_world.tscn").instantiate()
	current_scene.queue_free()
	await frames(2)
	root.add_child(world)
	current_scene = world
	await frames(10)
	world.call(&"complete", false)
	await frames(5)
	var card: Node = dialogue.get(&"_card")
	check(card != null and card.visible, "a world's end plays its paper")
	await frames(30)
	await tap_pad(JOY_BUTTON_A)
	await frames(5)
	check(dialogue.get(&"_card") == null and not dialogue.call(&"is_active"), "A puts it down")
	check(game.call(&"has_flag", "done/probe"), "and the world's marked done")


func _erase() -> void:
	game.call(&"collect", &"key", &"probe", &"probe_01")
	current_scene.queue_free()
	await frames(2)
	var title: Node = load("res://levels/title/title.tscn").instantiate()
	root.add_child(title)
	current_scene = title
	await frames(3)
	title.call(&"show_slots")
	await frames(3)
	var row: Node = title.find_child("Slot1", true, false)
	check(row.has_node("Erase"), "slot 1 has a game now, so it can be erased")
	(row.get_node("Erase") as Control).grab_focus()
	await tap_pad(JOY_BUTTON_A)
	await frames(3)
	row = title.find_child("Slot1", true, false)
	check((row.get_node("Erase") as Button).text == "Sure?" and game.call(&"keys") == 1, "the first A asks \"Sure?\"")
	await tap_pad(JOY_BUTTON_A)
	await frames(3)
	row = title.find_child("Slot1", true, false)
	check(not row.has_node("Erase") and game.call(&"keys") == 0, "the second erases it")
