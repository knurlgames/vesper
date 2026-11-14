extends "res://levels/primrose/keys/primrose_key.gd"
## The boss: Mrs Marjorie Gander, in her conservatory and topiary garden (worlds/02_PRIMROSE_CLOSE.md "The boss"; WO-015
## step 4). The garden opens after the demonstration party (primrose/party_done). Walk in and her back door locks.
##   1. **The garden party.** Her guests wander the lawns in trances; Gander hides among the topiary, honking and
##      throwing teacups (a red ring shows where each will land). Nim hasn't the pendant yet, so she follows the honks.
##      Strike her three times; each time she runs for another hiding place. A guest struck instead: "HONK! Ha!", and
##      she's got her breath back (one hit undone). Nobody hurts the guests.
##   2. **The sprinklers.** She runs to her control box and floods the garden. The water knocks the wind out of Nim
##      while she's standing in it: up onto the topiary, and crack each sprinkler head with the crop (six).
##   3. **The tantrum.** Cornered in the conservatory, she throws everything she owns. You don't fight a tantrum: a strike
##      only makes it worse. Grizelda's Scold (LB) and she freezes mid-throw, then sits down on an upturned flowerpot.
##      A strike, then, and she's tied.
## Then she's bound to her own garden bench under her own sign, the order book (and the Docks' shipping notes under it),
## Grizelda's verdict, Vesper, and the parish newsletter (World.complete). Downed (back at the checkpoint just inside),
## that phase starts over. OWNER REVIEW: every line.

## The garden, inside its hedges (x -22..22, z -136.5..-176).
const GARDEN := AABB(Vector3(-22.0, -1.0, -176.0), Vector3(44.0, 12.0, 39.6))
const LAWN := 0.08
const DOOR_Z := -136.0
## Her bench (primrose.gd: x -1.5..1.5, z -173.95..-173.05, its top at 0.9), under her sign.
const BENCH := Vector3(0.0, 0.9, -173.5)
const CONTROL := Vector3(19.0, LAWN, -141.4)
const CONSERVATORY := Vector3(0.0, LAWN, -143.4)
## Where she hides in the garden party: among the topiary, round the edges.
const SPOTS := [Vector3(-19.0, LAWN, -150.0), Vector3(19.0, LAWN, -150.0), Vector3(-19.0, LAWN, -170.0),
	Vector3(19.0, LAWN, -170.0), Vector3(-10.0, LAWN, -164.0), Vector3(10.0, LAWN, -156.0), Vector3(0.0, LAWN, -172.0),
	Vector3(-5.0, LAWN, -150.0)]
## The sprinkler heads: by the topiary, each on its jet, in the crop's reach from a topiary's top.
const HEADS := [Vector3(-13.2, LAWN, -152.0), Vector3(6.8, LAWN, -152.0), Vector3(-3.2, LAWN, -160.0),
	Vector3(16.8, LAWN, -160.0), Vector3(-13.2, LAWN, -168.0), Vector3(6.8, LAWN, -168.0)]
const HEAD_UP := 1.3
const WATER_Y := 0.5

@export var hits_needed := 3
@export var throw_every := 2.0
@export var cup_flight := 1.15
@export var tantrum_every := 0.9
@export var soak_every := 2.2

enum Phase { LOCKED, READY, PARTY, SPRINKLERS, TANTRUM, DONE }

## A hittable stand-in for her (strikes and the crop find it in "hittable"), or for a guest.
class Target extends Node3D:
	var hit_radius := 0.5
	var boss: Node
	var guest := -1

	func can_be_hit() -> bool:
		return boss.call(&"_hittable", guest)

	func take_hit(from: Vector3, power: int) -> void:
		boss.call(&"_struck", guest, from, power)


var phase := Phase.LOCKED
## The phase she'd reached (it starts over there if Nim's downed).
var stage := Phase.PARTY
var hits := 0
var heads_out := 0
var gander: Node3D
var target: Target
var _lock: StaticBody3D
var _water: MeshInstance3D
var _water_y := 0.0
var _jets: Array = []          # [column, CropTarget]
var _guests: Array = []        # [node, goal]
var _cups: Array = []          # [node, from, to, t, ring]
var _spot := 0
var _running := false
var _throw_t := 0.0
var _near_t := 0.0
var _soak_t := 0.0
var _frozen := false
var _sitting := false
var _pot: Node3D
var _rig: RigGear
var _anim_t := 0.0
var _rng := RandomNumberGenerator.new()


