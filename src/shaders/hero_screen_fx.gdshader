shader_type canvas_item;

// Wind-up presentation spec §5.2/§5.3: one full-screen pass for the low-HP dark-red vignette and
// the death desaturation. Both uniforms at 0 is the identity (the rect is hidden in that state).
uniform sampler2D screen_tex : hint_screen_texture, filtering_linear, repeat_disable;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.0;
uniform float desaturate : hint_range(0.0, 1.0) = 0.0;
uniform float inset : hint_range(0.01, 0.5) = 0.15;

void fragment() {
	vec4 base = textureLod(screen_tex, SCREEN_UV, 0.0);
	float lum = dot(base.rgb, vec3(0.299, 0.587, 0.114));
	vec3 col = mix(base.rgb, vec3(lum), desaturate);
	vec2 d = min(UV, 1.0 - UV);
	float edge = 1.0 - smoothstep(0.0, inset, min(d.x, d.y));
	col = mix(col, vec3(0.45, 0.02, 0.02), edge * vignette_strength);
	COLOR = vec4(col, 1.0);
}
