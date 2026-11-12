class_name DialogueScript
extends RefCounted
## A parsed .dialogue file: labelled sections of nodes. Built by DialogueParser, played by DialogueRunner. The format
## is in docs/WRITING.md. Ported from Nine Lives.
##
## Node dictionaries:
##   {type: "line", speaker, emotion, text, cond, choices: [{text, goto, cond}], line}
##   {type: "jump", goto, cond, line}            goto "END" ends the conversation
##   {type: "set", flag, value, cond, line}      value null = unset

const END := "END"

var source: String = ""
## label -> Array of node Dictionaries, in file order.
var sections: Dictionary = {}
## "file:line: message" strings. Empty = valid.
var errors: PackedStringArray = []


func has_label(label: String) -> bool:
	return sections.has(label)


func is_valid() -> bool:
	return errors.is_empty()
