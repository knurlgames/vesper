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
## A model to stand on the perch ("gull_lookout"...; assets/enemies), in place of the greybox bird.
@export var look_body := ""

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
## Flicked with the crop (the Pier's brief: "A crop flick shuts them up"): it flaps off and stays gone (Game flag
## "hushed/<world>/<name>").
var hushed := false
var _bird: Array[Node3D] = []
var _pivot: Node3D
var _look: EnemyModel


## What the crop aims at: a point on the post a little under the bird, in the crop's reach from the ground (3.2 m up)
## and out of the claws' (1.8 m).
class Target extends Node3D:
	var hit_radius := 0.4
	var bird: Node

	func can_be_hit() -> bool:
		return not bird.get(&"hushed")

	func take_hit(_from: Vector3, _power: int) -> void:
		bird.call(&"hush")


func _ready() -> void:
	add_to_group(&"lookout")
	add_to_group(&"watcher")
	_build()
	var t := Target.new()
	t.name = "CropTarget"
	t.bird = self
	t.position.y = minf(perch_height, 3.0)
	add_child(t)
	t.add_to_group(&"hittable")
	var game := get_node_or_null(^"/root/Game")
	if game and game.call(&"has_flag", _hush_flag()):
		hushed = true
		for n in _bird:
			n.visible = false
		_mark.text = ""


func _hush_flag() -> String:
	var n := get_parent()
	while n and not n.has_method(&"spawn_player"):
		n = n.get_parent()
	return "hushed/%s/%s" % [n.get(&"world_id") if n else "test", name]


## Cropped: a squawk, and it's off, for good.
func hush() -> void:
	if hushed:
		return
	hushed = true
	alarmed = false
	suspicion = 0.0
	_mark.text = ""
	var game := get_node_or_null(^"/root/Game")
	if game:
		game.call(&"set_flag", _hush_flag())
	var hud := get_node_or_null(^"/root/Hud")
	if hud:
		hud.call(&"caption", "", "SQUAWK!", 1.0)
	var tw := create_tween().set_parallel()
	for n in _bird:
		tw.tween_property(n, ^"position", n.position + Vector3(6.0, 9.0, -4.0), 1.2).set_ease(Tween.EASE_IN)
	await tw.finished
	for n in _bird:
		n.visible = false


func looking() -> Vector3:
	return -_head.global_basis.z


func _physics_process(delta: float) -> void:
	if hushed:
		sees_her = false
		return
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
	if _pivot:
		_pivot.rotation.y = _head.rotation.y
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
	if EnemyModel.exists(look_body):
		_build_model()
		return
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
	_bird = [body, _head]
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
	_mark.no_depth_test = false   # behind walls and floors it stays hidden (it showed through the pier's boards)
	_mark.position.y = perch_height + 1.2
	add_child(_mark)


## The model version: the lookout (an anthro gull, WO-013) stands on a little crow's nest at the post's top, and turns
## the way its head looks.
func _build_model() -> void:
	var nest := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.5
	disc.bottom_radius = 0.4
	disc.height = 0.12
	nest.mesh = disc
	nest.position.y = perch_height
	nest.material_override = Look.toon(Color("4a3a32"))
	add_child(nest)
	_head = Node3D.new()
	_head.position.y = perch_height + 1.4
	add_child(_head)
	_pivot = Node3D.new()
	_pivot.position.y = perch_height + 0.06
	add_child(_pivot)
	_look = EnemyModel.new()
	_look.body = look_body
	_pivot.add_child(_look)
	_look.show_state(0, 0.0, 0.0, 0.0)
	_bird = [_pivot]
	_mark = Label3D.new()
	_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_mark.font_size = 96
	_mark.pixel_size = 0.006
	_mark.outline_size = 14
	_mark.outline_modulate = Look.INK
	_mark.position.y = perch_height + 2.2
	add_child(_mark)
