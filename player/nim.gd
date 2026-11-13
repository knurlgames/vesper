class_name Nim
extends CharacterBody3D
## Nim's movement (WO-003, DESIGN.md "The core"): run, a long low jump, crouch-sneak, climbing marked walls, hanging
## from ledges, balancing on beams and wires, and the pounce. Still a greybox capsule; the model and her animations
## replace the meshes, not this code.
##
## Climbable surfaces are marked by collision layer 2 (value 2, on top of layer 1). Beams are `Beam` nodes. Her front is
## -Z, so `rotation.y` is the way she faces and the camera's recentre puts it behind her.
##
## States: MOVE (ground and air, with the pounce as a timer), BALANCE (on a beam), CLIMB (on a marked wall), HANG (from a
## ledge), MANTLE (pulling up over an edge, scripted).

signal state_changed(state: State)

enum State { MOVE, BALANCE, CLIMB, HANG, MANTLE, CEILING, SWING }

# --- the feel (WORK_ORDERS.md WO-003: tune on the Deck) ---------------------------------------------------------------
const RUN_SPEED := 7.0
const SNEAK_SPEED := 3.0
const ACCEL := 45.0
const AIR_ACCEL := 18.0
const TURN_SPEED := 14.0
const JUMP_HEIGHT := 2.2
const APEX_TIME := 0.35
const GRAVITY := 2.0 * JUMP_HEIGHT / (APEX_TIME * APEX_TIME)
const JUMP_SPEED := 2.0 * JUMP_HEIGHT / APEX_TIME
## Let go of A while rising and gravity bites this much harder: a tap is a hop, a hold is the full jump.
const SHORT_HOP := 2.5
const MAX_FALL := 30.0
const COYOTE := 0.1
const BUFFER := 0.1
const CLIMB_SPEED := 2.5
const BALANCE_SPEED := 2.0
const POUNCE_SPEED := 9.0
const POUNCE_TIME := 0.25
const POUNCE_COOL := 0.3
## An air pounce (one per jump) is level for its whole length: it carries her across a gap a jump alone can't.
const SHIMMY_SPEED := 1.6
const MANTLE_TIME := 0.35
## How long the stick has to push at the wall while she hangs before she pulls herself up (A does it at once).
const HANG_PUSH := 0.3
## A leap off a climbable wall: out, and up.
const WALL_LEAP_OUT := 5.0
const WALL_LEAP_UP := 0.8   # times a full jump
## After leaving a wall or ledge she can't grab again for this long (no re-grabbing the thing she just let go of).
const REGRAB := 0.3
## The tallest step (a kerb, a stair) she walks up without jumping.
const STEP := 0.3

# --- stealth (WO-005) ------------------------------------------------------------------------------------------------
## How often the light at her is measured.
const LIGHT_EVERY := 0.1
## Running (faster than this) makes footsteps every STEP_EVERY, heard this far. Walking and sneaking are silent.
const RUN_NOISE_SPEED := 4.5
const STEP_EVERY := 0.35
const RUN_NOISE := 7.0
## Landing from this high makes a thump heard this far.
const LAND_NOISE_FALL := 2.5
const LAND_NOISE := 9.0
## The takedown from above: landing from at least this high next to (or on) a goon.
const DROP_TAKEDOWN_FALL := 1.5

# --- lessons and gear (WO-007) ---------------------------------------------------------------------------------------
const LAYER_CEILING := 4
## How far above her head a marked ceiling can be and still be gripped.
const CEILING_REACH := 0.45
const CEILING_SPEED := 2.0
## Head first down a marked wall.
const HEADFIRST_SPEED := 4.5
## The rope: reach to an anchor, its shortest length, how hard the stick pumps a swing, and how long the anchor she let
## go of is skipped. Her hands are this high on her.
const ROPE_REACH := 7.5
const ROPE_MIN := 1.8
const SWING_PUMP := 6.0
const ROPE_SKIP := 0.5
const HAND := 1.45

# --- her body --------------------------------------------------------------------------------------------------------
const RADIUS := 0.35
const HEIGHT := 1.7
const CROUCH_HEIGHT := 1.0
## Hanging, her feet are this far below the ledge's top (hands up on the edge).
const HANG_DROP := 1.95
## A ledge she can grab is this far above her feet: reached with her arms up.
const GRAB_MIN := 0.6
const GRAB_MAX := 2.4
const LAYER_WORLD := 1
const LAYER_CLIMB := 2

## The follow camera: "up" on the stick is the way it looks.
var camera: Node3D
## Her fighting and health (player/nim_combat.gd).
var combat: NimCombat
## Her outfits, Composure, commands and the fake trance (player/nim_suit.gd).
var suit: NimSuit
## The sisters' gear on LB and the rope on the ground (player/nim_gear.gd).
var gear: NimGear
## How lit she is (0 dark, 1 in a lamp's pool), measured a few times a second.
var light := 0.0
## The lessons and gear she has (core/lessons.gd flags -> true), filled by the level from Game's flags.
var known := {}
## Vesper's world-1 lesson: landing on a goon from above binds him at once.
var can_drop_takedown: bool:
	get:
		return knows(Lessons.TAKEDOWN_ABOVE)
	set(v):
		known[Lessons.TAKEDOWN_ABOVE] = v
