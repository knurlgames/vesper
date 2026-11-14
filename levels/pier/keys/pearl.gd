extends "res://levels/pier/keys/pier_key.gd"
## Key 5: Madame Pearl, the fortune teller (worlds/01_PIER.md). She sells Swyne's toys under the table. In the suit,
## Nim poses as a buyer for a club and has to stay in character: every slip in the conversation costs Composure, and
## two slips, or naming the Claw, lose the sale and blow her cover. She can try again once she's recovered. Pearl's
## reading is right about the ledger and wrong about everything else.

const PEARL := Vector3(-14.6, 0.0, -57.0)   # behind her table (x -14.2 to -12.8)
const KEY_AT := Vector3(-11.4, 0.0, -57.0)
## Composure each slip costs.
const SLIP_COST := 0.3
const SLIPS := ["pearl_slip1", "pearl_slip2", "pearl_slip3"]

var pearl: Talker


func _setup() -> void:
	pearl = talker("Pearl", "pearl", "start", PEARL, -PI / 2.0, "", "garb", "Madame Pearl", Color("3aa86a"), true,
		"pearl_parrot")
	pearl.reach = 2.6   # across her table
	pearl.talked.connect(_on_talked)


func _on_talked(_which: String) -> void:
	var n := nim()
	var slips := SLIPS.filter(func(f: String) -> bool: return flag(f)).size()
	for f: String in SLIPS:
		clear(f)
	if flag("pearl_refused"):
		clear("pearl_refused")
		n.suit.call(&"_spend", 2.0)   # all of it: her cover's blown, and Pearl's shouting for the goons
		return
	if slips > 0 and n.suit.in_suit():
		n.suit.call(&"_spend", SLIP_COST * slips)
	if flag("pearl_sold"):
		award(&"pier_05", KEY_AT)
