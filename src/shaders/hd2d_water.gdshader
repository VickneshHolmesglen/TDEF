shader_type spatial;
// HD-2D river surface (ADR-0044, spec 2026-11-07-3d-terrain §6.2). One flat
// plane just below ground level; the ground hides it everywhere except the
// sunken river beds. Pixel-stepped ripples drift slowly, matching the ground's
// texel grid; a few glints sparkle. Lit lightly so it sits in the scene.
render_mode blend_mix, depth_draw_opaque, cull_back, specular_disabled;

uniform vec4 water_color : source_color = vec4(0.24, 0.47, 0.62, 0.8);
uniform float z_stretch = 1.0;
uniform float texel_world = 3.0;
uniform float flow_speed = 4.0;

varying vec2 map_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	map_pos = vec2(w.x, w.z / z_stretch);
}

void fragment() {
	vec2 px = floor(map_pos / texel_world);
	float t = floor(TIME * flow_speed);
	float ripple = sin((px.x + t) * 0.35 + sin(px.y * 0.21) * 2.0) * sin((px.y - t * 0.5) * 0.27);
	float band = step(0.55, ripple);
	vec3 col = water_color.rgb * (0.9 + band * 0.22);
	float glint = step(0.997, hash(px + floor(TIME * 2.0)));
	col = mix(col, vec3(0.88, 0.95, 1.0), glint);
	ALBEDO = col;
	ROUGHNESS = 0.4;
	ALPHA = water_color.a;
}
