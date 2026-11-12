class_name WritingLint
extends RefCounted
## The writing lint's rules (WO-009); tools/dialogue_lint.gd runs them over the whole game, and probes run them on
## samples. A problem is:
##   - a .dialogue file that doesn't parse (bad labels, jumps to nowhere, bad conditions);
##   - a speaker who isn't in data/dialogue/speakers.json (a typo'd name);
##   - **a line by Vesper or Swyne that isn't marked for the owner**: a "# OWNER REVIEW" comment before it in its
##     section, or one before the file's first label (which covers the whole file);
##   - a cutscene that doesn't parse, says a conversation that isn't there, or shows a card without "owner_review": true;
##   - **a banned word** (data/writing/banned_words.json, whole words, any case) anywhere in the writing: dialogue,
##     cutscenes, world data, and string literals in code;
##   - a string in code that gives Vesper or Swyne a line ("Vesper:" ...) without OWNER REVIEW on it or the line before.

const DIALOGUE_DIR := "res://data/dialogue"
const CUTSCENE_DIR := "res://data/cutscenes"
const WORLD_DIR := "res://data/worlds"
const CODE_DIRS := ["res://core", "res://player", "res://levels"]
const REVIEWED := ["Vesper", "Swyne"]
const MARK := "OWNER REVIEW"

var problems: Array[String] = []
var files := 0
var lines := 0
var _banned: Array[RegEx] = []
var _speakers := {}
var _string_re := RegEx.create_from_string("\"((?:[^\"\\\\]|\\\\.)*)\"")


func _init() -> void:
	var words: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/writing/banned_words.json"))
	for w: String in (words as Dictionary).get("words", []):
		_banned.append(RegEx.create_from_string("(?i)\\b%s\\b" % w.replace(" ", "\\s+")))
	var sp: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIALOGUE_DIR + "/speakers.json"))
	_speakers = sp if sp is Dictionary else {}


## Everything in the game.
func run_all() -> void:
	for path in walk(DIALOGUE_DIR, ".dialogue"):
		dialogue(path, FileAccess.get_file_as_string(path))
	for path in walk(CUTSCENE_DIR, ".json"):
		cutscene(path, FileAccess.get_file_as_string(path))
	for path in walk(WORLD_DIR, ".json"):
		banned_in(path, FileAccess.get_file_as_string(path))
	for dir: String in CODE_DIRS:
		for path in walk(dir, ".gd"):
			code(path, FileAccess.get_file_as_string(path))


static func walk(dir: String, ext: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(ext):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		if not sub.begins_with("."):
			out.append_array(walk(dir.path_join(sub), ext))
	return out


func dialogue(path: String, text: String) -> void:
	files += 1
	var ds := DialogueParser.parse(text, path)
	for e in ds.errors:
		problems.append(e)
	var file_marked := false
	var section_marked := false
	var seen_label := false
	var n := 0
	for raw in text.split("\n"):
		n += 1
		var line := raw.strip_edges()
		if line.begins_with("#"):
			if MARK in line:
				if seen_label:
					section_marked = true
				else:
					file_marked = true
			continue
		if line.begins_with("~"):
			seen_label = true
			section_marked = false
			continue
		if line == "":
			continue
		lines += 1
		var body := line
		if body.begins_with("[if "):
			body = body.substr(body.find("]") + 1).strip_edges()
		var is_line := not (body.begins_with("-") or body.begins_with("set ") or body.begins_with("unset ")
			or body.begins_with("=>") or body.begins_with("[narrator]"))
		if is_line and ":" in body:
			var who := body.split(":", true, 1)[0].split("[", true, 1)[0].strip_edges()
			if who in REVIEWED and not (file_marked or section_marked):
				problems.append("%s:%d: %s's line isn't marked # %s" % [path, n, who, MARK])
			if not _speakers.has(who):
				problems.append("%s:%d: unknown speaker '%s' (add them to speakers.json)" % [path, n, who])
		banned_line(path, n, line)


func cutscene(path: String, text: String) -> void:
	files += 1
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary or not (data as Dictionary).has("steps"):
		problems.append("%s: not a cutscene (no \"steps\")" % path)
		return
	var i := 0
	for step: Dictionary in data["steps"]:
		i += 1
		if step.has("say"):
			var f := String(step["say"].get("file", ""))
			var label := String(step["say"].get("label", "start"))
			var ds := DialogueParser.parse_file(f)
			if not ds.is_valid() or not ds.has_label(label):
				problems.append("%s: step %d says %s:%s, which isn't there" % [path, i, f, label])
		if step.has("card") and step["card"].get("owner_review") != true:
			problems.append("%s: step %d's card isn't marked \"owner_review\": true" % [path, i])
	banned_in(path, text)


func code(path: String, text: String) -> void:
	var all := text.split("\n")
	for i in all.size():
		var line := all[i]
		if line.strip_edges().begins_with("#"):
			continue
		for m in _string_re.search_all(line):
			var s := m.get_string(1)
			banned_line(path, i + 1, s)
			for who: String in REVIEWED:
				var t := s.strip_edges()
				if t.begins_with(who + ":") or t.begins_with(who + " ["):
					var prev := all[i - 1] if i > 0 else ""
					if not (MARK in line or MARK in prev):
						problems.append("%s:%d: %s's line in code isn't marked # %s" % [path, i + 1, who, MARK])


func banned_in(path: String, text: String) -> void:
	var n := 0
	for line in text.split("\n"):
		n += 1
		banned_line(path, n, line)


func banned_line(path: String, n: int, text: String) -> void:
	for re in _banned:
		var m := re.search(text)
		if m:
			problems.append("%s:%d: banned word '%s'" % [path, n, m.get_string()])
