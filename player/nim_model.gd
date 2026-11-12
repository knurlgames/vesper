extends Node3D
## Nim's model (WO-011): both outfits' GLBs, one shown at a time, driven by what Nim, NimCombat and NimSuit are doing.
## Built by tools/nim_build.py (ART_DIRECTION.md, "The hero"). Each GLB carries the same 33 clips and face keys.
##
## Reads only Nim and its children, and reaches Dialogue at runtime (get_node_or_null): a probe compiles this before
## autoloads exist (HANDOFF, "compile-before-autoloads").
##
## - The clip follows her state every frame; one-shots (land, hurt, a command, Hold the Room, the mask) play through.
## - The garb's velvet muzzle (`Nim_garb_Mask` on the head bone) is on while she's covert and off in conversation,
##   with `mask_on` / `mask_off` clicking it into place (DESIGN.md, "Her velvet muzzle").
## - She blinks; her brows narrow while she fights (masked, the brows are her whole face: owner).

const GLB := {
	0: "res://assets/characters/nim/nim_garb.glb",
	1: "res://assets/characters/nim/nim_suit.glb",
}
## How fast the moving clips' feet travel at speed scale 1 (m/s), so playback matches her real speed.
const CLIP_SPEED := {&"walk": 1.6, &"strut": 1.4, &"prowl": 1.5, &"run": 5.5, &"balance": 0.9, &"climb_up": 1.2,
	&"climb_side": 1.0, &"ceiling": 1.0, &"descend": 2.0}
const BLEND := 0.12
const RUN_FROM := 3.6       # m/s: faster than this is a run
const MOVE_FROM := 0.3      # m/s: slower than this is standing
## The frame (at 24 fps) where the muzzle's catch clicks: it appears or disappears then.
const MASK_CLICK := 9.0 / 24.0

var nim: Node
var outfit := 0
var loaded := false
var mask_on := true

var _models: Array = [null, null]
var _players: Array = [null, null]
var _faces: Array = [null, null]
var _mask: Node3D
var _clip := &""
var _oneshot := &""
var _was_air := false
var _blink_t := 2.0
var _blink := 0.0
var _mask_switch := -1.0
var _health := -1


func _ready() -> void:
	nim = get_parent()
	for o in GLB:
		var packed: PackedScene = load(GLB[o]) if ResourceLoader.exists(GLB[o]) else null
		if packed == null:
			return
		var m: Node3D = packed.instantiate()
		m.rotation.y = PI   # the GLB faces +Z; Nim's front is -Z
		m.visible = o == outfit
		add_child(m)
		_dress(m)
		_models[o] = m
		_players[o] = m.find_child("AnimationPlayer", true, false)
		for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
			if mi.name.ends_with("_Mask"):
				if o == 0:
					_mask = mi
			elif mi.mesh is ArrayMesh and (mi.mesh as ArrayMesh).get_blend_shape_count() > 0:
				_faces[o] = mi
		for ap: AnimationPlayer in [_players[o]]:
			if ap:
				ap.animation_finished.connect(_on_finished)
				for loop_clip in [&"idle_garb", &"idle_suit", &"walk", &"prowl", &"strut", &"run", &"jump", &"fall",
						&"climb_up", &"climb_side", &"hang", &"balance", &"ceiling", &"descend", &"swing", &"bind",
						&"trance"]:
					if ap.has_animation(loop_clip):
						ap.get_animation(loop_clip).loop_mode = Animation.LOOP_LINEAR
	loaded = true
	var combat: Node = nim.get(&"combat")
	if combat:
		combat.connect(&"health_changed", _on_health)
	var suit: Node = nim.get(&"suit")
	if suit:
		suit.connect(&"gestured", _on_gesture)
		suit.connect(&"outfit_changed", set_outfit)


## The game's look (ART_DIRECTION §4): every surface becomes the toon ramp with its own colour and texture, an ink
## outline, and her light rim (she must read against every world, §3). Only brass shines (§2).
const RIM := 0.18
const OUTLINE_WIDTH := 0.008


func _dress(root: Node) -> void:
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i)
			var colour := Color.WHITE
			var tex: Texture2D = null
			var gloss := 0.0
			if src is BaseMaterial3D:
				colour = (src as BaseMaterial3D).albedo_color
				tex = (src as BaseMaterial3D).albedo_texture
				if src.resource_name.contains("brass"):
					gloss = 0.9
				elif src.resource_name.contains("leather"):
					gloss = 0.3
			mi.set_surface_override_material(i, Look.toon(colour, gloss, RIM, tex))
		mi.material_overlay = Look.outline(mi.get_aabb(), OUTLINE_WIDTH)


## Show one outfit (NimSuit.Outfit: 0 garb, 1 suit). The clip carries over.
func set_outfit(o: int) -> void:
	if not loaded or o == outfit:
		return
	var t := 0.0
	var ap: AnimationPlayer = _players[outfit]
	if ap and ap.is_playing():
		t = ap.current_animation_position
		ap.stop()
	_models[outfit].visible = false
	outfit = o
	_models[outfit].visible = true
	if _clip != &"":
		_players[outfit].play(_clip)
		_players[outfit].seek(t, true)
	_apply_mask()


func _physics_process(delta: float) -> void:
	if not loaded:
		return
	_update_mask(delta)
	_update_face(delta)
	if _oneshot != &"":
		return
	var want := _pick()
	var ap: AnimationPlayer = _players[outfit]
	if want != _clip or not ap.is_playing():
		_clip = want
		ap.play(want, BLEND)
	ap.speed_scale = _speed_for(want)


