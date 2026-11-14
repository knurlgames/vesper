class_name RigGear
extends RefCounted
## Poses and gear on a character's bones, built in code, for the club's scenes (WO-014b): the cross, the rope frame,
## the parlour. Works on both rigs: Meshy's (the cast and the clients: LeftArm, Spine, Head...) and Nim's own
## (upper_arm.L, chest, head). The helpers came out of core/cross_scene.gd, whose bones are Nine Lives' After Hours
## (code only).
##
## The model must be held first (its `hold(true)`: the clips stop, frozen on idle). Then pose (aim bones, turn them),
## `capture()` the pose as the base, and each frame `restore()` and add what moves (a sway, a breath, an arm swinging).
##
## Meshy's skeletons carry a 0.01 scale (their meshes are in centimetres): gear is set through the bone's inverse,
## never just parented there (a cuff parented plainly came out a hundredth of its size).

var sk: Skeleton3D
## The character's root: its -Z is their front.
var body: Node3D
## Bone names by role (bones_for).
var b: Dictionary
## Everything hung on them, freed by clear().
var gear: Array[Node] = []
var _base := {}

const ROPE := Color("b8283c")      # the Claw's red
const ROPE_TAN := Color("c8a070")
const LEATHER := Color("1c1418")


func _init(skeleton: Skeleton3D, owner_body: Node3D) -> void:
	sk = skeleton
	body = owner_body
	b = bones_for(sk)


static func bones_for(s: Skeleton3D) -> Dictionary:
	if s.find_bone("LeftArm") >= 0:
		return {"hips": "Hips", "spine": "Spine01", "chest": "Spine", "shoulderL": "LeftShoulder",
			"shoulderR": "RightShoulder", "armL": "LeftArm", "forearmL": "LeftForeArm", "handL": "LeftHand",
			"armR": "RightArm", "forearmR": "RightForeArm", "handR": "RightHand", "thighL": "LeftUpLeg",
			"shinL": "LeftLeg", "footL": "LeftFoot", "thighR": "RightUpLeg", "shinR": "RightLeg", "footR": "RightFoot",
			"neck": "neck", "head": "Head", "head_end": "head_end", "front": "headfront"}
	return {"hips": "hips", "spine": "spine", "chest": "chest", "shoulderL": "shoulder.L", "shoulderR": "shoulder.R",
		"armL": "upper_arm.L", "forearmL": "forearm.L", "handL": "hand.L", "armR": "upper_arm.R",
		"forearmR": "forearm.R", "handR": "hand.R", "thighL": "thigh.L", "shinL": "shin.L", "footL": "foot.L",
		"thighR": "thigh.R", "shinR": "shin.R", "footR": "foot.R", "neck": "neck", "head": "head", "head_end": "",
		"front": ""}


## A role's bone name ("armL"), or the name itself.
func bone(role: String) -> String:
	return b.get(role, role)


## Where a bone is, in the world.
func pos(role: String) -> Vector3:
	var i := sk.find_bone(bone(role))
	return (sk.global_transform * sk.get_bone_global_pose(i)).origin if i >= 0 else body.global_position


func fwd() -> Vector3:
	var f := -body.global_basis.z
	f.y = 0.0
	return f.normalized()


## Their left, read off the body itself (its left arm's side).
func left() -> Vector3:
	sk.force_update_all_bone_transforms()
	var l := pos("armL") - pos("armR")
	l.y = 0.0
	return l.normalized() if l.length() > 0.01 else body.global_basis.x * -1.0


## About how wide their shoulders are, for sizing a harness to the body.
func shoulder_span() -> float:
	sk.force_update_all_bone_transforms()
	return maxf((pos("armL") - pos("armR")).length(), 0.2)


# --- posing ------------------------------------------------------------------------------------------------------------

## Turns `role` so the way to `child` points along `dir` (world).
func aim(role: String, child: String, dir: Vector3) -> void:
	var bi := sk.find_bone(bone(role))
	var ci := sk.find_bone(bone(child))
	if bi < 0 or ci < 0 or dir.length() < 0.001:
		return
	sk.force_update_all_bone_transforms()
	var want := (sk.global_basis.inverse() * dir).normalized()
	var g := sk.get_bone_global_pose(bi)
	var now := sk.get_bone_global_pose(ci).origin - g.origin
	if now.length() < 0.0001:
		return
	now = now.normalized()
	var turned := Transform3D(Basis(Quaternion(now, want)) * g.basis, g.origin)
	var p := sk.get_bone_parent(bi)
	var pg := sk.get_bone_global_pose(p) if p >= 0 else Transform3D()
	sk.set_bone_pose_rotation(bi, (pg.affine_inverse() * turned).basis.get_rotation_quaternion())


## Turns `role` by `angle` about a world axis through it (a lean, a flinch, a dropped chin).
func turn(role: String, axis: Vector3, angle: float) -> void:
	var bi := sk.find_bone(bone(role))
	if bi < 0 or absf(angle) < 0.0001:
		return
	sk.force_update_all_bone_transforms()
	var a := (sk.global_basis.inverse() * axis).normalized()
	var g := sk.get_bone_global_pose(bi)
	var turned := Transform3D(Basis(a, angle) * g.basis, g.origin)
	var p := sk.get_bone_parent(bi)
	var pg := sk.get_bone_global_pose(p) if p >= 0 else Transform3D()
	sk.set_bone_pose_rotation(bi, (pg.affine_inverse() * turned).basis.get_rotation_quaternion())


## Keeps the pose as it is now as the base restore() goes back to.
func capture() -> void:
	_base.clear()
	for i in sk.get_bone_count():
		_base[i] = sk.get_bone_pose_rotation(i)


func restore() -> void:
	for i: int in _base:
		sk.set_bone_pose_rotation(i, _base[i])