var state := State.MOVE
var crouching := false

var _coyote := 0.0
var _buffer := 0.0
var _pounce := 0.0
var _pounce_cool := 0.0
var _pounce_dir := Vector3.FORWARD
var _air_pounce := true
var _pounce_in_air := false
var _light_t := 0.0
var _lights_t := 0.0
var _lights: Array = []
var _air_top := 0.0
var _step_t := 0.0
var _ceiling_y := 0.0
var _headfirst := false
## Pushing into a wall started this climb, and the stick hasn't been let go since (see _climb).
var _grab_push := false
var _grab_stick := Vector2.ZERO
## Seconds left in which a beam won't catch her (she's just dropped off one on purpose).
var _no_magnet := 0.0
var _anchor: Node3D
var _rope_len := 0.0
var _left_anchor: Node3D
var _left_t := 0.0
var _rope_mesh: MeshInstance3D
var _regrab := 0.0
var _wall_n := Vector3.BACK
var _ledge_y := 0.0
var _hang_push := 0.0
var _mantle_from := Vector3.ZERO
var _mantle_to := Vector3.ZERO
var _mantle_t := 0.0
var _beam: Beam

var _shape: CapsuleShape3D
var _col: CollisionShape3D
var _body: MeshInstance3D
var _capsule: CapsuleMesh
var _corset: MeshInstance3D
var _nose: MeshInstance3D
## Her model: both outfits' GLBs and their clips (player/nim_model.gd). `model.loaded` is false without the assets.
var model: NimModelScript
const NimModelScript := preload("res://player/nim_model.gd")


func _ready() -> void:
	add_to_group(&"player")
	collision_mask = LAYER_WORLD
	floor_snap_length = 0.25
	suit = NimSuit.new()
	suit.name = "Suit"
	add_child(suit)
	suit.outfit_changed.connect(_dress)
	gear = NimGear.new()
	gear.name = "Gear"
	add_child(gear)
	combat = NimCombat.new()
	combat.name = "Combat"
	add_child(combat)
	_shape = CapsuleShape3D.new()
	_shape.radius = RADIUS
	_shape.height = HEIGHT
	_col = CollisionShape3D.new()
	_col.shape = _shape
	_col.position.y = HEIGHT / 2.0
	add_child(_col)
	_body = MeshInstance3D.new()
	_capsule = CapsuleMesh.new()
	_capsule.radius = RADIUS
	_capsule.height = HEIGHT
	_body.mesh = _capsule
	_body.position.y = HEIGHT / 2.0
	_body.material_override = _flat(Color("6f8fa8"))
	add_child(_body)
	# A nose, so the way she faces reads in a greybox.
	var nose := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.18, 0.18, 0.3)
	nose.mesh = box
	nose.position = Vector3(0.0, HEIGHT * 0.8, -RADIUS)
	nose.material_override = _flat(Color("e8c27a"))
	add_child(nose)
	# The suit's corset: a crimson band, shown only in the suit.
	_corset = MeshInstance3D.new()
	var band := CylinderMesh.new()
	band.top_radius = RADIUS + 0.03
	band.bottom_radius = RADIUS + 0.05
	band.height = 0.32
	_corset.mesh = band
	_corset.position.y = 1.0
	_corset.material_override = Look.toon(Look.VELVET, 0.3)
	_corset.visible = false
	add_child(_corset)
	_nose = nose
	# Her model (WO-011). The greybox stays as the fallback when the GLBs aren't there.
	model = NimModelScript.new()
	model.name = "Model"
	add_child(model)
	if model.loaded:
		_body.visible = false
		_nose.visible = false
		_corset.visible = false


## The greybox in her outfit: matte charcoal for the night garb, glossy black with the corset for the suit.
## (Her model swaps itself on the same signal.)
func _dress(o: int) -> void:
	var suit_on := o == NimSuit.Outfit.SUIT
	_body.material_override = Look.toon(Color("101014") if suit_on else Color("4a4e5a"), 0.8 if suit_on else 0.0, 0.6)
	_corset.visible = suit_on and not (model and model.loaded)


## Put her somewhere, standing, facing `yaw`, with every timer cleared (spawns, resets, probes).
func teleport(at: Vector3, yaw := rotation.y) -> void:
	_set_state(State.MOVE)
	_set_crouch(false)
	global_position = at
	rotation.y = yaw
	velocity = Vector3.ZERO
	_pounce = 0.0
	_pounce_cool = 0.0
	_buffer = 0.0
	_coyote = 0.0
	_regrab = 0.0
	_air_top = at.y
	reset_physics_interpolation()


