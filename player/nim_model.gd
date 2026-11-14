extends Node3D
## Nim's model (WO-011): both outfits' GLBs, one shown at a time, driven by what Nim, NimCombat and NimSuit are doing.
## Built by tools/nim_build.py (ART_DIRECTION.md, "The hero"). Each GLB carries the same 33 clips and face keys.
##
## Reads only Nim and its children, and reaches Dialogue at runtime (get_node_or_null): a probe compiles this before
## autoloads exist (HANDOFF, "compile-before-autoloads").
##
## - The clip follows her state every frame; one-shots (land, hurt, a command, Hold the Room, the mask) play through.
## - The garb's velvet muzzle (`Nim_garb_Mask` on the head bone) stays on, conversations included (owner, Deck
##   review 3); `mask_on` / `mask_off` click it into place if a scene ever takes it off (DESIGN.md, "Her velvet muzzle").
## - She blinks; her brows narrow while she fights (masked, the brows are her whole face: owner).

const GLB := {
	0: "res://assets/characters/nim/nim_garb.glb",
	1: "res://assets/characters/nim/nim_suit.glb",
}
## Her two-piece (WO-014b; DESIGN.md "The Velvet Rope's house", the dress code), worn only in the club's scenes when
## she's the sub: never a gameplay outfit, so NimSuit doesn't know it. Loaded the first time a scene asks (wear_swim):
## it's 43 MB, and most levels never need it.
const SWIM := 2
const SWIM_GLB := "res://assets/characters/nim/nim_swim.glb"
## How fast the moving clips' feet travel at speed scale 1 (m/s), so playback matches her real speed.
const CLIP_SPEED := {&"walk": 1.6, &"strut": 1.4, &"prowl": 1.5, &"run": 3.4, &"balance": 0.9, &"climb_up": 1.2,
	&"climb_side": 1.0, &"ceiling": 1.0, &"descend": 2.0}
const BLEND := 0.12
## Her head's in-game scale (core/bone_scale.gd). The A-pose sculpt's head was 0.59 m wide against the cast's
## 0.29-0.45, so it ran at 0.8, then 0.66 (owner: "Why is Nims head so oversized?"). The v15 T-pose remake shrinks
## the head in the sculpt itself (nim_build.py HEAD_SHRINK; owner: "make it smaller in the model too"), so 1.0:
## no BoneScale runs.
const HEAD_SCALE := 1.0
## The muzzle mask's own overall scale (it's under the head bone). It's fitted to the v15 face as built, so 1.0. (The
## A-pose head needed 0.8 against its 0.66 head: her muzzle shrank less than the rest.)
const MASK_SCALE := 1.0
## Snappier cross-fades for the fight: a strike's wind-up is 0.07 s (nim_combat.HITS), so the default blend would eat it.
const FAST_BLEND := {&"strike1": 0.03, &"strike2": 0.03, &"strike3": 0.04, &"pounce": 0.04}
## Faster than RUN_FROM is a run, and a run lasts until she's slower than RUN_TO. The walk's feet travel 1.6 m/s, so
## past about 2.5 a walk only plays faster. It was 3.6: pacing Dash at 3.6 m/s she walked at the 2x cap, feet barely
## off the ground and arms a blur, and that was what read as a jittery run (owner's Deck clips, 2026-11-12).
const RUN_FROM := 2.6
const RUN_TO := 2.2
## The walk and the strut never play faster than this.
const WALK_SCALE_MAX := 1.5
## The strut may play a little faster, so her feet keep up with her at its top speed (NimSuit.STRUT_SPEED).
const STRUT_SCALE_MAX := 1.8
## The run plays no faster than this: at her 7 m/s the cadence would otherwise pass six steps a second (it read as
## jitter on the Deck). Past it her feet slide a little, which reads better than a blur of legs.
const RUN_SCALE_MAX := 1.4
const MOVE_FROM := 0.3      # m/s: slower than this is standing
## The frame (at 24 fps) where the muzzle's catch clicks: it appears or disappears then.
const MASK_CLICK := 9.0 / 24.0

