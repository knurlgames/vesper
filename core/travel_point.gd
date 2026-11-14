class_name TravelPoint
extends Node3D
## Fast travel within a world (WO-008): a bed of rose petals on the ground, swirling a little, its place's name over it
## (owner, 2026-11-14). Walking past one finds it (Game flag "travel/<world>/<id>"); Y on it lists the others found in
## this world, and a cyclone of rose buds takes her there (RoseCyclone).
##
## It's a checkpoint too (owner, Deck: "2 flags outside of the pier seem confusing": a checkpoint's flag stood two
## metres from a travel post's): passing it makes it where she comes back, on it, facing its yaw (the node's), and its
## petals glow a little while it's hers. So no level needs a Checkpoint beside one.

@export var id: StringName = &""
@export var label := ""

var world: StringName = &"test"
var found := false
var _bed: MultiMeshInstance3D
var _lit := false


func _ready() -> void:
	add_to_group(&"travel_point")
	var n := get_parent()
	while n and not n.has_method(&"spawn_player"):
		n = n.get_parent()
	if n:
		world = n.get(&"world_id")
	# A bed of rose petals on the ground, swirling a little (owner, 2026-11-14; it was a lamp post with a ribbon):
	# RosePetals.bed, its motion in petals.gdshader.
	_bed = RosePetals.bed(self, 1.1, 240, hash(String(id)))
	var plate := Label3D.new()
	plate.text = label
	plate.font_size = 32
	plate.pixel_size = 0.006
	plate.outline_size = 8
	plate.outline_modulate = Look.INK
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plate.position.y = 1.5
	add_child(plate)
	var game := get_node_or_null(^"/root/Game")
	found = game != null and game.call(&"has_flag", flag())


func flag() -> String:
	return "travel/%s/%s" % [world, id]


func _physics_process(_delta: float) -> void:
	var nim := get_tree().get_first_node_in_group(&"player") as Node3D
	if nim == null or nim.global_position.distance_to(global_position) >= 3.0:
		return
	if not found:
		found = true
		var game := get_node_or_null(^"/root/Game")
		if game:
			game.call(&"set_flag", flag())
	if not _lit:   # hers to come back to (Level.checkpoint lights it)
		var level := get_parent()
		while level and not level.has_method(&"checkpoint"):
			level = level.get_parent()
		if level:
			level.call(&"checkpoint", global_position, global_rotation.y, self)


## Lit while it's the checkpoint she comes back to.
func set_lit(on: bool) -> void:
	if on == _lit:
		return
	_lit = on
	(_bed.material_override as ShaderMaterial).set_shader_parameter(&"glow", 0.35 if on else 0.0)


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
		# Wrapped up in rose buds here, unwrapped there, in the middle of its bed.
		RoseCyclone.travel(nim, to.global_position + Vector3.UP * 0.05, to.rotation.y))
