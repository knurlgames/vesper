extends "res://levels/pier/keys/pier_key.gd"
## The boss: Lucky Lou Laffer, in the Prize Hall (worlds/01_PIER.md, "The boss"). The hall opens once Nim has the
## courier's ledger (flag pier/ledger, Key 9). Walk in and the door locks behind her.
##   1. The Cackling Crane. He works an overhead crane from a gallery high on the east wall. The claw tracks her, shakes, and
##      drops; dodge it. After a drop it sticks, and its cable is marked: climb it onto the crane's bridge and walk the
##      bridge to his gallery. He flees down a chute.
##   2. Whack-a-goon. The floor's a field of hatches. He pops up and down; hit him while he's up (claws or crop), three
##      times. Goons pop out too and fight. A gull on the gallery rail squawks where he'll come up next.
##   3. The prize mountain. He climbs the heap and waves a hypnotic toy at her. Nothing happens: "...Huh." He throws
##      boxes down as she climbs; at the top, a pounce or a strike and he's tied.
## Then the WINNER rosette, Vesper at the door ("Adequate."), and the morning paper (World.complete). Downed in the fight
## (she's back at the checkpoint outside), the door opens and that phase starts over when she comes back in.

## Inside the hall's walls.
const HALL := AABB(Vector3(-21.4, -0.5, -297.4), Vector3(42.8, 17.0, 38.6))
## The gallery along the east wall (x 19.4..21.7, z -262..-296), its top level with the crane's bridge.
const GALLERY_TOP := 13.6
const BRIDGE_Z := Vector2(-264.0, -293.0)
const TROLLEY_X := Vector2(-18.0, 17.0)
## The claw's lowest point when it's raised, and how far the cable hangs off the bridge's centre line.
const CLAW_UP := 11.4
const CLAW_OFF := 0.95
const LAFFER_DESK := Vector3(20.6, GALLERY_TOP, -279.0)
const CHUTE_TOP := Vector3(20.6, GALLERY_TOP, -263.0)
const CHUTE_FOOT := Vector3(17.5, 0.0, -262.0)
const HATCH_X := [-9.0, 0.0, 9.0]
const HATCH_Z := [-266.0, -275.0, -284.0]
## The heap: six steps rising toward the back wall, 1.25 m each, 1.7 m deep; Laffer on the top.
const HEAP_FRONT := -285.5
const HEAP_STEP := 1.7
const HEAP_RISE := 1.25
const HEAP_STEPS := 6
const LAFFER_TOP := Vector3(0.0, 7.5, -295.6)

@export var crane_speed := 4.5
@export var aim_time := 0.9
@export var drop_time := 0.45
@export var stuck_time := 4.5
@export var pop_every := 2.8
## How long before he pops up the gull calls the hatch.
@export var hint_ahead := 1.5
@export var pop_time := 2.2
@export var hits_needed := 3
@export var throw_every := 1.6
@export var box_speed := 6.0

enum Phase { LOCKED, READY, CLAW, WHACK, MOUNTAIN, DONE }
enum Claw { TRACK, AIM, DROP, STUCK, RISE, PARKED }

## A hittable stand-in for Laffer: strikes and the crop find it in the "hittable" group.
class Target extends Node3D:
	var hit_radius := 0.5
	var boss: Node

	func can_be_hit() -> bool:
		return boss.call(&"_laffer_hittable")

	func take_hit(from: Vector3, power: int) -> void:
		boss.call(&"_laffer_hit", from, power)


var phase := Phase.LOCKED
## The phase she'd reached (it restarts there if she's downed).
var stage := Phase.CLAW
var claw_state := Claw.PARKED
var hits := 0
var goons_spawned := 0
var laffer: Node3D
var target: Target
var bridge: AnimatableBody3D
var cable: AnimatableBody3D
var _cable_shape: BoxShape3D
var _cable_mesh: MeshInstance3D
var _claw: Node3D
var _door: LockDoor
var _bridge_z := -278.0
var _trolley_x := 0.0
var _claw_y := CLAW_UP
var _t := 0.0
var _anim_t := 0.0
var _aim := 0.0
var _laffer_up := false
var _next_hatch := -1
var _last_hatch := -1
var _cycle := 0
var _hinted := false
var _toy_done := false
var _boxes: Array[Node3D] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	pier = get_parent()
	_build()
	super()


