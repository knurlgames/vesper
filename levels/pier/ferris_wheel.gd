extends Node3D
## The Pier's Ferris wheel (worlds/01_PIER.md, Key 8): a rim that turns about the X axis and cars that hang level off
## it. The cars are AnimatableBody3Ds moved in the physics step, so Nim rides them. Its origin is the axle.
##
## Climbed while it turns: she hops into the lowest car at the platform, then car to car as they pass, up to the crown
## platform over the top, where Key 8 waits. The crown is fixed; it doesn't turn.

@export var radius := 13.0
@export var cars := 8
## Seconds per turn. Slow: the rim moves about 1.4 m/s.
@export var period := 60.0
## How far a car's floor hangs under its pivot on the rim.
@export var hang := 1.3
@export var car_size := Vector3(2.4, 0.2, 1.8)

var angle := 0.0
var car_bodies: Array[AnimatableBody3D] = []
var _rim: Node3D


func _ready() -> void:
	_rim = Node3D.new()
	_rim.name = "Rim"
	add_child(_rim)
	var frame := Look.toon(Color("e8e0d0"), 0.3)
	var bulb := StandardMaterial3D.new()
	bulb.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bulb.albedo_color = Color(2.2, 1.6, 0.9)
	# The rim: two rings of struts (one each side of the cars), spokes to the hub, a bulb at every joint.
	var segs := 32
	for side: float in [-1.6, 1.6]:
		for i in segs:
			var a0 := TAU * i / segs
			var a1 := TAU * (i + 1) / segs
			var p0 := Vector3(side, sin(a0) * radius, cos(a0) * radius)
			var p1 := Vector3(side, sin(a1) * radius, cos(a1) * radius)
			_strut(p0, p1, 0.18, frame)
			if i % 2 == 0:
				_strut(Vector3(side, 0, 0), p0, 0.1, frame)
			var b := MeshInstance3D.new()
			var s := SphereMesh.new()
			s.radius = 0.16
			s.height = 0.32
			b.mesh = s
			b.material_override = bulb
			b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			b.position = p0 * Vector3(1, 1.01, 1.01)
			_rim.add_child(b)
	var hub := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.9
	cyl.bottom_radius = 0.9
	cyl.height = 3.8
	hub.mesh = cyl
	hub.rotation.z = PI / 2.0
	hub.material_override = Look.toon(Look.BRASS, 0.6)
	add_child(hub)
	# The cars: a floor, a back and two sides, waist high, open at the front (+Z of the car) and the top.
	var car_mat := Look.toon(Color("c83a4a"), 0.35)
	for i in cars:
		var car := AnimatableBody3D.new()
		car.name = "Car%d" % i
		car.sync_to_physics = true
		add_child(car)
		_car_part(car, Vector3(0, -car_size.y / 2.0, 0), car_size, car_mat)
		_car_part(car, Vector3(0, 0.45, -car_size.z / 2.0 + 0.06), Vector3(car_size.x, 0.9, 0.12), car_mat)
		for sx: float in [-1.0, 1.0]:
			_car_part(car, Vector3(sx * (car_size.x / 2.0 - 0.06), 0.3, 0.0), Vector3(0.12, 0.6, car_size.z), car_mat)
		# The hanger up to the rim.
		var rod := MeshInstance3D.new()
		var rc := CylinderMesh.new()
		rc.top_radius = 0.05
		rc.bottom_radius = 0.05
		rc.height = hang
		rod.mesh = rc
		rod.position = Vector3(0, hang / 2.0, 0)
		rod.material_override = frame
		car.add_child(rod)
		car_bodies.append(car)
	_place()


func _physics_process(delta: float) -> void:
	angle = fposmod(angle + TAU * delta / period, TAU)
	_place()


## Where car `i`'s pivot is now, in the wheel's space.
func pivot(i: int) -> Vector3:
	var a := angle + TAU * i / cars
	return Vector3(0, sin(a) * radius, cos(a) * radius)


func _place() -> void:
	if _rim:
		_rim.rotation.x = -angle
	for i in car_bodies.size():
		car_bodies[i].position = pivot(i) - Vector3(0, hang, 0)


func _car_part(car: Node3D, at: Vector3, size: Vector3, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	m.mesh = box
	m.position = at
	m.material_override = mat
	car.add_child(m)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position = at
	car.add_child(col)


func _strut(a: Vector3, b: Vector3, thick: float, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(thick, thick, a.distance_to(b))
	m.mesh = box
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rim.add_child(m)
	m.look_at_from_position((a + b) / 2.0, b, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT)
