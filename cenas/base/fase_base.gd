class_name FaseBase
extends Node2D

## CENA PAI de todas as fases. Nao e jogavel sozinha.
##
## Aqui mora toda a logica de fase; as fases concretas (cenas/fases/fase_0N.tscn)
## sao cenas herdadas que trazem apenas dois dados: o FaseConfig atribuido no
## Inspector e o labirinto desenhado no TileMapLayer. O objetivo declarado na
## monografia -- "adicionar fases com baixo esforco de codificacao, atraves do
## uso de matrizes de dados" -- se cumpre ou se perde neste arquivo.
##
## Regra de ouro: se a mesma linha for necessaria em fase_01 e fase_02, ela
## pertence a este arquivo. Se uma fase precisar de script proprio, a
## generalizacao falhou e o conserto e aqui, nao la.

signal fase_concluida(numero: int)
signal fase_abandonada(numero: int)

const CENA_DO_MENU: String = "res://cenas/ui/menu_principal.tscn"

## O unico ponto de configuracao de uma fase. Sem ele a cena nao roda -- e isso
## e proposital: fase_base.tscn aberta direto no editor tem que falhar com
## mensagem clara, nao rodar meio funcionando.
@export var configuracao: FaseConfig

@onready var labirinto: TileMapLayer = $Labirinto
@onready var jogador: Jogador = $Jogador
@onready var cachorro: Cachorro = $Cachorro
@onready var camera: Camera2D = $CameraJogador
@onready var marcadores: Node2D = $Marcadores
@onready var ponto_de_entrada: Marker2D = $Marcadores/PontoDeEntrada
@onready var ponto_de_saida: Area2D = $Marcadores/PontoDeSaida
@onready var hud: Hud = $Hud
@onready var terminal: Terminal = $Terminal
@onready var tela_captura: TelaCaptura = $TelaCaptura
@onready var aviso: CanvasLayer = $AvisoDeConfiguracao
@onready var _rotulo_do_aviso: Label = $AvisoDeConfiguracao/Fundo/Texto

var _configurada: bool = false
var _encerrada: bool = false
var _capturas: int = 0

## IA de perseguicao (scripts/ia/navegacao.gd, wrapper de AStarGrid2D). Uma
## instancia por fase porque a grade depende do labirinto desta cena.
var _navegacao: Navegacao = Navegacao.new()
var _temporizador_replanejamento: Timer = null
var _cachorro_com_linha_de_visao: bool = false
var _depuracao_astar_visivel: bool = false

## Progresso do terminal. Marco 1 nao tem "escolher desafio": os desafios de
## FaseConfig.desafios sao resolvidos em ordem -- e a decisao mais simples que
## atende Cesar e Vigenere sem mudar (docs/decisoes/0007-marco1-cachorro-e-desafios.md).
var _indice_desafio: int = 0
var _numero_tentativa_do_desafio: int = 1


func _ready() -> void:
	aviso.visible = false

	var problema: String = _diagnosticar()
	if problema != "":
		_falhar(problema)
		return

	_configurada = true
	_conectar_sinais()

	jogador.reposicionar(ponto_de_entrada.global_position)
	jogador.velocidade = maxf(jogador.velocidade, 1.0)
	cachorro.velocidade = configuracao.velocidade_cachorro
	cachorro.alcance_deteccao = configuracao.alcance_deteccao_cachorro

	_navegacao.configurar(labirinto)
	_configurar_temporizador_replanejamento()
	_replanejar_caminho_do_cachorro()

	Sessao.entrar_na_fase(configuracao.numero, configuracao.vidas_iniciais)
	hud.definir_titulo("fase %d -- %s" % [configuracao.numero, configuracao.titulo])

	Telemetria.registrar_evento(CatalogoEventos.FASE_INICIADA, {
		"algoritmo": configuracao.algoritmo,
		"desafios": configuracao.desafios.size(),
		"vidas_iniciais": configuracao.vidas_iniciais,
	}, configuracao.numero)

	if configuracao.briefing_pedagogico != "":
		terminal.escrever(configuracao.briefing_pedagogico)
	var desafio_inicial: DesafioConfig = _desafio_atual()
	if desafio_inicial != null:
		terminal.escrever("desafio: %s" % desafio_inicial.enunciado)


func _physics_process(_delta: float) -> void:
	if not _configurada:
		return
	# A camera segue o jogador por posicao, e nao por parentesco, para o Marco 1
	# poder aplicar limites (limit_left/right) vindos do tamanho do labirinto sem
	# mexer na cena do jogador.
	camera.global_position = jogador.global_position
	_atualizar_deteccao_do_cachorro()


