extends RefCounted

## Roteiro do video de demonstracao (tools/video_demonstracao.gd): percorre o
## jogo como um jogador faria -- menu, galeria, escolha do gato, fase de Cesar
## com terminal, A*, painel F4, pergunta, captura e porta, fases de SHA-256 e
## de golpes, telemetria e editor -- com legendas explicando cada parte.
##
## Participante FICTICIO (ADR 0019); telemetria, fases e preferencias ficam em
## user://testes/video, sem tocar nos dados de quem joga nesta maquina.

const PASTA_DADOS: String = "user://testes/video"
const SUJEITO: String = "f1c71c10-0001-4000-8000-0000000000c3"
const FPS: float = 30.0
const FONTE: FontFile = preload("res://recursos/fontes/silkscreen_regular.woff")
const FONTE_NEGRITO: FontFile = preload("res://recursos/fontes/silkscreen_bold.woff")
const LOGO: Texture2D = preload("res://recursos/arte/logo_crypto_cats.png")
const GATO_DO_MENU: Texture2D = preload("res://recursos/arte/gato_siames_rabo.png")

## Fundo da galeria que da o tema do video: menu, telas, legendas e cartelas.
## video_demonstracao.gd troca pelo que vier em --fundo=<nome>.
var fundo: String = "noite"

var _arvore: SceneTree
var _fases: Dictionary = {}
var _camada: CanvasLayer
var _legenda: PanelContainer
var _texto_legenda: Label
var _cartela: Control


# --------------------------------------------------------------- tempo

func _esperar(segundos: float) -> void:
	for i: int in int(round(segundos * FPS)):
		await _arvore.process_frame


# --------------------------------------------------------------- sobreposicao

func _montar_sobreposicao() -> void:
	_camada = CanvasLayer.new()
	_camada.layer = 120
	_camada.process_mode = Node.PROCESS_MODE_ALWAYS
	_arvore.root.add_child(_camada)

	_legenda = PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	var tinta: Color = GaleriaDeFundos.tinta(fundo)
	estilo.bg_color = Color(tinta.r, tinta.g, tinta.b, 0.92)
	estilo.border_color = GaleriaDeFundos.tom(fundo).lightened(0.45)
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(6)
	estilo.content_margin_left = 10
	estilo.content_margin_right = 10
	estilo.content_margin_top = 5
	estilo.content_margin_bottom = 5
	_legenda.add_theme_stylebox_override(&"panel", estilo)
	_legenda.anchor_left = 0.5
	_legenda.anchor_right = 0.5
	_legenda.anchor_top = 1.0
	_legenda.anchor_bottom = 1.0
	_legenda.offset_left = -270
	_legenda.offset_right = 270
	_legenda.offset_top = -66
	_legenda.offset_bottom = -26
	_legenda.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_texto_legenda = Label.new()
	_texto_legenda.add_theme_font_override(&"font", FONTE)
	_texto_legenda.add_theme_font_size_override(&"font_size", 8)
	_texto_legenda.add_theme_color_override(&"font_color", Color.WHITE)
	_texto_legenda.add_theme_constant_override(&"line_spacing", 2)
	_texto_legenda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texto_legenda.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_texto_legenda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_legenda.add_child(_texto_legenda)
	_legenda.modulate.a = 0.0
	_camada.add_child(_legenda)


## A legenda fica embaixo; com o terminal aberto (que ocupa a parte de baixo
## da tela) ela sobe para o alto, para nao cobrir o que se digita.
func _legenda_no_alto(no_alto: bool) -> void:
	if no_alto:
		_legenda.anchor_top = 0.0
		_legenda.anchor_bottom = 0.0
		_legenda.offset_top = 20
		_legenda.offset_bottom = 60
		_legenda.grow_vertical = Control.GROW_DIRECTION_END
	else:
		_legenda.anchor_top = 1.0
		_legenda.anchor_bottom = 1.0
		_legenda.offset_top = -66
		_legenda.offset_bottom = -26
		_legenda.grow_vertical = Control.GROW_DIRECTION_BEGIN


