class_name RoteiroDeDemonstracao
extends RefCounted

## Roteiro da sessao de demonstracao (ver tools/sessao_de_demonstracao.gd).
##
## Monta cenas/fases/fase_01.tscn de verdade e aciona o pipeline pelo mesmo
## caminho que o jogador usa (o sinal Terminal.comando_submetido) -- os corpos
## produzidos aqui sao REAIS, nao hand-typed, e viram os exemplos de
## docs/contrato-telemetria.md. Reexecutar isto depois de qualquer mudanca no
## analisador, no resolvedor ou no catalogo de eventos regenera os exemplos
## automaticamente, em vez de deixar a documentacao divergir da implementacao
## (foi exatamente isso que aconteceu com a versao anterior deste arquivo:
## escrita a mao no Marco 0, antes do analisador existir, e desatualizada
## desde entao -- inclusive classificando o caso TC-04 como ERRO_LEXICO, que
## a decisao de ADR 0006 corrigiu para ERRO_SINTATICO).
##
## Inclui o caso TC-04 da monografia ("cyfrar pacote chave=3"), captura e
## acerto -- em modo MOCK. Escreve em user://demonstracao/, nunca no .jsonl da
## coleta real.

const DIRETORIO: String = "user://demonstracao"


func executar() -> void:
	DirAccess.make_dir_recursive_absolute(DIRETORIO)
	var caminho_mock: String = "%s/telemetria.jsonl" % DIRETORIO
	if FileAccess.file_exists(caminho_mock):
		DirAccess.remove_absolute(caminho_mock)

	Telemetria.reiniciar(TransporteMock.new(caminho_mock), "%s/fila.json" % DIRETORIO)

	var id_sessao: String = Sessao.iniciar()

	var arvore: SceneTree = Engine.get_main_loop() as SceneTree
	var cena: PackedScene = load("res://cenas/fases/fase_01.tscn") as PackedScene
	var fase: FaseBase = cena.instantiate() as FaseBase
	arvore.root.add_child(fase)
	await arvore.process_frame

	# TC-04 (monografia): "cyfrar" nao e reconhecido como VERBO -- ver ADR 0006.
	fase.terminal.comando_submetido.emit("cyfrar pacote chave=3", 4310)
	# Um caractere fora do alfabeto -- ERRO_LEXICO de verdade, para diferenciar
	# do caso acima.
	fase.terminal.comando_submetido.emit("cifrar pacote!", 1200)

	# Cachorro perto do jogador: detecta, depois encosta em texto claro.
	fase.cachorro.global_position = fase.jogador.global_position + Vector2(16, 0)
	fase._atualizar_deteccao_do_cachorro()
	fase.cachorro.parar()
	fase.cachorro.global_position = fase.jogador.global_position
	for _tentativa: int in 10:
		await arvore.physics_frame
		if Sessao.vidas < fase.configuracao.vidas_iniciais:
			break
	fase.cachorro.global_position = Vector2(2000, 2000)
	fase.tela_captura.encerrada.emit()
	await arvore.process_frame

	# Acerto na segunda tentativa do mesmo desafio.
	fase.terminal.comando_submetido.emit("cifrar pacote chave=3", 2180)

	Sessao.encerrar()
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

	fase.queue_free()
	await arvore.process_frame
