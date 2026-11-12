class_name ShortcutDoor
extends StaticBody3D
## A shortcut (WO-008, Banjo's lesson): a door, hatch or ladder that only opens from its far side, so it's found on
## the way out and saves the walk back. Y beside it, on its back side (+Z), opens it for good (Game flag
## "shortcut/<world>/<id>"). From the front it's locked. Its front faces -Z.

@export var id: StringName = &""
@export var width := 1.6
@export var height := 2.6

var is_open := false
var world: StringName = &"test"
var _mesh: MeshInstance3D
var _col: CollisionShape3D


func _ready() -> void:
	add_to_group(&"shortcut")
	var n := get_parent()
	while n and not n.has_method(&"spawn_player"):
		n = n.get_parent()
	if n:
		world = n.get(&"world_id")
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height, 0.2)
	_col = CollisionShape3D.new()
	_col.shape = shape
	_col.position.y = height / 2.0
	add_child(_col)
	_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = shape.size
	_mesh.mesh = box
	_mesh.position.y = height / 2.0
	_mesh.material_override = Look.toon(Color("4a3a2a"))
	add_child(_mesh)
	var bolt := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.5, 0.1, 0.1)
	bolt.mesh = b
	bolt.position = Vector3(0, height * 0.5, 0.15)   # the bolt's on the back
	bolt.material_override = Look.toon(Look.BRASS, 0.6)
	_mesh.add_child(bolt)
	var game := get_node_or_null(^"/root/Game")
	if game and game.call(&"has_flag", flag()):
		_open_now(false)


func flag() -> String:
	return "shortcut/%s/%s" % [world, id]


## Y beside it: from behind it opens (true); from the front it's bolted (false).
func try_open(from: Vector3) -> bool:
	if is_open:
		return true
	if (from - global_position).dot(global_basis.z) <= 0.0:
		return false
	_open_now(true)
	var game := get_node_or_null(^"/root/Game")
	if game:
		game.call(&"set_flag", flag())
	return true


func _open_now(animate: bool) -> void:
	is_open = true
	_col.set_deferred(&"disabled", true)
	if animate:
		create_tween().tween_property(_mesh, ^"rotation:y", -PI / 2.0, 0.5)
	else:
		_mesh.rotation.y = -PI / 2.0
