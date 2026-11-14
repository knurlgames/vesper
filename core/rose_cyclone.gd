class_name RoseCyclone
extends Node3D
## Fast travel's going and coming (owner, 2026-11-14: "when you execute the travel it wraps you up in a cyclone of rose
## buds and then they dissapate into the ground once you arrive"):
##   - WRAP: buds and petals rise off the ground round her, spinning faster and drawing in, until she's hidden;
##   - then she's moved, and the cyclone stands round her at the other end, already full;
##   - SINK: it slows and opens out and the buds sink into the ground and are gone.
## One MultiMesh for the buds and one for the petals, moved here each frame (260 instances; thick enough to hide her).
##
##   await RoseCyclone.travel(nim, to, yaw)

enum Mode { WRAP, SINK }

const BUDS := 90
const LEAVES := 170
const WRAP_SECS := 1.0
const SINK_SECS := 1.2
## Its shape when it's full: how wide and how tall.
const RADIUS := 0.5
const HEIGHT := 2.3
const BUD := preload("res://shaders/rose_bud.gdshader")

var mode := Mode.WRAP
var _t := 0.0
var _buds: MultiMesh
var _leaves: MultiMesh
## Per instance: [angle, height share, radius share, speed, size, tumble].
var _p: Array = []

signal finished


## Wraps her up where she stands, moves her to `to` facing `yaw`, and unwraps her there. Her physics is held
## throughout. Await it.
static func travel(nim: Node3D, to: Vector3, yaw: float) -> void:
	var scene := nim.get_tree().current_scene
	var held := nim.is_physics_processing()
	nim.set_physics_process(false)
	if nim.get(&"velocity") != null:
		nim.set(&"velocity", Vector3.ZERO)
	var a := RoseCyclone.new()
	scene.add_child(a)
	a.global_position = nim.global_position
	await a.play(Mode.WRAP)
	nim.visible = false
	nim.call(&"teleport", to, yaw)
	a.queue_free()
	var b := RoseCyclone.new()
	scene.add_child(b)
	b.global_position = to
	b.mode = Mode.SINK
	b._place(0.0)
	await nim.get_tree().process_frame
	nim.visible = true
	await b.play(Mode.SINK)
	b.queue_free()
	if held and is_instance_valid(nim):
		nim.set_physics_process(true)


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # (a menu may have paused the world as it closes)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_buds = _multimesh(RosePetals.bud_mesh(), BUDS, rng)
	_leaves = _multimesh(RosePetals.petal_mesh(), LEAVES, rng)
	for i in BUDS + LEAVES:
		_p.append([rng.randf() * TAU, pow(rng.randf(), 0.8), rng.randf_range(0.7, 1.25), rng.randf_range(0.8, 1.3),
			rng.randf_range(0.8, 1.25), rng.randf() * TAU])


func _multimesh(mesh: Mesh, n: int, rng: RandomNumberGenerator) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = n
	for i in n:
		mm.set_instance_color(i, RosePetals.colour(rng))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.custom_aabb = AABB(Vector3(-2, -0.5, -2), Vector3(4, 3.5, 4))
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = BUD
	mmi.material_override = m
	add_child(mmi)
	return mm


## Runs `m` to its end. Await it.
func play(m: Mode) -> Signal:
	mode = m
	_t = 0.0
	_place(0.0)
	return finished


func _process(delta: float) -> void:
	var secs := WRAP_SECS if mode == Mode.WRAP else SINK_SECS
	if _t >= 1.0:
		return
	_t = minf(1.0, _t + delta / secs)
	_place(_t)
	if _t >= 1.0:
		finished.emit()


## Every bud and petal at progress `u` (0..1) through the mode.
func _place(u: float) -> void:
	for i in BUDS + LEAVES:
		var p: Array = _p[i]
		var e: float
		var r: float
		var y: float
		var spin: float
		var size: float
		if mode == Mode.WRAP:
			e = u * u * (3.0 - 2.0 * u)
			r = lerpf(1.25, RADIUS, e) * p[2]
			y = p[1] * lerpf(0.05, HEIGHT, e)
			spin = p[0] + (u * u * 9.0 + u * 3.0) * p[3]
			size = clampf(u * 4.0, 0.2, 1.0)
		else:
			e = u * u
			r = lerpf(RADIUS, 1.1, sqrt(u)) * p[2]
			y = p[1] * HEIGHT * pow(1.0 - u, 1.6) - smoothstep(0.55, 1.0, u) * 0.35   # down, and into the ground
			spin = p[0] + 12.0 * p[3] + (1.0 - (1.0 - u) * (1.0 - u)) * 5.0 * p[3]
			size = 1.0 - smoothstep(0.7, 1.0, u)
		var at := Vector3(cos(spin) * r, y, sin(spin) * r)
		var tumble: float = p[5] + spin * 1.7
		var turn := Basis(Vector3.UP, -spin) * Basis(Vector3.RIGHT, 0.5 + 0.4 * sin(tumble)) \
			* Basis.from_scale(Vector3.ONE * maxf(0.001, size * p[4]))
		if i < BUDS:
			_buds.set_instance_transform(i, Transform3D(turn, at))
		else:
			_leaves.set_instance_transform(i - BUDS, Transform3D(turn * Basis(Vector3.FORWARD, tumble), at))
