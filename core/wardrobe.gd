class_name Wardrobe
extends StaticBody3D
## A wardrobe (WO-006): Y beside it and Nim changes, garb to suit or back, in a second. A change restores her cover
## and her Composure, and anyone chasing her loses her (if they can't see her change). Its front faces -Z.

const WIDTH := 1.4
const HEIGHT := 2.4
const DEPTH := 0.7


func _ready() -> void:
	add_to_group(&"wardrobe")
	var shape := BoxShape3D.new()
	shape.size = Vector3(WIDTH, HEIGHT, DEPTH)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0, HEIGHT / 2.0, DEPTH / 2.0)
	add_child(col)
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(WIDTH, HEIGHT, DEPTH)
	body.mesh = box
	body.position = col.position
	body.material_override = Look.toon(Color("4a2c22"))
	add_child(body)
	for side: float in [-1.0, 1.0]:   # two doors, a velvet tassel on each handle
		var tassel := MeshInstance3D.new()
		var t := BoxMesh.new()
		t.size = Vector3(0.06, 0.18, 0.06)
		tassel.mesh = t
		tassel.position = Vector3(side * 0.12, 1.2, -0.04)
		tassel.material_override = Look.toon(Look.VELVET)
		add_child(tassel)
	var label := Label3D.new()
	label.text = "WARDROBE"
	label.font_size = 36
	label.pixel_size = 0.006
	label.outline_size = 8
	label.outline_modulate = Look.INK
	label.position = Vector3(0, HEIGHT + 0.3, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
