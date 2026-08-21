class_name RoteiroDeDemonstracao
extends RefCounted

## Roteiro da sessao de demonstracao (ver tools/sessao_de_demonstracao.gd).
##
## Reproduz uma partida curta da fase 1 do jeito que ela vai acontecer no Marco
## 1, inclusive o caso TC-04 da monografia -- "cyfrar pacote chave=3", que o AFD
## rejeita como ERRO_LEXICO -- seguido do acerto na segunda tentativa. Os corpos
## produzidos aqui sao os exemplos reais de docs/contrato-telemetria.md.
##
## Escreve em user://demonstracao/, nunca no .jsonl da coleta real.

const DIRETORIO: String = "user://demonstracao"


func executar() -> void:
	DirAccess.make_dir_recursive_absolute(DIRETORIO)
	var caminho_mock: String = "%s/telemetria.jsonl" % DIRETORIO
	if FileAccess.file_exists(caminho_mock):
		DirAccess.remove_absolute(caminho_mock)

	Telemetria.reiniciar(TransporteMock.new(caminho_mock), "%s/fila.json" % DIRETORIO)

	var id_sessao: String = Identificador.uuid_v4()
	Telemetria.iniciar_sessao(id_sessao, ConfigJogo.id_sujeito)

	Telemetria.registrar_evento(CatalogoEventos.FASE_INICIADA, {
		"algoritmo": "CESAR",
		"desafios": 1,
		"vidas_iniciais": 3,
	}, 1)

	Telemetria.registrar_evento(CatalogoEventos.COMANDO_SUBMETIDO, {
		"tamanho": 21,
		"tempo_resposta_ms": 4310,
	}, 1)

	Telemetria.registrar_evento(CatalogoEventos.ERRO_LEXICO, {
		"lexema": "cyfrar",
		"posicao": 0,
	}, 1)

	Telemetria.registrar_tentativa(
		1, "cesar-01", "cyfrar pacote chave=3",
		[
			{"tipo": "IDENTIFICADOR", "lexema": "cyfrar", "posicao": 0},
			{"tipo": "IDENTIFICADOR", "lexema": "pacote", "posicao": 7},
			{"tipo": "IDENTIFICADOR", "lexema": "chave", "posicao": 14},
			{"tipo": "ATRIBUICAO", "lexema": "=", "posicao": 19},
			{"tipo": "NUMERO", "lexema": "3", "posicao": 20},
		],
		CatalogoResultados.ERRO_LEXICO, "VERBO_NAO_RECONHECIDO", 4310, 1)

	Telemetria.registrar_tentativa(
		1, "cesar-01", "cifrar pacote chave=3",
		[
			{"tipo": "VERBO", "lexema": "cifrar", "posicao": 0},
			{"tipo": "IDENTIFICADOR", "lexema": "pacote", "posicao": 7},
			{"tipo": "IDENTIFICADOR", "lexema": "chave", "posicao": 14},
			{"tipo": "ATRIBUICAO", "lexema": "=", "posicao": 19},
			{"tipo": "NUMERO", "lexema": "3", "posicao": 20},
		],
		CatalogoResultados.SUCESSO, "", 2180, 2)

	Telemetria.registrar_evento(CatalogoEventos.CACHORRO_DETECTOU, {
		"distancia_celulas": 6,
	}, 1)

	Telemetria.registrar_evento(CatalogoEventos.FASE_CONCLUIDA, {
		"capturas": 0,
		"pontuacao": 150,
		"vidas_restantes": 3,
	}, 1)

	Telemetria.encerrar_sessao()
	await Telemetria.descarregar()

	print("id_sessao: %s" % id_sessao)
	print("arquivo:   %s" % ProjectSettings.globalize_path(caminho_mock))
	print("fila ao final: %s" % JSON.stringify(Telemetria.estatisticas()))
	print("")

	var arquivo: FileAccess = FileAccess.open(caminho_mock, FileAccess.READ)
	while not arquivo.eof_reached():
		var linha: String = arquivo.get_line()
		if not linha.is_empty():
			print(linha)
	arquivo.close()
