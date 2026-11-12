extends Level
## The test room: a checkered floor, steps, a ramp and a few blocks at night, with the greybox Nim and the follow camera.
## Built in code. The probes use it; Back / Tab flips to the street corner.

const SPAWN := Vector3(0, 0.1, 10)
const ROOM := 40.0

const CHECKER := "shader_type spatial;
uniform vec3 a : source_color = vec3(0.24, 0.20, 0.26);
uniform vec3 b : source_color = vec3(0.17, 0.14, 0.19);
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 c = floor(wp.xz);
	ALBEDO = mod(c.x + c.y, 2.0) < 1.0 ? a : b;
	ROUGHNESS = 0.9;
}"


func _ready() -> void:
	_environment()
	var checker := ShaderMaterial.new()
	checker.shader = Shader.new()
	checker.shader.code = CHECKER
	block(Vector3(0, -0.5, 0), Vector3(ROOM, 1, ROOM), checker)
	# Steps, a ramp, and blocks at jump heights.
	for i in 5:
		block(Vector3(-8, 0.25 + i * 0.25, -4 - i * 1.0), Vector3(4, 0.5 + i * 0.5, 1.0), flat(Color("5a4660")))
	var ramp := block(Vector3(8, 1.0, -6), Vector3(4, 0.4, 8), flat(Color("4a5a66")))
	ramp.rotation.x = deg_to_rad(-15)
	for h: float in [0.5, 1.0, 1.5, 2.0]:
		block(Vector3(1 + h * 4.0, h / 2.0, 2), Vector3(1.5, h, 1.5), flat(Color("6a4a3a")))
	# Walls round the edge so nothing runs off by accident.
	for side: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var size := Vector3(1, 3, ROOM) if side.x != 0.0 else Vector3(ROOM, 3, 1)
		block(side * (ROOM / 2.0 + 0.5) + Vector3.UP * 1.5, size, flat(Color("2a2230")))
	spawn_player(SPAWN)


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("120c18")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("5a4a78")
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color("b8c4ff")
	moon.light_energy = 0.8
	moon.shadow_enabled = true
	moon.rotation = Vector3(deg_to_rad(-50), deg_to_rad(30), 0)
	add_child(moon)
