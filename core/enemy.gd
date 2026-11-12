class_name Enemy
extends CharacterBody3D
## EnemyBase (WO-004, WO-005): one of Swyne's goons. It patrols, grows suspicious, chases, fights, searches and gives up.
## Struck, it staggers; the third hit of a combo knocks it down. Staggered, knocked down or caught unaware, Nim can bind
## it. Bound, it stays bound for good: the flag survives checkpoints, reloads and saves, per world.
##
## Goons never die (DESIGN.md: her takedowns restrain, never kill). Sight is `Sight.sees`: a cone and a line of sight,
## shortened by darkness and crouching. He hears her running, landing and fighting (`hear`), and comes when a lookout
## raises the alarm (`alert`). Unaware, he can be taken down only from behind (`bindable_from`).
##
## A greybox capsule with a cap, a fist that telegraphs its punch, and a ? or ! over its head.

signal bound

enum State { PATROL, SUSPICIOUS, CHASE, FIGHT, SEARCH, RETURN, STAGGER, KNOCKDOWN, BINDING, BOUND, KNEEL, FROZEN }

## Unique within its world: bound goons are remembered by it.
@export var id: StringName = &""
## Points it walks between, in a loop (world space). Empty: it stands guard where it started, facing the way it faced.
@export var patrol := PackedVector3Array()
@export var colour := Color("7d8a5a")
## Security who know her face: they suspect her even in the suit (unless she's lost in a crowd).
@export var knows_her := false

# --- tunables --------------------------------------------------------------------------------------------------------
const WALK_SPEED := 2.2
const RUN_SPEED := 5.0
const TURN_SPEED := 7.0
const ACCEL := 20.0
const GRAVITY := 30.0
const SIGHT_RANGE := 14.0
const SIGHT_HALF_ANGLE := deg_to_rad(55.0)
## A noise lifts suspicion to at least this, plus a step; past HEAR_INVESTIGATE, the next noise sends him to look.
const HEAR_SUSPICION := 0.4
const HEAR_STEP := 0.25
const HEAR_INVESTIGATE := 0.6
## An unaware goon can be taken down only from this far round behind him (angle from where he's looking).
const TAKEDOWN_BEHIND := deg_to_rad(100.0)
## Told to kneel, he stays down this long, out of her way and watching nothing.
const KNEEL_TIME := 20.0
## Closer than this he notices her whichever way he faces (he bumps into her).
const BUMP_RANGE := 1.2
## Suspicion per second at point blank and at the edge of sight; it drains when she's out of sight.
const NOTICE_NEAR := 2.5
const NOTICE_FAR := 0.5
const FORGET := 0.35
## Suspicion above this and he stops to look; at 1 he gives chase.
const LOOK_AT := 0.15
const LOSE_TIME := 2.5
const SEARCH_TIME := 3.5
const ATTACK_RANGE := 1.7
const WINDUP := 0.6
const RECOVER := 0.9
const STAGGER_TIME := 0.8
const KNOCKDOWN_TIME := 1.8
const STAGGER_KNOCK := 1.0
const KNOCKDOWN_KNOCK := 5.0
const RADIUS := 0.4
const HEIGHT := 1.8
## How far past his centre a strike can still reach him.
var hit_radius := 0.45

var state := State.PATROL
var suspicion := 0.0
var last_seen := Vector3.ZERO
## Whether he can see her right now, suspicious or not (Composure, in the suit).
var sees_her := false
var world: StringName = &"test"

var _t := 0.0
var _lost := 0.0
var _struck := false
var _patrol_i := 0
var _home := Vector3.ZERO
var _home_yaw := 0.0
var _nim: Node3D
var _model: Node3D
var _fist: MeshInstance3D
var _mark: Label3D
var _ropes: Node3D
var _note: Label3D


func _ready() -> void:
	add_to_group(&"enemy")
	add_to_group(&"hittable")
	add_to_group(&"listener")
	add_to_group(&"watcher")
	add_to_group(&"commandable")
	_home = global_position
	_home_yaw = rotation.y
	var level := _level()
	if level:
		world = level.get(&"world_id")
	_build()
	if _game() and _game().call(&"has_flag", bound_flag()):
		_become_bound()


## The flag that remembers him bound.
func bound_flag() -> String:
	return "bound/%s/%s" % [world, id]


func can_be_hit() -> bool:
	return state != State.BOUND and state != State.BINDING


## Nim may tie him: staggered, knocked down, or unaware of her.
func can_bind() -> bool:
	match state:
		State.STAGGER, State.KNOCKDOWN, State.FROZEN:
			return true
		State.PATROL, State.RETURN:
			return suspicion < 0.5
	return false


func is_bound() -> bool:
	return state == State.BOUND


