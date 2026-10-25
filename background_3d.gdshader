shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 color_a : source_color = vec4(0.04, 0.02, 0.10, 1.0);
uniform vec4 color_b : source_color = vec4(0.08, 0.42, 0.82, 1.0);
uniform vec4 color_c : source_color = vec4(0.92, 0.28, 0.62, 1.0);
uniform float speed : hint_range(0.0, 2.0) = 0.28;
uniform float noise_scale : hint_range(0.5, 8.0) = 2.6;
uniform float contrast : hint_range(0.5, 3.0) = 1.45;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	vec2 p = uv * noise_scale;
	float t = TIME * speed;
	float n1 = fbm(p + vec2(t * 0.4, t * 0.15));
	float n2 = fbm(p * 1.7 - vec2(t * 0.22, -t * 0.35) + n1 * 1.5);
	float n3 = fbm(p * 0.55 + vec2(-t * 0.12, t * 0.28));
	float swirl = n2 * 0.68 + n3 * 0.32;
	vec3 col = mix(color_a.rgb, color_b.rgb, smoothstep(0.22, 0.78, n1));
	col = mix(col, color_c.rgb, pow(clamp(swirl, 0.0, 1.0), contrast));
	float stars = step(0.987, noise(uv * 190.0 + t * 0.03));
	col += vec3(0.9, 0.95, 1.0) * stars * 0.9;
	float vignette = smoothstep(1.15, 0.32, length(uv - 0.5) * 1.45);
	col *= vignette;
	ALBEDO = col;
	EMISSION = col;
}
