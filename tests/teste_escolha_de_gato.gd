extends CasoDeTeste

## Escolha do gatinho antes da fase: amarelo, calico ou siames (ADR 0030).
##
## O que trava: as tres folhas sao intercambiaveis (mesmas animacoes, mesmo
## quadro), a fase veste o gato pedido e o mantem ao reiniciar, a tela de
## escolha comeca no ultimo gato escolhido, e a selecao de fases so poe a fase
## em jogo DEPOIS da escolha. A preferencia vai para um arquivo temporario: o
## teste nao pode mexer no user://preferencias.cfg de quem roda a suite.

var _caminho_original: String = ""
var _fase: FaseBase = null
var _criados: PackedStringArray = PackedStringArray()


func antes() -> void:
	_caminho_original = Preferencias.caminho
	Preferencias.caminho = caminho_temporario("preferencias.cfg")
	if FileAccess.file_exists(Preferencias.caminho):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Preferencias.caminho))
	Telemetria.reiniciar(TransporteMock.new(caminho_temporario("gato.jsonl")),
		caminho_temporario("gato_fila.json"))


func depois() -> void:
	get_tree().paused = false
	if _fase != null and is_instance_valid(_fase):
		_fase.queue_free()
	_fase = null
	for caminho: String in _criados:
		if FileAccess.file_exists(caminho):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho))
	_criados = PackedStringArray()
	if Sessao.ativa:
		Sessao.encerrar()
	Preferencias.caminho = _caminho_original
	await get_tree().process_frame


func teste_as_tres_pelagens_sao_intercambiaveis() -> void:
	afirmar_igual(PelagemGato.ORDEM, [PelagemGato.AMARELO, PelagemGato.CALICO, PelagemGato.SIAMES],
		"amarelo, calico e siames, nesta ordem")
	afirmar_igual(PelagemGato.PADRAO, PelagemGato.AMARELO, "o amarelo e o gato base")
	var base: Array = Array(PelagemGato.quadros(PelagemGato.AMARELO).get_animation_names())
	base.sort()
	for pelagem: String in PelagemGato.ORDEM:
		var quadros: SpriteFrames = PelagemGato.quadros(pelagem)
		var nomes: Array = Array(quadros.get_animation_names())
		nomes.sort()
		afirmar_igual(nomes, base, "%s: as mesmas animacoes do gato base" % pelagem)
		for animacao: StringName in quadros.get_animation_names():
			afirmar_igual(quadros.get_frame_count(animacao),
				PelagemGato.quadros(PelagemGato.AMARELO).get_frame_count(animacao),
				"%s/%s: mesmo numero de quadros" % [pelagem, animacao])
		afirmar_igual(quadros.get_frame_texture(&"parado", 0).get_size(), Vector2(32, 32),
			"%s: quadro de 32x32" % pelagem)
	afirmar_igual(PelagemGato.nome(PelagemGato.CALICO), "Cálico", "nome com acento para a tela")
	afirmar_igual(PelagemGato.nome(PelagemGato.SIAMES), "Siamês", "nome com acento para a tela")


func teste_folhas_tem_desenho_em_todos_os_quadros() -> void:
	# Um quadro vazio so apareceria jogando: o gato sumiria num passo.
	for pelagem: String in PelagemGato.ORDEM:
		var imagem: Image = Image.load_from_file(
			ProjectSettings.globalize_path("res://recursos/arte/gato_%s.png" % pelagem))
		afirmar_igual(imagem.get_size(), Vector2i(128, 160), "%s: 4 colunas x 5 linhas de 32" % pelagem)
		for linha: int in 5:
			var desenhados: int = [4, 3, 4, 3, 4][linha]
			for coluna: int in desenhados:
				var usado: Rect2i = imagem.get_region(Rect2i(coluna * 32, linha * 32, 32, 32)).get_used_rect()
				afirmar_verdadeiro(usado.size.x > 8 and usado.size.y > 8,
					"%s: quadro (%d, %d) tem desenho" % [pelagem, coluna, linha])


