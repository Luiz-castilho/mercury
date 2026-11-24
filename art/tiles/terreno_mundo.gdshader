shader_type canvas_item;
// Terreno de Mercúrio: as bordas (contorno, beirada) vêm do atlas, mas a rocha e
// a poeira são lidas em coordenadas do MUNDO. Assim a textura continua de um
// tile para o outro sem emenda e sem repetir a cada 64 px.
// Use no TileMapLayer com Texture Filter = Nearest e o TileSet com
// "Use Texture Padding" desligado (o mercurio_terreno.tres já vem assim).

uniform sampler2D mask_atlas : filter_nearest; // R = rocha, G = poeira, B = sombra
uniform sampler2D rock_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D dust_tex : repeat_enable, filter_linear_mipmap;
uniform float world_size = 256.0; // px de mundo por repetição das texturas
uniform float dust_tint = 0.9;

varying vec2 world_pos;
varying vec4 modulate_color;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	modulate_color = COLOR;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec4 m = texture(mask_atlas, UV);
	vec2 wuv = world_pos / world_size;
	vec3 rock = texture(rock_tex, wuv).rgb * m.b;
	vec3 dust = texture(dust_tex, wuv).rgb * dust_tint * m.b;
	// Troca a rocha/poeira "local" do atlas pela versão em coordenadas do mundo.
	vec3 col = mix(base.rgb, rock, m.r);
	col = mix(col, dust, m.g);
	COLOR = vec4(col, base.a) * modulate_color;
}
