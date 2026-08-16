shader_type canvas_item;

// Animation Pipeline (design/art/animation-pipeline.md §5). Drives a flash-
// to-white pulse on a Sprite2D, matching TowerInstance.play_attack_punch()'s
// existing modulate-flash idiom but through a shader parameter for a cleaner
// full-white flash than tinting modulate toward an element color allows.
// Driven by a Tween animating flash_amount 0.0 -> 1.0 -> 0.0 on hit.
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	COLOR = vec4(mix(tex_color.rgb, vec3(1.0), flash_amount), tex_color.a);
}