func _draw() -> void:
	# Depuracao visual obrigatoria (secao 6 do CLAUDE.md, apontamento 7): F3
	# mostra o caminho que o AStarGrid2D calculou por ultimo. Os "nos
	# expandidos" do algoritmo NAO aparecem aqui de proposito -- AStarGrid2D
	# nao expoe o conjunto fechado pela API publica, e astar_referencia.gd (que
	# expoe) e explicitamente vetada para uso em runtime pela secao 2 do
	# CLAUDE.md. Registrado como pendencia no relatorio de fim de marco.
	if not _depuracao_astar_visivel:
		return

	var caminho: PackedVector2Array = cachorro.caminho_atual()
	if caminho.size() < 2:
		return

	var pontos_locais := PackedVector2Array()
	for ponto: Vector2 in caminho:
		pontos_locais.append(to_local(ponto))

	const COR_CAMINHO: Color = Color(1.0, 0.3, 0.3, 0.9)
	draw_polyline(pontos_locais, COR_CAMINHO, 1.5)
	for ponto_local: Vector2 in pontos_locais:
		draw_circle(ponto_local, 2.0, COR_CAMINHO)


func _unhandled_input(evento: InputEvent) -> void:
	if not _configurada or _encerrada:
		return

	if evento.is_action_pressed("alternar_depuracao"):
		_depuracao_astar_visivel = not _depuracao_astar_visivel
		queue_redraw()
		get_viewport().set_input_as_handled()
		return

	if evento.is_action_pressed("abrir_terminal"):
		if terminal.esta_aberto():
			terminal.fechar()
		else:
			terminal.abrir()
		get_viewport().set_input_as_handled()
		return

	if evento.is_action_pressed("pausar"):
		if terminal.esta_aberto():
			terminal.fechar()
		else:
			abandonar()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# Ciclo da fase
# ---------------------------------------------------------------------------

func concluir() -> void:
	if _encerrada or not _configurada:
		return
	_encerrada = true
	Telemetria.registrar_evento(CatalogoEventos.FASE_CONCLUIDA, {
		"capturas": _capturas,
		"pontuacao": Sessao.pontuacao,
		"vidas_restantes": Sessao.vidas,
	}, configuracao.numero)
	Sessao.sair_da_fase()
	fase_concluida.emit(configuracao.numero)
	_voltar_ao_menu()


func abandonar() -> void:
	if _encerrada or not _configurada:
		return
	_encerrada = true

	# Desafio deixado pra tras sem solucao: registra ABANDONO nessa tentativa
	# em vez de simplesmente nao gerar nenhuma linha. E o unico gatilho de
	# gameplay deste marco para o resultado ABANDONO -- documentado em
	# docs/decisoes/0007-marco1-cachorro-e-desafios.md junto com a pendencia de
	# TIMEOUT (sem mecanica de prazo por desafio especificada ate aqui).
	var desafio_atual: DesafioConfig = _desafio_atual()
	if desafio_atual != null:
		Telemetria.registrar_tentativa(
			configuracao.numero, desafio_atual.identificador, "", [],
			CatalogoResultados.ABANDONO, "", 0, _numero_tentativa_do_desafio)

	Telemetria.registrar_evento(CatalogoEventos.FASE_ABANDONADA, {
		"capturas": _capturas,
		"pontuacao": Sessao.pontuacao,
	}, configuracao.numero)
	Sessao.sair_da_fase()
	fase_abandonada.emit(configuracao.numero)
	_voltar_ao_menu()


func _conectar_sinais() -> void:
	jogador.protecao_alterada.connect(hud.mostrar_protecao)
	cachorro.contato_com_jogador.connect(_ao_encostar_no_jogador)
	terminal.comando_submetido.connect(_ao_submeter_comando)
	terminal.aberto.connect(func() -> void: jogador.definir_entrada_habilitada(false))
	terminal.fechado.connect(func() -> void: jogador.definir_entrada_habilitada(true))
	tela_captura.encerrada.connect(_ao_terminar_captura)
	ponto_de_saida.body_entered.connect(_ao_chegar_na_saida)
	Sessao.vidas_esgotadas.connect(_ao_esgotar_vidas)


func _ao_chegar_na_saida(corpo: Node2D) -> void:
	if corpo is Jogador:
		concluir()


