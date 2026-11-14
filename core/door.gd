class_name Door
extends StaticBody3D
## A locked door (WO-006): staff told to Open it walk up and open it. Its front, where they stand to open it, faces -Z.
##
## It swings on its hinges (DoorKit; owner, 2026-11-14: "doors actually open"; it used to slide up into the air): a
## wide one (a van's back, a cupboard) is a pair; a narrow one (the Watch hut) or a hatch (the postbox) is one leaf.
## They all swing out toward whoever opened it (in, they'd swing into the solid thing they're set on), and behind them
## is a dark inside.

@export var width := 1.6
@export var height := 2.6
@export var colour := Color("3a2420")

const SWING := deg_to_rad(100.0)

var is_open := false
var _col: CollisionShape3D
var _leaves: Array[Node3D] = []
var _angles: Array[float] = []


func _ready() -> void:
	add_to_group(&"door")
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height, 0.2)
	_col = CollisionShape3D.new()
	_col.shape = shape
	_col.position.y = height / 2.0
	add_child(_col)
	# A dark inside behind the leaves (door audit, 2026-11-14: opened, the hut's and the van's doors showed the solid
	# wall they're set on, a door painted on it): a shallow black recess, in the frame.
	DoorKit.part(self, [[Vector3(0, height / 2.0, 0.09), Vector3(width - 0.02, height - 0.02, 0.02)]],
		Look.toon(Color("0c0a10")))
	var thick := clampf(width * 0.05, 0.04, 0.08)
	if width >= 1.4:
		# A pair, out toward the front: the left (hinged at -X, running +X) turns +, the right -.
		for side: float in [-1.0, 1.0]:
			_leaves.append(DoorKit.panelled(self, Vector3(side * width / 2.0, 0, 0), width / 2.0, height, -side, colour, thick))
			_angles.append(-side * SWING)
	else:
		_leaves.append(DoorKit.panelled(self, Vector3(-width / 2.0, 0, 0), width, height, 1.0, colour, thick))
		_angles.append(SWING)


## Where someone stands to open it.
func front() -> Vector3:
	return global_position - global_basis.z * 0.8


func open() -> void:
	if is_open:
		return
	is_open = true
	_col.set_deferred(&"disabled", true)
	for i in _leaves.size():
		DoorKit.swing(_leaves[i], _angles[i], 0.7)
