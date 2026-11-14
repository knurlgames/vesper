class_name Checkpoint
extends Area3D
## A checkpoint (WO-004: generous, no lives): walking past it makes it where Nim comes back after she's downed. An
## invisible trigger at a key point (owner, 2026-11-14: "remove the explicit checkpoint flags throughout the game ...
## so they aren't more on-screen clutter"; it was a post with a velvet flag). The travel posts, which you can see and
## use, are checkpoints too (TravelPoint).

## The way she faces when she comes back here.
@export var yaw := 0.0

var _lit := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1   # Nim's layer; she's picked out by class below
	monitoring = true
	var shape := BoxShape3D.new()
	shape.size = Vector3(6.0, 4.0, 6.0)   # wide: with nothing to see, nobody aims for it
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = 2.0
	add_child(col)


func _physics_process(_delta: float) -> void:
	for b in get_overlapping_bodies():
		if b is Nim:
			_reach(b)


func _reach(_nim: Nim) -> void:
	var level := get_parent()
	while level and not level.has_method(&"checkpoint"):
		level = level.get_parent()
	if level:
		level.call(&"checkpoint", global_position, yaw, self)


## (Level.checkpoint lights the current one; there's nothing to see.)
func set_lit(on: bool) -> void:
	_lit = on
