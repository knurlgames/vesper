class_name DialogueRunner
extends RefCounted
## Steps through a DialogueScript (ported from Nine Lives): applies flag sets, follows jumps, skips lines whose [if]
## fails, and hands back one line to show at a time. A section that runs out without a jump ends the conversation.

## Anything with get_flag / set_flag / has_flag / clear_flag (Game in the game; a test's own store in tests).
var flags: Object
var dialogue: DialogueScript
var current: Dictionary = {}
var finished: bool = false

var _nodes: Array = []
var _index: int = 0


func _init(s: DialogueScript, flag_store: Object) -> void:
	dialogue = s
	flags = flag_store


func start(label: String = "start") -> Dictionary:
	finished = false
	if not dialogue.has_label(label):
		push_error("Dialogue %s: no label '%s'" % [dialogue.source, label])
		finished = true
		return {}
	_goto(label)
	return next()


## Advances to the next line to show. {} when the conversation is over. The line's `choices` lists only the ones
## whose [if] passes.
func next() -> Dictionary:
	current = {}
	while not finished:
		if _index >= _nodes.size():
			finished = true
			break
		var node: Dictionary = _nodes[_index]
		_index += 1
		if not DialogueCondition.evaluate(node.cond, flags):
			continue
		match node.type:
			"set":
				if node.value == null:
					flags.call(&"clear_flag", StringName(node.flag))
				else:
					flags.call(&"set_flag", StringName(node.flag), node.value)
			"jump":
				if node.goto == DialogueScript.END:
					finished = true
				else:
					_goto(node.goto)
			"line":
				current = node.duplicate()
				current.choices = node.choices.filter(
					func(c: Dictionary) -> bool: return DialogueCondition.evaluate(c.cond, flags))
				return current
	return {}


## Picks choice `i` of the current line, then advances.
func choose(i: int) -> Dictionary:
	var choices: Array = current.get("choices", [])
	if i >= 0 and i < choices.size():
		var goto: String = choices[i].goto
		if goto == DialogueScript.END:
			finished = true
			return {}
		if goto != "":
			_goto(goto)
	return next()


## Runs to the end without showing anything, taking choice `pick` each time. Flags end up as if played.
func run_to_end(pick := 0) -> void:
	var guard := 10000
	if current.is_empty() and not finished:
		next()
	while not finished and guard > 0:
		guard -= 1
		if current.is_empty():
			next()
		elif current.choices.is_empty():
			next()
		else:
			choose(mini(pick, current.choices.size() - 1))


func _goto(label: String) -> void:
	_nodes = dialogue.sections.get(label, [])
	_index = 0
