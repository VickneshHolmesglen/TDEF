shader_type spatial;
// Painted-vector props (spec 2026-11-08-painted-vector-style-design §2): a flat
// fill with a soft vertical gradient (bottom -> top over grad_height local
// units), tinted by the vertex / MultiMesh instance colour, lit in soft bands.
render_mode specular_disabled;

uniform vec3 top_color : source_color = vec3(0.6, 0.85, 0.42);
uniform vec3 bottom_color : source_color = vec3(0.25, 0.55, 0.28);
uniform float grad_bottom = 0.0;
uniform float grad_height = 60.0;
// true: the gradient runs over world height above the node's origin (kit props
// of any mesh scale); false: over local mesh height (MultiMesh instances).
uniform bool world_gradient = false;

varying float h01;
varying vec3 tint;

void vertex() {
	float y = world_gradient ? (MODEL_MATRIX * vec4(VERTEX, 1.0)).y - NODE_POSITION_WORLD.y : VERTEX.y;
	h01 = clamp((y - grad_bottom) / grad_height, 0.0, 1.0);
	tint = COLOR.rgb;
}

void fragment() {
	ALBEDO = mix(bottom_color, top_color, h01) * tint;
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
