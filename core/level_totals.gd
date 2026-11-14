class_name LevelTotals
extends VBoxContainer
## The pause menu's "Level Totals" (owner, 2026-11-13: "paged results, defaulted to your current world, of each world
## you have been through and a final totals page as the last tab that shows an overview of everything").
##
## A tab per world she's been to (in the order the game opens them), then "All Worlds". Left and right along the tabs
## (or LB / RB, Q / E, from anywhere on the screen) turn the page; B or Back closes it.

signal closed

## What each world tallies, its icon (UiKit.icon) and its name on the page.
const KINDS: Array[StringName] = [&"key", &"contraband", &"freed", &"tin"]
const ICONS := {&"key": "rose", &"contraband": "box", &"freed": "zzz", &"tin": "tin"}
const NAMES := {&"key": "Velvet Roses", &"contraband": "Contraband", &"freed": "Sleepers Woken", &"tin": "Collection Tin"}
const SHORT := {&"key": "Roses", &"contraband": "Contraband", &"freed": "Woken", &"tin": "Tin"}
const PAGE_W := 760.0

var page := 0
var worlds: Array[StringName] = []


## The Game autoload, found at run time: the HUD (an autoload itself) compiles this before Game is named.
## (Untyped, so its constants and methods resolve when called.)
static func _g():
	return (Engine.get_main_loop() as SceneTree).root.get_node(^"/root/Game")
var _tabs: HBoxContainer
var _body: VBoxContainer
var _hint: Label
var back: Button


func _init() -> void:
	add_theme_constant_override(&"separation", 10)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override(&"panel", UiKit.card(18))
	add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 12)
	col.custom_minimum_size = Vector2(PAGE_W, 0)
	card.add_child(col)
	Menu.heading(col, "Level Totals", 40)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override(&"separation", 6)
	_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_tabs)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override(&"separation", 10)
	_body.custom_minimum_size = Vector2(PAGE_W, 330)
	col.add_child(_body)
	_hint = Label.new()
	_hint.add_theme_font_override(&"font", UiKit.bold())
	_hint.add_theme_font_size_override(&"font_size", 16)
	_hint.add_theme_color_override(&"font_color", UiKit.DIM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_hint)
	back = Menu.button(self, "Back", func() -> void: closed.emit())
	back.name = "Back"


## Fills the tabs for where she's been, and opens on `current` (its own page, or All Worlds if it has none).
func open(current: StringName) -> void:
	worlds = been_to(current)
	for c in _tabs.get_children():
		_tabs.remove_child(c)
		c.queue_free()
	var names: Array[String] = []
	for w in worlds:
		names.append(String(_g().NAMES.get(w, w)))
	names.append("All Worlds")
	for i in names.size():
		var b := Button.new()
		b.text = UiKit.title_case(names[i])
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_ALL
		b.add_theme_font_size_override(&"font_size", 17)
		b.custom_minimum_size = Vector2(0, 40)
		b.focus_entered.connect(show_page.bind(i))
		b.pressed.connect(show_page.bind(i))
		_tabs.add_child(b)
	# Down from any tab is Back; up from Back is the tab that's open.
	for b: Button in _tabs.get_children():
		b.focus_neighbor_bottom = back.get_path()
	var at := worlds.find(current)
	show_page(at if at >= 0 else worlds.size())
	_focus_tab()
	# (Controls by path: a class_name script compiles before the autoloads are named.)
	var controls := get_node_or_null(^"/root/Controls")
	var pad: bool = controls != null and bool(controls.get(&"using_pad"))
	_hint.text = "%s  %s  Turn the Page" % (["LB", "RB"] if pad else ["Q", "E"])


func page_count() -> int:
	return worlds.size() + 1


## The world on the page showing, or &"" on All Worlds.
func page_world() -> StringName:
	return worlds[page] if page < worlds.size() else &""


func turn(by: int) -> void:
	show_page(wrapi(page + by, 0, page_count()))
	_focus_tab()


