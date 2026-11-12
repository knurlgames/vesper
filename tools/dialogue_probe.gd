extends SceneTree
## WO-009's acceptance, with real input on the test course:
##   - **A writer adds a conversation without code:** a new .dialogue file (written here, as a writer would) and a
##     Talker pointed at it. Nim walks up, Y, reads it, picks the second choice with the D-pad; the flags it sets are
##     set; the lint passes it.
##   - The box's guards: A held as a talk opens, and A mashed in its first moments, skip nothing.
##   - Dash: a choice that sets a flag, and a second visit that reads it.
##   - The newsstand's cutscene: the camera moves, the paper's card shows, a line follows, and the level's camera comes
##     back with the world running again.
##   - **The lint** passes the whole game, and catches each kind of problem in samples.
##   godot --headless --fixed-fps 60 --path . -s tools/dialogue_probe.gd

const Driver := preload("res://tools/probe_driver.gd")
const X := 192.0
const NEW_FILE := "user://writer_probe.dialogue"
const NEW_TEXT := "# A writer's new conversation: no code, just this file and a Talker pointed at it.

~ start
Goon [nervous]: You're not supposed to be back here.
Nim: Neither are you.
- I'm with the band. => band
- I'm the inspector. => inspector

~ band
Goon: Oh. Carry on then.
set probe_said_band

~ inspector
Goon [panicked]: I didn't see anything! Nobody saw anything!
set probe_said_inspector
set probe_goon_scared = 2
"

var d: Driver
var course: Node
var game: Node
var dialogue: Node


func _initialize() -> void:
	await process_frame
	game = root.get_node("/root/Game")
	dialogue = root.get_node("/root/Dialogue")
	game.set(&"persist", false)
	game.call(&"reset")
	game.call(&"set_setting", "age_confirmed", true)
	course = load("res://levels/test_course/course.tscn").instantiate()
	root.add_child(course)
	current_scene = course
	await physics_frame
	d = Driver.new(self, course.get(&"nim"), course.get(&"cam"))
	await _writer_adds_one()
	await _guards()
	await _dash()
	await _cutscene()
	_lint()
	print("dialogue probe: %d failures" % d.fails)
	quit(1 if d.fails else 0)


func _current_text() -> String:
	var line: Dictionary = dialogue.get(&"_line")
	return String(line.get("text", ""))


## Waits out the box's opening guard, then taps A until `cond` or the talk ends.
func _a_until(cond: Callable, timeout := 6.0) -> bool:
	var t := 0.0
	await d.secs(0.45)
	while t < timeout:
		if cond.call():
			return true
		if not dialogue.call(&"is_active"):
			return cond.call()
		await d.tap(JOY_BUTTON_A)
		await d.secs(0.3)
		t += 0.35
	return cond.call()


func _writer_adds_one() -> void:
	var f := FileAccess.open(NEW_FILE, FileAccess.WRITE)
	f.store_string(NEW_TEXT)
	f.close()
	var lint := WritingLint.new()
	lint.dialogue(NEW_FILE, NEW_TEXT)
	d.check(lint.problems.is_empty(), "the writer's new file passes the lint %s" % str(lint.problems))
	var t := Talker.new()
	t.file = NEW_FILE
	t.display_name = "Goon"
	t.position = Vector3(X - 2.0, 0.0, 6.0)
	course.add_child(t)
	await d.place(Vector3(X - 2.0, 0.05, 7.5), 0.0)
	await d.tap(JOY_BUTTON_Y)
	await d.frames(3)
	d.check(dialogue.call(&"is_active") and get_first_node_in_group(&"player").get_tree().paused,
		"Y beside the Talker opens the conversation, and the world waits")
	# Read to the choice, then the D-pad picks the second one.
	var at_choice := await _a_until(func() -> bool:
		return not (dialogue.get(&"_line").get("choices", []) as Array).is_empty() and dialogue.get(&"_choices").visible, 8.0)
	d.check(at_choice, "reading on with A reaches the choice")
	await d.tap(JOY_BUTTON_DPAD_DOWN)
	await d.tap(JOY_BUTTON_A)
	await _a_until(func() -> bool: return false, 4.0)
	d.check(not dialogue.call(&"is_active") and not paused, "the talk ends and the world runs again")
	d.check(game.call(&"has_flag", "probe_said_inspector") and not game.call(&"has_flag", "probe_said_band")
		and game.call(&"get_flag", "probe_goon_scared") == 2, "the second choice set its flags (and only its flags)")
	t.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(NEW_FILE))


