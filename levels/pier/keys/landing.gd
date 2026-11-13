extends "res://levels/pier/keys/pier_key.gd"
## Key 2: the smugglers' landing (worlds/01_PIER.md). Three of the crew work the landing; take them one by one (from
## the beams above, ideally). The fourth has been bound already, by himself, practising (his flag is set by the level
## before he's placed). With the other three tied, he has a word, and the Key is by him.

const CREW: Array[StringName] = [&"u_crew1", &"u_crew2", &"u_crew3"]
const KEEN := &"u_crew4"

var _done := false


func _setup() -> void:
	_done = has_key(&"pier_02")


func _physics_process(_delta: float) -> void:
	if _done or Dialogue.is_active():
		return
	var all := CREW.all(func(id: StringName) -> bool:
		var g := goon(id)
		return g != null and g.is_bound())
	if all:
		_done = true
		_payoff()


func _payoff() -> void:
	await talk("landing", "practised")
	var g := goon(KEEN)
	var at := g.global_position + Vector3(-1.2, 0.0, 0.0) if g else Vector3(10.0, -6.0, -108.0)
	award(&"pier_02", at)
