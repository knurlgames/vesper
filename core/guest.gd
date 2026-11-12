class_name Guest
extends StaticBody3D
## A guest at one of Swyne's parties (WO-006): they stand in knots, chatting. Strutting among two or more of them, Nim
## in her suit is one of the crowd (NimSuit.hidden_in_crowd). They're watchers too: what she does in front of them
## costs Composure. Greybox: a capsule in party colours, turned toward the knot.

## Where they're looking (yaw: 0 looks down -Z). Set it toward the knot's middle.
@export var look_yaw := 0.0
@export var colour := Color("b08a6a")

const SIGHT_RANGE := 10.0
const SIGHT_HALF_ANGLE := deg_to_rad(70.0)
const RADIUS := 0.33
const HEIGHT := 1.7

var sees_her := false
var _nim: Node3D
var _model: Node3D


func _ready() -> void:
	add_to_group(&"guest")
	add_to_group(&"watcher")
	rotation.y = look_yaw
	var shape := CapsuleShape3D.new()
	shape.radius = RADIUS
	shape.height = HEIGHT
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = HEIGHT / 2.0
	add_child(col)
	_model = Node3D.new()
	add_child(_model)
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = RADIUS
	cap.height = HEIGHT
	body.mesh = cap
	body.position.y = HEIGHT / 2.0
	body.material_override = Look.toon(colour)
	_model.add_child(body)
	var glass := MeshInstance3D.new()
	var g := CylinderMesh.new()
	g.top_radius = 0.04
	g.bottom_radius = 0.03
	g.height = 0.14
	glass.mesh = g
	glass.position = Vector3(0.3, 1.15, -0.2)
	glass.material_override = Look.toon(Color("f0d890"), 0.6)
	_model.add_child(glass)


func _physics_process(_delta: float) -> void:
	if _nim == null or not is_instance_valid(_nim):
		_nim = get_tree().get_first_node_in_group(&"player")
	if _nim == null:
		return
	sees_her = Sight.sees(global_position + Vector3.UP * 1.6, -global_basis.z, _nim, SIGHT_RANGE, SIGHT_HALF_ANGLE,
		0.0, get_world_3d().direct_space_state, [get_rid()])
	_model.rotation.z = sin(Time.get_ticks_msec() / 900.0 + position.x) * 0.03
