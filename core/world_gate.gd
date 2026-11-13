class_name WorldGate
extends Area3D
## A world's way in (Banjo's walk-in entrances; WO-014): walk into it and she's in that world, at `arrival`. Put it
## behind the world's RankDoor, so the rank decides; if the world isn't open (or doesn't exist yet), it says so.

@export var world: StringName = &"pier"
@export var arrival := "hub"
@export var size := Vector3(4.0, 3.0, 2.0)

var _used := false


func _ready() -> void:
	add_to_group(&"world_gate")
	collision_layer = 0
	collision_mask = 1
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = size.y / 2.0
	add_child(col)
	body_entered.connect(_on_body)


func _on_body(b: Node) -> void:
	if not b is Nim or _used:
		return
	if not Game.SCENES.has(world):
		Hud.note("%s isn't built yet." % Game.NAMES.get(world, String(world)), 2.5)
		return
	if not Game.world_open(world):
		Hud.note("%s opens at a higher rank." % Game.NAMES.get(world, String(world)), 2.5)
		return
	_used = true
	Game.travel(Game.SCENES[world], arrival)