## A strike or pounce from `from`. Power 1 staggers, 2 knocks him down.
func take_hit(from: Vector3, power: int) -> void:
	if not can_be_hit():
		return
	var away := global_position - from
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else -global_basis.z
	if power >= 2:
		state = State.KNOCKDOWN
		_t = KNOCKDOWN_TIME
		velocity = away * KNOCKDOWN_KNOCK + Vector3.UP * 3.0
	else:
		state = State.STAGGER
		_t = STAGGER_TIME
		velocity = away * STAGGER_KNOCK
	_struck = true
	suspicion = 1.0
	last_seen = from


func begin_bind() -> void:
	state = State.BINDING
	velocity = Vector3.ZERO


func cancel_bind() -> void:
	if state == State.BINDING:
		state = State.STAGGER
		_t = STAGGER_TIME


func finish_bind() -> void:
	_become_bound()
	if _game():
		_game().call(&"set_flag", bound_flag())
	bound.emit()


func _physics_process(delta: float) -> void:
	if _nim == null or not is_instance_valid(_nim):
		_nim = get_tree().get_first_node_in_group(&"player")
	if state == State.BOUND or state == State.BINDING:
		sees_her = false
		_show()
		return
	if state == State.KNEEL or state == State.FROZEN:
		sees_her = false
		_t -= delta
		if _t <= 0.0:
			if state == State.FROZEN:
				_chase()   # he comes out of it furious
			else:
				state = State.RETURN
		velocity = Vector3(0.0, velocity.y - GRAVITY * delta, 0.0)
		move_and_slide()
		_show()
		return
	var sees := _nim != null and noticing()
	_think(delta, sees)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()
	_show()


## Can he see Nim right now? A cone, a range (shorter when she's crouched), and a clear line between his eyes and her.
## `sees_her` is whether he can see her at all (it's what drains her Composure in the suit); this is whether he
## suspects what he sees: always in her night garb, in the suit only once her cover's blown or if he knows her face.
func noticing() -> bool:
	sees_her = Sight.sees(global_position + Vector3.UP * 1.6, -global_basis.z, _nim, SIGHT_RANGE, SIGHT_HALF_ANGLE,
		BUMP_RANGE, get_world_3d().direct_space_state, [get_rid()])
	if not sees_her:
		return false
	var suit: Node = _nim.get(&"suit")
	return suit == null or suit.call(&"suspicious_to", self)


# --- the suit: commands, a wardrobe change, Hold the Room (WO-006) ---------------------------------------------------

## The most authority he answers to: goons only kneel.
func command_tier() -> int:
	return 1


func can_obey(word: StringName) -> bool:
	return word == &"kneel" and state in [State.PATROL, State.RETURN, State.SUSPICIOUS, State.SEARCH]


func obey(word: StringName, _by: Node3D) -> void:
	if word == &"kneel":
		state = State.KNEEL
		_t = KNEEL_TIME
		suspicion = 0.0
		velocity = Vector3.ZERO


## Grizelda's Scold: he freezes where he stands for `secs` (and can be bound meanwhile). False if he can't be.
func freeze(secs: float) -> bool:
	if state in [State.BOUND, State.BINDING, State.KNEEL]:
		return false
	state = State.FROZEN
	_t = secs
	velocity = Vector3.ZERO
	return true


## After her: chasing, fighting or searching.
func hunting() -> bool:
	return state in [State.CHASE, State.FIGHT, State.SEARCH]


## She changed out of sight: whoever was chasing her goes to look where she was, and finds someone else.
func lose_her() -> void:
	if state == State.CHASE or state == State.FIGHT:
		state = State.SEARCH
		_t = SEARCH_TIME
		_lost = 0.0


## Stared down (Hold the Room): he stops, thinks better of it, and goes back to his rounds.
func stand_down() -> void:
	if hunting() or state == State.SUSPICIOUS:
		state = State.RETURN
		suspicion = 0.0


## A noise (her running, landing, fighting) from `at`. He turns to look; a second noise sends him to see what it was.
## Hearing alone never starts a chase.
func hear(at: Vector3) -> void:
	match state:
		State.PATROL, State.RETURN, State.SUSPICIOUS, State.SEARCH:
			last_seen = at
			# A second noise while he's still wondering about the first: he goes to look.
			if state == State.SUSPICIOUS or state == State.SEARCH or suspicion >= HEAR_INVESTIGATE:
				if state != State.SEARCH:
					_t = SEARCH_TIME
				state = State.SEARCH
			else:
				state = State.SUSPICIOUS
			suspicion = minf(0.95, maxf(suspicion, HEAR_SUSPICION) + HEAR_STEP)


## A lookout's alarm: she was seen at `at`. He comes running.
func alert(at: Vector3) -> void:
	match state:
		State.BOUND, State.BINDING, State.STAGGER, State.KNOCKDOWN, State.FIGHT, State.FROZEN:
			return
	last_seen = at
	_chase()


