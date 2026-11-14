extends CanvasLayer
## Everything on screen that isn't the world (autoload "Hud", WO-010; redrawn 2026-11-13 on core/ui_kit.gd, owner: "A HUD
## art pass... Let's change out the 'health' resource to something cute and witty"):
##
##   top left       **Dignity** (her health): five little tiaras, and the verdict on them ("Immaculate" down to "Hanging
##                  by a Thread"). A hit tips one over. Under it, the light: an eye that opens as she's lit.
##   top middle     the zone she's walked into, on a ribbon; a world's arrival card
##   top right      the Banjo-style pop-up when she picks something up (its icon, its count); the frame rate, if on
##   bottom left    in the suit, Composure (the mask; COVER BLOWN) and the Command word; the gear on LB
##   bottom middle  what Y does here, as a pill with the button drawn; short notes; captions
## and the pause screen (each world's tallies, rank, and the menu), the pad-first chooser (fast travel), the settings
## screen, and the age gate. Settings (text size, fps, volume, fullscreen, subtitles) apply here as they change.
## The readouts are drawn on one canvas (`_world_ui`'s draw): no boxes of labels; the labels kept (`_caption`, `_zone`,
## the hidden `_prompt`) hold the text for the probes.

const AgeGate := preload("res://core/age_gate.gd")
const TEXT_SCALES := [0.85, 1.0, 1.2]
## Dignity's verdicts, by how much is left (the last that fits).
const VERDICTS := [[1.0, "Immaculate"], [0.79, "Intact"], [0.59, "Ruffled"], [0.39, "Bruised"], [0.21, "Tattered"],
	[0.0, "Hanging by a Thread"]]
const PICKUP_ICONS := {&"key": "rose", &"contraband": "box", &"freed": "zzz", &"tin": "tin"}
const PICKUP_NAMES := {&"key": "Velvet Roses", &"contraband": "Contraband", &"freed": "Woken", &"tin": "Collection Tin"}

## The open age gate, or null.
var gate: AgeGate
var _world_ui: Control
var _hearts: Node   # (kept for old probes: one child per point of Dignity)
var _suit_box: Control
var _prompt: Label
var _note: Label
var _caption: Label
var _zone: Label
var _fps: Label
var _pause: Control
var _pause_menu: VBoxContainer
var _pause_help: Control
var _resume: Button
## The pause screen's border (this world's tallies in its corners, drawn) and its centred title.
var _pause_frame: Control
var _pause_title: Label
var _pause_area: Label
var _pause_rank: Label
var _totals: LevelTotals
## The world the last zone name was shown in, so the pause screen never shows another world's area.
var _zone_world: StringName = &""
var _chooser: Control
var _settings: SettingsMenu

# What's shown.
var _dignity := 5
var _dignity_max := 5
var _hit_t := 0.0          # a tiara just lost: it wobbles
var _hit_i := -1
var _light := 0.0
var _light_shown := 0.0
var _composure := 1.0
var _composure_shown := 1.0
var _blown := false
var _in_suit := false
var _word := ""
var _gear := ""
var _lures := 0
var _prompt_what := ""
var _note_t := 0.0
var _caption_t := 0.0
var _zone_t := 0.0
var _arrival_title := ""
var _arrival_sub := ""
var _arrival_t := 0.0
var _arrival_len := 3.5
var _counter_kind: StringName = &""
var _counter_text := ""
var _counter_world := ""
var _counter_t := 0.0
var _t := 0.0


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

## Dignity (Nim's health, as the HUD calls it).
func set_health(current: int, maximum: int) -> void:
	show_world_ui(true)
	if current < _dignity and maximum == _dignity_max:
		_hit_i = current
		_hit_t = 0.6
	_dignity = current
	_dignity_max = maximum
	while _hearts.get_child_count() < maximum:
		_hearts.add_child(Node.new())
	while _hearts.get_child_count() > maximum:
		var c := _hearts.get_child(_hearts.get_child_count() - 1)
		_hearts.remove_child(c)
		c.queue_free()


func dignity_verdict() -> String:
	var f := float(_dignity) / maxf(1.0, float(_dignity_max))
	for v: Array in VERDICTS:
		if f >= float(v[0]) - 0.001:
			return v[1]
	return VERDICTS[VERDICTS.size() - 1][1]


## How lit Nim is, 0 (dark) to 1 (a lamp's pool).
func set_light(v: float) -> void:
	_light = clampf(v, 0.0, 1.0)


## The suit's Composure (shown only in the suit), and COVER BLOWN when it's gone.
func set_composure(value: float, blown: bool, outfit: int) -> void:
	_in_suit = outfit == 1
	_suit_box.visible = _in_suit
	_composure = clampf(value, 0.0, 1.0)
	_blown = blown


## The gear on LB (and how many lures are left).
func set_gear(gear: String, lures: int) -> void:
	_gear = gear
	_lures = lures


## The Command word the D-pad has picked.
func set_word(word: StringName) -> void:
	_word = UiKit.title_case(String(word).capitalize())


## What Y does right now ("" for nothing), shown with the button for the device in use.
## `action`: the button it's for (Y by default; X for "strike the toy" beside someone in a trance).
func set_prompt(what: String, action: StringName = &"interact") -> void:
	_prompt_what = UiKit.title_case(what)
	_prompt_action = action
	_prompt.text = "" if what == "" else "%s   %s" % [Controls.glyph(action), _prompt_what]


var _prompt_action: StringName = &"interact"


# --- the guide: what to do next, and which way (owner, from a first playthrough: "Need a guide or arrow to assist
# with story progression") ------------------------------------------------------------------------------------------

var _goal_text := ""
var _goal_at := Vector3.INF


## The current objective, shown under Dignity until it changes, with a marker over `at` (or an arrow at the screen's
## edge toward it) when it's in this scene. "" clears it.
func set_goal(text: String, at := Vector3.INF) -> void:
	_goal_text = text
	_goal_at = at


