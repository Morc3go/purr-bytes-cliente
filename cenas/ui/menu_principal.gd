extends Control

## Menu principal.
##
## "Telemetria" abre o Dashboard (cenas/ui/dashboard_telemetria.tscn), que
## responde "o que a coleta diz" -- acertos x erros e tempo por fase. O painel
## de diagnostico tecnico ("a coleta esta funcionando?": modo, fila, sequencia,
## id_sujeito) continua existindo e abre por um botao la dentro; ele nao foi
## removido, so deixou de ser a primeira tela.
##
## O jogo nao tem fase propria embutida -- e ferramenta de autoria (ADR 0012).
## "Escolher fase" e o unico caminho para jogar: lista user://fases/, que
## nunca fica vazia (CarregadorFaseJson.semear_exemplo cria uma de exemplo no
## primeiro boot) e cresce com o que o professor cria ou sobe.

const CENA_DO_DASHBOARD: String = "res://cenas/ui/dashboard_telemetria.tscn"
const CENA_DA_SELECAO: String = "res://cenas/ui/selecao_de_fases.tscn"
const CENA_DO_EDITOR: String = "res://cenas/ui/editor_de_fase.tscn"

## O gatinho do menu (ADR 0031, trocado pelo siames no ADR 0039): deitado,
## abanando o rabo, desenhado pela equipe. A folha tem os 4 quadros; a ida e
## volta (0 1 2 3 2 1) e montada aqui para o rabo ir e voltar sem dar um pulo
## do ultimo quadro para o primeiro. 5 quadros por segundo, 200 ms cada.
const FOLHA_DO_GATO: Texture2D = preload("res://recursos/arte/gato_siames_rabo.png")
const QUADROS_DO_GATO: int = 4
const SEQUENCIA_DO_RABO: Array[int] = [0, 1, 2, 3, 2, 1]
const QUADROS_POR_SEGUNDO: float = 5.0
## O siames e menor que o gato amarelo (35 x 29 contra 49 x 38). Com 4/3 ele fica
## com 47 x 39, quase o tamanho do antigo, e ainda cabe no Mascote (40 de altura),
## entao o cartao nao cresce. Na janela padrao (1920 x 1080, 3x a base) cada pixel de
## arte vira 4 pixels de tela, sem pixel torto.
const ESCALA_DO_GATO: float = 4.0 / 3.0
const ANIMACAO_DO_RABO: StringName = &"rabo"

## Estados da moldura dos botoes que trocam de cor com o fundo (ADR 0033).
const ESTADOS_DO_BALAO: Array[StringName] = [&"normal", &"hover", &"pressed", &"disabled"]

var _fundo_atual: String = GaleriaDeFundos.PADRAO


## SpriteFrames do gatinho, montado a partir da folha. Estatico para os testes
## conferirem a sequencia sem abrir o menu.
static func quadros_do_gato() -> SpriteFrames:
	var quadros := SpriteFrames.new()
	quadros.remove_animation(&"default")
	quadros.add_animation(ANIMACAO_DO_RABO)
	quadros.set_animation_loop(ANIMACAO_DO_RABO, true)
	quadros.set_animation_speed(ANIMACAO_DO_RABO, QUADROS_POR_SEGUNDO)
	var largura: int = FOLHA_DO_GATO.get_width() / QUADROS_DO_GATO
	for indice: int in SEQUENCIA_DO_RABO:
		var recorte := AtlasTexture.new()
		recorte.atlas = FOLHA_DO_GATO
		recorte.region = Rect2(indice * largura, 0, largura, FOLHA_DO_GATO.get_height())
		quadros.add_frame(ANIMACAO_DO_RABO, recorte)
	return quadros


func _ready() -> void:
	# A fase de exemplo e semeada aqui, e nao no autoload: o jogo so precisa
	# dela quando alguem abre o menu, e escrever em user:// durante um teste
	# headless seria efeito colateral escondido.
	CarregadorFaseJson.semear_exemplo()
	CarregadorFaseJson.atualizar_exemplo()
	CarregadorFaseJson.semear_fases_demo()

	var gato: AnimatedSprite2D = $Cartao/Coluna/Mascote/Gato
	gato.sprite_frames = quadros_do_gato()
	gato.scale = Vector2.ONE * ESCALA_DO_GATO
	gato.play(ANIMACAO_DO_RABO)
	# O gato fica no meio do cartao, seja qual for a largura final da coluna.
	var mascote: Control = $Cartao/Coluna/Mascote
	mascote.resized.connect(func() -> void: gato.position = mascote.size * 0.5)

	$Cartao/Coluna/Botoes/EscolherFase.pressed.connect(_ao_escolher_fase)
	$Cartao/Coluna/Botoes/CriarFase.pressed.connect(_ao_criar_fase)
	$Cartao/Coluna/Botoes/SubirFase.pressed.connect(_ao_subir_fase)
	$DialogoDeImportacao.file_selected.connect(_ao_escolher_arquivo_para_subir)
	$Cartao/Coluna/Botoes/Telemetria.pressed.connect(_ao_abrir_telemetria)
	$Cartao/Coluna/Botoes/Sair.pressed.connect(_ao_sair)
	$Galeria.pressed.connect(_ao_trocar_fundo)
	aplicar_fundo(GaleriaDeFundos.atual())
	$Cartao/Coluna/Botoes/EscolherFase.grab_focus()


