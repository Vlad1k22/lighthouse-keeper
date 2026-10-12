shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float night_factor : hint_range(0.0, 1.0) = 0.0;
varying vec3 world_pos;
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(world_pos.x * 0.42 + TIME * 0.7) * 0.065
		+ cos(world_pos.z * 0.5 + TIME * 0.6) * 0.04;
}
void fragment() {
	float depth = clamp(length(world_pos.xz / vec2(22.0, 18.2)) - 0.9, 0.0, 1.0);
	vec3 shallow = mix(vec3(0.14, 0.29, 0.29), vec3(0.075, 0.18, 0.24), night_factor);
	vec3 deep = mix(vec3(0.04, 0.15, 0.20), vec3(0.025, 0.075, 0.13), night_factor);
	vec3 color = mix(shallow, deep, depth);
	float drift = sin(world_pos.x * 0.16 + world_pos.z * 0.22 + TIME * 0.14) * 2.0
		+ cos(world_pos.z * 0.12 - world_pos.x * 0.08) * 1.5;
	float wave = sin(world_pos.x * 0.9 + world_pos.z * 1.3 + drift + TIME * 0.8);
	float broken = sin(world_pos.x * 0.7 - world_pos.z * 0.5 + sin(world_pos.z * 0.35) * 2.3);
	float glint = smoothstep(0.985, 1.0, wave) * smoothstep(0.65, 0.9, broken);
	color += glint * mix(vec3(0.12, 0.20, 0.20), vec3(0.035, 0.06, 0.08), night_factor);
	ALBEDO = color;
}