func _setup() -> void:
	_rng.seed = 22
	_make_gander()
	_lock = StaticBody3D.new()
	_lock.name = "GardenLock"
	_lock.collision_layer = 0
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.4, 2.6, 0.4)
	var col := CollisionShape3D.new()
	col.shape = shape
	_lock.add_child(col)
	_lock.position = Vector3(0, 1.3, DOOR_Z)
	add_child(_lock)
	if flag("gander_bound"):
		phase = Phase.DONE
		_on_bench()
		return
	_make_garden()
	if flag("party_done"):
		phase = Phase.READY
	Game.flag_changed.connect(func(key: StringName) -> void:
		if key == &"primrose/party_done" and phase == Phase.LOCKED:
			phase = Phase.READY)
	var n := nim()
	if n:
		n.combat.downed.connect(_on_downed)
		n.gear.said.connect(_on_scold)


func _make_gander() -> void:
	if EnemyModel.exists("gander"):
		var m := EnemyModel.new()
		m.body = "gander"
		gander = m
	else:
		gander = Node3D.new()
		var cap := MeshInstance3D.new()
		var mesh := CapsuleMesh.new()
		mesh.radius = 0.4
		mesh.height = 1.8
		cap.mesh = mesh
		cap.position.y = 0.9
		cap.material_override = Look.toon(Color("e8e0d0"))
		gander.add_child(cap)
	gander.name = "GanderBoss"
	add_child(gander)
	gander.global_position = CONSERVATORY
	target = Target.new()
	target.name = "GanderTarget"
	target.boss = self
	target.position.y = 1.0
	gander.add_child(target)
	target.add_to_group(&"hittable")


## The flood's water (hidden until phase 2), the sprinkler jets and their heads, the guests in their trances.
func _make_garden() -> void:
	_water = MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(43.6, 0.02, 39.2)
	_water.mesh = plane
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.35, 0.55, 0.8, 0.55)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.roughness = 0.1
	_water.material_override = wm
	_water.position = Vector3(0, -0.2, -156.2)
	_water.visible = false
	add_child(_water)
	for h: Vector3 in HEADS:
		var jet := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.05
		cyl.bottom_radius = 0.1
		cyl.height = HEAD_UP
		jet.mesh = cyl
		var jm := StandardMaterial3D.new()
		jm.albedo_color = Color(0.8, 0.9, 1.0, 0.5)
		jm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		jet.material_override = jm
		jet.position = h + Vector3(0, HEAD_UP / 2.0, 0)
		jet.visible = false
		add_child(jet)
		var head := CropTarget.new()
		head.kind = CropTarget.Kind.TARGET
		head.position = h + Vector3(0, HEAD_UP, 0)
		head.visible = false
		head.struck = true   # (not hittable until the flood)
		add_child(head)
		head.hit.connect(_on_head.bind(_jets.size()))
		_jets.append([jet, head])
	var bodies := ["hare_civilian", "otter_civilian", "fox_civilian", "hedgehog_civilian", "otter_civilian"]
	var tints := [Color("d0b8e0"), Color("e0c8a8"), Color("e0c890"), Color("b8c8d8"), Color("d8b0a0")]
	for i in bodies.size():
		var g: Node3D
		if EnemyModel.exists(bodies[i]):
			var m := EnemyModel.new()
			m.body = bodies[i]
			m.tint = tints[i]
			g = m
		else:
			g = Node3D.new()
		g.name = "TranceGuest_%d" % i
		add_child(g)
		g.global_position = Vector3(-14.0 + i * 7.0, LAWN, -158.0 + (i % 2) * 6.0)
		var t := Target.new()
		t.boss = self
		t.guest = i
		t.position.y = 1.0
		t.hit_radius = 0.4
		g.add_child(t)
		t.add_to_group(&"hittable")
		_guests.append([g, _wander_goal()])