## The base pose as it stands, to come back to (a scene that moves her between poses keeps her neutral one).
func snapshot() -> Dictionary:
	return _base.duplicate()


## Back to a snapshot as the base, and onto the bones.
func reset_to(base: Dictionary) -> void:
	_base = base.duplicate()
	restore()


## Arms up and out in an X, legs a little apart (the cross; After Hours' _pose_x).
func pose_x(up := 0.87, spread := 0.22) -> void:
	var l := left()
	for s: Array in [["L", 1.0], ["R", -1.0]]:
		var side: Vector3 = l * float(s[1])
		var arm := side * cos(up) + Vector3.UP * sin(up)
		aim("arm" + s[0], "forearm" + s[0], arm)
		aim("forearm" + s[0], "hand" + s[0], arm)
		aim("thigh" + s[0], "shin" + s[0], side * spread + Vector3.DOWN)
		aim("shin" + s[0], "foot" + s[0], side * spread + Vector3.DOWN)


## Wrists together over the head, a little forward (tied up to a frame's beam).
func pose_arms_up() -> void:
	var l := left()
	var f := fwd()
	for s: Array in [["L", 1.0], ["R", -1.0]]:
		var side: Vector3 = l * float(s[1])
		aim("arm" + s[0], "forearm" + s[0], Vector3.UP * 0.9 + side * 0.42 + f * 0.08)
		aim("forearm" + s[0], "hand" + s[0], Vector3.UP * 0.75 - side * 0.62 + f * 0.06)
		aim("thigh" + s[0], "shin" + s[0], side * 0.06 + Vector3.DOWN)
		aim("shin" + s[0], "foot" + s[0], side * 0.06 + Vector3.DOWN)


## Hands clasped behind the back, shoulders back (a posture to hold).
func pose_hands_behind() -> void:
	var l := left()
	var f := fwd()
	for s: Array in [["L", 1.0], ["R", -1.0]]:
		var side: Vector3 = l * float(s[1])
		aim("arm" + s[0], "forearm" + s[0], Vector3.DOWN + side * 0.22 - f * 0.3)
		aim("forearm" + s[0], "hand" + s[0], -side * 0.9 - f * 0.4 + Vector3.DOWN * 0.15)


## Seated: thighs forward, shins down, hands on the thighs. Returns how far to lower the body so the hips sit where
## the knees were (the seat's about shin height).
func pose_sit(feet_up := 0.0) -> float:
	var l := left()
	var f := fwd()
	var thigh := (pos("shinL") - pos("thighL")).length()
	for s: Array in [["L", 1.0], ["R", -1.0]]:
		var side: Vector3 = l * float(s[1])
		aim("thigh" + s[0], "shin" + s[0], f + side * 0.12 + Vector3.UP * feet_up * 0.15)
		# feet_up 0: shins straight down; toward 1, out in front (onto a footstool).
		aim("shin" + s[0], "foot" + s[0], Vector3.DOWN + f * (0.12 + feet_up))
		aim("arm" + s[0], "forearm" + s[0], Vector3.DOWN + f * 0.35 + side * 0.15)
		aim("forearm" + s[0], "hand" + s[0], f + Vector3.DOWN * 0.25)
	return thigh


## Kneeling up: thighs straight down, shins flat behind. Returns how far to lower the body (the shin's length).
func pose_kneel() -> float:
	var l := left()
	var f := fwd()
	var shin := (pos("footL") - pos("shinL")).length()
	for s: Array in [["L", 1.0], ["R", -1.0]]:
		var side: Vector3 = l * float(s[1])
		aim("thigh" + s[0], "shin" + s[0], Vector3.DOWN + side * 0.1 + f * 0.05)
		aim("shin" + s[0], "foot" + s[0], -f + Vector3.DOWN * 0.08)
	return shin


## Wrists offered, forward and together (for cuffs).
func pose_wrists_out() -> void:
	var l := left()
	var f := fwd()
	for s: Array in [["L", 1.0], ["R", -1.0]]:
		var side: Vector3 = l * float(s[1])
		aim("arm" + s[0], "forearm" + s[0], Vector3.DOWN * 0.7 + f * 0.6 + side * 0.08)
		aim("forearm" + s[0], "hand" + s[0], f - side * 0.25 + Vector3.UP * 0.1)


## The right arm reaching for a point in the world (the hand that holds the tool), elbow a little bent.
func reach(target: Vector3, side := "R") -> void:
	var sh := pos("arm" + side)
	var d := target - sh
	if d.length() < 0.01:
		return
	d = d.normalized()
	aim("arm" + side, "forearm" + side, (d + Vector3.DOWN * 0.3).normalized())
	aim("forearm" + side, "hand" + side, d)


# --- gear --------------------------------------------------------------------------------------------------------------

## Hung on a bone, turned with it (its +Y along the bone), `offset` in that frame.
func attach(role: String, what: Node3D, offset := Vector3.ZERO) -> Node3D:
	var i := sk.find_bone(bone(role))
	if i < 0:
		what.free()
		return null
	sk.force_update_all_bone_transforms()
	var bg := sk.global_transform * sk.get_bone_global_pose(i)
	var basis := bg.basis.orthonormalized()
	var a := BoneAttachment3D.new()
	a.bone_name = bone(role)
	sk.add_child(a)
	a.add_child(what)
	what.transform = bg.affine_inverse() * Transform3D(basis, bg.origin + basis * offset)
	gear.append(a)
	return what


## Hung on a bone but laid out in the world's frame: `what`'s middle at `at`, its +Z along `face`, its +Y up.
func wear(role: String, what: Node3D, at: Vector3, face: Vector3, up := Vector3.UP) -> Node3D:
	var i := sk.find_bone(bone(role))
	if i < 0:
		what.free()
		return null
	sk.force_update_all_bone_transforms()
	var bg := sk.global_transform * sk.get_bone_global_pose(i)
	var a := BoneAttachment3D.new()
	a.bone_name = bone(role)
	sk.add_child(a)
	a.add_child(what)
	what.transform = bg.affine_inverse() * Transform3D(Basis.looking_at(-face, up), at)
	gear.append(a)
	return what