## Can Nim tie him from `from`? Staggered or knocked down: from anywhere. Unaware: only from behind (the takedown).
func bindable_from(from: Vector3) -> bool:
	if not can_bind():
		return false
	if state == State.STAGGER or state == State.KNOCKDOWN or state == State.FROZEN:
		return true
	var to := from - global_position
	to.y = 0.0
	return to.length() < 0.01 or (-global_basis.z).angle_to(to) > TAKEDOWN_BEHIND


func _think(delta: float, sees: bool) -> void:
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if sees and state != State.STAGGER and state != State.KNOCKDOWN:
		var d := global_position.distance_to(_nim.global_position)
		suspicion = minf(1.0, suspicion + lerpf(NOTICE_NEAR, NOTICE_FAR, clampf(d / SIGHT_RANGE, 0.0, 1.0)) * delta)
		last_seen = _nim.global_position
	elif state != State.CHASE and state != State.FIGHT:
		suspicion = maxf(0.0, suspicion - FORGET * delta)

	match state:
		State.PATROL, State.RETURN, State.SEARCH:
			if suspicion >= 1.0:
				_chase()
			elif suspicion > LOOK_AT and state != State.SEARCH:   # searching, he keeps looking rather than stopping to stare
				state = State.SUSPICIOUS
			elif state == State.PATROL:
				flat = _patrol(delta)
			elif state == State.RETURN:
				flat = _go_home(delta)
			else:
				flat = _search(delta)
		State.SUSPICIOUS:
			_face(last_seen, delta)
			flat = flat.move_toward(Vector3.ZERO, ACCEL * delta)
			if suspicion >= 1.0:
				_chase()
			elif suspicion <= 0.0:
				state = State.RETURN
		State.CHASE:
			if sees:
				_lost = 0.0
			else:
				_lost += delta
			if _lost > LOSE_TIME:
				state = State.SEARCH
				_t = SEARCH_TIME
			elif sees and global_position.distance_to(_nim.global_position) <= ATTACK_RANGE:
				state = State.FIGHT
				_t = WINDUP + RECOVER
				_struck = false
			else:
				flat = _toward(last_seen, RUN_SPEED, delta)
		State.FIGHT:
			flat = flat.move_toward(Vector3.ZERO, ACCEL * delta)
			if _t > RECOVER:
				_face(_nim.global_position, delta)
			_t -= delta
			if not _struck and _t <= RECOVER:
				_struck = true
				_punch()
			if _t <= 0.0:
				state = State.CHASE
		State.STAGGER, State.KNOCKDOWN:
			flat = flat.move_toward(Vector3.ZERO, 6.0 * delta)
			_t -= delta
			if _t <= 0.0:
				_chase()
	velocity.x = flat.x
	velocity.z = flat.z


func _chase() -> void:
	state = State.CHASE
	suspicion = 1.0
	_lost = 0.0
	# A goon coming for her in the suit means her cover's gone.
	if _nim:
		var suit: Node = _nim.get(&"suit")
		if suit:
			suit.call(&"expose")


func _punch() -> void:
	if _nim == null:
		return
	var to := _nim.global_position - global_position
	to.y = 0.0
	if to.length() <= ATTACK_RANGE + 0.3 and (-global_basis.z).angle_to(to) < deg_to_rad(70.0):
		var combat: Node = _nim.get(&"combat")
		if combat:
			combat.call(&"hurt", global_position)


func _patrol(delta: float) -> Vector3:
	if patrol.is_empty():
		_face(global_position + Vector3(-sin(_home_yaw), 0, -cos(_home_yaw)), delta)
		return _toward(_home, WALK_SPEED, delta, false) if global_position.distance_to(_home) > 0.4 else Vector3.ZERO
	var p := patrol[_patrol_i]
	if Vector2(global_position.x - p.x, global_position.z - p.z).length() < 0.4:
		_patrol_i = (_patrol_i + 1) % patrol.size()
	return _toward(patrol[_patrol_i], WALK_SPEED, delta)


func _go_home(delta: float) -> Vector3:
	var p := _home if patrol.is_empty() else patrol[_patrol_i]
	if Vector2(global_position.x - p.x, global_position.z - p.z).length() < 0.5:
		state = State.PATROL
		return Vector3.ZERO
	return _toward(p, WALK_SPEED, delta)


## Walk to where she was last seen, then look round; then give up and go back.
func _search(delta: float) -> Vector3:
	# Walk to the spot; if a wall's in the way (the spot was behind it), as near as he can get will do.
	if Vector2(global_position.x - last_seen.x, global_position.z - last_seen.z).length() > 0.6 and not is_on_wall():
		return _toward(last_seen, WALK_SPEED * 1.3, delta)
	rotation.y += 1.6 * delta
	_t -= delta
	if _t <= 0.0:
		suspicion = 0.0
		state = State.RETURN
	return Vector3.ZERO


