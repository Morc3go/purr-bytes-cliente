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
@onready var regioes_no: Node2D = $Marcadores/Regioes
@onready var hud: Hud = $Hud
@onready var terminal: Terminal = $Terminal
@onready var painel_cifra: PainelCifra = $PainelCifra
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

## Diretor de IA (Marco 2, scripts/ia/diretor.gd). Null quando a fase nao tem
## nenhuma regiao em Marcadores/Regioes (caso do Marco 1: fase_01.tscn) -- sem
## Diretor, o cachorro continua perseguindo a posicao real sempre, exatamente
## o comportamento original do Marco 1 (docs/decisoes/0007, decisao 1).
var _diretor: Diretor = null
var _temporizador_diretor: Timer = null
var _regiao_atual_do_jogador: Area2D = null
var _indice_varredura: int = 0

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
	_configurar_diretor()
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

	if evento.is_action_pressed("mostrar_demonstracao"):
		_alternar_painel_de_demonstracao()
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

	if _diretor != null:
		_diretor.pista_captura(_regiao_atual_do_jogador)

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
		if _diretor != null:
			_diretor.pista_comando_errado(_regiao_atual_do_jogador)
		return

	if resultado.resultado == CatalogoResultados.ERRO_SINTATICO:
		terminal.escrever("erro sintatico: comando mal formado. digite 'status' para ver o desafio atual.")
		Telemetria.registrar_evento(CatalogoEventos.ERRO_SINTATICO, {}, configuracao.numero)
		_registrar_tentativa(resultado, resultado.resultado, resultado.codigo_erro, tempo_resposta_ms)
		if _diretor != null:
			_diretor.pista_comando_errado(_regiao_atual_do_jogador)
		return

	var desafio_atual: DesafioConfig = _desafio_atual()
	var veredicto: VeredictoComando = ResolvedorComando.resolver(
		configuracao, desafio_atual, _numero_tentativa_do_desafio, resultado)

	terminal.escrever(veredicto.texto_para_terminal)
	_registrar_tentativa(resultado, veredicto.resultado, veredicto.codigo_erro, tempo_resposta_ms)

	if veredicto.resultado != CatalogoResultados.SUCESSO and _diretor != null:
		_diretor.pista_comando_errado(_regiao_atual_do_jogador)

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
		cachorro.global_position, _alvo_de_perseguicao())
	cachorro.definir_caminho(caminho)
	if _depuracao_astar_visivel:
		queue_redraw()


## CACHORRO_DETECTOU/CACHORRO_PERDEU sao emitidos na borda de subida/descida da
## linha de visao, checada a cada quadro (a deteccao tem que ser tao responsiva
## quanto o jogo, mesmo com o replanejamento do A* rodando so por intervalo).
func _atualizar_deteccao_do_cachorro() -> void:
	var visivel: bool = cachorro.tem_linha_de_visao(jogador.global_position)
	if visivel and not _cachorro_com_linha_de_visao:
		Telemetria.registrar_evento(CatalogoEventos.CACHORRO_DETECTOU,
			{"posicao": jogador.global_position}, configuracao.numero)
	elif not visivel and _cachorro_com_linha_de_visao:
		Telemetria.registrar_evento(CatalogoEventos.CACHORRO_PERDEU, {}, configuracao.numero)
	_cachorro_com_linha_de_visao = visivel


## O alvo que o A* persegue. Linha de visao direta sempre vence (o cachorro
## "viu" o jogador de verdade -- nao ha razao para fingir que nao sabe onde ele
## esta). Sem linha de visao: se ha Diretor (Marco 2, fase com regioes), o alvo
## e a crenca dele; sem Diretor (Marco 1, fase_01), o cachorro continua
## perseguindo a posicao real sempre -- o mesmo comportamento original do
## Marco 1, preservado de proposito (docs/decisoes/0007, decisao 1).
func _alvo_de_perseguicao() -> Vector2:
	if cachorro.tem_linha_de_visao(jogador.global_position):
		return jogador.global_position
	if _diretor == null:
		return jogador.global_position
	var regiao: Area2D = _diretor.regiao_mais_provavel()
	return _alvo_de_varredura(regiao) if regiao != null else cachorro.global_position


## Comportamento de caca local (secao 7 do CLAUDE.md): ao chegar perto do
## centro da regiao-alvo do Diretor, o cachorro varre alguns pontos ao redor
## em vez de ficar parado em cima do centro -- ate ganhar contato visual ou o
## Diretor mudar de alvo (o que reseta a varredura via alvo_alterado).
const _OFFSETS_DE_VARREDURA: Array[Vector2] = [
	Vector2.ZERO, Vector2(16, 0), Vector2(0, 16), Vector2(-16, 0), Vector2(0, -16),
]


