shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float night_factor : hint_range(0.0, 1.0) = 0.0;
uniform float rain_amount : hint_range(0.0, 1.0) = 0.0;
varying vec3 world_pos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x),
		mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(world_pos.x * 0.42 + TIME * 0.7) * 0.065
		+ cos(world_pos.z * 0.5 + TIME * 0.6) * 0.04;
}
void fragment() {
	vec2 p = world_pos.xz;
	float angle = atan(p.y, p.x);
	float coast = length(p / vec2(21.5, 17.5)) / (1.0 + 0.045 * sin(angle * 5.0) + 0.035 * cos(angle * 7.0));
	float depth = smoothstep(0.94, 1.85, coast);
	vec3 shallow = mix(vec3(0.09, 0.15, 0.14), vec3(0.035, 0.07, 0.085), night_factor);
	vec3 deep = mix(vec3(0.018, 0.045, 0.06), vec3(0.009, 0.018, 0.03), night_factor);
	float swell = noise(p * 0.18 + vec2(TIME * 0.025, -TIME * 0.014));
	vec3 color = mix(shallow, deep, depth) + (swell - 0.5) * 0.035;
	float ribbon = sin(coast * 93.0 - TIME * 1.1 + noise(p * 0.5) * 3.5);
	float foam = smoothstep(0.82, 0.99, ribbon) * (1.0 - smoothstep(1.02, 1.19, coast)) * smoothstep(0.98, 1.015, coast);
	color = mix(color, mix(vec3(0.22, 0.28, 0.25), vec3(0.10, 0.16, 0.18), night_factor), foam * 0.65);
	float ripple = sin(p.x * 0.7 + p.y * 1.2 + swell * 8.0 + TIME * 0.75);
	float glint = smoothstep(0.989, 1.0, ripple) * smoothstep(0.55, 0.8, noise(p * 0.6));
	color += glint * mix(vec3(0.045, 0.07, 0.065), vec3(0.015, 0.025, 0.04), night_factor);
	float rain = pow(max(0.0, sin(p.x * 18.0 + p.y * 13.0 + TIME * 11.0)), 40.0) * noise(p * 4.0 + TIME);
	ALBEDO = color + rain * rain_amount * 0.018;
}
