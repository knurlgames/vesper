class_name NimSuit
extends Node
## Nim's outfits and everything that hangs off them (WO-006, DESIGN.md "The outfits change what she can do"):
##
##   - **Garb or suit,** swapped at a Wardrobe. A change always restores her cover and her Composure.
##   - **Composure** (the suit's one meter, 0 to 1): doing something out of character while anyone can see her drains
##     it (running, jumping, pouncing, climbing, crouching, trying to fight, a command that fails). A poised strut in
##     sight and commands that work restore it. Empty, and her **cover's blown**: the goons nearby come for her, and
##     only now will she fight in the suit.
##   - **The strut:** in the suit, the stick pushed part-way (or B held) is a poised walk; all the way is a run.
##   - **Recovery:** her cover comes back when nobody's after her and nobody's seen her for a while (break sight; a
##     crowd helps), at a wardrobe, or with Hold the Room (Vesper's world-4 lesson: hold Y and stare the room down).
##   - **Crowds:** strutting among guests (two within reach), she's one of them: nobody picks her out.
##   - **Commands** (suit, cover intact): LT picks who, the D-pad picks the word, Y says it. Kneel (core), Fetch and
##     Open (Grizelda's world-2 lesson). Everyone has a tier; asking above it fails and costs Composure.
##   - **The fake trance** (Lull's pendant, world 4; LB): slow, eyes half shut; goons and lookouts ignore her until she
##     does anything quick.
##
## A child of Nim, ticked before NimCombat. Watchers (goons, staff, guests, lookouts) are in the "watcher" group with a
## `sees_her` they keep up to date; commandable people are in "commandable" with `command_tier()` and `obey()`.

signal outfit_changed(outfit: Outfit)
signal composure_changed(value: float, blown: bool, outfit: Outfit)
signal word_changed(word: StringName)
## She gave a command (the word, obeyed or not) or held the room (&"hold_room"): her model plays the gesture.
signal gestured(what: StringName)
## A short line for the HUD: a refusal, a failed command.
signal said(text: String)

enum Outfit { GARB, SUIT }

const WORDS: Array[StringName] = [&"kneel", &"fetch", &"open"]
## How much authority each word needs (an NPC's tier is the most it will obey).
const WORD_LEVEL := {&"kneel": 1, &"fetch": 2, &"open": 2}
## Which lesson teaches each word ("" = she knows it from the start).
const WORD_LESSON := {&"kneel": "", &"fetch": "lesson_fetch_open", &"open": "lesson_fetch_open"}

const STRUT_SPEED := 3.2
## The stick pushed this far or less is a strut, in the suit.
const STRUT_STICK := 0.6
## Composure: what drains it (per second, or per act) while she's watched, and what restores it.
const DRAIN_RUN := 0.3
const DRAIN_CLIMB := 0.4
const DRAIN_CROUCH := 0.2
const COST_JUMP := 0.12
const COST_POUNCE := 0.25
const COST_REFUSED := 0.1
const COST_FAILED := 0.25
const GAIN_STRUT := 0.06
const GAIN_COMMAND := 0.15
## Cover blown: goons this close come for her.
const BLOWN_RADIUS := 25.0
## Unwatched and unchased this long, her cover's back (at this much Composure).
const RECOVER_TIME := 5.0
const RECOVER_TO := 0.35
const HOLD_ROOM_TIME := 1.0
const HOLD_ROOM_RADIUS := 15.0
const HOLD_ROOM_TO := 0.3
const COMMAND_RANGE := 6.0
const CROWD_REACH := 2.2
const CROWD_MIN := 2
const CHANGE_TIME := 1.0
const WARDROBE_REACH := 1.6
## A wardrobe won't do with a goon chasing her this close.
const CHANGE_CLEAR := 2.5
const TRANCE_SPEED := 1.2
## Pushing the stick past this (trying to run) breaks the trance.
const TRANCE_BREAK_PUSH := 0.85

var nim: Nim
var outfit := Outfit.GARB
var composure := 1.0
var cover_blown := false
var word: StringName = &"kneel"
## Strutting among guests: nobody picks her out (Sight).
var hidden_in_crowd := false
## The pendant's fake trance: goons and lookouts ignore her (Sight).
var faking_trance := false
var watched := false
## What staff have fetched her (key ids).
var keys := {}

var _unwatched_t := 0.0
var _hold_y := 0.0
var _change_t := 0.0
var _change_to := Outfit.GARB
## True for the frame Y went to a wardrobe or a command (NimCombat leaves it alone).
var interact_used := false


