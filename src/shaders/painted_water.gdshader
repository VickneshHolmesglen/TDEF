shader_type spatial;
// Painted-vector river (spec 2026-11-08-painted-vector-style-design §2): flat
// blue with drifting painted ripple strokes and a few pale glints.
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back;

uniform vec4 water_color : source_color = vec4(0.25, 0.62, 0.85, 0.9);
uniform vec3 stroke_color : source_color = vec3(0.75, 0.92, 0.98);
uniform float z_stretch = 1.0;
uniform float flow_speed = 6.0;

varying vec2 map_pos;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	map_pos = vec2(w.x, w.z / z_stretch);
}

void fragment() {
	vec2 p = map_pos;
	float wob = sin(p.x * 0.05 + TIME * 0.6) * 6.0;
	float band = sin((p.y + wob + TIME * flow_speed) * 0.16 + sin(p.x * 0.03) * 2.0);
	float stroke = smoothstep(0.93, 0.985, band) * smoothstep(0.3, 0.7, sin(p.x * 0.09 + p.y * 0.02));
	vec3 col = mix(water_color.rgb, stroke_color, stroke * 0.6);
	col *= 0.94 + 0.06 * sin(p.x * 0.013 + p.y * 0.011);
	ALBEDO = col;
	ALPHA = water_color.a;
}
