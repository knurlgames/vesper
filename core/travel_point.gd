class_name TravelPoint
extends Node3D
## Fast travel within a world (WO-008): a lamp post with a velvet ribbon. Walking past one finds it (Game flag
## "travel/<world>/<id>"); Y beside any found point lists the others found in this world, and she's there.

@export var id: StringName = &""
@export var label := ""

var world: StringName = &"test"
var found := false


func _ready() -> void:
	add_to_group(&"travel_point")
	var n := get_parent()
	while n and not n.has_method(&"spawn_player"):
		n = n.get_parent()
	if n:
		world = n.get(&"world_id")
	var post := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.06
	c.bottom_radius = 0.1
	c.height = 2.4
	post.mesh = c
	post.position.y = 1.2
	post.material_override = Look.toon(Look.INK)
	add_child(post)
	var ribbon := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.6, 0.35, 0.04)
	ribbon.mesh = b
	ribbon.position = Vector3(0.3, 2.1, 0)
	ribbon.material_override = Look.toon(Look.VELVET, 0.3)
	add_child(ribbon)
	var plate := Label3D.new()
	plate.text = label
	plate.font_size = 32
	plate.pixel_size = 0.006
	plate.outline_size = 8
	plate.outline_modulate = Look.INK
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plate.position.y = 2.7
	add_child(plate)
	var game := get_node_or_null(^"/root/Game")
	found = game != null and game.call(&"has_flag", flag())


func flag() -> String:
	return "travel/%s/%s" % [world, id]


func _physics_process(_delta: float) -> void:
	if found:
		return
	var nim := get_tree().get_first_node_in_group(&"player") as Node3D
	if nim and nim.global_position.distance_to(global_position) < 3.0:
		found = true
		var game := get_node_or_null(^"/root/Game")
		if game:
			game.call(&"set_flag", flag())


## Y beside it: the list of found points in this world; picking one sends her there.
func open_menu(nim: Node3D) -> void:
	var points: Array = get_tree().get_nodes_in_group(&"travel_point").filter(
		func(p: Node) -> bool: return p.get(&"found") == true)
	var names: Array[String] = []
	for p: Node in points:
		names.append(String(p.get(&"label")))
	var hud := get_node_or_null(^"/root/Hud")
	if hud == null:
		return
	hud.call(&"choose", "Travel to", names, func(i: int) -> void:
		var to: Node3D = points[i]
		nim.call(&"teleport", to.global_position + to.global_basis.z * 1.5 + Vector3.UP * 0.05, to.rotation.y))