func _ready() -> void:
	nim = get_parent() as Nim


func in_suit() -> bool:
	return outfit == Outfit.SUIT


## In the suit with her cover intact, she won't fight (or bind, or stun with a pounce).
func refuses_fight() -> bool:
	return in_suit() and not cover_blown


## Whether `watcher` treats her as an intruder: always in her night garb, in the suit only once her cover's blown, or
## if he's one who knows her face.
func suspicious_to(watcher: Node) -> bool:
	if not in_suit() or cover_blown:
		return true
	return watcher.get(&"knows_her") == true


## Which group LT locks on to: in the suit with her cover, people to command; otherwise goons.
func lock_group() -> StringName:
	return &"commandable" if in_suit() and not cover_blown else &"enemy"


func changing() -> bool:
	return _change_t > 0.0


func knows(lesson: String) -> bool:
	return nim.knows(lesson)


## The pendant's fake trance on or off (NimGear calls it on LB when there's nobody to wake).
func toggle_trance() -> void:
	faking_trance = not faking_trance
	said.emit("Eyes half shut. Slow." if faking_trance else "")


func set_outfit(o: Outfit) -> void:
	outfit = o
	cover_blown = false
	composure = 1.0
	faking_trance = false
	outfit_changed.emit(o)
	composure_changed.emit(composure, cover_blown, outfit)


# --- each frame ------------------------------------------------------------------------------------------------------

func tick(delta: float) -> void:
	interact_used = false
	if _change_t > 0.0:
		_change_t -= delta
		if _change_t <= 0.0:
			set_outfit(_change_to)
			# The pause menu's "Back to the last wardrobe".
			var game := nim.get_node_or_null(^"/root/Game")
			var scene := nim.get_tree().current_scene
			if game and scene:
				game.call(&"remember_wardrobe", scene.scene_file_path, nim.global_position, nim.rotation.y)
			_lose_chasers()
		return
	watched = _anyone_watching()
	_crowd()
	_trance_input()
	_word_input()
	_interact_input(delta)
	_composure(delta)


## The target speed for her move this frame, given the outfit: a strut, or the trance's shuffle.
func adjust(wish: Vector3, target: Vector3) -> Vector3:
	if faking_trance:
		return wish.limit_length(1.0) * TRANCE_SPEED
	if in_suit() and nim.is_on_floor():
		var push := wish.length()
		if Input.is_action_pressed(&"crouch"):
			return wish.normalized() * STRUT_SPEED if push > 0.1 else Vector3.ZERO
		if push <= STRUT_STICK:
			return wish / STRUT_STICK * STRUT_SPEED
	return target


func strutting() -> bool:
	if not in_suit() or not nim.is_on_floor():
		return false
	var speed := Vector2(nim.velocity.x, nim.velocity.z).length()
	return speed > 0.3 and speed <= STRUT_SPEED + 0.6


## Something out of character just happened (Nim and NimCombat call this): it costs Composure if anyone's watching.
## The trance breaks on anything quick.
func act(what: StringName) -> void:
	if faking_trance and what != &"refused":
		faking_trance = false
		said.emit("The trance is broken.")
	if not in_suit() or cover_blown or not watched:
		return
	match what:
		&"jump":
			_spend(COST_JUMP)
		&"pounce":
			_spend(COST_POUNCE)
		&"refused":
			_spend(COST_REFUSED)


## Staff hand her what she sent them to Fetch.
func receive(id: StringName) -> void:
	keys[id] = true
	said.emit("Thank you.")   # OWNER REVIEW


func refused() -> void:
	said.emit("Not in the suit. Not while they're watching.")   # OWNER REVIEW
	act(&"refused")


# --- composure and cover ---------------------------------------------------------------------------------------------

func _anyone_watching() -> bool:
	for w: Node in nim.get_tree().get_nodes_in_group(&"watcher"):
		if w.get(&"sees_her") == true:
			return true
	return false


func _composure(delta: float) -> void:
	if not in_suit():
		return
	if cover_blown:
		# Back when no goon is after her and none has seen her for a while.
		var hunted := false
		for e: Node in nim.get_tree().get_nodes_in_group(&"enemy"):
			if e.call(&"hunting"):
				hunted = true
				break
		_unwatched_t = 0.0 if hunted or watched else _unwatched_t + delta
		if _unwatched_t >= RECOVER_TIME:
			_restore(RECOVER_TO)
		return
	if not watched:
		return
	var speed := Vector2(nim.velocity.x, nim.velocity.z).length()
	var before := composure
	if nim.state == Nim.State.CLIMB or nim.state == Nim.State.HANG or nim.state == Nim.State.MANTLE:
		composure -= DRAIN_CLIMB * delta
	elif nim.crouching:
		composure -= DRAIN_CROUCH * delta
	elif nim.is_on_floor() and speed > STRUT_SPEED + 0.6:
		composure -= DRAIN_RUN * delta
	elif strutting():
		composure = minf(1.0, composure + GAIN_STRUT * delta)
	if composure != before:
		_settle()


