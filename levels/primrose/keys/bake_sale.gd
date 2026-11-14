extends "res://levels/primrose/keys/primrose_key.gd"
## Key 2: the bake sale (worlds/02_PRIMROSE_CLOSE.md). The stallholder at St. Prudence's bake sale keeps a cake under
## the counter, "reserved". In the suit, tell him to Fetch it (Vesper's lesson): he brings it round to her. The cake is
## a box of toys with icing on it.

## The bake sale's first trestle (x 58.5..61.5, z -29.5..-30.5): he stands off its east end, the cake under it.
const STALL_AT := Vector3(62.4, 0.12, -28.9)
const CAKE_AT := Vector3(61.8, 0.12, -30.25)   # on the floor at the trestle's end, behind its cloth

var stallholder: Staff
var cake: Node3D
var _done := false


func _setup() -> void:
	stallholder = staff("Stallholder", "Stallholder", STALL_AT, PI / 2.0, "hedgehog_civilian",
		"Oh! Oh dear. Is this a Decency thing? I'll kneel. I'm kneeling.")
	if has_key(&"primrose_02"):
		_done = true
		return
	cake = fetch_box("Cake", &"cake", CAKE_AT, Vector3(0.36, 0.22, 0.36), Color("f0e0c8"), Color("f0a0c0"))
	stallholder.fetch_item = stallholder.get_path_to(cake)
	# His sign, on the trestle's end: what the cake's "reserved" for.
	level.call(&"_sign", "RESERVED\nfor Mrs Gander", Vector3(61.56, 0.95, -30.0), PI / 2.0, Color("6a2a3e"), 14, false)


func _physics_process(_delta: float) -> void:
	if _done or Dialogue.is_active():
		return
	var n := nim()
	if n and n.suit.keys.has(&"cake"):
		_done = true
		_reveal()


func _reveal() -> void:
	await talk("stall", "cake")
	var p := nim().global_position
	award(&"primrose_02", Vector3(p.x, 0.12, p.z) + nim().facing() * 1.0)
