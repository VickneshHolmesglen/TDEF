shader_type spatial;
// Painted-vector towers (ADR-0045): the tower's own texture, brightened and a
// little more saturated, under the same soft banded sun light as the painted
// scenery, so 3D towers sit in the painted world without losing their detail.
render_mode specular_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float brighten = 1.18;
uniform float saturation = 1.2;
// Glowing parts (crystals, fires) keep their emission from the source material.
uniform vec3 emission_color : source_color = vec3(0.0);
uniform float emission_energy = 0.0;
uniform sampler2D emission_tex : source_color, filter_linear_mipmap, hint_default_white;

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb * albedo_color.rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation) * brighten;
	ALBEDO = c;
	ROUGHNESS = 1.0;
	EMISSION = emission_color * texture(emission_tex, UV).rgb * emission_energy;
}

void light() {
	float d = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	if (LIGHT_IS_DIRECTIONAL) {
		float bands = 0.48 + smoothstep(0.05, 0.2, d) * 0.28 + smoothstep(0.5, 0.65, d) * 0.24;
		DIFFUSE_LIGHT += bands * LIGHT_COLOR / PI;
	} else {
		DIFFUSE_LIGHT += d * LIGHT_COLOR / PI;
	}
}
