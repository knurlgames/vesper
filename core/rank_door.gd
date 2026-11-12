class_name RankDoor
extends StaticBody3D
## A door that opens to her rank in the order (WO-008, DESIGN.md: ranks are counted in Keys, never spent, and each
## opens the next world). With enough Keys it slides open as she comes near; without, it shows what it needs. Its
## front faces -Z.

@export var keys_needed := 1
@export var width := 3.0
@export var height := 3.5

var is_open := false
var _mesh: MeshInstance3D
var _col: CollisionShape3D
var _label: Label3D


func _ready() -> void:
	add_to_group(&"rank_door")
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height, 0.3)
	_col = CollisionShape3D.new()
	_col.shape = shape
	_col.position.y = height / 2.0
	add_child(_col)
	_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = shape.size
	_mesh.mesh = box
	_mesh.position.y = height / 2.0
	_mesh.material_override = Look.toon(Look.VELVET.darkened(0.3), 0.2)
	add_child(_mesh)
	_label = Label3D.new()
	_label.font_size = 64
	_label.pixel_size = 0.006
	_label.outline_size = 10
	_label.outline_modulate = Look.INK
	_label.modulate = Look.BRASS.lightened(0.3)
	_label.position = Vector3(0, height / 2.0, -0.2)
	_label.rotation.y = PI
	_label.double_sided = false
	add_child(_label)


func _physics_process(_delta: float) -> void:
	if is_open:
		return
	var game := get_node_or_null(^"/root/Game")
	var have: int = game.call(&"keys") if game else 0
	_label.text = "%d KEYS\n(you have %d)" % [keys_needed, have]
	if have < keys_needed:
		return
	var nim := get_tree().get_first_node_in_group(&"player") as Node3D
	if nim and nim.global_position.distance_to(global_position) < 5.0:
		open()


func open() -> void:
	is_open = true
	_label.text = ""
	_col.set_deferred(&"disabled", true)
	create_tween().tween_property(_mesh, ^"position:y", -height / 2.0, 0.8)
