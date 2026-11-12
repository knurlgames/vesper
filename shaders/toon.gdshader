// Characters and props: a colour (and texture, for Meshy props), the toon ramp, optional gloss for latex and brass,
// and an optional rim so Nim reads against every world (ART_DIRECTION.md "Colour").
shader_type spatial;

#include "res://shaders/toon_light.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic;
uniform float gloss : hint_range(0.0, 1.0) = 0.0;
uniform vec4 rim_color : source_color = vec4(0.6, 0.72, 1.0, 1.0);
uniform float rim : hint_range(0.0, 2.0) = 0.0;
// Lit glass: the brightest, warmest parts of the texture glow (a lamp's lantern). 0 for everything else.
uniform float glow : hint_range(0.0, 8.0) = 0.0;

void fragment() {
	vec4 c = texture(albedo_tex, UV) * albedo;
	ALBEDO = c.rgb;
	float warm = smoothstep(0.45, 0.65, c.r) * smoothstep(0.05, 0.2, c.r - c.b);
	EMISSION = c.rgb * warm * glow;
	ROUGHNESS = mix(0.9, 0.15, gloss);
	SPECULAR = mix(0.15, 0.6, gloss);
	v_gloss = gloss;
	v_jitter = 0.0;
	float f = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	EMISSION += rim_color.rgb * smoothstep(0.55, 0.75, f) * rim;
}
