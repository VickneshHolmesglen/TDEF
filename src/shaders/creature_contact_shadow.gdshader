shader_type spatial;
render_mode cull_disabled, unshaded, blend_mix, depth_draw_never;

// Flat, grounded, unlit shadow-blob quad -- deliberately NOT relying on
// real-time shadow-casting from the body billboard (docs/architecture/
// investigation-2026-08-24-hybrid-swarm-rendering.md §5: a camera-facing
// billboard's own cast shadow is shaped by its fixed camera-facing
// orientation relative to the light, not the creature's actual silhouette
// from the light's point of view -- it reads as a smear, not a contact
// shadow). This quad is world-grounded (horizontal, not billboarded) and
// fades by a soft radial falloff baked into its own alpha, driven only by a
// shared opacity uniform -- no per-instance shader logic needed.

uniform float shadow_opacity : hint_range(0.0, 1.0) = 0.45;

void vertex() {
	// No billboarding at all -- the shadow batch's own per-instance
	// transform (set by MonsterSwarmBatch, horizontal orientation baked in)
	// is used as-is. This is what ADR-0038's "body and shadow transforms may
	// differ in orientation" means in practice.
}

void fragment() {
	// Soft radial falloff from quad center (UV 0.5,0.5) outward, so the
	// blob doesn't read as a hard-edged rectangle.
	float dist = distance(UV, vec2(0.5));
	float falloff = clamp(1.0 - dist * 2.0, 0.0, 1.0);
	ALBEDO = vec3(0.0);
	ALPHA = falloff * shadow_opacity;
}
