extends "res://levels/primrose/keys/primrose_key.gd"
## Vesper's lesson at the Neighbourhood Watch hut (worlds/02_PRIMROSE_CLOSE.md "How it teaches" 1): the commands Fetch
## and Open, in the suit. She waits by the hut. Nim comes near in the suit (in her garb, Vesper sends her to number 4's
## porch to change): Vesper asks the watchman for the hut's key, and he fetches it; asks him to open the hut, and he
## does. The lesson's taught (Lessons.FETCH_OPEN). Then it's Nim's turn: have him fetch the Watch's thermos from beside
## the hut and open the postbox. Inside the postbox: forty party invitations, every one to a councillor. Vesper says
## her piece and walks off up Church Path to the steeple, where she'll watch from.

const HUT := Vector3(11.0, 0.12, -1.0)
const VESPER_AT := Vector3(7.6, 0.12, 0.6)
const WATCHMAN_AT := Vector3(8.6, 0.12, -3.2)
## Close enough (flat) for her to notice Nim.
const TRIGGER := 5.0
## Her way to the church: down the entrance pavement east, and up Church Path to the tower.
const EXIT := [Vector3(8.6, 0.12, 4.0), Vector3(48.0, 0.12, 4.0), Vector3(49.0, 0.12, -46.0), Vector3(54.0, 0.12, -46.0)]

var vesper: Talker
var watchman: Staff
var hut_key: KeyItem
var hut_door: Door
var thermos: Node3D
var postbox: Door
var _stage := 0
var _garb_said := false


func _setup() -> void:
	watchman = staff("Watchman", "Watchman", WATCHMAN_AT, PI / 2.0, "meerkat_watch", "On my knees? On the Watch's own lawn?")
	# The hut's key on a hook by its door, and the hut's door (on its west face, where the deco door is).
	hut_key = KeyItem.new()
	hut_key.id = &"watch_hut"
	hut_key.name = "HutKey"
	hut_key.position = HUT + Vector3(-1.38, 1.5, 0.55)
	add_child(hut_key)
	hut_door = door("HutDoor", HUT + Vector3(-1.45, 0.0, -0.7), HUT + Vector3(-3.0, 0.0, -0.7), 0.9, 2.1)
	# Nim's turn: the thermos on the windowsill, and the postbox's hatch.
	thermos = fetch_box("Thermos", &"thermos", HUT + Vector3(-1.5, 0.0, 1.0), Vector3(0.14, 0.32, 0.14), Color("b02a2a"))
	postbox = door("Postbox", Vector3(7.4, 0.62, -2.68), Vector3(7.4, 0.62, -1.6), 0.46, 0.5, Color("b8202a"))
	if flag("lesson_done"):
		hut_door.open()
		postbox.open()
		thermos.queue_free()
		return
	vesper = talker("Vesper_lesson", "vesper", "lesson_garb", VESPER_AT, -PI / 2.0, "vesper", "suit", "", Color("c0283e"))
	watchman.fetch_item = watchman.get_path_to(hut_key)
	watchman.door = watchman.get_path_to(hut_door)
	if Game.has_flag(Lessons.FETCH_OPEN):
		_your_turn()


func _physics_process(_delta: float) -> void:
	if vesper == null or Dialogue.is_active():
		return
	match _stage:
		0:
			var n := nim()
			if n == null or Vector2(n.global_position.x - VESPER_AT.x, n.global_position.z - VESPER_AT.z).length() > TRIGGER:
				return
			if not in_suit():
				if not _garb_said:
					_garb_said = true
					talk("vesper", "lesson_garb")
				return
			_stage = 1
			_demonstrate()
		2:
			if nim().suit.keys.has(&"thermos") and postbox.is_open:
				_stage = 3
				_finish()


## She asks, and he does it: the key fetched to her hand, the hut opened.
func _demonstrate() -> void:
	await talk("vesper", "lesson_watch")
	watchman.obey(&"fetch", vesper)
	await _done_with()
	await talk("vesper", "lesson_open")
	watchman.obey(&"open", vesper)
	await _done_with()
	await talk("vesper", "lesson_teach")
	Game.set_flag(Lessons.FETCH_OPEN)
	nim().known[Lessons.FETCH_OPEN] = true
	Hud.note("Learned: Fetch and Open. In the suit: D-pad right for Fetch, down for Open, then Y at them.")
	_your_turn()


## Until the watchman's back at his post.
func _done_with() -> void:
	await get_tree().physics_frame
	while is_instance_valid(watchman) and watchman.state != Staff.State.IDLE:
		await get_tree().physics_frame
	await get_tree().create_timer(0.3).timeout


func _your_turn() -> void:
	watchman.fetch_item = watchman.get_path_to(thermos)
	watchman.door = watchman.get_path_to(postbox)
	if vesper:
		vesper.label = "lesson_turn"
	_stage = 2


## The postbox's secret, her piece, and she walks off to the steeple (no vanishing).
func _finish() -> void:
	await talk("vesper", "lesson_done")
	set_flag("lesson_done")
	var v := vesper
	vesper = null
	if v == null or not is_instance_valid(v):
		return
	await v.walk_path(EXIT, 1.8)
	if is_instance_valid(v):
		v.queue_free()