func facing() -> Vector3:
	return -global_basis.z


func knows(flag: String) -> bool:
	return flag == "" or known.get(flag, false)


func pouncing() -> bool:
	return _pounce > 0.0


## Going down a wall head first (CLIMB): her model plays the descent.
func headfirst() -> bool:
	return _headfirst


## The ledge she's hanging from (its top's height), for probes and the camera.
func ledge_height() -> float:
	return _ledge_y


## A hit sends her this way: off a wall or ledge if she's on one.
func knock(v: Vector3) -> void:
	if state != State.MOVE and state != State.BALANCE:
		_set_state(State.MOVE)
	_pounce = 0.0
	_regrab = REGRAB
	velocity = v


func _physics_process(delta: float) -> void:
	_regrab -= delta
	_no_magnet -= delta
	_buffer = BUFFER if Input.is_action_just_pressed(&"jump") else _buffer - delta
	suit.tick(delta)
	gear.tick(delta)
	combat.tick(delta)
	if combat.is_down() or suit.changing():
		# Downed, or changing at a wardrobe: she stays put.
		velocity = Vector3(0.0, velocity.y - GRAVITY * delta, 0.0)
		move_and_slide()
		_buffer = 0.0
		return
	match state:
		State.MOVE, State.BALANCE:
			_move(delta)
		State.CLIMB:
			_climb(delta)
		State.HANG:
			_hang(delta)
		State.MANTLE:
			_mantle(delta)
		State.CEILING:
			_ceiling(delta)
		State.SWING:
			_swing(delta)
	_left_t -= delta
	_draw_rope()
	_measure_light(delta)


# --- stealth: light, noise, the drop takedown ------------------------------------------------------------------------

## How lit she is, 0 to 1, a few times a second (core/light_meter.gd). Goons and lookouts see her less far in the dark.
func _measure_light(delta: float) -> void:
	_light_t -= delta
	if _light_t > 0.0:
		return
	_light_t = LIGHT_EVERY
	_lights_t -= LIGHT_EVERY
	if _lights_t <= 0.0 or _lights.is_empty():
		_lights_t = 2.0
		var level := get_parent()
		_lights = level.find_children("*", "Light3D", true, false) if level else []
	light = LightMeter.measure(global_position + Vector3.UP * 1.0, _lights, get_world_3d().direct_space_state, [get_rid()])


## A noise where she is: every goon within `radius` hears it (Enemy.hear).
func make_noise(radius: float) -> void:
	for l: Node3D in get_tree().get_nodes_in_group(&"listener"):
		if l.global_position.distance_to(global_position) <= radius:
			l.call(&"hear", global_position)


## After a move: footsteps when she runs (not when she walks or sneaks), a thump when she lands from high up, and the
## takedown from above when she lands on a goon (once Vesper's taught it).
func _sounds(delta: float, was_grounded: bool) -> void:
	var grounded := is_on_floor()
	if not grounded:
		_air_top = maxf(_air_top, global_position.y)
		return
	if not was_grounded:
		var fall := _air_top - global_position.y
		var took := fall >= DROP_TAKEDOWN_FALL and can_drop_takedown and combat.drop_takedown()
		if not took and fall >= LAND_NOISE_FALL:
			make_noise(LAND_NOISE)
	_air_top = global_position.y
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed > RUN_NOISE_SPEED and not crouching:
		_step_t -= delta
		if _step_t <= 0.0:
			_step_t = STEP_EVERY
			make_noise(RUN_NOISE)
	else:
		_step_t = 0.0


# --- running, jumping, sneaking, balancing, pouncing -----------------------------------------------------------------

