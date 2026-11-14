extends Talker
## The Backroom's pinboard of Swyne's chain, a card a world, red string between (WO-014b; owner, 2026-11-13: "proceed
## with the Alongside option"). Alongside the gates: the Old Quarter's rank doors still decide what's open; the board
## briefs every world and, for one that's open, takes Nim straight there (Vesper's briefing table, and the fast way
## out of the club). Y at the board opens it.
##
## Each world: open, done, or how many roses its gate wants; its roses so far; who hosts it and what Swyne's doing
## there (data/worlds/<id>.json). A pad-first list (D-pad / stick, A to go, B to close), keys and mouse too.

var _layer: CanvasLayer
var _brief: Label
var _title: Label
var _status: Label


func _ready() -> void:
	greybox = false
	if display_name == "":
		display_name = "The board"
	super()


func talk() -> void:
	if _layer:
		return
	_open()
	while is_instance_valid(_layer):
		await get_tree().process_frame
	talked.emit("board")


func _open() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 9
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(root)
	var col := Menu.panel(root, 900.0)
	Menu.heading(col, "Swyne's chain", 34)
	Menu.text(col, "One card a world, the red string between. The gates in the Old Quarter open them; this takes you there.", 16)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 24)
	col.add_child(row)
	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(360, 0)
	list.add_theme_constant_override(&"separation", 6)
	row.add_child(list)
	var info := VBoxContainer.new()
	info.custom_minimum_size = Vector2(500, 0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	_title = Menu.heading(info, "", 26)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_status = Menu.text(info, "", 18, Menu.GOLD)
	_brief = Menu.text(info, "", 17, Menu.INK)
	var first: Button = null
	for i in Game.RANK_WORLDS.size():
		var w: StringName = Game.RANK_WORLDS[i]
		var b := Menu.button(list, "%d.  %s   %s" % [i + 1, Game.NAMES.get(w, String(w)), _tag(w)], _go.bind(w), 40)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_entered.connect(_show.bind(w, i))
		b.mouse_entered.connect(b.grab_focus)
		if first == null:
			first = b
	Menu.text(col, "%s  go there      %s  close" % [Controls.glyph(&"jump"), Controls.glyph(&"crouch")], 15)
	get_tree().paused = true
	Hud.show_world_ui(false)
	if first:
		first.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if _layer and (event.is_action_pressed(&"crouch") or event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause")):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	if _layer:
		_layer.queue_free()
		_layer = null
	get_tree().paused = false
	Hud.show_world_ui(true)


## A world's state, short, for its row.
func _tag(w: StringName) -> String:
	if Game.has_flag("done/%s" % w):
		return "DONE"
	if Game.world_open(w):
		return "OPEN" if Game.SCENES.has(w) else "AHEAD"
	return "%d roses" % Game.RANK_KEYS[Game.RANK_WORLDS.find(w)]


func _show(w: StringName, i: int) -> void:
	var data := _data(w)
	_title.text = Game.NAMES.get(w, String(w))
	var roses := "Roses %d / %d" % [Game.count(&"key", w), Game.WORLD_TOTALS.key] if w != &"city_hall" else ""
	var state := ""
	if Game.has_flag("done/%s" % w):
		state = "Done. %s" % roses
	elif Game.world_open(w) and Game.SCENES.has(w):
		state = "Open. %s   %s takes you there." % [roses, Controls.glyph(&"jump")]
	elif Game.world_open(w):
		state = "Open, but Vesper hasn't briefed it yet."
	else:
		state = "Its gate opens at %d roses. You have %d." % [Game.RANK_KEYS[i], Game.keys()]
	_status.text = state
	var lines: Array[String] = []
	if data.has("host"):
		lines.append("Your host: %s." % data.host)
	if data.has("link"):
		lines.append("The link in the chain: %s" % data.link)
	if data.has("gear") and Game.has_flag("done/%s" % w):
		lines.append("You came back with: %s." % data.gear)
	_brief.text = "\n\n".join(lines) if not lines.is_empty() else "A card with a question mark, and a lot of red string."


func _go(w: StringName) -> void:
	if not (Game.world_open(w) and Game.SCENES.has(w)):
		Hud.note("Not yet." if not Game.world_open(w) else "Vesper hasn't briefed that one yet.", 2.0)
		return
	_close()
	Game.travel(Game.SCENES[w], "hub")


func _data(w: StringName) -> Dictionary:
	var path := "res://data/worlds/%s.json" % w
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
