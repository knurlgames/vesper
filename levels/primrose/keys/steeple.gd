extends "res://levels/primrose/keys/primrose_key.gd"
## Key 4: the steeple, climbed in the rain (worlds/02_PRIMROSE_CLOSE.md). Its rose is placed in the belfry (primrose.gd).
## Vesper's up there, at the foot of the spire, watching the Close (the world's story: "Vesper sits on the church's
## steeple, watching"). Nim pulls up into the belfry: "Mind the bells." The bells go off.

const TOWER := Vector3(65.0, 0.0, -55.0)
const BELFRY := 14.0
const VESPER_AT := Vector3(66.6, 14.3, -56.6)

var vesper: Talker
var _rung := false


func _setup() -> void:
	vesper = talker("Vesper_steeple", "vesper", "belfry", VESPER_AT, PI * 0.75, "vesper", "garb", "", Color("c0283e"))
	_rung = flag("bells_rung")


func _physics_process(_delta: float) -> void:
	if _rung or Dialogue.is_active():
		return
	var n := nim()
	if n and n.global_position.y > BELFRY - 0.2 and n.is_on_floor() \
			and Vector2(n.global_position.x - TOWER.x, n.global_position.z - TOWER.z).length() < 3.2:
		_rung = true
		_ring()


func _ring() -> void:
	await talk("vesper", "mind_the_bells")
	set_flag("bells_rung")
	for b: String in ["Bell_0", "Bell_1"]:
		var bell := level.get_node_or_null(b) as Node3D
		if bell:
			var tw := create_tween().set_loops(4)
			tw.tween_property(bell, ^"rotation:x", 0.5, 0.35).set_trans(Tween.TRANS_SINE)
			tw.tween_property(bell, ^"rotation:x", -0.5, 0.7).set_trans(Tween.TRANS_SINE)
			tw.tween_property(bell, ^"rotation:x", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
	for i in 4:
		Hud.caption("", "BONG.", 0.9)
		await get_tree().create_timer(1.4).timeout
	await talk("vesper", "after_bells")