func _move(delta: float) -> void:
	var grounded := is_on_floor()
	if grounded:
		_coyote = COYOTE
		_air_pounce = true
	else:
		_coyote -= delta
	var wish := _wish()
	var busy := combat.busy()
	_beam = _beam_under(wish) if grounded else null
	_set_state(State.BALANCE if _beam else State.MOVE)
	if _beam and Input.is_action_just_pressed(&"crouch") and not busy and not suit.in_suit():
		_drop_off_beam(wish)
		grounded = false

	# B crouches in the night garb; in the suit it's the strut (NimSuit.adjust), and she doesn't crouch.
	var wants_crouch := Input.is_action_pressed(&"crouch") and not suit.in_suit() and not suit.faking_trance
	_set_crouch((wants_crouch and grounded and _beam == null and not busy) or (crouching and not _can_stand()))

	_pounce_cool -= delta
	if _pounce > 0.0:
		_pounce -= delta
		if combat.pounce_contact():
			_pounce = 0.0   # it lands on him and stops
		if _pounce <= 0.0:
			_pounce_cool = POUNCE_COOL
	elif Input.is_action_just_pressed(&"pounce") and not busy and _pounce_cool <= 0.0 and _beam == null and (grounded or _air_pounce):
		_pounce = POUNCE_TIME
		_pounce_dir = wish.normalized() if wish.length() > 0.1 else facing()
		_pounce_in_air = not grounded
		if not grounded:
			_air_pounce = false
		suit.act(&"pounce")

	if _buffer > 0.0 and _coyote > 0.0 and not busy and (not crouching or _can_stand()):
		velocity.y = JUMP_SPEED
		_buffer = 0.0
		_coyote = 0.0
		_set_crouch(false)
		suit.act(&"jump")

	if _pounce > 0.0 and _pounce_in_air:
		velocity.y = 0.0   # an air pounce is level: a lunge across, not an arc
	else:
		velocity.y -= GRAVITY * delta
		if velocity.y > 0.0 and not Input.is_action_pressed(&"jump"):
			velocity.y -= GRAVITY * delta * (SHORT_HOP - 1.0)
	velocity.y = maxf(velocity.y, -MAX_FALL)

	var speed := BALANCE_SPEED if _beam else (SNEAK_SPEED if crouching else RUN_SPEED)
	var target := suit.adjust(wish, wish * speed)
	if _beam:
		var a := _beam.axis()
		target = a * target.dot(a)
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	# In the air with the stick let go she keeps her momentum (a leap off a wall carries); steering still works.
	if grounded or wish.length() > 0.1:
		flat = flat.move_toward(target, (ACCEL if grounded else AIR_ACCEL) * delta)
	if _beam:
		flat = flat.limit_length(BALANCE_SPEED)   # stepping on at a run, she slows at once
	flat = combat.override_flat(flat)
	if _pounce > 0.0:
		flat = _pounce_dir * POUNCE_SPEED
	velocity.x = flat.x
	velocity.z = flat.z
	move_and_slide()
	if grounded and is_on_wall() and flat.length() > 0.5:
		_step_up(flat * delta)
	_sounds(delta, grounded)

	if _beam:
		_hold_on_beam(_beam, delta)
	elif not is_on_floor():
		_beam_magnet()

	var face := _pounce_dir if _pounce > 0.0 else flat
	if face.length() > 0.5 and not combat.striking() and not combat.binding():
		_turn_to(face, delta)

	# The rope (RB held in the air) catches an anchor, whatever else is going on.
	if not is_on_floor() and not busy and knows(Lessons.ROPE) and Input.is_action_pressed(&"rope") and _try_swing():
		return
	if _regrab > 0.0 or _pounce > 0.0 or busy:
		return
	if knows(Lessons.CEILING):
		# Jumping up under a marked ceiling, she grips it; walking off the top of a marked wall, she goes down it head
		# first (Vesper's world-3 lesson).
		if not is_on_floor() and velocity.y > -2.0 and _try_ceiling():
			return
		if grounded and not is_on_floor() and velocity.y <= 0.5 and _try_headfirst(flat):
			return
	if wish.length() > 0.3 and _try_climb(wish):
		return
	if not is_on_floor() and velocity.y < 3.0:
		_try_ledge(wish)


## Kerbs and steps: blocked low down by something no higher than STEP, she steps up onto it instead of stopping.
func _step_up(motion: Vector3) -> void:
	var t := global_transform
	if test_move(t, Vector3.UP * STEP):
		return
	t.origin += Vector3.UP * STEP
	var ahead := motion.normalized() * maxf(motion.length(), RADIUS * 0.5)
	if test_move(t, ahead):
		return
	t.origin += ahead
	var hit := KinematicCollision3D.new()
	if not test_move(t, Vector3.DOWN * (STEP + 0.05), hit) or hit.get_normal().y < 0.7:
		return
	global_position = t.origin + hit.get_travel()


## The stick (or WASD) on the ground, relative to the camera.
func _wish() -> Vector3:
	var v := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var fwd: Vector3 = camera.forward() if camera else Vector3.FORWARD
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	return (right * v.x - fwd * v.y).limit_length(1.0)


func _turn_to(dir: Vector3, delta: float) -> void:
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), clampf(TURN_SPEED * delta, 0.0, 1.0))


func _face(dir: Vector3) -> void:
	rotation.y = atan2(-dir.x, -dir.z)


# --- crouch ----------------------------------------------------------------------------------------------------------

func _set_crouch(on: bool) -> void:
	if on == crouching:
		return
	crouching = on
	var h := CROUCH_HEIGHT if on else HEIGHT
	_shape.height = h
	_col.position.y = h / 2.0
	_capsule.height = h
	_body.position.y = h / 2.0


## Room to stand up: a crouched Nim under a low ceiling stays crouched.
func _can_stand() -> bool:
	if not crouching:
		return true
	return not test_move(global_transform, Vector3.UP * (HEIGHT - CROUCH_HEIGHT))


# --- beams -----------------------------------------------------------------------------------------------------------

