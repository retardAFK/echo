shader_type canvas_item;
// Screen filter (spec S-005, T-031): fewer colors, ordered 4 x 4 dithering in
// the gradients and a film grain. Values come from visual_settings.tres.

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float color_levels = 24.0;
uniform float dither_strength = 0.6;
uniform float grain_strength = 0.03;
// Changes a few times per second, so the grain looks like film, not snow.
uniform float grain_seed = 0.0;

// Classic 4 x 4 Bayer matrix, thresholds from 0 to 15.
const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float bayer(vec2 pixel) {
	int x = int(mod(pixel.x, 4.0));
	int y = int(mod(pixel.y, 4.0));
	return BAYER[x + y * 4] / 16.0 - 0.5;
}

float noise(vec2 pixel) {
	return fract(sin(dot(pixel + grain_seed, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 color = texture(screen_texture, SCREEN_UV).rgb;
	color += (noise(FRAGCOORD.xy) - 0.5) * grain_strength;
	color += bayer(FRAGCOORD.xy) * dither_strength / color_levels;
	color = floor(color * color_levels + 0.5) / color_levels;
	COLOR = vec4(color, 1.0);
}
