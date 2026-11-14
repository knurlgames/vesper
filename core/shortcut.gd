class_name ShortcutDoor
extends StaticBody3D
## A shortcut (WO-008, Banjo's lesson): a door, hatch or ladder that only opens from its far side, so it's found on
## the way out and saves the walk back. Y beside it, on its back side (+Z), opens it for good (Game flag
## "shortcut/<world>/<id>"). From the front it's locked. Its front faces -Z.

@export var id: StringName = &""
@export var width := 1.6
@export var height := 2.6
@export var colour := Color("4a3a2a")

var is_open := false
var world: StringName = &"test"
var _leaf: Node3D
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
	# A leaf on its hinge (DoorKit; it used to spin on its middle, half of it through the wall either side), its bolt
	# on the back.
	_leaf = DoorKit.panelled(self, Vector3(-width / 2.0, 0, 0), width, height, 1.0, colour, 0.07)
	DoorKit.part(_leaf, [[Vector3(width - 0.35, height * 0.5, 0.07), Vector3(0.5, 0.08, 0.06)]], Look.toon(Look.BRASS, 0.6))
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
	# Away from whoever unbolted it (they're behind it, +Z): it swings to the front.
	DoorKit.swing(_leaf, deg_to_rad(100.0), 0.6 if animate else 0.0)
