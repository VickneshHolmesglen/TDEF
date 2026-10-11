shader_type spatial;
// HD-2D foliage card (ADR-0042): grass tufts, flowers, shrubs. Alpha-scissored
// nearest-filtered pixel texture; wind sway bends only the top of the card;
// normals forced up so crossed cards never go black when seen edge-on.
// Per-instance tint comes from MultiMesh instance colour (COLOR).
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D card_texture : source_color, filter_nearest;
uniform float sway_amount = 3.0;
uniform float sway_speed = 1.6;

void vertex() {
	// UV.y = 0 at the top of the card: the tip moves, the root stays planted.
	float bend = 1.0 - UV.y;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = world.x * 0.021 + world.z * 0.017;
	VERTEX.x += sin(TIME * sway_speed + phase) * sway_amount * bend * bend;
	VERTEX.z += cos(TIME * sway_speed * 0.8 + phase) * sway_amount * 0.5 * bend * bend;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	vec4 tex = texture(card_texture, UV);
	ALBEDO = tex.rgb * COLOR.rgb;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
