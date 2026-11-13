class_name EnemyModel
extends Node3D
## An enemy's model (WO-013): assets/enemies/<species>/<body>.glb, built by tools/enemy_build.py from Meshy's rig.
## Every GLB has idle, talk, walk and run; a fighter also has Meshy's library fight clips: combat_idle, jab, hit,
## knockdown. Enemy (core/enemy.gd) builds one in place of its greybox capsule when the GLB exists, and calls
## `show_state` every frame. Its collision, ? / ! marks and bound ropes stay its own.

const ROOT := "res://assets/enemies/%s/%s.glb"
## Feet speed at speed scale 1 (m/s), so a moving clip matches the ground.
const CLIP_SPEED := {&"walk": 1.3, &"run": 4.5}
const BLEND := 0.15
const RIM := 0.1
const OUTLINE_WIDTH := 0.01
## The bound ropes: velvet catches light at its edges.
const ROPE_RIM := 0.35
const ROPE_OUTLINE := 0.004
## Clips that play once and hold their last frame while the state lasts.
const ONCE := [&"jab", &"hit", &"knockdown"]

@export var body := "weasel_goon"
## Multiplies the texture: a crowd of four species reads as many people with a light tint each.
@export var tint := Color.WHITE

var loaded := false
## Held for a scene on the cross (hold()): show_state and pose leave it alone.
var held := false
var _player: AnimationPlayer
var _clip := &""
## The Rope's cord (`<body>_Ropes_*` in the GLB, on his bones): shown only while he's bound.
var _ropes: Array[Node3D] = []
## True when the GLB has a `bound` clip and its ropes: Enemy then hides its own greybox rings.
var has_bound := false


static func path_for(p_body: String) -> String:
	return ROOT % [p_body.get_slice("_", 0), p_body]


static func exists(p_body: String) -> bool:
	return p_body != "" and ResourceLoader.exists(path_for(p_body))


func _ready() -> void:
	if not exists(body):
		return
	var model: Node3D = (load(path_for(body)) as PackedScene).instantiate()
	model.rotation.y = PI   # the GLB faces +Z; a character's front is -Z
	add_child(model)
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		if "_Ropes" in String(mi.name):
			# Velvet cord: its twist texture (crimson strands, dark grooves) under the toon light, matte, with a
			# strong rim for the velvet's sheen at the edges, and a fine ink line.
			var rsrc := mi.get_active_material(0)
			var rtex: Texture2D = (rsrc as BaseMaterial3D).albedo_texture if rsrc is BaseMaterial3D else null
			mi.material_override = Look.toon(Color.WHITE if rtex else Look.VELVET, 0.0, ROPE_RIM, rtex)
			mi.material_overlay = Look.outline(mi.get_aabb(), ROPE_OUTLINE)
			mi.visible = false
			_ropes.append(mi)
			continue
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i)
			var tex: Texture2D = (src as BaseMaterial3D).albedo_texture if src is BaseMaterial3D else null
			mi.set_surface_override_material(i, Look.toon(tint, 0.0, RIM, tex))
		mi.material_overlay = Look.outline(mi.get_aabb(), OUTLINE_WIDTH)
	_player = model.find_child("AnimationPlayer", true, false)
	if _player:
		for clip in [&"idle", &"talk", &"walk", &"run", &"combat_idle", &"drink", &"sit"]:
			if _player.has_animation(clip):
				_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		for clip in ONCE:
			if _player.has_animation(clip):
				_player.get_animation(clip).loop_mode = Animation.LOOP_NONE
		if _player.has_animation(&"bound"):
			_player.get_animation(&"bound").loop_mode = Animation.LOOP_LINEAR
	has_bound = _player != null and _player.has_animation(&"bound") and not _ropes.is_empty()
	loaded = true


## The clip for an EnemyBase state (its State enum's order), its timer and his flat speed.
## PATROL 0, SUSPICIOUS 1, CHASE 2, FIGHT 3, SEARCH 4, RETURN 5, STAGGER 6, KNOCKDOWN 7, BINDING 8, BOUND 9, KNEEL 10,
## FROZEN 11.
func show_state(state: int, t: float, speed: float, recover: float) -> void:
	if _player == null or held:
		return
	var want := &"idle"
	match state:
		0, 1, 4, 5:
			want = &"walk" if speed > 0.2 else &"idle"
		2:
			want = &"run" if speed > 2.5 else (&"walk" if speed > 0.2 else &"combat_idle")
		3:
			# The wind-up squares up; the jab is thrown as the strike lands (the timer drops past `recover`).
			want = &"jab" if t <= recover + 0.25 else &"combat_idle"
		6:
			want = &"hit"
		7, 8:
			want = &"knockdown"
		9:
			# Bound: sat up, tied, struggling a little (the ropes show).
			want = &"bound" if has_bound else &"knockdown"
		10:
			want = &"idle"
		11:
			want = _clip if _clip != &"" else &"idle"
	if not _player.has_animation(want):
		want = &"idle" if want != &"run" or not _player.has_animation(&"walk") else &"walk"
	if want != _clip:
		_clip = want
		_player.play(want, BLEND)
		for r in _ropes:
			r.visible = want == &"bound"
	if state == 11:
		_player.speed_scale = 0.0          # frozen by the Scold, mid-step
	elif CLIP_SPEED.has(want):
		_player.speed_scale = clampf(speed / CLIP_SPEED[want], 0.5, 2.0)
	else:
		_player.speed_scale = 1.0


func clip_name() -> StringName:
	return _clip


## A named clip outside the Enemy states (the club's clients: "kneel", "drink", "sit"; WO-014b). `hold` 0..1 freezes
## it there (the kneel-and-stand transition, held at the kneel). False if the body hasn't the clip.
func pose(clip: StringName, hold := -1.0) -> bool:
	if _player == null or held or not _player.has_animation(clip):
		return false
	_clip = clip
	if hold >= 0.0:
		# No blend: frozen at speed 0, a blend from idle would never finish (it held the standing pose).
		_player.play(clip, 0.0)
		_player.seek(_player.get_animation(clip).length * hold, true)
		_player.speed_scale = 0.0
		return true
	_player.play(clip, BLEND)
	_player.speed_scale = 1.0
	return true


## Held still for a scene on the cross (core/cross_scene.gd): frozen on idle so the bones can be posed by hand.
func hold(on: bool) -> void:
	held = on
	if _player == null:
		return
	if on:
		_player.play(&"idle")
		_player.seek(0.0, true)
		_player.pause()
	else:
		var sk := skeleton()
		if sk:
			sk.reset_bone_poses()
		_clip = &""
		_player.speed_scale = 1.0
		_player.play(&"idle")


func skeleton() -> Skeleton3D:
	var all := find_children("*", "Skeleton3D", true, false)
	return all[0] as Skeleton3D if not all.is_empty() else null


## How high the head bone sits above their feet (Meshy's rig: "Head"; 0 if there's none). For placing what they hold.
## (The skinned meshes' own bounds are in the rig's units, not metres.)
func head_height() -> float:
	var skel := find_child("*Skeleton*", true, false) as Skeleton3D
	if skel == null:
		for s: Skeleton3D in find_children("*", "Skeleton3D", true, false):
			skel = s
			break
	if skel == null:
		return 0.0
	var head := skel.find_bone("Head")
	if head < 0:
		return 0.0
	return (skel.global_transform * skel.get_bone_global_pose(head)).origin.y - global_position.y
