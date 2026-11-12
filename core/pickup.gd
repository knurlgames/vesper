class_name Pickup
extends Area3D
## A collectible (WO-008): a Key, a piece of contraband, or the Decency League's collection tin. Touch it and it's
## Game's (`collect(kind, world, id)`), gone for good; if it was already had when the level loads, it isn't there.
## Keys turn slowly, brass; contraband is a boxed toy with a spiral glow (never shown in use); the tin is cream and navy,
## and it has to be smashed (a strike), not walked into.

@export var kind: StringName = &"key"
## Unique within its world and kind.
@export var id: StringName = &""

var world: StringName = &"test"
## For the tin: struck, not touched.
var hit_radius := 0.35
var _mesh: Node3D
var _taken := false


func _ready() -> void:
	add_to_group(&"pickup")
	collision_layer = 0
	collision_mask = 1
	var n := get_parent()
	while n and not n.has_method(&"spawn_player"):
		n = n.get_parent()
	if n:
		world = n.get(&"world_id")
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
		_mesh.rotation.y += (1.5 if kind == &"key" else 0.8) * delta


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
	match kind:
		&"key":
			var bow := MeshInstance3D.new()
			var t := TorusMesh.new()
			t.inner_radius = 0.1
			t.outer_radius = 0.17
			bow.mesh = t
			bow.rotation.x = PI / 2.0
			bow.position.y = 0.22
			bow.material_override = Look.toon(Look.BRASS, 0.8, 0.0)
			_mesh.add_child(bow)
			var shaft := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(0.06, 0.42, 0.06)
			shaft.mesh = b
			shaft.position.y = -0.08
			shaft.material_override = Look.toon(Look.BRASS, 0.8)
			_mesh.add_child(shaft)
			var bit := MeshInstance3D.new()
			var bb := BoxMesh.new()
			bb.size = Vector3(0.14, 0.08, 0.06)
			bit.mesh = bb
			bit.position = Vector3(0.07, -0.24, 0)
			bit.material_override = Look.toon(Look.BRASS, 0.8)
			_mesh.add_child(bit)
			var glow := OmniLight3D.new()
			glow.light_color = Color("ffd890")
			glow.light_energy = 0.6
			glow.omni_range = 2.0
			_mesh.add_child(glow)
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
