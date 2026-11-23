extends CasoDeTeste

## Morte (captura) e volta ao inicio -- o relato de jogo que motivou isto:
## "morri perto do spawn, o cachorro me cercou e ja me matou de novo, e na
## terceira vez ele ja estava em cima de mim".
##
## Tres causas, uma por teste:
##   1. durante a tela de captura os cachorros continuavam replanejando e
##      andando ate o jogador parado;
##   2. um segundo contato durante a propria tela contava outra captura;
##   3. ao voltar ao inicio, os cachorros estavam onde tinham parado (muitas
##      vezes em cima do ponto de entrada), e nao havia janela nenhuma de
##      invulnerabilidade.

var _fase: FaseBase = null


func antes() -> void:
	Telemetria.reiniciar(TransporteMock.new(caminho_temporario("captura.jsonl")),
		caminho_temporario("captura_fila.json"))
	Sessao.iniciar()
	var lido: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_texto(
		JSON.stringify(CarregadorFaseJson._exemplo()))
	_fase = IniciadorDeFase.jogar(get_tree(), lido.config)
	await get_tree().process_frame


func depois() -> void:
	get_tree().paused = false
	if _fase != null and is_instance_valid(_fase):
		_fase.queue_free()
	_fase = null
	if Sessao.ativa:
		Sessao.encerrar()
	await get_tree().process_frame


func _vigia_que_so_persegue() -> Cachorro:
	for alvo: Cachorro in _fase.cachorros:
		if _fase._apenas_persegue(alvo):
			return alvo
	return null


func _esperar_fisica(quadros: int) -> void:
	for i: int in quadros:
		await get_tree().physics_frame


func teste_cachorros_nao_andam_durante_a_tela_de_captura() -> void:
	var vermelho: Cachorro = _vigia_que_so_persegue()
	_fase._ao_encostar_no_jogador(_fase.jogador, vermelho)

	var posicoes: Dictionary = {}
	for alvo: Cachorro in _fase.cachorros:
		posicoes[alvo] = alvo.global_position
	# O tempo inteiro da tela (2,5 s): o replanejamento do A* roda a cada 1 s.
	await _esperar_fisica(150)

	for alvo: Cachorro in _fase.cachorros:
		afirmar_verdadeiro(alvo.global_position.distance_to(posicoes[alvo]) < 0.5,
			"%s ficou parado enquanto a tela de captura estava aberta" % alvo.identificador)


func teste_segundo_contato_durante_a_captura_nao_mata_de_novo() -> void:
	var vermelho: Cachorro = _vigia_que_so_persegue()
	var vidas_antes: int = Sessao.vidas
	_fase._ao_encostar_no_jogador(_fase.jogador, vermelho)
	for alvo: Cachorro in _fase.cachorros:
		_fase._ao_encostar_no_jogador(_fase.jogador, alvo)

	afirmar_igual(Sessao.vidas, vidas_antes - 1, "uma captura custa UMA vida, mesmo cercado")
	afirmar_igual(_fase._capturas, 1, "e conta uma captura so")


func teste_ao_voltar_os_cachorros_voltam_para_o_ponto_deles() -> void:
	var nascimento: Dictionary = {}
	for alvo: Cachorro in _fase.cachorros:
		nascimento[alvo] = alvo.global_position

	# Os cachorros andam um pouco e um deles pega o jogador perto da entrada.
	await _esperar_fisica(90)
	var vermelho: Cachorro = _vigia_que_so_persegue()
	vermelho.global_position = _fase.ponto_de_entrada.global_position
	_fase._ao_encostar_no_jogador(_fase.jogador, vermelho)
	_fase.tela_captura.encerrar_agora()

	var entrada: Vector2 = _fase.ponto_de_entrada.global_position
	afirmar_igual(_fase.jogador.global_position, entrada, "o pacote volta ao inicio")
	for alvo: Cachorro in _fase.cachorros:
		afirmar_verdadeiro(alvo.global_position.distance_to(nascimento[alvo]) < 0.5,
			"%s volta para onde nasceu" % alvo.identificador)
		afirmar_verdadeiro(alvo.global_position.distance_to(entrada) > 48.0,
			"%s nao fica em cima da entrada (mais de 3 tiles)" % alvo.identificador)


func teste_depois_da_captura_ha_invulnerabilidade_curta() -> void:
	var vermelho: Cachorro = _vigia_que_so_persegue()
	var vidas_antes: int = Sessao.vidas
	_fase._ao_encostar_no_jogador(_fase.jogador, vermelho)
	_fase.tela_captura.encerrar_agora()
	await get_tree().process_frame

	afirmar_verdadeiro(_fase.jogador_invulneravel(), "logo depois de voltar, o jogador esta protegido")
	_fase._ao_encostar_no_jogador(_fase.jogador, vermelho)
	afirmar_igual(Sessao.vidas, vidas_antes - 1, "um contato na janela de invulnerabilidade nao mata")
	afirmar_falso(get_tree().paused, "e o jogo voltou a rodar")


func teste_tela_de_captura_pode_ser_fechada_com_enter() -> void:
	var vermelho: Cachorro = _vigia_que_so_persegue()
	_fase._ao_encostar_no_jogador(_fase.jogador, vermelho)
	afirmar_verdadeiro(_fase.tela_captura.visible, "a tela aparece")

	# Enter logo de cara nao fecha: evita pular a explicacao sem querer.
	var enter := InputEventAction.new()
	enter.action = "ui_accept"
	enter.pressed = true
	_fase.tela_captura._input(enter)
	afirmar_verdadeiro(_fase.tela_captura.visible, "Enter no primeiro instante nao pula a explicacao")

	_fase.tela_captura._aberta_em_ms -= 10000
	_fase.tela_captura._input(enter)
	afirmar_falso(_fase.tela_captura.visible, "depois do tempo minimo, Enter continua o jogo")
	afirmar_falso(get_tree().paused, "sem esperar o tempo todo travado")


## Gato piscando (logo depois de uma captura): quem vem atras dele para uma
## celula antes, sem subir em cima do desenho do gato. Fora disso, a rota vai
## ate o gato, como sempre.
func teste_cachorro_nao_pisa_no_gato_que_ele_nao_pode_pegar() -> void:
	var alvo: Cachorro = _fase.cachorros[0]
	var celula_do_gato: Vector2i = _fase.labirinto.local_to_map(_fase.labirinto.to_local(_fase.jogador.global_position))
	var vizinha: Vector2i = celula_do_gato
	for passo: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var dado: TileData = _fase.labirinto.get_cell_tile_data(celula_do_gato + passo)
		if dado != null and not bool(dado.get_custom_data("solido")):
			vizinha = celula_do_gato + passo
			break
	afirmar_verdadeiro(vizinha != celula_do_gato, "o gato tem uma celula livre ao lado")
	var rota := PackedVector2Array([
		_fase.labirinto.to_global(_fase.labirinto.map_to_local(vizinha)),
		_fase.jogador.global_position])

	_fase._invulneravel_ate_ms = 0
	afirmar_igual(_fase._sem_pisar_no_gato(alvo, rota).size(), 2, "pode pegar: a rota vai ate o gato")

	_fase._invulneravel_ate_ms = Time.get_ticks_msec() + 60_000
	var curta: PackedVector2Array = _fase._sem_pisar_no_gato(alvo, rota)
	afirmar_igual(curta.size(), 1, "gato piscando: a rota para uma celula antes")
	afirmar_igual(curta[0], rota[0], "e termina na celula vizinha")
	_fase._invulneravel_ate_ms = 0
