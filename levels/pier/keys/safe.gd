extends "res://levels/pier/keys/pier_key.gd"
## Key 6: the back office safe (worlds/01_PIER.md). In through the roof vent (garb). The safe isn't even locked; inside
## is Laffer's Decency League membership card. Opening it, she's heard: a goon outside counts to ten. Out of the office
## before ten and the Key is hers; still inside at ten and they come in (the goons are alerted), and she can try again.

## Seconds the count takes.
@export var count_secs := 10.0

const SAFE := Vector3(16.6, 0.0, -149.0)
## The office, inside its walls.
const OFFICE := AABB(Vector3(6.2, -0.5, -151.5), Vector3(11.3, 8.5, 13.3))
const WORDS := ["One...", "Two...", "Three...", "Four...", "Five...", "Six...", "Seven...", "Eight...", "Nine...",
	"TEN! Ready or not!"]

var safe: Talker
var counting := false
var _t := 0.0
var _said := 0


func _setup() -> void:
	safe = talker("Safe", "safe", "open", SAFE, 0.0, "", "garb", "Safe", Color.WHITE, false)
	safe.talked.connect(_on_talked)


func _on_talked(_which: String) -> void:
	if not has_key(&"pier_06") and not counting:
		counting = true
		_t = 0.0
		_said = 0


func _physics_process(delta: float) -> void:
	if not counting or Dialogue.is_active():
		return
	_t += delta
	var n := nim()
	if not OFFICE.has_point(n.global_position):
		counting = false
		Hud.caption("Goon", "...TEN! Coming in! ...Huh. Nobody. Must be the wind.")
		var p := n.global_position
		award(&"pier_06", Vector3(p.x, maxf(p.y, 0.0), p.z))
		return
	var due := int(_t / count_secs * WORDS.size())
	if due > _said:
		_said = due
		Hud.caption("Goon", WORDS[mini(due, WORDS.size()) - 1], 1.2)
	if _t >= count_secs:
		counting = false
		for id: StringName in [&"p_office", &"p_rounds"]:
			var g := goon(id)
			if g and not g.is_bound():
				g.alert(n.global_position)
