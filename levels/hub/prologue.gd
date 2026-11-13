extends Node3D
## The prologue (worlds/01_PIER.md "Coming in"; WO-014 step 5): Nim's first night as one of the Rope, in the club's
## dungeon. Vesper welcomes her; a member's guest comes down the ramp glassy-eyed, holding a prize-stall plush that
## hums. Nim breaks its device (a strike at the toy, from in front: Entranced). He wakes, and that pays the hub's Key 10
## (her first Key, rank 1: the Pier's gate opens). Vesper reads the tag: "Laffer's Fun Palace. The Pier."
## After that (flag hub/prologue_done), Vesper's in the lounge.

const DIALOGUE := "res://data/dialogue/hub/prologue.dialogue"
const DUNGEON := -1.6
const VESPER_DUNGEON := Vector3(2.5, DUNGEON, -35.2)
const VESPER_LOUNGE := Vector3(0.0, 0.0, -26.6)
## The ramp between the dungeon and the lounge, and the guest's seat up there.
const RAMP_FOOT := Vector3(7.5, DUNGEON, -33.0)
const RAMP_TOP := Vector3(7.5, 0.0, -25.0)
## At the bar, waiting for his tea, clear of every way through the lounge. (At (2.2, -21) he stuck on a sofa's back;
## at the sofa's east end he stood in the way from the door to the ramp.)
const GUEST_SEAT := Vector3(-6.6, 0.0, -23.4)

var hub: Node
var vesper: Talker
var guest: Entranced
var stage := 0


func _ready() -> void:
	hub = get_parent()
	_setup.call_deferred()


func _setup() -> void:
	vesper = Talker.new()
	vesper.name = "Vesper"
	vesper.file = "res://data/dialogue/hub/club.dialogue"
	vesper.label = "vesper"
	vesper.who = "vesper"
	vesper.outfit = "suit"
	vesper.display_name = "Vesper"
	add_child(vesper)
	if Game.has_flag("hub/prologue_done"):
		_to_lounge()
		stage = 3
		return
	vesper.global_position = VESPER_DUNGEON
	vesper.rotation.y = -PI / 2.0
	vesper.label = ""   # nothing to say over Y until the prologue's done
	await get_tree().create_timer(0.6).timeout
	# After every wait: still in the game? (Quit to the title mid-prologue and this would play over whatever's next.)
	if not is_inside_tree():
		return
	await Dialogue.run(DIALOGUE, "welcome")
	if not is_inside_tree():
		return
	guest = Entranced.new()
	guest.id = &"guest"
	guest.name = "Entranced_guest"
	guest.colour = Color("b0a0c8")
	guest.look_body = "hare_civilian"
	guest.toy = "toy_plush"   # "a prize-stall plush that hums"
	guest.loop = PackedVector3Array([Vector3(7.5, 0, -25.0), Vector3(7.5, DUNGEON, -33.0), Vector3(2.0, DUNGEON, -34.0),
		Vector3(7.5, DUNGEON, -33.0)])
	guest.position = Vector3(7.5, 0.05, -24.0)
	hub.add_child(guest)
	await get_tree().create_timer(2.5).timeout
	if not is_inside_tree():
		return
	await Dialogue.run(DIALOGUE, "guest")
	Hud.note("Wake him: strike the toy he's holding, from in front. (X)", 5.0)
	stage = 1


func _physics_process(_delta: float) -> void:
	if stage == 1 and Game.has_collected(&"freed", &"hub", &"guest") and not Dialogue.is_active():
		stage = 2
		_tag()


func _tag() -> void:
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree():
		return
	await Dialogue.run(DIALOGUE, "tag")
	if not is_inside_tree():
		return
	# He does as he's told: up the ramp to the lounge to sit down. Vesper follows him up (both on foot: owner, on the
	# Deck, "have the characters move on organically instead of simply teleporting away like in the Dungeon").
	if guest:
		guest.go([RAMP_FOOT, RAMP_TOP, GUEST_SEAT])
	Game.set_flag("hub/prologue_done")
	Hud.note("The Pier's gate is open: east of the square, down Seafront Road.", 5.0)
	stage = 3
	await get_tree().create_timer(1.2).timeout
	if not is_inside_tree():
		return
	vesper.label = "vesper"   # she'll talk on the way, too
	await vesper.walk_path([RAMP_FOOT, RAMP_TOP, VESPER_LOUNGE], 1.8)
	if is_inside_tree():
		_to_lounge()


func _to_lounge() -> void:
	vesper.global_position = VESPER_LOUNGE
	vesper.rotation.y = PI
	vesper.label = "vesper"
