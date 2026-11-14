extends Node3D
## A third-person camera on a spring arm, ported from Nine Lives: right stick, arrow keys or the mouse turn it; R3 / V /
## middle mouse swings it back behind her. Click the window to capture the mouse; pausing frees it.

const DISTANCE := 5.5
## Under this far from her (a wall's pushed the camera in), it starts to rise over her shoulder.
const CLOSE_FROM := 1.6
const HEIGHT := 1.3
const STICK_SPEED := 2.6
const MOUSE_SPEED := 0.004
const PITCH_MIN := -1.2
const PITCH_MAX := 0.35
const RECENTRE_SPEED := 10.0
const LOCK_SPEED := 6.0

var target: Node3D
## Locked on (LT): the camera swings to keep this goon in view past her shoulder.
var lock_target: Node3D
var yaw := 0.0
var pitch := -0.32
var _arm: SpringArm3D
var _cam: Camera3D
var _holder: Node3D
var _recentring := false


func _ready() -> void:
	top_level = true
	_arm = SpringArm3D.new()
	_arm.spring_length = DISTANCE
	_arm.margin = 0.2
	_arm.collision_mask = 1 | 8   # the world, plus layer 4: things only the camera should keep out of
	var probe := SphereShape3D.new()
	probe.radius = 0.25
	_arm.shape = probe
	add_child(_arm)
	_cam = Camera3D.new()
	# Depth precision for surfaces a few centimetres apart: the defaults (5 cm to 4 km) spread it thin.
	_cam.near = 0.1
	_cam.far = 600.0
	_cam.fov = 62.0
	# The arm places its child at its length; the squeeze's crane moves the camera inside that child. Setting the
	# camera's own position (it was the arm's child) wiped out the arm's placement whenever this ran after the arm:
	# the camera sat at the pivot, inside Nim (owner, Deck clip 2026-11-13: "perma zoomed in on Nim's back").
	_holder = Node3D.new()
	_arm.add_child(_holder)
	_holder.add_child(_cam)
	_cam.make_current()
	# The player moves on physics ticks and the project interpolates her between them. The camera moves every rendered
	# frame, so it follows her interpolated position and opts out of interpolation itself. Chasing her raw tick position
	# is what made Kiara jitter on the Deck, where the screen and the physics tick don't line up.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _process(delta: float) -> void:
	if target == null:
		return
	if target is CollisionObject3D:
		_arm.add_excluded_object((target as CollisionObject3D).get_rid())
	var look := Controls.camera_vector() * _feel()
	yaw -= look.x * STICK_SPEED * delta
	pitch = clampf(pitch - look.y * STICK_SPEED * 0.6 * delta, PITCH_MIN, PITCH_MAX)
	if Input.is_action_just_pressed(&"cam_recentre"):
		_recentring = true
	if look.length() > 0.0:
		_recentring = false
	if lock_target and is_instance_valid(lock_target):
		var to := lock_target.global_position - target.global_position
		if Vector2(to.x, to.z).length() > 0.5:
			yaw = lerp_angle(yaw, atan2(-to.x, -to.z), clampf(LOCK_SPEED * delta, 0.0, 1.0))
		_recentring = false
	elif _recentring:
		# Behind her is where her back faces: her model looks down its -Z.
		var behind := target.global_rotation.y
		yaw = lerp_angle(yaw, behind, clampf(RECENTRE_SPEED * delta, 0.0, 1.0))
		if absf(angle_difference(yaw, behind)) < 0.01:
			_recentring = false
	var at := target.get_global_transform_interpolated().origin + Vector3.UP * HEIGHT
	if global_position.distance_to(at) > 8.0:
		global_position = at  # a reset or a scene start: cut, don't swoop
	global_position = global_position.lerp(at, clampf(12.0 * delta, 0.0, 1.0))
	rotation = Vector3(pitch, yaw, 0)
	# Pushed in by a wall: rise and look down over her shoulder rather than press into her back, and at the very
	# closest, drop her outline (owner, Deck review 5: close up she looked "all around cracked").
	var squeeze := clampf((CLOSE_FROM - _arm.get_hit_length()) / CLOSE_FROM, 0.0, 1.0)
	_cam.position = Vector3(0.0, squeeze * 0.85, 0.0)
	_cam.rotation.x = -squeeze * 0.55
	var model: Node = target.get(&"model")
	if model and model.has_method(&"camera_close"):
		model.call(&"camera_close", _arm.get_hit_length() < 0.75)


## The way "up" on the stick points, flat on the ground.
func forward() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED \
			and not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m: Vector2 = event.relative * _feel()
		yaw -= m.x * MOUSE_SPEED
		pitch = clampf(pitch - m.y * MOUSE_SPEED, PITCH_MIN, PITCH_MAX)
		_recentring = false


## The settings' camera speed and inverts, as a per-axis multiplier.
func _feel() -> Vector2:
	var speed: float = Game.get_setting("cam_speed")
	return Vector2(-speed if Game.get_setting("invert_x") else speed, -speed if Game.get_setting("invert_y") else speed)