func _spend(amount: float) -> void:
	composure -= amount
	_settle()


func _settle() -> void:
	if composure <= 0.0 and not cover_blown:
		composure = 0.0
		_blow()
	composure_changed.emit(composure, cover_blown, outfit)


## Someone's come for her (a goon gave chase): in the suit, her cover's gone.
func expose() -> void:
	if in_suit() and not cover_blown:
		composure = 0.0
		_settle()


## Her cover's blown: every goon near enough comes for her.
func _blow() -> void:
	cover_blown = true
	_unwatched_t = 0.0
	said.emit("Cover blown.")
	for e: Node3D in nim.get_tree().get_nodes_in_group(&"enemy"):
		if e.global_position.distance_to(nim.global_position) <= BLOWN_RADIUS:
			e.call(&"alert", nim.global_position)


func _restore(to: float) -> void:
	cover_blown = false
	composure = to
	_unwatched_t = 0.0
	composure_changed.emit(composure, cover_blown, outfit)


## A change at a wardrobe, out of their sight: whoever was after her loses her.
func _lose_chasers() -> void:
	for e: Node in nim.get_tree().get_nodes_in_group(&"enemy"):
		e.call(&"lose_her")


# --- crowds and the trance -------------------------------------------------------------------------------------------

func _crowd() -> void:
	hidden_in_crowd = false
	if not in_suit() or not nim.is_on_floor():
		return
	var speed := Vector2(nim.velocity.x, nim.velocity.z).length()
	if speed > STRUT_SPEED + 0.6:
		return
	var near := 0
	for g: Node3D in nim.get_tree().get_nodes_in_group(&"guest"):
		if g.global_position.distance_to(nim.global_position) <= CROWD_REACH:
			near += 1
	hidden_in_crowd = near >= CROWD_MIN


func _trance_input() -> void:
	if faking_trance:
		# The trance holds her to a shuffle; pushing the stick hard (trying to run) breaks it, as does anything quick.
		var push := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down").length()
		if push > TRANCE_BREAK_PUSH or nim.state != Nim.State.MOVE or nim.pouncing() or nim.combat.striking() \
				or not nim.is_on_floor():
			act(&"broke")


# --- commands, wardrobes, Hold the Room ------------------------------------------------------------------------------

func _word_input() -> void:
	var picks := {&"word_up": &"kneel", &"word_right": &"fetch", &"word_down": &"open"}
	for action: StringName in picks:
		if Input.is_action_just_pressed(action):
			var w: StringName = picks[action]
			if knows(WORD_LESSON[w]):
				word = w
				word_changed.emit(word)
			else:
				said.emit("She doesn't know that one yet.")


func _interact_input(delta: float) -> void:
	var y_pressed := Input.is_action_just_pressed(&"interact")
	_hold_y = _hold_y + delta if Input.is_action_pressed(&"interact") else 0.0
	if y_pressed:
		var teacher := _near(&"lesson_giver", WARDROBE_REACH + 0.4)
		if teacher and not teacher.get(&"taught"):
			interact_used = true
			teacher.call(&"teach", nim)
			return
		var talker := _near_talker()
		if talker:
			interact_used = true
			talker.call(&"talk")
			return
		var point := _near(&"travel_point", 1.8)
		if point and point.get(&"found") == true:
			interact_used = true
			point.call(&"open_menu", nim)
			return
		var door := _near(&"shortcut", 1.8)
		if door and not door.get(&"is_open"):
			interact_used = true
			if not door.call(&"try_open", nim.global_position):
				said.emit("Bolted from the other side.")
			return
		var robe := _near_wardrobe()
		if robe and nim.is_on_floor():
			interact_used = true
			if _hunter_within(CHANGE_CLEAR):
				said.emit("Not with him on her heels.")
				return
			# Garb to suit and back; a blown suit is swapped for a fresh one (a new mask, a different coat).
			_change_to = Outfit.SUIT if not in_suit() or cover_blown else Outfit.GARB
			_change_t = CHANGE_TIME
			nim.velocity = Vector3.ZERO
			return
		if in_suit() and not cover_blown:
			interact_used = true
			_command()
			return
	if cover_blown and in_suit() and knows("lesson_hold_room") and _hold_y >= HOLD_ROOM_TIME:
		_hold_y = -INF   # once per hold
		interact_used = true
		_hold_the_room()


