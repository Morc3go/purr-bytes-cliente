extends CasoDeTeste

## Menu com o logo da equipe, o gatinho mexendo o rabo e a moldura de vinhas
## em volta do cartao (ADR 0031).

const MENU: String = "res://cenas/ui/menu_principal.tscn"
const SOBRA_DA_MOLDURA: float = 12.0   # 6 pixels de arte x 2


func _abrir_menu() -> Control:
	var menu: Control = (load(MENU) as PackedScene).instantiate() as Control
	get_tree().root.add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	return menu


func teste_logo_no_lugar_do_titulo() -> void:
	var menu: Control = await _abrir_menu()
	var logo: TextureRect = menu.get_node_or_null("Cartao/Coluna/Logo") as TextureRect
	if afirmar_nao_nulo(logo, "o menu tem o logo"):
		afirmar_igual(logo.texture.resource_path, "res://recursos/arte/logo_crypto_cats.png", "o logo da equipe")
		afirmar_igual(logo.tooltip_text, "Crypto Cats", "o nome do jogo continua escrito no logo")
		afirmar_igual(logo.texture.get_size(), Vector2(182, 50), "pixel de arte em 2x2, sem esticar")
	afirmar_nulo(menu.get_node_or_null("Cartao/Coluna/Titulo"), "o titulo em texto saiu")
	afirmar_nulo(menu.get_node_or_null("Cartao/Coluna/Subtitulo"), "e o subtitulo tambem, a pedido da equipe")
	menu.free()


func teste_gatinho_mexe_o_rabo_indo_e_voltando() -> void:
	var quadros: SpriteFrames = load("res://cenas/ui/menu_principal.gd").quadros_do_gato()
	var rabo: StringName = &"rabo"
	afirmar_verdadeiro(quadros.get_animation_loop(rabo), "em loop")
	afirmar_igual(quadros.get_animation_speed(rabo), 5.0, "200 ms por quadro, como o GIF")
	var colunas: Array[float] = []
	for i: int in quadros.get_frame_count(rabo):
		colunas.append((quadros.get_frame_texture(rabo, i) as AtlasTexture).region.position.x)
	afirmar_igual(colunas, [0.0, 35.0, 70.0, 105.0, 70.0, 35.0] as Array[float],
		"vai do quadro 0 ao 3 e volta, sem pular do ultimo para o primeiro")

	var menu: Control = await _abrir_menu()
	var mascote: Control = menu.get_node("Cartao/Coluna/Mascote") as Control
	afirmar_igual(mascote.get_child_count(), 1, "os tres bichinhos sairam: fica so o gatinho")
	var gato: AnimatedSprite2D = mascote.get_node("Gato") as AnimatedSprite2D
	afirmar_verdadeiro(gato.is_playing(), "o rabo esta mexendo")
	afirmar_igual(gato.position.x, mascote.size.x * 0.5, "no meio do cartao")
	# Um pouco maior que a arte (ADR 0039), mas ainda dentro da altura do Mascote.
	afirmar_igual(gato.scale, Vector2.ONE * 4.0 / 3.0, "siames ampliado 4/3")
	afirmar_verdadeiro(29.0 * gato.scale.y <= mascote.size.y, "cabe no espaco do mascote")
	menu.free()


func teste_folha_do_gato_tem_fundo_transparente() -> void:
	# O siames deitado (ADR 0039): os 4 quadros cortados pelo mesmo retangulo,
	# entao o corpo fica parado e so o rabo mexe.
	var imagem: Image = Image.load_from_file(ProjectSettings.globalize_path("res://recursos/arte/gato_siames_rabo.png"))
	afirmar_igual(imagem.get_size(), Vector2i(140, 29), "4 quadros de 35x29")
	for quadro: int in 4:
		afirmar_igual(imagem.get_pixel(quadro * 35, 0).a, 0.0, "quadro %d: canto transparente" % quadro)
		var usado: Rect2i = imagem.get_region(Rect2i(quadro * 35, 0, 35, 29)).get_used_rect()
		afirmar_verdadeiro(usado.size.x > 24 and usado.size.y > 24, "quadro %d tem o gato inteiro" % quadro)
	var quadros: SpriteFrames = load("res://cenas/ui/menu_principal.gd").quadros_do_gato()
	var primeiro: AtlasTexture = quadros.get_frame_texture(&"rabo", 0) as AtlasTexture
	afirmar_igual(primeiro.atlas.resource_path, "res://recursos/arte/gato_siames_rabo.png", "o menu usa o siames")


