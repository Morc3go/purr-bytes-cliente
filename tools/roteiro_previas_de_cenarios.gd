extends RefCounted

## Roteiro de tools/gerar_previas_de_cenarios.gd (com os autoloads ja de pe).

## Tamanho da miniatura, em pixels da tela base: 7 x 4 celulas de 16, com um
## pixel de jogo por pixel de imagem (sem esticar o pixel art).
const TAMANHO: Vector2i = Vector2i(112, 64)


func executar(arvore: SceneTree) -> void:
	DirAccess.make_dir_recursive_absolute("user://testes")
	arvore.root.get_node("Telemetria").call("reiniciar",
		TransporteMock.new("user://testes/previas.jsonl"), "user://testes/previas_fila.json")
	arvore.root.get_node("Sessao").call("iniciar")
	var demo: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_arquivo(
		CarregadorFaseJson.PASTA_DAS_FASES_DEMO.path_join("01-cesar-o-primeiro-segredo.json"))
	for cenario: String in CenarioDoLabirinto.ORDEM:
		demo.config.cenario = cenario
		var fase: FaseBase = IniciadorDeFase.jogar(arvore, demo.config, PelagemGato.PADRAO)
		for i: int in 10:
			await arvore.physics_frame
		# a HUD e o rodape nao entram na miniatura
		fase.hud.visible = false
		for i: int in 3:
			await arvore.process_frame
		await RenderingServer.frame_post_draw
		var tela: Image = arvore.root.get_texture().get_image()
		# A janela pode ser maior que a tela base (pixel art ampliado): a
		# miniatura sai em pixel de jogo, reduzida pelo mesmo fator inteiro.
		var fator: int = maxi(1, roundi(float(tela.get_width()) / fase.get_viewport().get_visible_rect().size.x))
		var recorte: Vector2i = TAMANHO * fator
		var centro: Vector2 = _centro(fase, tela.get_size())
		var canto := Vector2i(clampi(int(centro.x) - recorte.x / 2, 0, tela.get_width() - recorte.x),
			clampi(int(centro.y) - recorte.y / 2, 0, tela.get_height() - recorte.y))
		var previa: Image = tela.get_region(Rect2i(canto, recorte))
		previa.resize(TAMANHO.x, TAMANHO.y, Image.INTERPOLATE_NEAREST)
		var pasta: String = "res://recursos/arte/cenarios/%s" % cenario
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pasta))
		previa.save_png(ProjectSettings.globalize_path(pasta.path_join("previa.png")))
		print("previa: %s %s" % [cenario, canto])


## Onde centrar o recorte: no primeiro enfeite (o boneco de neve, o sapinho...)
## ou, no jardim, na entrada com o gatinho.
func _centro(fase: FaseBase, tela: Vector2i) -> Vector2:
	var arbustos: ArbustosDoLabirinto = fase.labirinto.get_node("Arbustos") as ArbustosDoLabirinto
	var alvo: Vector2 = fase.ponto_de_entrada.global_position + Vector2(40, 16)
	var enfeites: Array[Dictionary] = arbustos.enfeites()
	var preferidos: Array[String] = ["boneco_de_neve", "sapo_na_folha"]
	for enfeite: Dictionary in enfeites:
		if preferidos.has(String(enfeite["nome"])):
			alvo = arbustos.to_global(enfeite["base"])
			break
	if alvo == fase.ponto_de_entrada.global_position + Vector2(40, 16) and not enfeites.is_empty():
		alvo = arbustos.to_global(enfeites[0]["base"])
	var na_tela: Vector2 = fase.get_viewport().get_canvas_transform() * alvo
	return na_tela * (Vector2(tela) / fase.get_viewport().get_visible_rect().size)
