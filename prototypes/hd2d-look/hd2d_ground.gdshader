shader_type spatial;
// HD-2D painted ground: grass / dirt / flagstone picked per pixel from a
// low-res lane mask (R = dirt, G = stone). The mask lookup is snapped to the
// texture's own pixel grid and jittered by noise, so lane edges come out
// ragged and pixel-stepped instead of smooth or cell-square.

uniform sampler2D grass_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D stone_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D lane_mask : filter_linear, repeat_disable;
uniform vec2 map_size = vec2(1024.0, 768.0);
uniform vec2 map_origin = vec2(0.0);
uniform float texel_world = 3.0;     // world units per texture pixel
uniform float edge_jitter = 0.22;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 px = floor(world_pos.xz / texel_world);
	vec2 snapped = (px + 0.5) * texel_world;
	vec2 uv = snapped / (128.0 * texel_world);
	vec3 grass = texture(grass_tex, uv).rgb;
	vec3 dirt = texture(dirt_tex, uv).rgb;
	vec3 stone = texture(stone_tex, uv * 2.5).rgb;  // smaller slabs than the ground pixel grid
	vec2 muv = (snapped - map_origin) / map_size;
	// Outside the mask: plain grass (repeat_disable alone would smear the edge texels outward).
	float inside = step(0.0, muv.x) * step(muv.x, 1.0) * step(0.0, muv.y) * step(muv.y, 1.0);
	vec4 mask = texture(lane_mask, muv) * inside;
	float n = (hash(px) - 0.5) * edge_jitter;
	float dirt_w = step(0.5, mask.r + n);
	float stone_w = step(0.5, mask.g + n);
	vec3 col = mix(grass, dirt, dirt_w);
	col = mix(col, stone, stone_w);
	// Darker fringe where grass meets dirt: reads as the lip of the worn path.
	float fringe = step(0.38, mask.r + n) * (1.0 - dirt_w);
	col *= 1.0 - fringe * 0.25;
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
