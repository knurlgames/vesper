class_name Look
## The look in code (ART_DIRECTION.md): toon materials, painted surfaces for architecture, ink outlines, and a pass that
## turns an imported Meshy prop into all three. Static helpers; nothing to instance.

const TOON := preload("res://shaders/toon.gdshader")
const PAINTED := preload("res://shaders/painted.gdshader")
const OUTLINE := preload("res://shaders/outline.gdshader")

## Painted patterns (shaders/painted.gdshader).
enum Pattern { PLASTER, BRICK, COBBLES, FLAGSTONES, SLATE, PLANKS }

## The palette (ART_DIRECTION.md "Colour"). The Velvet Claw's red belongs to the sisters, the club and their marks.
const VELVET := Color("7a1428")
const SODIUM := Color("ffa04a")
const MOON := Color("aab8ff")
const INDIGO := Color("1a1430")
const INK := Color("0d0814")
const BRASS := Color("b8893a")
const DECENCY_CREAM := Color("efe4c8")
const DECENCY_NAVY := Color("1f2a4a")


static func toon(colour: Color, gloss := 0.0, rim := 0.0, tex: Texture2D = null) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter(&"albedo", colour)
	m.set_shader_parameter(&"gloss", gloss)
	m.set_shader_parameter(&"rim", rim)
	if tex:
		m.set_shader_parameter(&"albedo_tex", tex)
	return m


## A painted surface. `opts`: scale, stroke, wet, puddles, rain.
static func painted(pattern: Pattern, base: Color, accent := Color("1c1620"), opts := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PAINTED
	m.set_shader_parameter(&"pattern", pattern)
	m.set_shader_parameter(&"base_color", base)
	m.set_shader_parameter(&"accent", accent)
	for k: String in opts:
		m.set_shader_parameter(StringName(k), opts[k])
	return m


## An ink outline for a mesh with these bounds.
static func outline(bounds: AABB, width := 0.012, ink := INK) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = OUTLINE
	m.set_shader_parameter(&"width", width)
	m.set_shader_parameter(&"ink", ink)
	m.set_shader_parameter(&"base", bounds.position.y)
	m.set_shader_parameter(&"height", bounds.size.y)
	return m


## Every mesh under `root`: its imported material becomes a toon one (keeping its colour and texture), and it gets an
## ink outline. `gloss` is for brass and latex only; props are matte.
static func dress(root: Node, outline_width := 0.012, gloss := 0.0, glow := 0.0) -> void:
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i)
			var colour := Color.WHITE
			var tex: Texture2D = null
			if src is BaseMaterial3D:
				colour = (src as BaseMaterial3D).albedo_color
				tex = (src as BaseMaterial3D).albedo_texture
			var m := toon(colour, gloss, 0.0, tex)
			m.set_shader_parameter(&"glow", glow)
			if mi.mesh.get_surface_count() == 1:
				mi.material_override = m
			else:
				mi.set_surface_override_material(i, m)
		if outline_width > 0.0:
			mi.material_overlay = outline(mi.get_aabb(), outline_width)
