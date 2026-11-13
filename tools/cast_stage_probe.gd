extends SceneTree
## The cast stage loads: all 17 cast bodies load their GLBs, the walkers move and play walk / run, the standing ones
## idle, Nim can walk up to the dais, and the perf overlay is up and producing numbers.
##   godot --headless --fixed-fps 60 --path . -s tools/cast_stage_probe.gd

const In := preload("res://tools/probe_input.gd")
const CAST := 17

var fails := 0


func _initialize() -> void:
	root.size = Vector2i(1280, 800)
	await process_frame
	var game := root.get_node("/root/Game")
	game.set(&"persist", false)
	game.call(&"set_setting", "age_confirmed", true)
	var scene: Node = load("res://levels/cast_stage/cast_stage.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 10:
		await physics_frame
	var cast: Array = scene.get(&"cast")
	_check(cast.size() == CAST, "%d cast bodies placed (want %d)" % [cast.size(), CAST])
	var names := {}
	var missing: Array[String] = []
	for cm: Node in cast:
		names["%s_%s" % [cm.get(&"who"), cm.get(&"outfit")]] = true
		if not cm.get(&"loaded"):
			missing.append(String(cm.name))
	_check(names.size() == CAST, "every body is different (%d distinct)" % names.size())
	_check(missing.is_empty(), "every body's GLB loaded%s" % ("" if missing.is_empty() else ": missing " + ", ".join(missing)))
	# The garbs wear their masks.
	var garbs := 0
	for cm: Node in cast:
		if cm.get(&"outfit") == "garb" and cm.get(&"who") != "swyne":
			garbs += 1
			_check(cm.get(&"masked") == true, "%s is masked" % cm.name)
	_check(garbs == 8, "8 garbs (%d)" % garbs)

	# WO-013's enemies: the lineup's models, and the live goons wearing theirs (not the capsule).
	var lineup: Array = scene.get(&"lineup")
	_check(lineup.size() == 19, "19 enemies in the lineup (%d)" % lineup.size())
	for em: Node in lineup:
		_check(em.get(&"loaded") == true and em.call(&"clip_name") == &"idle", "%s stands and idles" % em.name)
	var goons: Array = scene.get(&"goons")
	_check(goons.size() == 2, "2 live goons (%d)" % goons.size())
	for g: Node in goons:
		_check(g.find_child("AnimationPlayer", true, false) != null, "%s wears his model" % g.get(&"body"))

	# Walkers move, and play a moving clip; standing ones idle.
	var before := {}
	for cm: Node3D in cast:
		before[cm] = cm.global_position
	for i in 120:
		await physics_frame
	var walking := 0
	for cm: Node3D in cast:
		var moved: float = cm.global_position.distance_to(before[cm])
		var player: AnimationPlayer = cm.find_child("AnimationPlayer", true, false)
		var clip := String(player.current_animation) if player else ""
		if cm.get(&"speed") > 0.0:
			walking += 1
			_check(moved > 1.5 and clip in ["walk", "run"], "%s walks the loop (%.1f m in 2 s, %s)" % [cm.name, moved, clip])
		else:
			_check(moved < 0.001 and clip == "idle", "%s stands and idles (%s)" % [cm.name, clip])
	_check(walking == 4, "4 walkers (%d)" % walking)

	# Nim walks north from the spawn and is stopped by the dais's front rank (or steps up on it): she gets close.
	var nim: CharacterBody3D = scene.get(&"nim")
	var cam: Node3D = scene.get(&"cam")
	cam.set(&"yaw", 0.0)
	var start := nim.global_position
	In.stick(JOY_AXIS_LEFT_Y, -1.0)
	for i in 180:
		await physics_frame
	In.stick(JOY_AXIS_LEFT_Y, 0.0)
	for i in 20:
		await physics_frame
	var p := nim.global_position
	_check(p.z < start.z - 8.0 and p.y > -0.5, "Nim walks up to the dais (z %.1f to %.1f)" % [start.z, p.z])
	# Whoever stands near her talks (the stage's demo), and nobody far away does.
	for i in 20:
		await physics_frame
	var talkers := 0
	for cm: Node3D in cast:
		if cm.get(&"speed") > 0.0:
			continue
		var player: AnimationPlayer = cm.find_child("AnimationPlayer", true, false)
		var clip := String(player.current_animation) if player else ""
		var near := cm.global_position.distance_to(nim.global_position) < 3.5
		_check(clip == ("talk" if near else "idle"), "%s %s near Nim (%s)" % [cm.name, "talks" if near else "idles", clip])
		talkers += int(near)
	_check(talkers >= 1, "someone near the dais talks (%d)" % talkers)

	# Pacing Dash (about 3.6 m/s, a part-way stick) she runs, never a walk at its speed cap (owner's Deck clips).
	var model: Node = nim.get(&"model")
	var paced := false
	for tilt in [0.45, 0.5, 0.55, 0.6, 0.65, 0.7]:
		In.stick(JOY_AXIS_LEFT_Y, tilt)        # back south, into the open
		for i in 30:
			await physics_frame
		var v := nim.velocity
		var sp := Vector2(v.x, v.z).length()
		if sp > 3.2 and sp < 4.2:
			paced = true
			_check(model.call(&"clip_name") == &"run", "at %.1f m/s she runs (%s x%.2f)" % [sp,
				model.call(&"clip_name"), model.call(&"clip_scale")])
			break
	_check(paced, "a part-way stick paces Dash")
	In.stick(JOY_AXIS_LEFT_Y, 0.0)

	# The overlay is up and has numbers.
	var overlay: Node = scene.get(&"_overlay")
	_check(overlay != null and overlay.get(&"shown") == true, "the perf overlay is on")
	if overlay:
		var text: String = overlay.call(&"readout")
		_check(text.contains("fps") and text.contains("draws"), "the overlay reads out")
		print(text)
	print("cast stage probe: %d failures" % fails)
	quit(1 if fails else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
