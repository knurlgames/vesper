extends "res://levels/pier/keys/pier_key.gd"
## Vesper's lesson under the pier (worlds/01_PIER.md "How it teaches" 2): the takedown from above. She waits on a
## cross-beam over the first of four smugglers. Nim comes near: Vesper tells her to watch, drops onto him and binds him
## in one move, teaches the lesson (Lessons.TAKEDOWN_ABOVE), and leaves the other three to her. When they're all tied
## she says her piece and goes up to the wheel.

const BEAM_Y := -3.2
const SAND := -6.0
## Where she waits: on the cross-beam at z -30, beside the goon under it.
const PERCH := Vector3(-1.4, BEAM_Y, -30.0)
const TRIGGER := Vector3(-3.0, SAND, -27.0)
## The lantern, hung from the deck's underside 3 m along the beam from her.
const LANTERN := Vector3(-4.4, BEAM_Y + 1.6, -30.3)
## Across the sand (flat distance), with Nim below the beams.
const TRIGGER_RANGE := 9.0
const STUDENTS: Array[StringName] = [&"u_lesson2", &"u_lesson3", &"u_lesson4"]
## Her way out when it's done: down the sandbar between the pilings (x -6 runs between their rows at -9 and -3),
## seaward, out of sight in the dark under the deck.
const EXIT := [Vector3(-6.0, SAND, -34.0), Vector3(-6.0, SAND, -62.0)]

var vesper: Talker
var _stage := 0


func _setup() -> void:
	if flag("lesson_done"):
		return
	vesper = talker("Vesper_lesson", "vesper", "lesson_watch", PERCH, PI / 2.0, "vesper", "garb", "", Color("c0283e"))
	# A fisherman's lantern hung off the deck a few metres along, dim: enough to see the beam she's standing on (in
	# the dark she read as floating in the air: owner, Deck clip), not enough to light her up.
	var lantern := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.18, 0.26, 0.18)
	lantern.mesh = box
	lantern.material_override = Look.toon(Color(2.2, 1.5, 0.7))
	lantern.position = LANTERN
	add_child(lantern)
	var glow := OmniLight3D.new()
	glow.light_color = Color("ffb868")
	glow.light_energy = 0.9
	glow.omni_range = 5.0
	glow.position = LANTERN + Vector3(0, -0.2, 0)
	add_child(glow)
	if Game.has_flag(Lessons.TAKEDOWN_ABOVE):
		_stage = 2
		vesper.label = "lesson_teach"


func _physics_process(_delta: float) -> void:
	if vesper == null or Dialogue.is_active():
		return
	match _stage:
		0:
			# She has to be down here, under the pier, and close: from the deck above (6 m up, inside the old 11 m
			# sphere) it started with Nim nowhere near (owner, Deck clip).
			var n := nim()
			if n and n.global_position.y < BEAM_Y - 0.5 \
					and Vector2(n.global_position.x - TRIGGER.x, n.global_position.z - TRIGGER.z).length() < TRIGGER_RANGE:
				_stage = 1
				_demonstrate()
		2:
			var done := STUDENTS.all(func(id: StringName) -> bool:
				var g := goon(id)
				return g == null or g.is_bound())
			if done:
				_stage = 3
				_finish()


## The demonstration is shot from its own camera, framing Vesper on the beam and the smuggler under her, so it's seen
## wherever the player was looking (on the Deck it played off-screen). The world keeps running for the drop and the
## scuffle; the player's camera comes back after her lesson.
func _demonstrate() -> void:
	var mark := goon(&"u_lesson1")
	var player_cam := get_viewport().get_camera_3d()
	var shot := Camera3D.new()
	shot.name = "LessonShot"
	add_child(shot)
	# Over Nim's shoulder: from just behind her, looking at Vesper on the beam and the smuggler under it, so it's her
	# view of it (a fixed far shot read as happening somewhere else).
	var look_at := PERCH.lerp(mark.global_position if mark else PERCH, 0.5) + Vector3(0, 0.3, 0)
	var her: Vector3 = nim().global_position
	var away := Vector3(her.x - look_at.x, 0.0, her.z - look_at.z)
	if away.length() < 3.0:
		away = Vector3(5.5, 0.0, 6.0)
	away = away.normalized() * clampf(away.length() + 2.2, 5.0, 9.0)
	shot.global_position = Vector3(look_at.x + away.x, her.y + 1.9, look_at.z + away.z)
	shot.look_at(look_at, Vector3.UP)
	shot.make_current()
	await talk("vesper", "lesson_watch")
	if mark and not mark.is_bound():
		# Off the beam, onto him: a short fall, a scuffle, and the knot's tied.
		var land := mark.global_position + Vector3(0.7, 0.0, 0.0)
		var tw := create_tween()
		tw.tween_property(vesper, ^"global_position", land, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tw.finished
		mark.begin_bind()
		var cloud := ScuffleCloud.new()
		pier.add_child(cloud)
		cloud.global_position = (mark.global_position + land) * 0.5
		cloud.hide_while([mark.get(&"_model"), vesper])
		await get_tree().create_timer(1.0).timeout
		cloud.poof()
		mark.finish_bind()
		await get_tree().create_timer(0.6).timeout
	await talk("vesper", "lesson_teach")
	if player_cam and is_instance_valid(player_cam):
		player_cam.make_current()
	shot.queue_free()
	Game.set_flag(Lessons.TAKEDOWN_ABOVE)
	nim().known[Lessons.TAKEDOWN_ABOVE] = true
	Hud.note("Learned: the takedown from above. Drop onto a goon from a beam or a ledge.")
	vesper.label = "lesson_teach"
	_stage = 2


## Her piece, then she goes: off down the sandbar toward the wheel, out of sight (no vanishing).
func _finish() -> void:
	await talk("vesper", "lesson_done")
	set_flag("lesson_done")
	var v := vesper
	vesper = null
	if v == null or not is_instance_valid(v):
		return
	await v.walk_path(EXIT, 2.0)
	if is_instance_valid(v):
		v.queue_free()
