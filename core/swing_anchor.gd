class_name SwingAnchor
extends Node3D
## Something to swing from with the rope (WO-007): a ring on a beam, a crane hook, a rigging block. In the air with RB
## held, Nim catches the best one in reach and swings (Nim's SWING state). A brass ring on a short chain.


func _ready() -> void:
	add_to_group(&"tether_anchor")
	var ring := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.18
	t.outer_radius = 0.26
	ring.mesh = t
	ring.rotation.x = PI / 2.0
	ring.material_override = Look.toon(Look.BRASS, 0.7)
	ring.material_overlay = Look.outline(AABB(Vector3(-0.26, -0.04, -0.26), Vector3(0.52, 0.08, 0.52)), 0.01)
	add_child(ring)
	var chain := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.03
	c.bottom_radius = 0.03
	c.height = 0.6
	chain.mesh = c
	chain.position.y = 0.5
	chain.material_override = Look.toon(Look.INK)
	add_child(chain)
