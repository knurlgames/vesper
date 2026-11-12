class_name Door
extends StaticBody3D
## A locked door (WO-006): staff told to Open it walk up and open it (it slides up out of the way). Its front, where
## they stand to open it, faces -Z.

@export var width := 1.6
@export var height := 2.6

var is_open := false
var _mesh: MeshInstance3D
var _col: CollisionShape3D


func _ready() -> void:
	add_to_group(&"door")
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height, 0.2)
	_col = CollisionShape3D.new()
	_col.shape = shape
	_col.position.y = height / 2.0
	add_child(_col)
	_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, height, 0.2)
	_mesh.mesh = box
	_mesh.position.y = height / 2.0
	_mesh.material_override = Look.toon(Color("3a2420"))
	add_child(_mesh)


## Where someone stands to open it.
func front() -> Vector3:
	return global_position - global_basis.z * 0.8


func open() -> void:
	if is_open:
		return
	is_open = true
	_col.set_deferred(&"disabled", true)
	var tw := create_tween()
	tw.tween_property(_mesh, ^"position:y", height * 1.5, 0.6)
