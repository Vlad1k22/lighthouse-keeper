shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform float apparition : hint_range(0.0, 1.0) = 0.0;
uniform float drift = 0.0;

void fragment() {
	vec2 p = UV - vec2(.40 + drift, .35);
	float head = length(p / vec2(.115, .185));
	float shoulders = length((p - vec2(.017, .44)) / vec2(.28, .32));
	float neck = length((p - vec2(.008, .24)) / vec2(.086, .18));
	float shape = 1.0 - smoothstep(.88, 1.09, min(head, min(shoulders, neck)));
	float frost = .90 + .09 * fract(sin(dot(floor(UV * 86.0), vec2(17.3, 51.8))) * 12653.74);
	ALBEDO = vec3(.016, .025, .032);
	ALPHA = apparition * shape * frost;
}
