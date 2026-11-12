class_name WorldData
extends RefCounted
## Each world as data (WO-008): `data/worlds/<id>.json`, taken from the briefs in docs/worlds/. Its areas, wardrobes,
## shortcuts, the 10 Keys (id, name, where, outfit, the joke), contraband, the tin, the set piece and the boss. Levels
## place Keys by these ids; the pause screen and later the HUD name them from here. The briefs are proposals: change a
## brief, change its file.

const DIR := "res://data/worlds/"

static var _cache := {}


## The world's data, or {} if it has no file (the test course, the probe world).
static func of(world: StringName) -> Dictionary:
	if _cache.has(world):
		return _cache[world]
	var path := DIR + String(world) + ".json"
	var d := {}
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			d = parsed
	_cache[world] = d
	return d


## One Key's entry ({} if the world or Key isn't known).
static func key(world: StringName, id: StringName) -> Dictionary:
	for k: Dictionary in of(world).get("keys", []):
		if k.get("id") == String(id):
			return k
	return {}


## Every world file there is, by id.
static func all_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for f in DirAccess.get_files_at(DIR):
		if f.ends_with(".json"):
			ids.append(StringName(f.get_basename()))
	return ids