var nim: Node
var outfit := 0
var loaded := false
## Held still for a scene on the cross (core/cross_scene.gd): her clips stop, frozen on idle, so her bones can be posed.
var held := false
var mask_on := true

var _models: Array = [null, null, null]
var _players: Array = [null, null, null]
var _faces: Array = [null, null, null]
var _masks: Array[Node3D] = []   # each outfit's velvet muzzle (the garb's and the two-piece's)
## The outfit shown before wear_swim(true), to go back to (-1: not wearing it).
var _before_swim := -1
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
		if not _load(o, GLB[o]):
			return
	loaded = true
	var combat: Node = nim.get(&"combat")
	if combat:
		combat.connect(&"health_changed", _on_health)
	var suit: Node = nim.get(&"suit")
	if suit:
		suit.connect(&"gestured", _on_gesture)
		suit.connect(&"outfit_changed", set_outfit)


## One outfit's GLB into slot `o`, hidden unless it's the one shown. False if the file isn't there.
func _load(o: int, path: String) -> bool:
	var packed: PackedScene = load(path) if ResourceLoader.exists(path) else null
	if packed == null:
		return false
	var m: Node3D = packed.instantiate()
	m.rotation.y = PI   # the GLB faces +Z; Nim's front is -Z
	m.visible = o == outfit
	add_child(m)
	_dress(m)
	_models[o] = m
	_players[o] = m.find_child("AnimationPlayer", true, false)
	# Dash's crop, in her right hand while she cracks it (shown only then: owner, Deck clip 2026-11-13, "she never uses
	# an actual crop, she just spins her tail").
	var skel: Skeleton3D = null
	for s: Skeleton3D in m.find_children("*", "Skeleton3D", true, false):
		skel = s
		break
	if skel:
		var crop := RigGear.new(skel, get_parent() as Node3D).attach("handR", RigGear.tool_mesh("crop"), Vector3(0, 0.03, 0))
		if crop:
			crop.visible = false
			# Chunkier than the club's (that's seen up close): this one has to read from the follow camera, 5 m back.
			crop.scale = Vector3(2.2, 1.2, 2.2)
			_crops[o] = crop
	for sk: Skeleton3D in m.find_children("*", "Skeleton3D", true, false):
		var hs := BoneScale.new()
		hs.bone_name = &"head"
		hs.factor = HEAD_SCALE
		sk.add_child(hs)
	for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
		if mi.name.ends_with("_Mask"):
			_masks.append(mi)
			mi.visible = mask_on
			# The mask rides the head bone and shrinks by the full HEAD_SCALE, but her muzzle's skin is partly
			# weighted to the neck and shrinks less, so the shrunken mask sank into her face (owner, on the
			# Deck). It's shrunk only to MASK_SCALE overall.
			# Scaled about the head joint (the attachment's origin), not the mask node's own origin, which sits
			# far from the face (scaling about it lifted the mask over her brow).
			var k := MASK_SCALE / HEAD_SCALE
			mi.transform = Transform3D(mi.transform.basis.scaled(Vector3.ONE * k), mi.transform.origin * k)
		elif mi.mesh is ArrayMesh and (mi.mesh as ArrayMesh).get_blend_shape_count() > 0:
			_faces[o] = mi
	var ap: AnimationPlayer = _players[o]
	if ap:
		ap.animation_finished.connect(_on_finished)
		for loop_clip in [&"idle_garb", &"idle_suit", &"walk", &"prowl", &"strut", &"run", &"jump", &"fall",
				&"climb_up", &"climb_side", &"hang", &"balance", &"ceiling", &"descend", &"swing", &"bind",
				&"trance"]:
			if ap.has_animation(loop_clip):
				ap.get_animation(loop_clip).loop_mode = Animation.LOOP_LINEAR
	return true


