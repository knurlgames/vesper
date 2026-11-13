class_name Staff
extends CharacterBody3D
## Staff at one of Swyne's places (WO-006): a barman, a waiter, a doorman. They take orders from a Domme. Tier 2:
## they'll Kneel, Fetch and Open. Fetch: they walk to their `fetch_item`, pick it up and bring it to her. Open: they walk
## to their `door` and open it. Then they go back to their post. They're watchers: what she does in front of them costs
## Composure.

enum State { IDLE, KNEEL, FETCH_GO, FETCH_BRING, OPEN_GO, RETURN }

@export var fetch_item: NodePath
@export var door: NodePath
@export var tier := 2
## The powerful (councillors, the Ball's guests): they answer to no Domme, until Augusta's signet (tier 0 without it).
@export var powerful := false
@export var colour := Color("e0d8c8")
## An enemy body to wear ("weasel_goon", "meerkat_watch"...; assets/enemies) instead of the greybox capsule.
@export var look_body := ""
## Who the captions name ("Staff" or "Councillor" if empty), and what he says when told to kneel.
@export var speaker := ""
@export var kneel_line := "Yes, Mistress."   # OWNER REVIEW

const WALK_SPEED := 2.6
const TURN_SPEED := 8.0
const GRAVITY := 30.0
const KNEEL_TIME := 20.0
const SIGHT_RANGE := 12.0
const SIGHT_HALF_ANGLE := deg_to_rad(60.0)
const RADIUS := 0.35
const HEIGHT := 1.75
const REACH := 0.9

var state := State.IDLE
var sees_her := false
var _t := 0.0
var _home := Vector3.ZERO
var _home_yaw := 0.0
var _nim: Node3D
var _carrying: Node3D
var _model: Node3D
var _look: EnemyModel
var _line: Label3D
var _line_t := 0.0


func _ready() -> void:
	add_to_group(&"staff")
	add_to_group(&"watcher")
	add_to_group(&"commandable")
	_home = global_position
	_home_yaw = rotation.y
	_build()


func command_tier() -> int:
	return 0 if powerful else tier


func can_obey(word: StringName) -> bool:
	if state != State.IDLE and state != State.RETURN:
		return false
	match word:
		&"fetch":
			return has_node(fetch_item) and get_node(fetch_item).is_visible_in_tree()
		&"open":
			return has_node(door) and not get_node(door).get(&"is_open")
	return word == &"kneel"


func obey(word: StringName, by: Node3D) -> void:
	_nim = by
	match word:
		&"kneel":
			state = State.KNEEL
			_t = KNEEL_TIME
			_say(kneel_line)
		&"fetch":
			state = State.FETCH_GO
			_say("At once.")   # OWNER REVIEW
		&"open":
			state = State.OPEN_GO
			_say("Of course.")   # OWNER REVIEW


func _physics_process(delta: float) -> void:
	if _nim == null or not is_instance_valid(_nim):
		_nim = get_tree().get_first_node_in_group(&"player")
	sees_her = state != State.KNEEL and _nim != null and Sight.sees(global_position + Vector3.UP * 1.6, -global_basis.z,
		_nim, SIGHT_RANGE, SIGHT_HALF_ANGLE, 0.0, get_world_3d().direct_space_state, [get_rid()])
	var flat := Vector3.ZERO
	match state:
		State.KNEEL:
			_t -= delta
			if _t <= 0.0:
				state = State.RETURN
		State.FETCH_GO:
			var item := get_node(fetch_item) as Node3D
			flat = _toward(item.global_position, delta)
			if _flat_dist(item.global_position) < REACH:
				_carrying = item
				item.reparent(self)
				item.position = Vector3(0.3, 1.1, -0.3)
				state = State.FETCH_BRING
		State.FETCH_BRING:
			flat = _toward(_nim.global_position, delta)
			if _flat_dist(_nim.global_position) < 1.3:
				var suit: Node = _nim.get(&"suit")
				if suit and _carrying:
					suit.call(&"receive", _carrying.get(&"id"))
				if _carrying:
					_carrying.queue_free()
					_carrying = null
				state = State.RETURN
		State.OPEN_GO:
			var d := get_node(door) as Node3D
			var front: Vector3 = d.call(&"front")
			flat = _toward(front, delta)
			if _flat_dist(front) < REACH:
				d.call(&"open")
				state = State.RETURN
		State.RETURN:
			flat = _toward(_home, delta)
			if _flat_dist(_home) < 0.3:
				state = State.IDLE
		State.IDLE:
			rotation.y = lerp_angle(rotation.y, _home_yaw, clampf(TURN_SPEED * delta, 0.0, 1.0))
	velocity.x = flat.x
	velocity.z = flat.z
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()
	if _look:
		# Kneeling, he's down on the floor (the knocked-down pose, held); otherwise he stands or walks.
		_look.show_state(7 if state == State.KNEEL else 0, 0.0, Vector2(velocity.x, velocity.z).length(), 0.0)
	else:
		_model.position.y = -0.6 if state == State.KNEEL else 0.0
	if _line_t > 0.0:
		_line_t -= delta
		if _line_t <= 0.0:
			_line.text = ""


func _toward(p: Vector3, delta: float) -> Vector3:
	var to := Vector3(p.x - global_position.x, 0.0, p.z - global_position.z)
	if to.length() < 0.1:
		return Vector3.ZERO
	rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), clampf(TURN_SPEED * delta, 0.0, 1.0))
	return to.normalized() * WALK_SPEED


func _flat_dist(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()


func _say(text: String) -> void:
	_line.text = text
	_line_t = 2.5
	var hud := get_node_or_null(^"/root/Hud")
	if hud:
		hud.call(&"caption", speaker if speaker != "" else ("Councillor" if powerful else "Staff"), text)


func _build() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = RADIUS
	shape.height = HEIGHT
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = HEIGHT / 2.0
	add_child(col)
	_model = Node3D.new()
	add_child(_model)
	if EnemyModel.exists(look_body):
		_look = EnemyModel.new()
		_look.body = look_body
		_model.add_child(_look)
		_build_line()
		return
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = RADIUS
	cap.height = HEIGHT
	body.mesh = cap
	body.position.y = HEIGHT / 2.0
	body.material_override = Look.toon(colour)
	_model.add_child(body)
	var tie := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.22, 0.08, 0.1)
	tie.mesh = b
	tie.position = Vector3(0, 1.45, -RADIUS)
	tie.material_override = Look.toon(Look.INK)
	_model.add_child(tie)
	_build_line()


func _build_line() -> void:
	_line = Label3D.new()
	_line.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_line.font_size = 32
	_line.pixel_size = 0.004
	_line.outline_size = 6
	_line.outline_modulate = Look.INK
	_line.position.y = HEIGHT + 0.35
	add_child(_line)
