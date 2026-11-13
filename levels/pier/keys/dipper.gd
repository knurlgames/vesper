extends "res://levels/pier/keys/pier_key.gd"
## Key 9: the Big Dipper chase (worlds/01_PIER.md, "The set piece"). The courier (a stoat) is at the coaster's station
## with Laffer's ledger. Nim comes near; he jumps a car, and it climbs the first hill.
##   - She follows on the maintenance catwalk: up beside the lift hill, then across the coaster's high platforms (gaps
##     to leap, beams to tail-walk, gulls perched on them, marked struts to climb back up if she falls).
##   - On the switch tower at the loop she cracks the points with the crop; next time round, his car turns onto the
##     maintenance spur.
##   - The spur car stalls at the crest of its last drop until she's on the platform beside it, then tips over and
##     rolls down slowly. She jumps (or pounces) into the car and binds him before it reaches the bottom.
##   - Miss him and he laughs and goes round again (crack the points again).
## Punchline: the ride photo, him screaming and her with her eyes shut. She buys it.
##
## The track is drawn by the level (Pier.track); the walkable parts are the catwalk's beams and platforms here. The car
## is an AnimatableBody3D moved along the track in the physics step, so she can stand in it.

## The circuit, from the station going south (a closed loop). BRANCH is where the spur leaves it.
const MAIN := [Vector3(27.5, 1.4, -160), Vector3(27.5, 1.4, -172), Vector3(27.5, 18, -198), Vector3(27.5, 18, -204),
	Vector3(27.5, 3, -222), Vector3(22, 3, -235), Vector3(12, 4, -241), Vector3(4, 6, -236), Vector3(0, 9, -224),
	Vector3(0, 9, -212), Vector3(6, 7, -200), Vector3(16, 5, -192), Vector3(34, 3, -188), Vector3(36, 2, -172),
	Vector3(34, 1.4, -156), Vector3(30, 1.4, -154), Vector3(27.5, 1.4, -156)]
const BRANCH := 9
## The maintenance spur: from the branch to the crest (where the car stalls, beside the middle of P4), a crawl to the
## lip of the last drop (still beside P4), down it to the end.
const SPUR := [Vector3(0, 9, -212), Vector3(-6, 10, -204), Vector3(-8, 10, -201.5), Vector3(-8, 10, -199.5),
	Vector3(-8, 10, -194.5), Vector3(-8, 2.4, -178), Vector3(-8, 1.4, -170)]
const CREST := 3
## Where she sets it off: the station's platform.
const STATION := Vector3(21.0, 1.4, -164.0)
const TRIGGER_RANGE := 7.0
## The courier waits on the platform beside the parked car.
const COURIER_WAIT := Vector3(25.8, 1.4, -161.0)
## The catwalk's platforms (centre, size): the lift hill's top, two strut towers, the switch tower, and the one beside
## the spur's crest.
const P0 := [Vector3(25.3, 18.0, -202.0), Vector3(2.6, 0.4, 10.0)]
const P1 := [Vector3(14.0, 15.5, -210.0), Vector3(3.0, 0.4, 3.0)]
const P2 := [Vector3(6.5, 13.0, -220.0), Vector3(3.0, 0.4, 3.0)]
const P3 := [Vector3(2.8, 12.0, -226.5), Vector3(3.6, 0.4, 4.0)]
const P4 := [Vector3(-5.5, 10.4, -197.5), Vector3(2.2, 0.4, 7.0)]
const SWITCH_AT := Vector3(4.1, 13.1, -228.0)

## Car speeds: the lift hill, the flat, the fastest drop; on the spur, and down its last drop (brakes on).
@export var lift_speed := 3.0
@export var flat_speed := 5.0
@export var drop_speed := 10.0
@export var spur_speed := 4.0
@export var last_drop_speed := 2.0

enum Phase { WAITING, RUNNING, HANGING, DROPPING, CAUGHT, DONE }

var phase := Phase.WAITING
var car: AnimatableBody3D
## False once the Meshy car is drawn: the parts are collision only.
var _drawn := true
const CAR_MODEL := "res://assets/props/coaster_car.glb"
var courier: Node3D
var points: CropTarget
var diverted := false
var on_spur := false
var _d := 0.0
var _main_cum: Array[float] = []
var _spur_cum: Array[float] = []
var _t := 0.0
var _hang_said := false