func _legendar(texto: String) -> void:
	if _legenda.modulate.a > 0.0:
		for i: int in 5:
			_legenda.modulate.a = 1.0 - (i + 1) / 5.0
			await _arvore.process_frame
	_texto_legenda.text = texto
	for i: int in 6:
		_legenda.modulate.a = (i + 1) / 6.0
		await _arvore.process_frame


func _esconder_legenda() -> void:
	for i: int in 5:
		_legenda.modulate.a = 1.0 - (i + 1) / 5.0
		await _arvore.process_frame


## Cartela de abertura e de encerramento: fundo do jogo, logo e textos.
func _mostrar_cartela(linhas: Array[String], segundos: float) -> void:
	_cartela = Control.new()
	_cartela.set_anchors_preset(Control.PRESET_FULL_RECT)
	var papel := TextureRect.new()
	papel.texture = GaleriaDeFundos.textura_do_fundo(fundo)
	papel.set_anchors_preset(Control.PRESET_FULL_RECT)
	papel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	papel.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_cartela.add_child(papel)
	var veu := ColorRect.new()
	var tinta: Color = GaleriaDeFundos.tinta(fundo)
	veu.color = Color(tinta.r, tinta.g, tinta.b, 0.5)
	veu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cartela.add_child(veu)
	var coluna := VBoxContainer.new()
	coluna.set_anchors_preset(Control.PRESET_FULL_RECT)
	coluna.alignment = BoxContainer.ALIGNMENT_CENTER
	coluna.add_theme_constant_override(&"separation", 10)
	_cartela.add_child(coluna)
	var logo := TextureRect.new()
	logo.texture = LOGO
	logo.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	logo.custom_minimum_size = LOGO.get_size()
	coluna.add_child(logo)
	var gato := TextureRect.new()
	var recorte := AtlasTexture.new()
	recorte.atlas = GATO_DO_MENU
	var quadro: Vector2 = Vector2(GATO_DO_MENU.get_width() / 4.0, GATO_DO_MENU.get_height())
	recorte.region = Rect2(Vector2.ZERO, quadro)
	gato.texture = recorte
	gato.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	gato.custom_minimum_size = quadro
	coluna.add_child(gato)
	for indice: int in linhas.size():
		var rotulo := Label.new()
		rotulo.text = linhas[indice]
		rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rotulo.add_theme_font_override(&"font", FONTE_NEGRITO if indice == 0 else FONTE)
		rotulo.add_theme_font_size_override(&"font_size", 10 if indice == 0 else 8)
		rotulo.add_theme_color_override(&"font_color", Color.WHITE)
		coluna.add_child(rotulo)
	_cartela.modulate.a = 0.0
	_camada.add_child(_cartela)
	for i: int in 12:
		_cartela.modulate.a = (i + 1) / 12.0
		await _arvore.process_frame
	await _esperar(segundos)
	for i: int in 12:
		_cartela.modulate.a = 1.0 - (i + 1) / 12.0
		await _arvore.process_frame
	_cartela.queue_free()


# --------------------------------------------------------------- acoes de jogador

func _apertar(acao: StringName) -> void:
	var evento := InputEventAction.new()
	evento.action = acao
	evento.pressed = true
	Input.parse_input_event(evento)
	await _arvore.process_frame
	var solta := InputEventAction.new()
	solta.action = acao
	solta.pressed = false
	Input.parse_input_event(solta)
	await _arvore.process_frame


func _clicar(botao: Button, antes_s: float = 0.6) -> void:
	botao.grab_focus()
	await _esperar(antes_s)
	botao.pressed.emit()
	await _esperar(0.2)