func goal_text() -> String:
	return _goal_text


func _draw_goal(c: Control, vp: Vector2) -> void:
	if _goal_text == "" or not bool(Game.get_setting("show_guide", true)):
		return
	# The line, under the Dignity card.
	var font := UiKit.bold()
	var lines := _wrap(_goal_text, font, 16, 330.0)
	var h := 20.0 * lines.size() + 16.0
	var box := Rect2(16, 128, 360, h)
	c.draw_style_box(UiKit.card(12, 0.8), box)
	c.draw_circle(box.position + Vector2(16, 18), 5.0, UiKit.GOLD)
	for i in lines.size():
		UiKit.text(c, font, box.position + Vector2(30, 24 + i * 20), lines[i], 16, UiKit.CREAM)
	# The marker: over the place if it's in front of the camera and on screen, else a chevron on the edge.
	if _goal_at == Vector3.INF:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var n := _nim()
	var dist: float = n.global_position.distance_to(_goal_at) if n else 0.0
	if dist < 3.0:
		return
	var at := _goal_at + Vector3.UP * 2.2
	var ahead := not cam.is_position_behind(at)
	var p := cam.unproject_position(at)
	var margin := 48.0
	if vp.x < margin * 3.0 or vp.y < margin * 3.0:
		return   # (a probe's 64-pixel window: no room for a marker)
	var bob := sin(_t * 3.0) * 5.0
	var label := "%d m" % roundi(dist)
	if ahead and Rect2(Vector2(margin, margin), vp - Vector2(margin, margin) * 2.0).has_point(p):
		var tip := p + Vector2(0, bob)
		c.draw_colored_polygon(PackedVector2Array([tip + Vector2(-12, -22), tip + Vector2(12, -22), tip]), UiKit.GOLD)
		c.draw_polyline(PackedVector2Array([tip + Vector2(-12, -22), tip + Vector2(12, -22), tip, tip + Vector2(-12, -22)]),
			UiKit.INK, 2.0, true)
		UiKit.text(c, UiKit.display(), tip + Vector2(-30, -30), label, 16, UiKit.CREAM, HORIZONTAL_ALIGNMENT_CENTER, 60)
		return
	# Off screen (or behind): point from the middle toward it, pinned to the edge.
	var centre := vp / 2.0
	var d := p - centre
	if not ahead:
		d = -d
	if d.length() < 1.0:
		d = Vector2(0, 1)
	d = d.normalized()
	var half := centre - Vector2(margin, margin)
	var k := minf(half.x / maxf(absf(d.x), 0.001), half.y / maxf(absf(d.y), 0.001))
	var edge := centre + d * k
	var side := Vector2(-d.y, d.x)
	var pts := PackedVector2Array([edge + d * 16, edge - d * 10 + side * 14, edge - d * 10 - side * 14])
	c.draw_colored_polygon(pts, UiKit.GOLD)
	pts.append(pts[0])
	c.draw_polyline(pts, UiKit.INK, 2.0, true)
	UiKit.text(c, UiKit.display(), edge - d * 34 + Vector2(-30, 6), label, 16, UiKit.CREAM, HORIZONTAL_ALIGNMENT_CENTER, 60)


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
	_zone.text = UiKit.title_case(text)
	_zone_t = 3.0
	_zone_world = _here()


## The world she's in (the current scene's world_id), or &"" off a level.
func _here() -> StringName:
	var scene := get_tree().current_scene if is_inside_tree() else null
	if scene == null:
		return &""
	var w: Variant = scene.get(&"world_id")
	return w if w is StringName else &""


## A world's arrival card: its name, large, and a line under it, for a few seconds.
func arrival(title: String, subtitle := "", secs := 3.5) -> void:
	_arrival_title = UiKit.title_case(title)
	_arrival_sub = subtitle
	_arrival_t = secs
	_arrival_len = secs


func arrival_showing() -> bool:
	return _arrival_t > 0.0


# --- pause, the chooser, settings ------------------------------------------------------------------------------------

func paused() -> bool:
	return _pause.visible


func set_paused(on: bool) -> void:
	_pause.visible = on
	get_tree().paused = on
	# The play HUD (Dignity, the counters) fades out under the pause screen: its corners are the tallies' now.
	_world_ui.modulate.a = 0.0 if on else 1.0
	if on:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_fill_pause()
		_show_pause_help(false)
		_pause_kit.visible = false
		_totals.visible = false
		_resume.grab_focus()


## A short pad-first list (fast travel): up and down pick, A takes it, B backs out. The world waits meanwhile.
func choose(title: String, options: Array[String], on_pick: Callable) -> void:
	if _chooser:
		_chooser.queue_free()
	_chooser = Control.new()
	_chooser.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_chooser)
	var col := Menu.panel(_chooser, 380.0)
	Menu.heading(col, title, 32)
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
	_t += delta
	if _fps.visible:
		_fps.text = "%d fps" % Engine.get_frames_per_second()
	_note_t = maxf(_note_t - delta, 0.0)
	_caption_t = maxf(_caption_t - delta, 0.0)
	_zone_t = maxf(_zone_t - delta, 0.0)
	_counter_t = maxf(_counter_t - delta, 0.0)
	_arrival_t = maxf(_arrival_t - delta, 0.0)
	_hit_t = maxf(_hit_t - delta, 0.0)
	_light_shown = lerpf(_light_shown, _light, clampf(delta * 6.0, 0.0, 1.0))
	_composure_shown = lerpf(_composure_shown, _composure, clampf(delta * 8.0, 0.0, 1.0))
	_note.modulate.a = clampf(_note_t * 2.0, 0.0, 1.0)
	_caption.modulate.a = clampf(_caption_t * 2.0, 0.0, 1.0)
	_zone.modulate.a = 0.0   # (drawn on its ribbon; the label holds the text)
	if _world_ui.visible:
		_world_ui.queue_redraw()


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
		elif _pause_kit.visible:
			_show_kit(false)
		elif _totals.visible:
			show_totals(false)
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
	# A "key" in the code is a Velvet Rose on screen (owner, 2026-11-12): the Claw's rose for good work.
	_counter_kind = kind
	_counter_text = "%d / %d" % [Game.count(kind, world), Game.total(kind, world)] if kind != &"tin" else "Smashed!"
	_counter_world = Game.NAMES.get(world, String(world))
	_counter_t = 3.2
	if kind == &"key":
		note("Velvet Roses: %d. Rank %d." % [Game.keys(), Game.rank()], 3.0)
	elif kind == &"contraband" and not Game.has_flag("taught/contraband"):
		Game.set_flag("taught/contraband")
		note("Contraband: one of Swyne's toys, off the street. Take what you seize to Rivet at the club: she turns it into gear.", 7.0)


