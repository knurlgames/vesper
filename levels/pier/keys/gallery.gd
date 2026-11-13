extends "res://levels/pier/keys/pier_key.gd"
## Key 3: the shooting gallery (worlds/01_PIER.md). In the suit, with Dash's crop: talk to the barker, then crack all six
## targets in thirty seconds from the counter. It's rigged: they slide on rails behind the counter, and every hit makes
## the rest go faster. The prize is one of Swyne's toys, and Nim confiscates it.

@export var secs := 30.0
@export var targets := 6
## Rail speed, metres a second, at the start and with one target left.
@export var speed_from := 1.4
@export var speed_to := 3.0

## The stall: x -16..-9, z -24..-36; the counter's front at x -9. The rails run along x -11.6 behind it.
const RAIL_X := -11.6
const RAIL_Z := Vector2(-26.0, -34.0)
const BARKER := Vector3(-10.4, 0.0, -30.0)
const PRIZE := Vector3(-8.0, 0.0, -30.0)

var barker: Talker
var playing := false
var hits := 0
var _t := 0.0
var _targets: Array[CropTarget] = []
var _phase: Array[float] = []


func _setup() -> void:
	barker = talker("Barker", "gallery", "start", BARKER, -PI / 2.0, "", "garb", "Barker", Color("c83a3a"), true,
		"weasel_goon")   # one of Laffer's staff, in the striped waistcoat
	barker.reach = 2.6
	barker.talked.connect(_on_talked)
	_track_outfit()


## The barker's lines depend on her outfit: a flag the conversation can read.
func _track_outfit() -> void:
	var n := nim()
	if n == null:
		return
	set_flag("in_suit", n.suit.in_suit())
	n.suit.outfit_changed.connect(func(_o: int) -> void: set_flag("in_suit", n.suit.in_suit()))


func _on_talked(_which: String) -> void:
	if flag("gallery_go") and not playing:
		clear("gallery_go")
		_start()


func _start() -> void:
	playing = true
	hits = 0
	_t = 0.0
	for i in targets:
		var t := CropTarget.new()
		t.name = "GalleryTarget%d" % i
		t.kind = CropTarget.Kind.TARGET
		t.rotation.y = PI / 2.0   # its face toward the counter (+X)
		add_child(t)
		t.hit.connect(_on_hit.bind(t))
		_targets.append(t)
		_phase.append(float(i) / targets)
	_place(0.0)
	Hud.note("Crack all %d targets: hold X." % targets, 2.5)


func _on_hit(t: CropTarget) -> void:
	if not playing:
		return
	hits += 1
	t.visible = false
	if hits >= targets:
		_end(true)


func _physics_process(delta: float) -> void:
	if not playing:
		return
	_t += delta
	_place(delta)
	if _t >= secs:
		_end(false)


## Each target ping-pongs along the rail; three heights. The fewer left, the faster they go.
func _place(delta: float) -> void:
	var left := float(targets - hits) / targets
	var speed := lerpf(speed_to, speed_from, left)
	var span := RAIL_Z.x - RAIL_Z.y
	for i in _targets.size():
		_phase[i] = fposmod(_phase[i] + speed * delta / (span * 2.0), 1.0)
		var u := _phase[i] * 2.0
		var z := RAIL_Z.x - span * (u if u <= 1.0 else 2.0 - u)
		_targets[i].global_position = Vector3(RAIL_X, 1.4 + (i % 3) * 0.55, z)


func _end(won: bool) -> void:
	playing = false
	for t in _targets:
		t.queue_free()
	_targets.clear()
	_phase.clear()
	if won:
		set_flag("gallery_won")
		await talk("gallery", "won")
		award(&"pier_03", PRIZE)
	else:
		await talk("gallery", "lost")
