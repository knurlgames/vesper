class_name LessonGiver
extends StaticBody3D
## Vesper, teaching (WO-007): a stand-in until her scenes (WO-009) and her model. Y beside her and she teaches
## `lesson`: Game's flag is set and Nim knows it from then on. Greybox: tall, a bobcat's tawny, in her crimson coat.

@export var lesson := ""
## Her lesson, as a conversation: a label in a .dialogue file (WO-009). Played as she teaches it.
@export_file("*.dialogue") var dialogue_file := ""
@export var dialogue_label := ""

## Her model (CastModel), in place of the greybox when the GLB exists: "suit" (the velvet coat) or "garb".
@export var outfit := "suit"

const HEIGHT := 2.0
const RADIUS := 0.36

var taught := false
var model: CastModel


func _ready() -> void:
	add_to_group(&"lesson_giver")
	if CastModel.exists("vesper", outfit):
		model = CastModel.new()
		model.who = "vesper"
		model.outfit = outfit
		add_child(model)
	var shape := CapsuleShape3D.new()
	shape.radius = RADIUS
	shape.height = HEIGHT
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = HEIGHT / 2.0
	add_child(col)
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = RADIUS
	cap.height = HEIGHT
	body.mesh = cap
	body.position.y = HEIGHT / 2.0
	body.material_override = Look.toon(Color("c8904a"))
	body.visible = model == null
	add_child(body)
	var coat := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = RADIUS + 0.04
	c.bottom_radius = RADIUS + 0.16
	c.height = 1.3
	coat.mesh = c
	coat.position.y = 0.75
	coat.material_override = Look.toon(Look.VELVET, 0.2)
	coat.visible = model == null
	add_child(coat)
	var label := Label3D.new()
	label.text = "VESPER"
	label.font_size = 36
	label.pixel_size = 0.006
	label.outline_size = 8
	label.outline_modulate = Look.INK
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = HEIGHT + 0.4
	add_child(label)


## Teaches Nim her lesson. Returns the line to show.
## Teaches Nim her lesson, and plays the conversation that goes with it.
func teach(nim: Node) -> void:
	taught = true
	var known: Dictionary = nim.get(&"known")
	known[lesson] = true
	var game := get_node_or_null(^"/root/Game")
	if game:
		game.call(&"set_flag", lesson)
	var dialogue := get_node_or_null(^"/root/Dialogue")
	if dialogue and dialogue_file != "" and dialogue_label != "":
		dialogue.call(&"run", dialogue_file, dialogue_label)
