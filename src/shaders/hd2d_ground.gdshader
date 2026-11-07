shader_type spatial;
// HD-2D painted ground (ADR-0042). Grass / dirt / flagstone picked per pixel
// from a low-res lane mask (R = dirt, G = flagstone). Lookups happen in 2D
// map space (world z divided by z_stretch, see Hd2dScenery.to_world), snapped
// to a texel_world pixel grid and noise-jittered, so lane edges come out
// ragged and pixel-stepped. Unshaded-free: lit by the scenery's own sun.

uniform sampler2D grass_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D stone_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D lane_mask : filter_linear, repeat_disable;
uniform vec2 mask_origin = vec2(0.0);   // 2D map position of the mask's top-left
uniform vec2 mask_size = vec2(1024.0, 768.0);
uniform float z_stretch = 1.0;
uniform float texel_world = 3.0;        // 2D map px per texture pixel
uniform float stone_scale = 2.5;        // flagstone slabs smaller than the ground pixel grid
uniform float edge_jitter = 0.22;
uniform float lane_shimmer = 0.0;
// Terrain (ADR-0044): tint by surface height and show stone on steep slopes.
// Defaults are no-ops, so flat maps render exactly as before.
uniform sampler2D height_tint : source_color, filter_linear, repeat_disable, hint_default_white;
uniform float height_max = 0.0;          // 0 = no height tint
uniform float rock_slope = 0.0;          // world normal.y below this shows stone; 0 = never
uniform float slope_shade = 0.0;         // darkening on slopes (terrain only)
uniform float level_height = 0.0;        // 2D px per height level; > 0 draws contour rims
uniform float contour_strength = 0.0;    // darkening of the rim at each level's edge
uniform float lane_scale = 1.0;        // > 1 = smaller lane texture features (cobbles)      // > 0: scroll + sparkle the lane (river)

varying vec2 map_pos;
varying float world_y;
varying float world_up;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	map_pos = vec2(w.x, w.z / z_stretch);
	world_y = w.y;
	world_up = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
}

void fragment() {
	vec2 px = floor(map_pos / texel_world);
	vec2 snapped = (px + 0.5) * texel_world;
	vec2 uv = snapped / (128.0 * texel_world);
	vec3 grass = texture(grass_tex, uv).rgb;
	// River lanes flow: offset in whole texture pixels so the scroll stays pixel-stepped.
	vec2 flow = floor(vec2(TIME * 6.0, TIME * 2.0) * lane_shimmer) / 128.0;
	vec3 dirt = texture(dirt_tex, uv * lane_scale + flow).rgb;
	float glint = step(0.9985, hash(px + floor(TIME * 3.0))) * step(0.001, lane_shimmer);
	dirt = mix(dirt, vec3(0.86, 0.93, 0.96), glint);
	vec3 stone = texture(stone_tex, uv * stone_scale).rgb;
	vec2 muv = (snapped - mask_origin) / mask_size;
	// Outside the mask: plain grass (repeat_disable alone would smear the edge texels outward).
	float inside = step(0.0, muv.x) * step(muv.x, 1.0) * step(0.0, muv.y) * step(muv.y, 1.0);
	vec4 mask = texture(lane_mask, muv) * inside;
	float n = (hash(px) - 0.5) * edge_jitter;
	float dirt_w = step(0.5, mask.r + n);
	float stone_w = step(0.5, mask.g + n);
	vec3 col = mix(grass, dirt, dirt_w);
	col = mix(col, stone, stone_w);
	// Darker fringe where grass meets dirt: the lip of the worn path.
	float fringe = step(0.38, mask.r + n) * (1.0 - dirt_w);
	col *= 1.0 - fringe * 0.25;
	if (height_max > 0.0) {
		float t = clamp(world_y / height_max, 0.0, 1.0);
		col *= texture(height_tint, vec2(t, 0.5)).rgb;
		// Shade the slopes so every hill reads as a raised shape at a glance.
		col *= 1.0 - slope_shade * (1.0 - smoothstep(0.88, 0.995, world_up));
		// A thin rim where the ground crosses each level's mid-height: the
		// outline of every hill's buildable top (spec 2026-11-07-3d-terrain §6.1).
		if (level_height > 0.0) {
			float lv = world_y / level_height - 0.5;
			float d = abs(lv - round(lv)) * level_height;
			float rim = (1.0 - step(fwidth(world_y) * 1.2 + 0.4, d)) * step(0.0, lv + 0.25);
			col *= 1.0 - contour_strength * rim;
		}
	}
	// Pixel-stepped rock on steep slopes, with the same ragged edge jitter.
	float rock_w = step(world_up + n * 0.3, rock_slope) * (1.0 - dirt_w);
	col = mix(col, stone * 0.85, rock_w);
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
