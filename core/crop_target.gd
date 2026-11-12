class_name CropTarget
extends Node3D
## Something to hit (WO-007, the crop: "hits switches, bells and targets at range"): a switch that flips, a bell that
## rings, a target that drops. Any strike that reaches it works; most are placed so only the crop's reach does
## (out on a post, or up high). `hit` tells the level it's been struck.

signal hit

enum Kind { SWITCH, BELL, TARGET }

@export var kind := Kind.SWITCH

var hit_radius := 0.3
var struck := false
var _mesh: MeshInstance3D


func _ready() -> void:
	add_to_group(&"hittable")
	_mesh = MeshInstance3D.new()
	match kind:
		Kind.SWITCH:
			var b := BoxMesh.new()
			b.size = Vector3(0.12, 0.45, 0.12)
			_mesh.mesh = b
			_mesh.rotation.x = -0.6
		Kind.BELL:
			var c := CylinderMesh.new()
			c.top_radius = 0.1
			c.bottom_radius = 0.28
			c.height = 0.35
			_mesh.mesh = c
		Kind.TARGET:
			var c := CylinderMesh.new()
			c.top_radius = 0.35
			c.bottom_radius = 0.35
			c.height = 0.06
			_mesh.mesh = c
			_mesh.rotation.x = PI / 2.0
	_mesh.material_override = Look.toon(Look.BRASS if kind == Kind.BELL else Color("d04030"), 0.5)
	add_child(_mesh)


func can_be_hit() -> bool:
	return not struck or kind == Kind.BELL


func take_hit(_from: Vector3, _power: int) -> void:
	struck = true
	match kind:
		Kind.SWITCH:
			_mesh.rotation.x = 0.6
			_mesh.material_override = Look.toon(Color("40c060"), 0.5)
		Kind.BELL:
			var tw := create_tween()
			tw.tween_property(_mesh, ^"rotation:z", 0.5, 0.08)
			tw.tween_property(_mesh, ^"rotation:z", -0.4, 0.12)
			tw.tween_property(_mesh, ^"rotation:z", 0.0, 0.15)
		Kind.TARGET:
			var tw := create_tween()
			tw.tween_property(_mesh, ^"rotation:x", 0.0, 0.25)
	hit.emit()
