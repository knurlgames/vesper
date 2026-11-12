class_name Checkpoint
extends Area3D
## A checkpoint (WO-004: generous, no lives): walking past it makes it where Nim comes back after she's downed. A lamp
## post with a velvet ribbon that brightens when it's hers.

## The way she faces when she comes back here.
@export var yaw := 0.0

var _flag: MeshInstance3D
var _lit := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1   # Nim's layer; she's picked out by class below
	monitoring = true
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.0, 3.0, 3.0)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = 1.5
	add_child(col)
	var post := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.08
	cyl.height = 2.2
	post.mesh = cyl
	post.position = Vector3(1.6, 1.1, 0)
	post.material_override = Look.toon(Look.INK)
	add_child(post)
	_flag = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.05, 0.5, 0.35)
	_flag.mesh = box
	_flag.position = Vector3(1.6, 1.9, 0.2)
	_flag.material_override = Look.toon(Look.VELVET.darkened(0.5))
	add_child(_flag)


func _physics_process(_delta: float) -> void:
	for b in get_overlapping_bodies():
		if b is Nim:
			_reach(b)


func _reach(_nim: Nim) -> void:
	var level := get_parent()
	while level and not level.has_method(&"checkpoint"):
		level = level.get_parent()
	if level:
		level.call(&"checkpoint", global_position, yaw, self)


## Lit when it's the current one.
func set_lit(on: bool) -> void:
	if on == _lit:
		return
	_lit = on
	_flag.material_override = Look.toon(Look.VELVET if on else Look.VELVET.darkened(0.5), 0.3 if on else 0.0)
