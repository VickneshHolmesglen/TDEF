shader_type spatial;

// Epic 15 Phase 3 (VFX/shaders -> spatial): spatial port of
// src/shaders/hit_flash.gdshader for the 3D visual companions (ADR-0037).
// Same flash-to-white contract as the canvas_item original and as
// creature_swarm_body.gdshader's identical INSTANCE_CUSTOM.y channel for the
// monster swarm (ADR-0038) -- this is the same VFX language applied to a
// per-instance MeshInstance3D (Tower/Hero) instead of a per-instance
// MultiMesh row (monsters) or a Sprite2D (2D layer). Driven by a Tween
// animating flash_amount 0.0 -> 1.0 -> 0.0, same idiom as the 2D original.
uniform sampler2D albedo_tex : source_color;
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex_color = texture(albedo_tex, UV);
	ALBEDO = mix(tex_color.rgb, vec3(1.0), flash_amount);
	ALPHA = tex_color.a;
}