func _ready() -> void:
	pier = get_parent()
	_build()
	super()


func _setup() -> void:
	_main_cum = _cumulative(MAIN, true)
	_spur_cum = _cumulative(SPUR, false)
	_make_car()
	if flag("dipper_done"):
		phase = Phase.DONE
		_d = _spur_cum[_spur_cum.size() - 1]
		on_spur = true
		_place_car()
		_courier_state(Enemy.State.BOUND)
		award(&"pier_09", Vector3(-5.3, 1.4, -171.0))
		return
	_place_car()
	courier.reparent(self)
	courier.global_position = COURIER_WAIT
	courier.rotation.y = PI / 2.0
	_make_points()


# --- the build (before the level batches its meshes) -----------------------------------------------------------------

func _build() -> void:
	for i in MAIN.size():
		pier.call(&"track", MAIN[i], MAIN[(i + 1) % MAIN.size()])
	for i in SPUR.size() - 1:
		pier.call(&"track", SPUR[i], SPUR[i + 1])
	var plank := Look.painted(Look.Pattern.PLANKS, Color("54443a"), Color("1a120e"), {"wet": 0.4})
	var climb := Look.painted(Look.Pattern.BRICK, Color("4f8a5a"), Color("173020"), {"wet": 0.5, "scale": 1.6})
	var white := Look.toon(Color("e8e0d0"), 0.2)
	var beam_mat := Look.toon(Color("6a5040"))
	for p: Array in [P0, P1, P2, P3, P4]:
		var c: Vector3 = p[0]
		var s: Vector3 = p[1]
		pier.call(&"solid", c - Vector3(0, s.y / 2.0, 0), s, plank)
		# A marked strut at one corner, deck to platform top: the way back up after a fall.
		var corner := c + Vector3(s.x / 2.0 + 0.3, 0, s.z / 2.0 - 0.3)
		pier.call(&"solid", Vector3(corner.x, c.y / 2.0, corner.z), Vector3(0.6, c.y, 0.6), climb, 1 | 2)
		# And legs under the other corners (drawn only).
		for k: Vector2 in [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1)]:
			pier.call(&"deco", Vector3(c.x + k.x * (s.x / 2.0 - 0.15), (c.y - s.y) / 2.0, c.z + k.y * (s.z / 2.0 - 0.15)),
				Vector3(0.18, c.y - s.y, 0.18), white)
	# The catwalk: up beside the lift hill to P0; P0 west to the gap before P1; P1 down to P2; (a gap to P3); P3 to P4.
	_beam(Vector3(25.8, 1.4, -168.0), Vector3(25.8, 18.0, -197.0), 0.3, beam_mat)   # ends flush at P0's edge
	_beam(Vector3(24.0, 18.0, -205.0), Vector3(17.5, 18.0, -205.0), 0.25, beam_mat)
	_beam(Vector3(13.2, 15.5, -211.0), Vector3(7.0, 13.0, -219.6), 0.25, beam_mat)
	_beam(Vector3(1.2, 12.0, -224.8), Vector3(-5.2, 10.4, -199.6), 0.25, beam_mat)
	# The points' post on the switch tower.
	pier.call(&"solid", Vector3(SWITCH_AT.x, 12.5, SWITCH_AT.z), Vector3(0.15, 1.0, 0.15), white)
	# Gulls on two of the struts' platforms.
	for g: Array in [[Vector3(15.2, 15.5, -211.2), PI / 2.0], [Vector3(7.7, 13.0, -218.8), PI]]:
		var bird := Lookout.new()
		bird.name = "Gull_dipper_%d" % get_child_count()
		bird.position = g[0]
		bird.perch_height = 1.0
		bird.look_body = "gull_lookout"
		bird.watch_yaw = g[1]
		add_child(bird)
	# The spur's end: a maintenance platform beside it.
	pier.call(&"solid", Vector3(-5.3, 0.7, -171.0), Vector3(2.6, 1.4, 6.0), plank)


## A walkable beam from a to b (its top surface on the line), tilted to follow it.
func _beam(a: Vector3, b: Vector3, width: float, mat: Material) -> Beam:
	var bm := Beam.new()
	bm.length = a.distance_to(b)
	bm.width = width
	bm.material = mat
	var x := (b - a).normalized()
	var z := x.cross(Vector3.UP).normalized()
	var y := z.cross(x)
	bm.transform = Transform3D(Basis(x, y, z), (a + b) / 2.0)
	add_child(bm)
	return bm


