class_name Talker
extends Node3D
## Someone to talk to (WO-009): Y beside them plays `label` of their .dialogue file. Writers add a conversation by
## writing the file and pointing a Talker at it; no code. Set `once` and it plays one time only (the flag
## "talked/<file>/<label>" remembers it), then `after_label` if there is one.
##
## The body is optional: a Talker can sit on a character (a child of Vesper's stand-in) or stand alone as a greybox.

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

var model: CastModel


func _ready() -> void:
	add_to_group(&"talker")
	if who != "" and CastModel.exists(who, outfit):
		model = CastModel.new()
		model.who = who
		model.outfit = outfit
		add_child(model)
	if greybox or model:
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
		mesh.visible = model == null
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
