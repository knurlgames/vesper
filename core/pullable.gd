class_name Pullable
extends StaticBody3D
## Something the rope can pull down (WO-007): a crate on a ledge, a sign on a bracket, a loose plank. RB on the ground,
## facing it, in reach: it topples off its perch to the ground and stays there (a step, a bridge, a noise). Greybox: a
## crate with a ring on it.

@export var size := Vector3(1.2, 1.2, 1.2)
## How far it drops when pulled (to the ground below its perch).
@export var drop := 3.0

var pulled := false
var _mesh: MeshInstance3D


func _ready() -> void:
	add_to_group(&"pullable")
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = size.y / 2.0
	add_child(col)
	_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	_mesh.mesh = box
	_mesh.position.y = size.y / 2.0
	_mesh.material_override = Look.painted(Look.Pattern.PLANKS, Color("7a5a3a"), Color("2a1a10"), {"wet": 0.0})
	add_child(_mesh)
	var ring := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.08
	t.outer_radius = 0.12
	ring.mesh = t
	ring.rotation.x = PI / 2.0
	ring.position = Vector3(0, size.y * 0.6, size.z / 2.0 + 0.03)
	ring.material_override = Look.toon(Look.BRASS, 0.7)
	add_child(ring)


## The rope's tug, from `from`: it topples toward her and drops.
func pull(from: Vector3) -> void:
	if pulled:
		return
	pulled = true
	var toward := from - global_position
	toward.y = 0.0
	toward = toward.normalized() if toward.length() > 0.01 else Vector3.BACK
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, ^"global_position", global_position + toward * (size.z + 0.4) + Vector3.DOWN * drop, 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, ^"rotation:x", rotation.x + 0.4, 0.5)
