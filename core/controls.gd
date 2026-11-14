extends Node
## Every input in the game, bound in code so the bindings are readable (autoload "Controls", loaded first).
## Pad first: the Steam Deck is the test device. Keyboard and mouse get the same actions. Remapping comes with the
## settings screen (WO-010); it will write over these defaults, never replace this table.
##
##   Pad              Keys / mouse          Action
##   left stick       WASD                  move
##   right stick      mouse, arrow keys     camera (R3 / V / middle mouse recentres)
##   A                Space                 jump
##   X                J, left mouse         strike (hold for the crop)
##   Y                E                     bind, talk or Command (context)
##   B                C, Ctrl               crouch-sneak
##   RT               K                     pounce
##   LT               L, right mouse        lock on / pick a Command target
##   RB               Shift                 rope
##   LB               Q                     gear (Scold, pendant, lure)
##   D-pad            1 2 3 4               pick the Command word
##   Start            Esc, P                pause
##   Back             Tab                   flip between the test scenes (prototype only)

## Below this a stick or trigger counts as released.
const DEADZONE := 0.2

const HINT := "Move: left stick / WASD    Camera: right stick / mouse    Jump: A / Space    Crouch: B / C    Pounce: RT / K\nClimb: push into green walls    Ledges: A pulls up, B lets go    Recentre: R3 / V    Next scene: Back / Tab    Pause: Start / Esc\nStrike: X / J (three for a knockdown, hold for the crop)    Bind: Y / E (staggered, down, or unaware)    Lock on: LT / L / right mouse
In the suit: strut with the stick half-way (or B)    Command: LT picks, D-pad / 1-3 the word, Y says it    Wardrobe: Y
Gear: LB / Q (D-pad left / 4 picks)    Rope: RB / Shift (swing in the air; bind or pull on the ground)    Ceilings: jump up under them"

const KEYS := {
	&"move_left": [KEY_A], &"move_right": [KEY_D], &"move_up": [KEY_W], &"move_down": [KEY_S],
	&"cam_left": [KEY_LEFT], &"cam_right": [KEY_RIGHT], &"cam_up": [KEY_UP], &"cam_down": [KEY_DOWN],
	&"cam_recentre": [KEY_V],
	&"jump": [KEY_SPACE], &"strike": [KEY_J], &"interact": [KEY_E], &"crouch": [KEY_C, KEY_CTRL],
	&"pounce": [KEY_K], &"lock_on": [KEY_L], &"rope": [KEY_SHIFT], &"gear": [KEY_Q],
	&"word_up": [KEY_1], &"word_right": [KEY_2], &"word_down": [KEY_3], &"word_left": [KEY_4],
	&"pause": [KEY_ESCAPE, KEY_P], &"debug_swap": [KEY_TAB],
}
const MOUSE := {
	&"strike": [MOUSE_BUTTON_LEFT], &"lock_on": [MOUSE_BUTTON_RIGHT], &"cam_recentre": [MOUSE_BUTTON_MIDDLE],
}
const PAD_BUTTONS := {
	&"jump": [JOY_BUTTON_A], &"strike": [JOY_BUTTON_X], &"interact": [JOY_BUTTON_Y], &"crouch": [JOY_BUTTON_B],
	&"rope": [JOY_BUTTON_RIGHT_SHOULDER], &"gear": [JOY_BUTTON_LEFT_SHOULDER],
	&"word_up": [JOY_BUTTON_DPAD_UP], &"word_right": [JOY_BUTTON_DPAD_RIGHT],
	&"word_down": [JOY_BUTTON_DPAD_DOWN], &"word_left": [JOY_BUTTON_DPAD_LEFT],
	&"cam_recentre": [JOY_BUTTON_RIGHT_STICK], &"pause": [JOY_BUTTON_START], &"debug_swap": [JOY_BUTTON_BACK],
}
## action -> [axis, direction]. The triggers are axes on most pads, the Deck's included.
const PAD_AXES := {
	&"move_left": [JOY_AXIS_LEFT_X, -1.0], &"move_right": [JOY_AXIS_LEFT_X, 1.0],
	&"move_up": [JOY_AXIS_LEFT_Y, -1.0], &"move_down": [JOY_AXIS_LEFT_Y, 1.0],
	&"cam_left": [JOY_AXIS_RIGHT_X, -1.0], &"cam_right": [JOY_AXIS_RIGHT_X, 1.0],
	&"cam_up": [JOY_AXIS_RIGHT_Y, -1.0], &"cam_down": [JOY_AXIS_RIGHT_Y, 1.0],
	&"pounce": [JOY_AXIS_TRIGGER_RIGHT, 1.0], &"lock_on": [JOY_AXIS_TRIGGER_LEFT, 1.0],
}
const ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"move_up", &"move_down",
	&"cam_left", &"cam_right", &"cam_up", &"cam_down", &"cam_recentre",
	&"jump", &"strike", &"interact", &"crouch", &"pounce", &"lock_on", &"rope", &"gear",
	&"word_up", &"word_right", &"word_down", &"word_left", &"pause", &"debug_swap",
]