# --- the build (before the level batches its meshes) -----------------------------------------------------------------

func _build() -> void:
	var gallery := Look.painted(Look.Pattern.PLANKS, Color("4a3a30"), Color("1a120e"), {"wet": 0.0})
	var white := Look.toon(Color("e8e0d0"), 0.2)
	var brass := Look.toon(Look.BRASS, 0.6)
	pier.call(&"solid", Vector3(20.55, GALLERY_TOP - 0.15, -279.0), Vector3(2.3, 0.3, 34.0), gallery)
	for z: float in [-264.0, -279.0, -294.0]:
		# Up to the gallery's underside (to its top, the post's top fought the boards).
		pier.call(&"deco", Vector3(19.6, (GALLERY_TOP - 0.3) / 2.0, z), Vector3(0.25, GALLERY_TOP - 0.3, 0.25), white)
	# The crane's rails along both side walls, under the roof.
	for x: float in [-21.2, 21.2]:
		pier.call(&"deco", Vector3(x, GALLERY_TOP + 0.6, -279.0), Vector3(0.3, 0.3, 35.0), brass)
	# Laffer's control desk, and the chute down from the gallery's north end.
	# (owner, 2026-11-14: "Fix the Laffer prop": a Meshy showman's desk, levers and bulbs, its front to the hall, -X)
	if not pier.call(&"props", "laffer_desk", [[LAFFER_DESK + Vector3(-0.75, 0, 0), -PI / 2.0]], false):
		pier.call(&"deco", LAFFER_DESK + Vector3(-0.7, 0.5, 0), Vector3(0.6, 1.0, 1.6), Look.toon(Color("c83a4a"), 0.4))
	pier.call(&"_strut", CHUTE_TOP + Vector3(0, 0.2, 0), CHUTE_FOOT + Vector3(0, 0.3, 0), 1.0,
		Look.toon(Color("e8c860"), 0.5), false)
	# The hatches: lids flush with the floor.
	for x: float in HATCH_X:
		for z: float in HATCH_Z:
			pier.call(&"deco", Vector3(x, 0.02, z), Vector3(1.6, 0.04, 1.6), Look.toon(Color("6a4a30")))
			pier.call(&"deco", Vector3(x, 0.03, z), Vector3(1.2, 0.04, 1.2), brass)
	# The prize mountain: six stacked steps of boxed prizes against the back wall.
	var boxes := [Look.toon(Color("e86a8a")), Look.toon(Color("6aa0c8")), Look.toon(Color("e8c860"))]
	var heap := Look.toon(Color("d8d0c0"))   # one material: the steps share their sides and back
	for i in HEAP_STEPS:
		var front := HEAP_FRONT - HEAP_STEP * i
		var top := HEAP_RISE * (i + 1)
		var back := -297.4
		pier.call(&"solid", Vector3(0, top / 2.0, (front + back) / 2.0), Vector3(14.0, top, absf(front - back)), heap)
		for k in 7:
			pier.call(&"deco", Vector3(-6.0 + k * 2.0, top - 0.5, front + 0.02), Vector3(1.6, 0.9, 0.04), boxes[(k + i) % 3])
	# Light: the hall's been dark for stocktaking.
	for p: Vector3 in [Vector3(-10, 10, -270), Vector3(10, 10, -270), Vector3(0, 11, -288)]:
		pier.call(&"_light", p, Color("ffc870"), 3.0, 18.0)
	# The hall's doors (pier.gd "HallDoors", a LockDoor): shut behind her during the fight, open between.
	_door = pier.get_node_or_null(^"HallDoors") as LockDoor