## Her two-piece on (or off again, back to the outfit she had on) for a scene where she's the sub: the club's dress
## code (owner, Deck review 3: the one being led changes into it, and back after). Call it during a fade, before
## hold(true): hold() and skeleton() then work on the two-piece. Her gameplay outfit (NimSuit) never changes.
func wear_swim(on: bool) -> void:
	if not loaded:
		return
	if on:
		if _before_swim >= 0:
			return
		if _models[SWIM] == null and not _load(SWIM, SWIM_GLB):
			return
		_before_swim = outfit
		_show(SWIM)
	elif _before_swim >= 0:
		var back := _before_swim
		_before_swim = -1
		_show(back)


func wearing_swim() -> bool:
	return _before_swim >= 0


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
		_outlined.append(mi)


var _outlined: Array[MeshInstance3D] = []
var _outlines_off := false


## The camera's pressed right up to her (a wall behind it): her ink outline goes, since a shell a few millimetres out
## from every strap and edge shows through at that range as jagged dark cracks (owner, Deck review 5). The follow
## camera calls it.
func camera_close(on: bool) -> void:
	if on == _outlines_off:
		return
	_outlines_off = on
	for mi in _outlined:
		if is_instance_valid(mi):
			mi.material_overlay = null if on else Look.outline(mi.get_aabb(), OUTLINE_WIDTH)


## Show one outfit (NimSuit.Outfit: 0 garb, 1 suit). The clip carries over. While the two-piece is on, the change
## waits for it to come off.
func set_outfit(o: int) -> void:
	if not loaded:
		return
	if _before_swim >= 0:
		_before_swim = o
		return
	if o != outfit:
		_show(o)


func _show(o: int) -> void:
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


func hold(on: bool) -> void:
	held = on
	var ap: AnimationPlayer = _players[outfit]
	if ap == null:
		return
	var idle := &"idle_suit" if outfit == 1 else &"idle_garb"
	if on:
		ap.play(idle)
		ap.seek(0.0, true)
		ap.pause()
	else:
		var sk := skeleton()
		if sk:
			sk.reset_bone_poses()
		_clip = &""
		ap.play(idle)


## The crop's hit number in NimCombat (its CROP_HIT; a literal: this compiles before NimCombat's class is safe to name
## in a probe).
const CROP_HIT := 4
## The crop in her right hand, per outfit.
var _crops := {}


## The crop's snap at its tip, the moment it lands (NimCombat._strike_now): a white burst and a little "Crack!".
func crack_flash() -> void:
	var crop: Node3D = _crops.get(outfit)
	if crop == null or not is_instance_valid(crop):
		return
	# Where the lash lands: out in front of her at chest height (when the hit registers, the arm's still finishing its
	# wind-up, and the crop's own tip is down by her knees).
	var body := get_parent() as Node3D
	var ahead := -body.global_basis.z
	ahead.y = 0.0
	var tip := body.global_position + ahead.normalized() * 1.5 + Vector3.UP * 1.15
	var burst := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.12
	s.height = 0.24
	burst.mesh = s
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(2.4, 2.2, 1.8, 0.9)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	burst.material_override = m
	get_tree().current_scene.add_child(burst)
	burst.global_position = tip
	var word := Label3D.new()
	word.text = "Crack!"
	word.font_size = 48
	word.pixel_size = 0.006
	word.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	word.modulate = Color(2.0, 1.8, 1.2)
	word.outline_size = 10
	word.outline_modulate = Color(0.1, 0.02, 0.06)
	word.no_depth_test = true
	get_tree().current_scene.add_child(word)
	word.global_position = tip + Vector3.UP * 0.2
	var tw := burst.create_tween().set_parallel(true)
	tw.tween_property(burst, ^"scale", Vector3.ONE * 1.5, 0.18)
	tw.tween_property(m, ^"albedo_color:a", 0.0, 0.18)
	tw.chain().tween_callback(burst.queue_free)
	var tw2 := word.create_tween().set_parallel(true)
	tw2.tween_property(word, ^"global_position:y", word.global_position.y + 0.5, 0.6)
	tw2.tween_property(word, ^"modulate:a", 0.0, 0.6).set_delay(0.25)
	tw2.chain().tween_callback(word.queue_free)


