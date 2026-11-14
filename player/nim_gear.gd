class_name NimGear
extends Node
## The sisters' gear (WO-007, DESIGN.md "Gear from each world's host"), as far as it isn't movement:
##
##   - **LB** (a tap) uses the selected gear; **LB held** opens the gear wheel to pick another (WHEEL_HOLD, below):
##     - **the Scold** (Grizelda): a shout that freezes every goon within SCOLD_RANGE for SCOLD_TIME. Frozen, he can be
##       bound.
##     - **the pendant** (Lull): wakes someone in a trance at range, if she's looking at them; otherwise it's the fake
##       trance (NimSuit).
##     - **lures** (Rivet): throws a seized toy; where it lands it buzzes, and goons come to look.
##   - **RB on the ground** (Silke's rope): ties a goon who could be bound, from up to ROPE_BIND_RANGE away; or pulls
##     down something marked Pullable. (RB in the air is the swing, in Nim.)
##   - The crop (Dash) is in NimCombat: hold X. The signet (Augusta) is in NimSuit: Commands reach the powerful.
##
## A child of Nim, ticked after NimSuit and before NimCombat.

signal gear_changed(gear: String, count: int)
signal said(text: String)

const SCOLD_RANGE := 8.0
const SCOLD_TIME := 3.0
const SCOLD_COOL := 5.0
const PENDANT_RANGE := 9.0
const PENDANT_HALF_ARC := deg_to_rad(45.0)
const LURE_SPEED := 9.0
const LURE_UP := 5.0
const ROPE_BIND_RANGE := 7.0
const ROPE_BIND_TIME := 0.6
const ROPE_PULL_RANGE := 9.0
const ROPE_HALF_ARC := deg_to_rad(40.0)

var nim: Nim
## Which of the LB gear is selected ("" if she has none).
var selected := ""
## Seized toys she can throw.
var lures := 0
var _scold_cool := 0.0


func _ready() -> void:
	nim = get_parent() as Nim
	# The lures Rivet has made from seized contraband (Game flag "gear/lures", kept in the save).
	var game := get_node_or_null(^"/root/Game")
	if game:
		lures = int(game.call(&"get_flag", "gear/lures", 0))


## The gear wheel (owner, 2026-11-13: "go ahead with the wheel"): LB held past WHEEL_HOLD opens it, time slows to
## WHEEL_TIME, the stick points at a piece of gear, and letting go of LB takes it. A tap of LB uses what's taken.
## (It was D-pad left that cycled: the D-pad is the Commands' now.) While it's open the stick is the wheel's, not her
## feet's (Nim._wish).
const WHEEL_HOLD := 0.22
const WHEEL_TIME := 0.25
var wheel_open := false
## The gear she has, in the wheel's order (clockwise from the top), and the one the stick points at (-1: none).
var wheel_items: Array = []
var wheel_pick := -1
var _lb_from := -1.0   # how long LB's been down (game seconds), -1 if it's up


func tick(delta: float) -> void:
	_scold_cool -= delta
	if selected == "" or not nim.knows(selected):
		_pick(false)
	# How long LB's been held, in game seconds unslowed by the wheel's own slow-down (not the wall clock: the probes run
	# faster than real time).
	if Input.is_action_just_pressed(&"gear"):
		_lb_from = 0.0
	elif _lb_from >= 0.0:
		_lb_from += delta / maxf(Engine.time_scale, 0.01)
	if _lb_from >= 0.0 and Input.is_action_pressed(&"gear"):
		if not wheel_open and _lb_from >= WHEEL_HOLD:
			_open_wheel()
		if wheel_open:
			_point_wheel()
	elif _lb_from >= 0.0:
		# Let go: a tap uses the gear; after a hold, the wheel's pick is taken.
		_lb_from = -1.0
		if wheel_open:
			_close_wheel(true)
		else:
			_use()
	if Input.is_action_just_pressed(&"rope") and nim.is_on_floor() and nim.knows(Lessons.ROPE) and not nim.combat.busy():
		_rope_on_ground()


func _open_wheel() -> void:
	wheel_items = Lessons.LB_GEAR.filter(func(g: String) -> bool: return nim.knows(g))
	if wheel_items.is_empty():
		return
	wheel_open = true
	wheel_pick = wheel_items.find(selected)
	Engine.time_scale = WHEEL_TIME


## The stick's direction to the nearest piece of gear on the wheel (the first at the top, then clockwise).
func _point_wheel() -> void:
	var v := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if v.length() < 0.5 or wheel_items.is_empty():
		return
	var a := fposmod(atan2(v.x, -v.y), TAU)   # 0 at the top, clockwise
	var step := TAU / wheel_items.size()
	wheel_pick = int(round(a / step)) % wheel_items.size()


func _close_wheel(take: bool) -> void:
	wheel_open = false
	Engine.time_scale = 1.0
	if take and wheel_pick >= 0 and wheel_pick < wheel_items.size() and wheel_items[wheel_pick] != selected:
		selected = wheel_items[wheel_pick]
		gear_changed.emit(selected, lures)


