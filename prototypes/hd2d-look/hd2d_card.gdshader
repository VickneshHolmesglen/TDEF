shader_type spatial;
// HD-2D foliage card (grass tufts, flowers): alpha-scissored pixel texture,
// nearest-filtered, with a wind sway that bends only the top of the card.
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D card_texture : source_color, filter_nearest;
uniform float sway_amount = 3.0;
uniform float sway_speed = 1.6;
uniform vec3 tint : source_color = vec3(1.0);

void vertex() {
	// UV.y = 0 at the top of the card: the tip moves, the root stays planted.
	float bend = 1.0 - UV.y;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = world.x * 0.021 + world.z * 0.017;
	VERTEX.x += sin(TIME * sway_speed + phase) * sway_amount * bend * bend;
	VERTEX.z += cos(TIME * sway_speed * 0.8 + phase) * sway_amount * 0.5 * bend * bend;
	// Light every card as if it faced up, so tufts never go black edge-on.
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	vec4 tex = texture(card_texture, UV);
	ALBEDO = tex.rgb * tint * COLOR.rgb;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