func _hunter_within(r: float) -> bool:
	for e: Node3D in nim.get_tree().get_nodes_in_group(&"enemy"):
		if e.call(&"hunting") and e.global_position.distance_to(nim.global_position) <= r:
			return true
	return false


## What Y would do right now, for the HUD's prompt ("" for nothing). The same order as _interact_input, then the
## Bind and Hold the Room.
func y_prompt() -> String:
	if _change_t > 0.0 or not nim.is_on_floor():
		return ""
	var teacher := _near(&"lesson_giver", WARDROBE_REACH + 0.4)
	if teacher and not teacher.get(&"taught"):
		return "Learn"
	if _near_talker():
		return "Talk"
	var point := _near(&"travel_point", 1.8)
	if point and point.get(&"found") == true:
		return "Travel"
	var door := _near(&"shortcut", 1.8)
	if door and not door.get(&"is_open"):
		return "Open" if (nim.global_position - door.global_position).dot(door.global_basis.z) > 0.0 else "Bolted"
	if _near_wardrobe():
		return "Change"
	if in_suit() and not cover_blown:
		var who := _nearest_commandable()
		return "Command: %s" % String(word).capitalize() if who else ""
	if cover_blown and in_suit() and knows("lesson_hold_room"):
		return "Hold the Room (hold)"
	for e: Node3D in nim.get_tree().get_nodes_in_group(&"enemy"):
		if e.global_position.distance_to(nim.global_position) <= NimCombat.BIND_RANGE \
				and e.call(&"bindable_from", nim.global_position):
			return "Bind"
	return ""


## Someone to talk to, in their reach, with something to say.
func _near_talker() -> Node3D:
	for t: Node3D in nim.get_tree().get_nodes_in_group(&"talker"):
		if t.global_position.distance_to(nim.global_position) <= float(t.get(&"reach")) and t.call(&"next_label") != "":
			return t
	return null


func _near(group: StringName, reach: float) -> Node3D:
	for n: Node3D in nim.get_tree().get_nodes_in_group(group):
		if n.global_position.distance_to(nim.global_position) <= reach:
			return n
	return null


func _near_wardrobe() -> Node3D:
	for w: Node3D in nim.get_tree().get_nodes_in_group(&"wardrobe"):
		if w.global_position.distance_to(nim.global_position) <= WARDROBE_REACH:
			return w
	return null


## Y in the suit: the word to the LT target, or to whoever's nearest in front.
func _command() -> void:
	var who: Node3D = nim.combat.lock if nim.combat.lock and nim.combat.lock.is_in_group(&"commandable") else _nearest_commandable()
	if who == null:
		return
	if who.global_position.distance_to(nim.global_position) > COMMAND_RANGE:
		return
	gestured.emit(word)
	var tier: int = who.call(&"command_tier")
	# Augusta's signet: the powerful answer to her as if they were staff.
	if who.get(&"powerful") == true and knows(Lessons.SIGNET):
		tier = 2
	if WORD_LEVEL[word] > tier or not who.call(&"can_obey", word):
		said.emit("They don't move.")
		_spend(COST_FAILED)
		return
	who.call(&"obey", word, nim)
	composure = minf(1.0, composure + GAIN_COMMAND)
	composure_changed.emit(composure, cover_blown, outfit)


func _nearest_commandable() -> Node3D:
	var best: Node3D = null
	var best_d := COMMAND_RANGE
	for c: Node3D in nim.get_tree().get_nodes_in_group(&"commandable"):
		var to := c.global_position - nim.global_position
		to.y = 0.0
		if to.length() < best_d and (to.length() < 1.0 or nim.facing().angle_to(to) < deg_to_rad(60.0)):
			best = c
			best_d = to.length()
	return best


## Vesper's world-4 lesson: with her cover blown, she holds still and stares the room down. Everyone after her who can
## see her stops, thinks better of it, and goes back to what they were doing.
func _hold_the_room() -> void:
	for e: Node3D in nim.get_tree().get_nodes_in_group(&"enemy"):
		if e.global_position.distance_to(nim.global_position) <= HOLD_ROOM_RADIUS:
			e.call(&"stand_down")
	gestured.emit(&"hold_room")
	said.emit("She holds the room.")   # OWNER REVIEW
	_restore(HOLD_ROOM_TO)