func _setup() -> void:
	_rng.seed = 11
	_make_crane()
	_make_laffer()
	if flag("laffer_bound"):
		_open_hall()
		phase = Phase.DONE
		laffer.global_position = LAFFER_TOP
		_laffer_state(Enemy.State.BOUND)
		if flag("laffer_gagged"):
			_tape_on.call_deferred(false)
		return
	if flag("ledger"):
		_open_hall()
		phase = Phase.READY
	Game.flag_changed.connect(func(key: StringName) -> void:
		if key == &"pier/ledger" and phase == Phase.LOCKED:
			_open_hall(true)
			phase = Phase.READY)


## Open for business: the sign's down and the doors swing in (at once on loading a game where it's open).
func _open_hall(animate := false) -> void:
	var sign := pier.get_node_or_null(^"ShutterSign")
	if sign:
		sign.queue_free()
	if _door:
		_door.unlock(animate)


func _make_crane() -> void:
	bridge = AnimatableBody3D.new()
	bridge.name = "CraneBridge"
	bridge.sync_to_physics = true
	add_child(bridge)
	var walk := Look.painted(Look.Pattern.PLANKS, Color("6a5a4a"), Color("1a120e"), {"wet": 0.0})
	var size := Vector3(40.4, 0.3, 1.2)
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	m.mesh = box
	m.material_override = walk
	m.position = Vector3(-0.8, -0.15, 0)
	bridge.add_child(m)
	var col := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	col.shape = s
	col.position = m.position
	bridge.add_child(col)
	# The trolley rides the bridge; the claw hangs from it, off the bridge's south side.
	cable = AnimatableBody3D.new()
	cable.name = "CraneCable"
	cable.sync_to_physics = true
	cable.collision_layer = 1 | 2   # marked: she climbs it when the claw's stuck
	add_child(cable)
	_cable_shape = BoxShape3D.new()
	_cable_shape.size = Vector3(0.4, 1.0, 0.4)
	var ccol := CollisionShape3D.new()
	ccol.shape = _cable_shape
	cable.add_child(ccol)
	_cable_mesh = MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.4, 1.0, 0.4)
	_cable_mesh.mesh = cm
	_cable_mesh.material_override = Look.painted(Look.Pattern.BRICK, Color("4f8a5a"), Color("173020"), {"wet": 0.0, "scale": 1.6})
	cable.add_child(_cable_mesh)
	_claw = Node3D.new()
	_claw.name = "Claw"
	add_child(_claw)
	var brass := Look.toon(Look.BRASS, 0.7)
	var hub := MeshInstance3D.new()
	var hb := BoxMesh.new()
	hb.size = Vector3(0.9, 0.5, 0.9)
	hub.mesh = hb
	hub.position.y = 0.95
	hub.material_override = brass
	_claw.add_child(hub)
	for a in 3:
		var prong := MeshInstance3D.new()
		var pb := BoxMesh.new()
		pb.size = Vector3(0.14, 0.9, 0.14)
		prong.mesh = pb
		var ang := TAU * a / 3.0
		prong.position = Vector3(cos(ang) * 0.45, 0.4, sin(ang) * 0.45)
		prong.rotation = Vector3(sin(ang) * 0.35, 0, -cos(ang) * 0.35)
		prong.material_override = brass
		_claw.add_child(prong)
	var trolley := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(1.2, 0.5, 2.2)
	trolley.mesh = tb
	trolley.name = "Trolley"
	trolley.material_override = Look.toon(Color("c83a4a"), 0.4)
	add_child(trolley)
	_place_crane()


