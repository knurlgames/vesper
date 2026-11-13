extends "res://levels/pier/keys/pier_key.gd"
## Vesper on the wheel (worlds/01_PIER.md, Key 8 and "the story"): she sits in a car all night, watching the whole
## pier, and won't come down to help. Ride up to her for an optional talk. When Nim takes Key 8 from the crown, she's in
## the car next to it: "You took your time."

## Which car she rides in.
const CAR := 2

var vesper: Talker


func _setup() -> void:
	var wheel: Node = pier.get(&"wheel")
	var cars: Array = wheel.get(&"car_bodies")
	vesper = Talker.new()
	vesper.name = "Vesper_wheel"
	vesper.file = DIALOGUE_DIR + "vesper.dialogue"
	vesper.label = "wheel"
	vesper.who = "vesper"
	vesper.outfit = "garb"
	vesper.display_name = "Vesper"
	vesper.position = Vector3(0.6, 0.0, -0.3)
	vesper.rotation.y = PI / 2.0
	(cars[CAR] as Node).add_child(vesper)
	Game.collected.connect(_on_collected)


func _on_collected(kind: StringName, world: StringName, id: StringName) -> void:
	if kind == &"key" and world == &"pier" and id == &"pier_08":
		await get_tree().create_timer(0.6).timeout
		await talk("vesper", "wheel_top")