## A band round a bone (a cuff, a collar), along the bone.
## Returns its fit: scale that across (x and z) to loosen or tighten it on the limb, buckle and all.
func band(role: String, radius: float, c: Color, buckle: bool, along := 0.0) -> Node3D:
	var root := Node3D.new()
	var n := Node3D.new()
	root.add_child(n)
	var t := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = radius
	var tube := clampf(radius * 0.45, 0.016, 0.03)
	tm.outer_radius = radius + tube
	t.mesh = tm
	t.scale = Vector3(1.0, 1.6, 1.0)   # a cuff is wider than its tube is thick
	t.material_override = Look.toon(c, 0.3)
	n.add_child(t)
	if buckle:
		var bk := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.03, 0.03, 0.015)
		bk.mesh = bm
		bk.material_override = Look.toon(Look.BRASS, 0.7)
		bk.position = Vector3(0, 0, radius + tube)
		n.add_child(bk)
	attach(role, root, Vector3(0, along, 0))
	return n


## A cuff on a wrist or ankle ("wristL", "ankleR", ...), fitted to this body: round the end of the forearm or shin
## (the foot's and hand's bones run off along the foot and hand, so a ring round them sat tilted round the heel and
## knuckles: owner, "Straps not fully lined up"), as wide as the limb is there, measured off the mesh.
func cuff(where: String, c: Color, buckle := true) -> Node3D:
	var side := where.right(1)
	var limb := "shin" if where.begins_with("ankle") else "forearm"
	var tip := "foot" if limb == "shin" else "hand"
	var length := (pos(tip + side) - pos(limb + side)).length()
	var along := length * (0.86 if limb == "shin" else 0.88)
	# The wrist or ankle is the limb's narrowest: the thinnest of a few slabs up it (one slab at the end caught Nim's
	# hand and gave her a bangle wider than her shin).
	var fallback := 0.05 if limb == "shin" else 0.044
	var r := INF
	for k: float in [0.62, 0.72, 0.8, along / length]:
		r = minf(r, girth(limb + side, length * k, fallback))
	return band(limb + side, r + 0.006, c, buckle, along)


## How far the skin stands off a bone's axis `along` it (metres from its head): the 85th percentile of the skinned
## vertices in a thin slab there, or `fallback` if there aren't enough to tell.
func girth(role: String, along: float, fallback: float) -> float:
	var bi := sk.find_bone(bone(role))
	if bi < 0:
		return fallback
	sk.force_update_all_bone_transforms()
	var g := sk.global_transform * sk.get_bone_global_pose(bi)
	var axis := g.basis.y.normalized()
	# Along the limb itself, to the next joint, where there is one: a bone rolled off the limb's line slices it
	# on the slant and reads it fat.
	var next := {"forearm": "hand", "shin": "foot", "upperarm": "forearm", "thigh": "shin"}
	var key := role.left(-1)
	if next.has(key):
		var to := pos(String(next[key]) + role.right(1)) - g.origin
		if to.length() > 0.05:
			axis = to.normalized()
	var at := g.origin + axis * along
	var dists: Array[float] = []
	for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or mi.skin == null or mi.name.ends_with("_Mask") or not mi.is_visible_in_tree():
			continue
		var skin := mi.skin
		var bind := -1
		for b in skin.get_bind_count():
			if skin.get_bind_name(b) == sk.get_bone_name(bi) or skin.get_bind_bone(b) == bi:
				bind = b
				break
		if bind < 0:
			continue
		var to_world := sk.global_transform * sk.get_bone_global_pose(bi) * skin.get_bind_pose(bind)
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bones = arr[Mesh.ARRAY_BONES]
			var weights = arr[Mesh.ARRAY_WEIGHTS]
			if bones == null or weights == null:
				continue
			var per := (bones as Array).size() / maxi(verts.size(), 1)
			for v in verts.size():
				var w := 0.0
				for k in per:
					if int(bones[v * per + k]) == bind:
						w += float(weights[v * per + k])
				if w < 0.3:
					continue
				var p := to_world * verts[v]
				var rel := p - at
				var t := rel.dot(axis)
				if absf(t) > 0.025:
					continue
				dists.append((rel - axis * t).length())
	if dists.size() < 8:
		return fallback
	dists.sort()
	return clampf(dists[int(dists.size() * 0.85)], 0.025, 0.12)


## Rope wrapped round a bone: `turns` thin coils side by side, and a knot.
func wrap(role: String, radius: float, along := 0.0, turns := 3, c := ROPE) -> void:
	var n := Node3D.new()
	var tube := 0.011
	for k in turns:
		var t := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = radius
		tm.outer_radius = radius + tube * 2.0
		tm.rings = 20
		tm.ring_segments = 8
		t.mesh = tm
		t.position.y = (k - (turns - 1) / 2.0) * tube * 2.1
		t.material_override = Look.toon(c, 0.15)
		n.add_child(t)
	var knot := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = tube * 2.2
	sm.height = tube * 4.4
	knot.mesh = sm
	knot.position = Vector3(0, 0, radius + tube)
	knot.material_override = Look.toon(c, 0.15)
	n.add_child(knot)
	attach(role, n, Vector3(0, along, 0))