## Where two beams cross (the pier's stringers over its cross-beams), she takes the one the stick runs along; with the
## stick let go, she stays on the one she was on.
func _beam_under(wish := Vector3.ZERO) -> Beam:
	var best: Beam = null
	var best_fit := -1.0
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		# Under her feet now: the last slide's contacts outlive a teleport by a frame.
		if c.get_normal().y > 0.7 and c.get_collider() is Beam and c.get_position().distance_to(global_position) < 0.6:
			var b: Beam = c.get_collider()
			var fit := absf(b.axis().dot(wish)) if wish.length() > 0.3 else (1.0 if b == _beam else 0.0)
			if fit > best_fit:
				best = b
				best_fit = fit
	# The contacts name only one of two crossing beams: look for another crossing right here that runs with the stick.
	if best and wish.length() > 0.3:
		for b: Beam in get_tree().get_nodes_in_group(&"beam"):
			if b == best or not b.spans(global_position):
				continue
			var on := b.closest(global_position)
			var off := Vector2(global_position.x - on.x, global_position.z - on.z).length()
			if off < 0.3 and absf(global_position.y - on.y) < 0.15 and absf(b.axis().dot(wish)) > best_fit + 0.2:
				best = b
				best_fit = absf(b.axis().dot(wish))
	return best


## On a beam she keeps to its line (the tail does the work).
func _hold_on_beam(beam: Beam, delta: float) -> void:
	var on := beam.closest(global_position)
	var k := clampf(14.0 * delta, 0.0, 1.0)
	global_position.x = lerpf(global_position.x, on.x, k)
	global_position.z = lerpf(global_position.z, on.z, k)


## B on a beam: she lets go and drops off its side, the way down onto a goon below it (the takedown from above). The
## stick picks the side; with it let go, her right.
func _drop_off_beam(wish: Vector3) -> void:
	var dir := Vector3(wish.x, 0.0, wish.z)
	if dir.length() < 0.3:
		dir = facing().cross(Vector3.UP)
	dir = dir.normalized()
	# Step clear of every beam under her (at a crossing, both), toward the stick's side of each.
	var p := global_position
	for i in 3:
		var on := _beam_at(p)
		if on == null:
			break
		var across := on.axis().cross(Vector3.UP).normalized()
		if across.dot(dir) < 0.0:
			across = -across
		var line := on.closest(p)
		var off := Vector3(p.x - line.x, 0.0, p.z - line.z).dot(across)
		p += across * (on.width / 2.0 + RADIUS + 0.05 - off)
	global_position = p
	velocity = Vector3.ZERO
	_no_magnet = 0.5
	_beam = null
	_set_state(State.MOVE)


## A beam she'd be standing on at `p` (its top at her feet, its line within her reach), or null.
func _beam_at(p: Vector3) -> Beam:
	for b: Beam in get_tree().get_nodes_in_group(&"beam"):
		if not b.spans(p):
			continue
		var on := b.closest(p)
		if absf(p.y - on.y) < 0.2 and Vector2(p.x - on.x, p.z - on.z).length() < b.width / 2.0 + RADIUS:
			return b
	return null


## Falling close above a beam pulls her onto its line, so a wire a few centimetres wide is catchable.
func _beam_magnet() -> void:
	if velocity.y > 0.0 or _no_magnet > 0.0:
		return
	for b: Beam in get_tree().get_nodes_in_group(&"beam"):
		if not b.spans(global_position):
			continue
		var on := b.closest(global_position)
		var above := global_position.y - on.y
		var off := Vector2(global_position.x - on.x, global_position.z - on.z).length()
		# Up to 20 cm below the top still counts: stepping off a platform onto a beam at a run, a little off its line,
		# she's already dropping by the time she's over it.
		if above > -0.2 and above < 0.7 and off < 0.5:
			global_position.x = on.x
			global_position.z = on.z
			if above < 0.0:
				global_position.y = on.y
				velocity.y = 0.0
			return


# --- climbing --------------------------------------------------------------------------------------------------------

func _ray(from: Vector3, to: Vector3, mask := LAYER_WORLD) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, mask, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(q)


## Pushing into a marked wall (on the ground or in the air) starts a climb.
func _try_climb(wish: Vector3) -> bool:
	var d := Vector3(wish.x, 0.0, wish.z).normalized()
	var chest := global_position + Vector3.UP * 1.0
	var hit := _ray(chest, chest + d * (RADIUS + 0.4), LAYER_CLIMB)
	if hit.is_empty():
		return false
	var n: Vector3 = hit.normal
	n.y = 0.0
	if n.length() < 0.7 or d.dot(-n.normalized()) < 0.5:
		return false
	_wall_n = n.normalized()
	var p: Vector3 = hit.position + _wall_n * (RADIUS + 0.03)
	global_position = Vector3(p.x, global_position.y, p.z)
	velocity = Vector3.ZERO
	_face(-_wall_n)
	_set_crouch(false)
	_set_state(State.CLIMB)
	_grab_push = true
	_grab_stick = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	return true


