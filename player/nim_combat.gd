class_name NimCombat
extends Node
## Nim's fighting (WO-004, DESIGN.md "The core"): the three-hit claw combo (each hit staggers, the third knocks down),
## the Bind (Y: tie a staggered or knocked-down goon where he stands; an unaware one from behind is the takedown), the
## takedown from above (WO-005: landing on a goon, once Vesper's taught it), lock-on (LT held), and her health (a few
## hits; downed, she's back at the last checkpoint, no lives).
##
## A child of Nim. Nim calls `tick()` at the top of every physics frame and passes her movement through
## `override_flat()`. Things she can hit are in the "hittable" group with `take_hit(from, power)`, `can_be_hit()` and a
## `hit_radius`; people in trances aren't in it, so strikes pass through them.

signal health_changed(current: int, maximum: int)
signal downed

const MAX_HEALTH := 5
## Reach: from her centre to the edge of what she hits.
const STRIKE_RANGE := 1.3
const STRIKE_HALF_ARC := deg_to_rad(60.0)
## Per hit of the combo: wind-up, active, recovery (seconds). The third is heavier; the fourth is the crop.
const HITS := [[0.07, 0.08, 0.22], [0.07, 0.08, 0.22], [0.1, 0.1, 0.4], [0.12, 0.1, 0.35]]
## The crop (Dash's gear): hold X this long; it's "hit" 4, with its own reach, arc and height. It doesn't step in.
const CROP_HIT := 4
const CROP_HOLD := 0.3
const CROP_RANGE := 3.2
const CROP_HALF_ARC := deg_to_rad(30.0)
const CROP_HEIGHT := 3.2
## She steps in while winding up, if her target's further than this.
const LUNGE_SPEED := 4.0
const LUNGE_STOP := 1.1
## Without a lock, a strike turns her to the nearest goon this close and this near her line.
const SOFT_RANGE := 3.5
const SOFT_HALF_ARC := deg_to_rad(70.0)
const BIND_TIME := 0.6
const BIND_RANGE := 1.8
## The takedown from above: a goon this close (flat) to where she lands is bound, faster than a Bind.
const DROP_REACH := 1.3
const DROP_BIND_TIME := 0.4
## A strike that lands is heard this far.
const FIGHT_NOISE := 8.0
const LOCK_RANGE := 15.0
const LOCK_KEEP := 20.0
const INVULNERABLE := 1.0
const KNOCK_BACK := 5.0
const KNOCK_UP := 3.0
const STUN := 0.35
const DOWN_TIME := 1.2

var nim: Nim
## MAX_HEALTH plus Rivet's health upgrades (Game flag "upgrade/health": seized contraband, handed in at the club).
var max_health := MAX_HEALTH
var health := MAX_HEALTH
## The goon LT is locked on (or null).
var lock: Node3D

var _hit := 0            # which hit of the combo (1-3), 0 when not striking
var _phase := 0          # 0 wind-up, 1 active, 2 recovery
var _phase_t := 0.0
## Presses waiting for the next hits of the combo (a mashed X counts each press, up to the third hit).
var _queued := 0
var _x_held := 0.0
var _crop_done := false
var _crop_pending := false
var _struck := {}
var _target: Node3D
var _bind_t := 0.0
var _binding: Enemy
var _cloud: ScuffleCloud
## Closer than this, the scuffle cloud swallows Nim too.
const CLOUD_SWALLOWS := 2.2
var _invulnerable := 0.0
var _stun := 0.0
var _down := 0.0
var _marker: MeshInstance3D


func _ready() -> void:
	nim = get_parent() as Nim
	refresh_max_health()
	health = max_health
	_marker = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.12
	s.height = 0.24
	_marker.mesh = s
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(2.0, 0.3, 0.4)
	m.no_depth_test = true
	_marker.material_override = m
	_marker.top_level = true
	_marker.visible = false
	add_child(_marker)


## True while she can't move freely: striking, binding, knocked back or down.
func busy() -> bool:
	return _hit > 0 or _bind_t > 0.0 or _stun > 0.0 or _down > 0.0


