// First-person arms and weapons (spec S-024, Q18, Q19, Q22, T-372): vertex
// colours, a little light of their own so they read at night, and a depth
// squashed next to the near plane so they are always drawn in front of the
// scene (no second camera, no SubViewport: no extra draw call).
shader_type spatial;
render_mode cull_back, shadows_disabled;

// Share of the real depth kept: 0 = all on the near plane (Godot 4.3+ draws
// with a reversed depth, the near plane at z = w, in every renderer).
uniform float depth_keep = 0.05;
// Light of their own, added to the scene's.
uniform float self_light = 0.45;
// Flash when a hit lands or is taken (0 to 1).
uniform vec3 flash_color = vec3(1.0, 1.0, 1.0);
uniform float flash = 0.0;

void vertex() {
	POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	POSITION.z = mix(POSITION.w, POSITION.z, depth_keep);
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.85;
	EMISSION = COLOR.rgb * self_light + flash_color * flash;
}
