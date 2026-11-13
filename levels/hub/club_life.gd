extends Node
## The living dungeon (WO-014b; owner: "have the clients filter in/out... some fixed, but they can also be 'random' in
## a sense like the dungeon is alive"). A child of the hub. Clients (ClubClient) come in at the door in street clothes,
## change at the screen by the bar (swimwear downstairs), go down to the vaults' hall and wait, take a free sister's
## room for a session, go on to Lull's room for aftercare, and leave. A few regulars come and go among them.
##
## While a client waits in the hall, Nim can offer them a session of her own (in the suit): their Talker runs the
## check-in (hub/sessions.dialogue), and "club/session_go" starts the game (core/club_game.gd). The scenes with the
## sisters (Switch or Domme) start the same way, from their own conversations ("club/scene/<sister>_<way>").

const ClubGame := preload("res://core/club_game.gd")
const SESSIONS := "res://data/dialogue/hub/sessions.dialogue"

## How many clients in the club at once, and how often a new one comes in.
const MAX_CLIENTS := 6
const ARRIVE_EVERY := Vector2(14.0, 24.0)
## How long things take (seconds, a range).
const WAIT := Vector2(18.0, 40.0)
const SESSION := Vector2(30.0, 55.0)
const AFTERCARE := Vector2(18.0, 30.0)
## Ambient lines are spoken when Nim's within this, every LINE_EVERY.
const HEAR := 7.5
const LINE_EVERY := 4.0

const DOOR := Vector3(0.0, 0.0, -17.2)
const SCREEN := Vector3(-7.4, 0.0, -17.6)
## From the lounge to the vaults' hall: past the sofas, the ramp to the dungeon, the stair down.
const DOWN := [Vector3(1.0, 0.0, -18.0), Vector3(6.6, 0.0, -18.6), Vector3(7.5, 0.0, -26.0), Vector3(7.5, -1.6, -33.0),
	Vector3(0.0, -1.6, -36.0), Vector3(0.0, -1.6, -38.2), Vector3(0.0, -5.0, -46.6), Vector3(0.0, -5.0, -50.0)]
## Where clients wait in the hall, between the doorways, facing across it.
const WAITS := [Vector3(-3.1, -5.0, -55.0), Vector3(3.1, -5.0, -55.0), Vector3(-3.1, -5.0, -62.0),
	Vector3(3.1, -5.0, -62.0), Vector3(-3.1, -5.0, -49.4), Vector3(3.1, -5.0, -49.4)]
## Lull's room: two places on the chaise (its seat's front edge; it stands against the east wall), facing the hall.
const AFTERCARE_SPOTS := [Vector3(10.1, -5.0, -53.4), Vector3(10.1, -5.0, -52.3)]

## The four bodies, street and swimwear, and tints for a crowd.
const BODIES := [["otter_civilian", "otter_swim"], ["hare_civilian", "hare_swim"], ["fox_civilian", "fox_swim"],
	["hedgehog_civilian", "hedgehog_swim"]]
const TINTS := [Color("ffffff"), Color("f0e0ff"), Color("e0f0ff"), Color("fff0d8"), Color("e8ffe8")]
## The regulars: id, name over them, body pair, who they talk as.
const REGULARS := [
	[&"smith", "\"Mr Smith\" (a false moustache)", ["hedgehog_civilian", "hedgehog_swim"], "smith"],
	[&"pip", "Pip (first time)", ["otter_civilian", "otter_swim"], "pip"],
]

## What's said in each room during a session (OWNER REVIEW): the sister's line, then the client's, in turn.
const ROOM_LINES := {
	&"parlour": [["Augusta", "Chin up. Shoulders down. There."], ["", "Like this, Mistress?"], ["Augusta", "Exactly like that. Hold it."], ["", "...Thank you, Mistress."]],
	&"rope": [["Silke", "How's that? Too snug?"], ["", "No. It's... perfect."], ["Silke", "Wiggle your fingers for me. Good."], ["", "I could stay like this."]],
	&"throne": [["Grizelda", "You missed a spot."], ["", "Sorry, Mistress Grizelda."], ["Grizelda", "The left heel. Again. With feeling."], ["", "Yes, Mistress."]],
	&"dash": [["Dash", "Faster! Faster! ...Okay, slower."], ["", "Is this... a workout?"], ["Dash", "It's whatever I say it is."], ["", "I love it here."]],
	&"quiet": [["Lull", "Tea's warm. Take your time."], ["", "That was a lot. Good a lot."], ["Lull", "Mm. Tell me about it."], ["", "I feel... lighter."]],
}

