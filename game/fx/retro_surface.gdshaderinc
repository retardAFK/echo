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
// Unshaded sources (the sign) glow with their color instead of being lit.
uniform bool unshaded = false;

// Building scan look (T-032), set every frame by ScanLook through RetroSurface.
// scan_amount fades from 0 (no scan) to 1 (scan running).
uniform float scan_amount = 0.0;
// Center of the building box, world to box rotation, and half the box size.
uniform vec3 scan_center = vec3(0.0);
uniform mat3 scan_rotation = mat3(1.0);
uniform vec3 scan_half = vec3(0.0);
uniform float scan_dim = 0.0;
uniform float scan_desaturation = 0.0;
uniform vec3 scan_edge_color : source_color = vec3(0.0);
uniform float scan_edge_width = 0.0;
// Radius of the pale wave around the building, in meters, and its thickness.
uniform float scan_wave_radius = 0.0;
uniform float scan_wave_width = 0.0;
uniform float scan_wave_fade = 0.0;

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

vec3 desaturate(vec3 color, float amount) {
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	return mix(color, vec3(luma), amount);
}

void fragment() {
	vec2 uv = world_triplanar ? triplanar_uv(world_pos * uv_scale, world_normal) : UV * uv_scale.xy;
	vec3 albedo = texture(albedo_texture, uv).rgb * albedo_color.rgb;
	vec3 emission = texture(emission_texture, UV).rgb * emission_color;
	if (unshaded) {
		emission = albedo;
		albedo = vec3(0.0);
	}
	if (scan_amount > 0.0) {
		vec3 local = scan_rotation * (world_pos - scan_center);
		vec3 inner = scan_half - abs(local);
		if (min(inner.x, min(inner.y, inner.z)) < 0.0) {
			// Outside the scanned building: darker and greyer.
			float keep = 1.0 - scan_dim * scan_amount;
			albedo = desaturate(albedo, scan_desaturation * scan_amount) * keep;
			emission = desaturate(emission, scan_desaturation * scan_amount) * keep;
			float away = length(max(abs(local) - scan_half, vec3(0.0)));
			float ring = 1.0 - smoothstep(0.0, scan_wave_width, abs(away - scan_wave_radius));
			emission += scan_edge_color * ring * scan_wave_fade * scan_amount;
		} else {
			// Inside: the box edges light up where two faces meet.
			vec3 near_face = step(inner, vec3(scan_edge_width));
			if (near_face.x + near_face.y + near_face.z >= 2.0) {
				emission += scan_edge_color * scan_amount;
			}
		}
	}
	ALBEDO = albedo;
	ROUGHNESS = roughness;
	EMISSION = emission;
}
