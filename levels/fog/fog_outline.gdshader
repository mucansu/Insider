// Görüş sisi krokisi (US-011a; GDD §6.5): duvar kenarı ve kapı eşiği çizgileri bir kez çizilir; her parçanın
// görünürlüğü, bulunduğu karonun sis verisinden gelir (FogLayer veri dokuları, geçiş fog_layer.gdshader ile aynı:
// mix(prev, next, blend_t); R bilinmeyen, G hafıza ağırlığı). Görünen ve çevresel karoda kroki gizlidir (seviyenin
// kendi çizgisi zaten görünür). Renk çizim komutundan (ThemeTokens tonundan); burada sabit renk yok.
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