## Contato so intercepta se o pacote estiver em texto claro. Com a cifra ativa o
## cachorro passa por cima sem entender nada -- que e exatamente a licao da fase.
func _ao_encostar_no_jogador(_corpo: Node2D) -> void:
	if _encerrada or jogador.protecao_ativa:
		return

	_capturas += 1
	Telemetria.registrar_evento(CatalogoEventos.JOGADOR_CAPTURADO, {
		"protecao_ativa": false,
		"captura_numero": _capturas,
	}, configuracao.numero)

	Sessao.perder_vida()
	Sessao.somar_pontos(-configuracao.penalidade_captura)
	jogador.definir_entrada_habilitada(false)
	cachorro.parar()
	tela_captura.mostrar(
		"pacote interceptado",
		"o pacote viajava em texto claro. use o terminal para cifrar antes de atravessar.")


func _ao_terminar_captura() -> void:
	jogador.reposicionar(ponto_de_entrada.global_position)
	jogador.cancelar_protecao()
	jogador.definir_entrada_habilitada(true)


func _ao_esgotar_vidas() -> void:
	if _encerrada:
		return
	# Vidas zeradas reinicia a fase; nao expulsa do jogo (secao 7 do CLAUDE.md).
	Sessao.repor_vidas(configuracao.vidas_iniciais)
	terminal.escrever("vidas esgotadas. a fase recomeca -- o pacote volta ao inicio.")


# ---------------------------------------------------------------------------
# Terminal: pipeline lexico -> sintatico -> semantico
# ---------------------------------------------------------------------------

## ERRO_LEXICO e ERRO_SINTATICO sao veredito final de AnalisadorComando; so
## quando os dois passam e que ResolvedorComando entra para decidir SUCESSO vs
## ERRO_SEMANTICO contra o FaseConfig e o desafio corrente.
func _ao_submeter_comando(texto: String, tempo_resposta_ms: int) -> void:
	var resultado: ResultadoComando = AnalisadorComando.analisar(texto)

	if resultado.resultado == CatalogoResultados.ERRO_LEXICO:
		terminal.escrever("erro lexico: caractere nao reconhecido no comando.")
		Telemetria.registrar_evento(CatalogoEventos.ERRO_LEXICO, {}, configuracao.numero)
		_registrar_tentativa(resultado, resultado.resultado, resultado.codigo_erro, tempo_resposta_ms)
		return

	if resultado.resultado == CatalogoResultados.ERRO_SINTATICO:
		terminal.escrever("erro sintatico: comando mal formado. digite 'status' para ver o desafio atual.")
		Telemetria.registrar_evento(CatalogoEventos.ERRO_SINTATICO, {}, configuracao.numero)
		_registrar_tentativa(resultado, resultado.resultado, resultado.codigo_erro, tempo_resposta_ms)
		return

	var desafio_atual: DesafioConfig = _desafio_atual()
	var veredicto: VeredictoComando = ResolvedorComando.resolver(
		configuracao, desafio_atual, _numero_tentativa_do_desafio, resultado)

	terminal.escrever(veredicto.texto_para_terminal)
	_registrar_tentativa(resultado, veredicto.resultado, veredicto.codigo_erro, tempo_resposta_ms)

	if veredicto.delta_pontos != 0:
		Sessao.somar_pontos(veredicto.delta_pontos)

	if veredicto.dica_solicitada and desafio_atual != null:
		Telemetria.registrar_evento(CatalogoEventos.DICA_SOLICITADA,
			{"desafio": desafio_atual.identificador}, configuracao.numero)

	if veredicto.resolveu_desafio:
		jogador.ativar_protecao(veredicto.duracao_protecao_s)
		_avancar_desafio()
	elif _e_tentativa_do_desafio_corrente(desafio_atual, resultado.ast.verbo):
		# So conta como nova tentativa do MESMO desafio quando o verbo bate com
		# o que o desafio espera -- "status" e "dica" nao consomem tentativa.
		_numero_tentativa_do_desafio += 1


func _registrar_tentativa(
		resultado: ResultadoComando, resultado_final: String, codigo_erro: String, tempo_resposta_ms: int) -> void:
	var desafio_atual: DesafioConfig = _desafio_atual()
	var identificador_desafio: String = desafio_atual.identificador if desafio_atual != null \
		else "sem-desafio-ativo"
	Telemetria.registrar_tentativa(
		configuracao.numero,
		identificador_desafio,
		resultado.texto_normalizado,
		resultado.tokens_para_telemetria(),
		resultado_final,
		codigo_erro,
		tempo_resposta_ms,
		_numero_tentativa_do_desafio)


