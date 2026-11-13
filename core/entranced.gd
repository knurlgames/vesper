class_name Entranced
extends CharacterBody3D
## Someone under Swyne's hypnosis (WO-004, DESIGN.md "People in trances"): they wander a loop holding the toy that keeps
## them under. They're never struck or bound: strikes pass through them, and nothing can target them. Break the device
## they hold, from in front of them, and they wake. Waking is counted per world (Game "freed"); five pays a Key.
##
## Never hurt, never the joke (WORK_ORDERS.md §0.2).

signal woke

enum State { ENTRANCED, AWAKE }

@export var id: StringName = &""
## Points they wander between, in a loop (world space). Empty: they sway where they stand.
@export var loop := PackedVector3Array()
@export var colour := Color("9a8aa8")
## A civilian's body (EnemyModel, e.g. "hare_civilian"), lightly tinted by `colour`. Empty or missing: the capsule.
@export var look_body := ""
## Which of Swyne's toys they hold (TranceDevice.TOYS); "" picks one by their id.
@export var toy := ""

## What they murmur while they're under, when Nim's near: it feels so good they can't stop (owner, 2026-11-12). Never
## the joke, never explicit: blissed out, and a little sad. OWNER REVIEW
const MURMURS := [
	"Mmm... just a little longer...",
	"It's so warm. I can't put it down.",
	"Everything's humming. Isn't it lovely?",
	"One more. Just one more.",
	"I was going somewhere... wasn't I? ...Mmm. Later.",
	"Don't take it. Not yet. Please.",
]
## In earshot, a murmur every so often.
const MURMUR_RANGE := 8.0
const MURMUR_EVERY := 5.0
const MURMUR_SHOW := 3.0

var _murmur_t := 1.5

const TINT := 0.35

const WALK_SPEED := 1.0
## Awake and going somewhere: a brisker walk.
const GO_SPEED := 1.5
const TURN_SPEED := 3.0
const GRAVITY := 30.0
const RADIUS := 0.35
const HEIGHT := 1.7

var state := State.ENTRANCED
var world: StringName = &"test"
var device: Node3D
var _i := 0
var _path: Array = []
var _model: Node3D
var _look: EnemyModel
var _line: Label3D
var _line_t := 0.0

const WAKE_LINE := "...Where am I? Why am I holding this?"   # OWNER REVIEW


func _ready() -> void:
	add_to_group(&"entranced")
	var n := get_parent()
	while n and not n.has_method(&"spawn_player"):
		n = n.get_parent()
	if n:
		world = n.get(&"world_id")
	_build()
	var game := get_node_or_null(^"/root/Game")
	if game and game.call(&"has_collected", &"freed", world, id):
		_wake(false)


func facing() -> Vector3:
	return -global_basis.z


## The device was broken: they come round.
func wake() -> void:
	if state == State.AWAKE:
		return
	_wake(true)
	var game := get_node_or_null(^"/root/Game")
	if game:
		game.call(&"collect", &"freed", world, id)
	woke.emit()


func _wake(say: bool) -> void:
	state = State.AWAKE
	velocity = Vector3.ZERO
	if device:
		device.queue_free()
		device = null
	if say:
		_line.text = WAKE_LINE
		var hud := get_node_or_null(^"/root/Hud")
		if hud:
			hud.call(&"caption", "", WAKE_LINE)
		_line_t = 4.0


## Awake, they walk off somewhere (a path, once) instead of vanishing: `go(points)`.
func go(points: Array) -> void:
	_path = points.duplicate()


func _physics_process(delta: float) -> void:
	var flat := Vector3.ZERO
	var target := Vector3.INF
	if not _path.is_empty():
		target = _path[0]
	elif state == State.ENTRANCED and not loop.is_empty():
		target = loop[_i]
	if target != Vector3.INF:
		var to := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
		if to.length() < 0.3:
			if not _path.is_empty():
				_path.pop_front()
			else:
				_i = (_i + 1) % loop.size()
		else:
			flat = to.normalized() * (WALK_SPEED if _path.is_empty() else GO_SPEED)
			rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), clampf(TURN_SPEED * delta, 0.0, 1.0))
	velocity.x = flat.x
	velocity.z = flat.z
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()
	# A slow sway while they're under.
	_model.rotation.z = sin(Time.get_ticks_msec() / 700.0) * 0.06 if state == State.ENTRANCED else 0.0
	if _look:
		_look.show_state(0, 0.0, flat.length(), 0.0)
	if _line_t > 0.0:
		_line_t -= delta
		if _line_t <= 0.0:
			_line.text = ""
	elif state == State.ENTRANCED:
		_murmur(delta)


func _murmur(delta: float) -> void:
	var nim := get_tree().get_first_node_in_group(&"player") as Node3D
	if nim == null or nim.global_position.distance_to(global_position) > MURMUR_RANGE:
		_murmur_t = minf(_murmur_t, 1.5)   # the first one comes soon after she's near
		return
	_murmur_t -= delta
	if _murmur_t > 0.0:
		return
	_murmur_t = MURMUR_EVERY + randf() * 2.0
	_line.text = MURMURS[randi() % MURMURS.size()]
	_line_t = MURMUR_SHOW


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
		_look.tint = Color.WHITE.lerp(colour.lightened(0.3), TINT)
		_model.add_child(_look)
	else:
		var body := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = RADIUS
		cap.height = HEIGHT
		body.mesh = cap
		body.position.y = HEIGHT / 2.0
		body.material_override = Look.toon(colour)
		_model.add_child(body)
	device = TranceDevice.new()
	device.toy = toy if toy != "" else TranceDevice.TOYS[absi(hash(String(id))) % TranceDevice.TOYS.size()]
	device.position = Vector3(0.0, 1.05, -0.38)   # hugged close, in front (struck from the front only)
	if _look and _look.head_height() > 0.5:
		device.position.y = _look.head_height() * 0.78   # at the chest, whatever their height
	add_child(device)
	_line = Label3D.new()
	_line.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_line.font_size = 32
	_line.pixel_size = 0.004
	_line.outline_size = 6
	_line.outline_modulate = Look.INK
	_line.position.y = HEIGHT + 0.4
	add_child(_line)
