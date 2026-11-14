class_name FetchBox
extends Node3D
## Something staff can be told to Fetch that isn't a key (core/key_item.gd is): a small box, a cake, a thermos. Its
## `id` is what Nim receives (NimSuit.keys).

@export var id: StringName = &"box"
@export var size := Vector3(0.3, 0.2, 0.3)
@export var colour := Color("e8e0d0")
## A second colour on its top (a cake's icing); transparent for none.
@export var top := Color.TRANSPARENT


func _ready() -> void:
	add_to_group(&"fetchable")
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = Look.toon(colour)
	m.position.y = size.y / 2.0
	add_child(m)
	if top.a > 0.0:
		var icing := MeshInstance3D.new()
		var ib := BoxMesh.new()
		ib.size = Vector3(size.x + 0.02, size.y * 0.25, size.z + 0.02)
		icing.mesh = ib
		icing.material_override = Look.toon(top, 0.3)
		icing.position.y = size.y + ib.size.y / 2.0 - 0.01
		add_child(icing)