func _guards() -> void:
	# A held before the talk opens: it waits for A to be let go.
	var dash := course.get_node("Dash_k") as Node3D
	await d.place(dash.global_position + Vector3(0, 0.05, 1.5), 0.0)
	d.button(JOY_BUTTON_A, true)
	await d.frames(2)
	await d.tap(JOY_BUTTON_Y)
	var first := ""
	await d.secs(0.2)
	first = _current_text()
	await d.secs(1.0)   # still held
	var held := _current_text()
	d.button(JOY_BUTTON_A, false)
	d.check(first != "" and held == first, "A held as the talk opens skips nothing")
	# Mashed in the first 0.4 s of a talk: ignored. (Close this one first.)
	await _a_until(func() -> bool: return false, 8.0)
	game.call(&"clear_flag", "dash_met")
	game.call(&"clear_flag", "dash_race_offered")
	await d.place(dash.global_position + Vector3(0, 0.05, 1.5), 0.0)
	await d.tap(JOY_BUTTON_Y)
	await d.frames(2)
	var opening := _current_text()
	for i in 3:
		await d.tap(JOY_BUTTON_A, 0.03)
	d.check(_current_text() == opening and dialogue.call(&"is_active"), "A mashed in its first moments skips nothing")


func _dash() -> void:
	# (Dash's talk is open from the guard test.) Read to the choice and take "Prove it." (the first).
	await _a_until(func() -> bool: return dialogue.get(&"_choices").visible, 8.0)
	await d.tap(JOY_BUTTON_A)
	await _a_until(func() -> bool: return false, 6.0)
	d.check(game.call(&"has_flag", "dash_race_offered") and game.call(&"has_flag", "dash_met"),
		"Dash: taking \"Prove it.\" sets the race")
	var dash := course.get_node("Dash_k") as Node3D
	await d.place(dash.global_position + Vector3(0, 0.05, 1.5), 0.0)
	await d.tap(JOY_BUTTON_Y)
	await d.secs(0.3)
	d.check(_current_text().contains("race is still on"), "and a second visit remembers it: \"%s\"" % _current_text())
	await _a_until(func() -> bool: return false, 6.0)


func _cutscene() -> void:
	var stand := course.get_node("Newsstand_k") as Node3D
	await d.place(stand.global_position + Vector3(0, 0.05, 1.5), 0.0)
	var level_cam := root.get_viewport().get_camera_3d()
	await d.tap(JOY_BUTTON_Y)
	await d.secs(1.6)   # the shot moves the camera over 1.2 s
	var cut_cam := root.get_viewport().get_camera_3d()
	d.check(cut_cam != level_cam and dialogue.call(&"is_active"), "the newsstand's cutscene takes the camera")
	var card: Node = dialogue.get(&"_card")
	d.check(card != null and card.visible, "and shows the paper")
	await d.secs(0.5)
	await d.tap(JOY_BUTTON_A)
	await d.secs(0.1)
	var said := await _a_until(func() -> bool: return _current_text().contains("Inspecting"), 4.0)
	d.check(said, "then Nim's line: \"%s\"" % _current_text())
	await _a_until(func() -> bool: return false, 4.0)
	await d.secs(0.6)
	d.check(root.get_viewport().get_camera_3d() == level_cam and not paused and not dialogue.call(&"is_active"),
		"and the level's camera comes back, the world running")


func _lint() -> void:
	var all := WritingLint.new()
	all.run_all()
	d.check(all.problems.is_empty(), "the lint passes the whole game (%d files, %d lines) %s" % [all.files, all.lines, str(all.problems)])
	var cases := [
		["an unmarked Vesper line", "~ start\nVesper: Hello.\n", 1],
		["a Vesper line marked in its section", "~ start\n# OWNER REVIEW\nVesper: Hello.\n", 0],
		["a whole file marked at the top", "# OWNER REVIEW\n~ a\nSwyne: Decency!\n~ b\nVesper: No.\n", 0],
		["a mark that doesn't reach the next section", "~ a\n# OWNER REVIEW\nVesper: One.\n~ b\nVesper: Two.\n", 1],
		["an unknown speaker", "~ start\nVespr: Typo.\n", 1],
		["a banned word", "~ start\nNim: That's about consent, really.\n", 1],
		["a word that only contains one", "~ start\nNim: Sixteen houses on the Close.\n", 0],
		["a jump to nowhere", "~ start\nNim: Off we go.\n=> nowhere\n", 1],
	]
	for c: Array in cases:
		var l := WritingLint.new()
		l.dialogue("sample.dialogue", c[1])
		d.check(l.problems.size() == c[2], "lint: %s gives %d problem(s) (%d)" % [c[0], c[2], l.problems.size()])
	var code := WritingLint.new()
	code.code("sample.gd", "\tlabel.text = \"Vesper: Hello.\"\n")
	var ok := WritingLint.new()
	ok.code("sample.gd", "\tlabel.text = \"Vesper: Hello.\"   # OWNER REVIEW\n")
	d.check(code.problems.size() == 1 and ok.problems.is_empty(), "lint: Vesper's line in code needs its mark too")