func _make_laffer() -> void:
	if EnemyModel.exists("laffer"):
		var m := EnemyModel.new()
		m.body = "laffer"
		m.no_mouth_tape = true   # (tied in the scuffle, mouth free; Nim tapes him after his last word: tape_gag)
		laffer = m
	else:
		laffer = Node3D.new()
		var cap := MeshInstance3D.new()
		var mesh := CapsuleMesh.new()
		mesh.radius = 0.35
		mesh.height = 1.9
		cap.mesh = mesh
		cap.position.y = 0.95
		cap.material_override = Look.toon(Color("c8a060"))
		laffer.add_child(cap)
	laffer.name = "Laffer"
	add_child(laffer)
	laffer.global_position = LAFFER_DESK
	laffer.rotation.y = PI / 2.0   # facing the hall (-X)
	target = Target.new()
	target.name = "LafferTarget"
	target.boss = self
	laffer.add_child(target)
	target.add_to_group(&"hittable")


func _laffer_state(state: int) -> void:
	if laffer is EnemyModel:
		(laffer as EnemyModel).show_state(state, _anim_t, 0.0, 1.0)


# --- the fight -------------------------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if laffer == null:
		return
	_anim_t += delta
	var n := nim()
	if n == null:
		return
	var inside := HALL.has_point(n.global_position)
	match phase:
		Phase.READY:
			_laffer_state(Enemy.State.PATROL)
			if inside and n.global_position.z < -261.0 and not Dialogue.is_active():
				_begin()
		Phase.CLAW, Phase.WHACK, Phase.MOUNTAIN:
			if not inside and not Dialogue.is_active():
				_reset()
				return
			match phase:
				Phase.CLAW:
					_claw_tick(delta)
				Phase.WHACK:
					_whack_tick(delta)
				Phase.MOUNTAIN:
					_mountain_tick(delta)
		Phase.DONE:
			_laffer_state(Enemy.State.BOUND)


func _begin() -> void:
	if _door:
		_door.lock()
	phase = stage   # at once, so this can't run twice while the intro plays
	if stage == Phase.CLAW:
		claw_state = Claw.PARKED
		if flag("laffer_met"):
			Hud.caption("Laffer", "Back again! Ha ha! Another go on the Cackling Crane!", 2.0)
		else:
			set_flag("laffer_met")
			# His entrance (owner, 2026-11-13: boss intros as cutscenes): the hall, then him at his desk, his piece.
			await Dialogue.play_cutscene("res://data/cutscenes/laffer_intro.json")
		_start_claw()
	elif stage == Phase.WHACK:
		Hud.caption("Laffer", "Back for more? Ha ha! Whack-a-goon, boys!", 2.5)
		_start_whack()
	else:
		Hud.caption("Laffer", "Ha! Ha ha! You again!", 2.0)
		_start_mountain()


## Downed, she's back at the checkpoint outside: the door opens, and this phase starts over when she comes back in.
func _reset() -> void:
	if _door:
		_door.unlock()
	phase = Phase.READY
	for b in _boxes:
		b.queue_free()
	_boxes.clear()
	_laffer_up = false
	claw_state = Claw.PARKED
	_claw_y = CLAW_UP
	_place_crane()
	if stage == Phase.CLAW:
		laffer.global_position = LAFFER_DESK
		laffer.visible = true


# --- 1. the Cackling Crane (his claw machine: never "the Claw", the crew's name) ---------------------------------

func _start_claw() -> void:
	phase = Phase.CLAW
	stage = Phase.CLAW
	claw_state = Claw.TRACK
	_aim = 0.0