# --- the car and the courier -----------------------------------------------------------------------------------------

func _make_car() -> void:
	car = AnimatableBody3D.new()
	car.name = "DipperCar"
	car.sync_to_physics = true
	add_child(car)
	# The Meshy car (WO-014 step 6) when it's there: the boxes below then only give it collision. Its nose is the GLB's
	# -X (the headlamp); the car's is -Z.
	if ResourceLoader.exists(CAR_MODEL):
		var model: Node3D = (load(CAR_MODEL) as PackedScene).instantiate()
		model.rotation.y = -PI / 2.0
		Look.dress(model, 0.012, 0.3, 1.0)
		car.add_child(model)
		_drawn = false
	var red := Look.toon(Color("c8303a"), 0.4)
	var gold := Look.toon(Look.BRASS, 0.6)
	_part(Vector3(0, 0.25, 0), Vector3(1.4, 0.2, 2.2), red)
	_part(Vector3(0, 0.6, -1.05), Vector3(1.4, 0.5, 0.12), red)     # the nose
	_part(Vector3(0, 0.6, 1.05), Vector3(1.4, 0.5, 0.12), red)      # the back
	for sx: float in [-0.66, 0.66]:
		_part(Vector3(sx, 0.55, 0), Vector3(0.1, 0.4, 2.2), red)
	_part(Vector3(0, 0.55, -0.55), Vector3(1.2, 0.4, 0.4), gold)   # the front seat's back
	if EnemyModel.exists("stoat_courier"):
		var m := EnemyModel.new()
		m.body = "stoat_courier"
		courier = m
	else:
		var cap := MeshInstance3D.new()
		var mesh := CapsuleMesh.new()
		mesh.radius = 0.3
		mesh.height = 1.4
		cap.mesh = mesh
		cap.position.y = 0.7
		cap.material_override = Look.toon(Color("a07a5a"))
		courier = Node3D.new()
		courier.add_child(cap)
	courier.name = "Courier"
	car.add_child(courier)
	courier.position = Vector3(0, 0.35, -0.2)


func _part(at: Vector3, size: Vector3, mat: Material) -> void:
	if _drawn:
		var m := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = size
		m.mesh = box
		m.position = at
		m.material_override = mat
		car.add_child(m)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position = at
	car.add_child(col)


func _make_points() -> void:
	if points and is_instance_valid(points):
		points.queue_free()
	points = CropTarget.new()
	points.name = "DipperPoints"
	points.kind = CropTarget.Kind.SWITCH
	points.position = SWITCH_AT
	add_child(points)
	points.hit.connect(_on_points)


func _courier_state(state: int) -> void:
	if courier is EnemyModel:
		(courier as EnemyModel).show_state(state, _t, 0.0, 1.0)


# --- the chase -------------------------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if car == null:
		return
	_t += delta
	match phase:
		Phase.WAITING:
			_courier_state(Enemy.State.PATROL)
			if near(STATION, TRIGGER_RANGE):
				_board()
		Phase.RUNNING:
			_courier_state(Enemy.State.PATROL)
			_drive(delta)
		Phase.HANGING:
			if near(_spur_point(_spur_cum[CREST]), 4.5):
				phase = Phase.DROPPING
				Hud.caption("Courier", "It's moving! IT'S MOVING!", 2.0)
			_check_caught()
		Phase.DROPPING:
			_d += last_drop_speed * delta
			_place_car()
			_check_caught()
			if phase == Phase.DROPPING and _d >= _spur_cum[_spur_cum.size() - 1]:
				_missed()
		Phase.CAUGHT:
			_d = minf(_d + last_drop_speed * delta, _spur_cum[_spur_cum.size() - 1])
			_place_car()


func _board() -> void:
	phase = Phase.RUNNING
	Hud.caption("Courier", "The Rope?! You can't have the ledger! It's Mr. Laffer's ledger!", 3.0)
	courier.reparent(car)
	courier.position = Vector3(0, 0.35, -0.2)
	courier.rotation = Vector3.ZERO


