@tool
class_name Beam
extends StaticBody3D
## Something Nim walks with her tail out: a beam, a rail, a wire. Standing on one puts her in balance (slow, along its
## line, held on it); falling near one pulls her onto it. Its line runs along its local X, centred on its origin; the
## origin is at the top surface's centre, so she stands at the origin's height.

## Length along local X.
@export var length := 6.0:
	set(v):
		length = v
		_build()
## Width across. A wire is a few centimetres.
@export var width := 0.2:
	set(v):
		width = v
		_build()
## Round (a wire or rail) or square (a beam).
@export var wire := false:
	set(v):
		wire = v
		_build()
@export var material: Material:
	set(v):
		material = v
		_build()

var _mesh: MeshInstance3D
var _col: CollisionShape3D


func _ready() -> void:
	add_to_group(&"beam")
	_build()


## The beam's line in world space.
func axis() -> Vector3:
	return global_basis.x.normalized()


## The closest point on the beam's top line to `p` (clamped to its ends), and whether p is between the ends.
func closest(p: Vector3) -> Vector3:
	var a := axis()
	var along := clampf((p - global_position).dot(a), -length / 2.0, length / 2.0)
	return global_position + a * along


func spans(p: Vector3) -> bool:
	return absf((p - global_position).dot(axis())) <= length / 2.0


func _build() -> void:
	if not is_inside_tree():
		return
	if _mesh == null:
		_mesh = MeshInstance3D.new()
		add_child(_mesh)
		_col = CollisionShape3D.new()
		add_child(_col)
	var thick := maxf(width, 0.05)
	if wire:
		var cyl := CylinderMesh.new()
		cyl.top_radius = width / 2.0
		cyl.bottom_radius = width / 2.0
		cyl.height = length
		cyl.radial_segments = 10
		_mesh.mesh = cyl
		_mesh.rotation = Vector3(0, 0, PI / 2.0)
	else:
		var box := BoxMesh.new()
		box.size = Vector3(length, thick, width)
		_mesh.mesh = box
		_mesh.rotation = Vector3.ZERO
	_mesh.position = Vector3(0, -thick / 2.0, 0)
	_mesh.material_override = material
	# Collision is a box either way: a round top would roll her off.
	var shape := BoxShape3D.new()
	shape.size = Vector3(length, thick, width)
	_col.shape = shape
	_col.position = Vector3(0, -thick / 2.0, 0)