## A rope harness round the chest: a band above it and one below, joined down the front by a strand and a knot,
## laid level with the body (an oval: wider than it's deep).
func harness(c := ROPE) -> void:
	sk.force_update_all_bone_transforms()
	var half := shoulder_span() * 0.5
	var f := fwd()
	# Placed by the torso's length (shoulders to hips), not by bones: the rigs put their chest bones at different
	# heights (on the Meshy rig it's at the collarbones, and a band there read as a choker).
	var top := (pos("armL").y + pos("armR").y) / 2.0
	var torso := maxf(top - pos("hips").y, 0.2)
	var mid := pos("chest")
	var upper := Vector3(mid.x, top - torso * 0.14, mid.z)
	var lower := Vector3(mid.x, top - torso * 0.54, mid.z)
	var du := half * 0.66
	var dl := half * 0.8
	wear("chest", oval(half * 0.92, du, 0.022, c), upper, f)
	wear("chest", oval(half * 0.86, dl, 0.022, c), lower, f)
	var a := upper + f * du
	var b2 := lower + f * dl
	var strand := MeshInstance3D.new()
	strand.mesh = _cyl(0.011, (a - b2).length())
	strand.material_override = Look.toon(c, 0.15)
	wear("chest", strand, (a + b2) / 2.0, f)
	var knot := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.022
	sm.height = 0.044
	knot.mesh = sm
	knot.material_override = Look.toon(c, 0.15)
	wear("chest", knot, a.lerp(b2, 0.35) + f * 0.01, f)


## The head in world space: its middle, which way the face points, its size; where the eyes and mouth are. Meshy's
## rigs carry headfront and head_end; Nim's own rig is measured from her head bone and her model's facing.
func head_frame() -> Dictionary:
	sk.force_update_all_bone_transforms()
	var head := pos("head")
	var f0 := fwd()
	# Nim's head bone sits low in her head (her rig has no top or front bones): measured off her model. These are the
	# v15 head's (0.75 of the A-pose head's top 0.3, front 0.12 up / 0.3 out, neck 0.06, eyes 0.05: nim_build.py
	# HEAD_SHRINK).
	var top := head + Vector3.UP * 0.28
	var front := head + Vector3.UP * 0.09 + f0 * 0.23   # past her muzzle's goggles, so a blindfold goes over them
	var neck_r := 0.045
	var eye_up := 0.04   # her eyes sit higher in her head than the Meshy heads' do
	if b.front != "" and sk.find_bone(b.front) >= 0:
		front = pos("front")
		top = pos("head_end")
		neck_r = 0.0
		eye_up = 0.0
	var span := maxf((top - head).length(), 0.12)
	# Cartoon heads are big for their bones: the head's half-width is most of the way from its root to its top.
	var r := clampf(span * 0.55, 0.09, 0.18)
	var mid := head + Vector3.UP * span * 0.42
	var f := front - mid
	f.y = 0.0
	if f.length() < 0.02:
		f = f0
	var reach_f := clampf(f.length(), r * 0.8, r * 2.2)
	if neck_r == 0.0:
		neck_r = r * 0.62
	f = f.normalized()
	return {"mid": mid, "fwd": f, "r": r, "reach": reach_f, "front": front, "neck_r": neck_r,
		"eyes": mid + Vector3.UP * eye_up + f * reach_f * 0.55,
		"mouth": mid + Vector3.DOWN * span * 0.36 + f * reach_f * 0.85}


const TAPE := Color("2a2a30")
## Duct tape: the bosses' (owner, 2026-11-14), silver, so it reads on a black nose.
const DUCT := Color("a4a7ae")
## What colour the next tape gag is (TAPE, the club's black, unless set).
var tape_colour := TAPE