var hub: Node3D
var _clients: Array[ClubClient] = []
var _arrive_t := 3.0
var _line_t := 0.0
var _line_i := {}
var _game: Node
var _speech := {}   # a sister's speech label, by name


func _ready() -> void:
	hub = get_parent()
	_setup.call_deferred()


func _setup() -> void:
	Game.flag_changed.connect(_on_flag)
	# The club's already busy when she comes in: one in a session, one waiting, one in aftercare.
	var a := _spawn()
	_start_session(a, true)
	var b := _spawn()
	_to_wait(b, true)
	var c := _spawn()
	_to_aftercare(c, true)


func _process(delta: float) -> void:
	if _game:
		return
	_arrive_t -= delta
	if _arrive_t <= 0.0:
		_arrive_t = randf_range(ARRIVE_EVERY.x, ARRIVE_EVERY.y)
		if _clients.size() < MAX_CLIENTS:
			_spawn()
	for c in _clients.duplicate():
		if is_instance_valid(c):
			_tick(c, delta)
	_clients.assign(_clients.filter(func(c: Variant) -> bool: return is_instance_valid(c)))
	_line_t -= delta
	if _line_t <= 0.0:
		_line_t = LINE_EVERY
		_ambient_lines()


# --- the evening -----------------------------------------------------------------------------------------------------

func _spawn() -> ClubClient:
	var c := ClubClient.new()
	var reg := _free_regular()
	if not reg.is_empty() and randf() < 0.35:
		c.regular = reg[0]
		c.display = reg[1]
		c.street_body = reg[2][0]
		c.swim_body = reg[2][1]
		c.talk_as = reg[3]
	else:
		var pair: Array = BODIES[randi() % BODIES.size()]
		c.street_body = pair[0]
		c.swim_body = pair[1]
		c.tint = TINTS[randi() % TINTS.size()]
	c.name = "Client_%d" % randi()
	c.position = DOOR
	hub.add_child(c)
	_clients.append(c)
	c.phase = &"arriving"
	c.go([SCREEN])
	return c


func _free_regular() -> Array:
	for r: Array in REGULARS:
		if not _clients.any(func(c: Variant) -> bool: return is_instance_valid(c) and c.regular == r[0]):
			return r
	return []


func _tick(c: ClubClient, delta: float) -> void:
	match c.phase:
		&"arriving":
			if not c.walking():
				c.phase = &"changing"
				c.t = 1.2
		&"changing":
			c.t -= delta
			if c.t <= 0.0:
				c.dress(c.swim_body)
				c.phase = &"down"
				c.go(DOWN)
		&"down":
			if not c.walking():
				_to_wait(c)
		&"waiting":
			_keep_talker(c)
			c.t -= delta
			if c.t <= 0.0 and not _is_nims(c):
				var room := _free_room()
				if room.is_empty():
					c.t = 6.0
				else:
					_drop_talker(c)
					c.room = room
					_start_session(c)
		&"to_session":
			if not c.walking():
				c.phase = &"session"
				c.t = randf_range(SESSION.x, SESSION.y)
				c.face_toward = Hub.sister_spot(c.room)
				if c.room.id in [&"parlour", &"throne"]:
					c.pose(&"kneel", 0.18)   # the clip kneels, then stands: held on one knee
		&"session":
			c.t -= delta
			if c.t <= 0.0:
				_to_aftercare(c)
		&"to_aftercare":
			if not c.walking():
				c.phase = &"aftercare"
				c.t = randf_range(AFTERCARE.x, AFTERCARE.y)
				c.face_toward = c.spot + Vector3(-1.0, 0.0, 0.0)   # sat on the chaise, facing the hall, tea in hand
				c.pose(&"drink")
		&"aftercare":
			c.t -= delta
			if c.t <= 0.0:
				c.phase = &"leaving"
				var up: Array = DOWN.duplicate()
				up.reverse()
				c.go(_out_of(c.global_position) + up + [SCREEN, DOOR])
		&"leaving":
			if not c.walking():
				c.queue_free()


