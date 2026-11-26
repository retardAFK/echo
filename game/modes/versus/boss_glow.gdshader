shader_type spatial;
// The boss's glowing cracks (spec S-025, Q8, T-405): drawn over its model
// (material_overlay), orange lines from a cellular pattern, added on top,
// pulsing. BossLook sets strength by phase (stronger in each one).
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform float strength = 0.4;
uniform vec4 glow_color : source_color = vec4(1.0, 0.42, 0.08, 1.0);
uniform float density = 5.0;

varying vec3 local_position;

void vertex() {
	local_position = VERTEX;
}

vec2 cell_point(vec2 cell) {
	vec2 p = vec2(dot(cell, vec2(127.1, 311.7)), dot(cell, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

// Distance to the nearest edge between two cells: 0 on a crack.
float crack_distance(vec2 p) {
	vec2 cell = floor(p);
	vec2 inside = fract(p);
	float first = 8.0;
	float second = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 offset = vec2(float(x), float(y));
			vec2 r = offset + cell_point(cell + offset) - inside;
			float d = dot(r, r);
			if (d < first) {
				second = first;
				first = d;
			} else if (d < second) {
				second = d;
			}
		}
	}
	return sqrt(second) - sqrt(first);
}

void fragment() {
	vec2 p = vec2(local_position.x + local_position.z * 0.7, local_position.y) * density;
	float line = 1.0 - smoothstep(0.03, 0.12, crack_distance(p));
	float pulse = 0.75 + 0.25 * sin(TIME * 3.0 + local_position.y * 2.0);
	ALBEDO = glow_color.rgb * line * strength * pulse * 2.5;
}