## The face as it is, read off the mesh (owner, 2026-11-13: tape "bleeding through on Augusta's face"; a gag sized
## from the head's bones alone sank into some faces and floated off others). The head's own vertices, skinned to
## where the head bone is now, measured in the face's frame:
##   fwd, up, side: the face's axes; nose: the snout's tip; mouth: the front of the snout just under it (where a
##   gag sits); snout_w: the snout's half width there; head_w / head_back: the head's half width and how far back it
##   goes at that height (a strap round the head). Empty if there's no skinned mesh to read.
func face() -> Dictionary:
	var head_i := sk.find_bone(bone("head"))
	if head_i < 0:
		return {}
	var pts: Array[Vector3] = []
	sk.force_update_all_bone_transforms()
	# The head and every bone under it: a jaw, a beak, a snout bone (Mrs Gander's beak and Laffer's muzzle hang off
	# their own, and measured off the head bone alone the tape went inside them; owner, 2026-11-14).
	var under := {head_i: true}
	var grew := true
	while grew:
		grew = false
		for bi in sk.get_bone_count():
			if not under.has(bi) and under.has(sk.get_bone_parent(bi)):
				under[bi] = true
				grew = true
	for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or mi.skin == null or mi.name.ends_with("_Mask") or not mi.is_visible_in_tree():
			continue
		var skin := mi.skin
		# Each bind that's the head's or under it, and where it puts a vertex now.
		var xf := {}
		for bnd in skin.get_bind_count():
			var bi := skin.get_bind_bone(bnd)
			if bi < 0:
				bi = sk.find_bone(skin.get_bind_name(bnd))
			if bi >= 0 and under.has(bi):
				xf[bnd] = sk.global_transform * sk.get_bone_global_pose(bi) * skin.get_bind_pose(bnd)
		if xf.is_empty():
			continue
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bones = arr[Mesh.ARRAY_BONES]
			var weights = arr[Mesh.ARRAY_WEIGHTS]
			if bones == null or weights == null:
				continue
			var per := (bones as Array).size() / maxi(verts.size(), 1)
			for v in verts.size():
				var w := 0.0
				var top := -1
				var top_w := 0.0
				for k in per:
					var bnd := int(bones[v * per + k])
					var wk := float(weights[v * per + k])
					if xf.has(bnd):
						w += wk
						if wk > top_w:
							top_w = wk
							top = bnd
				if w > 0.3 and top >= 0:
					pts.append((xf[top] as Transform3D) * verts[v])
	if pts.size() < 30:
		return {}
	var hf := head_frame()
	# The head's own frame: how far the head bone has turned since its rest, applied to the body's level forward and
	# up. A head tipped back (Laffer's, tied on his prize mountain) points the muzzle up: measured level, it read as a
	# short face and the tape went under his chin (owner, 2026-11-14).
	var g := sk.global_transform.basis
	var now_b := (g * sk.get_bone_global_pose(head_i).basis).orthonormalized()
	var rest_b := (g * sk.get_bone_global_rest(head_i).basis).orthonormalized()
	var turn := now_b * rest_b.inverse()
	var f := (turn * fwd()).normalized()
	var up := (turn * Vector3.UP).normalized()
	var side := up.cross(f).normalized()
	up = f.cross(side).normalized()
	var head_at := pos("head")
	var mid: Vector3 = head_at + up * (Vector3(hf.mid) - head_at).length()
	# The nose: the highest of the points nearly as far forward as any (a jutting chin or lip can be the furthest).
	# Only at or under the head's middle: a hat's brim is skinned to the head too, and Laffer's boater stands out
	# further than his snout (owner, 2026-11-14: the tape went round his hat).
	var low: float = float(hf.r) * 0.3
	var far := -INF
	for p in pts:
		if (p - mid).dot(up) < low:
			far = maxf(far, (p - mid).dot(f))
	var nose := pts[0]
	var ny := -INF
	for p in pts:
		var d := p - mid
		var dy := d.dot(up)
		if dy < low and d.dot(f) > far - 0.012 and dy > ny:
			ny = dy
			nose = p
	# The mouth: a little under the nose, where a gag sits.
	var mouth_y := ny - 0.03
	var mouth := nose
	var best := -INF
	var widths: Array[float] = []
	var backs: Array[float] = []
	for p in pts:
		var d := p - mid
		if absf(d.dot(up) - mouth_y) < 0.015:
			if d.dot(f) > best:
				best = d.dot(f)
				mouth = p
			widths.append(absf(d.dot(side)))
			backs.append(-d.dot(f))
	if widths.is_empty():
		return {}
	widths.sort()
	backs.sort()
	# Most of the head, not its furthest wisp of fur.
	var head_w := widths[int(widths.size() * 0.9)]
	var back := backs[int(backs.size() * 0.95)]
	var snouts: Array[float] = []
	for p in pts:
		var d := p - mid
		if absf(d.dot(up) - mouth_y) < 0.015 and d.dot(f) > best - 0.04:
			snouts.append(absf(d.dot(side)))
	snouts.sort()
	var snout_w := snouts[int(snouts.size() * 0.9)] if not snouts.is_empty() else head_w * 0.5
	# The lips: between the nose and the chin (the lowest skin at the front of the snout), a little nearer the nose
	# (owner, 2026-11-13: tape "sit too high on their noses and not across their mouths" at the nose less 3 cm).
	var chin := ny
	for p in pts:
		var d := p - mid
		if d.dot(f) > far - 0.06 and d.dot(up) < chin:
			chin = d.dot(up)
	var lips_y := lerpf(ny, chin, 0.6) if ny - chin > 0.03 else mouth_y
	# (Heights, mouth_y and lips_y among them, are along `up`, the head's own, from `mid`.)
	return {"fwd": f, "side": side, "up": up, "mid": mid, "nose": nose, "mouth": mouth, "front": best,
		"snout_w": snout_w, "head_w": head_w, "head_back": back, "mouth_y": mouth_y, "pts": pts, "lips_y": lips_y,
		"jaw": ny - chin}


## A gag on the head (owner, 2026-11-13: "ball, bit, or tape gags"), from head_frame(): the ball or bit on a strap
## round the head at the mouth, or tape wound round the muzzle (every face here has a snout: a flat strip across
## one floats). Returns it worn, or null.
func gag(kind: String) -> Node3D:
	if kind == "" or kind == "none":
		return null
	var fc := face()
	if not fc.is_empty():
		return _fitted_gag(kind, fc)
	var head := head_frame()
	var f: Vector3 = head.fwd
	if kind == "tape":
		# Two turns round the snout, a hand's width back from its tip, and a torn end.
		var n := Node3D.new()
		var band := oval(head.r * 0.5, head.reach * 0.32, 0.05, TAPE)
		n.add_child(band)
		var band2 := oval(head.r * 0.52, head.reach * 0.34, 0.035, TAPE)
		band2.position = Vector3(0, -0.012, -0.01)
		band2.rotation.x = 0.12
		n.add_child(band2)
		var tab := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.03, 0.025, 0.004)
		tab.mesh = bm
		tab.position = Vector3(head.r * 0.48, -0.01, head.reach * 0.1)
		tab.rotation.y = 0.6
		tab.material_override = Look.toon(tape_colour, 0.25)
		n.add_child(tab)
		var at: Vector3 = head.mouth - f * head.reach * 0.32 + Vector3.UP * 0.01
		return wear("head", n, at, f)
	var front: float = head.reach * 0.85 + 0.008
	var g := oval(head.r + 0.008, front, 0.022, LEATHER)
	var piece := MeshInstance3D.new()
	if kind == "bit":
		var cm := CylinderMesh.new()
		cm.top_radius = 0.018
		cm.bottom_radius = 0.018
		cm.height = 0.13
		piece.mesh = cm
		piece.rotation.z = PI / 2.0
		piece.material_override = Look.toon(LEATHER, 0.4)
	else:
		var sm := SphereMesh.new()
		sm.radius = 0.038
		sm.height = 0.076
		piece.mesh = sm
		piece.material_override = Look.toon(Look.VELVET, 0.6)
	piece.position = Vector3(0, 0, front)
	g.add_child(piece)
	return wear("head", g, head.mouth - f * head.reach * 0.85, f)


