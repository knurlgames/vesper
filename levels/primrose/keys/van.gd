extends "res://levels/primrose/keys/primrose_key.gd"
## Key 8: the delivery van stuck in number 9's back garden, by the paddling pool's neighbour (worlds/02_PRIMROSE_CLOSE.md).
## Its driver stands guard at the back doors, which are locked. In the suit, tell him to Open them (Vesper's lesson):
## he does, with his own hands, and then he apologises to the van. Inside: more of the LITERATURE.

## The van (primrose.gd): x -34.15..-31.85, z -60.5..-55.5, 0.3 up on its wheels; its back doors face -Z.
const VAN := Vector3(-33.0, 0.08, -58.0)
const DRIVER_AT := Vector3(-35.0, 0.08, -61.9)

var driver: Staff
var doors: Door
var _done := false


func _setup() -> void:
	driver = staff("Driver", "Driver", DRIVER_AT, -PI * 0.75, "bulldog_goon", "Is this... a delivery thing? Fine.")
	doors = door("VanDoors", VAN + Vector3(0, 0.3, -2.62), VAN + Vector3(0, 0.3, -4.0), 2.1, 2.4)
	driver.door = driver.get_path_to(doors)
	if has_key(&"primrose_08"):
		_done = true
		doors.open()


func _physics_process(_delta: float) -> void:
	if _done or not doors.is_open:
		return
	_done = true
	await get_tree().create_timer(0.8).timeout
	driver.call(&"_say", "...Sorry. Sorry, van.")   # OWNER REVIEW
	await get_tree().create_timer(2.0).timeout
	award(&"primrose_08", VAN + Vector3(0, 0, -4.2))