# --- drawing the readouts --------------------------------------------------------------------------------------------

func _draw_world() -> void:
	var c := _world_ui
	var vp := c.size
	_draw_dignity(c)
	if _in_suit:
		_draw_suit(c, vp)
	_draw_gear(c, vp)
	_draw_goal(c, vp)
	_draw_prompt(c, vp)
	_draw_note(c, vp)
	_draw_zone(c, vp)
	_draw_arrival(c, vp)
	_draw_counter(c, vp)
	_draw_wheel(c, vp)


## Each piece of LB gear's icon.
const GEAR_ICONS := {"gear_scold": "gear", "gear_pendant": "pendant", "gear_lure": "lure"}


## The gear wheel (NimGear: LB held): the world dims and slows, her gear round a ring, the stick's pick lit, its name
## in the middle.
func _draw_wheel(c: Control, vp: Vector2) -> void:
	var n := _nim()
	var gear: Node = n.get(&"gear") if n else null
	if gear == null or not bool(gear.get(&"wheel_open")):
		return
	c.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.03, 0.01, 0.05, 0.45))
	var items: Array = gear.get(&"wheel_items")
	var pick: int = gear.get(&"wheel_pick")
	var centre := vp / 2.0
	var r := 120.0
	c.draw_circle(centre, r + 62.0, Color(UiKit.PLUM, 0.9))
	c.draw_arc(centre, r + 62.0, 0, TAU, 64, UiKit.GOLD_DEEP, 3.0, true)
	c.draw_arc(centre, 58.0, 0, TAU, 48, Color(UiKit.GOLD_DEEP, 0.6), 2.0, true)
	for i in items.size():
		var a := i * TAU / items.size() - PI / 2.0
		var at := centre + Vector2(cos(a), sin(a)) * r
		var on := i == pick
		c.draw_circle(at, 44.0 if on else 38.0, Color(UiKit.VELVET, 0.95) if on else Color(0.12, 0.06, 0.13, 0.95))
		c.draw_arc(at, 44.0 if on else 38.0, 0, TAU, 40, UiKit.GOLD if on else Color(UiKit.GOLD_DEEP, 0.6), 4.0 if on else 2.0, true)
		UiKit.icon(c, GEAR_ICONS.get(items[i], "gear"), at, 46.0 if on else 38.0, UiKit.GOLD if on else UiKit.CREAM)
	var name_text: String = UiKit.title_case(Lessons.NAMES.get(items[pick], "")) if pick >= 0 and pick < items.size() else "Gear"
	UiKit.text(c, UiKit.display(), Vector2(centre.x - 120, centre.y + 4), name_text, 22, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 240, 6)
	UiKit.text(c, UiKit.bold(), Vector2(centre.x - 260, centre.y + r + 100), "Point with the stick. Let go of LB to take it.", 16,
		UiKit.CREAM, HORIZONTAL_ALIGNMENT_CENTER, 520, 5)


## Top left: Dignity's tiaras and verdict, and the light's eye.
func _draw_dignity(c: Control) -> void:
	var n := maxi(_dignity_max, 1)
	var icon := 30.0
	var gap := 6.0
	var w := maxf(n * (icon + gap) + 26.0, 236.0)
	var box := Rect2(16, 14, w, 100)
	c.draw_style_box(UiKit.card(14, 0.82), box)
	var low := float(_dignity) / float(n) <= 0.21
	UiKit.text(c, UiKit.display(), box.position + Vector2(16, 28), "Dignity", 20, UiKit.GOLD)
	var verdict := dignity_verdict()
	var vc := UiKit.ROSE if low else UiKit.DIM
	if low:
		vc.a = 0.65 + 0.35 * sin(_t * 6.0)
	UiKit.text(c, UiKit.bold(), Vector2(box.position.x + 100, box.position.y + 27), verdict, 15, vc,
		HORIZONTAL_ALIGNMENT_RIGHT, box.size.x - 116, 4)
	for i in n:
		var at := box.position + Vector2(16 + icon / 2.0 + i * (icon + gap), 52)
		var lost := i >= _dignity
		var wob := 0.0
		if i == _hit_i and _hit_t > 0.0:
			wob = sin(_hit_t * 30.0) * _hit_t * 0.6
			at.y -= _hit_t * 10.0
		c.draw_set_transform(at, (0.35 if lost and not (i == _hit_i and _hit_t > 0.0) else 0.0) + wob, Vector2.ONE)
		UiKit.icon(c, "tiara", Vector2.ZERO, icon, UiKit.GOLD, 1.0, lost and not (i == _hit_i and _hit_t > 0.0))
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# The light: an eye, shut in the dark, wide open in a lamp's pool, with a word for it.
	var eye_at := box.position + Vector2(30, 84)
	UiKit.icon(c, "eye", eye_at, 30.0, Color("ffc860"), _light_shown)
	var bar := Rect2(box.position + Vector2(54, 79), Vector2(box.size.x - 140, 10))
	c.draw_style_box(UiKit.flat(Color(0.02, 0.01, 0.04, 0.95), Color(UiKit.GOLD_DEEP, 0.5), 1, 5, Vector4.ZERO), bar)
	var lit := Rect2(bar.position, Vector2(bar.size.x * _light_shown, bar.size.y))
	c.draw_style_box(UiKit.flat(Color("3a3070").lerp(Color("ffc860"), _light_shown), Color.TRANSPARENT, 0, 5, Vector4.ZERO), lit)
	var word := "Hidden" if _light_shown < 0.3 else ("Seen" if _light_shown > 0.7 else "Dim")
	UiKit.text(c, UiKit.bold(), Vector2(bar.end.x + 8, bar.position.y + 10), word, 14,
		UiKit.GREEN if word == "Hidden" else (UiKit.ROSE if word == "Seen" else UiKit.DIM), HORIZONTAL_ALIGNMENT_LEFT, -1, 4)