## A strip of tape across the mouth, laid on the face itself (owner, 2026-11-13: "Mr. Smith looks odd with his gag
## (tape)": the old one was a band round the snout's tip, which stood off a short snout like a black box). Sampled off
## the head's vertices in columns across the mouth and rows up it, each point just proud of the skin there, from cheek
## to cheek; a torn tab at one end. In the frame wear() gives: x the face's side, y up, z out of the face, from the
## middle of the head at mouth height.
func _tape(fc: Dictionary) -> Node3D:
	# A long muzzle or a beak (Laffer's, Mrs Gander's): a strip across the front only covers the tip, so the tape
	# wraps round the muzzle instead (owner, 2026-11-14: the bosses "properly gagged").
	if float(fc.front) > float(fc.head_w) * 2.5:
		var band := _muzzle_band(fc)
		if band:
			return band
	var f: Vector3 = fc.fwd
	var side: Vector3 = fc.side
	var up: Vector3 = fc.get("up", Vector3.UP)
	var o: Vector3 = fc.mid + up * float(fc.lips_y)
	var pts: Array = fc.pts
	var span := float(fc.snout_w) * 1.35 + 0.01
	var cols := 14
	# A wide strip (owner: "make the strip extra thick"), most of the way from the nose to the chin, with real depth.
	var hh := clampf(float(fc.jaw) * 0.26, 0.017, 0.028)
	var thick := 0.006
	# Each column stands as far out as the furthest skin anywhere up the strip there: tape bridges the lip's crease
	# rather than following it in (following it let the fur poke through in patches).
	var zs: Array[float] = []
	for c in cols + 1:
		var s := lerpf(-span, span, float(c) / cols)
		var z := -INF
		for p: Vector3 in pts:
			var d := p - o
			if absf(d.dot(side) - s) < 0.014 and absf(d.dot(up)) < hh + 0.004:
				z = maxf(z, d.dot(f))
		zs.append(z)
	# A column with no skin in reach takes its neighbour's depth; then each stands at least as far out as its
	# neighbours, so no skin pokes through between them.
	for pass_i in 3:
		for c in cols + 1:
			if zs[c] == -INF:
				var l := zs[c - 1] if c > 0 else -INF
				var r := zs[c + 1] if c < cols else -INF
				zs[c] = maxf(l, r) - 0.004 if maxf(l, r) > -INF else 0.0
	var smooth: Array[float] = []
	for c in cols + 1:
		smooth.append(maxf(zs[c], maxf(zs[maxi(c - 1, 0)], zs[mini(c + 1, cols)]) - 0.002))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Both windings on every face: a slab seen from any side, whatever the toon shader culls.
	var quad := func(a: Vector3, b2: Vector3, cc: Vector3, d: Vector3) -> void:
		for t: Array in [[a, b2, cc], [b2, d, cc], [a, cc, b2], [b2, cc, d]]:
			for v: Vector3 in t:
				st.add_vertex(v)
	var pt := func(c: int, y: float, outer: bool) -> Vector3:
		return Vector3(lerpf(-span, span, float(c) / cols), y, smooth[c] + 0.003 + (thick if outer else 0.0))
	for c in cols:
		quad.call(pt.call(c, hh, true), pt.call(c + 1, hh, true), pt.call(c, -hh, true), pt.call(c + 1, -hh, true))
		quad.call(pt.call(c, hh, false), pt.call(c + 1, hh, false), pt.call(c, hh, true), pt.call(c + 1, hh, true))
		quad.call(pt.call(c, -hh, true), pt.call(c + 1, -hh, true), pt.call(c, -hh, false), pt.call(c + 1, -hh, false))
	for c: int in [0, cols]:
		quad.call(pt.call(c, hh, false), pt.call(c, hh, true), pt.call(c, -hh, false), pt.call(c, -hh, true))
	st.generate_normals()
	var n := Node3D.new()
	var strip := MeshInstance3D.new()
	strip.mesh = st.commit()
	strip.material_override = Look.toon(tape_colour, 0.25)
	n.add_child(strip)
	# The torn end, lifting off the right cheek.
	var tab := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.022, 0.03, 0.003)
	tab.mesh = bm
	var end: Vector3 = pt.call(cols, 0.0, true)
	tab.position = end + Vector3(0.006, -0.004, 0.004)
	tab.rotation = Vector3(0.0, 0.5, 0.25)
	tab.material_override = Look.toon(tape_colour, 0.25)
	n.add_child(tab)
	return n


