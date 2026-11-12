// Shared toon lighting (ART_DIRECTION.md "Rendering"): soft painted steps, not hard cel bands. Light pools under lamps
// get a stepped edge too, so light and dark read at a glance (where Nim is safe).
// The including shader writes v_gloss (0 matte .. 1 latex or a puddle) and v_jitter (a painted wobble of the light's
// edge) in fragment().

uniform float ramp_soft : hint_range(0.01, 0.5) = 0.1;
// Where the second, brighter step starts (dot of normal and light).
uniform float ramp_split : hint_range(0.0, 1.0) = 0.45;

varying float v_gloss;
varying float v_jitter;

void light() {
	float ndl = dot(NORMAL, LIGHT) + v_jitter;
	float ramp = smoothstep(-ramp_soft, ramp_soft, ndl) * 0.6
		+ smoothstep(ramp_split - ramp_soft, ramp_split + ramp_soft, ndl) * 0.4;
	// Lamp pools: a bright core, a dimmer ring, then dark. Directional light (attenuation 1, or shadowed 0) passes through.
	float a = ATTENUATION;
	float pool = smoothstep(0.0, 0.06, a) * mix(0.45, 1.0, smoothstep(0.22, 0.32, a));
	DIFFUSE_LIGHT += LIGHT_COLOR * ramp * pool / PI;

	if (v_gloss > 0.0) {
		vec3 h = normalize(VIEW + LIGHT);
		float s = pow(max(dot(NORMAL, h), 0.0), mix(24.0, 1400.0, v_gloss * v_gloss));
		s = smoothstep(0.35, 0.55, s);
		SPECULAR_LIGHT += LIGHT_COLOR * s * pool * v_gloss * 0.5;
	}
}
