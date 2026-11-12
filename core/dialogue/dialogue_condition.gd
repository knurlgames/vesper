class_name DialogueCondition
extends RefCounted
## The tiny condition language for [if ...] on Game flags (ported from Nine Lives):
##   flag            truthy
##   not flag / !flag
##   flag == 3   flag != "x"   tips >= 5   (==, !=, >=, <=, >, <)
##   a and b   a or b   (and binds tighter; no parentheses)
## `flags` is anything with get_flag / has_flag (Game, or a test's own store).

const OPS := ["==", "!=", ">=", "<=", ">", "<"]


static func evaluate(cond: String, flags: Object) -> bool:
	if cond.strip_edges() == "":
		return true
	for any_part in cond.split(" or "):
		var all_true := true
		for part in any_part.split(" and "):
			if not _term(part.strip_edges(), flags):
				all_true = false
				break
		if all_true:
			return true
	return false


## "" if `cond` is well-formed, else an error message.
static func check_syntax(cond: String) -> String:
	for any_part in cond.split(" or "):
		for part in any_part.split(" and "):
			var t := part.strip_edges()
			if t.begins_with("not "):
				t = t.substr(4).strip_edges()
			t = t.trim_prefix("!")
			var flag_name := t
			for op in OPS:
				if op in t:
					flag_name = t.split(op, true, 1)[0].strip_edges()
					break
			if not _flag_name_ok(flag_name):
				return "bad condition '%s'" % cond
	return ""


## Flag names are identifiers, with "/" allowed for the namespaced ones Game keeps ("bound/pier/g1").
static func _flag_name_ok(n: String) -> bool:
	return n != "" and n.replace("/", "_").is_valid_ascii_identifier()


static func _term(t: String, store: Object) -> bool:
	if t.begins_with("not "):
		return not _term(t.substr(4).strip_edges(), store)
	if t.begins_with("!"):
		return not _term(t.substr(1).strip_edges(), store)
	for op: String in OPS:
		if op in t:
			var kv := t.split(op, true, 1)
			var a: Variant = store.call(&"get_flag", StringName(kv[0].strip_edges()))
			var b: Variant = DialogueParser.literal(kv[1].strip_edges())
			return _compare(a, b, op)
	return store.call(&"has_flag", StringName(t))


static func _compare(a: Variant, b: Variant, op: String) -> bool:
	if a == null:
		a = 0 if (b is int or b is float) else ""
	if (a is int or a is float) != (b is int or b is float):
		return op == "!="
	match op:
		"==":
			return a == b
		"!=":
			return a != b
		">=":
			return a >= b
		"<=":
			return a <= b
		">":
			return a > b
		"<":
			return a < b
	return false
