extends CasoDeTeste

## O jogador escolhe o cenario antes da fase, logo depois do gatinho (ADR 0036).
## As preferencias vao para um arquivo temporario.

var _caminho_original: String = ""
var _criados: PackedStringArray = []
var _fase: FaseBase = null


func antes() -> void:
	_caminho_original = Preferencias.caminho
	Preferencias.caminho = caminho_temporario("preferencias_cenario.cfg")
	Telemetria.reiniciar(TransporteMock.new(caminho_temporario("escolha_cenario.jsonl")),
		caminho_temporario("escolha_cenario_fila.json"))


func depois() -> void:
	Preferencias.caminho = _caminho_original
	for caminho: String in _criados:
		if FileAccess.file_exists(caminho):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho))
	_criados.clear()
	if _fase != null and is_instance_valid(_fase):
		_fase.queue_free()
	_fase = null
	if Sessao.ativa:
		Sessao.encerrar()
	await get_tree().process_frame


func _abrir(sugerido: String) -> EscolhaDeCenario:
	var tela: EscolhaDeCenario = (load("res://cenas/ui/escolha_de_cenario.tscn") as PackedScene).instantiate() as EscolhaDeCenario
	tela.sugerido = sugerido
	add_child(tela)
	await get_tree().process_frame
	return tela


func teste_um_cartao_por_cenario_com_miniatura() -> void:
	var tela: EscolhaDeCenario = await _abrir("lago")
	for cenario: String in CenarioDoLabirinto.ORDEM:
		var cartao: Button = tela.cartao(cenario)
		if not afirmar_nao_nulo(cartao, "%s: tem cartao" % cenario):
			continue
		var previa: TextureRect = cartao.get_node("Previa") as TextureRect
		afirmar_igual(previa.texture, CenarioDoLabirinto.textura_da_previa(cenario), "%s: com a miniatura dele" % cenario)
		afirmar_igual(previa.texture.get_size(), Vector2(112, 64), "%s: miniatura em pixel de jogo" % cenario)
		afirmar_igual((cartao.get_node("Nome") as Label).text, CenarioDoLabirinto.nome(cenario), "%s: com o nome" % cenario)
		afirmar_igual(cartao.theme_type_variation, &"CartaoDeGato", "%s: cartao igual ao da escolha do gato" % cenario)
	afirmar_verdadeiro((tela.get_node("Painel/Coluna/Subtitulo") as Label).text.contains("lago com passarelas"),
		"o subtitulo diz o cenario sugerido pela fase")
	tela.queue_free()
	await get_tree().process_frame


func teste_comeca_no_sugerido_e_escolhe() -> void:
	var tela: EscolhaDeCenario = await _abrir("inverno")
	afirmar_igual(tela.em_foco(), "inverno", "comeca no cenario que a fase sugere: Enter joga como o professor montou")
	tela.focar("lavanda")
	afirmar_igual(tela.em_foco(), "lavanda", "o foco anda entre os cartoes")
	afirmar_igual(tela.cartao("lavanda").modulate.a, 1.0, "o escolhido fica aceso")
	afirmar_verdadeiro(tela.cartao("inverno").modulate.a < 1.0, "e os outros apagadinhos")
	var recebidos: Array[String] = []
	tela.escolhido.connect(func(c: String) -> void: recebidos.append(c))
	tela.cartao("ruinas").pressed.emit()
	afirmar_igual(recebidos, ["ruinas"] as Array[String], "clicar no cartao escolhe o cenario")
	var cancelou: Array[bool] = []
	tela.cancelado.connect(func() -> void: cancelou.append(true))
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	tela._unhandled_input(esc)
	afirmar_tamanho(cancelou, 1, "Esc volta")
	tela.queue_free()
	await get_tree().process_frame


func teste_fase_sem_cenario_sugere_o_jardim() -> void:
	var tela: EscolhaDeCenario = await _abrir("")
	afirmar_igual(tela.em_foco(), "jardim", "sem sugestao, o jardim de sempre")
	tela.queue_free()
	await get_tree().process_frame


func _selecao_com_fase(cenario_da_fase: String) -> Control:
	CarregadorFaseJson.garantir_pasta()
	var dados: Dictionary = CarregadorFaseJson._exemplo()
	dados["cenario"] = cenario_da_fase
	var caminho: String = "%s/%s" % [CarregadorFaseJson.pasta_das_fases, "0000-zz-teste-cenario.json"]
	var arquivo: FileAccess = FileAccess.open(caminho, FileAccess.WRITE)
	arquivo.store_string(JSON.stringify(dados))
	arquivo.close()
	_criados.append(caminho)
	var tela: Control = (load("res://cenas/ui/selecao_de_fases.tscn") as PackedScene).instantiate() as Control
	get_tree().root.add_child(tela)
	get_tree().current_scene = tela
	await get_tree().process_frame
	(tela._lista as ItemList).select(Array(tela._caminhos).find(caminho))
	return tela


func teste_gato_depois_cenario_depois_fase() -> void:
	var tela: Control = await _selecao_com_fase("cerejeira")
	tela._ao_jogar()
	await get_tree().process_frame
	tela._escolha_de_gato.escolhido.emit(PelagemGato.CALICO)
	await get_tree().process_frame
	var escolha: EscolhaDeCenario = tela._escolha_de_cenario
	if not afirmar_nao_nulo(escolha, "depois do gato vem o cenario"):
		tela.queue_free()
		return
	afirmar_igual(escolha.em_foco(), "cerejeira", "com o cenario da fase ja marcado")

	# Esc no cenario volta ao gatinho, sem perder a fase
	escolha.cancelado.emit()
	await get_tree().process_frame
	afirmar_nulo(tela._escolha_de_cenario, "voltar fecha a escolha do cenario")
	afirmar_nao_nulo(tela._escolha_de_gato, "e reabre a do gatinho")
	afirmar_igual(tela._escolha_de_gato.em_foco(), PelagemGato.CALICO, "no gato que ja tinha sido escolhido")

	tela._escolha_de_gato.escolhido.emit(PelagemGato.CALICO)
	await get_tree().process_frame
	tela._escolha_de_cenario.escolhido.emit("inverno")
	await get_tree().process_frame
	_fase = get_tree().current_scene as FaseBase
	if not afirmar_nao_nulo(_fase, "escolher o cenario poe a fase em jogo"):
		return
	afirmar_igual(_fase.configuracao.cenario, "inverno", "no cenario que o jogador escolheu")
	afirmar_igual((_fase.labirinto.get_node("Arbustos") as ArbustosDoLabirinto).cenario(), "inverno",
		"e o labirinto vestido nele")
	afirmar_igual(_fase.jogador.pelagem(), PelagemGato.CALICO, "com o gato escolhido")
	# O arquivo da fase nao muda: a escolha vale para esta partida.
	var lido: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_criados[0])) as Dictionary
	afirmar_igual(String(lido["cenario"]), "cerejeira", "a fase continua sugerindo o que o professor escolheu")
