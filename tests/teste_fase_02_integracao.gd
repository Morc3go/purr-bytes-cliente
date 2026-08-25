extends CasoDeTeste

## Critérios de aceite do Marco 2 (seção 7 do CLAUDE.md): Vigenère com o MESMO
## parser do Marco 1, painel de demonstração emitindo CIFRA_DEMONSTRADA, e o
## Diretor nunca convergindo para a posição real do jogador sem pista nem
## linha de visão. Monta cenas/fases/fase_02.tscn de verdade (gerado por
## tools/gerar_fase_02.gd).
##
## Cada teste usa seu próprio arquivo de mock (mesma lição do Marco 1: o
## runner só limpa user://testes uma vez para a suíte inteira).

var _mock: TransporteMock
var _fase: FaseBase


func _preparar_mock(sufixo: String) -> TransporteMock:
	var mock := TransporteMock.new(caminho_temporario("fase02_mock_%s.jsonl" % sufixo))
	Telemetria.reiniciar(mock, caminho_temporario("fase02_fila_%s.json" % sufixo))
	return mock


func depois() -> void:
	if _fase != null and is_instance_valid(_fase):
		_fase.queue_free()
	_fase = null
	if Sessao.ativa:
		Sessao.encerrar()


func _montar_fase() -> FaseBase:
	Sessao.iniciar()
	var cena: PackedScene = load("res://cenas/fases/fase_02.tscn") as PackedScene
	var fase: FaseBase = cena.instantiate() as FaseBase
	add_child(fase)
	return fase


func teste_fase_02_carrega_configurada_com_diretor_e_4_regioes() -> void:
	_preparar_mock("carrega")
	_fase = _montar_fase()
	await get_tree().process_frame

	afirmar_falso(_fase.aviso.visible, "FaseConfig gerado por gerar_fase_02.gd e valido")
	afirmar_igual(_fase.configuracao.algoritmo, "VIGENERE", "fase 2 e Vigenere")
	afirmar_igual(_fase.configuracao.desafios.size(), 3, "tres desafios: dois de Vigenere mais a revisao de Cesar do cachorro verde")
	afirmar_igual(_fase.regioes_no.get_child_count(), 4, "4 regioes definidas na cena")
	afirmar_nao_nulo(_fase._diretor, "Diretor criado porque a fase tem regioes")


func teste_partida_completa_com_vigenere_emite_sequencia_esperada() -> void:
	_mock = _preparar_mock("completa")
	_fase = _montar_fase()
	await get_tree().process_frame

	_fase.terminal.comando_submetido.emit("cifrar pacote!", 400)          # ERRO_LEXICO
	_fase.terminal.comando_submetido.emit("pacote chave=gato", 350)       # ERRO_SINTATICO
	_fase.terminal.comando_submetido.emit("cifrar pacote chave=3", 500)   # ERRO_SEMANTICO: chave numerica invalida p/ Vigenere
	_fase.terminal.comando_submetido.emit("dica", 200)                   # SUCESSO (dica), custa pontos

	# Deteccao: cachorro perto do jogador, corredor aberto (fase_02 tambem
	# comeca com o jogador na celula 1,1 -- row1 do labirinto e livre).
	_fase.cachorro.global_position = _fase.jogador.global_position + Vector2(16, 0)
	afirmar_verdadeiro(_fase.cachorro.tem_linha_de_visao(_fase.jogador.global_position),
		"cachorro enxerga o jogador de perto, em corredor aberto")
	_fase._atualizar_deteccao_do_cachorro()

	# Captura em texto claro.
	var vidas_antes: int = Sessao.vidas
	_fase.cachorro.parar()
	_fase.cachorro.global_position = _fase.jogador.global_position
	var capturado: bool = false
	for tentativa: int in 10:
		await get_tree().physics_frame
		if Sessao.vidas < vidas_antes:
			capturado = true
			break
	afirmar_verdadeiro(capturado, "cachorro capturou o jogador em texto claro")

	_fase.cachorro.global_position = Vector2(3000, 3000)
	_fase.tela_captura.encerrada.emit()
	await get_tree().process_frame

	# Resolve os dois desafios em ordem, com chave alfabetica.
	_fase.terminal.comando_submetido.emit("cifrar pacote chave=gato", 1800)
	_fase.terminal.comando_submetido.emit("cifrar servidor chave=rede", 1500)

	await Telemetria.descarregar()

	var registros: Array[Dictionary] = _ler_jsonl(_mock.caminho())
	var eventos: Array[Dictionary] = _filtrar(registros, "evento")
	var tentativas: Array[Dictionary] = _filtrar(registros, "tentativa")
	var tipos: PackedStringArray = _tipos(eventos)

	for esperado: String in [
		CatalogoEventos.SESSAO_INICIADA, CatalogoEventos.FASE_INICIADA,
		CatalogoEventos.ERRO_LEXICO, CatalogoEventos.ERRO_SINTATICO,
		CatalogoEventos.DICA_SOLICITADA, CatalogoEventos.CACHORRO_DETECTOU,
		CatalogoEventos.JOGADOR_CAPTURADO,
	]:
		afirmar_verdadeiro(tipos.has(esperado), "sequencia contem %s" % esperado)

	afirmar_tamanho(tentativas, 6, "uma tentativa_comando por comando digitado (6 comandos)")

	var resultados: PackedStringArray = PackedStringArray()
	for tentativa: Dictionary in tentativas:
		resultados.append(String(tentativa["resultado"]))
	afirmar_igual(resultados, PackedStringArray([
		CatalogoResultados.ERRO_LEXICO, CatalogoResultados.ERRO_SINTATICO,
		CatalogoResultados.ERRO_SEMANTICO, CatalogoResultados.SUCESSO,
		CatalogoResultados.SUCESSO, CatalogoResultados.SUCESSO,
	]), "um resultado por tentativa, na ordem submetida")

	_afirmar_sequencia_sem_lacuna(eventos)


