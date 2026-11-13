extends Node
## Progress (autoload "Game"): story flags, what's been collected where, ranks, and which door Nim comes through next.
## Ported from Nine Lives' 3D Game and grown for this game's economy (DESIGN.md "The economy", WO-008).
##
## **Saving:** every change autosaves to `user://vesper.json`, which holds three slots; `slot` is the one in play.
## Settings (the age gate, later volume and camera) live apart, in `user://settings.cfg`, so erasing a slot never
## brings the age gate back. Probes set `persist = false` (or VESPER_NO_SAVE=1), or point `save_path` somewhere else.
##
## **Collectibles,** counted per world, Banjo-style:
##   key          10 per world and 10 in the hub (six of the hub's are paid by the worlds' collection tins); ranks are
##                counted in Keys, never spent, and each rank opens the next world
##   contraband   100 seized per world
##   freed        5 people woken from a trance per world; all five pay that world's Key 10 ("<world>_10")
##   tin          the Decency League's collection tin, one per world; smashing it pays the hub Key "tin_<world>"
## Bound goons are flags "bound/<world>/<id>"; opened shortcuts "shortcut/<world>/<id>"; fast travel points found,
## "travel/<world>/<id>".

signal collected(kind: StringName, world: StringName, id: StringName)
## A rose earned without a pickup of its own (five woken, a tin smashed): the level tosses one down (Game._earn).
signal rose_earned(world: StringName, id: StringName)
signal flag_changed(key: StringName)
## A rank reached (1 to 7): Keys have opened something.
signal ranked(rank: int)
## A setting changed (the settings screen; the HUD, camera and window apply it).
signal settings_changed(key: String)

const SAVE_PATH := "user://vesper.json"
const SETTINGS_PATH := "user://settings.cfg"
const VERSION := 2
const SLOTS := 3

const WORLDS: Array[StringName] = [&"hub", &"pier", &"primrose", &"docks", &"retreat", &"press", &"ball", &"city_hall"]
const NAMES := {&"hub": "The Velvet Rope", &"pier": "The Pier", &"primrose": "Primrose Close", &"docks": "The Docks",
	&"retreat": "The Retreat", &"press": "The Decency Press", &"ball": "The Decency Ball", &"city_hall": "City Hall",
	&"test": "The test course", &"probe": "The probe world", &"cast": "The cast stage"}
## Where each world's scene is, once it exists. The hub is the Old Quarter round the Velvet Rope (WO-014 step 5).
const SCENES := {&"hub": "res://levels/hub/hub.tscn", &"test": "res://levels/test_course/course.tscn",
	&"pier": "res://levels/pier/pier.tscn"}
## The hub's one sleeper is the prologue's guest; waking him pays the hub's Key 10 (hub_10), her first Key.
const TOTALS := {
	&"hub": {&"key": 10, &"contraband": 0, &"freed": 1, &"tin": 0},
	&"city_hall": {&"key": 0, &"contraband": 0, &"freed": 0, &"tin": 0},
}
const WORLD_TOTALS := {&"key": 10, &"contraband": 100, &"freed": 5, &"tin": 1}
## Keys needed for each rank; rank n opens world n (rank 7 is City Hall). A proposal, tuned at WO-014.
const RANK_KEYS: Array[int] = [1, 6, 14, 22, 32, 42, 58]
const RANK_WORLDS: Array[StringName] = [&"pier", &"primrose", &"docks", &"retreat", &"press", &"ball", &"city_hall"]
## Where "New game" and "Continue" go: the hub (a new game starts in the prologue, in the club's dungeon).
const START_SCENE := "res://levels/hub/hub.tscn"
## The cast stage: every cast body on screen, with a performance readout (the title's "Cast stage", and Back / Tab).
const CAST_STAGE := "res://levels/cast_stage/cast_stage.tscn"
## The settings screen's options and their defaults (WO-010).
const SETTING_DEFAULTS := {
	"cam_speed": 1.0, "invert_x": false, "invert_y": false,
	"subtitles": true, "text_size": 1, "reduce_motion": false, "reduce_flashing": false,
	"volume": 1.0, "fullscreen": false, "show_fps": false, "bindings": {},
}