func teste_moldura_de_vinhas_contorna_o_cartao() -> void:
	var menu: Control = await _abrir_menu()
	var cartao: PanelContainer = menu.get_node("Cartao") as PanelContainer
	var moldura: MolduraDeVinhas = menu.get_node_or_null("Moldura") as MolduraDeVinhas
	if not afirmar_nao_nulo(moldura, "o menu tem a moldura de vinhas"):
		menu.free()
		return
	await get_tree().process_frame
	afirmar_igual(cartao.size, Vector2(300, 312),
		"o conteudo cabe no cartao (o cartao do menu nao cresceu)")
	afirmar_igual(moldura.size, cartao.size + Vector2.ONE * SOBRA_DA_MOLDURA * 2.0,
		"a moldura foi desenhada para este cartao, com a sobra dos lados")
	afirmar_igual(moldura.get_rect().grow(-SOBRA_DA_MOLDURA), cartao.get_rect(), "e esta centrada nele")
	afirmar_verdadeiro(moldura.get_index() > cartao.get_index(), "desenhada por cima da borda do vidro")
	afirmar_igual(moldura.mouse_filter, Control.MOUSE_FILTER_IGNORE, "nao rouba o clique dos botoes")
	# O miolo da moldura e vazio: o vidro e os botoes continuam a vista.
	var imagem: Image = moldura.textura_atual().get_image()
	var centro: Vector2i = imagem.get_size() / 2
	afirmar_igual(imagem.get_region(Rect2i(centro - Vector2i(60, 60), Vector2i(120, 120))).get_used_rect().size,
		Vector2i.ZERO, "o meio da moldura e transparente")
	menu.free()


## A moldura serve para qualquer cartao (ADR 0034): mesmo tamanho, mesmo
## desenho; tamanhos diferentes, a vinha continua dando a volta inteira.
func teste_moldura_e_desenhada_para_qualquer_tamanho() -> void:
	var a: Image = MolduraDeVinhas.desenhar(Vector2i(150, 156))
	var b: Image = MolduraDeVinhas.desenhar(Vector2i(150, 156))
	afirmar_igual(a.get_data(), b.get_data(), "semente fixa: o mesmo cartao tem sempre a mesma moldura")
	for arte: Vector2i in [Vector2i(304, 164), Vector2i(100, 40), Vector2i(220, 120)]:
		var imagem: Image = MolduraDeVinhas.desenhar(arte)
		var sobra: int = MolduraDeVinhas.SOBRA
		afirmar_igual(imagem.get_size(), arte + Vector2i.ONE * sobra * 2, "%s: com a sobra dos lados" % arte)
		# Cada lado do cartao tem vinha: uma faixa de 4 pixels em volta da borda
		# nao pode estar vazia em nenhum dos quatro lados.
		var faixas: Array[Rect2i] = [
			Rect2i(sobra + 10, sobra - 2, arte.x - 20, 4),
			Rect2i(sobra + 10, sobra + arte.y - 2, arte.x - 20, 4),
			Rect2i(sobra - 2, sobra + 10, 4, arte.y - 20),
			Rect2i(sobra + arte.x - 2, sobra + 10, 4, arte.y - 20),
		]
		for faixa: Rect2i in faixas:
			afirmar_verdadeiro(imagem.get_region(faixa).get_used_rect().size != Vector2i.ZERO,
				"%s: a vinha passa pela faixa %s" % [arte, faixa])