func _claw_tick(delta: float) -> void:
	var n := nim()
	var p := n.global_position
	_laffer_state(Enemy.State.PATROL)
	match claw_state:
		Claw.TRACK:
			_bridge_z = move_toward(_bridge_z, clampf(p.z - CLAW_OFF, BRIDGE_Z.y, BRIDGE_Z.x), crane_speed * delta)
			_trolley_x = move_toward(_trolley_x, clampf(p.x, TROLLEY_X.x, TROLLEY_X.y), crane_speed * delta)
			var over := Vector2(_trolley_x - p.x, _bridge_z + CLAW_OFF - p.z).length() < 1.2 and p.y < 2.0
			_aim = _aim + delta if over else 0.0
			if _aim > 0.35:
				claw_state = Claw.AIM
				_t = aim_time
				Hud.caption("Laffer", ["Lucky dip! Ha ha!", "Everybody's a winner!", "Grab the prize! Ha!"][_rng.randi() % 3], 1.5)
		Claw.AIM:
			_t -= delta
			_claw.rotation.y = sin(_anim_t * 40.0) * 0.15   # the shake: it's about to drop
			if _t <= 0.0:
				claw_state = Claw.DROP
				_t = 0.0
				_claw.rotation.y = 0.0
		Claw.DROP:
			_t += delta
			_claw_y = lerpf(CLAW_UP, 0.1, clampf(_t / drop_time, 0.0, 1.0))
			if _t >= drop_time:
				var at := _claw_point()
				if Vector2(at.x - p.x, at.z - p.z).length() < 1.3 and p.y < 2.2:
					n.combat.hurt(at)
				claw_state = Claw.STUCK
				_t = stuck_time
				Hud.caption("Laffer", "It's stuck! Ha ha... ha?", 2.0)
		Claw.STUCK:
			# It stays stuck while she's on its cable or up on the bridge.
			var on_it := (n.state == Nim.State.CLIMB and Vector2(_trolley_x - p.x, _bridge_z + CLAW_OFF - p.z).length() < 1.2) \
				or p.y > GALLERY_TOP - 0.6
			if not on_it:
				_t -= delta
			if _t <= 0.0:
				claw_state = Claw.RISE
				_t = 0.0
		Claw.RISE:
			_t += delta
			_claw_y = lerpf(0.1, CLAW_UP, clampf(_t / 1.0, 0.0, 1.0))
			if _t >= 1.0:
				claw_state = Claw.TRACK
				_aim = 0.0
	_place_crane()
	# Up on the gallery: he's off down the chute.
	if p.y > GALLERY_TOP - 0.4 and p.x > 19.2:
		_flee()


func _flee() -> void:
	phase = Phase.WHACK
	claw_state = Claw.PARKED
	await talk("laffer", "chute")
	var tw := create_tween()
	tw.tween_property(laffer, ^"global_position", CHUTE_TOP, 0.5)
	tw.tween_property(laffer, ^"global_position", CHUTE_FOOT, 0.8)
	await tw.finished
	laffer.visible = false
	_claw_y = CLAW_UP
	_place_crane()
	_start_whack()


func _claw_point() -> Vector3:
	return Vector3(_trolley_x, _claw_y, _bridge_z + CLAW_OFF)


func _place_crane() -> void:
	bridge.global_position = Vector3(0, GALLERY_TOP, _bridge_z)
	var trolley := get_node_or_null(^"Trolley") as Node3D
	if trolley:
		trolley.global_position = Vector3(_trolley_x, GALLERY_TOP + 0.25, _bridge_z + 0.5)
	_claw.global_position = _claw_point()
	# The cable: from the claw's top up to the bridge's walking surface.
	var bottom := _claw_y + 0.6   # down into the hub: low enough to grab from the floor
	var length := maxf(GALLERY_TOP - bottom, 0.2)
	_cable_shape.size = Vector3(0.4, length, 0.4)
	(_cable_mesh.mesh as BoxMesh).size = _cable_shape.size
	cable.global_position = Vector3(_trolley_x, bottom + length / 2.0, _bridge_z + CLAW_OFF)


# --- 2. whack-a-goon -------------------------------------------------------------------------------------------------

func _start_whack() -> void:
	phase = Phase.WHACK
	stage = Phase.WHACK
	hits = 0
	_t = 1.5
	_cycle = 0
	_laffer_up = false
	_hinted = false
	laffer.visible = false