var flags := {}
## kind -> world -> {id: true}
var got := {}
## Where the next scene should put her: an arrival id the level knows ("" = its default spawn).
var arrive := ""
## The last wardrobe she used: {"scene", "pos" [x, y, z], "yaw"} (the pause menu takes her back to it).
var last_wardrobe := {}
## The slot in play (1 to SLOTS).
var slot := 1
## False for probes and tests, so they never touch the player's save or settings.
var persist := true
## Probes can save somewhere of their own.
var save_path := SAVE_PATH
var _settings := ConfigFile.new()
var _slots := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_cmdline_user_args().has("--no-save") or OS.has_environment("VESPER_NO_SAVE"):
		persist = false
	load_game()
	if persist:
		_settings.load(SETTINGS_PATH)


# --- flags -----------------------------------------------------------------------------------------------------------

func set_flag(key: Variant, value: Variant = true) -> void:
	var k := String(key)
	if flags.get(k) == value:
		return
	flags[k] = value
	flag_changed.emit(StringName(k))
	save_game()


func get_flag(key: Variant, default: Variant = null) -> Variant:
	return flags.get(String(key), default)


func has_flag(key: Variant) -> bool:
	var v: Variant = flags.get(String(key))
	if v == null:
		return false
	if v is bool:
		return v
	if v is int or v is float:
		return v != 0
	return String(v) != ""


func clear_flag(key: Variant) -> void:
	if flags.erase(String(key)):
		flag_changed.emit(StringName(String(key)))
		save_game()


# --- collectibles ----------------------------------------------------------------------------------------------------

## Records a pickup. False if it was already had. Pays what it pays: the fifth person woken in a world pays that
## world's "freed" Key; a world's tin pays the hub Key "tin_<world>". A Key may raise her rank.
func collect(kind: StringName, world: StringName, id: StringName) -> bool:
	var per_world: Dictionary = got.get_or_add(String(kind), {})
	var seen: Dictionary = per_world.get_or_add(String(world), {})
	if seen.has(String(id)):
		return false
	var rank_before := rank()
	seen[String(id)] = true
	if kind == &"key":
		flags.erase("rose_pending/%s" % id)   # a tossed rose, picked up at last (World._restore_roses)
	collected.emit(kind, world, id)
	match kind:
		&"freed":
			if count(&"freed", world) >= total(&"freed", world):
				_earn(world, StringName("%s_10" % world))   # every brief's Key 10 is "five woken"
		&"tin":
			_earn(&"hub", StringName("tin_%s" % world))
	if rank() > rank_before:
		ranked.emit(rank())
	save_game()
	return true


## A rose earned by something other than a pickup (five woken, a tin). The level tosses it down at Nim's feet, to be
## picked up like any deed's rose (owner: "it makes the collection obvious ... and keeps the collect process
## consistent"): see World._on_rose_earned. With no level listening, it's paid straight away.
## A rose for something done (the club's sessions and scenes, WO-014b): tossed down like the rest.
func earn_rose(world: StringName, id: StringName) -> void:
	_earn(world, id)


func _earn(world: StringName, id: StringName) -> void:
	if has_collected(&"key", world, id):
		return
	if rose_earned.get_connections().is_empty():
		collect(&"key", world, id)
	else:
		rose_earned.emit(world, id)


func has_collected(kind: StringName, world: StringName, id: StringName) -> bool:
	return got.get(String(kind), {}).get(String(world), {}).has(String(id))


## How many of `kind` she has in `world`, or everywhere with world &"".
func count(kind: StringName, world: StringName = &"") -> int:
	var per_world: Dictionary = got.get(String(kind), {})
	if world != &"":
		return per_world.get(String(world), {}).size()
	var n := 0
	for w: String in per_world:
		n += (per_world[w] as Dictionary).size()
	return n


func total(kind: StringName, world: StringName) -> int:
	return TOTALS.get(world, WORLD_TOTALS).get(kind, 0)


# --- ranks -----------------------------------------------------------------------------------------------------------

## Every Key she has, everywhere. Ranks are counted in these; they're never spent.
func keys() -> int:
	return count(&"key")


## Her rank in the order: how many thresholds her Keys have passed (0 to 7).
func rank() -> int:
	var k := keys()
	var r := 0
	for need in RANK_KEYS:
		if k >= need:
			r += 1
	return r


