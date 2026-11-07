shader_type spatial;
// Painted-vector ground (spec 2026-11-08-painted-vector-style-design §2).
// Flat colour tiers by height (lighter per level, a soft gradient inside each),
// a thin rim at each level's mid-height, a darker cool side band on slopes
// facing the camera, warm low-frequency patches and faint directional brush
// grain. The lane mask (R = path, G = flagstone) is the HD-2D one. Light is
// banded (a few smooth tones) in light(). No pixel snapping.
render_mode specular_disabled;

uniform sampler2D lane_mask : filter_linear, repeat_disable;
uniform vec2 mask_origin = vec2(0.0);
uniform vec2 mask_size = vec2(1024.0, 768.0);
uniform float z_stretch = 1.0;
uniform vec3 tier_low : source_color = vec3(0.37, 0.62, 0.27);
uniform vec3 tier_high : source_color = vec3(0.86, 0.95, 0.6);
uniform vec3 side_shade : source_color = vec3(0.70, 0.76, 0.86);
uniform vec3 lane_color : source_color = vec3(0.94, 0.81, 0.56);
uniform vec3 stone_color : source_color = vec3(0.82, 0.80, 0.74);
uniform vec3 patch_tint : source_color = vec3(1.0, 1.0, 0.85);
uniform float level_height = 32.0;   // 2D px per height level
uniform float max_level = 2.0;
uniform float rim_strength = 0.3;
uniform float grain = 0.1;
uniform float patch_strength = 0.35;

varying vec2 map_pos;
varying float world_y;
varying float world_front;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	map_pos = vec2(w.x, w.z / z_stretch);
	world_y = w.y;
	world_front = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).z;
}

void fragment() {
	// Height tiers: a band per level with a soft painted gradient inside it.
	float lv = max(world_y, 0.0) / level_height;
	float tier = floor(lv + 0.5);
	float inside = clamp(lv - tier + 0.5, 0.0, 1.0);
	float t = clamp((tier + inside * 0.45) / (max_level + 0.45), 0.0, 1.0);
	vec3 col = mix(tier_low, tier_high, t);
	// Warm low-frequency patches.
	float pn = vnoise(map_pos / 150.0);
	col *= mix(vec3(1.0), patch_tint, smoothstep(0.45, 0.7, pn) * patch_strength);
	// Side band: slopes turned toward the camera are darker and cooler.
	col *= mix(vec3(1.0), side_shade, smoothstep(0.02, 0.3, world_front));
	// Rim at each level's mid-height (the outline of every buildable top).
	float d = abs(fract(lv) - 0.5) * level_height;
	float rim = (1.0 - smoothstep(fwidth(world_y) * 1.0 + 0.3, fwidth(world_y) * 1.0 + 0.9, d)) * step(0.25, lv);
	col *= 1.0 - rim_strength * rim;
	// Lane and flagstones.
	vec2 muv = (map_pos - mask_origin) / mask_size;
	float inside_mask = step(0.0, muv.x) * step(muv.x, 1.0) * step(0.0, muv.y) * step(muv.y, 1.0);
	vec4 mask = texture(lane_mask, muv) * inside_mask;
	float lane_w = smoothstep(0.42, 0.58, mask.r);
	float lip = smoothstep(0.3, 0.45, mask.r) * (1.0 - lane_w);
	col *= 1.0 - lip * 0.22;
	col = mix(col, lane_color * (0.96 + 0.08 * vnoise(map_pos / 40.0)), lane_w);
	col = mix(col, stone_color, smoothstep(0.42, 0.58, mask.g));
	// Directional brush grain.
	float g = vnoise(map_pos * vec2(0.08, 0.32)) * 0.6 + vnoise(map_pos * vec2(0.21, 0.7)) * 0.4;
	col *= 1.0 + (g - 0.5) * 2.0 * grain;
	ALBEDO = col;
	ROUGHNESS = 1.0;
}

void light() {
	float d = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	if (LIGHT_IS_DIRECTIONAL) {
		// The sun paints in a few soft bands.
		float bands = 0.42 + smoothstep(0.05, 0.2, d) * 0.3 + smoothstep(0.45, 0.6, d) * 0.28;
		DIFFUSE_LIGHT += bands * LIGHT_COLOR / PI;
	} else {
		// Point lights (campfires) stay smooth: banding their falloff draws hard steps.
		DIFFUSE_LIGHT += d * LIGHT_COLOR / PI;
	}
}
