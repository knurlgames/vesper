extends "res://levels/primrose/keys/primrose_key.gd"
## Key 7: the Neighbourhood Watch's logbook (worlds/02_PRIMROSE_CLOSE.md). The Watch captain sits in a deckchair by
## the hut with the logbook on his knee: every visit to every party is in it. In the suit, pass for the Coalition's
## lady from head office: each slip costs Composure ("log_slipN"); two slips, or naming the Rope, and he blows his
## whistle (blown cover). Given it: the logbook also records eleven visits to the Watch hut by the captain's wife.

const CAPTAIN_AT := Vector3(12.8, 0.12, 1.2)
const KEY_AT := Vector3(10.6, 0.12, 1.4)
const SLIP_COST := 0.3
const SLIPS := ["log_slip1", "log_slip2"]

var captain: Talker


func _setup() -> void:
	# His deckchair, south of the hut, facing the road.
	level.call(&"block", CAPTAIN_AT + Vector3(0.1, 0.2, 0), Vector3(0.7, 0.4, 0.6), Look.toon(Color("3a6a8a")), self, true)
	captain = talker("Captain", "captain", "start", CAPTAIN_AT + Vector3(-0.45, 0, 0), PI / 2.0, "", "garb", "Watch Captain",
		Color("c8a878"), true, "meerkat_watch")
	captain.talked.connect(_on_talked)
	if has_key(&"primrose_07"):
		captain.label = "after"


func _on_talked(_which: String) -> void:
	var n := nim()
	var slips := SLIPS.filter(func(f: String) -> bool: return flag(f)).size()
	for f: String in SLIPS:
		clear(f)
	if flag("log_refused"):
		clear("log_refused")
		n.suit.call(&"_spend", 2.0)
		return
	if slips > 0 and n.suit.in_suit():
		n.suit.call(&"_spend", SLIP_COST * slips)
	if flag("logbook") and not has_key(&"primrose_07") and not n.suit.cover_blown:
		award(&"primrose_07", KEY_AT)
		captain.label = "after"