func teste_preferencia_comeca_no_amarelo_e_lembra_a_escolha() -> void:
	afirmar_igual(PelagemGato.preferida(), PelagemGato.AMARELO, "sem escolha ainda: o amarelo")
	afirmar_igual(PelagemGato.resolver(""), PelagemGato.AMARELO, "vazio resolve para a preferida")
	PelagemGato.salvar_preferida(PelagemGato.SIAMES)
	afirmar_igual(PelagemGato.preferida(), PelagemGato.SIAMES, "lembra o siames")
	afirmar_igual(PelagemGato.resolver(""), PelagemGato.SIAMES, "e passa a ser o padrao")
	afirmar_igual(PelagemGato.resolver(PelagemGato.CALICO), PelagemGato.CALICO, "pedido explicito vale mais")
	PelagemGato.salvar_preferida("frajola")
	afirmar_igual(PelagemGato.preferida(), PelagemGato.SIAMES, "pelagem desconhecida nao e gravada")


func teste_a_fase_veste_o_gato_pedido_e_mantem_ao_reiniciar() -> void:
	var lido: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_texto(JSON.stringify(CarregadorFaseJson._exemplo()))
	if not afirmar_verdadeiro(lido.ok(), "fase de exemplo carrega"):
		return
	Sessao.iniciar()
	_fase = IniciadorDeFase.jogar(get_tree(), lido.config, PelagemGato.SIAMES)
	await get_tree().process_frame
	afirmar_igual(_fase.jogador.pelagem(), PelagemGato.SIAMES, "o jogador e o siames")
	var sprite: AnimatedSprite2D = _fase.jogador.get_node("Sprite") as AnimatedSprite2D
	afirmar_igual(sprite.sprite_frames.resource_path, "res://recursos/arte/gato_siames_frames.tres",
		"e o desenho e mesmo o siames")

	_fase.reiniciar()
	await get_tree().process_frame
	_fase = get_tree().current_scene as FaseBase
	if not afirmar_nao_nulo(_fase, "reiniciar poe a fase de novo em jogo"):
		return
	afirmar_igual(_fase.jogador.pelagem(), PelagemGato.SIAMES, "reiniciar nao troca o gato")


func teste_sem_escolha_a_fase_usa_o_gato_base() -> void:
	var lido: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_texto(JSON.stringify(CarregadorFaseJson._exemplo()))
	Sessao.iniciar()
	_fase = IniciadorDeFase.jogar(get_tree(), lido.config)
	await get_tree().process_frame
	afirmar_igual(_fase.jogador.pelagem(), PelagemGato.AMARELO, "editor e testes jogam com o amarelo")


func teste_jogador_troca_de_pelagem_sem_perder_a_animacao() -> void:
	var jogador: Jogador = (load("res://cenas/base/jogador.tscn") as PackedScene).instantiate() as Jogador
	add_child(jogador)
	await get_tree().process_frame
	afirmar_igual(jogador.pelagem(), PelagemGato.AMARELO, "nasce amarelo")
	var sprite: AnimatedSprite2D = jogador.get_node("Sprite") as AnimatedSprite2D
	sprite.play(&"andar_direita")
	jogador.definir_pelagem(PelagemGato.CALICO)
	afirmar_igual(jogador.pelagem(), PelagemGato.CALICO, "virou calico")
	afirmar_igual(sprite.animation, &"andar_direita", "continua andando para a direita")
	afirmar_verdadeiro(sprite.is_playing(), "e animando")
	jogador.definir_pelagem("dalmata")
	afirmar_igual(jogador.pelagem(), PelagemGato.AMARELO, "pelagem estranha volta ao gato base")
	jogador.queue_free()
	await get_tree().process_frame


