class_name SwingDoor
extends Node3D
## A door that swings open as someone comes up to it and shuts behind them (owner, from a first playthrough: "Front Door
## of Club doesn't open": it was a painted panel in an open doorway). The node sits at the hinge; the leaf runs along
## its +X for `width`, and opens toward -Z (inward) by `swing`. Nothing to collide with: the doorway it hangs in is the
## way through, and the leaf is out of it whenever anyone's near.

@export var width := 2.0
@export var height := 2.8
@export var swing := deg_to_rad(100.0)
## Someone (Nim, or anyone in the "talker"/"client" groups) this close to its middle opens it.
@export var reach := 3.2
var material: Material

var _leaf: Node3D
var _open := 0.0


func _ready() -> void:
	_leaf = Node3D.new()
	add_child(_leaf)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, height, 0.08)
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = Vector3(width / 2.0, height / 2.0, 0)
	_leaf.add_child(mesh)
	# A brass handle on both faces.
	for z: float in [-0.07, 0.07]:
		var knob := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.06
		s.height = 0.12
		knob.mesh = s
		knob.material_override = Look.toon(Color("c8a040"), 0.6)
		knob.position = Vector3(width - 0.18, 1.05, z)
		_leaf.add_child(knob)


func _physics_process(delta: float) -> void:
	var mid := global_transform * Vector3(width / 2.0, 0, 0)
	var want := 0.0
	var scene := get_tree().current_scene
	var nim: Node3D = scene.get(&"nim") if scene else null
	if nim and Vector2(nim.global_position.x - mid.x, nim.global_position.z - mid.z).length() < reach \
			and absf(nim.global_position.y - mid.y) < 2.0:
		want = 1.0
	else:
		for g: StringName in [&"talker", &"client"]:
			for p: Node in get_tree().get_nodes_in_group(g):
				var b := p as Node3D
				if b and Vector2(b.global_position.x - mid.x, b.global_position.z - mid.z).length() < reach - 0.6:
					want = 1.0
					break
	_open = move_toward(_open, want, delta * (2.4 if want > _open else 1.2))
	_leaf.rotation.y = swing * (1.0 - pow(1.0 - _open, 2.0))


func is_open() -> bool:
	return _open > 0.9