func _exit_tree() -> void:
	if wheel_open:
		Engine.time_scale = 1.0


## A safety net, every rendered frame: if anything stops her ticking (a scene takes her, a pause) with the wheel open,
## it closes, and time's back to normal.
func _process(_delta: float) -> void:
	# (Letting go of LB is tick's to handle, so the pick's taken; this is only for when she isn't ticking at all.)
	if wheel_open and (not nim.is_physics_processing() or get_tree().paused):
		_lb_from = -1.0
		_close_wheel(false)


## The next LB gear she has (`cycle`), or just a valid one if what's selected isn't.
func _pick(cycle: bool) -> void:
	var have: Array = Lessons.LB_GEAR.filter(func(g: String) -> bool: return nim.knows(g))
	var was := selected
	if have.is_empty():
		selected = ""
	elif cycle:
		selected = have[(have.find(selected) + 1) % have.size()]
	elif not have.has(selected):
		selected = have[0]
	if selected != was or cycle:
		gear_changed.emit(selected, lures)


func _use() -> void:
	match selected:
		Lessons.SCOLD:
			_scold()
		Lessons.PENDANT:
			if not _pendant_wake():
				nim.suit.toggle_trance()
		Lessons.LURE:
			_throw_lure()


## Grizelda's Scold: every goon in range freezes where he stands.
func _scold() -> void:
	if _scold_cool > 0.0:
		return
	_scold_cool = SCOLD_COOL
	var n := 0
	for e: Node3D in nim.get_tree().get_nodes_in_group(&"enemy"):
		if e.global_position.distance_to(nim.global_position) <= SCOLD_RANGE and e.call(&"freeze", SCOLD_TIME):
			n += 1
	said.emit("\"SIT.\"" if n > 0 else "")   # OWNER REVIEW


## Lull's pendant, held up: the person in a trance she's looking at, in range and in sight, wakes.
func _pendant_wake() -> bool:
	var space := nim.get_world_3d().direct_space_state
	for p: Node3D in nim.get_tree().get_nodes_in_group(&"entranced"):
		if p.get(&"state") != 0:   # Entranced.State.ENTRANCED
			continue
		var to := p.global_position - nim.global_position
		to.y = 0.0
		if to.length() > PENDANT_RANGE or (to.length() > 0.5 and nim.facing().angle_to(to) > PENDANT_HALF_ARC):
			continue
		var q := PhysicsRayQueryParameters3D.create(nim.global_position + Vector3.UP * 1.4,
			p.global_position + Vector3.UP * 1.4, 1, [nim.get_rid(), (p as CollisionObject3D).get_rid()])
		if not space.intersect_ray(q).is_empty():
			continue
		p.call(&"wake")
		return true
	return false


## Rivet's lure: a seized toy, thrown the way she's facing (or at her lock-on target).
func _throw_lure() -> void:
	if lures <= 0:
		said.emit("No toys left to throw.")
		return
	lures -= 1
	var game := get_node_or_null(^"/root/Game")
	if game:
		game.call(&"set_flag", "gear/lures", lures)
	var dir := nim.facing()
	if nim.combat.lock:
		dir = nim.combat.lock.global_position - nim.global_position
		dir.y = 0.0
		dir = dir.normalized()
	var lure := Lure.new()
	nim.get_parent().add_child(lure)
	lure.global_position = nim.global_position + Vector3.UP * 1.4 + dir * 0.5
	lure.linear_velocity = dir * LURE_SPEED + Vector3.UP * LURE_UP
	gear_changed.emit(selected, lures)


## Silke's rope on the ground: tie the nearest goon who could be bound, at range; failing that, pull down what's in front.
func _rope_on_ground() -> void:
	if nim.suit.refuses_fight():
		nim.suit.refused()
		return
	var best: Node3D = null
	var best_d := ROPE_BIND_RANGE
	for e: Node3D in nim.get_tree().get_nodes_in_group(&"enemy"):
		if not e.call(&"bindable_from", nim.global_position):
			continue
		var d := e.global_position.distance_to(nim.global_position)
		if d < best_d and _in_front(e, ROPE_HALF_ARC * 2.0):
			best = e
			best_d = d
	if best:
		nim.combat.rope_bind(best, ROPE_BIND_TIME)
		return
	for p: Node3D in nim.get_tree().get_nodes_in_group(&"pullable"):
		if not p.get(&"pulled") and p.global_position.distance_to(nim.global_position) <= ROPE_PULL_RANGE \
				and _in_front(p, ROPE_HALF_ARC):
			p.call(&"pull", nim.global_position)
			return


func _in_front(n: Node3D, half_arc: float) -> bool:
	var to := n.global_position - nim.global_position
	to.y = 0.0
	return to.length() < 0.5 or nim.facing().angle_to(to) <= half_arc
