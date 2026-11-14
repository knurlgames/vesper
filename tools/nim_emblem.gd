extends SceneTree
## The Claw's emblem on Nim (owner, 2026-11-14: "Put the Clawed Rose on Nim's grille and buckle"). Painting it into
## her Meshy atlas was too fragile (scattered islands; the knot's lines run all over), so it's two Decals that ride her
## (player/nim_model.gd _emblems), and this measures where and makes their pictures:
##   - assets/ui/emblems/clawed_rose_brass.png: a brass plate with the rose on it, for her muzzle's grille;
##   - assets/ui/emblems/clawed_rose_medal.png: a black leather disc rimmed in steel with the rose on it, for the
##     medallion at the middle of her chest harness.
## Both opaque where the plate is, so the knot under them is covered.
##   godot --headless --path . -s tools/nim_emblem.gd
## It prints the grille's middle in the mask's own space and the medallion's in the skeleton's (paste them into
## NimModel's GRILLE and MEDALLION).

const EMBLEM := "res://assets/ui/emblems/clawed_rose.png"
const OUT := "res://assets/ui/emblems/"
const N := 512
## The grille's plate is taller than it's wide (NimModel.GRILLE_SIZE): its picture is too, so the rose stays round.
const BRASS_TALL := 1.19


func _initialize() -> void:
	await process_frame
	_plates()
	var scene: Node3D = (load("res://assets/characters/nim/nim_garb.glb") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var mask: MeshInstance3D
	var body: MeshInstance3D
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if mi.name.ends_with("_Mask"):
			mask = mi
		elif body == null or mi.mesh.get_aabb().size.y > body.mesh.get_aabb().size.y:
			body = mi
	# The grille: the mask's front-most stretch, its middle (the GLB faces +Z).
	var mv: PackedVector3Array = mask.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var front := -INF
	for v in mv:
		front = maxf(front, (mask.global_transform * v).z)
	var sum := Vector3.ZERO
	var n := 0
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for v in mv:
		var g := mask.global_transform * v
		if g.z > front - 0.006:
			sum += g
			n += 1
			lo = lo.min(g)
			hi = hi.max(g)
	var gc := sum / maxf(n, 1)
	print("GRILLE (scene) %s, front tip %.3f, spread %s, %d points" % [gc, front, hi - lo, n])
	print("GRILLE (mask-local) %s, mask basis scale %s" % [mask.global_transform.affine_inverse() * gc, mask.global_transform.basis.get_scale()])
	# A profile up her middle line (front-most z per cm), so the medallion standing proud of the sternum shows itself.
	var bv: PackedVector3Array = body.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var rows := {}
	for v in bv:
		var g := body.global_transform * v
		if absf(g.x) < 0.01 and g.y > 1.0 and g.y < 1.4:
			var k := int(g.y * 100)
			rows[k] = maxf(rows.get(k, -INF), g.z)
	var keys := rows.keys()
	keys.sort()
	var prof := ""
	for k: int in keys:
		prof += "%d:%.3f " % [k, rows[k]]
	print("CHEST profile (cm: front z) ", prof)
	var skel: Skeleton3D = null
	for s: Skeleton3D in scene.find_children("*", "Skeleton3D", true, false):
		skel = s
	if skel:
		print("skeleton %s at %s; body's parent %s; body global %s" % [skel.name, skel.global_transform.origin,
			body.get_parent().name, body.global_transform.origin])
		var names := []
		for i in skel.get_bone_count():
			names.append(skel.get_bone_name(i))
		print("  bones ", names)
		for b in ["chest", "spine", "spine1", "spine2", "upper_chest"]:
			var i := skel.find_bone(b)
			if i >= 0:
				print("  bone %s rest %s" % [b, skel.get_bone_global_rest(i)])
	quit()


## The two plate pictures: the rose (cropped to its shape) over a brass rounded square, and over a leather disc.
func _plates() -> void:
	var rose := Image.load_from_file(ProjectSettings.globalize_path(EMBLEM))
	rose.convert(Image.FORMAT_RGBA8)
	# Its own extent (the art has wide margins).
	var used := rose.get_used_rect()
	var side := maxi(used.size.x, used.size.y)
	var sq := Rect2i(used.get_center() - Vector2i(side, side) / 2, Vector2i(side, side))
	var crop := rose.get_region(sq)
	crop.resize(int(N * 0.8), int(N * 0.8), Image.INTERPOLATE_LANCZOS)
	var brass := Color("c8a050")
	var brass_dk := Color("6a4a18")
	var leather := Color("1c1a20")
	var steel := Color("8a8e98")
	for which in ["brass", "medal"]:
		var hgt := int(N * BRASS_TALL) if which == "brass" else N
		var img := Image.create(N, hgt, false, Image.FORMAT_RGBA8)
		var c := Vector2(N, hgt) / 2.0
		var half := Vector2(N * 0.42, hgt * 0.5 - N * 0.08)
		for y in hgt:
			for x in N:
				var p := Vector2(x + 0.5, y + 0.5) - c
				var col := Color(0, 0, 0, 0)
				if which == "brass":
					# A rounded square plate, a darker bevel round its edge, a soft sheen across it.
					var q := (p.abs() - half).max(Vector2.ZERO).length() - N * 0.06
					var edge := maxf(absf(p.x) / (half.x + N * 0.06), absf(p.y) / (half.y + N * 0.06))
					if q < 0.0:
						col = brass.lerp(Color("e8c878"), clampf(0.5 - (p.x + p.y) / N, 0.0, 1.0) * 0.5)
						if edge > 0.86:
							col = col.lerp(brass_dk, 0.6)
				else:
					var r := p.length() / (N * 0.5)
					if r < 1.0:
						col = leather if r < 0.86 else steel.darkened(0.15 + 0.3 * absf(p.normalized().x))
				img.set_pixel(x, y, col)
		img.blend_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), Vector2i((N - crop.get_width()) / 2, (hgt - crop.get_height()) / 2))
		img.save_png(ProjectSettings.globalize_path(OUT + "clawed_rose_%s.png" % which))
		print("wrote clawed_rose_%s.png" % which)
