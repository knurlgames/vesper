class_name RosePetals
extends RefCounted
## Rose petals and buds (owner, 2026-11-14: the fast-travel points as "a bed of rose petals on the ground that swirl a
## little", and travel as "a cyclone of rose buds"): the meshes, the colours, and the bed (TravelPoint). The cyclone
## is RoseCyclone. The Claw's crimson belongs to the rose (LIBERTIES.md: only the rose wears it).

const PETALS := preload("res://shaders/petals.gdshader")
## Crimson to deep wine, with the odd blush-pink one.
const COLOURS: Array[Color] = [Color("b3122e"), Color("c8203a"), Color("8e0c24"), Color("a01430"), Color("d94a66")]

static var _petal: ArrayMesh
static var _bud: ArrayMesh


## A petal: a cupped oval, 13 x 10 cm (big enough to read from the follow camera), white vertex colour (the instance colour tints it), both sides drawn.
static func petal_mesh() -> ArrayMesh:
	if _petal:
		return _petal
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 10
	var rim: Array[Vector3] = []
	for i in n:
		var a := TAU * i / n
		rim.append(Vector3(cos(a) * 0.065, 0.016 * (1.0 - absf(sin(a))), sin(a) * 0.05))   # the ends curl up
	for i in n:
		for v: Vector3 in [Vector3(0, -0.004, 0), rim[i], rim[(i + 1) % n]]:
			st.set_color(Color.WHITE)
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	st.generate_normals()
	_petal = st.commit()
	return _petal


## A bud: a closed teardrop, 9 cm across and 15 tall, its tip up.
static func bud_mesh() -> ArrayMesh:
	if _bud:
		return _bud
	var sm := SphereMesh.new()
	sm.radius = 0.045
	sm.height = 0.15
	sm.radial_segments = 8
	sm.rings = 4
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(Color.WHITE)
	st.append_from(sm, 0, Transform3D.IDENTITY)
	_bud = st.commit()
	return _bud


static func colour(rng: RandomNumberGenerator) -> Color:
	var c := COLOURS[rng.randi() % COLOURS.size()]
	return c.darkened(rng.randf_range(0.0, 0.25))


## The bed: `count` petals within `radius` of the node's origin, thicker toward the middle, swirling (petals.gdshader).
## Its material is its own, so `glow` can light one bed.
static func bed(parent: Node3D, radius := 1.0, count := 150, rng_seed := 1) -> MultiMeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = petal_mesh()
	mm.instance_count = count
	for i in count:
		mm.set_instance_transform(i, Transform3D.IDENTITY)
		var r := radius * sqrt(rng.randf()) * rng.randf_range(0.55, 1.0)
		mm.set_instance_custom_data(i, Color(r, rng.randf() * TAU, rng.randf(), rng.randf() * TAU))
		mm.set_instance_color(i, colour(rng))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Petals"
	mmi.multimesh = mm
	mmi.custom_aabb = AABB(Vector3(-radius, -0.1, -radius), Vector3(radius * 2.0, 0.6, radius * 2.0))
	var m := ShaderMaterial.new()
	m.shader = PETALS
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
	return mmi
