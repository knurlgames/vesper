extends SceneTree
## Finds z-fighting in the box-built worlds (the hub, the Pier): two drawn boxes whose faces lie in the same plane,
## face the same way and overlap, in different materials. (Same-material pairs paint the same colour, so they don't
## show.) Only BuiltWorld's axis-aligned boxes are checked: not slabs, struts, props or labels.
##   godot --headless --path . -s tools/zfight_check.gd [-- <scene> ...]
## Prints each overlap (where, its size, which materials) and a count per scene; exits 1 if there are any.

const SCENES := ["res://levels/hub/hub.tscn", "res://levels/pier/pier.tscn", "res://levels/primrose/primrose.tscn"]
## Faces closer than this count as the same plane (depth precision at 50 m is a few millimetres).
const PLANE_EPS := 0.004
## Overlaps smaller than this on either side are ignored (touching edges).
const MIN_SIDE := 0.02
## Bottom faces at or below this height stand on the ground: never seen. (The Pier's sand and beach are lower, so
## its boxes there are checked: their bottoms are still on the ground, but rarely coplanar with another's.)
const GROUND := 0.0


func _initialize() -> void:
	await process_frame
	var game := root.get_node("/root/Game")
	game.set(&"persist", false)
	game.call(&"set_setting", "age_confirmed", true)
	load("res://core/built_world.gd").set(&"record_boxes", true)
	var scenes: Array = OS.get_cmdline_user_args()
	if scenes.is_empty():
		scenes = SCENES
	var total := 0
	for path: String in scenes:
		var level: Node = load(path).instantiate()
		root.add_child(level)
		current_scene = level
		await process_frame
		if level.get(&"boxes") == null:
			print("%s: no boxes (did its script fail to load?)" % path)
			quit(2)
			return
		var found := _check(level.get(&"boxes"))
		print("%s: %d boxes, %d coplanar overlaps" % [path, (level.get(&"boxes") as Array).size(), found.size()])
		for f: String in found:
			print("  ", f)
		total += found.size()
		level.free()
		await process_frame
	quit(1 if total else 0)


func _check(boxes: Array) -> Array[String]:
	# Bucket every face by its axis, its direction and its plane coordinate.
	var buckets := {}
	for i in boxes.size():
		var c: Vector3 = boxes[i][0]
		var s: Vector3 = boxes[i][1]
		for axis in 3:
			for sgn: int in [-1, 1]:
				var coord := c[axis] + sgn * s[axis] / 2.0
				var key := Vector3i(axis, sgn, roundi(coord / PLANE_EPS))
				(buckets.get_or_add(key, []) as Array).append([i, coord])
	var out: Array[String] = []
	var seen := {}
	for key: Vector3i in buckets:
		var here: Array = buckets[key]
		var next: Array = buckets.get(Vector3i(key.x, key.y, key.z + 1), [])
		for a: Array in here:
			for b: Array in here + next:
				var i: int = a[0]
				var j: int = b[0]
				if i >= j or absf(float(a[1]) - float(b[1])) > PLANE_EPS:
					continue
				if boxes[i][2] == boxes[j][2]:
					continue
				# A bottom face on the ground (or below it) is never seen.
				if key.x == 1 and key.y < 0 and float(a[1]) <= GROUND + PLANE_EPS:
					continue
				var pair := Vector4i(i, j, key.x, key.y)
				if seen.has(pair):
					continue
				var o := _overlap(boxes[i], boxes[j], key.x)
				if o.x > MIN_SIDE and o.y > MIN_SIDE:
					seen[pair] = true
					out.append("%s face %s%s at %s: %.2f x %.2f m (box %s %s vs %s %s)" % [
						"xyz"[key.x], "-+"[(key.y + 1) / 2], "", _fmt(_face_centre(boxes[i], boxes[j], key.x, float(a[1]))),
						o.x, o.y, _fmt(boxes[i][0]), _fmt(boxes[i][1]), _fmt(boxes[j][0]), _fmt(boxes[j][1])])
	return out


## The overlap of two boxes' extents on the two axes other than `axis`.
func _overlap(a: Array, b: Array, axis: int) -> Vector2:
	var r := []
	for k in 3:
		if k == axis:
			continue
		var alo: float = a[0][k] - a[1][k] / 2.0
		var ahi: float = a[0][k] + a[1][k] / 2.0
		var blo: float = b[0][k] - b[1][k] / 2.0
		var bhi: float = b[0][k] + b[1][k] / 2.0
		r.append(minf(ahi, bhi) - maxf(alo, blo))
	return Vector2(r[0], r[1])


func _face_centre(a: Array, b: Array, axis: int, coord: float) -> Vector3:
	var p := Vector3()
	for k in 3:
		if k == axis:
			p[k] = coord
		else:
			var lo := maxf(a[0][k] - a[1][k] / 2.0, b[0][k] - b[1][k] / 2.0)
			var hi := minf(a[0][k] + a[1][k] / 2.0, b[0][k] + b[1][k] / 2.0)
			p[k] = (lo + hi) / 2.0
	return p


func _fmt(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]