func _climb(delta: float) -> void:
	if Input.is_action_just_pressed(&"jump"):
		_buffer = 0.0
		_leave_wall(_wall_n * WALL_LEAP_OUT + Vector3.UP * JUMP_SPEED * WALL_LEAP_UP)
		_face(_wall_n)
		return
	if Input.is_action_just_pressed(&"crouch"):
		_leave_wall(_wall_n * 1.5)
		return
	var v := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	# The push that put her on the wall means "up" until the stick's let go: the grab reads the stick through the
	# camera, the climb reads it raw, and with the camera facing her, "toward the wall" is "down" raw. Without this she
	# grabbed and let go every frame, flickering at the foot of the wall.
	if _grab_push:
		if v.length() < 0.3 or _grab_stick.length() < 0.3 or v.normalized().dot(_grab_stick.normalized()) < 0.8:
			_grab_push = false
		elif not _headfirst:
			v = Vector2(0.0, -1.0)
	var right := (-_wall_n).cross(Vector3.UP)
	var before := global_position
	# Head first (she came over the top of it), "up" on the stick takes her down the wall, and fast.
	var climb_up := v.y if _headfirst else -v.y
	var vertical := climb_up * (HEADFIRST_SPEED if _headfirst and climb_up < 0.0 else CLIMB_SPEED)
	velocity = right * v.x * CLIMB_SPEED + Vector3.UP * vertical - _wall_n * 0.5
	move_and_slide()

	# Back down at the bottom.
	if is_on_floor() and climb_up < -0.3:
		_set_state(State.MOVE)
		return
	# Still on the wall? Off its side edge she stops; keep her at arm's length from it.
	var chest := global_position + Vector3.UP * 1.0
	var hit := _ray(chest, chest - _wall_n * (RADIUS + 0.5), LAYER_CLIMB)
	if hit.is_empty():
		global_position = Vector3(before.x, global_position.y, before.z)
		chest = global_position + Vector3.UP * 1.0
		hit = _ray(chest, chest - _wall_n * (RADIUS + 0.5), LAYER_CLIMB)
		if hit.is_empty():
			_leave_wall(Vector3.ZERO)
			return
	var n: Vector3 = hit.normal
	n.y = 0.0
	if n.length() > 0.7:
		_wall_n = n.normalized()
	var p: Vector3 = hit.position + _wall_n * (RADIUS + 0.03)
	global_position.x = p.x
	global_position.z = p.z
	# At the top: the head's above the wall. Pushing up pulls her over; otherwise she holds there.
	var head := global_position + Vector3.UP * 1.6
	if _ray(head, head - _wall_n * (RADIUS + 0.5), LAYER_CLIMB).is_empty():
		if climb_up > 0.3 and _try_mantle(global_position.y + 0.9, global_position.y + 2.2):
			return
		global_position.y = minf(global_position.y, before.y)


func _leave_wall(v: Vector3) -> void:
	velocity = v
	_regrab = REGRAB
	_set_state(State.MOVE)


# --- ledges ----------------------------------------------------------------------------------------------------------

## Falling (or at the top of a jump) toward a ledge she can reach: she catches it and hangs.
func _try_ledge(wish: Vector3) -> bool:
	var d := Vector3(velocity.x, 0.0, velocity.z)
	if wish.length() > 0.2:
		d = wish
	if d.length() < 0.1:
		return false
	d = d.normalized()
	var chest := global_position + Vector3.UP * 1.3
	var hit := _ray(chest, chest + d * (RADIUS + 0.35))
	if hit.is_empty():
		return false
	var n: Vector3 = hit.normal
	if absf(n.y) > 0.3:
		return false
	n.y = 0.0
	n = n.normalized()
	var top := _ledge_top(hit.position, n, global_position.y + GRAB_MIN, global_position.y + GRAB_MAX)
	if is_nan(top):
		return false
	_wall_n = n
	_ledge_y = top
	var p: Vector3 = hit.position + n * (RADIUS + 0.03)
	global_position = Vector3(p.x, top - HANG_DROP, p.z)
	velocity = Vector3.ZERO
	_face(-n)
	_hang_push = 0.0
	_set_state(State.HANG)
	return true


## The height of a ledge's top just behind a wall point, between `lo` and `hi`; NAN if there's none, or if the wall goes
## on up (a ray starting inside it hits nothing).
func _ledge_top(wall_point: Vector3, n: Vector3, lo: float, hi: float) -> float:
	var over := wall_point - n * 0.25
	var down := _ray(Vector3(over.x, hi + 0.3, over.z), Vector3(over.x, lo, over.z))
	if down.is_empty() or down.normal.y < 0.7:
		return NAN
	return down.position.y


