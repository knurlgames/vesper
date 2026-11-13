class_name Level
extends Node3D
## What every level shares: Nim and the follow camera, a fall reset, the age gate on start, box helpers for code-built
## geometry, and Back / Tab to flip between the playable test scenes (a prototype convenience).

const FollowCam := preload("res://core/follow_cam.gd")
## Back / Tab cycles through these.
const TEST_SCENES := ["res://levels/test_course/course.tscn", "res://levels/cast_stage/cast_stage.tscn",
	"res://levels/style_test/corner.tscn", "res://main.tscn", "res://levels/probe_world/probe_world.tscn",
	"res://levels/pier/pier.tscn", "res://levels/hub/hub.tscn"]

const FALL_Y := -20.0

## Which world this is (Game counts collectibles and remembers bound goons per world).
var world_id: StringName = &"test"
var nim: Nim
var cam: Node3D
## Where she comes back: the spawn, then the last checkpoint she passed.
var spawn_at := Vector3.ZERO
var spawn_yaw := 0.0
var _checkpoint: Node


## Named places to come in at (`Game.arrive`, set by Game.travel): a door from another world, "@wardrobe" for the
## pause menu's "Back to the last wardrobe". Register them before spawn_player.
var arrivals := {}


func arrival(id: String, at: Vector3, yaw := 0.0) -> void:
	arrivals[id] = [at, yaw]


## Puts Nim and the camera in, facing `yaw` (the camera looks the same way), and asks the age question if it's needed.
## If she's arriving somewhere named (Game.arrive), she comes in there instead.
func spawn_player(at: Vector3, yaw := 0.0) -> void:
	var come := Game.arrive
	Game.arrive = ""
	if come == "@wardrobe" and Game.last_wardrobe.get("scene") == scene_file_path:
		var p: Array = Game.last_wardrobe["pos"]
		at = Vector3(p[0], p[1] + 0.05, p[2])
		yaw = float(Game.last_wardrobe["yaw"])
	elif arrivals.has(come):
		at = arrivals[come][0]
		yaw = arrivals[come][1]
	spawn_at = at
	spawn_yaw = yaw
	nim = Nim.new()
	nim.name = "Nim"
	add_child(nim)
	nim.teleport(at, yaw)
	cam = FollowCam.new()
	cam.name = "FollowCam"
	add_child(cam)
	cam.target = nim
	cam.yaw = yaw
	nim.camera = cam
	nim.combat.health_changed.connect(Hud.set_health)
	nim.combat.downed.connect(_on_downed)
	Hud.set_health(nim.combat.health, nim.combat.max_health)
	for flag: String in Lessons.ALL:
		nim.known[flag] = Game.has_flag(flag)
	nim.gear.gear_changed.connect(Hud.set_gear)
	nim.gear.said.connect(func(text: String) -> void:
		if text != "":
			Hud.note(text, 2.5))
	nim.suit.composure_changed.connect(Hud.set_composure)
	nim.suit.word_changed.connect(Hud.set_word)
	nim.suit.said.connect(func(text: String) -> void:
		if text != "":
			Hud.note(text, 2.5))
	nim.suit.set_outfit(NimSuit.Outfit.GARB)
	Hud.set_word(nim.suit.word)
	Hud.age_gate()
	_arrival_card()


func _process(_delta: float) -> void:
	if nim:
		Hud.set_light(nim.light)
		# Held by a scene (the cross, the club's games, cutscenes): nothing to press Y at.
		Hud.set_prompt(nim.suit.y_prompt() if nim.is_physics_processing() else "")


## The world's arrival card: its name, and its host and gear if its data has them.
func _arrival_card() -> void:
	var title: String = Game.NAMES.get(world_id, String(world_id).capitalize())
	var data := WorldData.of(world_id)
	var sub := ""
	if data.get("host"):
		sub = "%s.  %s" % [data["host"], ("Gear: %s." % data["gear"]) if data.get("gear") else ""]
	Hud.arrival(title, sub.strip_edges())


## A checkpoint she's walked past (core/checkpoint.gd): she comes back here now.
func checkpoint(at: Vector3, yaw: float, which: Node = null) -> void:
	if which == _checkpoint:
		return
	if _checkpoint and is_instance_valid(_checkpoint):
		_checkpoint.call(&"set_lit", false)
	_checkpoint = which
	if which:
		which.call(&"set_lit", true)
	spawn_at = at + Vector3.UP * 0.05
	spawn_yaw = yaw


func _physics_process(_delta: float) -> void:
	if nim and nim.global_position.y < FALL_Y:
		nim.teleport(spawn_at, spawn_yaw)


## Downed: back at the last checkpoint, healthy. No lives, nothing lost.
func _on_downed() -> void:
	nim.teleport(spawn_at, spawn_yaw)
	cam.set(&"yaw", spawn_yaw)
	nim.combat.revive()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_swap") and not get_tree().paused:
		var i := TEST_SCENES.find(scene_file_path)
		Game.travel(TEST_SCENES[(i + 1) % TEST_SCENES.size()])


## A solid box: `at` is its centre. Collision on layer 1 unless `solid` is false.
func block(at: Vector3, size: Vector3, mat: Material, parent: Node = self, solid := true) -> Node3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = mat
	if not solid:
		mesh.position = at
		parent.add_child(mesh)
		return mesh
	var body := StaticBody3D.new()
	body.position = at
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	body.add_child(mesh)
	parent.add_child(body)
	return body


## A box collider with no mesh: props keep box collision, never mesh collision (ART_DIRECTION.md "Props").
func collider(at: Vector3, size: Vector3, parent: Node = self) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	parent.add_child(body)
	return body


func flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m
