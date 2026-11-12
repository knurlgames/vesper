class_name KeyItem
extends Node3D
## Something staff can be told to Fetch (WO-006): a key on a hook, brass and readable. Its `id` is what Nim receives.

@export var id: StringName = &"key"


func _ready() -> void:
	add_to_group(&"fetchable")
	var ring := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.04
	t.outer_radius = 0.07
	ring.mesh = t
	ring.rotation.x = PI / 2.0
	ring.material_override = Look.toon(Look.BRASS, 0.7)
	add_child(ring)
	var shaft := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.03, 0.18, 0.02)
	shaft.mesh = b
	shaft.position.y = -0.14
	shaft.material_override = Look.toon(Look.BRASS, 0.7)
	add_child(shaft)
