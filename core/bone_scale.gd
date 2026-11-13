class_name BoneScale
extends SkeletonModifier3D
## Scales one bone (and everything under it) after the animation has posed the skeleton. Nim's head runs about 60%
## wider than the cast's Meshy heads (owner, on the Deck: "Nim's head is way larger than the rest of the cast"),
## so her model shrinks it in game rather than in the sculpt. Children ride along: the mask hangs on the head bone.

@export var bone_name := &"head"
@export var factor := 1.0

var _bone := -2


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if _bone == -2:
		_bone = sk.find_bone(bone_name)
	if _bone < 0 or is_equal_approx(factor, 1.0):
		return
	sk.set_bone_pose_scale(_bone, sk.get_bone_pose_scale(_bone) * factor)
