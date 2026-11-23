extends CasoDeTeste

## Galeria de fundos do menu (ADR 0033): seis paisagens, cada uma com a moldura
## dos botoes no tom que combina com ela, trocadas pelo botao do canto. As
## preferencias vao para um arquivo temporario, para nao mexer nas de quem roda
## a suite.

var _caminho_original: String = ""


func antes() -> void:
	_caminho_original = Preferencias.caminho
	Preferencias.caminho = caminho_temporario("preferencias_galeria.cfg")
	if FileAccess.file_exists(Preferencias.caminho):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Preferencias.caminho))


func depois() -> void:
	Preferencias.caminho = _caminho_original
	await get_tree().process_frame


func _abrir(cena: String) -> Control:
	var tela: Control = (load(cena) as PackedScene).instantiate() as Control
	get_tree().root.add_child(tela)
	await get_tree().process_frame
	return tela


func teste_cada_fundo_tem_imagem_e_moldura() -> void:
	afirmar_igual(GaleriaDeFundos.ORDEM.size(), 6, "brejo e os cinco fundos novos")
	afirmar_igual(GaleriaDeFundos.ORDEM[0], "brejo", "o brejo continua sendo o primeiro")
	var base: Image = GaleriaDeFundos.textura_do_balao("brejo").get_image()
	for fundo: String in GaleriaDeFundos.ORDEM:
		var imagem: Texture2D = GaleriaDeFundos.textura_do_fundo(fundo)
		afirmar_igual(imagem.get_size(), Vector2(640, 360), "%s: do tamanho da tela base" % fundo)
		afirmar_igual(imagem.resource_path, "res://recursos/arte/fundos/%s.png" % fundo, "%s: imagem propria" % fundo)
		var balao: Image = GaleriaDeFundos.textura_do_balao(fundo).get_image()
		afirmar_igual(balao.get_size(), base.get_size(), "%s: moldura do mesmo tamanho (mesmo nine-patch)" % fundo)
		afirmar_falso(GaleriaDeFundos.nome(fundo).is_empty(), "%s: tem nome para a dica do botao" % fundo)
		if fundo == "brejo":
			continue
		# O miolo verde muda de cor; a flor rosa do canto fica igual.
		afirmar_cores_diferentes(balao.get_pixel(35, 20), base.get_pixel(35, 20), "%s: miolo recolorido" % fundo)
		var flor: Vector2i = _primeiro_pixel_rosa(base)
		if flor.x >= 0:
			afirmar_igual(balao.get_pixelv(flor), base.get_pixelv(flor), "%s: flores intactas" % fundo)


func afirmar_cores_diferentes(a: Color, b: Color, mensagem: String) -> void:
	afirmar_verdadeiro(not a.is_equal_approx(b), mensagem)


func _primeiro_pixel_rosa(imagem: Image) -> Vector2i:
	for y: int in imagem.get_height():
		for x: int in imagem.get_width():
			var cor: Color = imagem.get_pixel(x, y)
			if cor.a > 0.5 and cor.r > 0.9 and cor.g < 0.75 and cor.b > 0.65:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func teste_seguinte_percorre_todos_e_volta_ao_inicio() -> void:
	var visto: Array[String] = []
	var fundo: String = GaleriaDeFundos.PADRAO
	for i: int in GaleriaDeFundos.ORDEM.size():
		visto.append(fundo)
		fundo = GaleriaDeFundos.seguinte(fundo)
	afirmar_igual(visto, GaleriaDeFundos.ORDEM, "passa por todos, na ordem")
	afirmar_igual(fundo, GaleriaDeFundos.PADRAO, "e volta ao brejo")
	afirmar_igual(GaleriaDeFundos.atual(), "brejo", "sem escolha guardada: o brejo")


func teste_botao_da_galeria_troca_fundo_e_botoes() -> void:
	var menu: Control = await _abrir("res://cenas/ui/menu_principal.tscn")
	var galeria: Button = menu.get_node_or_null("Galeria") as Button
	if not afirmar_nao_nulo(galeria, "o menu tem o botao de galeria"):
		menu.free()
		return
	afirmar_igual(galeria.icon.resource_path, "res://recursos/arte/icone_galeria.png", "com o icone de galeria")
	var area: Rect2 = galeria.get_global_rect()
	afirmar_verdadeiro(area.position.x > 560.0 and area.position.y < 20.0, "no canto superior direito")

	var fundo: TextureRect = menu.get_node("Fundo") as TextureRect
	var botao: Button = menu.get_node("Cartao/Coluna/Botoes/EscolherFase") as Button
	afirmar_igual(fundo.texture.resource_path, "res://recursos/arte/fundos/brejo.png", "comeca no brejo")

	galeria.pressed.emit()
	afirmar_igual(menu.fundo_atual(), "noite", "um toque: o proximo fundo")
	afirmar_igual(fundo.texture.resource_path, "res://recursos/arte/fundos/noite.png", "a imagem trocou")
	for estado: StringName in [&"normal", &"hover", &"pressed"]:
		afirmar_igual((botao.get_theme_stylebox(estado) as StyleBoxTexture).texture.resource_path,
			"res://recursos/arte/balao_botao_noite.png", "botao (%s) no tom da noite" % estado)
	afirmar_igual(GaleriaDeFundos.atual(), "noite", "a escolha fica lembrada")
	afirmar_igual((menu.get_node("Cartao/Coluna").theme.get_stylebox(&"normal", &"Button") as StyleBoxTexture)
		.texture.resource_path, "res://recursos/arte/balao_botao.png", "o tema compartilhado nao muda")

	for i: int in GaleriaDeFundos.ORDEM.size() - 1:
		galeria.pressed.emit()
	afirmar_igual(menu.fundo_atual(), "brejo", "seis toques: volta ao brejo")
	galeria.pressed.emit()
	galeria.pressed.emit()
	menu.free()

	var de_novo: Control = await _abrir("res://cenas/ui/menu_principal.tscn")
	afirmar_igual(de_novo.fundo_atual(), "estufa", "reabrir o menu mantem o fundo escolhido")
	de_novo.free()


func teste_telas_secundarias_usam_o_fundo_escolhido() -> void:
	GaleriaDeFundos.salvar("carpas")
	for cena: String in ["res://cenas/ui/selecao_de_fases.tscn", "res://cenas/ui/editor_de_fase.tscn",
			"res://cenas/ui/dashboard_telemetria.tscn"]:
		var tela: Control = await _abrir(cena)
		afirmar_igual((tela.get_node("Fundo") as TextureRect).texture.resource_path,
			"res://recursos/arte/fundos/carpas.png", "%s: mesmo fundo do menu" % cena.get_file())
		tela.queue_free()
		await get_tree().process_frame
