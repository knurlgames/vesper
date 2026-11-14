class_name ClubClient
extends CharacterBody3D
## A client at the Velvet Claw (WO-014b, DESIGN.md "The Velvet Claw's house"): an adult guest who's asked to be here.
## levels/hub/club_life.gd moves them through the evening: in at the door in street clothes, changed at the screen
## (swimwear downstairs: the owner's dress code), down to the vaults' hall to wait, a session in a sister's room,
## aftercare in Lull's room, and out again. While they wait, they're Nim's for a session of her own (in the suit).
##
## A walking body: `go(points)` walks them through points in turn; `pose(clip, hold)` plays a session clip (kneel,
## sit, drink); `say(text)` shows a line over them.

const SPEED := 1.5
const TURN_SPEED := 6.0

const RADIUS := 0.33   # the fallback capsule
const HEIGHT := 1.7

## Their bodies (EnemyModel): street clothes upstairs, swimwear downstairs. A light tint makes four species a crowd.
var street_body := "otter_civilian"
var swim_body := "otter_swim"
var tint := Color.WHITE
## A regular's id and name ("" for a member's guest); and which conversation they have with Nim.
var regular: StringName = &""
var display := ""
var talk_as := "client"
## The phase club_life keeps them in, and its own scratch (the room, the spot, the time left).
var phase: StringName = &"arriving"
var room: Dictionary = {}
var spot := Vector3.ZERO
var t := 0.0
var face_toward := Vector3.INF

var _path: Array = []
var _model: Node3D
var _look: EnemyModel
var _posed := false
var _line: Label3D
var _line_t := 0.0
var _tag: Label3D


func _ready() -> void:
	add_to_group(&"club_client")
	# Not solid: an ambient crowd steps through people (on the 3 m ramps they jammed Nim and each other). Their paths
	# carry the floors' heights, ramps included, so they need no physics to stay on them.
	collision_layer = 0
	collision_mask = 0
	_model = Node3D.new()
	add_child(_model)
	dress(street_body)
	_line = Label3D.new()
	_line.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_line.font_size = 30
	_line.pixel_size = 0.004
	_line.outline_size = 6
	_line.outline_modulate = Look.INK
	_line.position.y = HEIGHT + 0.45
	add_child(_line)
	if display != "":
		_tag = Label3D.new()
		_tag.text = display
		_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_tag.font_size = 26
		_tag.pixel_size = 0.004
		_tag.outline_size = 6
		_tag.outline_modulate = Look.INK
		_tag.modulate = Color("e8d7c0")
		_tag.position.y = HEIGHT + 0.2
		add_child(_tag)


## Into a body (EnemyModel name); the capsule if it isn't there.
func dress(body: String) -> void:
	for c in _model.get_children():
		c.queue_free()
	_look = null
	_posed = false
	if EnemyModel.exists(body):
		_look = EnemyModel.new()
		_look.body = body
		_look.tint = tint
		_model.add_child(_look)
		_look.show_state(0, 0.0, 0.0, 0.0)
		return
	var cap := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = RADIUS
	mesh.height = HEIGHT
	cap.mesh = mesh
	cap.position.y = HEIGHT / 2.0
	cap.material_override = Look.toon(tint)
	_model.add_child(cap)


func go(points: Array) -> void:
	_path = points.duplicate()
	_posed = false


func walking() -> bool:
	return not _path.is_empty()


## A session clip (EnemyModel.pose); idle if the body hasn't it.
func pose(clip: StringName, hold := -1.0) -> void:
	_posed = _look != null and _look.pose(clip, hold)


func say(text: String, secs := 3.5) -> void:
	_line.text = text
	_line_t = secs


func _physics_process(delta: float) -> void:
	var speed := 0.0
	if not _path.is_empty():
		var p: Vector3 = _path[0]
		var to := p - global_position
		var flat := Vector3(to.x, 0.0, to.z)
		if to.length() < 0.08:
			global_position = p
			_path.pop_front()
		else:
			global_position += to.limit_length(SPEED * delta)
			speed = SPEED
			if flat.length() > 0.05:
				rotation.y = lerp_angle(rotation.y, atan2(-flat.x, -flat.z), clampf(TURN_SPEED * delta, 0.0, 1.0))
	elif face_toward != Vector3.INF:
		var d := face_toward - global_position
		rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), clampf(TURN_SPEED * delta, 0.0, 1.0))
	if _look and not _posed:
		_look.show_state(0, 0.0, speed, 0.0)
	if _line_t > 0.0:
		_line_t -= delta
		if _line_t <= 0.0:
			_line.text = ""
