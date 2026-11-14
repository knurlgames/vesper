class_name DoorKit
extends RefCounted
## What every door's made of (owner, 2026-11-14: "ensure we have proper opening ... so that doors actually open"):
## a leaf on a hinge that swings, never a box that slides into the sky or spins on its middle. Shared by Door,
## ShortcutDoor, RankDoor and SwingDoor.
##
## A leaf is a Node3D at its hinge; the leaf runs along its +X (or -X for a right-hand one) and is a few boxes merged
## into one mesh per material (one draw each), so a gate of bars costs three draws, not thirty.


## Boxes into one mesh: each [centre, size].
static func boxes(list: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b: Array in list:
		var bm := BoxMesh.new()
		bm.size = b[1]
		st.append_from(bm, 0, Transform3D(Basis.IDENTITY, b[0]))
	return st.commit()


static func part(parent: Node3D, list: Array, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = boxes(list)
	mi.material_override = mat
	parent.add_child(mi)
	return mi


## A panelled wooden door leaf `w` wide, `h` tall, from its hinge along `dir` (+1 or -1 on X): a slab, raised panels
## on both faces, a brass handle each side by the far edge. Returns the hinge node (rotate it on Y to swing).
static func panelled(parent: Node3D, hinge: Vector3, w: float, h: float, dir: float, colour: Color,
		thick := 0.07) -> Node3D:
	var n := Node3D.new()
	n.position = hinge
	parent.add_child(n)
	var c := dir * w / 2.0
	part(n, [[Vector3(c, h / 2.0, 0), Vector3(w - 0.02, h, thick)]], Look.toon(colour))
	var panels := []
	for z: float in [-1.0, 1.0]:
		for y: float in [h * 0.28, h * 0.68]:
			panels.append([Vector3(c, y, z * (thick / 2.0 + 0.012)), Vector3(w * 0.62, h * 0.3, 0.025)])
	part(n, panels, Look.toon(colour.darkened(0.25)))
	var brass := []
	for z: float in [-1.0, 1.0]:
		brass.append([Vector3(dir * (w - 0.16), 1.0, z * (thick / 2.0 + 0.04)), Vector3(0.05, 0.16, 0.06)])
	part(n, brass, Look.toon(Look.BRASS, 0.7))
	return n


## Swings a hinge to `angle` over `secs` (0: at once), a little overshoot and settle. Returns what to await.
static func swing(n: Node3D, angle: float, secs: float) -> Signal:
	if secs <= 0.0:
		n.rotation.y = angle
		return n.get_tree().process_frame
	var tw := n.create_tween()
	tw.tween_property(n, ^"rotation:y", angle, secs).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tw.finished
