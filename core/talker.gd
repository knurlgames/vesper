class_name Talker
extends Node3D
## Someone to talk to (WO-009): Y beside them plays `label` of their .dialogue file. Writers add a conversation by
## writing the file and pointing a Talker at it; no code. Set `once` and it plays one time only (the flag
## "talked/<file>/<label>" remembers it), then `after_label` if there is one.
##
## The body is optional: a Talker can sit on a character (a child of Vesper's stand-in) or stand alone as a greybox.

## A conversation (or cutscene) has finished; `which` is the label that played. A world's Key scripts listen.
signal talked(which: String)

@export_file("*.dialogue") var file := ""
@export var label := "start"
@export var once := false
@export var after_label := ""
## A cutscene (data/cutscenes/*.json) to play instead of a conversation: a newsstand, a radio, a scene to watch.
@export_file("*.json") var cutscene := ""
## How close Nim must be for Y to reach them.
@export var reach := 2.0
## A greybox body (a capsule this colour), or none if they're part of something else.
@export var greybox := true
@export var colour := Color("a08a70")
@export var display_name := ""
## A cast member's model (CastModel: "vesper", "augusta", ... "swyne"), in place of the greybox capsule when its
## GLB exists. The collision capsule stays either way.
@export var who := ""
@export var outfit := "garb"
## Or an enemy body to wear ("weasel_goon"...; assets/enemies), idling, for staff and bit parts.
@export var look_body := ""

var model: CastModel
var look: EnemyModel
## True while walk_path is taking them somewhere.
var walking := false


func _ready() -> void:
	add_to_group(&"talker")
	if who != "" and CastModel.exists(who, outfit):
		model = CastModel.new()
		model.who = who
		model.outfit = outfit
		add_child(model)
	elif look_body != "" and EnemyModel.exists(look_body):
		look = EnemyModel.new()
		look.body = look_body
		look.process_mode = Node.PROCESS_MODE_ALWAYS   # they stand and idle: keep breathing through a conversation
		add_child(look)
		look.show_state(0, 0.0, 0.0, 0.0)
	if greybox or model or look:
		var body := StaticBody3D.new()
		var shape := CapsuleShape3D.new()
		shape.radius = 0.35
		shape.height = 1.75
		var col := CollisionShape3D.new()
		col.shape = shape
		col.position.y = 0.875
		body.add_child(col)
		var mesh := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.35
		cap.height = 1.75
		mesh.mesh = cap
		mesh.position.y = 0.875
		mesh.material_override = Look.toon(colour)
		mesh.visible = model == null and look == null
		body.add_child(mesh)
		add_child(body)
	if display_name != "":
		var tag := Label3D.new()
		tag.text = "%s  (Y)" % display_name
		tag.font_size = 32
		tag.pixel_size = 0.006
		tag.outline_size = 8
		tag.outline_modulate = Look.INK
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.position.y = 2.3
		add_child(tag)


func once_flag() -> String:
	return "talked/%s/%s" % [file.get_file().get_basename(), label]


## Which label Y plays now ("" if there's nothing more to say).
func next_label() -> String:
	var game := get_node_or_null(^"/root/Game")
	if once and game and game.call(&"has_flag", once_flag()):
		return after_label
	return label


## Y beside them. The conversation runs (and pauses the world) in the Dialogue autoload.
func talk() -> void:
	var which := next_label()
	if which == "":
		return
	var dialogue := get_node_or_null(^"/root/Dialogue")
	var game := get_node_or_null(^"/root/Game")
	if dialogue == null:
		return
	if cutscene != "":
		await dialogue.call(&"play_cutscene", cutscene)
	else:
		await dialogue.call(&"run", file, which)
	if once and which == label and game:
		game.call(&"set_flag", once_flag())
	talked.emit(which)


## Walks (or runs) through `points` in turn at `speed` m/s, turned the way they're going, the legs keeping pace (a
## cast model's walk or run, a body's walk). Await it. For leaving a scene on foot instead of vanishing (owner, on
## the Deck: "have the characters move on organically instead of simply teleporting away"). `walking` is true until
## they arrive.
func walk_path(points: Array, speed := 1.6) -> void:
	walking = true
	for p: Vector3 in points:
		var flat := Vector3(p.x - global_position.x, 0.0, p.z - global_position.z)
		if flat.length() > 0.05:
			rotation.y = atan2(-flat.x, -flat.z)
		_pace(speed)
		var secs := global_position.distance_to(p) / speed
		if secs > 0.0:
			var tw := create_tween()
			tw.tween_property(self, ^"global_position", p, secs)
			await tw.finished
		if not is_inside_tree():
			return
	_pace(0.0)
	walking = false


func _pace(speed: float) -> void:
	if model:
		model.speed = speed
	if look:
		look.show_state(0, 0.0, speed, 0.0)
