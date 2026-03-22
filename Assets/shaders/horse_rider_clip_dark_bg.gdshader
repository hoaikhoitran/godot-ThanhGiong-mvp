shader_type canvas_item;

/// Removes opaque sheet background / gray halos from horse_rider PNGs (bad alpha in file).
/// Tier 1: very low saturation (near-gray). Tier 2: medium-sat "halo" rings (mid mx, mid luma).

uniform float black_cutoff : hint_range(0.0, 0.25) = 0.1;
uniform float edge_softness : hint_range(0.0, 0.12) = 0.04;
uniform float flat_sat_max : hint_range(0.0, 0.2) = 0.1;
uniform float flat_mx_max : hint_range(0.0, 0.55) = 0.48;
uniform float flat_luma_max : hint_range(0.0, 0.55) = 0.4;
uniform float halo_sat_min : hint_range(0.0, 0.25) = 0.07;
uniform float halo_sat_max : hint_range(0.0, 0.35) = 0.2;
uniform float halo_mx_min : hint_range(0.0, 0.45) = 0.2;
uniform float halo_mx_max : hint_range(0.0, 0.6) = 0.48;
uniform float halo_luma_max : hint_range(0.0, 0.5) = 0.37;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float r = c.r;
	float g = c.g;
	float b = c.b;
	float mx = max(max(r, g), b);
	float mn = min(min(r, g), b);
	float sat = (mx - mn) / max(mx, 1e-4);
	float luma = dot(vec3(r, g, b), vec3(0.299, 0.587, 0.114));

	float a = c.a;

	// Near-black outside silhouette
	float keep_dark = smoothstep(black_cutoff - edge_softness, black_cutoff + edge_softness, mx);
	a *= keep_dark;

	// Flat gray sheet (very low saturation); avoid name "flat" (GLSL reserved).
	float flat_sheet = (1.0 - step(flat_sat_max, sat)) * (1.0 - step(flat_mx_max, mx)) * (1.0 - step(flat_luma_max, luma));

	// Mid-gray halos: slightly more saturation but still muted, mid brightness
	float halo = step(halo_sat_min, sat) * (1.0 - step(halo_sat_max, sat));
	halo *= step(halo_mx_min, mx) * (1.0 - step(halo_mx_max, mx)) * (1.0 - step(halo_luma_max, luma));

	a *= (1.0 - max(flat_sheet, halo));

	COLOR = vec4(c.rgb, a);
}