func _wander_goal() -> Vector3:
	return Vector3(_rng.randf_range(-18.0, 18.0), LAWN, _rng.randf_range(-172.0, -150.0))


# --- the fight ---------------------------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if gander == null:
		return
	_anim_t += delta
	var n := nim()
	if n == null:
		return
	match phase:
		Phase.LOCKED:
			_show(0, 0.0)
		Phase.READY:
			_show(0, 0.0)
			if GARDEN.has_point(n.global_position) and n.global_position.z < DOOR_Z - 1.5 and not Dialogue.is_active():
				_begin()
		Phase.PARTY, Phase.SPRINKLERS, Phase.TANTRUM:
			if Dialogue.is_active():
				return
			_guests_tick(delta)
			_cups_tick(delta)
			match phase:
				Phase.PARTY:
					_party_tick(delta)
				Phase.SPRINKLERS:
					_sprinklers_tick(delta)
				Phase.TANTRUM:
					_tantrum_tick(delta)
		Phase.DONE:
			_show(9, 0.0)


func _show(state: int, speed: float) -> void:
	if gander is EnemyModel:
		(gander as EnemyModel).show_state(state, _anim_t, speed, 1.0)


func _face(p: Vector3) -> void:
	var to := p - gander.global_position
	to.y = 0.0
	if to.length() > 0.05:
		gander.rotation.y = atan2(-to.x, -to.z)


func _begin() -> void:
	_lock.collision_layer = 1
	phase = stage   # at once, so this can't run twice while the intro plays
	if not flag("gander_met"):
		set_flag("gander_met")
		await talk("gander", "intro")
	else:
		Hud.caption("Gander", "You AGAIN. HONK.", 2.0)
	match stage:
		Phase.PARTY:
			_start_party()
		Phase.SPRINKLERS:
			_start_sprinklers()
		Phase.TANTRUM:
			_start_tantrum()


## Downed: back at the checkpoint just inside the door, and the phase she'd reached starts over.
func _on_downed() -> void:
	if phase in [Phase.PARTY, Phase.SPRINKLERS, Phase.TANTRUM]:
		_clear_cups()
		if _rig:
			_rig.clear()
			_rig = null
		if gander is EnemyModel:
			(gander as EnemyModel).hold(false)
		if is_instance_valid(_pot):
			_pot.queue_free()
		if _sitting or _frozen:
			gander.global_position = CONSERVATORY   # (up off the flowerpot)
		_frozen = false
		_sitting = false
		phase = Phase.READY


func _clear_cups() -> void:
	for c: Array in _cups:
		for node: Node in [c[0], c[4]]:
			if is_instance_valid(node):
				node.queue_free()
	_cups.clear()


## Her guests drift about the lawns, slowly, mowing nothing.
func _guests_tick(delta: float) -> void:
	for g: Array in _guests:
		var node: Node3D = g[0]
		var goal: Vector3 = g[1]
		var to := goal - node.global_position
		to.y = 0.0
		if to.length() < 0.3:
			g[1] = _wander_goal()
			continue
		node.global_position += to.normalized() * 0.7 * delta
		node.global_position.y = LAWN
		node.rotation.y = atan2(-to.x, -to.z)
		if node is EnemyModel:
			(node as EnemyModel).show_state(0, _anim_t, 0.7, 1.0)


# --- 1. the garden party -------------------------------------------------------------------------------------------

func _start_party() -> void:
	phase = Phase.PARTY
	hits = 0
	_spot = 0
	_run_to(SPOTS[_spot])
	_throw_t = throw_every


func _party_tick(delta: float) -> void:
	if _running:
		return
	var n := nim()
	_face(n.global_position)
	_show(0, 0.0)
	_throw_t -= delta
	if _throw_t <= 0.0:
		_throw_t = throw_every * _rng.randf_range(0.8, 1.2)
		_throw(n.global_position, cup_flight)
	# Too close: a moment's grace (strike now), then she's off.
	if gander.global_position.distance_to(n.global_position) < 3.0:
		_near_t += delta
		if _near_t > 1.1:
			_near_t = 0.0
			_flee_from(n.global_position)
	else:
		_near_t = 0.0


