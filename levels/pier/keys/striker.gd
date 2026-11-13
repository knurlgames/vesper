extends "res://levels/pier/keys/pier_key.gd"
## Key 4: the high striker (worlds/01_PIER.md). It's rigged: the puck never reaches the bell. Climb the marked tower
## (garb) and crack the bell with the crop from the cap. It rings, and the goon on the mallet takes the credit.

const TOWER := Vector3(12.0, 0.0, -41.0)
const CAP_Y := 10.2
## The bell hangs off the cap's west edge, over the avenue: in reach of the crop from the cap, never from the deck.
const BELL := Vector3(11.0, 10.75, -41.0)

var mallet: Staff
var bell: CropTarget
var _pitched := false


func _setup() -> void:
	mallet = Staff.new()
	mallet.name = "Mallet"
	mallet.speaker = "Mallet"
	mallet.look_body = "weasel_goon"
	mallet.kneel_line = "Can I still say I rang it?"   # OWNER REVIEW
	mallet.colour = Color("7d8a5a")
	mallet.position = Vector3(9.0, 0.05, -41.0)
	mallet.rotation.y = PI / 2.0
	add_child(mallet)
	# The bracket the bell hangs from.
	pier.call(&"block", Vector3(11.2, 11.05, -41.0), Vector3(0.5, 0.1, 0.1), Look.toon(Look.BRASS, 0.6), self, false)
	bell = CropTarget.new()
	bell.name = "StrikerBell"
	bell.kind = CropTarget.Kind.BELL
	bell.position = BELL
	add_child(bell)
	bell.hit.connect(_on_bell)


func _physics_process(_delta: float) -> void:
	if not _pitched and near(TOWER, 6.0):
		_pitched = true
		mallet.call(&"_say", "Ten pence a go! Ring the bell, win a prize! Nobody's ever rung it. Nobody.")


func _on_bell() -> void:
	if has_key(&"pier_04"):
		return
	mallet.call(&"_say", "DING! Did you see that? Did you SEE that? All me. Pure muscle.")
	award(&"pier_04", Vector3(TOWER.x + 0.3, CAP_Y, TOWER.z))
