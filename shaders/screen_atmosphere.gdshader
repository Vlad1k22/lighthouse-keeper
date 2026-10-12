shader_type canvas_item;
uniform float night = 0.0;
uniform float stress = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float edge = smoothstep(0.35, 1.45, length(p * vec2(0.85, 1.0)));
	float pulse = 0.5 + sin(TIME * 2.3) * 0.5;
	vec3 color = mix(vec3(0.025, 0.07, 0.08), vec3(0.22, 0.06, 0.08), stress * 0.65);
	COLOR = vec4(color, edge * (0.14 + night * 0.1 + stress * pulse * 0.2));
}
