class_name Sisters
extends RefCounted
## Where Vesper's sisters are (owner, 2026-11-13: "the sisters should all be away on missions and only come back after
## you complete their story"; "like the Grunty switch in Banjo changing the World"). Each is out on her own world's
## job, and comes home to the Velvet Claw when Nim has finished it ("done/<world>"). Her room is dark till then.
## The first time Nim talks to her at home is her homecoming ("home/<who>", set by club.dialogue). Her first good
## scene at home earns her Rose.

## Each sister's world.
const WORLD := {"dash": &"pier", "grizelda": &"primrose", "silke": &"docks", "lull": &"retreat", "rivet": &"press",
	"augusta": &"ball"}
## Each sister's Rose (the hub's). Dash's keeps the old "first sister scene" id, so a save that has it keeps it.
const ROSE := {"dash": &"hub_09", "grizelda": &"hub_11", "silke": &"hub_12", "lull": &"hub_13", "rivet": &"hub_14",
	"augusta": &"hub_15"}
## Her room (Hub.ROOMS id), for the guide.
const ROOM := {"dash": "her room", "grizelda": "the Throne Room", "silke": "the Rope Room", "lull": "the Quiet Room",
	"rivet": "the Workshop", "augusta": "the Parlour"}


static func _game() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node_or_null(^"/root/Game")


## Is she home? (A name that isn't a sister's is always "home": nobody else goes away.)
static func home(who: String) -> bool:
	if not WORLD.has(who):
		return true
	var g := _game()
	return g != null and bool(g.call(&"has_flag", "done/%s" % WORLD[who]))


## Home and greeted.
static func greeted(who: String) -> bool:
	var g := _game()
	return g != null and bool(g.call(&"has_flag", "home/%s" % who))


## Her Rose, for a good scene with her (once; Game ignores a Rose already held).
static func earn_rose(who: String) -> void:
	var g := _game()
	if g and ROSE.has(who):
		g.call(&"earn_rose", &"hub", ROSE[who])


static func has_rose(who: String) -> bool:
	var g := _game()
	return g != null and ROSE.has(who) and bool(g.call(&"has_collected", &"key", &"hub", ROSE[who]))