## Nim, from the level in play (for what the readouts can't be told: who's watching, what she knows).
func _nim() -> Node:
	var scene := get_tree().current_scene
	return scene.get(&"nim") if scene and scene.get(&"nim") != null else null


## Bottom left, in the suit: the mask and Composure, whether anyone's watching and what just cost her, and the three
## Commands on their D-pad buttons (the one picked lit; one she hasn't learned dim, with a lock).
func _draw_suit(c: Control, vp: Vector2) -> void:
	var n := _nim()
	var suit: Node = n.get(&"suit") if n else null
	var box := Rect2(16, vp.y - 196, 330, 128)
	c.draw_style_box(UiKit.card(14, 0.84), box)
	var shake := Vector2(sin(_t * 40.0) * 2.0, 0) if _blown else Vector2.ZERO
	UiKit.icon(c, "mask", box.position + Vector2(30, 28) + shake, 34.0, UiKit.RED if _blown else UiKit.CREAM)
	UiKit.text(c, UiKit.display(), box.position + Vector2(56, 28), "Cover Blown!" if _blown else "Composure", 19,
		UiKit.RED if _blown else UiKit.GOLD)
	# Watched or not: an open eye when anyone can see her (that's when slips cost), shut when nobody can.
	var watched: bool = suit != null and suit.get(&"watched") == true
	UiKit.icon(c, "eye", box.position + Vector2(box.size.x - 92, 21), 22.0, UiKit.ROSE if watched else UiKit.DIM, 1.0 if watched else 0.0)
	UiKit.text(c, UiKit.bold(), box.position + Vector2(box.size.x - 76, 27), "Watched" if watched else "Unseen", 14,
		UiKit.ROSE if watched else UiKit.DIM, HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
	var bar := Rect2(box.position + Vector2(56, 38), Vector2(box.size.x - 72, 12))
	c.draw_style_box(UiKit.flat(Color(0.02, 0.01, 0.04, 0.95), Color(UiKit.GOLD_DEEP, 0.5), 1, 6, Vector4.ZERO), bar)
	var fill := Rect2(bar.position, Vector2(bar.size.x * _composure_shown, bar.size.y))
	c.draw_style_box(UiKit.flat(UiKit.RED if _blown else Color("e8d0e0"), Color.TRANSPARENT, 0, 6, Vector4.ZERO), fill)
	# What just cost her, under the bar.
	var why := ""
	if suit and float(suit.get(&"slip_t")) > 0.0:
		why = String(suit.get(&"slip"))
	if _blown:
		why = "Get out of sight, or change at a wardrobe"
	if why != "":
		UiKit.text(c, UiKit.bold(), box.position + Vector2(56, 68), ("−  " if not _blown else "") + why, 14, UiKit.ROSE,
			HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 66, 4)
	# The Commands: up Kneel, right Fetch, down Open.
	var y := box.end.y - 24
	var x := box.position.x + 14
	var words := [[&"word_up", "Kneel", ""], [&"word_right", "Fetch", "lesson_fetch_open"], [&"word_down", "Open", "lesson_fetch_open"]]
	for wd: Array in words:
		var known: bool = String(wd[2]) == "" or (n != null and bool(n.call(&"knows", wd[2])))
		var on: bool = _word == wd[1]
		var gw := UiKit.draw_glyph(c, Vector2(x, y), wd[0], 24.0)
		var col := UiKit.GOLD if on else (UiKit.CREAM if known else Color(UiKit.DIM, 0.6))
		var label: String = wd[1] if known else "?"
		UiKit.text(c, UiKit.display() if on else UiKit.bold(), Vector2(x + gw + 6, y + 7), label, 17 if on else 15, col)
		x += gw + 14 + UiKit.display().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 18


## Bottom left, under the suit's box: the crop on X (once Dash has given it), and the gear on LB.
func _draw_gear(c: Control, vp: Vector2) -> void:
	var n := _nim()
	var crop_x := 16.0
	if n and bool(n.call(&"knows", Lessons.CROP)):
		var label := "Crop" if _in_suit and not _blown else "Hold: Crop"
		var tw := UiKit.bold().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		var cb := Rect2(16, vp.y - 58, tw + 70, 42)
		c.draw_style_box(UiKit.card(21, 0.8), cb)
		var gw := UiKit.draw_glyph(c, Vector2(cb.position.x + 12, cb.get_center().y), &"strike", 26.0)
		UiKit.text(c, UiKit.bold(), Vector2(cb.position.x + 22 + gw, cb.get_center().y + 6), label, 17, UiKit.CREAM)
		crop_x = cb.end.x + 10
	# Silke's rope, on RB.
	if n and bool(n.call(&"knows", Lessons.ROPE)):
		var rgw := UiKit.glyph_width(&"rope", 26.0)
		var rb := Rect2(crop_x, vp.y - 58, rgw + 106, 42)
		c.draw_style_box(UiKit.card(21, 0.8), rb)
		var gw := UiKit.draw_glyph(c, Vector2(rb.position.x + 12, rb.get_center().y), &"rope", 26.0)
		UiKit.icon(c, "rope", Vector2(rb.position.x + 26 + gw, rb.get_center().y), 22.0, UiKit.GOLD)
		UiKit.text(c, UiKit.bold(), Vector2(rb.position.x + 42 + gw, rb.get_center().y + 6), "Rope", 17, UiKit.CREAM)
		crop_x = rb.end.x + 10
	if _gear == "":
		return
	var name_text := UiKit.title_case(Lessons.NAMES.get(_gear, _gear)) + ("  x%d" % _lures if _gear == Lessons.LURE else "")
	var tw := UiKit.bold().get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	var box := Rect2(crop_x, vp.y - 58, tw + 108, 42)
	c.draw_style_box(UiKit.card(21, 0.8), box)
	var gw := UiKit.draw_glyph(c, Vector2(box.position.x + 12, box.get_center().y), &"gear", 26.0)
	UiKit.icon(c, GEAR_ICONS.get(_gear, "gear"), Vector2(box.position.x + 24 + gw, box.get_center().y), 24.0, UiKit.GOLD)
	UiKit.text(c, UiKit.bold(), Vector2(box.position.x + 42 + gw, box.get_center().y + 6), name_text, 17, UiKit.CREAM)
	# With more than one, a reminder the wheel's on a held LB.
	var have := Lessons.LB_GEAR.filter(func(g: String) -> bool: return n != null and bool(n.call(&"knows", g)))
	if have.size() > 1:
		UiKit.text(c, UiKit.bold(), Vector2(box.position.x + 4, box.position.y - 6), "Hold for the Wheel", 13, UiKit.DIM,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 4)


## Bottom middle: what Y does, a pill with the button drawn.
func _draw_prompt(c: Control, vp: Vector2) -> void:
	if _prompt_what == "":
		return
	var h := 32.0
	var tw := UiKit.display().get_string_size(_prompt_what, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	var gw := UiKit.glyph_width(_prompt_action, h)
	var w := gw + tw + 40.0
	var bob := sin(_t * 3.0) * 2.0
	var box := Rect2(vp.x / 2.0 - w / 2.0, vp.y - 172 + bob, w, h + 14)
	c.draw_style_box(UiKit.card(int((h + 14) / 2.0), 0.85), box)
	UiKit.draw_glyph(c, Vector2(box.position.x + 12, box.get_center().y), _prompt_action, h)
	UiKit.text(c, UiKit.display(), Vector2(box.position.x + 22 + gw, box.get_center().y + 8), _prompt_what, 22, UiKit.CREAM)


## A note: a toast card with a gold "!" badge, over the prompt.
func _draw_note(c: Control, vp: Vector2) -> void:
	if _note_t <= 0.0 or _note.text == "":
		return
	var a := clampf(_note_t * 2.0, 0.0, 1.0)
	var maxw := minf(vp.x * 0.62, 760.0)
	var font := UiKit.bold()
	var lines := _wrap(_note.text, font, 18, maxw - 70)
	var h := 22.0 * lines.size() + 24.0
	var w := 0.0
	for l: String in lines:
		w = maxf(w, font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x)
	w += 76.0
	var box := Rect2(vp.x / 2.0 - w / 2.0, vp.y - 236 - h + (1.0 - a) * 12.0, w, h)
	c.draw_style_box(UiKit.card(14, 0.88 * a), box)
	UiKit.icon(c, "bang", box.position + Vector2(28, h / 2.0), 26.0, Color(UiKit.GOLD, a))
	for i in lines.size():
		UiKit.text(c, font, box.position + Vector2(52, 30 + i * 22.0), lines[i], 18, Color(Color("ffe6b0"), a))


## Top middle: the zone, on a velvet ribbon that drops in.
func _draw_zone(c: Control, vp: Vector2) -> void:
	if _zone_t <= 0.0 or _zone.text == "" or _arrival_t > 0.0:
		return
	var a := clampf(_zone_t * 1.5, 0.0, 1.0)
	var drop := clampf((3.0 - _zone_t) * 5.0, 0.0, 1.0)
	var tw := UiKit.display().get_string_size(_zone.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	var w := tw + 90.0
	var y := lerpf(-50.0, 20.0, drop)
	_ribbon(c, Rect2(vp.x / 2.0 - w / 2.0, y, w, 50), a)
	UiKit.text(c, UiKit.display(), Vector2(vp.x / 2.0 - w / 2.0, y + 36), _zone.text, 30, Color(UiKit.GOLD, a),
		HORIZONTAL_ALIGNMENT_CENTER, w, 8)


## A velvet ribbon with notched ends and a gold edge.
func _ribbon(c: Control, r: Rect2, a: float) -> void:
	var n := r.size.y * 0.35
	var pts := PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0), r.end - Vector2(n, r.size.y / 2.0),
		r.end, r.position + Vector2(0, r.size.y), r.position + Vector2(n, r.size.y / 2.0)])
	c.draw_colored_polygon(pts, Color(UiKit.VELVET, 0.92 * a))
	pts.append(pts[0])
	c.draw_polyline(pts, Color(UiKit.GOLD, 0.85 * a), 2.0, true)