func _whack_tick(delta: float) -> void:
	_t -= delta
	if _laffer_up:
		_laffer_state(Enemy.State.PATROL)
		if _t <= 0.0:
			_duck()
		return
	if not _hinted and _t <= hint_ahead:
		_hinted = true
		_next_hatch = _pick_hatch(_last_hatch)
		Hud.caption("Gull", "SQUAWK! %s!" % _hatch_words(_next_hatch), 1.2)
	if _t <= 0.0:
		_pop(_next_hatch)


func _pop(h: int) -> void:
	_cycle += 1
	_last_hatch = h
	_laffer_up = true
	_t = pop_time
	laffer.visible = true
	laffer.global_position = _hatch(h)
	laffer.rotation.y = atan2(-(nim().global_position.x - laffer.global_position.x), -(nim().global_position.z - laffer.global_position.z))
	Hud.caption("Laffer", ["Peekaboo! Ha ha!", "Over here! Ha!", "Whack-a-Laffer! Ha ha ha!"][_cycle % 3], 1.2)
	# Every other time, a goon comes up another hatch (four in all, two at a time at most).
	if _cycle % 2 == 0 and goons_spawned < 4 and _goons_up() < 2:
		var gh := _pick_hatch(h)
		goons_spawned += 1
		var g := Enemy.new()
		g.id = StringName("hall_g%d" % goons_spawned)
		g.name = "Goon_hall_g%d" % goons_spawned
		g.body = "weasel_goon"
		g.position = _hatch(gh) + Vector3(0, 0.05, 0)
		pier.add_child(g)
		g.alert(nim().global_position)


func _duck() -> void:
	_laffer_up = false
	laffer.visible = false
	_hinted = false
	_t = pop_every


func _goons_up() -> int:
	var up := 0
	for i in range(1, goons_spawned + 1):
		var g := goon(StringName("hall_g%d" % i))
		if g and not g.is_bound():
			up += 1
	return up


func _pick_hatch(avoid: int) -> int:
	var h := _rng.randi() % 9
	while h == avoid:
		h = _rng.randi() % 9
	return h


func _hatch(h: int) -> Vector3:
	return Vector3(HATCH_X[h % 3], 0.0, HATCH_Z[h / 3])


func _hatch_words(h: int) -> String:
	return "%s row, %s" % [["Front", "Middle", "Back"][h / 3], ["left", "middle", "right"][h % 3]]


# --- 3. the prize mountain -------------------------------------------------------------------------------------------

func _start_mountain() -> void:
	phase = Phase.MOUNTAIN
	stage = Phase.MOUNTAIN
	_laffer_up = false
	_toy_done = false
	laffer.visible = true
	laffer.global_position = LAFFER_TOP
	laffer.rotation.y = PI   # facing the hall (+Z)
	_t = throw_every


func _mountain_tick(delta: float) -> void:
	var n := nim()
	_laffer_state(Enemy.State.PATROL)
	if not _toy_done and n.global_position.z < -276.0:
		_toy_done = true
		await talk("laffer", "toy")
		return
	if _toy_done:
		_t -= delta
		if _t <= 0.0 and n.global_position.y < LAFFER_TOP.y - 0.5:
			_t = throw_every
			_throw()
	_tick_boxes(delta)
	# At the top, a pounce at him (a strike or the crop hits LafferTarget) and he's done for.
	var to := laffer.global_position - n.global_position
	if n.global_position.y > LAFFER_TOP.y - 0.8 and Vector2(to.x, to.z).length() < 1.8 and float(n.get(&"_pounce")) > 0.0:
		_caught()


func _throw() -> void:
	var b := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.6, 0.6, 0.6)
	b.mesh = bm
	b.material_override = Look.toon([Color("e86a8a"), Color("6aa0c8"), Color("e8c860")][_rng.randi() % 3])
	add_child(b)
	b.global_position = LAFFER_TOP + Vector3(0, 1.2, 0.8)
	var to := nim().global_position - b.global_position
	to.y = 0.0
	b.set_meta(&"dir", to.normalized() if to.length() > 0.1 else Vector3.BACK)
	b.set_meta(&"age", 0.0)
	_boxes.append(b)