var _move_tw: Tween


## A run to `p` (a new one cancels the one under way).
func _run_to(p: Vector3, speed := 5.0) -> void:
	if _move_tw and _move_tw.is_valid():
		_move_tw.kill()
	_running = true
	_face(p)
	var tw := create_tween()
	_move_tw = tw
	tw.tween_property(gander, ^"global_position", p, gander.global_position.distance_to(p) / speed)
	_show(2, speed)
	await tw.finished
	if _move_tw == tw:
		_running = false


## Off to another hiding place, a fair way from Nim but not the far corner every time (a 40 m sprint after each hit
## was a chore): one 10 to 26 m off, at random, or the furthest if none is.
func _flee_from(from: Vector3) -> void:
	var fair: Array[int] = []
	var best := _spot
	var far := 0.0
	for i in SPOTS.size():
		if i == _spot:
			continue
		var d: float = (SPOTS[i] as Vector3).distance_to(from)
		if d >= 10.0 and d <= 26.0:
			fair.append(i)
		if d > far:
			far = d
			best = i
	_spot = fair[_rng.randi() % fair.size()] if not fair.is_empty() else best
	_honk()
	_run_to(SPOTS[_spot])


func _honk() -> void:
	var l := Label3D.new()
	l.text = "HONK!"
	l.font_size = 64
	l.pixel_size = 0.01
	l.modulate = Color("f0e8d0")
	l.outline_size = 10
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true   # heard through the topiary: that's how Nim finds her
	add_child(l)
	l.global_position = gander.global_position + Vector3(0, 2.2, 0)
	var tw := create_tween()
	tw.tween_property(l, ^"global_position:y", l.global_position.y + 1.2, 1.1)
	tw.parallel().tween_property(l, ^"modulate:a", 0.0, 1.1)
	tw.tween_callback(l.queue_free)


## A teacup (or, in the tantrum, whatever's to hand), lobbed at where Nim is; a ring where it'll land.
func _throw(at: Vector3, flight: float) -> void:
	_honk()
	if gander is EnemyModel:
		(gander as EnemyModel).show_state(3, 0.0, 0.0, 1.0)
	var cup := MeshInstance3D.new()
	var kind := _rng.randi() % (3 if phase == Phase.TANTRUM else 1)
	match kind:
		0:
			var c := CylinderMesh.new()
			c.top_radius = 0.09
			c.bottom_radius = 0.06
			c.height = 0.1
			cup.mesh = c
			cup.material_override = Look.toon(Color("f0ece0"), 0.4)
		1:
			var c := CylinderMesh.new()
			c.top_radius = 0.16
			c.bottom_radius = 0.11
			c.height = 0.2
			cup.mesh = c
			cup.material_override = Look.toon(Color("b05a3a"))
		_:
			var s := SphereMesh.new()
			s.radius = 0.14
			s.height = 0.3
			cup.mesh = s
			cup.material_override = Look.toon(Color("4a8a5a"))
	add_child(cup)
	var from := gander.global_position + Vector3(0, 1.3, 0)
	cup.global_position = from
	var to := Vector3(at.x, at.y, at.z)
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.7
	tor.outer_radius = 0.85
	ring.mesh = tor
	ring.material_override = Look.toon(Color(1.6, 0.3, 0.3))
	add_child(ring)
	ring.global_position = to + Vector3(0, 0.06 + (_water_y if phase == Phase.SPRINKLERS else 0.0), 0)
	_cups.append([cup, from, to, 0.0, ring, flight])


func _cups_tick(delta: float) -> void:
	var n := nim()
	for c: Array in _cups.duplicate():
		c[3] = float(c[3]) + delta
		var k: float = float(c[3]) / float(c[5])
		var cup: Node3D = c[0]
		var from: Vector3 = c[1]
		var to: Vector3 = c[2]
		if k < 1.0:
			cup.global_position = from.lerp(to, k) + Vector3.UP * 2.6 * 4.0 * k * (1.0 - k)
			cup.rotation.x += 10.0 * delta
			continue
		var d := n.global_position - to
		if Vector2(d.x, d.z).length() < 0.95 and absf(d.y) < 1.4:
			n.combat.hurt(to)
		for node: Node in [cup, c[4]]:
			if is_instance_valid(node):
				node.queue_free()
		_cups.erase(c)