## Abre o terminal (tecla T), digita letra por letra e aperta Enter.
func _digitar(fase: FaseBase, texto: String, depois_s: float = 2.5) -> void:
	if not fase.terminal.esta_aberto():
		_legenda_no_alto(true)
		await _apertar(&"abrir_terminal")
		await _esperar(0.5)
	var entrada: LineEdit = fase.terminal.get_node("Painel/Margem/Coluna/Entrada") as LineEdit
	for letra: String in texto:
		entrada.text += letra
		entrada.caret_column = entrada.text.length()
		await _esperar(0.07)
	await _esperar(0.4)
	entrada.text_submitted.emit(entrada.text)
	await _esperar(depois_s)


func _fechar_terminal(fase: FaseBase) -> void:
	if fase.terminal.esta_aberto():
		fase.terminal.fechar()
	_legenda_no_alto(false)
	await _esperar(0.3)


const _DIRECOES: Array[StringName] = [&"mover_direita", &"mover_esquerda", &"mover_baixo", &"mover_cima"]


func _soltar_direcoes() -> void:
	for acao: StringName in _DIRECOES:
		Input.action_release(acao)


## Anda pelo labirinto ate `destino` pelas setas, seguindo a rota do A*.
## Para sozinho se algo pausar o jogo (pergunta de pacote, captura).
func _andar_ate(fase: FaseBase, destino: Vector2, limite_s: float = 14.0) -> void:
	var jogador: Jogador = fase.jogador
	var caminho: PackedVector2Array = fase._navegacao.calcular_caminho(jogador.global_position, destino)
	var quadros: int = 0
	for ponto: Vector2 in caminho:
		while true:
			if not is_instance_valid(jogador) or _arvore.paused or quadros > limite_s * FPS:
				_soltar_direcoes()
				return
			var falta: Vector2 = ponto - jogador.global_position
			if falta.length() < 2.0:
				break
			var acao: StringName
			if absf(falta.x) >= absf(falta.y):
				acao = &"mover_direita" if falta.x > 0.0 else &"mover_esquerda"
				jogador.global_position.y = lerpf(jogador.global_position.y, ponto.y, 0.5)
			else:
				acao = &"mover_baixo" if falta.y > 0.0 else &"mover_cima"
				jogador.global_position.x = lerpf(jogador.global_position.x, ponto.x, 0.5)
			for outra: StringName in _DIRECOES:
				if outra != acao:
					Input.action_release(outra)
			Input.action_press(acao)
			await _arvore.physics_frame
			quadros += 1
		if not is_instance_valid(jogador):
			break
	_soltar_direcoes()


func _invulneravel(fase: FaseBase, ligado: bool) -> void:
	fase._invulneravel_ate_ms = Time.get_ticks_msec() + (1_000_000_000 if ligado else 0)


func _vigia_que_so_persegue(fase: FaseBase) -> Cachorro:
	for alvo: Cachorro in fase.cachorros:
		if fase._apenas_persegue(alvo):
			return alvo
	return fase.cachorros[0]


func _jogar(arquivo: String, pelagem: String) -> FaseBase:
	var fase: FaseBase = IniciadorDeFase.jogar(_arvore, _fases[arquivo], pelagem)
	await _esperar(1.0)
	return fase


## Os oito cenarios no proprio labirinto da fase (ADR 0035): so a roupa muda;
## paredes, rotas do A* e regras continuam as mesmas. O jogo fica em pausa
## enquanto isso, para os cachorros esperarem; depois volta o escolhido.
func _mostrar_todos_os_cenarios(fase: FaseBase) -> void:
	var arbustos: ArbustosDoLabirinto = fase.labirinto.get_node("Arbustos") as ArbustosDoLabirinto
	var escolhido: String = arbustos.cenario()
	_arvore.paused = true
	await _legendar("os oito cenários no mesmo labirinto: só a aparência muda, paredes e regras são iguais")
	await _esperar(2.0)
	for cenario: String in CenarioDoLabirinto.ORDEM:
		arbustos.vestir(fase.labirinto, cenario, fase.celulas_ocupadas(), fase.configuracao.semente_do_mapa)
		await _legendar("cenário: " + CenarioDoLabirinto.nome(cenario))
		await _esperar(2.2)
	arbustos.vestir(fase.labirinto, escolhido, fase.celulas_ocupadas(), fase.configuracao.semente_do_mapa)
	_arvore.paused = false


