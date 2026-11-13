class_name Pickup
extends Area3D
## A collectible (WO-008): a Key, a piece of contraband, or the Decency League's collection tin. Touch it and it's
## Game's (`collect(kind, world, id)`), gone for good; if it was already had when the level loads, it isn't there.
## Keys (Velvet Roses on screen: a crimson velvet rose) turn slowly; contraband is a boxed toy with a spiral glow (never shown in use); the tin is cream and navy,
## and it has to be smashed (a strike), not walked into.

@export var kind: StringName = &"key"
## Unique within its world and kind.
@export var id: StringName = &""

var world: StringName = &"test"
## Whose it is when that isn't the level it's in (a tin's rose is the hub's, tossed down on the Pier).
var world_override: StringName = &""
## For the tin: struck, not touched.
var hit_radius := 0.35
var _mesh: Node3D
var _taken := false
var _tossing := false

## A tossed rose's flight (toss_in).
const TOSS_TIME := 1.1
## The Meshy models, when they're there (tools/props.py); the primitives below are the fallback.
const ROSE_MODEL := "res://assets/props/velvet_rose.glb"
const BOX_MODEL := "res://assets/props/contraband_box.glb"


func _ready() -> void:
	add_to_group(&"pickup")
	collision_layer = 0
	collision_mask = 1
	var n := get_parent()
	while n and not n.has_method(&"spawn_player"):
		n = n.get_parent()
	if n:
		world = n.get(&"world_id")
	if world_override != &"":
		world = world_override
	var game := get_node_or_null(^"/root/Game")
	if game and game.call(&"has_collected", kind, world, id):
		queue_free()
		return
	var shape := SphereShape3D.new()
	shape.radius = 0.7
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = 0.8
	add_child(col)
	_build()
	if kind == &"tin":
		add_to_group(&"hittable")
	else:
		body_entered.connect(func(b: Node) -> void:
			if b is Nim:
				_take())


func _physics_process(delta: float) -> void:
	if _mesh and kind != &"tin":
		_mesh.rotation.y += (1.5 if kind == &"key" else 0.8) * delta * (6.0 if _tossing else 1.0)


## A deed's rose, thrown down from out of sight (the owner: an "encore"): from high up behind where it lands, away
## from the camera, it arcs down spinning over TOSS_TIME, can't be taken in the air, and lands with a burst of
## petals.
func toss_in() -> void:
	if _mesh == null or not is_inside_tree():
		return
	_tossing = true
	monitoring = false
	var land := _mesh.position
	var away := Vector3(0, 0, -1)
	var cam := get_viewport().get_camera_3d()
	if cam:
		away = global_position - cam.global_position
		away.y = 0.0
		away = away.normalized() if away.length() > 0.1 else Vector3(0, 0, -1)
	var start := land + global_basis.inverse() * (away * 5.0) + Vector3(0, 7.0, 0)
	_mesh.position = start
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		var p := start.lerp(land, t)
		p.y += sin(t * PI) * 1.5   # a lob, not a drop
		_mesh.position = p, 0.0, 1.0, TOSS_TIME)
	await tw.finished
	if not is_inside_tree():
		return
	_mesh.position = land
	_tossing = false
	monitoring = true
	_petals()
	# Already standing on the spot? It's hers. (The overlap list refreshes on the physics frames after monitoring's
	# back on; body_entered won't fire for someone already inside.)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree() or _taken:
		return
	for b in get_overlapping_bodies():
		if b is Nim:
			_take()


func _petals() -> void:
	var burst := CPUParticles3D.new()
	burst.one_shot = true
	burst.amount = 24
	burst.lifetime = 1.2
	burst.explosiveness = 0.95
	burst.direction = Vector3.UP
	burst.spread = 70.0
	burst.initial_velocity_min = 1.5
	burst.initial_velocity_max = 3.0
	burst.gravity = Vector3(0, -3.0, 0)
	burst.angular_velocity_min = -360.0
	burst.angular_velocity_max = 360.0
	burst.scale_amount_min = 0.6
	burst.scale_amount_max = 1.0
	var quad := QuadMesh.new()
	quad.size = Vector2(0.07, 0.05)
	var m := StandardMaterial3D.new()
	m.albedo_color = Look.VELVET.lightened(0.15)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material = m
	burst.mesh = quad
	burst.position.y = 0.9
	add_child(burst)
	burst.emitting = true
	get_tree().create_timer(2.0).timeout.connect(burst.queue_free)


func can_be_hit() -> bool:
	return kind == &"tin" and not _taken


## The tin, smashed.
func take_hit(_from: Vector3, _power: int) -> void:
	_take()


func _take() -> void:
	if _taken:
		return
	_taken = true
	var game := get_node_or_null(^"/root/Game")
	if game:
		game.call(&"collect", kind, world, id)
	queue_free()


