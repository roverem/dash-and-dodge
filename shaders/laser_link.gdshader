shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_opaque;

uniform vec4 laser_color : source_color = vec4(0.55, 1.0, 1.0, 1.0);
uniform float link_strength : hint_range(0.0, 1.0) = 1.0;
uniform float scroll_speed = 8.0;
uniform float band_count = 10.0;

varying float v_along;
varying float v_radial;

void vertex() {
	// CylinderMesh local space: Y = length, XZ = radius.
	v_along = VERTEX.y + 0.5;
	v_radial = 1.0 - clamp(length(VERTEX.xz) * 2.0, 0.0, 1.0);
}

void fragment() {
	float band = fract(v_along * band_count - TIME * scroll_speed);
	float pulse = 0.65 + 0.35 * step(0.35, band) * (1.0 - step(0.75, band));
	float body = mix(0.35, 1.0, v_radial);
	float intensity = body * pulse * mix(0.25, 1.0, link_strength);

	// Compatibility-friendly: put brightness in ALBEDO for blend_add.
	ALBEDO = laser_color.rgb * intensity * 2.5;
}
