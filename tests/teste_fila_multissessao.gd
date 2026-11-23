extends CasoDeTeste

## A fila precisa guardar MAIS DE UMA sessao ao mesmo tempo sem perder nada.
##
## Acontece na sala de aula: a rede cai, o aluno termina uma partida e comeca
## outra -- ou o jogo trava e e reaberto ainda sem rede. Quando a rede volta, a
## fila tem a sessao anterior e a nova. Se a abertura da anterior tiver sido
## sobrescrita, ou se um lote misturar as duas, a API responde 400 (sessao
## inexistente / id_sessao da rota diferente do evento) e o cliente DESCARTA o
## lote: a partida anterior some do banco.
##
## O transporte daqui aplica as mesmas regras que o back-end aplica (ver
## EventoIngestaoService e SessaoIngestaoService em back/), para o teste falhar
## pelos mesmos motivos que a coleta real falharia.


class TransporteComRegrasDaApi extends TransporteTelemetria:
	var no_ar: bool = false
	var abertas: Dictionary = {}       # id_sessao -> true
	var encerradas: Dictionary = {}    # id_sessao -> status
	var eventos_por_sessao: Dictionary = {}  # id_sessao -> Array de id_evento
	var tentativas_por_sessao: Dictionary = {}
	var recusas: PackedStringArray = []

	func rotulo() -> String:
		return "API-SIMULADA"

	func enviar(pacote: Dictionary) -> ResultadoEnvio:
		await _ceder_quadro()
		if not no_ar:
			return ResultadoEnvio.falha_transitoria("rede fora no teste")

		var id_rota: String = String(pacote["id_sessao"])
		match String(pacote["rota"]):
			ROTA_ABRIR_SESSAO:
				abertas[String(pacote["corpo"]["id_sessao"])] = true
			ROTA_EVENTOS, ROTA_TENTATIVAS:
				var chave: String = "eventos" if pacote.has("eventos") else "tentativas"
				var destino: Dictionary = eventos_por_sessao if chave == "eventos" else tentativas_por_sessao
				for item: Dictionary in pacote[chave]:
					if String(item["id_sessao"]) != id_rota:
						return _recusar("id_sessao da rota nao bate com o de um item do lote")
				if not abertas.has(id_rota):
					return _recusar("sessao inexistente; abra a sessao antes de enviar %s" % chave)
				var ids: Array = destino.get(id_rota, [])
				for item: Dictionary in pacote[chave]:
					ids.append(String(item["id_%s" % ("evento" if chave == "eventos" else "tentativa")]))
				destino[id_rota] = ids
			ROTA_ENCERRAR_SESSAO:
				if not abertas.has(id_rota):
					return _recusar("sessao inexistente; abra a sessao antes de encerra-la")
				encerradas[id_rota] = String(pacote["corpo"]["status"])
		return ResultadoEnvio.ok()

	func _recusar(motivo: String) -> ResultadoEnvio:
		recusas.append(motivo)
		return ResultadoEnvio.falha_permanente("HTTP 400: " + motivo)


var _lote_original: int
var _intervalo_original: float
var _nivel_original: String


func antes() -> void:
	_lote_original = ConfigJogo.tamanho_lote
	_intervalo_original = ConfigJogo.intervalo_envio_s
	_nivel_original = Registro.nome_do_nivel()
	ConfigJogo.tamanho_lote = 500
	ConfigJogo.intervalo_envio_s = 3600.0
	Registro.definir_nivel_por_nome("SILENCIO")


func depois() -> void:
	ConfigJogo.tamanho_lote = _lote_original
	ConfigJogo.intervalo_envio_s = _intervalo_original
	Registro.definir_nivel_por_nome(_nivel_original)


func teste_duas_sessoes_sem_rede_chegam_inteiras() -> void:
	var api := TransporteComRegrasDaApi.new()
	Telemetria.reiniciar(api, caminho_temporario("fila_duas_sessoes.json"))

	# Rede fora a aula inteira: duas partidas seguidas na mesma maquina.
	var sessao_a: String = Identificador.uuid_v4()
	Telemetria.iniciar_sessao(sessao_a, Identificador.uuid_v4())
	for i: int in 3:
		Telemetria.registrar_evento(CatalogoEventos.COMANDO_SUBMETIDO, {"indice": i}, 1)
	Telemetria.registrar_tentativa(1, "cesar-01", "cifrar pacote chave=3", [],
		CatalogoResultados.SUCESSO, "", 900, 1)
	Telemetria.encerrar_sessao()
	await Telemetria.descarregar()

	var sessao_b: String = Identificador.uuid_v4()
	Telemetria.iniciar_sessao(sessao_b, Identificador.uuid_v4())
	for i: int in 2:
		Telemetria.registrar_evento(CatalogoEventos.COMANDO_SUBMETIDO, {"indice": i}, 1)
	Telemetria.encerrar_sessao()
	await Telemetria.descarregar()

	# A rede volta.
	api.no_ar = true
	await _drenar()

	_afirmar_sessao_completa(api, sessao_a, 5, 1, "ENCERRADA")  # INICIADA + 3 + ENCERRADA
	_afirmar_sessao_completa(api, sessao_b, 4, 0, "ENCERRADA")  # INICIADA + 2 + ENCERRADA
	afirmar_tamanho(api.recusas, 0, "a API nao recusou nenhum lote: %s" % ", ".join(api.recusas))
	afirmar_igual(int(Telemetria.estatisticas()["itens_descartados"]), 0, "nada descartado")


