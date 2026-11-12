class_name DialogueParser
extends RefCounted
## Parses the .dialogue format (docs/WRITING.md; ported from Nine Lives):
##
##   # comment                        (# OWNER REVIEW marks lines for the owner: see the lint)
##   ~ start                          section label (lines before any label are "start")
##   Vesper [warm]: You took your time.   speaker, optional [emotion], text with inline tags
##   [narrator] The tide came in.     narrator line
##   - Lie => lie                     a choice for the line above (=> label optional)
##   - [if has_crop] Crop it => crop
##   [if met_dash] Dash: You again!   any line, jump or set can be conditional
##   set met_dash                     set a flag (true)
##   set tips = 3                     set a flag to a value
##   unset met_dash
##   => label   /   => END            jump

const SPEAKER_RE := "^([A-Za-z][A-Za-z0-9 '._-]*?)\\s*(?:\\[([A-Za-z_]+)\\])?\\s*:\\s*(.*)$"

static var _speaker_re: RegEx


static func parse_file(path: String) -> DialogueScript:
	if not FileAccess.file_exists(path):
		var s := DialogueScript.new()
		s.source = path
		s.errors.append("%s: file not found" % path)
		return s
	return parse(FileAccess.get_file_as_string(path), path)


static func parse(text: String, source: String = "") -> DialogueScript:
	if _speaker_re == null:
		_speaker_re = RegEx.create_from_string(SPEAKER_RE)
	var out := DialogueScript.new()
	out.source = source
	var label := "start"
	var nodes: Array = []
	out.sections[label] = nodes
	var last_line: Dictionary = {}
	var lines := text.split("\n")
	for i in lines.size():
		var n := i + 1
		var line := lines[i].strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		var err := func(msg: String) -> void:
			out.errors.append("%s:%d: %s" % [source, n, msg])
		if line.begins_with("~"):
			label = line.substr(1).strip_edges()
			if label == "" or label == DialogueScript.END:
				err.call("bad label")
				continue
			if out.sections.has(label) and not out.sections[label].is_empty():
				err.call("duplicate label '%s'" % label)
			nodes = out.sections.get(label, [])
			out.sections[label] = nodes
			last_line = {}
			continue
		if line.begins_with("- "):
			if last_line.is_empty():
				err.call("choice without a line before it")
				continue
			var body := line.substr(2).strip_edges()
			var cond := ""
			if body.begins_with("[if "):
				var c := _split_condition(body)
				cond = c[0]
				body = c[1]
			var goto := ""
			var arrow := body.rfind("=>")
			if arrow >= 0:
				goto = body.substr(arrow + 2).strip_edges()
				body = body.substr(0, arrow).strip_edges()
			last_line.choices.append({"text": body, "goto": goto, "cond": cond, "line": n})
			continue
		var cond := ""
		if line.begins_with("[if "):
			var c := _split_condition(line)
			if c[0] == "":
				err.call("unclosed [if ...]")
				continue
			cond = c[0]
			line = c[1]
		if line.begins_with("=>"):
			nodes.append({"type": "jump", "goto": line.substr(2).strip_edges(), "cond": cond, "line": n})
			last_line = {}
		elif line.begins_with("set ") or line.begins_with("unset "):
			var unset := line.begins_with("unset ")
			var body := line.substr(6 if unset else 4).strip_edges()
			var value: Variant = true
			if unset:
				value = null
			elif "=" in body:
				var kv := body.split("=", true, 1)
				body = kv[0].strip_edges()
				value = literal(kv[1].strip_edges())
			if not DialogueCondition._flag_name_ok(body):
				err.call("bad flag name '%s'" % body)
				continue
			nodes.append({"type": "set", "flag": body, "value": value, "cond": cond, "line": n})
			last_line = {}
		elif line.begins_with("[narrator]"):
			last_line = _line_node("Narrator", "", line.substr(10).strip_edges(), cond, n)
			nodes.append(last_line)
		else:
			var m := _speaker_re.search(line)
			if m == null:
				err.call("can't read this line (expected 'Speaker: text')")
				continue
			last_line = _line_node(m.get_string(1).strip_edges(), m.get_string(2), m.get_string(3), cond, n)
			nodes.append(last_line)
	_validate(out)
	return out


static func _line_node(speaker: String, emotion: String, text: String, cond: String, n: int) -> Dictionary:
	return {"type": "line", "speaker": speaker, "emotion": emotion if emotion != "" else "neutral",
		"text": text, "cond": cond, "choices": [], "line": n}


## "[if cond] rest" -> [cond, rest]; ["", text] if malformed.
static func _split_condition(text: String) -> Array:
	var close := text.find("]")
	if close < 0:
		return ["", text]
	return [text.substr(4, close - 4).strip_edges(), text.substr(close + 1).strip_edges()]


static func literal(s: String) -> Variant:
	if s == "true":
		return true
	if s == "false":
		return false
	if s.is_valid_int():
		return s.to_int()
	if s.is_valid_float():
		return s.to_float()
	return s.trim_prefix("\"").trim_suffix("\"")


static func _validate(ds: DialogueScript) -> void:
	for label in ds.sections:
		for node: Dictionary in ds.sections[label]:
			var targets: Array = []
			if node.type == "jump":
				targets.append(node.goto)
			elif node.type == "line":
				for c: Dictionary in node.choices:
					if c.goto != "":
						targets.append(c.goto)
			for t: String in targets:
				if t != DialogueScript.END and not ds.sections.has(t):
					ds.errors.append("%s:%d: no label '%s'" % [ds.source, node.line, t])
			if node.cond != "":
				var e := DialogueCondition.check_syntax(node.cond)
				if e != "":
					ds.errors.append("%s:%d: %s" % [ds.source, node.line, e])
