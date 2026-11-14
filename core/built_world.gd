class_name BuiltWorld
extends World
## A World built in code from boxes (the Pier, the hub; WO-014). What they share:
##   - solid(), deco(): boxes batched into one MultiMesh per material, collision on one shared body per layer; call
##     _flush() once at the end of _ready (anything added after that needs Level.block or its own nodes);
##   - _slab() (a tilted solid, a ramp), _strut() (a beam between two points), _sign() (neon or painted lettering),
##     _light(), _unlit();
##   - props(): Meshy props from assets/props, one MultiMesh per prop, standing in for boxes;
##   - _rain(): rain that follows the camera and stops under any roof (a ray up from the camera).


const PROP_PATH := "res://assets/props/%s.glb"
const TOON_HOLED := preload("res://shaders/toon_holed.gdshader")
const OUTLINE_HOLED := preload("res://shaders/outline_holed.gdshader")

## tools/zfight_check.gd sets this before a level loads: every axis-aligned box drawn is kept in `boxes` ([centre,
## size, material]) so coplanar faces can be found.
static var record_boxes := false
var boxes: Array = []

var _batches := {}
var _bodies := {}
var _rain_node: GPUParticles3D
var _rain_check := 0.0


func _process(delta: float) -> void:
	super(delta)   # Level's: the HUD's light readout and Y prompt
	if cam and _rain_node:
		_rain_node.global_position = cam.global_position + Vector3(0, 9, 0)
		# No rain under a roof: indoors, under the pier, in a hut.
		_rain_check -= delta
		if _rain_check <= 0.0:
			_rain_check = 0.2
			var from: Vector3 = cam.global_position
			var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.UP * 40.0, 1)
			_rain_node.visible = get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _unlit(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	return m


func _light(at: Vector3, colour: Color, energy := 3.0, reach := 10.0) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = colour
	l.light_energy = energy
	l.omni_range = reach
	l.omni_attenuation = 1.2
	l.position = at
	add_child(l)
	return l


func _rain() -> void:
	_rain_node = GPUParticles3D.new()
	# It keeps falling through dialogue and cutscenes, which pause the tree (owner: "the rain ceases to play").
	_rain_node.process_mode = Node.PROCESS_MODE_ALWAYS
	_rain_node.amount = 2600
	_rain_node.lifetime = 0.9
	_rain_node.local_coords = false
	_rain_node.visibility_aabb = AABB(Vector3(-20, -20, -20), Vector3(40, 40, 40))
	_rain_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(16, 0.5, 16)
	pm.direction = Vector3(0.12, -1, 0.05)
	pm.spread = 2.0
	pm.initial_velocity_min = 17.0
	pm.initial_velocity_max = 21.0
	pm.gravity = Vector3.ZERO
	_rain_node.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.01, 0.45)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.75, 0.8, 1.0, 0.28)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	# Drops right at the lens would be bars across the screen: fade them in from 1.5 to 5 m.
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_min_distance = 1.5
	m.distance_fade_max_distance = 5.0
	quad.material = m
	_rain_node.draw_pass_1 = quad
	add_child(_rain_node)


## A solid box: its collision goes on one shared body per collision layer, its mesh into a batch per material. Returns
## the body (shared: don't move it).
func solid(at: Vector3, size: Vector3, mat: Material, layer := 1) -> StaticBody3D:
	deco(at, size, mat)
	return _col(at, size, layer)


func _col(at: Vector3, size: Vector3, layer: int) -> StaticBody3D:
	var body: StaticBody3D = _bodies.get(layer)
	if body == null:
		body = StaticBody3D.new()
		body.name = "Solid_layer%d" % layer
		body.collision_layer = layer
		add_child(body)
		_bodies[layer] = body
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = at
	body.add_child(col)
	return body


## A box drawn but not solid, batched by material.
func deco(at: Vector3, size: Vector3, mat: Material) -> void:
	var list: Array = _batches.get_or_add(mat, [])
	list.append(Transform3D(Basis.from_scale(size), at))
	if record_boxes:
		boxes.append([at, size, mat])


## The inside of a room's walls, for a building whose outside is a Meshy shell: the walls themselves turn to bare
## collision (their painted outsides poked through the shell), and these quads face in, so they show from inside and
## vanish from outside (back faces are culled). `rect` is the room's inner faces on the ground (x0, z0, x1, z1), `gaps`
## the doorways: [side ("n" -z, "s" +z, "w" -x, "e" +x), from, to (along the wall), height].
func lining(rect: Rect2, y0: float, h: float, mat: Material, gaps: Array = []) -> void:
	var x0 := rect.position.x
	var z0 := rect.position.y
	var x1 := rect.end.x
	var z1 := rect.end.y
	# [side, start, end, the fixed coordinate, its inward normal]
	var walls := [["n", x0, x1, z0, Vector3(0, 0, 1)], ["s", x0, x1, z1, Vector3(0, 0, -1)],
		["w", z0, z1, x0, Vector3(1, 0, 0)], ["e", z0, z1, x1, Vector3(-1, 0, 0)]]
	for w: Array in walls:
		var side: String = w[0]
		var cuts: Array = gaps.filter(func(g: Array) -> bool: return g[0] == side)
		cuts.sort_custom(func(a: Array, b: Array) -> bool: return a[1] < b[1])
		var at: float = w[1]
		for g: Array in cuts:
			_lining_quad(side, at, g[1], float(w[3]), w[4], y0, h, mat)
			_lining_quad(side, g[1], g[2], float(w[3]), w[4], y0 + float(g[3]), h - float(g[3]), mat)   # over the door
			at = g[2]
		_lining_quad(side, at, w[2], float(w[3]), w[4], y0, h, mat)


