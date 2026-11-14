extends SceneTree
## Dialogue portraits (owner, 2026-11-13: "a sleek Banjo style with a portrait of who is talking"), rendered from the
## game's own models: head and shoulders, three-quarter view, on a transparent ground (windowed; it needs a GPU):
##   godot --path . -s tools/portraits.gd -- [only_id ...]
## Writes assets/ui/portraits/<id>_<mood>.png, SIZE square. <id> is a cast member and outfit ("vesper_garb") or an
## enemy/civilian body ("hedgehog_civilian"). Moods, from the face keys (tools/cast_face.py): n (rest), up (brows
## up: warm, grin, shock...), down (brows down: cold, sly), blink. A body without face keys gets n only; the
## dialogue box falls back to n (core/dialogue.gd _portrait).

const OUT := "res://assets/ui/portraits"
const SIZE := 320
const CAST := {"nim": ["garb", "suit", "swim"], "vesper": ["garb", "suit"], "augusta": ["garb", "suit"],
	"silke": ["garb", "suit"], "dash": ["garb", "suit"], "rivet": ["garb", "suit"], "lull": ["garb", "suit"],
	"grizelda": ["garb", "suit"], "bastion": ["garb", "suit"], "swyne": [""]}
const BODIES := ["weasel_goon", "bulldog_goon", "stoat_courier", "laffer", "gander", "pearl_parrot", "meerkat_watch",
	"fox_civilian", "hare_civilian", "otter_civilian", "hedgehog_civilian"]
## Gagged: a body with the tape on (a boss after the finish's second half, owner 2026-11-14), as <body>_tape.
const GAGGED := ["laffer", "gander"]
## Framing fixes where the head bone misleads: [metres up, distance scale, metres forward].
const FRAME := {"laffer": [0.1, 2.5, 0.2], "laffer_tape": [0.1, 2.5, 0.2]}
const MOODS := {"n": {}, "up": {&"brow_up": 1.0}, "down": {&"brow_down": 1.0}, "blink": {&"blink_L": 1.0, &"blink_R": 1.0}}

var vp: SubViewport
var cam: Camera3D


func _initialize() -> void:
	var only := OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DisplayServer.window_set_size(Vector2i(400, 400))
	await process_frame
	vp = SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.62, 0.58, 0.6)
	vp.add_child(env)
	cam = Camera3D.new()
	cam.fov = 26.0
	vp.add_child(cam)
	cam.current = true
	var jobs: Array = []
	for who: String in CAST:
		for o: String in CAST[who]:
			jobs.append(["cast", who, o])
	for b: String in BODIES:
		jobs.append(["body", b, ""])
	for b: String in GAGGED:
		jobs.append(["body", b, "tape"])
	for j: Array in jobs:
		var id: String = j[1] if j[2] == "" else "%s_%s" % [j[1], j[2]]
		if not only.is_empty() and not only.has(id):
			continue
		await _shoot(j, id)
	quit()


func _shoot(j: Array, id: String) -> void:
	var holder := Node3D.new()
	vp.add_child(holder)
	var model: Node3D
	if j[0] == "cast":
		var cm := CastModel.new()
		cm.who = j[1]
		if j[2] != "":
			cm.outfit = j[2]
		model = cm
	else:
		var em := EnemyModel.new()
		em.body = j[1]
		model = em
	holder.add_child(model)
	for i in 40:   # loaded, posed in its idle
		await process_frame
	var sk: Skeleton3D = model.call(&"skeleton") if model.has_method(&"skeleton") else null
	if sk == null:
		print("portrait: no skeleton for ", id)
		holder.queue_free()
		return
	model.process_mode = Node.PROCESS_MODE_DISABLED   # the pose and the mask stay; the face keys are ours now
	var rig := RigGear.new(sk, holder)
	if j[0] == "body" and j[2] == "tape":
		rig.tape_colour = RigGear.DUCT   # (the bosses' duct tape, as laffer.gd and gander.gd put on)
		rig.gag("tape")
	var head := rig.head_frame()
	var mid: Vector3 = head.mid
	var fwd: Vector3 = head.fwd
	var r: float = head.r
	var side := Vector3.UP.cross(fwd).normalized()
	# Three-quarters on, a touch above the eyes; head and shoulders in frame, the head in the upper middle.
	var fix: Array = FRAME.get(id, [0.0, 1.0, 0.0])
	var look := mid + Vector3.DOWN * r * 0.45 + Vector3.UP * float(fix[0]) + fwd * float(fix[2])
	var dir := (fwd + side * 0.42).normalized()
	cam.global_position = look + dir * r * 11.0 * float(fix[1]) + Vector3.UP * r * 0.6
	cam.look_at(look, Vector3.UP)
	var key := DirectionalLight3D.new()
	holder.add_child(key)
	key.look_at_from_position(mid + (fwd + side * -0.8 + Vector3.UP * 0.9) * 2.0, mid, Vector3.UP)
	key.light_energy = 1.1
	var faces: Array[MeshInstance3D] = []
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh and mi.find_blend_shape_by_name(&"blink_L") >= 0:
			faces.append(mi)
	for mood: String in MOODS:
		if mood != "n" and faces.is_empty():
			break
		for mi in faces:
			for k: StringName in [&"blink_L", &"blink_R", &"brow_up", &"brow_down"]:
				var bi := mi.find_blend_shape_by_name(k)
				if bi >= 0:
					mi.set_blend_shape_value(bi, float((MOODS[mood] as Dictionary).get(k, 0.0)))
		for i in 4:
			await process_frame
		var img := vp.get_texture().get_image()
		img.save_png("%s/%s_%s.png" % [OUT, id, mood])
	print("portrait: %s (%d moods)" % [id, 4 if not faces.is_empty() else 1])
	holder.queue_free()
	await process_frame
