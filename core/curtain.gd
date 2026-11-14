class_name Curtain
extends Node3D
## A curtained doorway (door audit, 2026-11-14: Madame Pearl's tent had "a curtained door" with no curtain): two
## pleated drapes that gather to the sides as someone comes up and fall closed behind them. Cloth: nothing to collide
## with. The node sits at the doorway's foot, in the middle; the drapes hang along its X, `width` across in all.

@export var width := 1.6
@export var height := 2.6
@export var colour := Color("6a2a8a")
## Nim (or anyone in the "talker" group) this close parts them.
@export var reach := 2.4

const PLEATS := 6
## How far each drape gathers: its width at rest times this.
const GATHERED := 0.22

var _drapes: Array[Node3D] = []
var _open := 0.0


func _ready() -> void:
	var cloth := Look.toon(colour, 0.25)
	var gold := Look.toon(Look.BRASS, 0.7)
	var half := width / 2.0
	for side: float in [-1.0, 1.0]:
		# Pivoted at its outer edge, it runs in to the middle; gathering is a squash toward that edge.
		var pivot := Node3D.new()
		pivot.position = Vector3(side * half, 0, 0)
		add_child(pivot)
		var pleats := []
		var w := half / PLEATS
		for i in PLEATS:
			var x := -side * (w * (i + 0.5))
			pleats.append([Vector3(x, height / 2.0, (0.03 if i % 2 == 0 else -0.03)), Vector3(w * 1.08, height, 0.05)])
		DoorKit.part(pivot, pleats, cloth)
		DoorKit.part(pivot, [[Vector3(-side * half / 2.0, 0.04, 0), Vector3(half, 0.08, 0.1)]], gold)   # a gold hem
		_drapes.append(pivot)
	# The pole and its finials, over the doorway.
	DoorKit.part(self, [[Vector3(0, height + 0.06, 0), Vector3(width + 0.3, 0.06, 0.06)],
		[Vector3(-(width / 2.0 + 0.18), height + 0.06, 0), Vector3(0.12, 0.12, 0.12)],
		[Vector3(width / 2.0 + 0.18, height + 0.06, 0), Vector3(0.12, 0.12, 0.12)]], gold)


func _process(delta: float) -> void:
	var want := 1.0 if _someone_near() else 0.0
	_open = move_toward(_open, want, delta * (2.5 if want > _open else 1.4))
	var s := lerpf(1.0, GATHERED, smoothstep(0.0, 1.0, _open))
	for d in _drapes:
		d.scale.x = s


func is_open() -> bool:
	return _open > 0.9


func _someone_near() -> bool:
	var mid := global_position
	var nim := get_tree().get_first_node_in_group(&"player") as Node3D
	if nim and nim.global_position.distance_to(mid) < reach:
		return true
	for t: Node in get_tree().get_nodes_in_group(&"talker"):
		var n := t as Node3D
		if n and n.global_position.distance_to(mid) < reach * 0.6:
			return true
	return false
