class_name Lookout
extends Node3D
## A lookout (WO-005): a gull, meerkat, heron or magpie on a perch. It never fights. Its head sweeps back and forth;
## when it's sure it's seen Nim it shrieks, and every goon within ALARM_RADIUS comes running to where she was.
## Then it settles and goes back to watching. Same sight rule as the goons (`Sight`): dark and crouched, she's hard
## to spot.
##
## A greybox bird on a post: the beak shows where it's looking.

signal alarm(at: Vector3)

## The way the sweep is centred (yaw, like a node's rotation.y: 0 looks down -Z).
@export var watch_yaw := 0.0
## How far either side of watch_yaw the head sweeps.
@export var sweep := deg_to_rad(40.0)
@export var perch_height := 2.5

const SIGHT_RANGE := 16.0
const SIGHT_HALF_ANGLE := deg_to_rad(60.0)
const BUMP_RANGE := 1.0
const SWEEP_TIME := 6.0
const NOTICE_NEAR := 2.0
const NOTICE_FAR := 0.6
const FORGET := 0.4
const ALARM_RADIUS := 30.0
## After an alarm it shrieks for a while, then settles; it can't raise another until it has.
const ALARM_HOLD := 4.0

var suspicion := 0.0
## Whether it can see her at all (her Composure, in the suit).
var sees_her := false
var alarmed := false
var alarms := 0
var _hold := 0.0
var _phase := 0.0
var _head: Node3D
var _mark: Label3D
var _nim: Node3D


func _ready() -> void:
	add_to_group(&"lookout")
	add_to_group(&"watcher")
	_build()


func looking() -> Vector3:
	return -_head.global_basis.z


func _physics_process(delta: float) -> void:
	if _nim == null or not is_instance_valid(_nim):
		_nim = get_tree().get_first_node_in_group(&"player")
	_phase += delta
	if _hold > 0.0:
		_hold -= delta
		if _hold <= 0.0:
			alarmed = false
			suspicion = 0.0
	else:
		_head.rotation.y = watch_yaw + sin(_phase / SWEEP_TIME * TAU) * sweep
	sees_her = _nim != null and Sight.sees(_head.global_position, looking(), _nim, SIGHT_RANGE, SIGHT_HALF_ANGLE,
		BUMP_RANGE, get_world_3d().direct_space_state)
	# A bird only cares about an intruder: the suit, with her cover intact, is just another guest.
	var suit: Node = _nim.get(&"suit") if _nim else null
	var sees: bool = sees_her and (suit == null or suit.call(&"suspicious_to", self))
	if sees and not alarmed:
		var d := _head.global_position.distance_to(_nim.global_position)
		suspicion = minf(1.0, suspicion + lerpf(NOTICE_NEAR, NOTICE_FAR, clampf(d / SIGHT_RANGE, 0.0, 1.0)) * delta)
		# Watching her: the head follows.
		var to := _nim.global_position - _head.global_position
		_head.rotation.y = lerp_angle(_head.rotation.y, atan2(-to.x, -to.z) - rotation.y, clampf(4.0 * delta, 0.0, 1.0))
		if suspicion >= 1.0:
			_raise(_nim.global_position)
	elif not alarmed:
		suspicion = maxf(0.0, suspicion - FORGET * delta)
	_mark.text = "!!" if alarmed else ("?" if suspicion > 0.15 else "")
	_mark.modulate = Color("ff5a4a") if alarmed else Color("ffd84a")


func _raise(at: Vector3) -> void:
	alarmed = true
	alarms += 1
	_hold = ALARM_HOLD
	for e: Node3D in get_tree().get_nodes_in_group(&"enemy"):
		if e.global_position.distance_to(global_position) <= ALARM_RADIUS:
			e.call(&"alert", at)
	alarm.emit(at)


func _build() -> void:
	var post := StaticBody3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.12
	shape.height = perch_height
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = perch_height / 2.0
	post.add_child(col)
	var pole := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.08
	cyl.bottom_radius = 0.12
	cyl.height = perch_height
	pole.mesh = cyl
	pole.position.y = perch_height / 2.0
	pole.material_override = Look.toon(Color("4a3a32"))
	post.add_child(pole)
	add_child(post)
	var body := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.4
	body.mesh = sphere
	body.position.y = perch_height + 0.2
	body.material_override = Look.toon(Color("e8e8e0"))
	body.material_overlay = Look.outline(AABB(Vector3(-0.25, -0.2, -0.25), Vector3(0.5, 0.4, 0.5)), 0.012)
	add_child(body)
	_head = Node3D.new()
	_head.position.y = perch_height + 0.5
	add_child(_head)
	var head := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.14
	hs.height = 0.28
	head.mesh = hs
	head.material_override = Look.toon(Color("e8e8e0"))
	_head.add_child(head)
	var beak := MeshInstance3D.new()
	var bm := PrismMesh.new()
	bm.size = Vector3(0.1, 0.25, 0.08)
	beak.mesh = bm
	beak.rotation.x = -PI / 2.0
	beak.position.z = -0.2
	beak.material_override = Look.toon(Color("e8a030"))
	_head.add_child(beak)
	_mark = Label3D.new()
	_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_mark.font_size = 96
	_mark.pixel_size = 0.006
	_mark.outline_size = 14
	_mark.outline_modulate = Look.INK
	_mark.no_depth_test = true
	_mark.position.y = perch_height + 1.2
	add_child(_mark)
