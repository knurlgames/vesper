extends RefCounted
## Plays Nim with real input for probes: the left stick, A, B and RT go in as pad events (tools/probe_input.gd), so a
## probe tests the bindings and the controller together. Every wait is in physics frames at 60 per second.

const In := preload("res://tools/probe_input.gd")

var tree: SceneTree
var nim: Nim
var cam: Node3D
var fails := 0


func _init(t: SceneTree, n: Nim, c: Node3D) -> void:
	tree = t
	nim = n
	cam = c


## Standing at `at`, facing (and the camera looking) `yaw`, every input let go, settled on the ground.
func place(at: Vector3, yaw := 0.0) -> void:
	release_all()
	nim.teleport(at, yaw)
	cam.set(&"yaw", yaw)
	await frames(15)


func frames(n: int) -> void:
	for i in n:
		await tree.physics_frame


func secs(s: float) -> void:
	await frames(int(s * 60.0))


## Waits until `cond` is true, up to `timeout` seconds. Returns whether it came true.
func until(cond: Callable, timeout: float) -> bool:
	for i in int(timeout * 60.0):
		if cond.call():
			return true
		await tree.physics_frame
	return cond.call()


## The left stick: x right, y down (so y -1 is "up", away from the camera).
func stick(x: float, y: float) -> void:
	In.stick(JOY_AXIS_LEFT_X, x)
	In.stick(JOY_AXIS_LEFT_Y, y)


## The stick pushed toward a world direction, through the camera (the way a player would); `push` under 1 is part-way.
func steer(dir: Vector3, push := 1.0) -> void:
	dir.y = 0.0
	if dir.length() < 0.01:
		stick(0.0, 0.0)
		return
	dir = dir.normalized()
	var f: Vector3 = cam.call(&"forward")
	var r := Vector3(-f.z, 0.0, f.x)
	stick(dir.dot(r) * push, -dir.dot(f) * push)


## Reads a conversation through the way a player would: A on each line (after the box's opening guard), up to
## `timeout` seconds. Picks the first choice whenever there are choices. True if it ended.
func talk_through(timeout := 20.0) -> bool:
	var dialogue: Node = tree.root.get_node(^"/root/Dialogue")
	await frames(2)
	var t := 0.0
	while dialogue.call(&"is_active") and t < timeout:
		await secs(0.45)
		await tap(JOY_BUTTON_A)
		t += 0.5
	return not dialogue.call(&"is_active")


## LT (an axis): held or let go.
func lock_on(on: bool) -> void:
	In.stick(JOY_AXIS_TRIGGER_LEFT, 1.0 if on else 0.0)


func button(b: JoyButton, down: bool) -> void:
	In.button(b, down)


## A press held for `hold` seconds (a jump held to its apex is about 0.35).
func tap(b: JoyButton, hold := 0.05) -> void:
	In.button(b, true)
	await secs(hold)
	In.button(b, false)


func jump(hold := 0.4) -> void:
	await tap(JOY_BUTTON_A, hold)


## RT is an axis.
func pounce() -> void:
	In.stick(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await frames(3)
	In.stick(JOY_AXIS_TRIGGER_RIGHT, 0.0)


func release_all() -> void:
	stick(0.0, 0.0)
	In.stick(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	In.stick(JOY_AXIS_TRIGGER_LEFT, 0.0)
	for b: JoyButton in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y]:
		In.button(b, false)


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("%s  %s" % ["ok  " if ok else "FAIL", what])


## Where she is, for messages.
func at() -> String:
	var p := nim.global_position
	return "(%.2f, %.2f, %.2f)" % [p.x, p.y, p.z]
