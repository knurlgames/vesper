extends Node3D
## What every one of Primrose Close's Key scripts shares (WO-015 step 2; the Pier's levels/pier/keys/pier_key.gd, for
## this world). Each is a child of the Primrose level, built in its own _setup() once the level (and Nim) are ready.
## Their lines are in data/dialogue/primrose/.

const DIALOGUE_DIR := "res://data/dialogue/primrose/"

var level: Node


func _ready() -> void:
	level = get_parent()
	_setup.call_deferred()


func _setup() -> void:
	pass


func nim() -> Nim:
	return level.get(&"nim")


## A world flag: "primrose/<name>".
func flag(name: String) -> bool:
	return Game.has_flag("primrose/" + name)


func set_flag(name: String, value: Variant = true) -> void:
	Game.set_flag("primrose/" + name, value)


func clear(name: String) -> void:
	Game.clear_flag("primrose/" + name)


func has_key(id: StringName) -> bool:
	return Game.has_collected(&"key", &"primrose", id)


## A deed's Velvet Rose: tossed down from out of sight to land at `at` (Vesper's always watching).
func award(id: StringName, at: Vector3) -> void:
	if not has_key(id):
		var p: Pickup = level.call(&"key", id, at)
		if p:
			p.toss_in()


func talk(file: String, label: String) -> void:
	await Dialogue.run(DIALOGUE_DIR + file + ".dialogue", label)


## A cast member or a body who speaks: Y beside them plays `label` of their file.
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


## Staff (core/staff.gd): someone a Domme can tell to Kneel, Fetch and Open.
func staff(node_name: String, speaker: String, at: Vector3, yaw: float, look_body := "", kneel_line := "Yes, Mistress.") -> Staff:
	var s := Staff.new()
	s.name = node_name
	s.speaker = speaker
	s.look_body = look_body
	s.kneel_line = kneel_line
	s.position = at
	s.rotation.y = yaw
	add_child(s)
	return s


## Something staff can Fetch: a small box (a cake, a thermos), its `id` what Nim receives.
func fetch_box(node_name: String, id: StringName, at: Vector3, size: Vector3, colour: Color, top := Color.TRANSPARENT) -> Node3D:
	var b := FetchBox.new()
	b.name = node_name
	b.id = id
	b.size = size
	b.colour = colour
	b.top = top
	b.position = at
	add_child(b)
	return b


## A Door (core/door.gd) staff can Open, `w` wide and `h` tall, its front (where they stand) toward `front`.
func door(node_name: String, at: Vector3, front: Vector3, w := 1.6, h := 2.6) -> Door:
	var d := Door.new()
	d.name = node_name
	d.width = w
	d.height = h
	d.position = at
	var f := front - at
	d.rotation.y = atan2(f.x, f.z) + PI   # its -Z (where it's opened from) toward `front`
	add_child(d)
	return d


func near(p: Vector3, r: float) -> bool:
	var n := nim()
	return n != null and n.global_position.distance_to(p) <= r


func in_suit() -> bool:
	var n := nim()
	return n != null and n.suit.in_suit()


func goon(id: StringName) -> Enemy:
	return level.get_node_or_null("Goon_%s" % id) as Enemy