func _hang(delta: float) -> void:
	var wish := _wish()
	var toward := wish.dot(-_wall_n)
	if Input.is_action_just_pressed(&"crouch") or toward < -0.5:
		_leave_wall(_wall_n * 1.0)
		return
	_hang_push = _hang_push + delta if toward > 0.5 else 0.0
	if Input.is_action_just_pressed(&"jump") or _hang_push > HANG_PUSH:
		_buffer = 0.0
		if _try_mantle(_ledge_y - 0.3, _ledge_y + 0.3):
			return
	# Shimmy along the edge, only as far as the ledge goes.
	var right := (-_wall_n).cross(Vector3.UP)
	var side := wish.dot(right)
	if absf(side) > 0.3:
		var next := global_position + right * signf(side) * SHIMMY_SPEED * delta
		var chest := next + Vector3.UP * 1.3
		var hit := _ray(chest, chest - _wall_n * (RADIUS + 0.4))
		if not hit.is_empty():
			var top := _ledge_top(hit.position, _wall_n, _ledge_y - 0.15, _ledge_y + 0.15)
			if not is_nan(top):
				global_position = next
	velocity = Vector3.ZERO


# --- pulling up ------------------------------------------------------------------------------------------------------

## Up and over the edge in front of her, onto a top between `lo` and `hi`, if she'd fit standing there.
func _try_mantle(lo: float, hi: float) -> bool:
	var at := global_position - _wall_n * (RADIUS + 0.05)
	var top := _ledge_top(at + Vector3.UP * 0.0, _wall_n, lo, hi)
	if is_nan(top):
		return false
	var to := global_position - _wall_n * (RADIUS * 2.0 + 0.2)
	to.y = top + 0.02
	var space := PhysicsShapeQueryParameters3D.new()
	space.shape = _shape
	space.transform = Transform3D(Basis.IDENTITY, to + Vector3.UP * (HEIGHT / 2.0 + 0.05))
	space.collision_mask = LAYER_WORLD
	space.exclude = [get_rid()]
	if not get_world_3d().direct_space_state.intersect_shape(space, 1).is_empty():
		return false
	_mantle_from = global_position
	_mantle_to = to
	_mantle_t = 0.0
	velocity = Vector3.ZERO
	_set_state(State.MANTLE)
	return true


func _mantle(delta: float) -> void:
	_mantle_t += delta / MANTLE_TIME
	var t := clampf(_mantle_t, 0.0, 1.0)
	# Up first, then over: the body rises along the wall, then steps onto the top.
	var up := clampf(t / 0.6, 0.0, 1.0)
	var over := clampf((t - 0.5) / 0.5, 0.0, 1.0)
	var flat := _mantle_from.lerp(_mantle_to, over)
	global_position = Vector3(flat.x, lerpf(_mantle_from.y, _mantle_to.y, up), flat.z)
	if t >= 1.0:
		velocity = Vector3.ZERO
		_regrab = REGRAB
		_set_state(State.MOVE)


# --- misc ------------------------------------------------------------------------------------------------------------

func _set_state(s: State) -> void:
	if s == state:
		return
	state = s
	if s != State.CLIMB:
		_headfirst = false
	if s != State.SWING:
		_anchor = null
	# Upside down under a ceiling or head first down a wall: the greybox flips.
	_body.rotation.x = PI if s == State.CEILING or (s == State.CLIMB and _headfirst) else 0.0
	state_changed.emit(s)


# --- the ceiling crawl and the headfirst descent (Vesper's world-3 lesson) -------------------------------------------

## Her head just under a marked ceiling (layer 3, value 4): she grips it and hangs, back to the ground.
func _try_ceiling() -> bool:
	var head := global_position + Vector3.UP * HEIGHT
	var hit := _ray(head - Vector3.UP * 0.1, head + Vector3.UP * CEILING_REACH, LAYER_CEILING)
	if hit.is_empty() or hit.normal.y > -0.7:
		return false
	_ceiling_y = hit.position.y
	global_position.y = _ceiling_y - HEIGHT - 0.02
	velocity = Vector3.ZERO
	_set_crouch(false)
	_set_state(State.CEILING)
	return true


func _ceiling(delta: float) -> void:
	if Input.is_action_just_pressed(&"jump") or Input.is_action_just_pressed(&"crouch"):
		_buffer = 0.0
		velocity = Vector3.ZERO
		_regrab = REGRAB
		_set_state(State.MOVE)
		return
	var wish := _wish()
	var before := global_position
	velocity = wish * CEILING_SPEED
	move_and_slide()
	global_position.y = _ceiling_y - HEIGHT - 0.02
	# Only as far as the ceiling goes.
	var head := global_position + Vector3.UP * HEIGHT
	var hit := _ray(head - Vector3.UP * 0.1, head + Vector3.UP * CEILING_REACH, LAYER_CEILING)
	if hit.is_empty():
		global_position = before
	if wish.length() > 0.2:
		_turn_to(wish, delta)


