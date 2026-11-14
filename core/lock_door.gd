class_name LockDoor
extends StaticBody3D
## A pair of doors a story locks and unlocks (door audit, 2026-11-14: the Prize Hall's and Mrs Gander's back door were
## an invisible wall during their fights, and a block that vanished when they unlocked). They swing open away from
## the way in (+Z here: put the node's -Z toward where she comes from) and swing shut behind her; shut, they're solid.
##
##   var d := LockDoor.new(); d.width = 6.0; d.height = 5.0; d.colour = ...; d.locked = true; add_child(d)
##   d.unlock()   # swing open (animated); d.unlock(false) at once
##   d.lock()     # swing shut

@export var width := 2.0
@export var height := 2.4
@export var colour := Color("3a2420")
## Shut when it's built.
@export var locked := true

const SWING := deg_to_rad(92.0)

var _col: CollisionShape3D
var _leaves: Array[Node3D] = []


func _ready() -> void:
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height, 0.3)
	_col = CollisionShape3D.new()
	_col.shape = shape
	_col.position.y = height / 2.0
	add_child(_col)
	var thick := clampf(width * 0.03, 0.06, 0.14)
	for side: float in [-1.0, 1.0]:
		_leaves.append(DoorKit.panelled(self, Vector3(side * width / 2.0, 0, 0), width / 2.0, height, -side, colour, thick))
	_apply(locked, false)


func is_locked() -> bool:
	return locked


func lock(animate := true) -> Signal:
	return _apply(true, animate)


func unlock(animate := true) -> Signal:
	return _apply(false, animate)


func _apply(shut: bool, animate: bool) -> Signal:
	locked = shut
	_col.set_deferred(&"disabled", not shut)
	# Open, the left (hinged at -X, running +X) turns -, the right +: both away to +Z.
	var last := get_tree().process_frame if is_inside_tree() else Signal()
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var angle := 0.0 if shut else side * SWING
		if animate and is_inside_tree():
			last = DoorKit.swing(_leaves[i], angle, 0.9 if shut else 1.1)
		else:
			_leaves[i].rotation.y = angle
	return last