## Which the player used last: the HUD's button prompts follow it ("A" or "Space").
signal device_changed(pad: bool)

## Actions the settings screen lets the player rebind (movement and the camera stay on the sticks and WASD / mouse).
const REMAPPABLE: Array[StringName] = [&"jump", &"strike", &"interact", &"crouch", &"pounce", &"lock_on", &"rope",
	&"gear", &"cam_recentre", &"word_up", &"word_right", &"word_down", &"word_left", &"pause"]
## What the settings and prompts call them.
const ACTION_NAMES := {&"jump": "Jump", &"strike": "Strike (hold: the crop)", &"interact": "Bind / talk / command",
	&"crouch": "Crouch (strut, in the suit)", &"pounce": "Pounce", &"lock_on": "Lock on", &"rope": "Rope", &"gear": "Gear",
	&"cam_recentre": "Recentre the camera", &"word_up": "Command: Kneel", &"word_right": "Command: Fetch",
	&"word_down": "Command: Open", &"word_left": "Next gear", &"pause": "Pause"}
const PAD_NAMES := {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_RIGHT_STICK: "R3", JOY_BUTTON_START: "Start", JOY_BUTTON_BACK: "Back", JOY_BUTTON_DPAD_UP: "D-pad up",
	JOY_BUTTON_DPAD_DOWN: "D-pad down", JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right"}

var using_pad := false


func _enter_tree() -> void:
	setup()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# The game's look (fonts, the menus' Theme): first thing, before any screen is built.
	UiKit.apply(get_tree().root)
	apply_saved.call_deferred()


func _input(event: InputEvent) -> void:
	var pad := event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5)
	var keys := event is InputEventKey or event is InputEventMouseButton
	if (pad and not using_pad) or (keys and using_pad):
		using_pad = pad
		device_changed.emit(using_pad)
	# In a menu, the left stick moves the focus one step per push (then repeats slowly while held), never once per
	# motion event: the stick sends a stream of them, and each counted as a press, skipping options (owner, Deck
	# review 5: "each press fires insanely fast which skips menu options and makes the joystick unusable").
	if event is InputEventJoypadMotion and (event.axis == JOY_AXIS_LEFT_X or event.axis == JOY_AXIS_LEFT_Y) \
			and get_viewport() and get_viewport().gui_get_focus_owner() != null:
		get_viewport().set_input_as_handled()


## The menu stick's state: which way it's pushed, and when it next repeats.
const MENU_PUSH := 0.6
const MENU_RELEASE := 0.35
const MENU_FIRST_REPEAT := 0.45
const MENU_REPEAT := 0.16
var _menu_dir := Vector2i.ZERO
var _menu_t := 0.0


func _process(delta: float) -> void:
	var vp := get_viewport()
	if vp == null or vp.gui_get_focus_owner() == null:
		_menu_dir = Vector2i.ZERO
		return
	var v := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	var dir := Vector2i.ZERO
	if v.length() > MENU_PUSH:
		dir = Vector2i(signi(roundi(v.x)), 0) if absf(v.x) > absf(v.y) else Vector2i(0, signi(roundi(v.y)))
	elif v.length() > MENU_RELEASE and _menu_dir != Vector2i.ZERO:
		dir = _menu_dir   # still held, just eased off a little
	if dir == Vector2i.ZERO:
		_menu_dir = Vector2i.ZERO
		return
	if dir != _menu_dir:
		_menu_dir = dir
		_menu_t = MENU_FIRST_REPEAT
		_menu_step(dir)
		return
	_menu_t -= delta
	if _menu_t <= 0.0:
		_menu_t = MENU_REPEAT
		_menu_step(dir)


func _menu_step(dir: Vector2i) -> void:
	var action := &"ui_up" if dir.y < 0 else (&"ui_down" if dir.y > 0 else (&"ui_left" if dir.x < 0 else &"ui_right"))
	for pressed in [true, false]:
		var e := InputEventAction.new()
		e.action = action
		e.pressed = pressed
		Input.parse_input_event(e)


# --- remapping (the settings screen) ---------------------------------------------------------------------------------

## Replaces `action`'s binding on the same kind of device as `event` (a key or mouse button replaces the keyboard
## one; a pad button or trigger replaces the pad one), and saves it.
func rebind(action: StringName, event: InputEvent) -> void:
	var pad := _is_pad(event)
	for e in InputMap.action_get_events(action):
		if _is_pad(e) == pad:
			InputMap.action_erase_event(action, e)
	InputMap.action_add_event(action, event)
	_save()


## Every remappable action back to the table at the top of this file.
func reset_bindings() -> void:
	for action in REMAPPABLE:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
	setup()
	var game := get_node_or_null(^"/root/Game")
	if game:
		game.call(&"set_setting", "bindings", {})


## Loads the player's saved bindings over the defaults.
func apply_saved() -> void:
	var game := get_node_or_null(^"/root/Game")
	if game == null:
		return
	var saved: Dictionary = game.call(&"get_setting", "bindings", {})
	for a: String in saved:
		var action := StringName(a)
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		for d: Dictionary in saved[a]:
			var e := _from_dict(d)
			if e:
				InputMap.action_add_event(action, e)


