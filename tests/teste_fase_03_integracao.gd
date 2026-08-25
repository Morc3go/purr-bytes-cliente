extends CasoDeTeste

## Critérios de aceite do Marco 3 (seção 8 do CLAUDE.md): SHA-256 validado
## contra vetores oficiais (tests/teste_sha256.gd), e as três fases jogáveis
## em sequência. Este arquivo cobre a fase 3 em si: "hash" e "verificar" pelo
## MESMO resolvedor genérico, e a amostra de desempenho.

var _mock: TransporteMock
var _fase: FaseBase


func _preparar_mock(sufixo: String) -> TransporteMock:
	var mock := TransporteMock.new(caminho_temporario("fase03_mock_%s.jsonl" % sufixo))
	Telemetria.reiniciar(mock, caminho_temporario("fase03_fila_%s.json" % sufixo))
	return mock


func depois() -> void:
	if _fase != null and is_instance_valid(_fase):
		_fase.queue_free()
	_fase = null
	if Sessao.ativa:
		Sessao.encerrar()


func _montar_fase() -> FaseBase:
	Sessao.iniciar()
	var cena: PackedScene = load("res://cenas/fases/fase_03.tscn") as PackedScene
	var fase: FaseBase = cena.instantiate() as FaseBase
	add_child(fase)
	return fase


func teste_fase_03_carrega_configurada() -> void:
	_preparar_mock("carrega")
	_fase = _montar_fase()
	await get_tree().process_frame

	afirmar_falso(_fase.aviso.visible, "FaseConfig gerado por gerar_fase_03.gd e valido")
	afirmar_igual(_fase.configuracao.algoritmo, "SHA256", "fase 3 e SHA-256")
	afirmar_igual(_fase.configuracao.desafios.size(), 4, "quatro desafios: dois de SHA-256 mais as revisoes de Vigenere e Cesar")
	afirmar_nao_nulo(_fase._diretor, "fase 3 tambem tem regioes -- mesmo Diretor generico do Marco 2")


func teste_partida_completa_com_hash_e_verificar() -> void:
	_mock = _preparar_mock("completa")
	_fase = _montar_fase()
	await get_tree().process_frame

	_fase.terminal.comando_submetido.emit("hash pacote!", 300)          # ERRO_LEXICO
	_fase.terminal.comando_submetido.emit("pacote hash", 250)           # ERRO_SINTATICO (falta o VERBO na frente)
	_fase.terminal.comando_submetido.emit("verificar pacote abcdef00", 500)  # ERRO_SEMANTICO: prefixo errado
	_fase.terminal.comando_submetido.emit("hash pacote", 400)           # SUCESSO: so calcula, nao resolve nada
	_fase.terminal.comando_submetido.emit("dica", 200)                  # SUCESSO (dica)

	# Resolve os dois desafios com o digest de verdade.
	var prefixo1: String = Sha256.digest_hex("pacote").substr(0, 8)
	var prefixo2: String = Sha256.digest_hex("mensagem").substr(0, 8)
	_fase.terminal.comando_submetido.emit("verificar pacote %s" % prefixo1, 1800)
	_fase.terminal.comando_submetido.emit("verificar mensagem %s" % prefixo2, 1500)

	await Telemetria.descarregar()

	var registros: Array[Dictionary] = _ler_jsonl(_mock.caminho())
	var tentativas: Array[Dictionary] = _filtrar(registros, "tentativa")

	afirmar_tamanho(tentativas, 7, "uma tentativa_comando por comando digitado (7 comandos)")
	var resultados: PackedStringArray = PackedStringArray()
	for tentativa: Dictionary in tentativas:
		resultados.append(String(tentativa["resultado"]))
	afirmar_igual(resultados, PackedStringArray([
		CatalogoResultados.ERRO_LEXICO, CatalogoResultados.ERRO_SINTATICO,
		CatalogoResultados.ERRO_SEMANTICO, CatalogoResultados.SUCESSO,
		CatalogoResultados.SUCESSO, CatalogoResultados.SUCESSO, CatalogoResultados.SUCESSO,
	]), "um resultado por tentativa, na ordem submetida")

	var eventos: Array[Dictionary] = _filtrar(registros, "evento")
	_afirmar_sequencia_sem_lacuna(eventos)


func teste_painel_de_avalanche_emite_cifra_demonstrada() -> void:
	_mock = _preparar_mock("avalanche")
	_fase = _montar_fase()
	await get_tree().process_frame

	afirmar_falso(_fase.painel_cifra.esta_aberto(), "painel comeca fechado")
	_fase._alternar_painel_de_demonstracao()
	afirmar_verdadeiro(_fase.painel_cifra.esta_aberto(), "abre o painel de avalanche para SHA256")
	_fase._alternar_painel_de_demonstracao()
	afirmar_falso(_fase.painel_cifra.esta_aberto(), "fecha de novo")

	await Telemetria.descarregar()
	var eventos: Array[Dictionary] = _filtrar(_ler_jsonl(_mock.caminho()), "evento")
	afirmar_igual(_contar(_tipos(eventos), CatalogoEventos.CIFRA_DEMONSTRADA), 1,
		"CIFRA_DEMONSTRADA emitido uma vez, so ao abrir")


func teste_amostra_de_desempenho_tem_os_quatro_campos() -> void:
	_mock = _preparar_mock("desempenho")
	_fase = _montar_fase()
	await get_tree().process_frame

	# Nao espera os 30s reais: chama o mesmo callback que o Timer chamaria.
	_fase._ao_vencer_temporizador_de_desempenho()
	await Telemetria.descarregar()

	var eventos: Array[Dictionary] = _filtrar(_ler_jsonl(_mock.caminho()), "evento")
	var amostras: Array[Dictionary] = []
	for evento: Dictionary in eventos:
		if String(evento["tipo_evento"]) == CatalogoEventos.AMOSTRA_DESEMPENHO:
			amostras.append(evento)

	afirmar_tamanho(amostras, 1, "uma amostra de desempenho emitida")
	var payload: Dictionary = amostras[0]["payload"] as Dictionary
	for campo: String in ["fps", "memoria_estatica_bytes", "objetos_desenhados", "replanejamento_medio_ms"]:
		afirmar_verdadeiro(payload.has(campo), "amostra tem o campo '%s'" % campo)
	afirmar_verdadeiro(float(payload["replanejamento_medio_ms"]) >= 0.0,
		"tempo medio de replanejamento nao e negativo")


# ---------------------------------------------------------------------------
# Apoio
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