func _pick() -> StringName:
	var combat: Node = nim.get(&"combat")
	var suit: Node = nim.get(&"suit")
	if combat and combat.call(&"is_down"):
		return &"knockdown"
	if suit and suit.call(&"changing"):
		return &"change"
	if combat and combat.call(&"striking"):
		var n: int = combat.call(&"hit_number")
		return [&"strike1", &"strike2", &"strike3"][clampi(n, 1, 3) - 1]
	if combat and combat.call(&"binding"):
		return &"bind"
	var state: int = nim.get(&"state")
	var v: Vector3 = nim.get(&"velocity")
	var flat := Vector2(v.x, v.z).length()
	match state:
		1:  # BALANCE
			return &"balance"
		2:  # CLIMB
			if nim.call(&"headfirst"):
				return &"descend"
			return &"climb_side" if absf(v.y) < flat else &"climb_up"
		3:  # HANG
			return &"hang"
		4:  # MANTLE
			return &"mantle"
		5:  # CEILING
			return &"ceiling"
		6:  # SWING
			return &"swing"
	if nim.call(&"pouncing"):
		return &"pounce"
	var on_floor: bool = nim.call(&"is_on_floor")
	if not on_floor:
		_was_air = true
		return &"jump" if v.y > 0.0 else &"fall"
	if _was_air:
		_was_air = false
		_play_once(&"land")
		return &"land"
	var trance: bool = suit != null and suit.get(&"faking_trance")
	if trance:
		return &"trance"
	if flat < MOVE_FROM:
		return &"idle_suit" if outfit == 1 else &"idle_garb"
	if nim.get(&"crouching"):
		return &"prowl"
	if flat > RUN_FROM:
		return &"run"
	return &"strut" if outfit == 1 else &"walk"


func _speed_for(clip: StringName) -> float:
	if not CLIP_SPEED.has(clip):
		return 1.0
	var v: Vector3 = nim.get(&"velocity")
	var s := Vector2(v.x, v.z).length()
	if clip in [&"climb_up", &"descend"]:
		s = absf(v.y) + s * 0.3
	return clampf(s / CLIP_SPEED[clip], 0.5, 2.0)


func _play_once(clip: StringName) -> void:
	var ap: AnimationPlayer = _players[outfit]
	if not ap.has_animation(clip):
		return
	_oneshot = clip
	_clip = clip
	ap.speed_scale = 1.0
	ap.play(clip, BLEND)


func _on_finished(anim: StringName) -> void:
	if anim == _oneshot:
		_oneshot = &""


func _on_gesture(what: StringName) -> void:
	_play_once(&"hold_room" if what == &"hold_room" else StringName("cmd_" + String(what)))


func _on_health(current: int, _maximum: int) -> void:
	if _health >= 0 and current < _health and current > 0:
		_play_once(&"hurt")
	_health = current


# --- the muzzle --------------------------------------------------------------------------------------------------------

## Put the muzzle on or take it off. With animate, she plays the click (and the mesh swaps on the click's frame).
func set_mask(on: bool, animate := true) -> void:
	if on == mask_on:
		return
	mask_on = on
	if animate and outfit == 0 and _oneshot == &"":
		_play_once(&"mask_on" if on else &"mask_off")
		_mask_switch = MASK_CLICK
	else:
		_apply_mask()


func _update_mask(delta: float) -> void:
	# Covert in the garb, it's on; in any conversation or cutscene, it's off.
	var dlg := get_node_or_null(^"/root/Dialogue")
	var talking: bool = dlg != null and dlg.has_method(&"is_active") and dlg.call(&"is_active")
	var want := not talking
	if want != mask_on:
		set_mask(want, not talking)   # off at once for dialogue; clicked back on after
	if _mask_switch >= 0.0:
		_mask_switch -= delta
		if _mask_switch < 0.0:
			_apply_mask()


func _apply_mask() -> void:
	if _mask:
		_mask.visible = mask_on


# --- the face ----------------------------------------------------------------------------------------------------------

func _update_face(delta: float) -> void:
	var face: MeshInstance3D = _faces[outfit]
	if face == null:
		return
	_blink_t -= delta
	if _blink_t <= 0.0:
		_blink = 0.14
		_blink_t = randf_range(2.0, 5.0)
	var b := 0.0
	if _blink > 0.0:
		_blink -= delta
		b = sin(clampf(1.0 - _blink / 0.14, 0.0, 1.0) * PI)
	face.set_blend_shape_value(face.find_blend_shape_by_name(&"blink_L"), b)
	face.set_blend_shape_value(face.find_blend_shape_by_name(&"blink_R"), b)
	# Her brows: narrowed in a fight, a heavy-lidded squint in the fake trance.
	var combat: Node = nim.get(&"combat")
	var suit: Node = nim.get(&"suit")
	var fighting: bool = combat != null and (combat.call(&"striking") or combat.get(&"lock") != null)
	var trance: bool = suit != null and suit.get(&"faking_trance")
	_ease_shape(face, &"brow_narrow", 1.0 if fighting else 0.0, delta)
	_ease_shape(face, &"squint", 0.8 if trance else 0.0, delta)


func _ease_shape(face: MeshInstance3D, shape: StringName, target: float, delta: float) -> void:
	var i := face.find_blend_shape_by_name(shape)
	if i < 0:
		return
	face.set_blend_shape_value(i, move_toward(face.get_blend_shape_value(i), target, delta * 6.0))
