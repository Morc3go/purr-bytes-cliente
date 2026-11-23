class_name EscolhaDeGato
extends Control

## Pergunta ao jogador qual gatinho ele quer antes de a fase comecar (ADR 0030).
##
## Um cartao por pelagem, na ordem de PelagemGato.ORDEM, com o proprio desenho
## do jogo ampliado: o cartao em foco mostra o gato sentado e de olho aberto, os
## outros cochilam -- da para ver de longe qual esta escolhido, sem depender so
## da borda do foco. Mouse e teclado fazem a mesma coisa: passar o mouse leva o
## foco, clicar ou apertar Enter confirma.
##
## A tela nao inicia a fase. Ela so avisa a escolha (sinal `escolhido`) e quem a
## abriu decide o que fazer; assim ela serve para qualquer porta de entrada.

signal escolhido(pelagem: String)
signal cancelado()

## Ampliacao inteira: o pixel da arte continua quadrado (ADR 0024).
const ESCALA_DO_GATO: float = 3.0
const TAMANHO_DO_CARTAO: Vector2 = Vector2(112, 128)
const ANIMACAO_EM_FOCO: StringName = &"sentado"
const ANIMACAO_FORA_DE_FOCO: StringName = &"descansar"
## Cartao fora de foco fica um pouco apagado: o escolhido salta aos olhos.
const OPACIDADE_FORA_DE_FOCO: float = 0.7

@onready var _cartoes: HBoxContainer = $Painel/Coluna/Cartoes
@onready var _voltar: Button = $Painel/Coluna/Rodape/Voltar

## pelagem -> Button
var _botoes: Dictionary = {}
var _em_foco: String = ""


func _ready() -> void:
	# Vidro com vinhas, veu e cartoes no tom do fundo escolhido (ADR 0034).
	EnfeiteDaGaleria.enfeitar(self, [$Painel] as Array[Control])
	EnfeiteDaGaleria.veu($Veu)
	for pelagem: String in PelagemGato.ORDEM:
		var cartao: Button = _criar_cartao(pelagem)
		_cartoes.add_child(cartao)
		_botoes[pelagem] = cartao
	_voltar.pressed.connect(_cancelar)
	# Comeca no gato da ultima partida: quem ja escolheu so aperta Enter.
	focar(PelagemGato.preferida())


func _criar_cartao(pelagem: String) -> Button:
	var cartao := Button.new()
	cartao.name = "Cartao_%s" % pelagem
	cartao.custom_minimum_size = TAMANHO_DO_CARTAO
	cartao.focus_mode = Control.FOCUS_ALL
	cartao.theme_type_variation = &"CartaoDeGato"
	cartao.tooltip_text = PelagemGato.nome(pelagem)

	var gato := AnimatedSprite2D.new()
	gato.name = "Gato"
	gato.sprite_frames = PelagemGato.quadros(pelagem)
	gato.scale = Vector2.ONE * ESCALA_DO_GATO
	gato.animation = ANIMACAO_FORA_DE_FOCO
	cartao.add_child(gato)

	var nome := Label.new()
	nome.name = "Nome"
	nome.text = PelagemGato.nome(pelagem)
	nome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nome.add_theme_font_size_override(&"font_size", 11)
	nome.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	nome.offset_top = -22.0
	nome.offset_bottom = -6.0
	cartao.add_child(nome)

	# O desenho acompanha o tamanho do cartao (o container pode esticar).
	cartao.resized.connect(func() -> void:
		gato.position = Vector2(cartao.size.x * 0.5, cartao.size.y * 0.42))
	cartao.focus_entered.connect(_destacar.bind(pelagem))
	cartao.mouse_entered.connect(cartao.grab_focus)
	cartao.pressed.connect(func() -> void: escolhido.emit(pelagem))
	return cartao


func focar(pelagem: String) -> void:
	var alvo: String = pelagem if _botoes.has(pelagem) else PelagemGato.PADRAO
	(_botoes[alvo] as Button).grab_focus()
	_destacar(alvo)


func em_foco() -> String:
	return _em_foco


func cartao(pelagem: String) -> Button:
	return _botoes.get(pelagem) as Button


func _destacar(pelagem: String) -> void:
	_em_foco = pelagem
	for outra: String in _botoes:
		var cartao_da_vez: Button = _botoes[outra] as Button
		var gato: AnimatedSprite2D = cartao_da_vez.get_node("Gato") as AnimatedSprite2D
		gato.play(ANIMACAO_EM_FOCO if outra == pelagem else ANIMACAO_FORA_DE_FOCO)
		cartao_da_vez.modulate.a = 1.0 if outra == pelagem else OPACIDADE_FORA_DE_FOCO


func _cancelar() -> void:
	cancelado.emit()


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_cancelar()