## Whether a world's door is open to her (its rank reached). The hub and test scenes are always open.
func world_open(world: StringName) -> bool:
	var i := RANK_WORLDS.find(world)
	return i < 0 or keys() >= RANK_KEYS[i]


# --- scenes ----------------------------------------------------------------------------------------------------------

## Leave for another scene and come in at `arrival` there. Deferred: never change scene from inside a physics or input
## callback (Nine Lives learned this the hard way on the Deck).
func travel(scene: String, arrival: String = "") -> void:
	arrive = arrival
	get_tree().paused = false
	get_tree().call_deferred(&"change_scene_to_file", scene)


func remember_wardrobe(scene: String, at: Vector3, yaw: float) -> void:
	last_wardrobe = {"scene": scene, "pos": [at.x, at.y, at.z], "yaw": yaw}
	save_game()


# --- settings --------------------------------------------------------------------------------------------------------

## A setting, or its default (SETTING_DEFAULTS) if `default` isn't given and it's never been set.
func get_setting(key: String, default: Variant = null) -> Variant:
	return _settings.get_value("game", key, default if default != null else SETTING_DEFAULTS.get(key))


func set_setting(key: String, value: Variant) -> void:
	_settings.set_value("game", key, value)
	if persist:
		_settings.save(SETTINGS_PATH)
	settings_changed.emit(key)


## Forget a setting in memory only (probes use it to see the first-launch age gate without touching the real file).
func forget_setting(key: String) -> void:
	if _settings.has_section_key("game", key):
		_settings.erase_section_key("game", key)


# --- save ------------------------------------------------------------------------------------------------------------

## The slot in play, as data.
func to_dict() -> Dictionary:
	return {"flags": flags, "got": got, "last_wardrobe": last_wardrobe, "saved_at": Time.get_datetime_string_from_system()}


func from_dict(d: Dictionary) -> void:
	flags = d.get("flags", {})
	got = d.get("got", {})
	last_wardrobe = d.get("last_wardrobe", {})


## Writes the slot in play into the file with the others.
func save_game() -> void:
	if not persist:
		return
	_slots[str(slot)] = to_dict()
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"version": VERSION, "current": slot, "slots": _slots}, "\t"))


## Reads the file and plays the slot it was last on.
func load_game() -> void:
	if not persist or not FileAccess.file_exists(save_path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary:
		return
	if data.has("slots"):
		_slots = data["slots"]
		slot = int(data.get("current", 1))
	else:
		_slots = {"1": data}   # a version 1 save: one game, no slots
		slot = 1
	from_dict(_slots.get(str(slot), {}))


## Switch to slot `n` (1 to SLOTS): the current one's saved, `n`'s is loaded (empty if it's never been played).
func use_slot(n: int) -> void:
	save_game()
	slot = clampi(n, 1, SLOTS)
	from_dict(_slots.get(str(slot), {}))
	arrive = ""
	save_game()


## A slot's headline, for the slot menu: Keys, rank and when it was saved, or empty.
func slot_summary(n: int) -> Dictionary:
	var d: Dictionary = to_dict() if n == slot else _slots.get(str(n), {})
	if d.is_empty() or (d.get("flags", {}).is_empty() and d.get("got", {}).is_empty()):
		return {}   # never played (or erased)
	var k := 0
	var keys_by_world: Dictionary = d.get("got", {}).get("key", {})
	for w: String in keys_by_world:
		k += (keys_by_world[w] as Dictionary).size()
	return {"keys": k, "saved_at": d.get("saved_at", "")}


func erase_slot(n: int) -> void:
	_slots.erase(str(n))
	if n == slot:
		reset()
	elif persist:
		save_game()


## Forget one world's progress: its flags (bound goons, shortcuts, travel points) and what was collected there.
func clear_world(world: StringName) -> void:
	for prefix: String in ["bound/%s/" % world, "shortcut/%s/" % world, "travel/%s/" % world]:
		for k: String in flags.keys():
			if k.begins_with(prefix):
				flags.erase(k)
	for kind: String in got:
		(got[kind] as Dictionary).erase(String(world))
	save_game()


## Wipe the slot in play (the pause menu's "Erase progress", later, and tests). Settings stay.
func reset() -> void:
	flags = {}
	got = {}
	arrive = ""
	last_wardrobe = {}
	save_game()