func _lining_quad(side: String, a: float, b: float, fixed: float, inward: Vector3, y0: float, h: float,
		mat: Material) -> void:
	if b - a < 0.01 or h < 0.01:
		return
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(b - a, h)
	q.mesh = qm
	q.material_override = mat
	var mid := (a + b) / 2.0
	q.position = Vector3(mid, y0 + h / 2.0, fixed) if side == "n" or side == "s" else Vector3(fixed, y0 + h / 2.0, mid)
	q.rotation.y = atan2(inward.x, inward.z)   # a QuadMesh faces +Z
	add_child(q)


## A tilted solid slab (a ramp): its own body, since the shared ones are axis-aligned.
func _slab(at: Vector3, size: Vector3, basis: Basis, mat: Material) -> void:
	var body := StaticBody3D.new()
	body.transform = Transform3D(basis, at)
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	add_child(body)
	var list: Array = _batches.get_or_add(mat, [])
	list.append(Transform3D(basis * Basis.from_scale(size), at))


## A beam from a to b, `thick` square; solid if asked (its own body).
func _strut(a: Vector3, b: Vector3, thick: float, mat: Material, is_solid: bool) -> void:
	var d := b - a
	var length := d.length()
	if length < 0.01:
		return
	var z := d / length
	var up := Vector3.UP if absf(z.y) < 0.99 else Vector3.RIGHT
	var x := up.cross(z).normalized()
	var y := z.cross(x)
	var basis := Basis(x, y, z)
	var mid := (a + b) / 2.0
	var list: Array = _batches.get_or_add(mat, [])
	list.append(Transform3D(basis * Basis.from_scale(Vector3(thick, thick, length)), mid))
	if is_solid:
		var body := StaticBody3D.new()
		body.transform = Transform3D(basis, mid)
		var shape := BoxShape3D.new()
		shape.size = Vector3(thick, thick, length)
		var col := CollisionShape3D.new()
		col.shape = shape
		body.add_child(col)
		add_child(body)


## Lettering facing +Z turned by `yaw`: neon (unshaded, glowing) unless `glow` is false.
func _sign(text: String, at: Vector3, yaw: float, colour: Color, size := 48, glow := true) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.01
	l.outline_size = 10
	l.modulate = colour
	l.outline_modulate = Look.INK
	l.shaded = not glow
	l.double_sided = false
	l.position = at
	l.rotation.y = yaw
	add_child(l)
	return l


## Meshy props (tools/props.py: one mesh, its origin at the bottom centre, its front +Z), one MultiMesh per name, so a
## row of them costs one draw. Each item is [at (the bottom centre), yaw] or [at, yaw, size]: a size stretches the prop
## to fill that box in its own axes, so it can stand exactly where a box stood. `is_solid` adds the box's collision on
## the shared layer-1 body (props never use mesh collision). Returns false when the prop isn't there: keep the boxes.
## `holes`: a box (world space, AABB; the first of them) where nothing of the prop is drawn, outline included (door
## audit, 2026-11-14: the Prize Hall's Meshy front kept its back face across its doorway, hiding the doors behind it).
func props(prop_name: String, items: Array, is_solid := true, outline := 0.012, glow := 0.0, holes: Array = []) -> bool:
	var path := PROP_PATH % prop_name
	if not ResourceLoader.exists(path):
		return false
	var scene: Node = (load(path) as PackedScene).instantiate()
	var found := scene.find_children("*", "MeshInstance3D", true, false)
	if found.is_empty():
		scene.free()
		return false
	var mi := found[0] as MeshInstance3D
	var local := mi.transform
	var aabb := local * mi.mesh.get_aabb()
	var src := mi.get_active_material(0)
	var tex: Texture2D = (src as BaseMaterial3D).albedo_texture if src is BaseMaterial3D else null
	var mesh := mi.mesh
	scene.free()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = items.size()
	for i in items.size():
		var item: Array = items[i]
		var at: Vector3 = item[0]
		var yaw: float = item[1]
		var size: Vector3 = item[2] if item.size() > 2 else Vector3.ZERO
		var s := Vector3.ONE if size == Vector3.ZERO else size / aabb.size
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(s), at) * local)
		if is_solid:
			var box := aabb.size * s
			var c := absf(cos(yaw))
			var sn := absf(sin(yaw))
			_col(at + Vector3(0, box.y / 2.0, 0), Vector3(c * box.x + sn * box.z, box.y, sn * box.x + c * box.z), 1)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Props_" + prop_name
	mmi.multimesh = mm
	var m := Look.toon(Color.WHITE, 0.0, 0.0, tex)
	m.set_shader_parameter(&"glow", glow)
	mmi.material_override = m
	if outline > 0.0:
		mmi.material_overlay = Look.outline(aabb, outline)
	if not holes.is_empty():
		var hole: AABB = holes[0]
		var mats: Array = [m, mmi.material_overlay] if mmi.material_overlay else [m]
		m.shader = TOON_HOLED
		if mmi.material_overlay:
			(mmi.material_overlay as ShaderMaterial).shader = OUTLINE_HOLED
		for mat: ShaderMaterial in mats:
			mat.set_shader_parameter(&"hole_min", hole.position)
			mat.set_shader_parameter(&"hole_max", hole.end)
	add_child(mmi)
	return true


func _flush() -> void:
	var unit := BoxMesh.new()
	for mat: Material in _batches:
		var list: Array = _batches[mat]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = unit
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		add_child(mmi)
	_batches.clear()
