class_name World
extends Level
## The base for a world (WO-008): a Level with the world's data (WorldData) and helpers to place what every world has:
## Keys, contraband, the collection tin, people in trances, zones, wardrobes, checkpoints, shortcuts, fast travel
## points and rank doors. Call `finish()` at the end of `_ready`, after spawn_player: it culls small things at a
## distance (the Deck's budget).
##
## Keys are placed by their data id ("pier_03"); a Key the world's data doesn't know is a warning, so a level can't
## drift from its brief unnoticed.

## Small meshes (this big or less) stop drawing past CULL_DISTANCE.
const CULL_SIZE := 2.5
const CULL_DISTANCE := 45.0

var data := {}


func load_data() -> void:
	data = WorldData.of(world_id)


func key(id: StringName, at: Vector3) -> Pickup:
	if not data.is_empty() and WorldData.key(world_id, id).is_empty():
		push_warning("World %s has no Key \"%s\" in its data." % [world_id, id])
	return _pickup(&"key", id, at)


func contraband(id: StringName, at: Vector3) -> Pickup:
	return _pickup(&"contraband", id, at)


## The Decency League's collection tin (one per world): a strike smashes it, and it pays a Key in the hub.
func tin(at: Vector3, yaw := 0.0) -> Pickup:
	var p := _pickup(&"tin", &"tin", at)
	p.rotation.y = yaw
	return p


func sleeper(id: StringName, at: Vector3, loop: PackedVector3Array) -> Entranced:
	var e := Entranced.new()
	e.id = id
	e.name = "Entranced_%s" % id
	e.position = at
	e.loop = loop
	add_child(e)
	return e


func zone(zone_name: String, at: Vector3, size: Vector3) -> Zone:
	var z := Zone.new()
	z.zone_name = zone_name
	z.size = size
	z.position = at
	add_child(z)
	return z


func wardrobe(at: Vector3, yaw := 0.0, node_name := "") -> Wardrobe:
	var w := Wardrobe.new()
	if node_name != "":
		w.name = node_name
	w.position = at
	w.rotation.y = yaw
	add_child(w)
	return w


func checkpoint_at(at: Vector3, yaw := 0.0) -> Checkpoint:
	var c := Checkpoint.new()
	c.position = at
	c.yaw = yaw
	add_child(c)
	return c


func shortcut(id: StringName, at: Vector3, yaw := 0.0) -> ShortcutDoor:
	var s := ShortcutDoor.new()
	s.id = id
	s.name = "Shortcut_%s" % id
	s.position = at
	s.rotation.y = yaw
	add_child(s)
	return s


func travel_point(id: StringName, label: String, at: Vector3, yaw := 0.0) -> TravelPoint:
	var t := TravelPoint.new()
	t.id = id
	t.label = label
	t.name = "Travel_%s" % id
	t.position = at
	t.rotation.y = yaw
	add_child(t)
	return t


func rank_door(keys_needed: int, at: Vector3, yaw := 0.0, node_name := "") -> RankDoor:
	var d := RankDoor.new()
	d.keys_needed = keys_needed
	if node_name != "":
		d.name = node_name
	d.position = at
	d.rotation.y = yaw
	add_child(d)
	return d


## The world's done (its boss bound): it's remembered ("done/<world>"), the next morning's paper plays if there is one
## (data/cutscenes/paper_<world>.json), and she's back at the club.
func complete(go_home := true) -> void:
	Game.set_flag("done/%s" % world_id)
	var paper := "res://data/cutscenes/paper_%s.json" % world_id
	if FileAccess.file_exists(paper):
		await Dialogue.play_cutscene(paper)
	if go_home:
		Game.travel(Game.SCENES[&"hub"], "club_door")


## The end of a world's _ready: small things stop drawing at a distance.
func finish() -> void:
	cull_small(self)


static func cull_small(root: Node) -> void:
	for g: GeometryInstance3D in root.find_children("*", "GeometryInstance3D", true, false):
		if g is MultiMeshInstance3D or g.visibility_range_end > 0.0:
			continue
		var size := g.get_aabb().size * g.global_basis.get_scale()
		if maxf(size.x, maxf(size.y, size.z)) <= CULL_SIZE:
			g.visibility_range_end = CULL_DISTANCE
			g.visibility_range_end_margin = 4.0
			g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


func _pickup(kind: StringName, id: StringName, at: Vector3) -> Pickup:
	var p := Pickup.new()
	p.kind = kind
	p.id = id
	p.name = "%s_%s" % [String(kind).capitalize(), id]
	p.position = at
	add_child(p)
	return p
