class_name Lure
extends RigidBody3D
## A lure (WO-007, Rivet's gear): one of Swyne's seized toys, boxed, thrown. Where it lands it buzzes for a while, and
## every goon within earshot comes to see what it is (Enemy.hear, twice over, sends him to search the spot). It's
## never shown in use: a box, a spiral glow, a buzz.

const BUZZ_TIME := 6.0
const BUZZ_EVERY := 0.5
const BUZZ_RADIUS := 11.0

var buzzing := false
var _t := 0.0
var _every := 0.0
var _glow: MeshInstance3D


func _ready() -> void:
	add_to_group(&"lure")
	mass = 0.4
	contact_monitor = true
	max_contacts_reported = 2
	collision_layer = 0
	collision_mask = 1
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.22, 0.3, 0.12)
	var col := CollisionShape3D.new()
	col.shape = shape
	add_child(col)
	var box := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = shape.size
	box.mesh = b
	box.material_override = Look.toon(Color("e0d0e8"))
	add_child(box)
	_glow = MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.04
	t.outer_radius = 0.08
	_glow.mesh = t
	_glow.rotation.x = PI / 2.0
	_glow.position.z = -0.07
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.5, 0.8, 2.2)
	_glow.material_override = m
	add_child(_glow)
	body_entered.connect(func(_b: Node) -> void:
		if not buzzing:
			buzzing = true
			_t = BUZZ_TIME)


func _physics_process(delta: float) -> void:
	if not buzzing:
		return
	_t -= delta
	_every -= delta
	_glow.rotation.z += 12.0 * delta
	if _every <= 0.0:
		_every = BUZZ_EVERY
		for l: Node3D in get_tree().get_nodes_in_group(&"listener"):
			if l.global_position.distance_to(global_position) <= BUZZ_RADIUS:
				l.call(&"hear", global_position)
	if _t <= 0.0:
		buzzing = false
		_glow.visible = false