## Into the hall to wait (a free spot), or straight there when the club's set up.
func _to_wait(c: ClubClient, now := false) -> void:
	var taken := _clients.filter(func(o: Variant) -> bool:
		return is_instance_valid(o) and o != c and o.phase == &"waiting").map(func(o: Variant) -> Vector3: return o.spot)
	var free := WAITS.filter(func(p: Vector3) -> bool: return not p in taken)
	c.spot = free[0] if not free.is_empty() else WAITS[0]
	c.phase = &"waiting"
	c.t = randf_range(WAIT.x, WAIT.y)
	c.face_toward = Vector3(0.0, -5.0, c.spot.z)
	if now:
		c.dress(c.swim_body)
		c.global_position = c.spot
	else:
		c.go([Vector3(0.0, -5.0, c.spot.z), c.spot])


func _start_session(c: ClubClient, now := false) -> void:
	if c.room.is_empty():
		c.room = _free_room()
	if c.room.is_empty():
		_to_wait(c, now)
		return
	var at: Vector3 = c.room.at
	c.phase = &"to_session"
	if now:
		c.dress(c.swim_body)
		c.global_position = at
	else:
		c.go(_out_of(c.global_position) + [Vector3(0.0, -5.0, at.z), Vector3(signf(at.x) * 4.6, -5.0, at.z), at])


func _to_aftercare(c: ClubClient, now := false) -> void:
	var taken := _clients.filter(func(o: Variant) -> bool:
		return is_instance_valid(o) and o != c and o.phase in [&"to_aftercare", &"aftercare"]).map(
			func(o: Variant) -> Vector3: return o.spot)
	var free := AFTERCARE_SPOTS.filter(func(p: Vector3) -> bool: return not p in taken)
	c.spot = free[0] if not free.is_empty() else AFTERCARE_SPOTS[0]
	c.room = {}
	c.phase = &"to_aftercare"
	c.face_toward = Vector3.INF
	if now:
		c.dress(c.swim_body)
		c.global_position = c.spot
	else:
		c.go(_out_of(c.global_position) + [Vector3(0.0, -5.0, -51.5), Vector3(4.6, -5.0, -51.5), c.spot])


## From a room, back out through its doorway to the hall first.
func _out_of(p: Vector3) -> Array:
	if p.y > -4.0 or absf(p.x) < 4.2:
		return []
	return [Vector3(signf(p.x) * 4.6, -5.0, _room_z(p.z)), Vector3(0.0, -5.0, _room_z(p.z))]


func _room_z(z: float) -> float:
	for r: Dictionary in Hub.ROOMS:
		if absf(z - float(r.at.z)) < 3.6:
			return r.at.z
	return z


## A sister's room with nobody in it (or on the way), whose sister is there. Dash's, rarely: nobody books Dash.
func _free_room() -> Dictionary:
	var rooms := Hub.ROOMS.filter(func(r: Dictionary) -> bool:
		if not r.sessions or hub.get_node_or_null(NodePath(String(r.sister))) == null:
			return false
		if r.id == &"dash" and randf() > 0.15:
			return false
		return not _clients.any(func(c: Variant) -> bool:
			return is_instance_valid(c) and not c.room.is_empty() and c.room.id == r.id))
	return rooms[randi() % rooms.size()] if not rooms.is_empty() else {}


# --- Nim's own session -----------------------------------------------------------------------------------------------

## A waiting client can be talked to: the check-in for a session (in the suit), or the dress code (in her garb).
func _keep_talker(c: ClubClient) -> void:
	var t := c.get_node_or_null("Ask") as Talker
	if t == null:
		t = Talker.new()
		t.name = "Ask"
		t.greybox = false
		t.file = SESSIONS
		t.display_name = c.display if c.display != "" else "A member's guest"
		c.add_child(t)
	var nim: Node = hub.get(&"nim")
	var suit: bool = nim != null and nim.suit.in_suit()
	t.label = c.talk_as + ("_suit" if suit else "_garb")


func _drop_talker(c: ClubClient) -> void:
	var t := c.get_node_or_null("Ask")
	if t:
		t.queue_free()


func _is_nims(c: ClubClient) -> bool:
	return _game != null and _game.get(&"client") == c


## The client Nim's standing by (her last conversation was theirs).
func _nearest_waiting() -> ClubClient:
	var nim: Node3D = hub.get(&"nim")
	var best: ClubClient = null
	for c in _clients:
		if is_instance_valid(c) and c.phase == &"waiting" and nim and (best == null
				or c.global_position.distance_to(nim.global_position) < best.global_position.distance_to(nim.global_position)):
			best = c
	return best