func _cracking() -> bool:
	var combat: Node = nim.get(&"combat") if nim else null
	return combat != null and combat.call(&"striking") and int(combat.call(&"hit_number")) == CROP_HIT


func skeleton() -> Skeleton3D:
	var m: Node = _models[outfit]
	return m.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D if m else null


func _physics_process(delta: float) -> void:
	if not loaded:
		return
	_update_mask(delta)
	_update_face(delta)
	var cracking := _cracking()
	for o in _crops:
		var cr: Node3D = _crops[o]
		if is_instance_valid(cr):
			cr.visible = cracking and o == outfit
	if _oneshot != &"" or held:
		return
	var want := _pick()
	var ap: AnimationPlayer = _players[outfit]
	# The fight's clips play once and hold their last frame: a strike clip ends a few frames before the strike does,
	# and replaying it restarted the punch for those frames (owner: "She punches and it jerks back quickly").
	if want != _clip or (not ap.is_playing() and not FAST_BLEND.has(want)):
		_clip = want
		ap.play(want, FAST_BLEND.get(want, BLEND))
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
		if n == CROP_HIT:
			return &"strike1"   # the crop: her right arm's lash, the crop in that hand (strike3's spin was all tail)
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
	# A dead band: once running she keeps running down to RUN_TO, so a speed hovering at the threshold (pacing Dash
	# at 3.6 m/s, owner's Deck clip) doesn't flip walk and run back and forth through cross-fades.
	# In the suit, a strut is always the strut: the run waits for a real run (past the strut's top speed). Her strut
	# was 3.2 m/s, over RUN_FROM, so every strut flipped into the run clip and back (owner, Deck: "her hips jar back
	# and forth").
	var run_from := RUN_FROM
	var run_to := RUN_TO
	if outfit == 1:
		run_from = NimSuit.STRUT_SPEED + 0.6
		run_to = NimSuit.STRUT_SPEED + 0.3
	if flat > run_from or (_clip == &"run" and flat > run_to):
		return &"run"
	return &"strut" if outfit == 1 else &"walk"


func _speed_for(clip: StringName) -> float:
	if not CLIP_SPEED.has(clip):
		return 1.0
	var v: Vector3 = nim.get(&"velocity")
	var s := Vector2(v.x, v.z).length()
	if clip in [&"climb_up", &"descend"]:
		s = absf(v.y) + s * 0.3
	var top := RUN_SCALE_MAX if clip == &"run" else STRUT_SCALE_MAX if clip == &"strut" \
		else WALK_SCALE_MAX if clip == &"walk" else 2.0
	return clampf(s / CLIP_SPEED[clip], 0.5, top)


## For the perf overlay: the clip playing and its playback rate.
func clip_name() -> StringName:
	return _clip


func clip_scale() -> float:
	var ap: AnimationPlayer = _players.get(outfit)
	return ap.speed_scale if ap else 0.0


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
	# On, conversations and cutscenes included (owner, Deck review 3: "stop removing the masks during dialogues").
	if not mask_on and _mask_switch < 0.0:
		set_mask(true)
	if _mask_switch >= 0.0:
		_mask_switch -= delta
		if _mask_switch < 0.0:
			_apply_mask()


func _apply_mask() -> void:
	# Never with the two-piece: it's what she wears to be the sub in a scene, and her face (and a blindfold) should
	# show (owner, Deck review 5: "Nim should have her mask removed during the scenes").
	for m in _masks:
		if is_instance_valid(m):
			m.visible = mask_on and not wearing_swim()


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