## A world's arrival: its name, huge, on a ribbon; the line under it.
func _draw_arrival(c: Control, vp: Vector2) -> void:
	if _arrival_t <= 0.0:
		return
	var age := _arrival_len - _arrival_t
	var a := clampf(_arrival_t, 0.0, 1.0) * clampf(age * 3.0, 0.0, 1.0)
	var pop := 1.0 + 0.25 * maxf(0.0, 1.0 - age * 4.0)
	var size := int(64 * pop)
	var tw := UiKit.display().get_string_size(_arrival_title, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var w := tw + 140.0
	var y := vp.y * 0.24
	_ribbon(c, Rect2(vp.x / 2.0 - w / 2.0, y, w, 92), a)
	UiKit.text(c, UiKit.display(), Vector2(vp.x / 2.0 - w / 2.0, y + 70), _arrival_title, size, Color(UiKit.GOLD, a),
		HORIZONTAL_ALIGNMENT_CENTER, w, 12)
	if _arrival_sub != "":
		var lines := _wrap(_arrival_sub, UiKit.bold(), 22, minf(vp.x * 0.7, 820.0))
		for i in lines.size():
			UiKit.text(c, UiKit.bold(), Vector2(vp.x * 0.15, y + 132 + i * 28.0), lines[i], 22, Color(UiKit.CREAM, a),
				HORIZONTAL_ALIGNMENT_CENTER, vp.x * 0.7, 6)


## Top right, Banjo-style: the pick-up's icon, the count, the world.
func _draw_counter(c: Control, vp: Vector2) -> void:
	if _counter_t <= 0.0:
		return
	var age := 3.2 - _counter_t
	var slide := clampf(age * 5.0, 0.0, 1.0) * clampf(_counter_t * 3.0, 0.0, 1.0)
	var box := Rect2(vp.x - 16 - 270 * slide, 70, 270, 92)
	c.draw_style_box(UiKit.card(16, 0.9), box)
	var bump := 1.0 + 0.35 * maxf(0.0, 1.0 - age * 3.0)
	UiKit.icon(c, PICKUP_ICONS.get(_counter_kind, "rose"), box.position + Vector2(46, 46), 52.0 * bump, UiKit.ROSE
		if _counter_kind == &"key" else (UiKit.GOLD if _counter_kind != &"freed" else Color("9fdcff")))
	UiKit.text(c, UiKit.display(), box.position + Vector2(86, 48), _counter_text, int(34 * bump), UiKit.CREAM)
	UiKit.text(c, UiKit.bold(), box.position + Vector2(86, 74), "%s  ·  %s" % [PICKUP_NAMES.get(_counter_kind, ""), _counter_world],
		13, UiKit.DIM, HORIZONTAL_ALIGNMENT_LEFT, 176, 4)


## Words to lines no wider than `width`.
func _wrap(s: String, font: Font, size: int, width: float) -> Array[String]:
	var out: Array[String] = []
	var line := ""
	for w: String in s.split(" "):
		var next := w if line == "" else line + " " + w
		if line != "" and font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
			out.append(line)
			line = w
		else:
			line = next
	if line != "":
		out.append(line)
	return out


# --- the pause screen ------------------------------------------------------------------------------------------------

## Every world's tallies as text (the probes read it; the screen shows the corners and Level Totals).
func _tally_text() -> String:
	var lines: Array[String] = []
	lines.append("%-22s %6s %10s %7s %5s" % ["", "Roses", "Contraband", "Woken", "Tin"])
	for w: StringName in Game.WORLDS:
		if w == &"city_hall":
			continue
		var wname: String = Game.NAMES.get(w, String(w))
		if not Game.world_open(w):
			lines.append("%-22s %s" % [wname, "locked"])
			continue
		lines.append("%-22s %6s %10s %7s %5s" % [wname, _tally(&"key", w), _tally(&"contraband", w), _tally(&"freed", w),
			_tally(&"tin", w)])
	lines.append("")
	lines.append(_summary_text())
	return "\n".join(lines)


func _tally(kind: StringName, w: StringName) -> String:
	if Game.total(kind, w) <= 0:
		return ""
	if kind == &"tin":
		return "Yes" if Game.count(&"tin", w) > 0 else "No"
	return "%d/%d" % [Game.count(kind, w), Game.total(kind, w)]


func _summary_text() -> String:
	var r := Game.rank()
	var next := "" if r >= Game.RANK_KEYS.size() else "  (Next at %d)" % Game.RANK_KEYS[r]
	var s := "Velvet Roses: %d.  Rank %d%s" % [Game.keys(), r, next]
	var handed := int(Game.get_flag("rivet/handed", 0))
	var seized := Game.count(&"contraband")
	if seized > 0:
		s += "\nContraband Seized: %d%s" % [seized, "" if seized <= handed else "  (%d Still to Hand to Rivet)" % (seized - handed)]
	return s


## The pause screen (owner, 2026-11-13): the world she's in, its area under it, centred over the menu; this world's
## tallies round the border, one to a corner, each with its icon.
func _fill_pause() -> void:
	var w := _here()
	_pause_title.text = UiKit.title_case(String(Game.NAMES.get(w, "Paused"))) if w != &"" else "Paused"
	_pause_area.text = _zone.text if _zone_world == w and w != &"" else ""
	_pause_area.visible = _pause_area.text != ""
	var r := Game.rank()
	_pause_rank.text = "Rank %d  ·  %d Velvet Roses" % [r, Game.keys()]
	_pause_frame.queue_redraw()


## The kinds this world tallies, in corner order (top left, top right, bottom left, bottom right).
func pause_corners() -> Array[StringName]:
	var out: Array[StringName] = []
	var w := _here()
	if w == &"":
		return out
	for k: StringName in LevelTotals.KINDS:
		if Game.total(k, w) > 0:
			out.append(k)
	return out


func _draw_pause_frame() -> void:
	var c := _pause_frame
	var vp := c.size
	var inset := 26.0
	# A thin gold border with a short rule broken at each corner, where the badges sit.
	var r := Rect2(Vector2(inset, inset), vp - Vector2(inset, inset) * 2.0)
	c.draw_rect(r, Color(UiKit.GOLD_DEEP, 0.55), false, 2.0)
	c.draw_rect(r.grow(-6.0), Color(UiKit.GOLD_DEEP, 0.25), false, 1.0)
	var w := _here()
	var kinds := pause_corners()
	var bw := 300.0
	var bh := 92.0
	var spots := [Vector2(inset + 18, inset + 18), Vector2(vp.x - inset - 18 - bw, inset + 18),
		Vector2(inset + 18, vp.y - inset - 18 - bh), Vector2(vp.x - inset - 18 - bw, vp.y - inset - 18 - bh)]
	for i in mini(kinds.size(), 4):
		var k := kinds[i]
		var at: Vector2 = spots[i]
		var full := LevelTotals.complete(k, w)
		var box := Rect2(at, Vector2(bw, bh))
		var sb := UiKit.flat(Color(0.1, 0.05, 0.11, 0.95), Color(UiKit.GOLD, 0.9) if full else Color(UiKit.GOLD_DEEP, 0.7),
			3 if full else 2, 14)
		c.draw_style_box(sb, box)
		var right := i % 2 == 1
		var icon_c := at + Vector2(bw - 48.0 if right else 48.0, bh / 2.0)
		c.draw_circle(icon_c, 36.0, Color(0.05, 0.02, 0.06, 0.9))
		UiKit.icon(c, LevelTotals.ICONS[k], icon_c, 52.0, UiKit.GOLD if Game.count(k, w) > 0 else Color(UiKit.DIM, 0.6))
		var tx := at.x + (18.0 if right else 96.0)
		var align := HORIZONTAL_ALIGNMENT_LEFT
		UiKit.text(c, UiKit.display(), Vector2(tx, at.y + 34.0), LevelTotals.NAMES[k], 20, UiKit.DIM, align)
		var count := LevelTotals.tally(k, w).replace(" / ", "/")
		UiKit.text(c, UiKit.display(), Vector2(tx, at.y + 74.0), count, 36, UiKit.GOLD if full else UiKit.CREAM, align)


## Every control, for the device in use, from the bindings as they are now (remaps included).
func _help_text() -> String:
	var pad := Controls.using_pad
	var lines: Array[String] = ["Move: %s    Camera: %s" % ["Left Stick" if pad else "WASD", "Right Stick" if pad else "Mouse"]]
	for action in Controls.REMAPPABLE:
		lines.append("%-30s %s" % [UiKit.title_case(Controls.ACTION_NAMES.get(action, String(action))), Controls.glyph(action, pad)])
	lines.append("")
	lines.append("Climb: push into marked walls.  Ledges: jump to catch, A pulls up, B lets go.")
	lines.append("In the suit: the stick part-way (or crouch) is a strut.  Y beside things: talk, change, travel.")
	return "\n".join(lines)


func _show_pause_help(on: bool) -> void:
	_pause_help.visible = on
	_pause_menu.visible = not on
	_pause_frame.visible = not on
	if on and _pause_kit:
		_pause_kit.visible = false
	if on:
		(_pause_help.find_child("Text", true, false) as Label).text = _help_text()
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
	l.add_theme_constant_override(&"outline_size", 7)
	parent.add_child(l)
	return l


func _build() -> void:
	_world_ui = Control.new()
	_world_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_world_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world_ui.draw.connect(_draw_world)
	add_child(_world_ui)
	_hearts = Node.new()
	_hearts.name = "Dignity"
	_world_ui.add_child(_hearts)
	set_health(5, 5)
	_suit_box = Control.new()   # (shown in the suit; drawn by _draw_suit)
	_suit_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_suit_box.visible = false
	_world_ui.add_child(_suit_box)
	# The labels that hold text: the prompt's (hidden; drawn as a pill), the zone's (drawn on its ribbon); the note's
	# (drawn as a toast); the caption, shown as subtitles.
	_prompt = _label(_world_ui, 1, Color.TRANSPARENT)
	_prompt.visible = false
	_note = _label(_world_ui, 1, Color.TRANSPARENT)
	_note.visible = false
	_zone = _label(_world_ui, 1, Color.TRANSPARENT)
	_zone.visible = false
	_caption = _label(_world_ui, 22, UiKit.CREAM)
	_caption.add_theme_font_override(&"font", UiKit.bold())
	_caption.anchor_left = 0.12
	_caption.anchor_right = 0.88
	_caption.anchor_top = 1.0
	_caption.anchor_bottom = 1.0
	_caption.offset_top = -104
	_caption.offset_bottom = -40
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fps = _label(self, 16, Color(1, 1, 1, 0.7))
	_fps.anchor_left = 1.0
	_fps.anchor_right = 1.0
	_fps.offset_left = -90.0
	_fps.offset_top = 8.0


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
	shade.color = Color(0.04, 0.02, 0.07, 0.86)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(shade)
	# The border, with this world's tallies in its corners (drawn: _draw_pause_frame).
	_pause_frame = Control.new()
	_pause_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_frame.draw.connect(_draw_pause_frame)
	_pause.add_child(_pause_frame)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(center)
	var stack := VBoxContainer.new()
	center.add_child(stack)
	# The middle: the world's name, the area she's in, her rank, then the menu.
	_pause_menu = VBoxContainer.new()
	_pause_menu.add_theme_constant_override(&"separation", 8)
	stack.add_child(_pause_menu)
	_pause_title = Menu.heading(_pause_menu, "Paused", 60)
	_pause_title.name = "WorldTitle"
	_pause_area = Label.new()
	_pause_area.name = "Area"
	_pause_area.add_theme_font_override(&"font", UiKit.display())
	_pause_area.add_theme_font_size_override(&"font_size", 26)
	_pause_area.add_theme_color_override(&"font_color", UiKit.CREAM)
	_pause_area.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_menu.add_child(_pause_area)
	_pause_rank = Label.new()
	_pause_rank.add_theme_font_override(&"font", UiKit.bold())
	_pause_rank.add_theme_font_size_override(&"font_size", 17)
	_pause_rank.add_theme_color_override(&"font_color", UiKit.DIM)
	_pause_rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_menu.add_child(_pause_rank)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	_pause_menu.add_child(gap)
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override(&"separation", 8)
	menu.custom_minimum_size = Vector2(360, 0)
	menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_pause_menu.add_child(menu)
	_resume = Menu.button(menu, "Resume", set_paused.bind(false))
	Menu.button(menu, "Level Totals", show_totals.bind(true)).name = "TotalsButton"
	Menu.button(menu, "Kit", _show_kit.bind(true)).name = "KitButton"
	Menu.button(menu, "Controls", _show_pause_help.bind(true))
	Menu.button(menu, "Settings", func() -> void: open_settings(func() -> void: _resume.grab_focus()))
	Menu.button(menu, "Back to the last wardrobe", _to_last_wardrobe)
	Menu.button(menu, "Return to the club", _to_club)
	Menu.button(menu, "Title screen", _to_title)
	Menu.button(menu, "Quit to desktop", func() -> void: get_tree().quit())
	_pause_help = VBoxContainer.new()
	_pause_help.visible = false
	stack.add_child(_pause_help)
	var hcard := PanelContainer.new()
	hcard.add_theme_stylebox_override(&"panel", UiKit.card(18))
	_pause_help.add_child(hcard)
	var hcol := VBoxContainer.new()
	hcol.add_theme_constant_override(&"separation", 10)
	hcard.add_child(hcol)
	Menu.heading(hcol, "Controls", 40)
	var help := Label.new()
	help.name = "Text"
	var mono := SystemFont.new()   # monospaced, so the columns line up (Consolas on Windows, DejaVu on the Deck)
	mono.font_names = PackedStringArray(["Consolas", "DejaVu Sans Mono", "Liberation Mono", "monospace"])
	help.add_theme_font_override(&"font", mono)
	help.add_theme_font_size_override(&"font_size", 18)
	hcol.add_child(help)
	var back := Menu.button(_pause_help, "Back", _show_pause_help.bind(false))
	back.name = "Back"
	# The Kit: everything she can do (core/kit.gd), filled each time it opens.
	_pause_kit = VBoxContainer.new()
	_pause_kit.visible = false
	stack.add_child(_pause_kit)
	var kcard := PanelContainer.new()
	kcard.add_theme_stylebox_override(&"panel", UiKit.card(18))
	_pause_kit.add_child(kcard)
	var kcol := VBoxContainer.new()
	kcol.add_theme_constant_override(&"separation", 10)
	kcard.add_child(kcol)
	Menu.heading(kcol, "Kit", 40)
	_kit_grid = GridContainer.new()
	_kit_grid.columns = 3
	_kit_grid.add_theme_constant_override(&"h_separation", 10)
	_kit_grid.add_theme_constant_override(&"v_separation", 8)
	kcol.add_child(_kit_grid)
	var kback := Menu.button(_pause_kit, "Back", _show_kit.bind(false))
	kback.name = "Back"
	# Level Totals: a page per world she's been to, then All Worlds (core/level_totals.gd).
	_totals = LevelTotals.new()
	_totals.visible = false
	_totals.closed.connect(show_totals.bind(false))
	stack.add_child(_totals)


## The Level Totals pages, open on the world she's in; the corners' tallies hide while it's up.
func show_totals(on: bool) -> void:
	_totals.visible = on
	_pause_menu.visible = not on
	_pause_frame.visible = not on
	if on:
		_totals.open(_here())
	else:
		(_pause_menu.find_child("TotalsButton", true, false) as Button).grab_focus()


func totals_showing() -> bool:
	return _totals.visible


var _pause_kit: VBoxContainer
var _kit_grid: GridContainer


func _show_kit(on: bool) -> void:
	_pause_kit.visible = on
	_pause_menu.visible = not on
	_pause_frame.visible = not on
	if on:
		_fill_kit()
		(_pause_kit.get_node("Back") as Button).grab_focus()
	else:
		_resume.grab_focus()


func kit_showing() -> bool:
	return _pause_kit.visible


## A card per entry: its icon, its name, its buttons (in the device's own glyphs) and how, where it works, who gave it.
## One she hasn't got is "???".
func _fill_kit() -> void:
	for c in _kit_grid.get_children():
		_kit_grid.remove_child(c)
		c.queue_free()
	var n := _nim()
	for e: Array in Kit.ENTRIES:
		var flag: String = e[1]
		var have: bool = flag == "" or (n != null and bool(n.call(&"knows", flag))) or Game.has_flag(flag)
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(330, 74)
		card.add_theme_stylebox_override(&"panel", UiKit.flat(Color(0.12, 0.06, 0.13, 0.9) if have else Color(0.06, 0.04, 0.07, 0.8),
			Color(UiKit.GOLD_DEEP, 0.6) if have else Color(0.3, 0.25, 0.3, 0.6), 2, 10, Vector4(8, 6, 10, 6)))
		_kit_grid.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 8)
		card.add_child(row)
		var icon := Control.new()
		icon.custom_minimum_size = Vector2(46, 46)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var icon_id: String = e[2]
		icon.draw.connect(func() -> void:
			UiKit.icon(icon, icon_id if have else "bang", Vector2(23, 23), 38.0, UiKit.GOLD if have else Color(UiKit.DIM, 0.4)))
		row.add_child(icon)
		var col := VBoxContainer.new()
		col.add_theme_constant_override(&"separation", 0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		var title := Label.new()
		title.text = e[3] if have else "???"
		title.add_theme_font_override(&"font", UiKit.display())
		title.add_theme_font_size_override(&"font_size", 18)
		title.add_theme_color_override(&"font_color", UiKit.CREAM if have else UiKit.DIM)
		col.add_child(title)
		var how := Label.new()
		var keys: Array = (e[4] as Array).map(func(a: StringName) -> String: return "[%s]" % Controls.glyph(a))
		how.text = ("  ".join(keys) + "  " if not keys.is_empty() else "") + String(e[5]) if have else "Not yet."
		how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		how.custom_minimum_size = Vector2(250, 0)
		how.add_theme_font_size_override(&"font_size", 13)
		how.add_theme_color_override(&"font_color", UiKit.CREAM if have else UiKit.DIM)
		col.add_child(how)
		var meta := Label.new()
		var from: String = e[7]
		meta.text = "%s  ·  %s%s" % [e[0], e[6] if e[6] != "Both" else "Garb & Suit", ("  ·  From " + from) if from != "" and have else ""]
		meta.add_theme_font_size_override(&"font_size", 12)
		meta.add_theme_color_override(&"font_color", UiKit.GOLD if have else Color(UiKit.DIM, 0.6))
		col.add_child(meta)
