extends Node3D
## What every one of the Pier's Key scripts shares (WO-014 step 2). Each is a child of the Pier level, built in its own
## _setup() once the level (and Nim) are ready. Their lines are in data/dialogue/pier/.

const DIALOGUE_DIR := "res://data/dialogue/pier/"

var pier: Node


func _ready() -> void:
	pier = get_parent()
	_setup.call_deferred()


func _setup() -> void:
	pass


func nim() -> Nim:
	return pier.get(&"nim")


## A world flag: "pier/<name>".
func flag(name: String) -> bool:
	return Game.has_flag("pier/" + name)


func set_flag(name: String, value: Variant = true) -> void:
	Game.set_flag("pier/" + name, value)


func clear(name: String) -> void:
	Game.clear_flag("pier/" + name)


func has_key(id: StringName) -> bool:
	return Game.has_collected(&"key", &"pier", id)


## Puts Key `id` at `at`, unless she has it already.
## A deed's Velvet Rose: tossed down from out of sight to land at `at` (an encore: Vesper's always watching).
func award(id: StringName, at: Vector3) -> void:
	if not has_key(id):
		var p: Pickup = pier.call(&"key", id, at)
		if p:
			p.toss_in()


func talk(file: String, label: String) -> void:
	await Dialogue.run(DIALOGUE_DIR + file + ".dialogue", label)


## A cast member or greybox who speaks: Y beside them plays `label` of their file.
func talker(node_name: String, file: String, label: String, at: Vector3, yaw: float, who := "", outfit := "garb",
		display := "", colour := Color("a08a70"), body := true, look_body := "") -> Talker:
	var t := Talker.new()
	t.name = node_name
	t.greybox = body
	t.look_body = look_body
	t.file = DIALOGUE_DIR + file + ".dialogue"
	t.label = label
	t.who = who
	t.outfit = outfit
	t.display_name = display
	t.colour = colour
	t.position = at
	t.rotation.y = yaw
	add_child(t)
	return t


func near(p: Vector3, r: float) -> bool:
	var n := nim()
	return n != null and n.global_position.distance_to(p) <= r


func in_suit() -> bool:
	var n := nim()
	return n != null and n.suit.in_suit()


func goon(id: StringName) -> Enemy:
	return pier.get_node_or_null("Goon_%s" % id) as Enemy