## Tape wound round a long muzzle, a little under halfway back from its tip: the muzzle's cross-section measured there
## off the head's vertices (its half width, its top and bottom), two turns just outside it, and a torn tab. In the
## same frame as _tape() (x the side, y up, z out of the face, from the head's middle at the lips). Null if there's too
## little muzzle there to measure.
func _muzzle_band(fc: Dictionary) -> Node3D:
	var f: Vector3 = fc.fwd
	var side: Vector3 = fc.side
	var up: Vector3 = fc.get("up", Vector3.UP)
	var o: Vector3 = fc.mid + up * float(fc.lips_y)
	var front := float(fc.front)
	var length := front - float(fc.head_w)
	var tall := clampf(length * 0.2, 0.045, 0.07)
	# Close to the tip: further back, a hat's brim can stand out over the muzzle (Laffer's boater reaches 0.66 m out,
	# his snout 0.8) and be taken for it.
	var zc := front - minf(length * 0.3, tall * 0.5 + 0.02)
	# The muzzle's slice there, in the face's (side, up) plane. Its middle: the run of heights round the lips' line
	# with no big gap in it (a hat's brim above is a separate run, and left out).
	var slice: Array[Vector2] = []
	for p: Vector3 in fc.pts:
		var d := p - o
		if absf(d.dot(f) - zc) < tall * 0.5:
			slice.append(Vector2(d.dot(side), d.dot(up)))
	if slice.size() < 16:
		return null
	var ys: Array[float] = []
	for q in slice:
		ys.append(q.y)
	ys.sort()
	var at := 0
	for i in ys.size():
		if absf(ys[i]) < absf(ys[at]):
			at = i
	var lo := at
	var hi := at
	while lo > 0 and ys[lo] - ys[lo - 1] < 0.02:
		lo -= 1
	while hi < ys.size() - 1 and ys[hi + 1] - ys[hi] < 0.02:
		hi += 1
	var y0 := ys[lo]
	var y1 := ys[hi]
	var c := Vector2(0.0, (y0 + y1) / 2.0)
	var mine: Array[Vector2] = []
	for q in slice:
		if q.y >= y0 - 0.001 and q.y <= y1 + 0.001:
			mine.append(q - c)
	# How far out the skin is at each angle round the middle (the furthest point within a few degrees of it).
	var steps := 28
	var radii: Array[float] = []
	var all_r: Array[float] = []
	for q in mine:
		all_r.append(q.length())
	all_r.sort()
	var cap := all_r[int(all_r.size() * 0.5)] * 2.2
	for k in steps:
		var a := TAU * k / steps
		var r := 0.0
		for q in mine:
			var qa := atan2(q.y, q.x)
			if absf(wrapf(qa - a, -PI, PI)) < PI / steps * 1.6 and q.length() < cap:
				r = maxf(r, q.length())
		radii.append(r)
	for pass_i in 2:   # an angle with nothing near: its neighbours' reach
		for k in steps:
			if radii[k] <= 0.0:
				radii[k] = maxf(radii[(k + steps - 1) % steps], radii[(k + 1) % steps])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Each face once, wound to face its own normal, the normal set by hand: two windings with generated normals
	# cancelled out and left only the outline showing. (Checked by eye: wound this way round, they draw.)
	var tri := func(a: Vector3, b2: Vector3, c2: Vector3, nrm: Vector3) -> void:
		if (b2 - a).cross(c2 - a).dot(nrm) < 0.0:
			var t := b2
			b2 = c2
			c2 = t
		for v: Vector3 in [a, b2, c2]:
			st.set_normal(nrm)
			st.add_vertex(v)
	var quad := func(p1: Vector3, p2: Vector3, p3: Vector3, p4: Vector3, nrm: Vector3) -> void:
		tri.call(p1, p2, p3, nrm)
		tri.call(p2, p4, p3, nrm)
	var ring := func(k: int, z: float, out: float) -> Vector3:
		var a := TAU * k / steps
		var r: float = radii[k % steps] + out
		return Vector3(c.x + cos(a) * r, c.y + sin(a) * r, z)
	var thick := 0.007
	var z0 := zc - tall * 0.5
	var z1 := zc + tall * 0.5
	var lift := 0.004
	for k in steps:
		var am := TAU * (k + 0.5) / steps
		var radial := Vector3(cos(am), sin(am), 0.0)
		var o0 := lift + thick
		quad.call(ring.call(k, z0, o0), ring.call(k + 1, z0, o0), ring.call(k, z1, o0), ring.call(k + 1, z1, o0), radial)
		quad.call(ring.call(k, z0, lift), ring.call(k + 1, z0, lift), ring.call(k, z1, lift), ring.call(k + 1, z1, lift), -radial)
		quad.call(ring.call(k, z0, lift), ring.call(k + 1, z0, lift), ring.call(k, z0, o0), ring.call(k + 1, z0, o0), Vector3.BACK * -1.0)
		quad.call(ring.call(k, z1, lift), ring.call(k + 1, z1, lift), ring.call(k, z1, o0), ring.call(k + 1, z1, o0), Vector3.BACK)
	var n := Node3D.new()
	var band := MeshInstance3D.new()
	band.mesh = st.commit()
	band.material_override = Look.toon(tape_colour, 0.25)
	n.add_child(band)
	# The torn end, lifting off the side.
	var tab := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.003, 0.03, 0.026)
	tab.mesh = bm
	tab.position = ring.call(0, zc, 0.005 + thick + 0.004)
	tab.rotation = Vector3(0.3, 0.0, -0.35)
	tab.material_override = Look.toon(tape_colour, 0.25)
	n.add_child(tab)
	return n


