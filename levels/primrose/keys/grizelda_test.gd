extends "res://levels/primrose/keys/primrose_key.gd"
## Key 1: Grizelda's test (worlds/02_PRIMROSE_CLOSE.md). On the lawn of number 4, her old house (for sale), three
## Coalition ladies take tea every Thursday "to look round it". Grizelda sets the test: take tea with them, in the
## suit, without losing Composure. Each slip in the conversation costs Composure (the dialogue sets "tea_slipN"); two
## slips, or naming the Claw, and the ladies close ranks (blown cover). Passed: her verdict, Key 1, and the Scold.
## The joke: she had the same three ladies to tea twelve years ago, and they still talk about it.

## Number 4: the east side's second plot (z -22), its lawn x 8..14.
const LAWN_AT := Vector3(11.5, 0.08, -19.6)
const GRIZELDA_AT := Vector3(9.4, 0.08, -24.4)
const KEY_AT := Vector3(10.0, 0.08, -21.8)
## Composure each slip costs.
const SLIP_COST := 0.3
const SLIPS := ["tea_slip1", "tea_slip2", "tea_slip3"]
## The three ladies round the table: [name, display, at (from the table), yaw, body, colour].
const LADIES := [
	["Ashby", "Mrs Ashby", Vector3(1.1, 0, 0), PI / 2.0, "hare_civilian", Color("d0b8e0")],
	["Primm", "Mrs Primm", Vector3(0, 0, 1.1), 0.0, "otter_civilian", Color("e0c8a8")],
	["Fairweather", "Mrs Fairweather", Vector3(0, 0, -1.1), PI, "hedgehog_civilian", Color("b8c8d8")],
]

var grizelda: Talker
var ladies: Array[Talker] = []


func _setup() -> void:
	# The tea table and its cloth, the cups.
	level.call(&"block", LAWN_AT + Vector3(0, 0.36, 0), Vector3(1.2, 0.72, 1.2), Look.toon(Color("6a5442")), self, true)
	# (The cloth sinks a centimetre into the table's top and the cups into the cloth: no shared faces.)
	level.call(&"block", LAWN_AT + Vector3(0, 0.725, 0), Vector3(1.3, 0.03, 1.3), Look.toon(Color("f0e8e0")), self, false)
	for i in 4:
		var a := i * TAU / 4.0 + 0.4
		level.call(&"block", LAWN_AT + Vector3(cos(a) * 0.38, 0.775, sin(a) * 0.38), Vector3(0.08, 0.08, 0.08),
			Look.toon(Color("e8e0d0"), 0.4), self, false)
	for l: Array in LADIES:
		var t := talker("Lady_" + String(l[0]), "tea", "tea", LAWN_AT + (l[2] as Vector3), float(l[3]), "", "garb", l[1],
			l[5], true, l[4])
		t.talked.connect(_on_tea)
		ladies.append(t)
	grizelda = talker("Grizelda", "grizelda", "test" if not has_key(&"primrose_01") else "after", GRIZELDA_AT, -PI / 2.0,
		"grizelda", "garb", "", Color("b07060"))
	grizelda.talked.connect(_on_grizelda)


func _on_grizelda(which: String) -> void:
	if which == "test":
		set_flag("tea_set")


## After a cup of tea: the slips are counted and paid for in Composure; passed, Grizelda's verdict and the Key.
func _on_tea(_which: String) -> void:
	var n := nim()
	var slips := SLIPS.filter(func(f: String) -> bool: return flag(f)).size()
	for f: String in SLIPS:
		clear(f)
	if flag("tea_refused"):
		clear("tea_refused")
		n.suit.call(&"_spend", 2.0)   # they close ranks: her cover's gone, and the Watch is ringing round
		return
	if slips > 0 and n.suit.in_suit():
		n.suit.call(&"_spend", SLIP_COST * slips)
	if flag("tea_done") and not has_key(&"primrose_01"):
		if n.suit.cover_blown:
			clear("tea_done")
			return
		await talk("grizelda", "verdict")
		award(&"primrose_01", KEY_AT)
		Game.set_flag(Lessons.SCOLD)
		n.known[Lessons.SCOLD] = true
		Hud.note("Got: Grizelda's Scold. LB: every goon near you freezes, for a moment.")
		grizelda.label = "after"