func teste_tela_de_escolha_mostra_os_tres_e_comeca_no_ultimo() -> void:
	PelagemGato.salvar_preferida(PelagemGato.CALICO)
	var tela: EscolhaDeGato = (load("res://cenas/ui/escolha_de_gato.tscn") as PackedScene).instantiate() as EscolhaDeGato
	add_child(tela)
	await get_tree().process_frame

	for pelagem: String in PelagemGato.ORDEM:
		var cartao: Button = tela.cartao(pelagem)
		if not afirmar_nao_nulo(cartao, "tem o cartao do %s" % pelagem):
			continue
		afirmar_igual((cartao.get_node("Nome") as Label).text, PelagemGato.nome(pelagem), "com o nome")
		var gato: AnimatedSprite2D = cartao.get_node("Gato") as AnimatedSprite2D
		afirmar_igual(gato.sprite_frames.resource_path, PelagemGato.quadros(pelagem).resource_path,
			"e com o desenho do proprio gato")
	afirmar_igual(tela.em_foco(), PelagemGato.CALICO, "comeca no ultimo gato escolhido")
	afirmar_verdadeiro(tela.cartao(PelagemGato.CALICO).has_focus(), "com o foco no cartao dele")
	var acordado: AnimatedSprite2D = tela.cartao(PelagemGato.CALICO).get_node("Gato") as AnimatedSprite2D
	var dormindo: AnimatedSprite2D = tela.cartao(PelagemGato.AMARELO).get_node("Gato") as AnimatedSprite2D
	afirmar_igual(acordado.animation, &"sentado", "o gato em foco senta de olho aberto")
	afirmar_igual(dormindo.animation, &"descansar", "os outros cochilam")
	afirmar_verdadeiro(tela.cartao(PelagemGato.AMARELO).modulate.a < tela.cartao(PelagemGato.CALICO).modulate.a,
		"e ficam mais apagados que o escolhido")

	tela.focar(PelagemGato.SIAMES)
	afirmar_igual(tela.em_foco(), PelagemGato.SIAMES, "o foco anda entre os cartoes")
	afirmar_igual(acordado.animation, &"descansar", "e o calico volta a cochilar")

	var recebidos: Array[String] = []
	tela.escolhido.connect(func(p: String) -> void: recebidos.append(p))
	tela.cartao(PelagemGato.SIAMES).pressed.emit()
	afirmar_igual(recebidos, [PelagemGato.SIAMES] as Array[String], "clicar no cartao escolhe o gato")

	var cancelou: Array[bool] = []
	tela.cancelado.connect(func() -> void: cancelou.append(true))
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	tela._unhandled_input(esc)
	afirmar_tamanho(cancelou, 1, "Esc volta sem escolher")
	tela.queue_free()
	await get_tree().process_frame


func teste_selecao_pergunta_o_gato_antes_de_jogar() -> void:
	CarregadorFaseJson.garantir_pasta()
	var caminho: String = "%s/%s" % [CarregadorFaseJson.pasta_das_fases, "0000-zz-teste-gato.json"]
	var arquivo: FileAccess = FileAccess.open(caminho, FileAccess.WRITE)
	arquivo.store_string(JSON.stringify(CarregadorFaseJson._exemplo()))
	arquivo.close()
	_criados.append(caminho)

	var tela: Control = (load("res://cenas/ui/selecao_de_fases.tscn") as PackedScene).instantiate() as Control
	get_tree().root.add_child(tela)
	get_tree().current_scene = tela
	await get_tree().process_frame
	var indice: int = Array(tela._caminhos).find(caminho)
	if not afirmar_verdadeiro(indice >= 0, "a fase de teste aparece na lista"):
		tela.queue_free()
		return
	(tela._lista as ItemList).select(indice)

	tela._ao_jogar()
	await get_tree().process_frame
	var escolha: EscolhaDeGato = tela._escolha_de_gato
	if not afirmar_nao_nulo(escolha, "jogar abre a escolha do gatinho"):
		tela.queue_free()
		return
	afirmar_igual(get_tree().current_scene, tela, "e a fase ainda nao comecou")

	escolha.cancelado.emit()
	await get_tree().process_frame
	afirmar_nulo(tela._escolha_de_gato, "voltar fecha a escolha")
	afirmar_igual(get_tree().current_scene, tela, "e continua na lista de fases")

	tela._ao_jogar()
	await get_tree().process_frame
	tela._escolha_de_gato.escolhido.emit(PelagemGato.SIAMES)
	await get_tree().process_frame
	# Depois do gato vem o cenario (ADR 0036); o cenario sugerido ja vem marcado.
	var cenario: EscolhaDeCenario = tela._escolha_de_cenario
	if not afirmar_nao_nulo(cenario, "escolher o gato abre a escolha do cenario"):
		tela.queue_free()
		return
	afirmar_nulo(tela._escolha_de_gato, "e a do gato fecha")
	afirmar_igual(get_tree().current_scene, tela, "a fase ainda nao comecou")
	cenario.escolhido.emit(cenario.em_foco())
	await get_tree().process_frame
	_fase = get_tree().current_scene as FaseBase
	if not afirmar_nao_nulo(_fase, "escolher o cenario poe a fase em jogo"):
		return
	afirmar_igual(_fase.jogador.pelagem(), PelagemGato.SIAMES, "com o gato escolhido")
	afirmar_igual(PelagemGato.preferida(), PelagemGato.SIAMES, "e a escolha fica lembrada")