func show_page(i: int) -> void:
	page = clampi(i, 0, page_count() - 1)
	for k in _tabs.get_child_count():
		(_tabs.get_child(k) as Button).set_pressed_no_signal(k == page)
	back.focus_neighbor_top = _tabs.get_child(page).get_path() if page < _tabs.get_child_count() else NodePath()
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	if page < worlds.size():
		_world_page(worlds[page])
	else:
		_all_page()


func _focus_tab() -> void:
	if page < _tabs.get_child_count():
		(_tabs.get_child(page) as Button).grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var by := 0
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			by = -1
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			by = 1
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			by = -1
		elif event.keycode == KEY_E:
			by = 1
	if by != 0:
		turn(by)
		get_viewport().set_input_as_handled()


# --- what's on the pages ---------------------------------------------------------------------------------------------

## The worlds she's been to: a visit, anything collected there, or the one she's in. City Hall only once she's been.
static func been_to(current: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for w: StringName in _g().WORLDS:
		var any := false
		for k in KINDS:
			if _g().count(k, w) > 0:
				any = true
		if w == current or any or _g().has_flag("visited/%s" % w):
			out.append(w)
	# A test level (the course, the probe world) gets a page while she's in it.
	if current != &"" and not current in out:
		out.append(current)
	return out


## "3 / 10", or the tin's state; "" where a world has none of that kind.
static func tally(kind: StringName, w: StringName) -> String:
	if _g().total(kind, w) <= 0:
		return ""
	if kind == &"tin":
		return "Smashed" if _g().count(&"tin", w) > 0 else "Still Standing"
	return "%d / %d" % [_g().count(kind, w), _g().total(kind, w)]


static func complete(kind: StringName, w: StringName) -> bool:
	return _g().total(kind, w) > 0 and _g().count(kind, w) >= _g().total(kind, w)


func _world_page(w: StringName) -> void:
	var head := HBoxContainer.new()
	_body.add_child(head)
	var title := Menu.heading(head, String(_g().NAMES.get(w, w)), 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var state := Label.new()
	state.add_theme_font_override(&"font", UiKit.display())
	state.add_theme_font_size_override(&"font_size", 20)
	var done: bool = _g().has_flag("done/%s" % w)
	state.text = "Cleaned Up" if done else "In Progress"
	state.add_theme_color_override(&"font_color", UiKit.GREEN if done else UiKit.DIM)
	state.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(state)
	for k in KINDS:
		if _g().total(k, w) <= 0:
			continue
		_body.add_child(_row(k, w))


## A row: the icon, the name, a bar filling toward the total, and the count.
func _row(kind: StringName, w: StringName) -> Control:
	var have: int = _g().count(kind, w)
	var all: int = _g().total(kind, w)
	var full := complete(kind, w)
	var row := PanelContainer.new()
	row.add_theme_stylebox_override(&"panel", UiKit.flat(Color(0.12, 0.06, 0.13, 0.9),
		Color(UiKit.GOLD_DEEP, 0.8) if full else Color(0.3, 0.22, 0.3, 0.6), 2, 10, Vector4(10, 6, 14, 6)))
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 12)
	row.add_child(h)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(52, 52)
	icon.draw.connect(func() -> void: UiKit.icon(icon, ICONS[kind], Vector2(26, 26), 42.0, UiKit.GOLD if have > 0 else Color(UiKit.DIM, 0.5)))
	h.add_child(icon)
	var name := Label.new()
	name.text = NAMES[kind]
	name.add_theme_font_override(&"font", UiKit.display())
	name.add_theme_font_size_override(&"font_size", 22)
	name.add_theme_color_override(&"font_color", UiKit.CREAM)
	name.custom_minimum_size = Vector2(200, 0)
	name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(name)
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 52)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var f := clampf(float(have) / maxf(float(all), 1.0), 0.0, 1.0)
	bar.draw.connect(func() -> void:
		var r := Rect2(0, 19, bar.size.x, 14)
		bar.draw_rect(r, Color(0.05, 0.02, 0.06, 0.9))
		if f > 0.0:
			bar.draw_rect(Rect2(r.position, Vector2(r.size.x * f, r.size.y)), UiKit.GOLD if full else UiKit.ROSE)
		bar.draw_rect(r, Color(UiKit.GOLD_DEEP, 0.7), false, 1.5))
	h.add_child(bar)
	var n := Label.new()
	n.text = tally(kind, w)
	n.add_theme_font_override(&"font", UiKit.display())
	n.add_theme_font_size_override(&"font_size", 26)
	n.add_theme_color_override(&"font_color", UiKit.GOLD if full else UiKit.CREAM)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	n.custom_minimum_size = Vector2(170, 0)
	n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(n)
	return row