## She's walked off the top of a marked wall: instead of falling, she grips its face and goes down it head first.
func _try_headfirst(moving: Vector3) -> bool:
	if moving.length() < 0.5:
		return false
	var dir := Vector3(moving.x, 0.0, moving.z).normalized()
	var from := global_position + dir * 0.7 + Vector3.DOWN * 0.6
	var hit := _ray(from, from - dir * 1.6, LAYER_CLIMB)
	if hit.is_empty():
		return false
	var n: Vector3 = hit.normal
	n.y = 0.0
	if n.length() < 0.7 or n.normalized().dot(dir) < 0.7:
		return false
	_wall_n = n.normalized()
	var p: Vector3 = hit.position + _wall_n * (RADIUS + 0.03)
	# Low enough that her chest is on the face, below the top she came over (she's head down; her body runs up it).
	global_position = Vector3(p.x, hit.position.y - 1.2, p.z)
	velocity = Vector3.ZERO
	_face(-_wall_n)
	_headfirst = true
	_set_state(State.CLIMB)
	return true


# --- the rope: a swing from an anchor (Silke's gear) -----------------------------------------------------------------

## In the air with RB held: the best anchor in reach above her (ahead of her by preference), not the one she's just
## let go of. A pendulum, always taut: the catch keeps her speed and turns it along the arc (a slack rope stopped
## swings dead in Nine Lives).
func _try_swing() -> bool:
	var hand := global_position + Vector3.UP * HAND
	var going := Vector3(velocity.x, 0.0, velocity.z)
	var best: Node3D = null
	var best_score := INF
	for a: Node3D in get_tree().get_nodes_in_group(&"tether_anchor"):
		if a == _left_anchor and _left_t > 0.0:
			continue
		var to := a.global_position - hand
		if to.y < 0.5 or to.length() > ROPE_REACH:
			continue
		var flat := Vector3(to.x, 0.0, to.z)
		var ahead := flat.normalized().dot(going.normalized()) if going.length() > 0.5 and flat.length() > 0.1 else 0.0
		var score := to.length() - ahead * 4.0
		if score < best_score:
			best = a
			best_score = score
	if best == null:
		return false
	_anchor = best
	var r := hand - best.global_position
	_rope_len = maxf(r.length(), ROPE_MIN)
	# Keep her speed, turned along the arc.
	var radial := r.normalized()
	var speed := velocity.length()
	var along := velocity - radial * velocity.dot(radial)
	velocity = along.normalized() * speed if along.length() > 0.1 else Vector3.ZERO
	_set_crouch(false)
	_set_state(State.SWING)
	return true


func _swing(delta: float) -> void:
	if not is_instance_valid(_anchor):
		_set_state(State.MOVE)
		return
	if Input.is_action_just_pressed(&"jump"):
		# A jump off the rope is a full jump on top of the swing.
		_buffer = 0.0
		_let_go()
		velocity.y = maxf(velocity.y, 0.0) + JUMP_SPEED
		return
	if not Input.is_action_pressed(&"rope"):
		_let_go()
		return
	velocity.y -= GRAVITY * delta
	velocity += _wish() * SWING_PUMP * delta
	var hand := global_position + Vector3.UP * HAND
	var next := hand + velocity * delta
	var r := next - _anchor.global_position
	if r.length() > _rope_len:
		next = _anchor.global_position + r.normalized() * _rope_len
	var radial := (next - _anchor.global_position).normalized()
	var out := velocity.dot(radial)
	if out > 0.0:
		velocity -= radial * out
	var hit := move_and_collide(next - hand)
	if hit:
		velocity = velocity.slide(hit.get_normal())
		if hit.get_normal().y > 0.7:
			_let_go()   # swung onto a floor: she's down
			return
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if flat.length() > 0.5:
		_turn_to(flat, delta)


func _let_go() -> void:
	_left_anchor = _anchor
	_left_t = ROPE_SKIP
	_set_state(State.MOVE)


func _draw_rope() -> void:
	if state != State.SWING or not is_instance_valid(_anchor):
		if _rope_mesh:
			_rope_mesh.visible = false
		return
	if _rope_mesh == null:
		_rope_mesh = MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.025
		c.bottom_radius = 0.025
		c.height = 1.0
		c.radial_segments = 6
		_rope_mesh.mesh = c
		_rope_mesh.material_override = Look.toon(Look.VELVET, 0.2)
		_rope_mesh.top_level = true
		add_child(_rope_mesh)
	var hand := global_position + Vector3.UP * HAND
	var a := _anchor.global_position
	_rope_mesh.visible = true
	_rope_mesh.global_position = (hand + a) / 2.0
	_rope_mesh.scale = Vector3(1.0, hand.distance_to(a), 1.0)
	var up := (a - hand).normalized()
	var side := up.cross(Vector3.FORWARD) if absf(up.dot(Vector3.FORWARD)) < 0.9 else up.cross(Vector3.RIGHT)
	_rope_mesh.global_basis = Basis(side.normalized(), up, side.normalized().cross(up)).scaled(Vector3(1.0, hand.distance_to(a), 1.0))


func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m
