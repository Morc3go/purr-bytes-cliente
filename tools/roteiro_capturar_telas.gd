extends RefCounted

## Roteiro de tools/capturar_telas.gd (carregado com os autoloads ja de pe).
## Usa a fase de exemplo e nao grava telemetria real: o transporte vira MOCK
## num arquivo de user://testes.


func _salvar(arvore: SceneTree, pasta: String, nome: String) -> void:
	for i: int in 4:
		await arvore.process_frame
	await RenderingServer.frame_post_draw
	var imagem: Image = arvore.root.get_texture().get_image()
	imagem.save_png(pasta.path_join(nome + ".png"))
	print("captura: %s" % nome)


func executar(arvore: SceneTree, pasta: String) -> void:
	DirAccess.make_dir_recursive_absolute(pasta)
	DirAccess.make_dir_recursive_absolute("user://testes")
	var telemetria: Node = arvore.root.get_node("Telemetria")
	telemetria.call("reiniciar", TransporteMock.new("user://testes/capturas.jsonl"),
		"user://testes/capturas_fila.json")

	arvore.change_scene_to_file("res://cenas/ui/menu_principal.tscn")
	await _salvar(arvore, pasta, "menu")
	for tela: String in ["selecao_de_fases", "dashboard_telemetria", "editor_de_fase"]:
		arvore.change_scene_to_file("res://cenas/ui/%s.tscn" % tela)
		await _salvar(arvore, pasta, tela)
		if tela == "selecao_de_fases":
			# "jogar" pergunta o gatinho antes de abrir a fase (ADR 0030).
			arvore.current_scene.call("_ao_jogar")
			await _salvar(arvore, pasta, "escolha_de_gato")
			# depois do gatinho, o cenario (ADR 0036)
			(arvore.current_scene.get("_escolha_de_gato") as EscolhaDeGato).escolhido.emit(PelagemGato.PADRAO)
			await _salvar(arvore, pasta, "escolha_de_cenario")

	arvore.root.get_node("Sessao").call("iniciar")
	var lido: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_texto(
		JSON.stringify(CarregadorFaseJson._exemplo()))
	var fase: FaseBase = IniciadorDeFase.jogar(arvore, lido.config)
	for i: int in 30:
		await arvore.physics_frame
	await _salvar(arvore, pasta, "fase")

	# Gato andando em cada direcao (a camera segue, o sprite troca de folha).
	var sprite: AnimadorDirecional = fase.jogador.get_node("Sprite") as AnimadorDirecional
	for direcao: Vector2 in [Vector2.RIGHT, Vector2.DOWN]:
		sprite.atualizar(direcao * 70.0)
		await _salvar(arvore, pasta, "fase_andando_%s" % ("direita" if direcao == Vector2.RIGHT else "baixo"))
	# Terminal aberto com um erro e um acerto, como no TC-04 / TC-03.
	fase._ao_submeter_comando("cyfrar senha chave=3", 2000)
	fase._ao_submeter_comando("cifrar senha chave=3", 1500)
	fase.terminal.call("abrir")
	await _salvar(arvore, pasta, "terminal")

	# Uma captura por fase de demonstracao (ADR 0021).
	var fases: PackedStringArray = DirAccess.get_files_at(CarregadorFaseJson.PASTA_DAS_FASES_DEMO)
	for nome: String in fases:
		if nome.get_extension() != "json":
			continue
		var demo: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_arquivo(
			CarregadorFaseJson.PASTA_DAS_FASES_DEMO.path_join(nome))
		IniciadorDeFase.jogar(arvore, demo.config)
		for i: int in 20:
			await arvore.physics_frame
		await _salvar(arvore, pasta, "demo_" + nome.get_basename())

	# A mesma fase em cada cenario do labirinto (ADR 0035).
	var base: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_arquivo(
		CarregadorFaseJson.PASTA_DAS_FASES_DEMO.path_join("01-cesar-o-primeiro-segredo.json"))
	for cenario: String in CenarioDoLabirinto.ORDEM:
		base.config.cenario = cenario
		IniciadorDeFase.jogar(arvore, base.config)
		for i: int in 20:
			await arvore.physics_frame
		await _salvar(arvore, pasta, "cenario_" + cenario)
