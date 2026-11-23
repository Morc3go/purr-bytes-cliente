extends RefCounted

## Roteiro de tools/capturar_galeria.gd (carregado com os autoloads ja de pe).


func _salvar(arvore: SceneTree, pasta: String, nome: String) -> void:
	for i: int in 5:
		await arvore.process_frame
	await RenderingServer.frame_post_draw
	arvore.root.get_texture().get_image().save_png(pasta.path_join(nome + ".png"))
	print("captura: %s/%s" % [pasta.get_file(), nome])


func executar(arvore: SceneTree, pasta: String, fundos: PackedStringArray) -> void:
	DirAccess.make_dir_recursive_absolute("user://testes")
	Preferencias.caminho = "user://testes/preferencias_capturas.cfg"
	var telemetria: Node = arvore.root.get_node("Telemetria")
	telemetria.call("reiniciar", TransporteMock.new("user://testes/capturas_galeria.jsonl"),
		"user://testes/capturas_galeria_fila.json")
	var lista: PackedStringArray = fundos if not fundos.is_empty() else PackedStringArray(GaleriaDeFundos.ORDEM)
	for fundo: String in lista:
		GaleriaDeFundos.salvar(fundo)
		TemaDaGaleria.esquecer_cache()
		var destino: String = pasta.path_join(fundo)
		DirAccess.make_dir_recursive_absolute(destino)
		await _telas(arvore, destino)
		await _paineis_do_jogo(arvore, destino)


func _telas(arvore: SceneTree, pasta: String) -> void:
	arvore.change_scene_to_file("res://cenas/ui/menu_principal.tscn")
	await _salvar(arvore, pasta, "01_menu")
	arvore.change_scene_to_file("res://cenas/ui/selecao_de_fases.tscn")
	await _salvar(arvore, pasta, "02_selecao")
	arvore.current_scene.call("_ao_jogar")
	await _salvar(arvore, pasta, "03_escolha_de_gato")
	(arvore.current_scene.get("_escolha_de_gato") as EscolhaDeGato).escolhido.emit(PelagemGato.PADRAO)
	await _salvar(arvore, pasta, "03b_escolha_de_cenario")
	arvore.change_scene_to_file("res://cenas/ui/editor_de_fase.tscn")
	await _salvar(arvore, pasta, "04_editor_geral")
	var editor: Node = arvore.current_scene
	(editor.get("_abas") as TabContainer).current_tab = 1
	await _salvar(arvore, pasta, "05_editor_cachorros")
	(editor.get("_abas") as TabContainer).current_tab = 2
	await _salvar(arvore, pasta, "06_editor_perguntas")
	arvore.change_scene_to_file("res://cenas/ui/dashboard_telemetria.tscn")
	await _salvar(arvore, pasta, "07_telemetria")
	arvore.current_scene.call("_ao_abrir_diagnostico")
	await _salvar(arvore, pasta, "08_telemetria_diagnostico")


func _paineis_do_jogo(arvore: SceneTree, pasta: String) -> void:
	var sessao: Node = arvore.root.get_node("Sessao")
	if not sessao.get("ativa"):
		sessao.call("iniciar")
	var demo: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_arquivo(
		CarregadorFaseJson.PASTA_DAS_FASES_DEMO.path_join("01-cesar-o-primeiro-segredo.json"))
	var fase: FaseBase = IniciadorDeFase.jogar(arvore, demo.config, "calico")
	for i: int in 20:
		await arvore.physics_frame
	await _salvar(arvore, pasta, "09_fase")

	fase._ao_submeter_comando("cyfrar senha chave=3", 2000)
	fase._ao_submeter_comando("cifrar senha chave=3", 1500)
	fase.terminal.call("abrir")
	await _salvar(arvore, pasta, "10_terminal")
	fase.terminal.call("fechar")

	fase._alternar_painel_de_demonstracao()
	await _salvar(arvore, pasta, "11_painel_f4")
	fase.painel_cifra.fechar()

	fase.caixa_puzzle.abrir(fase.pacotes[0].configuracao)
	await _salvar(arvore, pasta, "12_pergunta")
	fase.caixa_puzzle.fechar()

	fase.tela_captura.mostrar("pacote interceptado",
		"o vigia verde para com a cifra de César: cifrar senha chave=3. em texto claro, qualquer um lê o pacote.")
	await _salvar(arvore, pasta, "13_captura")
	fase.tela_captura.visible = false

	fase.painel_pause.abrir()
	await _salvar(arvore, pasta, "14_pausa")
	fase.painel_pause.fechar()
