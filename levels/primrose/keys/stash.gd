extends "res://levels/primrose/keys/primrose_key.gd"
## Key 5: the allotment stash (worlds/02_PRIMROSE_CLOSE.md). The toys are under the prize marrows. In her garb: lift
## the marrows (Y at the show bed), and get out of the Allotments without being seen. Seen (a bulldog after her, or the
## Watch ringing round) and the job's blown: lie low, and lift them again. Out unseen: the Key, and the marrows win
## first prize at the show anyway.

const SHOW := Vector3(-60.0, 0.0, -112.0)
## The Allotments: x -48..-96, z 6..-121 (the hedge at -48, Allotment Lane in at z 2..6).
const AREA := Rect2(-96.0, -121.0, 48.0, 125.0)
const GOONS: Array[StringName] = [&"a_rounds", &"a_marrows"]

var marrows: Talker
var _carrying := false


func _setup() -> void:
	marrows = talker("Marrows", "stash", "marrows", SHOW + Vector3(0, 0, 2.6), PI, "", "garb", "Prize marrows", Color.WHITE, false)
	marrows.reach = 2.4
	marrows.talked.connect(_on_marrows)
	if has_key(&"primrose_05"):
		marrows.label = "after"


func _on_marrows(_which: String) -> void:
	if flag("stash_lifted") and not has_key(&"primrose_05"):
		_carrying = true


func _physics_process(_delta: float) -> void:
	if not _carrying or Dialogue.is_active():
		return
	var n := nim()
	if n == null:
		return
	if _seen():
		_carrying = false
		clear("stash_lifted")
		Hud.caption("Goon", "Oi! Who's been at the marrows?")
		Hud.note("Seen. Lie low, and lift them again.")
		return
	var p := n.global_position
	if not AREA.has_point(Vector2(p.x, p.z)):
		_carrying = false
		set_flag("stash_out")
		marrows.label = "after"
		Hud.caption("", "The marrows win first prize at the show anyway.", 3.5)
		award(&"primrose_05", Vector3(p.x, maxf(p.y, 0.0), p.z) + n.facing() * 1.2)


## A bulldog in the Allotments after her, or a meerkat raising the alarm.
func _seen() -> bool:
	for id: StringName in GOONS:
		var g := goon(id)
		if g and not g.is_bound() and g.hunting():
			return true
	for w: Node in get_tree().get_nodes_in_group(&"lookout"):
		var l := w as Node3D
		if l and l.get(&"alarmed") == true and AREA.grow(10.0).has_point(Vector2(l.global_position.x, l.global_position.z)):
			return true
	return false
