// The travel cyclone's buds and petals (RoseCyclone): the toon light, each instance in its own colour (MultiMesh
// colours; the mesh's vertex colour is white), both sides drawn (a petal is one sheet).
shader_type spatial;
render_mode cull_disabled;

#include "res://shaders/toon_light.gdshaderinc"

uniform float glow = 0.25;

void fragment() {
	ALBEDO = COLOR.rgb;
	EMISSION = COLOR.rgb * glow;
	ROUGHNESS = 0.8;
	SPECULAR = 0.2;
	v_gloss = 0.0;
	v_jitter = 0.0;
}
