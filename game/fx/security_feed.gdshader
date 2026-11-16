shader_type canvas_item;
// What a security camera shows (spec S-018, Q11): the scene seen from its
// lens, coarse, green and brightened like an old night camera, with lines
// and a little snow. It reads the screen: the scene is never drawn twice.

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
// Pixels of the screen per pixel of the camera.
uniform float block = 3.0;
uniform float gain = 2.6;
uniform float snow = 0.08;
uniform float time_seed = 0.0;

float noise(vec2 pixel) {
	return fract(sin(dot(pixel + time_seed, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 cell = floor(FRAGCOORD.xy / block) * block + block * 0.5;
	vec3 color = texture(screen_texture, cell / size).rgb;
	float light = dot(color, vec3(0.3, 0.59, 0.11)) * gain;
	light += (noise(floor(FRAGCOORD.xy / block)) - 0.5) * snow;
	light *= 0.85 + 0.15 * step(1.0, mod(FRAGCOORD.y, 3.0));
	light = clamp(light, 0.0, 1.0);
	COLOR = vec4(light * 0.45, 0.08 + light * 0.95, light * 0.4, 1.0);
}