func _alvo_de_varredura(regiao: Area2D) -> Vector2:
	var centro: Vector2 = regiao.global_position
	var ponto: Vector2 = centro + _OFFSETS_DE_VARREDURA[_indice_varredura % _OFFSETS_DE_VARREDURA.size()]
	if cachorro.global_position.distance_to(ponto) <= cachorro.tolerancia_de_chegada:
		_indice_varredura += 1
		ponto = centro + _OFFSETS_DE_VARREDURA[_indice_varredura % _OFFSETS_DE_VARREDURA.size()]
	return ponto


# ---------------------------------------------------------------------------
# Diretor de IA (Marco 2): regioes, pistas e decaimento
# ---------------------------------------------------------------------------

## Regioes sao dado de cena (Area2D colocados pelo editor em Marcadores/Regioes
## de cada fase_0N.tscn), nunca hardcoded aqui -- e a mesma logica de
## "matriz de dados" do FaseConfig. Fase sem nenhuma regiao (fase_01.tscn) fica
## sem Diretor de proposito: ver _alvo_de_perseguicao.
func _configurar_diretor() -> void:
	var regioes: Array[Area2D] = []
	for filho: Node in regioes_no.get_children():
		if filho is Area2D:
			regioes.append(filho as Area2D)
			(filho as Area2D).body_entered.connect(_ao_jogador_entrar_na_regiao.bind(filho))
			(filho as Area2D).body_exited.connect(_ao_jogador_sair_da_regiao.bind(filho))

	if regioes.is_empty():
		return

	_diretor = Diretor.new(
		regioes,
		configuracao.peso_pista_comando_errado,
		configuracao.peso_pista_movimento,
		configuracao.peso_pista_captura,
		configuracao.decaimento_crenca_por_s)
	_diretor.alvo_alterado.connect(func(_r: Area2D) -> void: _indice_varredura = 0)

	_temporizador_diretor = Timer.new()
	_temporizador_diretor.name = "TemporizadorDoDiretor"
	_temporizador_diretor.wait_time = maxf(0.05, configuracao.intervalo_decisao_diretor_s)
	_temporizador_diretor.autostart = true
	_temporizador_diretor.timeout.connect(_ao_vencer_temporizador_do_diretor)
	add_child(_temporizador_diretor)


func _ao_vencer_temporizador_do_diretor() -> void:
	if _encerrada or _diretor == null:
		return
	_diretor.decair(_temporizador_diretor.wait_time)


## Pista fraca, disparada uma vez por entrada na regiao (nao a cada quadro
## parado dentro dela) -- reforcar continuamente equivaleria a entregar a
## posicao quase exata ao Diretor, o que contradiria a propria premissa da
## informacao imperfeita.
func _ao_jogador_entrar_na_regiao(corpo: Node2D, regiao: Area2D) -> void:
	if not (corpo is Jogador):
		return
	_regiao_atual_do_jogador = regiao
	if _diretor != null:
		_diretor.pista_movimento(regiao)


func _ao_jogador_sair_da_regiao(corpo: Node2D, regiao: Area2D) -> void:
	if not (corpo is Jogador):
		return
	if _regiao_atual_do_jogador == regiao:
		_regiao_atual_do_jogador = null


# ---------------------------------------------------------------------------
# Painel de demonstracao da cifra (Marco 2)
# ---------------------------------------------------------------------------

## Mostra um exemplo FIXO (FaseConfig.texto/chave_exemplo_demonstracao), nunca
## o desafio corrente -- o painel ensina o MECANISMO da cifra, nao e um jeito
## de espiar a chave que resolve o desafio ativo (isso ja existe, com custo:
## o verbo "dica"). Ver docs/decisoes/0008-vigenere-e-painel-de-demonstracao.md.
func _alternar_painel_de_demonstracao() -> void:
	if painel_cifra.esta_aberto():
		painel_cifra.fechar()
		return

	if configuracao.texto_exemplo_demonstracao.is_empty() \
			or configuracao.chave_exemplo_demonstracao.is_empty():
		terminal.escrever("esta fase nao tem exemplo de demonstracao configurado.")
		return

	var cifra: Cifra = FabricaCifra.para_algoritmo(configuracao.algoritmo)
	if cifra == null:
		terminal.escrever("nao ha demonstracao disponivel para o algoritmo '%s'." % configuracao.algoritmo)
		return

	painel_cifra.abrir(
		"como o %s desloca cada letra" % configuracao.algoritmo,
		configuracao.texto_exemplo_demonstracao,
		configuracao.chave_exemplo_demonstracao,
		cifra)
	Telemetria.registrar_evento(CatalogoEventos.CIFRA_DEMONSTRADA, {
		"algoritmo": configuracao.algoritmo,
	}, configuracao.numero)


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
