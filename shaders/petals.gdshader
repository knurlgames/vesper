// Rose petals on the ground, swirling slowly round a middle (owner, 2026-11-14: the fast-travel points as "a bed of
// rose petals on the ground that swirl a little"). One MultiMesh of petals; each instance's INSTANCE_CUSTOM is
// (radius, angle, phase, turn) and its colour is the instance colour. The motion is all here, so a bed costs one draw
// and no script. A few petals (by phase) lift and drift higher than the rest.
shader_type spatial;
render_mode cull_disabled;

#include "res://shaders/toon_light.gdshaderinc"

// Radians a second at 1 m out (nearer the middle turns faster).
uniform float swirl = 0.22;
// How high the ordinary petals breathe; the lifted ones go several times higher.
uniform float bob = 0.015;
// Brighter while it's the checkpoint she comes back to.
uniform float glow = 0.0;

varying vec3 v_col;

void vertex() {
	float r = INSTANCE_CUSTOM.r;
	float ph = INSTANCE_CUSTOM.b;
	float a = INSTANCE_CUSTOM.g + TIME * swirl / (0.35 + r);
	float s = INSTANCE_CUSTOM.a + TIME * 0.8 * (fract(ph * 7.0) - 0.5);
	mat3 turn = mat3(vec3(cos(s), 0.0, -sin(s)), vec3(0.0, 1.0, 0.0), vec3(sin(s), 0.0, cos(s)));
	float flier = step(0.86, fract(ph * 3.0));
	float wave = 0.5 + 0.5 * sin(TIME * (1.1 + flier * 0.6) + ph * 6.2832);
	float lift = bob * wave * (1.0 + flier * 14.0);
	// A flier tips as it rises.
	float tip = flier * wave * 0.9;
	mat3 tilt = mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, cos(tip), sin(tip)), vec3(0.0, -sin(tip), cos(tip)));
	VERTEX = turn * tilt * VERTEX + vec3(cos(a) * r, 0.015 + fract(ph * 13.0) * 0.025 + lift, sin(a) * r);
	NORMAL = turn * tilt * NORMAL;
	v_col = COLOR.rgb;
}

void fragment() {
	ALBEDO = v_col;
	EMISSION = v_col * glow;
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
	v_gloss = 0.0;
	v_jitter = 0.0;
}