func striking() -> bool:
	return _hit > 0


## Which strike of the combo is playing (1-3; the crop's is CROP_HIT), 0 when none: for her model.
func hit_number() -> int:
	return _hit


func binding() -> bool:
	return _bind_t > 0.0


func is_down() -> bool:
	return _down > 0.0


func tick(delta: float) -> void:
	_invulnerable -= delta
	_stun -= delta
	if _down > 0.0:
		_down -= delta
		if _down <= 0.0:
			downed.emit()
		return
	_update_lock()
	if _bind_t > 0.0:
		_tick_bind(delta)
		return
	if _hit > 0:
		_tick_strike(delta)
	var free := nim.state == Nim.State.MOVE or nim.state == Nim.State.BALANCE
	if not free or _stun > 0.0:
		return
	var refuses := nim.suit.refuses_fight()
	# Dash's crop: X held past CROP_HOLD lashes out at long reach once the claw is done. In the suit it's a Domme's
	# crop, not a fight: it cracks at targets, bells, switches and gulls, never at a goon (_strike_now).
	if Input.is_action_pressed(&"strike"):
		_x_held += delta
		# In the suit X is only ever the crop, tapped or held (a Domme with a crop isn't brawling): a tap was a refused
		# strike that cost Composure, and nothing said the crop wanted holding (owner, Deck clip 2026-11-13). In her
		# garb a tap's a strike, and held past CROP_HOLD it's the crop.
		var crop_now := refuses and Input.is_action_just_pressed(&"strike")
		if (_x_held >= CROP_HOLD or crop_now) and not _crop_done and nim.knows(Lessons.CROP):
			_crop_done = true
			_crop_pending = true
	else:
		_x_held = 0.0
		_crop_done = false
	if _crop_pending and _hit == 0:
		_crop_pending = false
		_queued = 0
		_start_hit(CROP_HIT)
		return
	if Input.is_action_just_pressed(&"strike"):
		if refuses:
			if not nim.knows(Lessons.CROP):
				nim.suit.refused()   # in the suit, with her cover, she won't (with the crop, a tap is: see above)
		elif _hit == 0:
			_start_hit(1)
		elif _hit < 3:
			_queued = mini(_queued + 1, 3 - _hit)
	elif Input.is_action_just_pressed(&"interact") and _hit == 0 and nim.is_on_floor() and not refuses \
			and not nim.suit.interact_used:
		_try_bind()


## Her movement this frame, given what she's doing: rooted (with a step in) while striking, still while binding or
## down, carried by the knock-back while stunned.
func override_flat(flat: Vector3) -> Vector3:
	if _down > 0.0 or _bind_t > 0.0:
		return Vector3.ZERO
	if _stun > 0.0:
		return Vector3(nim.velocity.x, 0.0, nim.velocity.z)
	if _hit > 0:
		if _phase == 0 and _hit != CROP_HIT and _target and _flat_dist(_target) > LUNGE_STOP:
			return nim.facing() * LUNGE_SPEED
		return Vector3.ZERO
	return flat


# --- the combo -------------------------------------------------------------------------------------------------------

func _start_hit(n: int) -> void:
	_hit = n
	_phase = 0
	_phase_t = HITS[n - 1][0]
	_struck.clear()
	_target = lock if lock else _soft_target()
	if _target:
		_face(_target.global_position)


func _tick_strike(delta: float) -> void:
	if _phase == 1:
		_strike_now()
	_phase_t -= delta
	if _phase_t > 0.0:
		return
	_phase += 1
	if _phase > 2:
		if _queued > 0 and _hit < 3 and _hit != CROP_HIT:
			_queued -= 1
			_start_hit(_hit + 1)
		else:
			_hit = 0
			_queued = 0
		return
	_phase_t = HITS[_hit - 1][_phase]