## Everything at once: a row per world she's been to, then her rank and the running totals.
func _all_page() -> void:
	var title := Menu.heading(_body, "All Worlds", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var grid := GridContainer.new()
	grid.columns = 1 + KINDS.size()
	grid.add_theme_constant_override(&"h_separation", 10)
	grid.add_theme_constant_override(&"v_separation", 6)
	_body.add_child(grid)
	grid.add_child(_cell("", 230))
	for k in KINDS:
		var hd := VBoxContainer.new()
		hd.add_theme_constant_override(&"separation", 0)
		var icon := Control.new()
		icon.custom_minimum_size = Vector2(120, 34)
		icon.draw.connect(func() -> void: UiKit.icon(icon, ICONS[k], Vector2(60, 17), 30.0))
		hd.add_child(icon)
		var l := _cell(SHORT[k], 120, UiKit.GOLD)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hd.add_child(l)
		grid.add_child(hd)
	for w in worlds:
		grid.add_child(_cell(String(_g().NAMES.get(w, w)), 230, UiKit.CREAM, UiKit.bold()))
		for k in KINDS:
			var s := tally(k, w)
			if k == &"tin" and s != "":
				s = "Yes" if _g().count(&"tin", w) > 0 else "No"
			var c := _cell(s if s != "" else "-", 120, UiKit.GOLD if complete(k, w) else (UiKit.CREAM if s != "" else UiKit.DIM))
			c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			grid.add_child(c)
	var sep := HSeparator.new()
	_body.add_child(sep)
	var r: int = _g().rank()
	var lines: Array[String] = []
	var next := "" if r >= _g().RANK_KEYS.size() else "  (Next at %d)" % _g().RANK_KEYS[r]
	lines.append("Velvet Roses: %d    Rank %d%s" % [_g().keys(), r, next])
	var seized: int = _g().count(&"contraband")
	var handed := int(_g().get_flag("rivet/handed", 0))
	lines.append("Contraband Seized: %d%s" % [seized, "" if seized <= handed else "  (%d Still to Hand to Rivet)" % (seized - handed)])
	lines.append("Sleepers Woken: %d    Tins Smashed: %d" % [_g().count(&"freed"), _g().count(&"tin")])
	var finished := 0
	for w: StringName in _g().RANK_WORLDS:
		if _g().has_flag("done/%s" % w):
			finished += 1
	lines.append("Worlds Cleaned Up: %d / %d" % [finished, _g().RANK_WORLDS.size()])
	var sum := Label.new()
	sum.name = "Summary"
	sum.text = "\n".join(lines)
	sum.add_theme_font_override(&"font", UiKit.bold())
	sum.add_theme_font_size_override(&"font_size", 19)
	sum.add_theme_color_override(&"font_color", UiKit.GOLD)
	_body.add_child(sum)


func _cell(s: String, w: float, c := UiKit.CREAM, font: Font = null) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_override(&"font", font if font else UiKit.display())
	l.add_theme_font_size_override(&"font_size", 19)
	l.add_theme_color_override(&"font_color", c)
	l.custom_minimum_size = Vector2(w, 0)
	return l
