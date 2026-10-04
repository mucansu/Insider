// Vision fog sketch (US-011a; GDD §6.5): wall-edge and door-threshold lines drawn once; each piece's visibility comes from the fog data of its tile
// (FogLayer data textures, same transition as fog_layer.gdshader: mix(prev, next, blend_t); R unknown, G memory weight).
// The sketch is hidden on visible and ambient tiles (the level's own line is already visible). Colour comes from the draw command (ThemeTokens tone); none hard-coded here.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D prev_data : filter_nearest, repeat_disable;
uniform sampler2D next_data : filter_nearest, repeat_disable;
uniform float blend_t = 1.0;
uniform vec2 grid_size = vec2(1.0);
uniform float tile_px = 32.0;

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec2 uv = (floor(local_pos / tile_px) + 0.5) / grid_size;
	vec4 d = mix(texture(prev_data, uv), texture(next_data, uv), blend_t);
	COLOR.a *= clamp(d.r + d.g, 0.0, 1.0);
}
