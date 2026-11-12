// Architecture: painted patterns in world space, so code-built boxes need no UVs (ART_DIRECTION.md "Pipeline").
// Each face picks the plane it mostly faces (floors use XZ, walls use their own plane with Y up), draws a pattern with
// brush-stroke mottling, and gets wet: darker, glossier, with puddles and rain rings on floors.
//
// pattern: 0 plaster, 1 brick, 2 cobbles, 3 flagstones, 4 slate, 5 planks
shader_type spatial;

#include "res://shaders/toon_light.gdshaderinc"

uniform int pattern = 0;
uniform vec4 base_color : source_color = vec4(0.5, 0.45, 0.5, 1.0);
// Mortar, grout and joints.
uniform vec4 accent : source_color = vec4(0.12, 0.1, 0.14, 1.0);
// Bigger numbers, bigger bricks and stones.
uniform float scale = 1.0;
// How hard the brush strokes mottle the colour.
uniform float stroke : hint_range(0.0, 0.5) = 0.14;
// The night is always wet: 0 dry, 1 soaked.
uniform float wet : hint_range(0.0, 1.0) = 0.6;
// How much of a floor is puddle.
uniform float puddles : hint_range(0.0, 1.0) = 0.0;
uniform float rain : hint_range(0.0, 1.0) = 1.0;

varying vec3 wp;
varying vec3 wn;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	return noise(p) * 0.55 + noise(p * 2.03 + 17.0) * 0.3 + noise(p * 4.1 + 41.0) * 0.15;
}

// A running bond of w x h cells with a joint `j` wide and pieces rounded by `r`. Returns (joint mask 0..1, cell id hash,
// x and y across the piece, -1..1).
vec4 bond(vec2 p, float w, float h, float j, float r) {
	float row = floor(p.y / h);
	float x = p.x / w + mod(row, 2.0) * 0.5 + (hash(vec2(row, 3.0)) - 0.5) * 0.3;
	vec2 cell = vec2(floor(x), row);
	vec2 half_size = vec2(w, h) * 0.5;
	vec2 f = vec2(fract(x) * w, fract(p.y / h) * h) - half_size;
	vec2 s = half_size - j * 0.5;
	vec2 q = abs(f) - (s - r);
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
	return vec4(smoothstep(-j * 0.3, j * 0.1, d), hash(cell), f / s);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	bool floor_face = wn.y > 0.6;
	vec2 p;
	if (abs(wn.y) > 0.6) {
		p = wp.xz;
	} else if (abs(wn.x) > abs(wn.z)) {
		p = vec2(wp.z, wp.y);
	} else {
		p = vec2(wp.x, wp.y);
	}
	p /= scale;

	float joint = 0.0;
	float tint = 0.5;
	vec2 bump = vec2(0.0);
	if (pattern == 1) {          // brick
		vec4 b = bond(p, 0.26, 0.085, 0.014, 0.004);
		joint = b.x;
		tint = b.y;
	} else if (pattern == 2) {   // cobbles: rounded, uneven stones that catch the light
		vec2 wobble = vec2(noise(p * 3.1), noise(p * 2.7 + 9.0)) * 0.05;
		vec4 b = bond(p + wobble, 0.22, 0.19, 0.035, 0.06);
		joint = b.x;
		tint = b.y;
		bump = b.zw;
	} else if (pattern == 3) {   // flagstones
		vec4 b = bond(p, 0.75, 0.55, 0.02, 0.01);
		joint = b.x;
		tint = b.y;
	} else if (pattern == 4) {   // slate, darker at each course's lower edge
		vec4 b = bond(p, 0.32, 0.17, 0.012, 0.0);
		joint = max(b.x, (-b.w * 0.5 + 0.5) * 0.45);
		tint = b.y;
	} else if (pattern == 5) {   // planks, running up the face
		vec4 b = bond(p.yx, 1.4, 0.16, 0.012, 0.0);
		joint = b.x;
		tint = b.y;
	}
	// Far off, small joints shimmer: settle them into an even tone.
	float near = 1.0 - smoothstep(9.0, 26.0, length(wp - CAMERA_POSITION_WORLD));
	joint = mix(joint * 0.5 + 0.12, joint, near);
	bump *= near;

	// Brush strokes: noise stretched along the face, plus a per-piece tint.
	float strokes = fbm(vec2(p.x * 1.3, p.y * 7.0)) - 0.5;
	vec3 col = base_color.rgb * (1.0 + strokes * stroke * 2.0 + (tint - 0.5) * 0.18);
	col = mix(col, accent.rgb, joint);

	// Wet: everything darkens and shines a little; floors pool.
	float puddle = 0.0;
	if (floor_face && puddles > 0.0) {
		float n = fbm(wp.xz * 0.22);
		puddle = smoothstep(0.62 - puddles * 0.3, 0.66 - puddles * 0.3, n);
	}
	float wetness = wet * (floor_face ? 1.0 : 0.55);
	col *= mix(1.0, 0.62, wetness);
	col = mix(col, col * 0.4 + vec3(0.01, 0.012, 0.03), puddle);

	vec3 n = wn;
	if (puddle < 0.5) {
		n = normalize(wn + vec3(bump.x, 0.0, bump.y) * 0.3 * (1.0 - joint));
	} else if (rain > 0.0) {
		// Rain rings: one drop per 0.7 m cell, each on its own clock.
		vec2 cell = floor(wp.xz / 0.7);
		vec2 f = fract(wp.xz / 0.7) - 0.5 - (vec2(hash(cell), hash(cell + 7.0)) - 0.5) * 0.5;
		float t = fract(TIME * 0.9 + hash(cell + 3.0));
		float r = length(f);
		float ring = sin((r - t * 0.45) * 70.0) * (1.0 - t) * (1.0 - smoothstep(0.0, 0.08, abs(r - t * 0.45)));
		n = normalize(wn + vec3(f.x, 0.0, f.y) / max(r, 0.001) * ring * 0.05 * rain);
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);

	ALBEDO = col;
	ROUGHNESS = mix(mix(0.92, 0.45, wetness * (1.0 - joint)), 0.04, puddle);
	SPECULAR = mix(0.3, 0.6, max(wetness, puddle));
	v_gloss = max(wetness * 0.35 * (1.0 - joint), puddle * 0.75);
	v_jitter = strokes * 0.25;
}