func _on_flag(key: StringName) -> void:
	var k := String(key)
	if not k.begins_with("club/") or Game.get_flag(k) != true:
		return
	if k == "club/session_go":
		# A client's session is on the cross (the owner: "part of the Dom process has the option of the Sub on the
		# cross"): their form, Nim's tray, aftercare.
		Game.set_flag(k, false)
		var c := _nearest_waiting()
		if c:
			_cross("dom", c, c.talk_as)
	elif k.begins_with("club/cross/"):
		# A sister on the cross, or Nim on it for her: "club/cross/<sister>_<dom|sub>".
		Game.set_flag(k, false)
		var what := k.trim_prefix("club/cross/")
		var sister := what.get_slice("_", 0)
		var s := hub.get_node_or_null(NodePath(sister.capitalize())) as Node3D
		if s:
			_cross(what.get_slice("_", 1), s, sister)
	elif k.begins_with("club/scene/"):
		Game.set_flag(k, false)
		var what := k.trim_prefix("club/scene/")   # e.g. "silke_switch"
		_play(StringName(what.get_slice("_", 1)), null, what.get_slice("_", 0))


## A scene on the cross (core/cross_scene.gd), once the conversation that asked for it has closed.
func _cross(role: String, partner: Node3D, who: String) -> void:
	while Dialogue.is_active():
		await get_tree().process_frame
	if _game or not is_inside_tree():
		return
	var c := partner as ClubClient
	if c:
		_drop_talker(c)
		c.phase = &"with_nim"
	var scene := CrossScene.new()
	scene.hub = hub
	scene.role = role
	scene.partner = partner
	scene.who = who
	_game = scene
	add_child(scene)
	await scene.finished
	scene.queue_free()
	_game = null
	if c and is_instance_valid(c):
		_to_aftercare(c, true)
	elif partner is Talker:
		# She walks back to her room from the quiet room's aftercare, out into the hall and along it: never popped
		# back (owner, deck review 2: "move on from the cutscene organically instead of simply teleporting away").
		for r: Dictionary in Hub.ROOMS:
			if String(r.sister).to_lower() == who:
				var t := partner as Talker
				var from := t.global_position
				var side := signf(float(r.at.x))
				await t.walk_path([Vector3(3.0, from.y, from.z), Vector3(side * 3.0, from.y, float(r.at.z)),
					Hub.sister_spot(r)], 1.6)
				if is_instance_valid(t):
					var to: Vector3 = r.at - t.global_position
					t.rotation.y = atan2(-to.x, -to.z)


## Starts a game once the conversation that asked for it has closed (it pauses the world).
func _play(mode: StringName, c: ClubClient, sister: String) -> void:
	while Dialogue.is_active():
		await get_tree().process_frame
	if _game or not is_inside_tree():
		return
	_game = ClubGame.new()
	_game.hub = hub
	_game.client = c
	_game.sister = sister
	_game.mode = mode
	add_child(_game)
	if c:
		_drop_talker(c)
		c.phase = &"with_nim"
	var result: Dictionary = await _game.finished
	_game.queue_free()
	_game = null
	if c and is_instance_valid(c):
		_to_aftercare(c)


# --- what's said -----------------------------------------------------------------------------------------------------

## In each busy room near Nim, the next line of its exchange: the sister's over her head, the client's over theirs.
func _ambient_lines() -> void:
	var nim: Node3D = hub.get(&"nim")
	if nim == null or Dialogue.is_active():
		return
	for c in _clients:
		if not is_instance_valid(c) or c.global_position.distance_to(nim.global_position) > HEAR:
			continue
		var key: StringName = &""
		if c.phase == &"session" and not c.room.is_empty():
			key = c.room.id
		elif c.phase == &"aftercare":
			key = &"quiet"
		if key == &"" or not ROOM_LINES.has(key):
			continue
		var lines: Array = ROOM_LINES[key]
		var i: int = _line_i.get(c, 0) % lines.size()
		_line_i[c] = i + 1
		var who: String = lines[i][0]
		if who == "":
			c.say(lines[i][1])
		else:
			_sister_says(who, lines[i][1])


func _sister_says(who: String, text: String) -> void:
	var s := hub.get_node_or_null(NodePath(who)) as Node3D
	if s == null:
		return
	var l: Label3D = _speech.get(who)
	if l == null or not is_instance_valid(l):
		l = Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.font_size = 30
		l.pixel_size = 0.004
		l.outline_size = 6
		l.outline_modulate = Look.INK
		l.position.y = 2.7
		s.add_child(l)
		_speech[who] = l
	l.text = text
	get_tree().create_timer(3.5).timeout.connect(func() -> void:
		if is_instance_valid(l) and l.text == text:
			l.text = "")