## Botao de galeria (canto superior direito): cada toque passa para o proximo
## fundo, com os botoes no tom que combina com ele, e lembra a escolha.
func _ao_trocar_fundo() -> void:
	var novo: String = GaleriaDeFundos.seguinte(_fundo_atual)
	GaleriaDeFundos.salvar(novo)
	aplicar_fundo(novo)


func aplicar_fundo(fundo: String) -> void:
	_fundo_atual = fundo if GaleriaDeFundos.conhece(fundo) else GaleriaDeFundos.PADRAO
	$Fundo.texture = GaleriaDeFundos.textura_do_fundo(_fundo_atual)
	# O resto da tela (dialogos de subir fase, dicas) no tom do fundo novo, como
	# as outras telas (ADR 0034).
	theme = TemaDaGaleria.tema(_fundo_atual)
	# A moldura vem do tema do menu; cada botao recebe uma copia com a textura
	# do fundo atual, para o tema compartilhado nao mudar para as outras telas.
	var tema: Theme = $Cartao/Coluna.theme
	var balao: Texture2D = GaleriaDeFundos.textura_do_balao(_fundo_atual)
	for botao: Node in $Cartao/Coluna/Botoes.get_children():
		for estado: StringName in ESTADOS_DO_BALAO:
			var copia: StyleBoxTexture = tema.get_stylebox(estado, &"Button").duplicate() as StyleBoxTexture
			copia.texture = balao
			(botao as Button).add_theme_stylebox_override(estado, copia)
	# A vinha em volta do cartao muda de cor junto com o fundo (ADR 0044).
	($Moldura as MolduraDeVinhas).definir_fundo(_fundo_atual)
	$Galeria.tooltip_text = "trocar o fundo (agora: %s)" % GaleriaDeFundos.nome(_fundo_atual)
	_vestir_botao_da_galeria()


## O botao da galeria e pequeno demais para o balao (as flores cobririam o
## icone): fica um quadradinho de vidro escuro com borda no tom do fundo.
func _vestir_botao_da_galeria() -> void:
	var estados: Dictionary = {
		&"normal": TemaDaGaleria.cor_do_campo(_fundo_atual),
		&"hover": TemaDaGaleria.cor_do_realce(_fundo_atual),
		&"pressed": TemaDaGaleria.cor_do_realce(_fundo_atual).darkened(0.2),
	}
	for estado: StringName in estados:
		var caixa := StyleBoxFlat.new()
		caixa.bg_color = estados[estado]
		caixa.set_border_width_all(1)
		caixa.border_color = TemaDaGaleria.cor_da_borda(_fundo_atual)
		caixa.set_corner_radius_all(6)
		caixa.set_content_margin_all(3.0)
		$Galeria.add_theme_stylebox_override(estado, caixa)
	$Galeria.add_theme_stylebox_override(&"focus", TemaDaGaleria.tema(_fundo_atual).get_stylebox(&"focus", &"Button"))


func fundo_atual() -> String:
	return _fundo_atual


## As fases criadas pelo professor: lista, joga, edita, exclui e exporta.
func _ao_escolher_fase() -> void:
	get_tree().change_scene_to_file(CENA_DA_SELECAO)


func _ao_criar_fase() -> void:
	if not ResourceLoader.exists(CENA_DO_EDITOR):
		return
	# Caminho vazio = editor em branco; preenchido = editar fase existente.
	EditorDeFaseEstado.caminho_para_editar = ""
	get_tree().change_scene_to_file(CENA_DO_EDITOR)



func _ao_subir_fase() -> void:
	$DialogoDeImportacao.popup_centered()


## Subir = VALIDAR e so entao copiar para user://fases. Um .json quebrado que
## entrasse na pasta viraria uma linha "(com erro)" na lista da qual o professor
## teria de se livrar depois -- e melhor recusar na porta, dizendo o porque.
func _ao_escolher_arquivo_para_subir(caminho: String) -> void:
	var resultado: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_arquivo(caminho)
	if not resultado.ok():
		_avisar("este arquivo não é uma fase válida:\n\n%s" % resultado.mensagem())
		return

	var destino: String = CarregadorFaseJson.nome_de_arquivo(resultado.config.titulo)
	if FileAccess.file_exists(destino):
		# Nao sobrescrever calado: o professor pode ter uma fase com o mesmo
		# titulo e perder o trabalho dela sem perceber.
		destino = "%s/%s-%s.json" % [CarregadorFaseJson.pasta_das_fases,
			destino.get_file().get_basename(), resultado.config.id_fase.substr(0, 8)]

	var erros: PackedStringArray = CarregadorFaseJson.salvar(resultado.config, destino)
	if not erros.is_empty():
		_avisar("não foi possível copiar a fase:\n\n%s" % "\n".join(erros))
		return

	_avisar("fase '%s' adicionada.\nela já aparece em 'escolher fase'." % resultado.config.titulo)


func _avisar(mensagem: String) -> void:
	$Aviso.dialog_text = mensagem
	$Aviso.popup_centered()


func _ao_abrir_telemetria() -> void:
	get_tree().change_scene_to_file(CENA_DO_DASHBOARD)


func _ao_sair() -> void:
	# Encerrar a sessao e drenar antes de sair e o que transforma "o jogador
	# fechou o jogo" em SESSAO_ENCERRADA em vez de sessao pendurada em ABERTA.
	if Sessao.ativa:
		Sessao.encerrar()
	await Telemetria.descarregar()
	get_tree().quit()


