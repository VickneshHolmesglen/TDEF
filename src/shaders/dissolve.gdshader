shader_type canvas_item;

// Animation Pipeline (design/art/animation-pipeline.md §5). Threshold/noise
// dissolve-out, used by monster_death_vfx.gd's dissolve sprite. Procedural
// hash noise (no external noise texture dependency) so this stays a single
// self-contained file. Driven by a Tween animating dissolve_amount 0.0 -> 1.0
// over the death VFX's duration.
uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.6, 0.2, 1.0);
uniform float edge_width : hint_range(0.0, 0.2) = 0.05;
// Noise grid in blocks across the sprite. Match it to the sprite's own art
// pixels (HD-2D pass) so it breaks apart pixel by pixel.
uniform vec2 cells = vec2(64.0, 64.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	float noise = hash(floor(UV * cells));
	float edge = step(dissolve_amount, noise);
	float past_edge = step(dissolve_amount + edge_width, noise);
	vec3 final_rgb = mix(edge_color.rgb, tex_color.rgb, past_edge);
	COLOR = vec4(final_rgb, tex_color.a * edge);
}