func _toward(p: Vector3, speed: float, delta: float, face := true) -> Vector3:
	var to := Vector3(p.x - global_position.x, 0.0, p.z - global_position.z)
	if face:
		_face(p, delta)
	if to.length() < 0.2:
		return Vector3.ZERO
	return Vector3(velocity.x, 0.0, velocity.z).move_toward(to.normalized() * speed, ACCEL * delta)


func _face(p: Vector3, delta: float) -> void:
	var to := Vector3(p.x - global_position.x, 0.0, p.z - global_position.z)
	if to.length() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), clampf(TURN_SPEED * delta, 0.0, 1.0))


func _become_bound() -> void:
	state = State.BOUND
	velocity = Vector3.ZERO
	suspicion = 0.0
	if _ropes:
		_ropes.visible = true
		_note.visible = true
	_show()


# --- the greybox -----------------------------------------------------------------------------------------------------

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
	var body := MeshInstance3D.new()
	var cap_mesh := CapsuleMesh.new()
	cap_mesh.radius = RADIUS
	cap_mesh.height = HEIGHT
	body.mesh = cap_mesh
	body.position.y = HEIGHT / 2.0
	body.material_override = Look.toon(colour)
	body.material_overlay = Look.outline(AABB(Vector3(-RADIUS, -HEIGHT / 2.0, -RADIUS), Vector3(RADIUS * 2, HEIGHT, RADIUS * 2)), 0.015)
	_model.add_child(body)
	_part(Vector3(0.0, HEIGHT - 0.05, 0.0), Vector3(0.62, 0.12, 0.62), colour.darkened(0.4))     # the cap
	_part(Vector3(0.0, HEIGHT - 0.12, -0.38), Vector3(0.5, 0.05, 0.25), colour.darkened(0.4))    # its peak: his front
	_fist = _part(Vector3(0.38, 1.0, -0.2), Vector3(0.2, 0.2, 0.2), Color("c8b8a0"))
	_mark = Label3D.new()
	_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_mark.font_size = 96
	_mark.pixel_size = 0.006
	_mark.outline_size = 14
	_mark.outline_modulate = Look.INK
	_mark.position.y = HEIGHT + 0.6
	_mark.no_depth_test = true
	add_child(_mark)
	# Bound: three turns of the Rope's red, and a note for the police.
	_ropes = Node3D.new()
	_ropes.visible = false
	add_child(_ropes)
	for y: float in [0.55, 0.95, 1.35]:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = RADIUS + 0.01
		torus.outer_radius = RADIUS + 0.07
		ring.mesh = torus
		ring.position.y = y
		ring.material_override = Look.toon(Look.VELVET, 0.2)
		_ropes.add_child(ring)
	_note = Label3D.new()
	_note.text = "For the police.\nNo need to thank us."   # OWNER REVIEW
	_note.font_size = 28
	_note.pixel_size = 0.004
	_note.outline_size = 6
	_note.outline_modulate = Look.INK
	_note.modulate = Look.DECENCY_CREAM
	_note.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_note.position.y = HEIGHT + 0.25
	_note.visible = false
	add_child(_note)


func _part(at: Vector3, size: Vector3, c: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	m.mesh = box
	m.position = at
	m.material_override = Look.toon(c)
	_model.add_child(m)
	return m


## Poses the greybox for the state: a raised fist winding up, a thrown one, a stagger's lean, lying knocked down.
func _show() -> void:
	_model.rotation = Vector3.ZERO
	_model.position = Vector3.ZERO
	_fist.position = Vector3(0.38, 1.0, -0.2)
	_mark.text = ""
	match state:
		State.SUSPICIOUS, State.SEARCH:
			_mark.text = "?"
			_mark.modulate = Color("ffd84a")
		State.CHASE:
			_mark.text = "!"
			_mark.modulate = Color("ff5a4a")
		State.FIGHT:
			_mark.text = "!"
			_mark.modulate = Color("ff5a4a")
			_fist.position = Vector3(0.3, 1.75, 0.05) if _t > RECOVER else Vector3(0.15, 1.3, -0.8)
		State.STAGGER:
			_model.rotation.x = 0.35
		State.KNOCKDOWN:
			_model.rotation.x = PI / 2.0
			_model.position = Vector3(0, RADIUS, 0)
		State.KNEEL:
			_model.position = Vector3(0, -0.6, 0)
			_model.rotation.x = 0.25
		State.FROZEN:
			_mark.text = "!?"
			_mark.modulate = Color("a0d0ff")
			_model.rotation.z = 0.08   # rigid, mid-step


func _level() -> Node:
	var n := get_parent()
	while n and not n.has_method(&"spawn_player"):
		n = n.get_parent()
	return n


func _game() -> Node:
	return get_node_or_null(^"/root/Game")