## Tape going on with a slap (a boss's finish, owner 2026-11-14): `g` (a worn gag) starts as a sliver at the middle
## of the mouth, stretches out past its width and settles. Returns the tween's finished signal (or a frame's, with no
## gag), run on `by` (a node in the tree).
static func slap_on(g: Node3D, by: Node) -> Signal:
	if g == null:
		return by.get_tree().process_frame
	var s := g.scale
	g.scale = Vector3(s.x * 0.05, s.y * 1.25, s.z)
	var tw := by.create_tween()
	tw.tween_property(g, ^"scale", Vector3(s.x * 1.12, s.y * 0.92, s.z), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(g, ^"scale", s, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tw.finished


## A gag fitted to the face as measured (face()): the strap round the head at mouth height, just outside it, front to
## back; the ball or the bit at the front of the snout. Tape laid across the mouth (_tape()).
func _fitted_gag(kind: String, fc: Dictionary) -> Node3D:
	var f: Vector3 = fc.fwd
	var mid: Vector3 = fc.mid
	var up: Vector3 = fc.get("up", Vector3.UP)
	var y := up * float(fc.mouth_y)
	var front: float = fc.front
	if kind == "tape":
		# At the lips, where _tape() builds it from (it was placed at mouth_y: off by their difference).
		return wear("head", _tape(fc), mid + up * float(fc.lips_y), f, up)
	var back: float = fc.head_back
	var depth := (front + back) * 0.5 + 0.012
	var g := oval(float(fc.head_w) + 0.012, depth, 0.022, LEATHER)
	var piece := MeshInstance3D.new()
	if kind == "bit":
		var cm := CylinderMesh.new()
		cm.top_radius = 0.016
		cm.bottom_radius = 0.016
		cm.height = float(fc.snout_w) * 2.0 + 0.05
		piece.mesh = cm
		piece.rotation.z = PI / 2.0
		piece.material_override = Look.toon(LEATHER, 0.4)
		piece.position = Vector3(0, 0, depth - 0.02)
	else:
		var sm := SphereMesh.new()
		sm.radius = 0.034
		sm.height = 0.068
		piece.mesh = sm
		piece.material_override = Look.toon(Look.VELVET, 0.6)
		piece.position = Vector3(0, 0, depth - 0.006)
	g.add_child(piece)
	return wear("head", g, mid + y + f * (front - back) * 0.5, f, up)


## A line through a gag: the sound, and what it means in brackets ("Mmh-mm. (Green.)"). OWNER REVIEW.
static func muffle(text: String) -> String:
	var sounds := ["Mmh.", "Mm-hm.", "Mmhh...", "Nnh."]
	return "%s  (%s)" % [sounds[absi(text.hash()) % sounds.size()], text]


## The bell a gagged sub holds: dropping it is her word.
func bell(hand := "handR") -> Node3D:
	var n := Node3D.new()
	var b := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.012
	cm.bottom_radius = 0.03
	cm.height = 0.045
	b.mesh = cm
	b.material_override = Look.toon(Look.BRASS, 0.9)
	n.add_child(b)
	return attach(hand, n, Vector3(0, 0, 0.04))


## Off with all of it.
func clear() -> void:
	for g in gear:
		if is_instance_valid(g):
			g.queue_free()
	gear.clear()


# --- shapes ------------------------------------------------------------------------------------------------------------

## A level oval strap: `side` wide each way, `front` long each way (its front is +Z), `tall` high.
static func oval(side: float, front: float, tall: float, c: Color) -> Node3D:
	var n := Node3D.new()
	var s := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.0
	tm.outer_radius = 1.12
	tm.rings = 28
	s.mesh = tm
	# The torus's tube is 0.06 of a unit thick; scaled, it's an oval strap `tall` high.
	s.scale = Vector3(side, tall / 0.12, front)
	s.material_override = Look.toon(c, 0.3)
	n.add_child(s)
	return n


## A cylinder from `a` to `b` (world points), as a node to place: its origin at the middle.
static func line_between(a: Vector3, b2: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 1.0
	cm.radial_segments = 8
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	return mi


## Sets a free-standing line (a MeshInstance3D from line_between, in the world) to run from `a` to `b2`.
static func set_line(mi: MeshInstance3D, a: Vector3, b2: Vector3) -> void:
	var d := b2 - a
	var length := d.length()
	if length < 0.001:
		return
	var y := d / length
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	mi.global_transform = Transform3D(Basis(x, y * length, z), (a + b2) / 2.0)


## A held tool, built from shapes, its grip at the origin and its length along +Y (a hand bone's +Y runs down the
## fingers). Suggestive kit, nothing explicit: sensation and impact only.
static func tool_mesh(tool: String) -> Node3D:
	var n := Node3D.new()
	var dark := Look.toon(LEATHER, 0.35)
	match tool:
		"feather":
			_part(n, _cyl(0.005, 0.34), Vector3(0, 0.12, 0), Look.toon(Color("e8dcc8")))
			var vane := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.045
			sm.height = 0.24
			vane.mesh = sm
			vane.scale = Vector3(1.0, 1.0, 0.18)
			vane.position = Vector3(0, 0.2, 0)
			vane.material_override = Look.toon(Color("f0c8e8"), 0.1)
			n.add_child(vane)
		"ice":
			var cube := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.06, 0.06, 0.06)
			cube.mesh = bm
			cube.rotation = Vector3(0.4, 0.6, 0.2)
			cube.position = Vector3(0, 0.05, 0)
			cube.material_override = Look.toon(Color(0.75, 0.92, 1.0), 0.9, 0.4)
			n.add_child(cube)
		"flogger":
			_part(n, _cyl(0.016, 0.2), Vector3(0, 0.0, 0), dark)
			_part(n, _cyl(0.022, 0.03), Vector3(0, 0.1, 0), Look.toon(Look.BRASS, 0.7))
			for k in 9:
				var a := (k - 4) * 0.06
				var fall := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.012, 0.42, 0.004)
				fall.mesh = bm
				fall.rotation.z = a
				fall.rotation.x = (k % 3 - 1) * 0.05
				fall.position = Vector3(sin(-a) * 0.21, 0.11 + cos(a) * 0.21, 0)
				fall.material_override = Look.toon(Color("3a0c18") if k % 2 else LEATHER, 0.3)
				n.add_child(fall)
		"crop":
			_part(n, _cyl(0.013, 0.16), Vector3(0, 0.0, 0), dark)
			_part(n, _cyl(0.006, 0.58), Vector3(0, 0.37, 0), dark)
			var keeper := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.04, 0.06, 0.006)
			keeper.mesh = bm
			keeper.position = Vector3(0, 0.68, 0)
			keeper.material_override = Look.toon(Look.VELVET, 0.3)
			n.add_child(keeper)
		"paddle":
			_part(n, _cyl(0.016, 0.18), Vector3(0, 0.0, 0), Look.toon(Color("3a2218")))
			var blade := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.12, 0.26, 0.022)
			blade.mesh = bm
			blade.position = Vector3(0, 0.22, 0)
			blade.material_override = Look.toon(Color("5a3420"), 0.2)
			n.add_child(blade)
	return n


static func _cyl(r: float, h: float) -> CylinderMesh:
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 10
	return cm


static func _part(n: Node3D, m: Mesh, at: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = at
	mi.material_override = mat
	n.add_child(mi)
