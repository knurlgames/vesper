class_name TranceDevice
extends Node3D
## The toy an entranced person holds: a boxed shape with a cold spiral glow (ART_DIRECTION.md: never shown in use).
## A strike breaks it, but only from in front of whoever holds it: from behind, a strike passes through them and
## the device both, so a fight can't wake anyone by accident.

## How far past its centre a strike can still reach it.
var hit_radius := 0.25


func _ready() -> void:
	add_to_group(&"hittable")
	var box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.22, 0.3, 0.12)
	box.mesh = mesh
	box.material_override = Look.toon(Color("e8e0f0"))
	add_child(box)
	var glow := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.05
	ring.outer_radius = 0.09
	glow.mesh = ring
	glow.rotation.x = PI / 2.0
	glow.position.z = -0.07
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.5, 0.8, 2.2)
	glow.material_override = m
	add_child(glow)


func can_be_hit() -> bool:
	return true


func take_hit(from: Vector3, _power: int) -> void:
	var holder := get_parent() as Node3D
	if holder == null or not holder.has_method(&"wake"):
		return
	var to_attacker := from - holder.global_position
	to_attacker.y = 0.0
	if to_attacker.dot(holder.call(&"facing")) > 0.0:
		holder.call(&"wake")