func _build() -> void:
	_mesh = Node3D.new()
	_mesh.position.y = 0.8
	add_child(_mesh)
	var model_path := ROSE_MODEL if kind == &"key" else BOX_MODEL if kind == &"contraband" else ""
	if model_path != "" and ResourceLoader.exists(model_path):
		var model: Node3D = (load(model_path) as PackedScene).instantiate()
		# A world has 100 contraband: no outline and no light each (draw calls, lights). Its spiral's glow is its own.
		Look.dress(model, 0.008 if kind == &"key" else 0.0, 0.2 if kind == &"key" else 0.0, 0.0 if kind == &"key" else 1.2)
		_mesh.position.y = 0.45
		_mesh.add_child(model)
		if kind == &"key":
			_mesh.scale = Vector3.ONE * 1.3
			var glow := OmniLight3D.new()
			glow.light_color = Color("ff8a8a")
			glow.light_energy = 0.7
			glow.omni_range = 2.0
			glow.position.y = 0.4
			_mesh.add_child(glow)
		return
	match kind:
		&"key":
			# A Velvet Rose (owner, 2026-11-12: the Rope's rose for good work; "key" stays the code's word for it).
			# A dark stem with two leaves, a crimson velvet bloom (a cup, a bud, curled petals), velvet rim light.
			var stem_mat := Look.toon(Color("1e3a24"))
			var velvet := Look.toon(Look.VELVET.lightened(0.08), 0.0, 0.6)
			var stem := MeshInstance3D.new()
			var sc := CylinderMesh.new()
			sc.top_radius = 0.018
			sc.bottom_radius = 0.022
			sc.height = 0.4
			stem.mesh = sc
			stem.position.y = -0.07
			stem.material_override = stem_mat
			_mesh.add_child(stem)
			for side: float in [-1.0, 1.0]:
				var leaf := MeshInstance3D.new()
				var ls := SphereMesh.new()
				ls.radius = 0.06
				ls.height = 0.12
				leaf.mesh = ls
				leaf.scale = Vector3(1.0, 0.25, 0.5)
				leaf.position = Vector3(0.06 * side, -0.12 + 0.06 * side, 0)
				leaf.rotation.z = -0.5 * side
				leaf.material_override = stem_mat
				_mesh.add_child(leaf)
			var cup := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.14
			cm.bottom_radius = 0.035
			cm.height = 0.12
			cup.mesh = cm
			cup.position.y = 0.18
			cup.material_override = velvet
			_mesh.add_child(cup)
			var bud := MeshInstance3D.new()
			var bm := SphereMesh.new()
			bm.radius = 0.095
			bm.height = 0.16
			bud.mesh = bm
			bud.position.y = 0.25
			bud.material_override = velvet
			_mesh.add_child(bud)
			for i in 5:
				var a := TAU * i / 5.0
				var petal := MeshInstance3D.new()
				var pm := SphereMesh.new()
				pm.radius = 0.09
				pm.height = 0.18
				petal.mesh = pm
				petal.scale = Vector3(1.0, 0.8, 0.35)
				petal.position = Vector3(cos(a) * 0.095, 0.22, sin(a) * 0.095)
				petal.rotation = Vector3(0.0, -a + PI / 2.0, 0.0)
				petal.material_override = velvet
				_mesh.add_child(petal)
			var glow := OmniLight3D.new()
			glow.light_color = Color("ff8a8a")
			glow.light_energy = 0.7
			glow.omni_range = 2.0
			glow.position.y = 0.2
			_mesh.add_child(glow)
			_mesh.scale = Vector3.ONE * 1.5   # readable at a distance, like the key it replaced
		&"contraband":
			var box := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(0.22, 0.3, 0.12)
			box.mesh = b
			box.material_override = Look.toon(Color("e0d0e8"))
			_mesh.add_child(box)
			var spiral := MeshInstance3D.new()
			var t := TorusMesh.new()
			t.inner_radius = 0.04
			t.outer_radius = 0.08
			spiral.mesh = t
			spiral.rotation.x = PI / 2.0
			spiral.position.z = -0.07
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(0.5, 0.8, 2.2)
			spiral.material_override = m
			_mesh.add_child(spiral)
		&"tin":
			_mesh.position.y = 0.0
			var can := MeshInstance3D.new()
			var c := CylinderMesh.new()
			c.top_radius = 0.16
			c.bottom_radius = 0.16
			c.height = 0.32
			can.mesh = c
			can.position.y = 1.0
			can.material_override = Look.toon(Look.DECENCY_CREAM)
			_mesh.add_child(can)
			var band := MeshInstance3D.new()
			var bc := CylinderMesh.new()
			bc.top_radius = 0.165
			bc.bottom_radius = 0.165
			bc.height = 0.1
			band.mesh = bc
			band.position.y = 1.0
			band.material_override = Look.toon(Look.DECENCY_NAVY)
			_mesh.add_child(band)
			var post := MeshInstance3D.new()
			var p := CylinderMesh.new()
			p.top_radius = 0.04
			p.bottom_radius = 0.06
			p.height = 0.84
			post.mesh = p
			post.position.y = 0.42
			post.material_override = Look.toon(Look.INK)
			_mesh.add_child(post)
			var label := Label3D.new()
			label.text = "GIVE\nGENEROUSLY\nto DECENCY"   # OWNER REVIEW
			label.font_size = 20
			label.pixel_size = 0.004
			label.modulate = Look.DECENCY_NAVY
			label.position = Vector3(0, 1.0, -0.17)
			label.rotation.y = PI
			label.double_sided = false
			_mesh.add_child(label)