## Everything hittable in front of her, in reach, once per swing.
func _strike_now() -> void:
	var power := 2 if _hit == 3 else 1
	var crop := _hit == CROP_HIT
	if crop:
		var model: Node = nim.get(&"model")
		if model and model.has_method(&"crack_flash"):
			model.call(&"crack_flash")
	var reach_max := CROP_RANGE if crop else STRIKE_RANGE
	var arc := CROP_HALF_ARC if crop else STRIKE_HALF_ARC
	var tall := CROP_HEIGHT if crop else 1.8
	var spare_goons := nim.suit.refuses_fight()
	for t: Node3D in nim.get_tree().get_nodes_in_group(&"hittable"):
		if _struck.has(t) or not t.call(&"can_be_hit") or (spare_goons and t is Enemy):
			continue
		var to := t.global_position - nim.global_position
		if absf(to.y) > tall:
			continue
		to.y = 0.0
		var reach: float = to.length() - float(t.get(&"hit_radius"))
		if reach > reach_max:
			continue
		if to.length() > 0.3 and nim.facing().angle_to(to) > arc:
			continue
		_struck[t] = true
		t.call(&"take_hit", nim.global_position, power)
		nim.make_noise(FIGHT_NOISE)


## The pounce staggers what it hits and stops on it. Called by Nim while pouncing; true if it hit something.
func pounce_contact() -> bool:
	if nim.suit.refuses_fight():
		return false
	for e: Node3D in nim.get_tree().get_nodes_in_group(&"enemy"):
		if not e.call(&"can_be_hit"):
			continue
		var to := e.global_position - nim.global_position
		if absf(to.y) < 1.5 and Vector2(to.x, to.z).length() < 1.0:
			e.call(&"take_hit", nim.global_position, 1)
			return true
	return false


func _soft_target() -> Node3D:
	var best: Node3D = null
	var best_d := SOFT_RANGE
	var look := nim.facing()
	for e: Node3D in nim.get_tree().get_nodes_in_group(&"enemy"):
		if not e.call(&"can_be_hit"):
			continue
		var to := e.global_position - nim.global_position
		to.y = 0.0
		if to.length() < best_d and (to.length() < 0.5 or look.angle_to(to) < SOFT_HALF_ARC):
			best = e
			best_d = to.length()
	return best


# --- the Bind --------------------------------------------------------------------------------------------------------

func _try_bind() -> void:
	var best: Enemy = null
	var best_d := BIND_RANGE
	for e: Enemy in nim.get_tree().get_nodes_in_group(&"enemy"):
		if not e.bindable_from(nim.global_position):
			continue
		var d := _flat_dist(e)
		if d < best_d and absf(e.global_position.y - nim.global_position.y) < 1.2:
			best = e
			best_d = d
	if best == null:
		return
	_begin_bind(best, BIND_TIME)


## Silke's rope on the ground (NimGear): a goon who could be bound, tied from where she stands.
func rope_bind(e: Enemy, secs: float) -> void:
	_hit = 0
	_begin_bind(e, secs)


func _begin_bind(e: Enemy, secs: float) -> void:
	_binding = e
	_bind_t = secs
	_face(e.global_position)
	e.begin_bind()
	_start_cloud(e)


## The old-cartoon scuffle (core/scuffle_cloud.gd): a ball of dust between them for the length of the bind, which
## swallows the goon, and Nim too when she's close (not when Silke's rope ties him from afar).
func _start_cloud(e: Enemy) -> void:
	_end_cloud()
	var level := nim.get_parent()
	if level == null:
		return
	_cloud = ScuffleCloud.new()
	var near := _flat_dist(e) < CLOUD_SWALLOWS
	var at := e.global_position
	if near:
		at = (e.global_position + nim.global_position) * 0.5
	level.add_child(_cloud)
	_cloud.global_position = at
	var hide: Array = [e.get(&"_model")]
	if near and nim.get(&"model"):
		hide.append(nim.get(&"model"))
	_cloud.hide_while(hide)


func _end_cloud() -> void:
	if _cloud and is_instance_valid(_cloud):
		_cloud.poof()
	_cloud = null