func _hittable(guest: int) -> bool:
	if guest >= 0:
		return phase == Phase.PARTY
	match phase:
		Phase.PARTY:
			return not _running
		Phase.TANTRUM:
			return true
	return false


func _struck(guest: int, _from: Vector3, _power: int) -> void:
	if guest >= 0:
		if phase == Phase.PARTY:
			hits = maxi(0, hits - 1)
			Hud.caption("Gander", "HONK! Ha! Hit my guests, would you? Lovely!", 2.0)
			Hud.note("Not the guests. They're in a trance, not in the way. (Gander: %d of %d)" % [hits, hits_needed], 2.2)
		return
	match phase:
		Phase.PARTY:
			hits += 1
			Hud.caption("Gander", ["HONK! How DARE you!", "HONK! My good hat!", "HONK! That's IT! That is IT!"][mini(hits - 1, 2)], 1.8)
			Hud.note("Mrs Gander: %d of %d" % [hits, hits_needed], 1.5)
			if hits >= hits_needed:
				_start_sprinklers()
			else:
				_flee_from(nim().global_position)
		Phase.TANTRUM:
			if _sitting:
				_caught()
			elif not _frozen:
				Hud.note("You don't fight a tantrum. (Grizelda's Scold: LB.)", 2.2)
				Hud.caption("Gander", "HOOOONK!", 1.2)
				_throw_t = 0.0   # it only makes it worse
				_throw(nim().global_position, 0.7)


# --- 2. the sprinklers ---------------------------------------------------------------------------------------------

func _start_sprinklers() -> void:
	phase = Phase.SPRINKLERS
	stage = Phase.SPRINKLERS
	heads_out = 0
	Hud.caption("Gander", "Enough! My SPRINKLERS! Let's see you dance!", 2.4)
	await _run_to(CONTROL, 6.0)
	if phase != Phase.SPRINKLERS:
		return
	_face(nim().global_position)
	_water.visible = true
	var tw := create_tween()
	tw.tween_method(_set_water, 0.0, WATER_Y, 3.0)
	for j: Array in _jets:
		(j[0] as Node3D).visible = true
		var head: CropTarget = j[1]
		head.visible = true
		head.struck = false
	Hud.note("The water's freezing. Up out of it (the topiary), and crack each sprinkler head with the crop.", 3.5)
	_throw_t = 3.0


func _set_water(y: float) -> void:
	_water_y = y
	_water.position.y = y


func _sprinklers_tick(delta: float) -> void:
	var n := nim()
	_show(0, 0.0)
	_face(n.global_position)
	for j: Array in _jets:
		var jet: Node3D = j[0]
		if jet.visible:
			jet.scale.y = 1.0 + 0.06 * sin(_anim_t * 18.0)
	# Stood in the water, it knocks the wind out of her.
	if n.is_on_floor() and n.global_position.y < _water_y - 0.05 and GARDEN.has_point(n.global_position):
		_soak_t += delta
		if _soak_t >= soak_every:
			_soak_t = 0.0
			n.combat.hurt(n.global_position + Vector3.DOWN)
	else:
		_soak_t = 0.0
	_throw_t -= delta
	if _throw_t <= 0.0:
		_throw_t = 3.2
		_throw(n.global_position, cup_flight)


func _on_head(i: int) -> void:
	if phase != Phase.SPRINKLERS:
		return
	var jet: Node3D = _jets[i][0]
	if not jet.visible:
		return
	jet.visible = false
	heads_out += 1
	Hud.note("Sprinklers: %d of %d" % [heads_out, HEADS.size()], 1.5)
	if heads_out >= HEADS.size():
		var tw := create_tween()
		tw.tween_method(_set_water, _water_y, 0.0, 2.0)
		tw.tween_callback(func() -> void: _water.visible = false)
		_start_tantrum()


# --- 3. the tantrum ------------------------------------------------------------------------------------------------

