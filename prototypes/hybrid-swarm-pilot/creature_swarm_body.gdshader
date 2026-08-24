shader_type spatial;
render_mode cull_disabled, unshaded, depth_draw_opaque;

// ADR-0038 fixed 4-channel INSTANCE_CUSTOM contract, per-instance:
//   x = atlas frame index (float, exactly representable small integer)
//   y = hit-flash amount, 0.0..1.0
//   z = status/variant bit mask (only bit 0 demonstrated here — 2026-08-24
//       pilot scope, full bit allocation is a later, versioned decision)
//   w = facing (0.0 = right-facing, >=0.5 = left-facing -- flips U)

uniform sampler2D atlas_tex : source_color;
uniform int atlas_cols = 4;
uniform int atlas_rows = 1;

// Confirmed live on the pinned 4.6.2.stable binary (investigation-2026-08-24
// -hybrid-swarm-rendering.md): INSTANCE_CUSTOM is vertex-stage-only. Reading
// it directly in fragment() fails with "Unknown identifier in expression:
// 'INSTANCE_CUSTOM'" -- it must be captured here and passed through a flat
// varying. Do not "simplify" this by reading INSTANCE_CUSTOM in fragment().
varying flat vec4 v_custom;

void vertex() {
	v_custom = INSTANCE_CUSTOM;

	// Camera-facing Y-axis billboard: cancel the view-space rotation on X/Z
	// while preserving the instance's own world position (MODEL_MATRIX[3])
	// and Y-axis (so the quad still stands upright, never tilts toward the
	// camera vertically -- a "vertical billboard," not a full sprite-facing
	// billboard). This is the ADR-0038-flagged open pilot question
	// ("fixed-yaw versus camera-facing billboarding") -- this pilot answers
	// it with camera-facing as the working default; fixed-yaw is a one-line
	// swap (skip this block entirely) if a future pass prefers it.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0],
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]
	);
}

void fragment() {
	float frame = v_custom.x;
	float flash = v_custom.y;
	float status_mask = v_custom.z;
	bool facing_left = v_custom.w >= 0.5;

	int col = int(mod(frame, float(atlas_cols)));
	int row = int(frame / float(atlas_cols));
	vec2 cell = vec2(1.0 / float(atlas_cols), 1.0 / float(atlas_rows));

	vec2 uv = UV;
	if (facing_left) {
		uv.x = 1.0 - uv.x;
	}
	vec2 sample_uv = uv * cell + vec2(float(col), float(row)) * cell;

	vec4 tex = texture(atlas_tex, sample_uv);

	// Hit-flash: mix toward white. Status mask: a cheap magenta tint so bit
	// 0 is visibly, independently distinguishable from flash in the pilot
	// screenshot -- not a real status-effect visual language, just proof
	// the channel round-trips independently of the other three.
	vec3 albedo = tex.rgb;
	albedo = mix(albedo, vec3(1.0), flash);
	if (status_mask > 0.5) {
		albedo = mix(albedo, vec3(1.0, 0.0, 1.0), 0.35);
	}

	ALBEDO = albedo;
	ALPHA = tex.a;
	// Godot 4.x spatial shaders: alpha scissor is a fragment-stage output
	// assignment (ALPHA_SCISSOR_THRESHOLD), not a render_mode directive with
	// parameters -- `render_mode alpha_scissor_threshold(0.5)` is invalid
	// syntax and fails shader compilation outright (confirmed live on this
	// pinned 4.6.2.stable binary: "Invalid render mode:
	// 'alpha_scissor_threshold'"). This is the correct form.
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
