extends SceneTree
## The style-test corner is walkable: Nim gets up and down the kerbs, can't walk through a lamp or a building, and the
## scene loads without errors.
##   godot --headless --fixed-fps 60 --path . -s tools/corner_probe.gd

const In := preload("res://tools/probe_input.gd")
const KERB := 0.12

var fails := 0
var nim: CharacterBody3D
var cam: Node3D


func _initialize() -> void:
	await process_frame
	var game := root.get_node("/root/Game")
	game.set(&"persist", false)
	game.call(&"set_setting", "age_confirmed", true)
	var scene: Node = load("res://levels/style_test/corner.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 5:
		await physics_frame
	nim = scene.get(&"nim")
	cam = scene.get(&"cam")

	# Up the kerb: from the road onto the club's pavement, stopping at the club's wall (x 7.2).
	var p := await _walk(Vector3(0, 0.05, -10), -PI / 2.0, 1.2)
	_check(p.y > KERB - 0.02 and p.x > 5.5 and p.x < 7.2, "up the kerb onto the pavement, stopped by the wall (%.2f, %.2f)" % [p.x, p.y])
	# Down the kerb: back into the road.
	p = await _walk(Vector3(6.5, KERB + 0.05, -10), PI / 2.0, 1.0)
	_check(p.y < 0.05 and p.x < 3.0, "down the kerb into the road (%.2f, %.2f)" % [p.x, p.y])
	# A lamp is solid: walking straight at the one on the SW corner (-6, 6) stops her short of it.
	p = await _walk(Vector3(-6, KERB + 0.05, 10), 0.0, 1.0)
	_check(p.z > 6.2, "a lamp stops her (z %.2f)" % p.z)
	print("corner probe: %d failures" % fails)
	quit(1 if fails else 0)


func _walk(from: Vector3, yaw: float, secs: float) -> Vector3:
	nim.global_position = from
	nim.velocity = Vector3.ZERO
	cam.set(&"yaw", yaw)
	for i in 20:
		await physics_frame
	In.stick(JOY_AXIS_LEFT_Y, -1.0)
	for i in int(secs * 60):
		await physics_frame
	In.stick(JOY_AXIS_LEFT_Y, 0.0)
	for i in 20:
		await physics_frame
	return nim.global_position


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
