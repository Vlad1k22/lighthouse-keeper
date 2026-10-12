shader_type spatial;
render_mode cull_disabled;
uniform vec4 leaf_color : source_color = vec4(0.2, 0.35, 0.25, 1.0);
uniform float sway = 0.07;
void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float weight = clamp(VERTEX.y + 0.7, 0.0, 2.5);
	float wind = sin(world.x * 0.8 + world.z * 0.4 + TIME * 1.1)
		+ sin(world.z * 1.4 + TIME * 1.9) * 0.25;
	VERTEX.x += wind * weight * sway;
	VERTEX.z += wind * weight * sway * 0.35;
}
void fragment() {
	ALBEDO = leaf_color.rgb;
	ROUGHNESS = 0.95;
}
