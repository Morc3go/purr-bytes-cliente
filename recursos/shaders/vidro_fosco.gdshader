// Vidro fosco do cartao do menu (ADR 0023).
//
// Aplicado no proprio PanelContainer: o shader so roda nos pixels que o
// StyleBoxFlat desenha, entao os cantos arredondados e a borda ja servem de
// mascara, sem textura extra. Os filhos (botoes, textos) nao herdam o
// material e continuam nitidos.
//
// A cor do StyleBox entra como "tinta": o alfa dela diz quanto do vidro e cor
// e quanto e fundo desfocado. Com alfa 0 o cartao seria so desfoque.
shader_type canvas_item;

uniform sampler2D tela : hint_screen_texture, filter_linear_mipmap;
// Raio do desfoque, em pixels da tela base (640x360).
uniform float raio_px : hint_range(0.0, 8.0) = 3.0;

void fragment() {
	// 5x5 amostras com peso gaussiano: o "levemente embacado" pedido. Mipmap
	// sozinho (textureLod alto) deixaria o desfoque quadriculado.
	vec2 passo = SCREEN_PIXEL_SIZE * raio_px * 0.5;
	vec3 soma = vec3(0.0);
	float pesos = 0.0;
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			float peso = exp(-float(x * x + y * y) / 4.0);
			soma += textureLod(tela, SCREEN_UV + vec2(float(x), float(y)) * passo, 1.0).rgb * peso;
			pesos += peso;
		}
	}
	vec3 fundo = soma / pesos;
	COLOR = vec4(mix(fundo, COLOR.rgb, COLOR.a), 1.0);
}
