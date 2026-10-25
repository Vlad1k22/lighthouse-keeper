shader_type canvas_item;
uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_linear;
uniform float night = 0.0;
uniform float stress = 0.0;
void fragment() {
	// Этот слой рисуется до интерфейса: цветокоррекция затрагивает только мир.
	vec3 scene = texture(scene_color, SCREEN_UV).rgb;
	float luminance = dot(scene, vec3(0.2126, 0.7152, 0.0722));
	float highlight = smoothstep(0.48, 0.88, luminance);
	vec3 graded = mix(vec3(luminance), scene, mix(0.70, 0.60, night));
	// Холодные тени; янтарные окна и фонари сохраняют свой цвет.
	graded *= mix(vec3(0.82, 0.94, 1.02), vec3(1.05, 1.01, 0.94), highlight);
	graded = max(vec3(0.0), (graded - 0.16) * 1.08 + 0.16);
	vec2 p = UV * 2.0 - 1.0;
	float edge = smoothstep(0.35, 1.45, length(p * vec2(0.85, 1.0)));
	float pulse = 0.5 + sin(TIME * 2.3) * 0.5;
	vec3 color = mix(vec3(0.025, 0.07, 0.08), vec3(0.22, 0.06, 0.08), stress * 0.65);
	graded = mix(graded, color, edge * (0.12 + night * 0.14 + stress * pulse * 0.18));
	float grain = fract(sin(dot(floor(FRAGCOORD.xy), vec2(12.9898, 78.233)) + floor(TIME * 12.0)) * 43758.5453) - 0.5;
	COLOR = vec4(clamp(graded + grain * 0.002, vec3(0.0), vec3(1.0)), 1.0);
}