## The takedown from above (Vesper's world-1 lesson; Nim calls this when she lands from high up): a goon she's landed
## on or beside, who isn't already tied, is bound at once, whatever he was doing. True if there was one.
func drop_takedown() -> bool:
	for e: Enemy in nim.get_tree().get_nodes_in_group(&"enemy"):
		if not e.can_be_hit():
			continue
		var to := e.global_position - nim.global_position
		if Vector2(to.x, to.z).length() <= DROP_REACH and to.y > -2.2 and to.y < 0.5:
			_hit = 0
			_begin_bind(e, DROP_BIND_TIME)
			return true
	return false


func _tick_bind(delta: float) -> void:
	if not is_instance_valid(_binding):
		_bind_t = 0.0
		_end_cloud()
		return
	_bind_t -= delta
	if _bind_t <= 0.0:
		_binding.finish_bind()
		_end_cloud()
		if lock == _binding:
			lock = null
		_binding = null


# --- lock-on ---------------------------------------------------------------------------------------------------------

func _update_lock() -> void:
	if not Input.is_action_pressed(&"lock_on"):
		lock = null
	elif lock == null or not is_instance_valid(lock) or not _lockable(lock) or _flat_dist(lock) > LOCK_KEEP \
			or not lock.is_in_group(nim.suit.lock_group()):
		lock = _pick_lock()
	if nim.camera:
		nim.camera.set(&"lock_target", lock)
	_marker.visible = lock != null
	if lock:
		_marker.global_position = lock.global_position + Vector3.UP * 2.5


## Locked-on things stay lockable while they can be hit (goons), or always (staff, to command).
func _lockable(n: Node) -> bool:
	return not n.has_method(&"can_be_hit") or n.call(&"can_be_hit")


## The goon (or, in the suit with her cover, the person to command) nearest the middle of the view, within range.
func _pick_lock() -> Node3D:
	var look: Vector3 = nim.camera.call(&"forward") if nim.camera else nim.facing()
	var best: Node3D = null
	var best_score := INF
	for e: Node3D in nim.get_tree().get_nodes_in_group(nim.suit.lock_group()):
		if not _lockable(e):
			continue
		var to := e.global_position - nim.global_position
		to.y = 0.0
		if to.length() > LOCK_RANGE:
			continue
		var score := look.angle_to(to) * 4.0 + to.length() / LOCK_RANGE
		if score < best_score:
			best = e
			best_score = score
	return best


# --- health ----------------------------------------------------------------------------------------------------------

## A goon's punch lands from `from`.
func hurt(from: Vector3) -> void:
	if _invulnerable > 0.0 or _down > 0.0:
		return
	health -= 1
	_invulnerable = INVULNERABLE
	_hit = 0
	if _binding:
		_binding.cancel_bind()
		_binding = null
		_bind_t = 0.0
		_end_cloud()
	health_changed.emit(health, max_health)
	var away := nim.global_position - from
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else -nim.facing()
	nim.knock(away * KNOCK_BACK + Vector3.UP * KNOCK_UP)
	if health <= 0:
		_down = DOWN_TIME
	else:
		_stun = STUN


## Back up after being downed (the level has put her at the checkpoint).
func revive() -> void:
	health = max_health
	_down = 0.0
	_stun = 0.0
	_invulnerable = INVULNERABLE
	health_changed.emit(health, max_health)


## Her cap, with Rivet's upgrades. Reached by path: probes compile this before autoloads exist.
func refresh_max_health() -> void:
	var game := get_node_or_null(^"/root/Game")
	max_health = MAX_HEALTH + (int(game.call(&"get_flag", "upgrade/health", 0)) if game else 0)


## Rivet's upgrade, given at the club: one more pip, and she's topped up.
func add_upgrade() -> void:
	refresh_max_health()
	health = max_health
	health_changed.emit(health, max_health)


func _face(p: Vector3) -> void:
	var to := p - nim.global_position
	to.y = 0.0
	if to.length() > 0.05:
		nim.rotation.y = atan2(-to.x, -to.z)


func _flat_dist(n: Node3D) -> float:
	var to := n.global_position - nim.global_position
	return Vector2(to.x, to.z).length()