func _start_tantrum() -> void:
	phase = Phase.TANTRUM
	stage = Phase.TANTRUM
	_frozen = false
	_sitting = false
	Hud.caption("Gander", "My LAWN! My lovely LAWN! Fine. FINE!", 2.4)
	await _run_to(CONSERVATORY, 6.0)
	_throw_t = 1.0
	_face(nim().global_position)


func _tantrum_tick(delta: float) -> void:
	if _running or _frozen or _sitting:
		return
	var n := nim()
	_face(n.global_position)
	_show(0, 0.0)
	_throw_t -= delta
	if _throw_t <= 0.0:
		_throw_t = tantrum_every * _rng.randf_range(0.7, 1.2)
		_throw(n.global_position + Vector3(_rng.randf_range(-1.0, 1.0), 0, _rng.randf_range(-1.0, 1.0)), 0.85)


## Grizelda's Scold, said near her: she freezes mid-throw, then sits down.
func _on_scold(_text: String) -> void:
	if phase != Phase.TANTRUM or _frozen or _sitting or _running:
		return
	var n := nim()
	if n.global_position.distance_to(gander.global_position) > NimGear.SCOLD_RANGE:
		return
	_frozen = true
	_clear_cups()
	if gander is EnemyModel:
		(gander as EnemyModel).show_state(3, 0.0, 0.0, 1.0)
		(gander as EnemyModel).show_state(11, 0.0, 0.0, 1.0)   # frozen, mid-throw
	Hud.caption("Gander", "...", 1.5)
	await get_tree().create_timer(1.8).timeout
	if phase != Phase.TANTRUM:
		return
	# Then she sits down, on her own, on an upturned flowerpot.
	_pot = MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.22
	c.bottom_radius = 0.3
	c.height = 0.42
	_pot.mesh = c
	_pot.material_override = Look.toon(Color("b05a3a"))
	add_child(_pot)
	_pot.global_position = gander.global_position + Vector3(0, 0.21, 0)
	if gander is EnemyModel:
		var m := gander as EnemyModel
		m.hold(true)
		var sk := m.skeleton()
		if sk:
			_rig = RigGear.new(sk, gander)
			var drop := _rig.pose_sit()
			_rig.capture()
			gander.global_position.y -= drop * 0.9
	_frozen = false
	_sitting = true
	Hud.caption("Gander", "...I'd like to sit down now.", 2.2)
	Hud.note("She's sat down. A strike, and she's tied.", 2.5)


func _caught() -> void:
	if phase != Phase.TANTRUM:
		return
	phase = Phase.DONE
	_clear_cups()
	var cloud := ScuffleCloud.new()
	level.add_child(cloud)
	cloud.global_position = gander.global_position + Vector3(0, 0.6, 0.6)
	cloud.hide_while([gander])
	await get_tree().create_timer(1.3).timeout
	cloud.poof()
	if is_instance_valid(_pot):
		_pot.queue_free()
	set_flag("gander_bound")
	_on_bench()
	for g: Array in _guests:
		if is_instance_valid(g[0]):
			(g[0] as Node3D).queue_free()   # (her guests wander home, waking on the way)
	_guests.clear()
	await talk("gander", "bound")
	set_flag("order_book")
	_lock.collision_layer = 0
	var lawn := Vector3(BENCH.x, LAWN, BENCH.z)
	talker("Grizelda_garden", "grizelda", "garden_after", lawn + Vector3(-2.6, 0, 3.5), PI * 0.85, "grizelda", "garb", "",
		Color("b07060"))
	talker("Vesper_garden", "vesper", "garden_after", lawn + Vector3(2.6, 0, 3.9), -PI * 0.85, "vesper", "garb", "",
		Color("c0283e"))
	await get_tree().create_timer(0.5).timeout
	await talk("grizelda", "verdict_world")
	await level.complete(false)


## Bound to her own bench, under the sign she made herself.
func _on_bench() -> void:
	if _rig:
		_rig.clear()
		_rig = null
	if gander is EnemyModel:
		(gander as EnemyModel).hold(false)
	gander.global_position = BENCH
	gander.rotation.y = PI   # facing the garden (+Z)
	target.remove_from_group(&"hittable")
	_show(9, 0.0)
