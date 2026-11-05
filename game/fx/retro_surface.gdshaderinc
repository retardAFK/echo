// Shared retro surface (spec S-005, T-031): vertices snapped to a screen grid
// (the PS1 wobble), nearest textures, world triplanar mapping for the greybox.
// Every value comes from uniforms set by RetroSurface from visual_settings.tres.

uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_enable, hint_default_white;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D emission_texture : source_color, filter_nearest, repeat_enable, hint_default_white;
uniform vec3 emission_color : source_color = vec3(0.0);
uniform float roughness = 1.0;
uniform bool world_triplanar = false;
uniform vec3 uv_scale = vec3(1.0);
// Screen grid the vertices snap to; 0 turns the wobble off.
uniform vec2 snap_grid = vec2(0.0);

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (snap_grid.x > 0.0 && clip.w > 0.0) {
		// Clip space spans 2 units across the screen, hence the half grid.
		vec2 half_grid = snap_grid / 2.0;
		clip.xy = round(clip.xy / clip.w * half_grid) / half_grid * clip.w;
	}
	POSITION = clip;
}

// Projects on the plane facing the dominant normal axis, without blending,
// so the pixels stay sharp on box corners.
vec2 triplanar_uv(vec3 p, vec3 n) {
	vec3 a = abs(n);
	if (a.x >= a.y && a.x >= a.z) {
		return p.zy;
	}
	if (a.y >= a.z) {
		return p.xz;
	}
	return p.xy;
}

void fragment() {
	vec2 uv = world_triplanar ? triplanar_uv(world_pos * uv_scale, world_normal) : UV * uv_scale.xy;
	ALBEDO = texture(albedo_texture, uv).rgb * albedo_color.rgb;
	ROUGHNESS = roughness;
	EMISSION = texture(emission_texture, UV).rgb * emission_color;
}