func teste_travamento_e_nova_sessao_sem_rede_nao_perde_a_anterior() -> void:
	var caminho_fila: String = caminho_temporario("fila_travamento.json")
	var api := TransporteComRegrasDaApi.new()
	Telemetria.reiniciar(api, caminho_fila)

	# Partida em andamento, rede fora, e o jogo morre sem encerrar.
	var sessao_a: String = Identificador.uuid_v4()
	Telemetria.iniciar_sessao(sessao_a, Identificador.uuid_v4())
	Telemetria.registrar_evento(CatalogoEventos.FASE_INICIADA, {}, 1)
	await Telemetria.descarregar()

	# Reabre ainda sem rede: a sessao A vira ABANDONADA e o aluno joga outra.
	var api_reaberta := TransporteComRegrasDaApi.new()
	Telemetria.reiniciar(api_reaberta, caminho_fila)
	Telemetria.recuperar_fila()
	var sessao_b: String = Identificador.uuid_v4()
	Telemetria.iniciar_sessao(sessao_b, Identificador.uuid_v4())
	Telemetria.registrar_evento(CatalogoEventos.FASE_INICIADA, {}, 1)
	await Telemetria.descarregar()

	api_reaberta.no_ar = true
	await _drenar()

	# A: INICIADA + FASE_INICIADA + ABANDONADA. B ainda esta aberta (sem encerrar).
	_afirmar_sessao_completa(api_reaberta, sessao_a, 3, 0, "ABANDONADA")
	afirmar_verdadeiro(api_reaberta.abertas.has(sessao_b), "a sessao nova foi aberta no banco")
	afirmar_tamanho(api_reaberta.eventos_por_sessao.get(sessao_b, []), 2,
		"os eventos da sessao nova chegaram")
	afirmar_tamanho(api_reaberta.recusas, 0,
		"a API nao recusou nenhum lote: %s" % ", ".join(api_reaberta.recusas))
	afirmar_igual(int(Telemetria.estatisticas()["itens_descartados"]), 0, "nada descartado")


func teste_fila_gravada_pela_versao_anterior_ainda_e_lida() -> void:
	# Maquinas da sala podem ter uma fila gravada pelo build anterior (versao 1,
	# uma abertura e um encerramento soltos). Ignorar o arquivo seria perder a
	# coleta que esta presa nele.
	var caminho_fila: String = caminho_temporario("fila_versao_1.json")
	var id_sessao: String = Identificador.uuid_v4()
	var antiga: Dictionary = {
		"versao": 1,
		"id_sessao": id_sessao,
		"sequencia": 1,
		"sessao_aberta": false,
		"abertura_pendente": {"id_sessao": id_sessao, "id_sujeito": Identificador.uuid_v4(),
			"versao_jogo": "0.1.0", "plataforma": "Windows", "iniciada_em": "2026-10-01T10:00:00.000Z"},
		"encerramento_pendente": {"id_sessao": id_sessao, "status": "ENCERRADA",
			"encerrada_em": "2026-10-01T10:05:00.000Z"},
		"eventos": [{"id_evento": Identificador.uuid_v4(), "id_sessao": id_sessao, "sequencia": 0,
			"tipo_evento": "SESSAO_INICIADA", "id_fase": null, "titulo_fase": null, "fase": null,
			"ocorrido_em": "2026-10-01T10:00:00.000Z", "payload": {}}],
		"tentativas": [],
		"itens_descartados": 0,
	}
	var arquivo: FileAccess = FileAccess.open(caminho_fila, FileAccess.WRITE)
	arquivo.store_string(JSON.stringify(antiga))
	arquivo.close()

	var api := TransporteComRegrasDaApi.new()
	api.no_ar = true
	Telemetria.reiniciar(api, caminho_fila)
	Telemetria.recuperar_fila()
	await _drenar()

	_afirmar_sessao_completa(api, id_sessao, 1, 0, "ENCERRADA")
	afirmar_tamanho(api.recusas, 0, "a API nao recusou nenhum lote")


# ---------------------------------------------------------------------------
# Apoio
# ---------------------------------------------------------------------------

func _afirmar_sessao_completa(api: TransporteComRegrasDaApi, id_sessao: String,
		eventos: int, tentativas: int, status: String) -> void:
	var rotulo: String = id_sessao.substr(0, 8)
	afirmar_verdadeiro(api.abertas.has(id_sessao), "sessao %s aberta no banco" % rotulo)
	afirmar_tamanho(api.eventos_por_sessao.get(id_sessao, []), eventos,
		"todos os eventos da sessao %s chegaram" % rotulo)
	afirmar_tamanho(api.tentativas_por_sessao.get(id_sessao, []), tentativas,
		"todas as tentativas da sessao %s chegaram" % rotulo)
	afirmar_igual(String(api.encerradas.get(id_sessao, "")), status,
		"sessao %s encerrada como %s" % [rotulo, status])


func _drenar() -> void:
	for i: int in 50:
		await Telemetria.descarregar()
		if Telemetria.fila_vazia():
			return
		await get_tree().process_frame
	falhar("a fila nao drenou em 50 tentativas")
