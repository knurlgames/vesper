class_name Sight
extends RefCounted
## Can a watcher see Nim? Shared by goons and lookouts (WO-005). A cone and a line of sight, out to a range that
## shrinks in the dark and when she's crouched: shadows are where she's safe. Close enough, and she's noticed whatever
## the light.

## In full dark her outline carries this fraction of the range; in a lamp's pool, all of it.
const DARK_SIGHT := 0.25
## Crouched, a further fraction.
const CROUCH_SIGHT := 0.5


## How far away she can be seen right now, by a watcher whose full range is `base`.
static func range_for(nim: Node3D, base: float) -> float:
	var light: float = nim.get(&"light") if nim.get(&"light") != null else 1.0
	var r := base * lerpf(DARK_SIGHT, 1.0, light)
	if nim.get(&"crouching") == true:
		r *= CROUCH_SIGHT
	return r


## True if a watcher with eyes at `eye`, looking along `look` (flat), sees her: in range, inside `half_angle` of the
## look (or within `bump` whichever way), and nothing in between. `exclude` is the watcher's own body.
static func sees(eye: Vector3, look: Vector3, nim: Node3D, base: float, half_angle: float, bump: float,
		space: PhysicsDirectSpaceState3D, exclude: Array[RID] = []) -> bool:
	# The suit (WO-006): faking a trance, she's ignored outright; strutting in a crowd, she's one of the guests.
	var suit: Object = nim.get(&"suit")
	if suit and suit.get(&"faking_trance") == true:
		return false
	var chest := nim.global_position + Vector3.UP * 1.0
	var to := chest - eye
	var flat := Vector2(to.x, to.z)
	var dist := flat.length()
	if dist < bump and absf(to.y) < 2.0:
		return true
	if suit and suit.get(&"hidden_in_crowd") == true:
		return false
	# In the suit, with her cover, she walks in the open: the dark doesn't hide her and she doesn't need it to.
	var open_suit: bool = suit != null and suit.get(&"outfit") == 1 and suit.get(&"cover_blown") == false
	if dist > (base if open_suit else range_for(nim, base)):
		return false
	var look_flat := Vector2(look.x, look.z)
	if dist > 0.01 and look_flat.length() > 0.01 and absf(look_flat.angle_to(flat)) > half_angle:
		return false
	var skip := exclude.duplicate()
	if nim is CollisionObject3D:
		skip.append((nim as CollisionObject3D).get_rid())
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, chest, 1, skip)).is_empty()