## Round the circuit; past the branch with the points switched, onto the spur; at the crest, stall.
func _drive(delta: float) -> void:
	if on_spur:
		_d += spur_speed * delta
		if _d >= _spur_cum[CREST]:
			_d = _spur_cum[CREST]
			phase = Phase.HANGING
			Hud.caption("Courier", "It's stopped! Why's it stopped?!", 2.5)
		_place_car()
		return
	var total: float = _main_cum[_main_cum.size() - 1]
	var before := _d
	_d += _main_speed(_d) * delta
	var branch: float = _main_cum[BRANCH]
	if diverted and before < branch and _d >= branch:
		on_spur = true
		_d = _d - branch
		Hud.caption("Courier", "Why are we going this way?!", 2.0)
	elif _d >= total:
		_d -= total
	_place_car()


func _on_points() -> void:
	if phase == Phase.RUNNING and not on_spur:
		diverted = true
		Hud.note("Clunk. The points are over: next time round, he's on the maintenance spur.", 3.0)


## She's in the car, or leaping over it, or on its rim (she's on him): a scuffle, and he's tied.
func _check_caught() -> void:
	var n := nim()
	var local := car.global_transform.affine_inverse() * n.global_position
	if absf(local.x) < 0.95 and absf(local.z) < 1.3 and local.y > 0.1 and local.y < 2.4:
		phase = Phase.CAUGHT
		# Into the back seat, beside him, for the ride down.
		n.teleport(car.global_transform * Vector3(0, 0.4, 0.55), car.rotation.y)
		var cloud := ScuffleCloud.new()
		pier.add_child(cloud)
		cloud.global_position = car.global_position + Vector3(0, 0.6, 0)
		cloud.hide_while([courier])
		await get_tree().create_timer(1.3).timeout
		cloud.poof()
		_courier_state(Enemy.State.BOUND)
		await get_tree().create_timer(0.4).timeout
		_done()


func _done() -> void:
	phase = Phase.DONE
	set_flag("dipper_done")
	set_flag("ledger")
	await talk("dipper", "caught")
	var p := nim().global_position
	award(&"pier_09", Vector3(p.x, p.y, p.z))


func _missed() -> void:
	Hud.caption("Courier", "Ha! Missed me! Round again! Wheee!", 2.5)
	on_spur = false
	diverted = false
	_d = 0.0
	phase = Phase.RUNNING
	_place_car()
	_make_points()


# --- along the track -------------------------------------------------------------------------------------------------

func _cumulative(path: Array, closed: bool) -> Array[float]:
	var out: Array[float] = [0.0]
	var n := path.size() if closed else path.size() - 1
	for i in n:
		out.append(out[out.size() - 1] + (path[i] as Vector3).distance_to(path[(i + 1) % path.size()]))
	return out


func _main_point(d: float) -> Vector3:
	return _along(MAIN, _main_cum, d, true)


func _spur_point(d: float) -> Vector3:
	return _along(SPUR, _spur_cum, d, false)


func _along(path: Array, cum: Array[float], d: float, closed: bool) -> Vector3:
	var n := path.size() if closed else path.size() - 1
	for i in n:
		if d <= cum[i + 1]:
			var a: Vector3 = path[i]
			var b: Vector3 = path[(i + 1) % path.size()]
			return a.lerp(b, (d - cum[i]) / maxf(cum[i + 1] - cum[i], 0.001))
	return path[0] if closed else path[path.size() - 1]


## Slow up the lift hill, fast down the drops.
func _main_speed(d: float) -> float:
	var a := _main_point(d)
	var b := _main_point(minf(d + 1.0, _main_cum[_main_cum.size() - 1]))
	var flat := Vector2(b.x - a.x, b.z - a.z).length()
	var slope := (b.y - a.y) / maxf(flat, 0.01)
	if slope > 0.1:
		return lift_speed
	return clampf(flat_speed - slope * 6.0, flat_speed, drop_speed)


func _place_car() -> void:
	var here := _spur_point(_d) if on_spur else _main_point(_d)
	var ahead := _spur_point(_d + 0.6) if on_spur else _main_point(fposmod(_d + 0.6, _main_cum[_main_cum.size() - 1]))
	var dir := Vector3(ahead.x - here.x, 0, ahead.z - here.z)
	var yaw := atan2(-dir.x, -dir.z) if dir.length() > 0.01 else car.rotation.y
	car.global_transform = Transform3D(Basis(Vector3.UP, yaw), here)