func _save() -> void:
	var out := {}
	for action in REMAPPABLE:
		var list: Array = []
		for e in InputMap.action_get_events(action):
			var d := _to_dict(e)
			if not d.is_empty():
				list.append(d)
		out[String(action)] = list
	var game := get_node_or_null(^"/root/Game")
	if game:
		game.call(&"set_setting", "bindings", out)


func _is_pad(e: InputEvent) -> bool:
	return e is InputEventJoypadButton or e is InputEventJoypadMotion


func _to_dict(e: InputEvent) -> Dictionary:
	if e is InputEventKey:
		return {"t": "key", "code": int(e.physical_keycode)}
	if e is InputEventMouseButton:
		return {"t": "mouse", "b": int(e.button_index)}
	if e is InputEventJoypadButton:
		return {"t": "joy", "b": int(e.button_index)}
	if e is InputEventJoypadMotion:
		return {"t": "axis", "a": int(e.axis), "v": signf(e.axis_value)}
	return {}


func _from_dict(d: Dictionary) -> InputEvent:
	match d.get("t", ""):
		"key":
			var e := InputEventKey.new()
			e.physical_keycode = int(d["code"])
			return e
		"mouse":
			var e := InputEventMouseButton.new()
			e.button_index = int(d["b"])
			return e
		"joy":
			var e := InputEventJoypadButton.new()
			e.button_index = int(d["b"])
			return e
		"axis":
			var e := InputEventJoypadMotion.new()
			e.axis = int(d["a"])
			e.axis_value = float(d["v"])
			return e
	return null


# --- names, for prompts and the settings screen ----------------------------------------------------------------------

## The button for `action` on the device in use ("A", "Space", "LT"), or on the pad / keyboard if `pad` is given.
func glyph(action: StringName, pad: Variant = null) -> String:
	var want_pad: bool = using_pad if pad == null else pad
	if not InputMap.has_action(action):
		return "?"
	for e in InputMap.action_get_events(action):
		if _is_pad(e) == want_pad:
			return event_text(e)
	return "-"


func event_text(e: InputEvent) -> String:
	if e is InputEventKey:
		var code: Key = e.physical_keycode if e.physical_keycode != KEY_NONE else e.keycode
		# The key's name in the player's own layout (a QWERTY "Q" is an AZERTY "A"); headless has no layout to ask.
		if DisplayServer.get_name() != "headless":
			code = DisplayServer.keyboard_get_keycode_from_physical(code)
		return OS.get_keycode_string(code)
	if e is InputEventMouseButton:
		return {MOUSE_BUTTON_LEFT: "Left mouse", MOUSE_BUTTON_RIGHT: "Right mouse",
			MOUSE_BUTTON_MIDDLE: "Middle mouse"}.get(e.button_index, "Mouse %d" % e.button_index)
	if e is InputEventJoypadButton:
		return PAD_NAMES.get(e.button_index, "Button %d" % e.button_index)
	if e is InputEventJoypadMotion:
		match e.axis:
			JOY_AXIS_TRIGGER_LEFT:
				return "LT"
			JOY_AXIS_TRIGGER_RIGHT:
				return "RT"
			JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y:
				return "Left stick"
			JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y:
				return "Right stick"
	return "?"


func setup() -> void:
	for action in ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, DEADZONE)
		for k: Key in KEYS.get(action, []):
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(action, e)
		for m: MouseButton in MOUSE.get(action, []):
			var e := InputEventMouseButton.new()
			e.button_index = m
			InputMap.action_add_event(action, e)
		for b: JoyButton in PAD_BUTTONS.get(action, []):
			var e := InputEventJoypadButton.new()
			e.button_index = b
			InputMap.action_add_event(action, e)
		if PAD_AXES.has(action):
			var e := InputEventJoypadMotion.new()
			e.axis = PAD_AXES[action][0]
			e.axis_value = PAD_AXES[action][1]
			InputMap.action_add_event(action, e)
	# Menus: Godot's ui_* actions already take the D-pad, A and B. Add the left stick, so every screen steers either way.
	_add_axis(&"ui_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_axis(&"ui_down", JOY_AXIS_LEFT_Y, 1.0)
	_add_axis(&"ui_left", JOY_AXIS_LEFT_X, -1.0)
	_add_axis(&"ui_right", JOY_AXIS_LEFT_X, 1.0)
	_add_button(&"ui_accept", JOY_BUTTON_A)
	_add_button(&"ui_cancel", JOY_BUTTON_B)


## The left stick or WASD as a camera-space vector, x right and y down the screen (Input.get_vector's convention).
func move_vector() -> Vector2:
	return Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")


func camera_vector() -> Vector2:
	return Input.get_vector(&"cam_left", &"cam_right", &"cam_up", &"cam_down")


func _add_axis(action: StringName, axis: JoyAxis, dir: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = dir
	if not InputMap.action_has_event(action, e):
		InputMap.action_add_event(action, e)


func _add_button(action: StringName, button: JoyButton) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	if not InputMap.action_has_event(action, e):
		InputMap.action_add_event(action, e)
