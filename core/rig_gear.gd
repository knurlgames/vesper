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

const ROPE := Color("b8283c")      # the Rope's red
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
func wear(role: String, what: Node3D, at: Vector3, face: Vector3) -> Node3D:
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
	what.transform = bg.affine_inverse() * Transform3D(Basis.looking_at(-face, Vector3.UP), at)
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
	for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or mi.skin == null or mi.name.ends_with("_Mask") or not mi.is_visible_in_tree():
			continue
		var skin := mi.skin
		var bind := -1
		for b in skin.get_bind_count():
			if skin.get_bind_name(b) == sk.get_bone_name(head_i) or skin.get_bind_bone(b) == head_i:
				bind = b
				break
		if bind < 0:
			continue
		var to_world := sk.global_transform * sk.get_bone_global_pose(head_i) * skin.get_bind_pose(bind)
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
				if w > 0.3:
					pts.append(to_world * verts[v])
	if pts.size() < 30:
		return {}
	var hf := head_frame()
	var f: Vector3 = hf.fwd
	var side := Vector3.UP.cross(f).normalized()
	var mid: Vector3 = hf.mid
	# The nose: the highest of the points nearly as far forward as any (a jutting chin or lip can be the furthest).
	var far := -INF
	for p in pts:
		far = maxf(far, (p - mid).dot(f))
	var nose := pts[0]
	var ny := -INF
	for p in pts:
		var d := p - mid
		if d.dot(f) > far - 0.012 and d.y > ny:
			ny = d.y
			nose = p
	# The mouth: a little under the nose, where a gag sits.
	var mouth_y := ny - 0.03
	var mouth := nose
	var best := -INF
	var widths: Array[float] = []
	var backs: Array[float] = []
	for p in pts:
		var d := p - mid
		if absf(d.y - mouth_y) < 0.015:
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
		if absf(d.y - mouth_y) < 0.015 and d.dot(f) > best - 0.04:
			snouts.append(absf(d.dot(side)))
	snouts.sort()
	var snout_w := snouts[int(snouts.size() * 0.9)] if not snouts.is_empty() else head_w * 0.5
	return {"fwd": f, "side": side, "mid": mid, "nose": nose, "mouth": mouth, "front": best, "snout_w": snout_w,
		"head_w": head_w, "head_back": back, "mouth_y": mouth_y}


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
		tab.material_override = Look.toon(TAPE, 0.25)
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


## A gag fitted to the face as measured (face()): the strap round the head at mouth height, just outside it, front to
## back; the ball or the bit at the front of the snout. Tape wound round the snout itself, just outside it.
func _fitted_gag(kind: String, fc: Dictionary) -> Node3D:
	var f: Vector3 = fc.fwd
	var mid: Vector3 = fc.mid
	var y := Vector3.UP * float(fc.mouth_y)
	var front: float = fc.front
	if kind == "tape":
		var length := clampf(front * 0.35, 0.035, 0.07)
		var n := Node3D.new()
		var w := float(fc.snout_w) + 0.01
		var band := oval(w, length * 0.5 + 0.012, 0.05, TAPE)
		n.add_child(band)
		var band2 := oval(w + 0.004, length * 0.5 + 0.016, 0.032, TAPE)
		band2.position = Vector3(0, -0.014, 0.004)
		band2.rotation.x = 0.1
		n.add_child(band2)
		var tab := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.028, 0.024, 0.004)
		tab.mesh = bm
		tab.position = Vector3(w + 0.004, -0.01, 0.0)
		tab.rotation.y = PI / 2.0 - 0.3
		tab.material_override = Look.toon(TAPE, 0.25)
		n.add_child(tab)
		return wear("head", n, mid + y + f * (front - length * 0.5), f)
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
	return wear("head", g, mid + y + f * (front - back) * 0.5, f)


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