# --------------------------------------------------------------- roteiro

func executar(arvore: SceneTree) -> void:
	_arvore = arvore
	DirAccess.make_dir_recursive_absolute(PASTA_DADOS)
	for nome: String in DirAccess.get_files_at(PASTA_DADOS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PASTA_DADOS.path_join(nome)))
	var pasta_fases: String = PASTA_DADOS.path_join("fases")
	DirAccess.make_dir_recursive_absolute(pasta_fases)
	for nome: String in DirAccess.get_files_at(pasta_fases):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(pasta_fases.path_join(nome)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(pasta_fases.path_join(".fases_demo")))
	CarregadorFaseJson.pasta_das_fases = pasta_fases
	Preferencias.caminho = PASTA_DADOS.path_join("preferencias.cfg")
	GaleriaDeFundos.salvar(fundo)
	var telemetria: Node = arvore.root.get_node("Telemetria")
	telemetria.call("reiniciar", TransporteMock.new(PASTA_DADOS.path_join("telemetria.jsonl")),
		PASTA_DADOS.path_join("fila.json"))
	arvore.root.get_node("ConfigJogo").set("id_sujeito", SUJEITO)
	_montar_sobreposicao()

	# ------------------------------------------------ abertura
	arvore.change_scene_to_file("res://cenas/ui/menu_principal.tscn")
	await _esperar(0.2)
	await _mostrar_cartela(["demonstração do jogo", "projeto Purr Bytes · TCC Ciência da Computação · Universidade Positivo",
		"letramento digital, criptografia e segurança cibernética"], 4.0)
	for caminho: String in CarregadorFaseJson.listar():
		var lido: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_arquivo(caminho)
		if lido.ok():
			_fases[caminho.get_file()] = lido.config

	# ------------------------------------------------ menu e galeria
	var menu: Control = arvore.current_scene as Control
	await _legendar("menu principal: logo e gatinho desenhados pela equipe")
	await _esperar(3.0)
	await _legendar("o botão de galeria (canto superior direito) troca o fundo e a cor dos botões")
	var galeria: Button = menu.get_node("Galeria") as Button
	for i: int in GaleriaDeFundos.ORDEM.size():
		await _clicar(galeria, 0.3)
		await _esperar(1.3)
	await _legendar("escolher fase abre a trilha de demonstração")
	await _clicar(menu.get_node("Cartao/Coluna/Botoes/EscolherFase") as Button, 1.2)
	await _esperar(0.8)

	# ------------------------------------------------ selecao e escolha do gato
	var selecao: Control = arvore.current_scene as Control
	await _legendar("cinco fases: César, Vigenère, SHA-256, golpes digitais e avaliação final")
	var lista: ItemList = selecao._lista as ItemList
	var indice_cesar: int = Array(selecao._caminhos).find(pasta_fases.path_join("01-cesar-o-primeiro-segredo.json"))
	for i: int in range(0, 5):
		lista.select(i)
		lista.item_selected.emit(i)
		await _esperar(0.7)
	lista.select(indice_cesar)
	lista.item_selected.emit(indice_cesar)
	await _esperar(1.5)
	await _legendar("antes de jogar, o jogador escolhe o seu gatinho")
	await _clicar(selecao.get_node("Raiz/Margem/Coluna/Acoes/Jogar") as Button, 0.8)
	await _esperar(1.0)
	var escolha: EscolhaDeGato = selecao._escolha_de_gato
	for pelagem: String in [PelagemGato.CALICO, PelagemGato.SIAMES, PelagemGato.CALICO]:
		escolha.focar(pelagem)
		await _esperar(1.2)
	await _esperar(0.5)
	escolha.cartao(PelagemGato.CALICO).pressed.emit()
	await _esperar(1.0)
	await _legendar("depois, o cenário do labirinto: a fase já sugere um, e o jogador pode trocar")
	var cenarios: EscolhaDeCenario = selecao._escolha_de_cenario
	for cenario: String in ["lago", "inverno", "cerejeira", "outono"]:
		cenarios.focar(cenario)
		await _esperar(1.0)
	cenarios.cartao("outono").pressed.emit()
	await _esperar(1.0)

	# ------------------------------------------------ fase 1: Cesar
	var fase: FaseBase = arvore.current_scene as FaseBase
	_invulneravel(fase, true)
	await _mostrar_todos_os_cenarios(fase)
	await _legendar("fase 1: o gato leva pacotes de dados pela rede; os cachorros interceptam o que estiver em texto claro")
	await _esperar(3.5)
	await _legendar("F3 mostra a rota que o algoritmo A* calculou para cada vigia, na cor dele")
	await _apertar(&"alternar_depuracao")
	await _esperar(4.0)
	await _apertar(&"alternar_depuracao")
	_legenda_no_alto(true)
	await _legendar("T abre o terminal: cada comando passa por análise léxica, sintática e semântica")
	await _digitar(fase, "cyfrar senha chave=3", 3.0)
	await _legendar("com o comando certo, o terminal explica a cifra letra a letra e o vigia deixa passar")
	await _digitar(fase, "cifrar senha chave=3", 4.5)
	await _fechar_terminal(fase)
	await _legendar("F4 mostra como o algoritmo funciona, com o exemplo da própria fase")
	await _apertar(&"mostrar_demonstracao")
	await _esperar(4.5)
	await _apertar(&"mostrar_demonstracao")

	await _legendar("pelas setas, o gato vai até um pacote; cada pacote traz uma pergunta")
	var primeiro: Pacote = fase.pacotes[0]
	for pacote: Pacote in fase.pacotes:
		if fase._navegacao.calcular_caminho(fase.jogador.global_position, pacote.global_position).size() \
				< fase._navegacao.calcular_caminho(fase.jogador.global_position, primeiro.global_position).size():
			primeiro = pacote
	await _andar_ate(fase, primeiro.global_position)
	if not fase.caixa_puzzle.esta_aberta():
		fase._ao_alcancar_pacote(primeiro)
	await _esperar(2.5)
	await _legendar("o erro é sinalizado na hora, sem entregar a resposta")
	var config_pacote: PacoteConfig = primeiro.configuracao
	for opcao: String in config_pacote.opcoes:
		if opcao != config_pacote.resposta_correta:
			fase.caixa_puzzle.escolher(opcao)
			break
	await _esperar(3.0)
	await _legendar("no acerto, o jogo explica o conceito e o pacote é coletado")
	fase.caixa_puzzle.escolher(config_pacote.resposta_correta)
	await _esperar(3.5)
	if fase.caixa_puzzle.esta_aberta():
		fase._fechar_puzzle()
	await _esperar(0.5)

	await _legendar("parado, o gatinho continua virado para onde andava, senta e depois cochila")
	await _esperar(8.5)

	await _legendar("sem a proteção certa, o pacote é interceptado e o jogo explica o que teria protegido")
	_invulneravel(fase, false)
	fase.jogador.cancelar_protecao()
	fase._ao_encostar_no_jogador(fase.jogador, _vigia_que_so_persegue(fase))
	await _esperar(4.5)
	fase.tela_captura.encerrar_agora()
	await _esperar(0.5)
	_invulneravel(fase, true)

	await _legendar("com todos os pacotes coletados, a porta de saída se abre")
	for pacote: Pacote in fase.pacotes:
		if not pacote.coletado:
			fase._coletar_pacote(pacote)
	await _esperar(0.3)
	var caminho_porta: PackedVector2Array = fase._navegacao.calcular_caminho(
		fase.jogador.global_position, fase.ponto_de_saida.global_position)
	if caminho_porta.size() > 9:
		fase.jogador.reposicionar(caminho_porta[caminho_porta.size() - 9])
	await _esperar(1.0)
	await _andar_ate(fase, fase.ponto_de_saida.global_position, 8.0)
	# Ao passar pela porta a fase termina e o jogo volta ao menu; o video segue
	# direto para a proxima fase, sem ficar parado no menu.
	await _esperar(0.2)

	# ------------------------------------------------ fase 3: SHA-256
	fase = await _jogar("03-sha256-o-pacote-foi-alterado.json", PelagemGato.CALICO)
	await _legendar("fase 3: SHA-256 não esconde a mensagem, confere se ela foi alterada")
	_invulneravel(fase, true)
	await _esperar(2.0)
	await _digitar(fase, "hash contrato", 3.0)
	await _digitar(fase, "verificar contrato %s" % Sha256.digest_hex("contrato").substr(0, 8), 4.0)
	await _fechar_terminal(fase)
	await _legendar("F4: um caractere diferente muda o resumo inteiro (efeito avalanche)")
	await _apertar(&"mostrar_demonstracao")
	await _esperar(4.5)
	await _apertar(&"mostrar_demonstracao")
	fase.concluir()
	await _esperar(0.8)

	# ------------------------------------------------ fase 4: golpes
	await _legendar("fase 4: os vigias são golpes digitais e o comando é a atitude que protege")
	fase = await _jogar("04-golpes-digitais-nao-morda-a-isca.json", PelagemGato.SIAMES)
	_invulneravel(fase, true)
	await _esperar(2.5)
	await _digitar(fase, "conferir remetente", 2.5)
	await _digitar(fase, "desconfiar do link", 2.5)
	await _digitar(fase, "ativar 2fa", 3.0)
	await _fechar_terminal(fase)
	for pacote: Pacote in fase.pacotes:
		fase._coletar_pacote(pacote)
	fase.concluir()
	await _esperar(0.8)

	# ------------------------------------------------ telemetria
	await telemetria.call("descarregar")
	await _legendar("telemetria: acertos, erros, tempo de resposta, dicas e capturas por fase (dados fictícios)")
	arvore.change_scene_to_file("res://cenas/ui/dashboard_telemetria.tscn")
	await _esperar(4.5)
	var painel: Node = arvore.current_scene
	painel.call("_ao_abrir_fases")
	await _esperar(3.5)
	await _legendar("o detalhe de cada fase mostra o histórico de partidas, para acompanhar a evolução")
	painel.call("_abrir_detalhe", (_fases["01-cesar-o-primeiro-segredo.json"] as FaseConfig).id_fase)
	await _esperar(4.0)

	# ------------------------------------------------ editor
	await _legendar("editor de fases: o professor cria e compartilha fases sem programar")
	EditorDeFaseEstado.caminho_para_editar = pasta_fases.path_join("01-cesar-o-primeiro-segredo.json")
	arvore.change_scene_to_file("res://cenas/ui/editor_de_fase.tscn")
	await _esperar(3.0)
	var abas: TabContainer = arvore.current_scene.get_node("Raiz/Margem/Coluna/Abas") as TabContainer
	abas.current_tab = 1
	await _esperar(3.0)
	abas.current_tab = 2
	await _esperar(3.0)
	EditorDeFaseEstado.caminho_para_editar = ""
	await _esconder_legenda()

	# ------------------------------------------------ encerramento
	arvore.change_scene_to_file("res://cenas/ui/menu_principal.tscn")
	await _esperar(0.3)
	await _mostrar_cartela(["Crypto Cats", "Dayane Dias · Letícia Belo Ribeiro · João Antônio de Souza · Matheus Henrique Urban",
		"orientação: Prof. Me. Leandro Escobar · Universidade Positivo · 2026"], 4.5)
	CarregadorFaseJson.pasta_das_fases = CarregadorFaseJson.PASTA_DAS_FASES
