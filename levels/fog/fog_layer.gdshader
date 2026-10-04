// Vision fog (US-011a; GDD §6.5, §14): a one-texel-per-tile data texture, tinted over the screen.
// Data: R unknown, G memory, B ambient weight, A dark scan. Transition happens here: d = mix(prev, next, blend_t)
// (FogLayer advances blend_t 0 -> 1; no per-tile CPU work per frame).
// Colours and saturation multipliers are uniforms supplied by FogLayer from ThemeTokens.GAMEPLAY_FOG_* (no hard-coded colour).
// "Blurry" = alpha + saturation drop; no blur (single pass, Compatibility-friendly).
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform sampler2D prev_data : filter_linear, repeat_disable;
uniform sampler2D next_data : filter_linear, repeat_disable;
uniform float blend_t = 1.0;
uniform vec2 grid_size = vec2(1.0);
uniform float tile_px = 32.0;
uniform float edge_px = 8.0;
uniform vec4 unknown_color;
uniform vec4 memory_color;
uniform vec4 peripheral_color;
uniform vec4 hatch_color;
uniform float unknown_saturation = 1.0;
uniform float memory_saturation = 1.0;
uniform float peripheral_saturation = 1.0;
uniform vec2 view_origin;
uniform float view_radius = 0.0;
uniform float soft_edge_px = 0.0;
uniform float hatch_step_px = 8.0;
uniform float hatch_width_px = 1.5;

void fragment() {
	vec2 grid_pos = UV * grid_size;
	vec2 world = grid_pos * tile_px;
	// Tile-edge smoothing: the linear blend between two texel centres is squeezed into +/- edge_px/2 of the tile border.
	vec2 t = grid_pos - 0.5;
	vec2 cell = floor(t);
	vec2 f = clamp((fract(t) - 0.5) * (tile_px / max(edge_px, 0.001)) + 0.5, 0.0, 1.0);
	vec2 uv = (cell + f + 0.5) / grid_size;
	vec4 d = mix(texture(prev_data, uv), texture(next_data, uv), blend_t);
	// Vision-edge fade: the last soft_edge_px of the radius shifts visible tiles toward the memory tone.
	float seen = clamp(1.0 - d.r - d.g - d.b, 0.0, 1.0);
	float fade = 0.0;
	if (soft_edge_px > 0.0) {
		fade = smoothstep(view_radius - soft_edge_px, view_radius, distance(world, view_origin));
	}
	float wu = d.r;
	float wm = d.g + seen * fade;
	float wp = d.b;
	vec3 under = texture(screen_tex, SCREEN_UV).rgb;
	float lum = dot(under, vec3(0.299, 0.587, 0.114));
	float sat = 1.0 - wu * (1.0 - unknown_saturation) - wm * (1.0 - memory_saturation)
			- wp * (1.0 - peripheral_saturation);
	vec3 col = mix(vec3(lum), under, clamp(sat, 0.0, 1.0));
	float a = wu * unknown_color.a + wm * memory_color.a + wp * peripheral_color.a;
	vec3 tint = (wu * unknown_color.a * unknown_color.rgb + wm * memory_color.a * memory_color.rgb
			+ wp * peripheral_color.a * peripheral_color.rgb) / max(a, 0.0001);
	col = mix(col, tint, clamp(a, 0.0, 1.0));
	if (d.a > 0.01) {
		float s = mod(world.x + world.y, hatch_step_px);
		col = mix(col, hatch_color.rgb, hatch_color.a * d.a * step(s, hatch_width_px));
	}
	COLOR = vec4(col, 1.0);
}