func teste_painel_de_demonstracao_emite_cifra_demonstrada() -> void:
	_mock = _preparar_mock("painel")
	_fase = _montar_fase()
	await get_tree().process_frame

	afirmar_falso(_fase.painel_cifra.esta_aberto(), "painel comeca fechado")

	_fase._alternar_painel_de_demonstracao()
	afirmar_verdadeiro(_fase.painel_cifra.esta_aberto(), "primeira chamada abre o painel")

	_fase._alternar_painel_de_demonstracao()
	afirmar_falso(_fase.painel_cifra.esta_aberto(), "segunda chamada fecha o painel")

	await Telemetria.descarregar()
	var eventos: Array[Dictionary] = _filtrar(_ler_jsonl(_mock.caminho()), "evento")
	afirmar_igual(_contar(_tipos(eventos), CatalogoEventos.CIFRA_DEMONSTRADA), 1,
		"CIFRA_DEMONSTRADA emitido uma vez, so ao ABRIR (fechar nao reemite)")


func teste_diretor_nao_converge_para_posicao_real_sem_pista_nem_visao() -> void:
	_preparar_mock("sem_pista")
	_fase = _montar_fase()
	await get_tree().process_frame

	# Cachorro longe (sem linha de visao) e nenhuma pista foi dada ainda --
	# o alvo tem que vir do Diretor (crenca), nunca da posicao exata do jogador.
	_fase.cachorro.parar()
	_fase.cachorro.global_position = Vector2(3000, 3000)

	var alvo: Vector2 = _fase._alvo_de_perseguicao(_fase.cachorro)
	afirmar_igual(alvo, _fase._diretor.alvo_atual(), "alvo vem do Diretor, nao do jogador")
	afirmar_diferente(alvo, _fase.jogador.global_position,
		"sem pista nem visao, o alvo nao e a posicao exata do jogador")

	# O jogador anda para varios pontos, ainda sem cruzar fronteira de regiao
	# nem visao do cachorro -- o alvo tem que continuar parado no mesmo lugar.
	for deslocamento: Vector2 in [Vector2(4, 0), Vector2(0, 6), Vector2(-3, 2)]:
		_fase.jogador.global_position += deslocamento
		var novo_alvo: Vector2 = _fase._alvo_de_perseguicao(_fase.cachorro)
		afirmar_igual(novo_alvo, alvo,
			"o jogador se moveu dentro da mesma regiao, mas o alvo do cachorro nao mudou")


