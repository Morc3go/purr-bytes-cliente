extends CasoDeTeste

## Criterio de aceite do Marco 1 (secao 6 do CLAUDE.md): uma partida completa em
## modo MOCK emite, com sequencia sem lacuna, SESSAO_INICIADA, FASE_INICIADA,
## COMANDO_SUBMETIDO implicito em cada tentativa, ERRO_LEXICO/ERRO_SINTATICO
## quando couber, CACHORRO_DETECTOU, JOGADOR_CAPTURADO quando ocorrer, e uma
## tentativa_comando por comando digitado.
##
## Monta cenas/fases/fase_01.tscn de verdade (gerado por tools/gerar_fase_01.gd)
## e aciona o pipeline pelo mesmo caminho que o jogador usa: o sinal publico
## Terminal.comando_submetido, nao um metodo interno de FaseBase.

var _mock: TransporteMock
var _fase: FaseBase


## Cada teste usa seu proprio arquivo de mock (sufixo distinto): o runner so
## limpa user://testes UMA VEZ no inicio da suite inteira (nao entre metodos), e
## reiniciar() nao apaga o .jsonl anterior -- so o estado em memoria. Reusar o
## mesmo nome faria um teste ler eventos deixados por outro.
func _preparar_mock(sufixo: String) -> TransporteMock:
	var mock := TransporteMock.new(caminho_temporario("fase01_mock_%s.jsonl" % sufixo))
	Telemetria.reiniciar(mock, caminho_temporario("fase01_fila_%s.json" % sufixo))
	return mock


func depois() -> void:
	if _fase != null and is_instance_valid(_fase):
		_fase.queue_free()
	_fase = null
	if Sessao.ativa:
		Sessao.encerrar()


func _montar_fase() -> FaseBase:
	Sessao.iniciar()
	var cena: PackedScene = load("res://cenas/fases/fase_01.tscn") as PackedScene
	var fase: FaseBase = cena.instantiate() as FaseBase
	add_child(fase)
	return fase


func teste_fase_01_carrega_configurada_e_jogavel() -> void:
	_preparar_mock("carrega")
	_fase = _montar_fase()
	await get_tree().process_frame

	afirmar_falso(_fase.aviso.visible, "FaseConfig gerado por gerar_fase_01.gd e valido")
	afirmar_igual(_fase.configuracao.desafios.size(), 2, "dois desafios de Cesar")
	afirmar_igual(_fase.jogador.global_position, _fase.ponto_de_entrada.global_position,
		"jogador comeca no ponto de entrada")
	afirmar_verdadeiro(_fase.cachorro.caminho_atual().size() > 0,
		"o primeiro replanejamento ja roda no _ready, sem esperar o temporizador")


func teste_partida_completa_emite_sequencia_esperada() -> void:
	_mock = _preparar_mock("completa")
	_fase = _montar_fase()
	await get_tree().process_frame

	# 1. Comando lexicamente invalido.
	_fase.terminal.comando_submetido.emit("cifrar pacote!", 400)
	# 2. Comando sintaticamente invalido (falta o verbo).
	_fase.terminal.comando_submetido.emit("pacote chave=3", 350)
	# 3. Chave fora da faixa da fase (1..25) -- ERRO_SEMANTICO.
	_fase.terminal.comando_submetido.emit("cifrar pacote chave=99", 500)
	# 4. Dica: nao resolve o desafio, custa pontos, emite DICA_SOLICITADA.
	_fase.terminal.comando_submetido.emit("dica", 200)

	# 5. Cachorro enxerga o jogador: corredor aberto (linha 1 do labirinto),
	#    uma celula ao lado -- dentro do alcance e sem parede no meio.
	#    tem_linha_de_visao() e puro (forca o RayCast2D a atualizar na hora),
	#    entao chamar direto evita depender de quantos passos de fisica um
	#    "await physics_frame" cobre de fato neste ambiente -- o timestep fixo
	#    do Godot pode processar varios passos de uma vez quando o processo
	#    fica um tempo sem ceder o controle (por exemplo por causa de I/O),
	#    o que tornaria uma asserção de "exatamente um quadro" instavel.
	_fase.cachorro.global_position = _fase.jogador.global_position + Vector2(16, 0)
	afirmar_verdadeiro(_fase.cachorro.tem_linha_de_visao(_fase.jogador.global_position),
		"cachorro enxerga o jogador de perto, em corredor aberto")
	_fase._atualizar_deteccao_do_cachorro()
	afirmar_verdadeiro(_fase._cachorro_com_linha_de_visao,
		"fase_base registra a deteccao (CACHORRO_DETECTOU sera emitido)")

	# 6. Captura: cachorro encosta no jogador, que ainda esta em texto claro.
	#    O overlap do Area2D so e confirmado depois de um passo de fisica de
	#    verdade -- por isso este e o unico trecho que ainda espera quadros,
	#    em loop limitado para tolerar quantos passos o ambiente processar.
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

	# Tira o cachorro de perto antes de fechar a tela de captura: senao o
	# proprio overlap que acabou de capturar continuaria valendo apos
	# _ao_terminar_captura() repor o jogador no ponto de entrada (mesma
	# celula), gerando uma segunda captura indesejada pelo teste.
	_fase.cachorro.global_position = Vector2(2000, 2000)
	_fase.tela_captura.encerrada.emit()  # equivale ao temporizador da tela vencer
	await get_tree().process_frame

	# 7. Resolve os dois desafios em ordem -- so agora, depois da captura, para
	#    a captura acontecer de proposito em texto claro.
	_fase.terminal.comando_submetido.emit("cifrar pacote chave=3", 1800)
	_fase.terminal.comando_submetido.emit("cifrar rede chave=5", 1500)

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


func teste_abandonar_com_desafio_ativo_registra_tentativa_abandono() -> void:
	_mock = _preparar_mock("abandono")
	_fase = _montar_fase()
	await get_tree().process_frame

	_fase.abandonar()
	await Telemetria.descarregar()

	var tentativas: Array[Dictionary] = _filtrar(_ler_jsonl(_mock.caminho()), "tentativa")
	afirmar_tamanho(tentativas, 1, "abandonar com desafio ativo gera uma tentativa")
	afirmar_igual(String(tentativas[0]["resultado"]), CatalogoResultados.ABANDONO, "resultado ABANDONO")


# ---------------------------------------------------------------------------
# Apoio (mesma leitura de .jsonl que tests/teste_telemetria.gd usa)
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