## Boxes tumble down the steps toward where she was; a hit knocks her back.
func _tick_boxes(delta: float) -> void:
	var n := nim()
	for b: Node3D in _boxes.duplicate():
		var age: float = b.get_meta(&"age") + delta
		b.set_meta(&"age", age)
		var p := b.global_position + (b.get_meta(&"dir") as Vector3) * box_speed * delta
		p.y = _heap_height(p.z) + 0.3
		b.global_position = p
		b.rotation.x += 8.0 * delta
		var to := n.global_position - p
		if Vector2(to.x, to.z).length() < 0.8 and absf(to.y + 0.3) < 1.3:
			n.combat.hurt(p)
			age = 99.0
		if age > 4.0 or p.z > -270.0:
			_boxes.erase(b)
			b.queue_free()


func _heap_height(z: float) -> float:
	if z > HEAP_FRONT:
		return 0.0
	var i := mini(int((HEAP_FRONT - z) / HEAP_STEP), HEAP_STEPS - 1)
	return HEAP_RISE * (i + 1)


func _caught() -> void:
	if phase != Phase.MOUNTAIN:
		return
	phase = Phase.DONE
	for b in _boxes:
		b.queue_free()
	_boxes.clear()
	var cloud := ScuffleCloud.new()
	pier.add_child(cloud)
	cloud.global_position = laffer.global_position + Vector3(0, 0.6, 0.6)
	cloud.hide_while([laffer])
	await get_tree().create_timer(1.3).timeout
	cloud.poof()
	_laffer_state(Enemy.State.BOUND)
	set_flag("laffer_bound")
	if _door:
		_door.unlock()
	# Vesper, at the door, for the walk back (there first, so the cutscene can find her).
	talker("Vesper_hall", "vesper", "hall_after", Vector3(1.5, 0.0, -261.0), 0.0, "vesper", "garb", "Vesper", Color("c0283e"))
	# His defeat as a cutscene (owner, 2026-11-13): the rosette, Dash's whoop, Vesper's "Adequate."
	await Dialogue.play_cutscene("res://data/cutscenes/laffer_defeat.json")
	await pier.complete(false)


## The second half of his finish (owner, 2026-11-14: tied in the scuffle, his last lines, Nim's retort, then the tape
## "properly gagged"): a strip of tape over his grin. Called from laffer_defeat.json; awaitable.
func tape_gag() -> Signal:
	return _tape_on(true)


var _tape_rig: RigGear


func _tape_on(slap: bool) -> Signal:
	set_flag("laffer_gagged")
	var sk: Skeleton3D = laffer.call(&"skeleton") if laffer.has_method(&"skeleton") else null
	if sk == null or _tape_rig != null:
		return get_tree().process_frame
	_tape_rig = RigGear.new(sk, laffer)
	_tape_rig.tape_colour = RigGear.DUCT
	return RigGear.slap_on(_tape_rig.gag("tape"), self) if slap else get_tree().process_frame


# --- Laffer as a target ----------------------------------------------------------------------------------------------

func _laffer_hittable() -> bool:
	if phase == Phase.WHACK:
		return _laffer_up
	if phase == Phase.MOUNTAIN:
		return _toy_done and nim().global_position.y > LAFFER_TOP.y - 0.8
	return false


func _laffer_hit(_from: Vector3, _power: int) -> void:
	if phase == Phase.WHACK and _laffer_up:
		hits += 1
		Hud.caption("Laffer", ["Ow! Ha ha! Ow!", "Ha! Ow! Ha ha ha!", "OW! Okay, that one's not funny! Ha ha!"][mini(hits - 1, 2)], 1.6)
		Hud.note("Laffer: %d of %d" % [hits, hits_needed], 1.5)
		_duck()
		if hits >= hits_needed:
			_start_mountain()
	elif phase == Phase.MOUNTAIN:
		_caught()
