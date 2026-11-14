extends "res://levels/primrose/keys/primrose_key.gd"
## Key 3: the raffle (worlds/02_PRIMROSE_CLOSE.md). The first prize is one of Swyne's hypnotic toys. Buy a ticket from
## the vicar (number 47), then fix the draw: when he turns to count the float on the stage, stuff the drum with your
## number (Y at the drum). Seen at it, he coughs, and you wait for the next chance. Then ask him to draw. Nim wins;
## the vicar's never been so relieved. Either outfit.

## The raffle table (x 67..69, z -35.5..-36.5), its drum on top; the vicar behind it.
const VICAR_AT := Vector3(68.0, 0.12, -37.0)
const DRUM_AT := Vector3(68.0, 0.12, -34.9)
## He watches the drum this long, then turns to the float on the stage for this long.
const WATCH_SECS := 4.5
const AWAY_SECS := 3.5

var vicar: Talker
var drum: Talker
var _t := 0.0
var _away := false


func _setup() -> void:
	vicar = talker("Vicar", "vicar", "start", VICAR_AT, PI, "", "garb", "The Vicar", Color("3a3a48"), true, "fox_civilian")
	vicar.reach = 2.6   # across his table (the drum, nearer the front, is what Y finds there)
	vicar.talked.connect(_on_vicar)
	drum = talker("Drum", "vicar", "drum", DRUM_AT, PI, "", "garb", "Raffle drum", Color.WHITE, false)
	drum.reach = 1.6
	set_flag("vicar_looking", true)


func _physics_process(delta: float) -> void:
	if vicar == null or Dialogue.is_active() or has_key(&"primrose_03"):
		return
	_t += delta
	if _t >= (AWAY_SECS if _away else WATCH_SECS):
		_t = 0.0
		_away = not _away
		set_flag("vicar_looking", not _away)
		# He turns to the stage (east) to count the float, and back to the drum.
		create_tween().tween_property(vicar, ^"rotation:y", -PI / 2.0 if _away else PI, 0.4)


func _on_vicar(_which: String) -> void:
	if flag("raffle_won") and not has_key(&"primrose_03"):
		award(&"primrose_03", DRUM_AT + Vector3(0, 0, 0.9))
		vicar.label = "after"
		drum.label = "after_drum"
