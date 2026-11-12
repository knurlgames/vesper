class_name Zone
extends Area3D
## A named part of a world (WO-008): walking into it puts its name on the HUD ("Under the Pier"). A box, `size`
## metres, centred on the node, floor at its origin.

@export var zone_name := ""
@export var size := Vector3(10, 4, 10)


func _ready() -> void:
	add_to_group(&"zone")
	collision_layer = 0
	collision_mask = 1
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = size.y / 2.0
	add_child(col)
	body_entered.connect(func(b: Node) -> void:
		if b is Nim:
			var hud := get_node_or_null(^"/root/Hud")
			if hud:
				hud.call(&"zone", zone_name))