func teste_comando_errado_gera_pista_para_a_regiao_do_jogador() -> void:
	_preparar_mock("pista_comando")
	_fase = _montar_fase()
	await get_tree().process_frame

	# Simula o jogador fisicamente numa regiao conhecida (sem depender de
	# quantos passos de fisica um overlap de Area2D levaria para registrar --
	# o overlap em si ja e coberto pelo teste do Diretor e pela partida
	# completa; aqui o alvo e a CONSEQUENCIA de uma pista forte).
	var regiao_alvo: Area2D = _fase.regioes_no.get_child(3) as Area2D  # RegiaoSudeste
	_fase._regiao_atual_do_jogador = regiao_alvo

	_fase.terminal.comando_submetido.emit("cifrar pacote chave=1", 300)  # chave numerica: ERRO_SEMANTICO

	afirmar_igual(_fase._diretor.regiao_mais_provavel(), regiao_alvo,
		"comando errado empurra a crenca do Diretor para a regiao onde o jogador estava")


func teste_linha_de_visao_sobrepoe_o_alvo_do_diretor() -> void:
	_preparar_mock("visao_sobrepoe")
	_fase = _montar_fase()
	await get_tree().process_frame

	# Forca o Diretor a apontar para uma regiao diferente de onde o jogador
	# realmente esta.
	var regiao_distante: Area2D = _fase.regioes_no.get_child(3) as Area2D  # RegiaoSudeste
	_fase._diretor.pista_comando_errado(regiao_distante)
	afirmar_igual(_fase._diretor.regiao_mais_provavel(), regiao_distante, "Diretor aponta para longe do jogador")

	# Mas com linha de visao direta, o alvo tem que ser a posicao real --
	# "ver o jogador de verdade" sempre vence a crenca.
	_fase.cachorro.parar()
	_fase.cachorro.global_position = _fase.jogador.global_position + Vector2(16, 0)
	afirmar_igual(_fase._alvo_de_perseguicao(_fase.cachorro), _fase.jogador.global_position,
		"linha de visao direta sobrepoe o alvo do Diretor")


# ---------------------------------------------------------------------------
# Apoio (mesma leitura de .jsonl que tests/teste_fase_01_integracao.gd usa)
# ---------------------------------------------------------------------------

func _ler_jsonl(caminho: String) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	if not FileAccess.file_exists(caminho):
		falhar("arquivo do modo MOCK nao foi criado: %s" % caminho)
		return saida
	var arquivo: FileAccess = FileAccess.open(caminho, FileAccess.READ)
	while not arquivo.eof_reached():
		var linha: String = arquivo.get_line().strip_edges()
		if linha.is_empty():
			continue
		var lido: Variant = JSON.parse_string(linha)
		if typeof(lido) != TYPE_DICTIONARY:
			continue
		saida.append(lido as Dictionary)
	arquivo.close()
	return saida


func _filtrar(registros: Array[Dictionary], tipo: String) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	for registro: Dictionary in registros:
		if String(registro.get("tipo_registro", "")) == tipo:
			saida.append(registro["dados"] as Dictionary)
	return saida


func _tipos(eventos: Array[Dictionary]) -> PackedStringArray:
	var saida := PackedStringArray()
	for evento: Dictionary in eventos:
		saida.append(String(evento["tipo_evento"]))
	return saida


func _contar(lista: PackedStringArray, alvo: String) -> int:
	var total: int = 0
	for item: String in lista:
		if item == alvo:
			total += 1
	return total


func _afirmar_sequencia_sem_lacuna(eventos: Array[Dictionary]) -> void:
	var esperada: int = 0
	for evento: Dictionary in eventos:
		var sequencia: int = int(evento["sequencia"])
		if sequencia != esperada:
			falhar("lacuna na sequencia: esperado %d, obtido %d (evento %s)"
				% [esperada, sequencia, evento["tipo_evento"]])
			return
		esperada += 1
	afirmar_verdadeiro(true, "sequencia contigua de 0 a %d" % maxi(0, esperada - 1))
