class_name Guide
extends RefCounted
## What to do next, and where (owner, from a first playthrough: "Need a guide or arrow to assist with story
## progression"; "wife ran down the Pier but never knew to go visit Dash"; "Vesper cutscene never triggered because she
## didn't go down"). Read off the save's flags each frame by Level._process, shown by Hud.set_goal: a line under
## Dignity and a marker over the place (or an arrow at the screen's edge toward it).
##
## `step(level)` returns [text, where] (where is Vector3.INF for "no one place"), or ["", INF] for nothing to say.

const NONE := ["", Vector3.INF]

## The Pier's ramp down to the beach (pier.gd: along the sea wall, x -40 at the top), Vesper's lesson under the deck
## (keys/vesper_lesson.gd TRIGGER), Dash's beach hut and the gate (keys/dash_race.gd HUT, START).
const PIER_RAMP := Vector3(-40.0, 0.0, 3.0)
const PIER_LESSON := Vector3(-3.0, -6.0, -27.0)
const PIER_DASH_HUT := Vector3(64.5, 0.0, 14.6)
const PIER_GATE := Vector3(2.5, 0.0, 5.0)
const PIER_HALL := Vector3(0.0, 0.0, -255.0)
## The hub: the Pier's gate at the end of Seafront Road (hub.gd _gate), Primrose Lane's mouth (hub.gd STUBS).
const HUB_PIER_GATE := Vector3(77.0, 0.0, 5.0)
const HUB_PRIMROSE := Vector3(-8.0, 0.0, 28.0)
## Primrose: Vesper's lesson at the Neighbourhood Watch hut (keys/vesper_lesson.gd VESPER_AT).
const PRIMROSE_LESSON := Vector3(7.6, 0.12, 0.6)


static func step(level: Node) -> Array:
	var world: StringName = level.get(&"world_id")
	match world:
		&"hub":
			return _hub(level)
		&"pier":
			return _pier(level)
		&"primrose":
			return _primrose(level)
	return NONE


static func _hub(level: Node) -> Array:
	if not Game.has_flag("hub/prologue_done"):
		# The prologue's guest, once he's wandering about in his trance.
		var guest := level.get_node_or_null(^"Entranced_guest") as Node3D
		if guest and not Game.has_collected(&"freed", &"hub", &"guest"):
			return ["Wake the guest: strike the toy he's holding, from in front (%s)." % Controls.glyph(&"strike"),
				guest.global_position]
		return NONE
	# A sister home from her job, not yet welcomed: first (Sisters; she's in her room in the vaults).
	for who: String in Sisters.WORLD:
		if Sisters.home(who) and not Sisters.greeted(who):
			var s := level.get_node_or_null(NodePath(who.capitalize())) as Node3D
			return ["%s is home. Welcome her back: %s, in the vaults." % [who.capitalize(), Sisters.ROOM[who]],
				s.global_position if s else Vector3.INF]
	# Inside the club, a sister at home whose Rose is still to earn: a scene with her.
	var nim := level.get(&"nim") as Node3D
	if nim and nim.global_position.y < -1.0:
		for who: String in Sisters.WORLD:
			if Sisters.greeted(who) and not Sisters.has_rose(who):
				var s := level.get_node_or_null(NodePath(who.capitalize())) as Node3D
				return ["A first scene with %s, either way round, earns her Rose." % who.capitalize(),
					s.global_position if s else Vector3.INF]
	if not Game.has_flag("done/pier"):
		var how := "Head for the Pier" if not Game.has_flag("visited/pier") else "Back to the Pier"
		return ["%s: east across the square, down Seafront Road to the gate." % how, HUB_PIER_GATE]
	if Game.world_open(&"primrose") and not Game.has_flag("done/primrose"):
		return ["Primrose Close: down Primrose Lane, off the south side of the square.", HUB_PRIMROSE]
	return NONE


static func _pier(level: Node) -> Array:
	var nim := level.get(&"nim") as Node3D
	if not Game.has_flag("pier/lesson_done"):
		# Down the ramp first, then under the deck to her.
		if nim and nim.global_position.y > -3.0:
			return ["Vesper's waiting under the pier. Take the ramp down to the beach, at the west end of the promenade.",
				PIER_RAMP]
		return ["Vesper's waiting under the pier, on a beam over the first smuggler.", PIER_LESSON]
	if Game.has_flag("pier/race_on"):
		return ["Race Dash: stand beside her at the gate.", PIER_GATE]
	if not (Game.has_flag("pier/race_won") or Game.has_flag("pier/race_lost")):
		return ["Dash is at her beach hut on the promenade. She wants a race.", PIER_DASH_HUT]
	if not Game.has_flag("done/pier"):
		var have := Game.count(&"key", &"pier")
		if have < 9:
			return ["Find the Pier's Velvet Roses (%d of 10). Help people out; break Swyne's toys." % have, Vector3.INF]
		return ["Laffer's in the Prize Hall, at the far end of the pier.", PIER_HALL]
	return NONE


static func _primrose(_level: Node) -> Array:
	if not Game.has_flag("primrose/lesson_done"):
		return ["Vesper's at the Neighbourhood Watch hut, by the Close's entrance.", PRIMROSE_LESSON]
	if not Game.has_flag("done/primrose"):
		return ["Find Primrose Close's Velvet Roses (%d of 10)." % Game.count(&"key", &"primrose"), Vector3.INF]
	return NONE
