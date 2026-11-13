extends SceneTree
## Checks every exported enemy GLB (WO-013, tools/enemy_build.py) the way the game uses it: the clips (a fighter has
## Meshy's fight clips too), the triangle budget, that EnemyModel loads and idles, and that an Enemy given the body
## shows the right clip for its state (a stagger plays the hit, a knock-down falls, a chase runs).
## godot --headless --fixed-fps 60 --path . -s tools/enemy_probe.gd
## Prints "ENEMY <file> ok" or what's wrong, then "ENEMY failures N".

const BODIES := {"weasel_goon": true, "badger_bouncer": true, "gull_lookout": false, "laffer": true,
	"bulldog_goon": true, "meerkat_watch": false, "gander": true,
	"rat_goon": true, "cormorant_lookout": false, "tusk": true, "stoat_customs": false,
	"sheep_orderly": true, "heron_staff": false, "strix": true,
	"mole_goon": true, "doberman_guard": true, "magpie_qc": false, "grubb": true,
	"stoat_courier": false}
const CLIPS := ["idle", "talk", "walk", "run", "bound"]
const FIGHT := ["combat_idle", "jab", "hit", "knockdown"]
const BUDGET := 80000

var failures := 0
var _models: Array[EnemyModel] = []
var _enemy: Enemy
var _frames := 0


func _fail(msg: String) -> void:
	failures += 1
	print("ENEMY FAIL ", msg)


func _initialize() -> void:
	var found := 0
	for body: String in BODIES:
		if not EnemyModel.exists(body):
			_fail("%s: no GLB at %s" % [body, EnemyModel.path_for(body)])
			continue
		found += 1
		_check(body, BODIES[body])
	print("ENEMY bodies ", found)
	# One live goon with a model, as a level places it.
	_enemy = Enemy.new()
	_enemy.body = "weasel_goon"
	get_root().add_child(_enemy)


func _check(body: String, fights: bool) -> void:
	var root: Node3D = (load(EnemyModel.path_for(body)) as PackedScene).instantiate()
	var ap: AnimationPlayer = root.find_child("AnimationPlayer", true, false)
	if ap == null:
		_fail("%s no AnimationPlayer" % body)
	else:
		for c in CLIPS + (FIGHT if fights else []):
			if not ap.has_animation(c):
				_fail("%s missing clip %s (has %s)" % [body, c, ", ".join(ap.get_animation_list())])
	var tris := 0
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi.mesh as ArrayMesh
		for s in m.get_surface_count():
			var idx := m.surface_get_array_index_len(s)
			tris += (idx if idx > 0 else m.surface_get_array_len(s)) / 3
	if tris > BUDGET:
		_fail("%s is %d triangles, over the budget (%d)" % [body, tris, BUDGET])
	root.free()
	var em := EnemyModel.new()
	em.body = body
	get_root().add_child(em)
	_models.append(em)
	print("ENEMY %s clips ok, tris %d" % [body, tris])


func _clip_of(e: Enemy) -> String:
	var ap: AnimationPlayer = e.find_child("AnimationPlayer", true, false)
	return String(ap.current_animation) if ap else ""


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 3:
		for em in _models:
			em.show_state(0, 0.0, 0.0, 0.9)
		return false
	if _frames == 5:
		for em in _models:
			if not em.loaded:
				_fail("%s EnemyModel didn't load" % em.body)
			elif em.clip_name() != &"idle":
				_fail("%s isn't idling (%s)" % [em.body, em.clip_name()])
		if _enemy.find_child("AnimationPlayer", true, false) == null:
			_fail("the Enemy with body weasel_goon has no model (still the capsule?)")
		_enemy.state = Enemy.State.STAGGER
		_enemy.set(&"_t", 0.8)
		return false
	if _frames == 8:
		_expect("hit", "staggered")
		_enemy.state = Enemy.State.KNOCKDOWN
		_enemy.set(&"_t", 1.8)
		return false
	if _frames == 11:
		_expect("knockdown", "knocked down")
		_enemy.call(&"_become_bound")
		return false
	if _frames == 14:
		_expect("bound", "bound (sat up and tied)")
		var ropes := _enemy.find_children("*_Ropes*", "MeshInstance3D", true, false)
		if ropes.is_empty():
			_fail("bound: no rope meshes in the model")
		elif not ropes.all(func(r: Node3D) -> bool: return r.is_visible_in_tree()):
			_fail("bound: the ropes aren't showing")
		else:
			print("ENEMY ok    bound shows %d ropes" % ropes.size())
		var rings: Node3D = _enemy.get(&"_ropes")
		if rings and rings.visible:
			_fail("bound: the greybox rings show as well as the model's ropes")
		print("ENEMY failures ", failures)
		quit(1 if failures else 0)
		return true
	return false


func _expect(clip: String, what: String) -> void:
	var got := _clip_of(_enemy)
	if got != clip:
		_fail("%s: playing %s, wanted %s" % [what, got, clip])
	else:
		print("ENEMY ok    %s plays %s" % [what, clip])
