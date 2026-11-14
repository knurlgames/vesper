class_name RankDoor
extends StaticBody3D
## A world's gate, opening to her rank in the order (WO-008, DESIGN.md: ranks are counted in Keys, never spent, and
## each opens the next world). Its front faces -Z.
##
## A pair of wrought-iron gates, velvet across their feet, a brass plaque between them saying how many Roses it
## wants (owner, 2026-11-14: "revamp how the gates drop for each world and ensure that they stay unlocked instead of
## the red gate dropping every time you get close"; it was a red slab that sank whenever she walked up, every visit).
## Unlocked, the plaque drops away, the gates rattle on their bolt and swing open toward her, back flat against the
## street's sides, and they stay open for good: `flag` ("gate/<world>") is saved, and a gate whose flag is set is
## built open.

@export var keys_needed := 1
@export var width := 3.0
@export var height := 3.5
## The Game flag that remembers it's open ("" forgets: a probe's door).
@export var flag := ""
## Open by itself when she comes up to it with the Roses (the hub opens its world gates with a scene first, and
## leaves this on as a fallback).
@export var auto_open := true

const SWING := deg_to_rad(96.0)
const NEAR := 5.0

var is_open := false
var _col: CollisionShape3D
var _label: Label3D
var _plaque: Node3D
var _leaves: Array[Node3D] = []


func _ready() -> void:
	add_to_group(&"rank_door")
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height, 0.3)
	_col = CollisionShape3D.new()
	_col.shape = shape
	_col.position.y = height / 2.0
	add_child(_col)
	for side: float in [-1.0, 1.0]:
		_leaves.append(_leaf(Vector3(side * width / 2.0, 0, 0), width / 2.0, -side))
	# The plaque, hung across the meeting edges on the front.
	_plaque = Node3D.new()
	_plaque.position = Vector3(0, minf(height * 0.55, 2.3), -0.1)
	add_child(_plaque)
	DoorKit.part(_plaque, [[Vector3.ZERO, Vector3(1.15, 0.62, 0.04)]], Look.toon(Look.BRASS, 0.7))
	DoorKit.part(_plaque, [[Vector3(0, 0, -0.022), Vector3(1.03, 0.5, 0.01)]], Look.toon(Look.VELVET.darkened(0.35), 0.2))
	_label = Label3D.new()
	_label.font_size = 48
	_label.pixel_size = 0.006
	_label.outline_size = 8
	_label.outline_modulate = Look.INK
	_label.modulate = Look.BRASS.lightened(0.35)
	_label.position = Vector3(0, 0, -0.03)
	_label.rotation.y = PI
	_label.double_sided = false
	_plaque.add_child(_label)
	var game := get_node_or_null(^"/root/Game")
	if flag != "" and game and game.call(&"has_flag", flag):
		open(0.0)


## One gate, hinged at `hinge`, running `along` (+1/-1 on X) for `w`: an iron frame and bars with finials, velvet
## across its foot, brass caps.
func _leaf(hinge: Vector3, w: float, along: float) -> Node3D:
	var n := Node3D.new()
	n.position = hinge
	add_child(n)
	var h := height
	var iron := []
	var mid := h * 0.42
	for x: float in [0.05, w - 0.05]:   # the stiles
		iron.append([Vector3(along * x, h / 2.0, 0), Vector3(0.1, h, 0.1)])
	for y: float in [0.12, mid, h - 0.12]:   # the rails
		iron.append([Vector3(along * w / 2.0, y, 0), Vector3(w, 0.09, 0.09)])
	var bars := maxi(3, roundi(w / 0.3))
	var brass := []
	for i in range(1, bars):
		var x := w * i / bars
		iron.append([Vector3(along * x, (mid + h) / 2.0, 0), Vector3(0.045, h - mid, 0.045)])
		iron.append([Vector3(along * x, h + 0.09, 0), Vector3(0.07, 0.18, 0.07)])   # a spike over each bar
	for x: float in [0.05, w - 0.05]:
		brass.append([Vector3(along * x, h + 0.07, 0), Vector3(0.16, 0.14, 0.16)])   # brass caps on the stiles
	brass.append([Vector3(along * w / 2.0, mid + 0.06, 0), Vector3(w - 0.1, 0.03, 0.11)])
	DoorKit.part(n, iron, Look.toon(Look.INK.lightened(0.12), 0.45))
	DoorKit.part(n, brass, Look.toon(Look.BRASS, 0.7))
	DoorKit.part(n, [[Vector3(along * w / 2.0, (0.12 + mid) / 2.0, 0), Vector3(w - 0.12, mid - 0.2, 0.04)]],
		Look.toon(Look.VELVET, 0.25))
	return n


func _physics_process(_delta: float) -> void:
	if is_open:
		return
	var game := get_node_or_null(^"/root/Game")
	var have: int = game.call(&"keys") if game else 0
	_label.text = "%d ROSE%s\n(you have %d)" % [keys_needed, "" if keys_needed == 1 else "S", have]
	if have < keys_needed or not auto_open:
		return
	var nim := get_tree().get_first_node_in_group(&"player") as Node3D
	if nim and nim.global_position.distance_to(global_position) < NEAR:
		open()


## Unbolts and swings both gates open toward the front, for good. Awaitable (the hub's gate scene waits on it); `secs`
## 0 is at once (a gate already open when the level's built).
func open(secs := 1.4) -> Signal:
	if is_open:
		return get_tree().process_frame
	is_open = true
	_col.set_deferred(&"disabled", true)
	var game := get_node_or_null(^"/root/Game")
	if flag != "" and game:
		game.call(&"set_flag", flag)
	# The left gate (hinged at -X, running +X) turns +; the right, -: both come toward the front (-Z).
	var angles := [SWING, -SWING]
	if secs <= 0.0:
		_plaque.visible = false
		for i in 2:
			_leaves[i].rotation.y = angles[i]
		return get_tree().process_frame
	var tw := create_tween()
	# The plaque drops away; a rattle on the bolt; then they swing.
	tw.tween_property(_plaque, ^"position:y", -0.4, 0.35).as_relative().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_plaque, ^"scale", Vector3.ONE * 0.01, 0.35)
	tw.tween_callback(func() -> void: _plaque.visible = false)
	for k in 2:
		for i in 2:
			var j := tw.parallel() if i == 1 else tw
			j.tween_property(_leaves[i], ^"rotation:y", angles[i] * 0.03 * (1 - k), 0.07)
	for i in 2:
		var j := tw.parallel() if i == 1 else tw
		j.tween_property(_leaves[i], ^"rotation:y", angles[i], secs).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tw.finished