func _e_tentativa_do_desafio_corrente(desafio_atual: DesafioConfig, verbo: String) -> bool:
	return desafio_atual != null and verbo == desafio_atual.verbo_esperado


func _desafio_atual() -> DesafioConfig:
	if _indice_desafio < 0 or _indice_desafio >= configuracao.desafios.size():
		return null
	return configuracao.desafios[_indice_desafio]


func _avancar_desafio() -> void:
	_indice_desafio += 1
	_numero_tentativa_do_desafio = 1
	var proximo: DesafioConfig = _desafio_atual()
	if proximo != null:
		terminal.escrever("proximo desafio: %s" % proximo.enunciado)
	else:
		terminal.escrever("todos os desafios resolvidos. va ate a saida.")


# ---------------------------------------------------------------------------
# IA do cachorro: replanejamento (AStarGrid2D via Navegacao) e deteccao
# ---------------------------------------------------------------------------

func _configurar_temporizador_replanejamento() -> void:
	_temporizador_replanejamento = Timer.new()
	_temporizador_replanejamento.name = "TemporizadorDeReplanejamento"
	# Timer nao aceita wait_time 0 -- e o mesmo piso defensivo que Telemetria
	# aplica ao intervalo de descarga, pelo mesmo motivo: um FaseConfig com 0.0
	# nao pode virar recalculo por quadro (secao 6: "replanejamento por
	# intervalo, nao por quadro").
	_temporizador_replanejamento.wait_time = maxf(0.05, configuracao.intervalo_replanejamento_s)
	_temporizador_replanejamento.autostart = true
	_temporizador_replanejamento.timeout.connect(_replanejar_caminho_do_cachorro)
	add_child(_temporizador_replanejamento)


func _replanejar_caminho_do_cachorro() -> void:
	if _encerrada:
		return
	var caminho: PackedVector2Array = _navegacao.calcular_caminho(
		cachorro.global_position, jogador.global_position)
	cachorro.definir_caminho(caminho)
	if _depuracao_astar_visivel:
		queue_redraw()


## CACHORRO_DETECTOU/CACHORRO_PERDEU sao emitidos na borda de subida/descida da
## linha de visao, checada a cada quadro (a deteccao tem que ser tao responsiva
## quanto o jogo, mesmo com o replanejamento do A* rodando so por intervalo).
## No Marco 1 o cachorro ja persegue a posicao real do jogador sempre -- nao ha
## Diretor ainda (Marco 2); a linha de visao aqui so controla estes dois
## eventos, preparando o terreno para quando ela tambem decidir o alvo.
func _atualizar_deteccao_do_cachorro() -> void:
	var visivel: bool = cachorro.tem_linha_de_visao(jogador.global_position)
	if visivel and not _cachorro_com_linha_de_visao:
		Telemetria.registrar_evento(CatalogoEventos.CACHORRO_DETECTOU,
			{"posicao": jogador.global_position}, configuracao.numero)
	elif not visivel and _cachorro_com_linha_de_visao:
		Telemetria.registrar_evento(CatalogoEventos.CACHORRO_PERDEU, {}, configuracao.numero)
	_cachorro_com_linha_de_visao = visivel


# ---------------------------------------------------------------------------
# Falha de configuracao
# ---------------------------------------------------------------------------

func _diagnosticar() -> String:
	if configuracao == null:
		return ("fase_base.tscn e a cena pai e nao roda sozinha.\n"
			+ "abra uma cena herdada (cenas/fases/fase_0N.tscn) ou atribua um\n"
			+ "FaseConfig no Inspector, no campo 'configuracao'.")

	var problemas: PackedStringArray = configuracao.problemas()
	if not problemas.is_empty():
		return "FaseConfig invalido:\n- %s" % "\n- ".join(problemas)

	return ""


func _falhar(mensagem: String) -> void:
	Registro.erro("FaseBase", mensagem.replace("\n", " "))
	_rotulo_do_aviso.text = mensagem
	aviso.visible = true
	set_physics_process(false)
	# Sem desligar os filhos, o jogador andaria por um labirinto sem regra
	# nenhuma atras da mensagem de erro.
	jogador.definir_entrada_habilitada(false)
	cachorro.parar()


func _voltar_ao_menu() -> void:
	get_tree().change_scene_to_file(CENA_DO_MENU)
