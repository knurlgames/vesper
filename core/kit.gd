class_name Kit
extends RefCounted
## The Kit (owner, 2026-11-13: "go ahead with the wheel and kit page"): everything Nim can do, for the pause menu's Kit
## page, like Banjo's move list. Each entry: [kind, the flag that unlocks it ("" from the start), icon (UiKit.icon), name,
## how (the actions, in the device's glyphs, then words), where (garb, suit or both), who it's from].
## Locked ones show as "???": a promise of more.

const MOVE := "Move"
const COMMAND := "Command"
const GEAR := "Gear"

const ENTRIES := [
	[MOVE, "", "paw", "Jump", [&"jump"], "Again by a ledge to catch it", "Both", ""],
	[MOVE, "", "paw", "Strike", [&"strike"], "Tap, up to three in a row", "Garb", ""],
	[MOVE, "", "paw", "Pounce", [&"pounce"], "Leaps and staggers what it hits", "Garb", ""],
	[MOVE, "", "paw", "Bind", [&"interact"], "Behind a goon who hasn't seen her, or one who's down", "Garb", ""],
	[MOVE, "", "paw", "Climb", [], "Push into marked walls", "Garb", ""],
	[MOVE, "", "paw", "Strut", [&"crouch"], "Hold, or the stick part-way: poise, not hurry", "Suit", ""],
	[MOVE, "lesson_takedown_above", "paw", "Takedown from Above", [&"crouch"], "Drop off a beam onto a goon", "Garb",
		"Vesper, on the Pier"],
	[MOVE, "lesson_ceiling", "paw", "Ceiling Crawl", [], "Jump to a marked ceiling", "Garb", "Vesper"],
	[MOVE, "lesson_hold_room", "paw", "Hold the Room", [&"interact"], "Cover blown: hold, and stare them down", "Suit",
		"Vesper"],
	[COMMAND, "", "word", "Kneel", [&"word_up", &"interact"], "Pick the word, then say it", "Suit", ""],
	[COMMAND, "lesson_fetch_open", "word", "Fetch", [&"word_right", &"interact"], "Staff bring her things", "Suit",
		"Vesper, in Primrose Close"],
	[COMMAND, "lesson_fetch_open", "word", "Open", [&"word_down", &"interact"], "Staff open doors for her", "Suit",
		"Vesper, in Primrose Close"],
	[GEAR, "gear_crop", "crop", "The Crop", [&"strike"], "Hold in the garb; any press in the suit. Bells, switches, targets",
		"Both", "Dash"],
	[GEAR, "gear_scold", "gear", "The Scold", [&"gear"], "Every goon near her freezes, for a moment", "Both", "Grizelda"],
	[GEAR, "gear_rope", "rope", "The Rope", [&"rope"], "Ties a goon from a distance; swings, in the air", "Garb", "Silke"],
	[GEAR, "gear_pendant", "pendant", "The Pendant", [&"gear"], "Wakes someone in a trance; or fake one yourself",
		"Both", "Lull"],
	[GEAR, "gear_lure", "lure", "Lures", [&"gear"], "A buzzing toy, thrown: goons go to look", "Garb", "Rivet"],
	[GEAR, "gear_signet", "signet", "The Signet", [], "Always on: Commands reach the powerful", "Suit", "Augusta"],
]
