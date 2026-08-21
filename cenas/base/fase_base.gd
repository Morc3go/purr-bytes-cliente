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

	Sessao.entrar_na_fase(configuracao.numero, configuracao.vidas_iniciais)
	hud.definir_titulo("fase %d -- %s" % [configuracao.numero, configuracao.titulo])

	Telemetria.registrar_evento(CatalogoEventos.FASE_INICIADA, {
		"algoritmo": configuracao.algoritmo,
		"desafios": configuracao.desafios.size(),
		"vidas_iniciais": configuracao.vidas_iniciais,
	}, configuracao.numero)

	if configuracao.briefing_pedagogico != "":
		terminal.escrever(configuracao.briefing_pedagogico)


func _physics_process(_delta: float) -> void:
	if not _configurada:
		return
	# A camera segue o jogador por posicao, e nao por parentesco, para o Marco 1
	# poder aplicar limites (limit_left/right) vindos do tamanho do labirinto sem
	# mexer na cena do jogador.
	camera.global_position = jogador.global_position


func _unhandled_input(evento: InputEvent) -> void:
	if not _configurada or _encerrada:
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


## Marco 0 apenas registra o comando. O analisador lexico-sintatico entra no
## Marco 1 e passa a produzir tentativa_comando com o resultado real; ate la,
## nao se emite tentativa nenhuma, porque um resultado inventado sujaria a taxa
## de acerto do Eixo 1.
func _ao_submeter_comando(texto: String, tempo_resposta_ms: int) -> void:
	Telemetria.registrar_evento(CatalogoEventos.COMANDO_SUBMETIDO, {
		"tamanho": texto.length(),
		"tempo_resposta_ms": tempo_resposta_ms,
	}, configuracao.numero)
	terminal.escrever("> %s" % texto)
	terminal.escrever("analisador lexico-sintatico chega no Marco 1.")


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
