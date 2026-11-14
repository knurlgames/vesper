// (outline.gdshader with a hole box, for BuiltWorld.props holes: a building front's doorway.)
// Ink outlines by inverted hull (ART_DIRECTION.md "Rendering"): the mesh again, pushed out along its normals, back
// faces only, flat ink. The line thickens toward the bottom of the shape. Used as a GeometryInstance3D's
// material_overlay (Look.outline), with `base` and `height` set from the mesh's bounds.
// Smooth-shaded meshes only: hard edges split their normals and the hull cracks at the corners.
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

uniform vec4 ink : source_color = vec4(0.05, 0.03, 0.08, 1.0);
// Line width in metres at the top of the shape.
uniform float width = 0.012;
// How much thicker it is at the bottom.
uniform float bottom_boost = 1.8;
uniform float base = 0.0;
uniform float height = 1.0;
// A box (world space) where nothing's drawn: a building front's doorway (BuiltWorld.props holes). Empty by default.
uniform vec3 hole_min = vec3(0.0);
uniform vec3 hole_max = vec3(0.0);
varying vec3 v_world;

void vertex() {
	float t = clamp((VERTEX.y - base) / max(height, 0.01), 0.0, 1.0);
	VERTEX += normalize(NORMAL) * width * mix(bottom_boost, 1.0, t);
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (all(greaterThan(v_world, hole_min)) && all(lessThan(v_world, hole_max))) {
		discard;
	}
	ALBEDO = ink.rgb;
}
