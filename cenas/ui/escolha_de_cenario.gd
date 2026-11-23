class_name EscolhaDeCenario
extends Control

## Pergunta ao jogador em qual cenario ele quer jogar, logo depois da escolha do
## gatinho (ADR 0036). Mesmo jeito da EscolhaDeGato: um cartao por cenario, com
## a miniatura do labirinto naquele cenario; mouse e teclado fazem a mesma
## coisa, passar o mouse leva o foco, clicar ou Enter confirma, Esc volta.
##
## O cartao que comeca em foco e o cenario que a fase sugere (o que o professor
## escolheu no editor): quem so aperta Enter joga como o professor montou.
## Cenario e so aparencia, entao a escolha nao muda regra nem telemetria.
##
## A tela nao inicia a fase: avisa a escolha (sinal `escolhido`) e quem a abriu
## decide o que fazer.

signal escolhido(cenario: String)
signal cancelado()

const TAMANHO_DO_CARTAO: Vector2 = Vector2(124, 90)
## Cartao fora de foco fica um pouco apagado: o escolhido salta aos olhos.
const OPACIDADE_FORA_DE_FOCO: float = 0.7

## Cenario sugerido pela fase. Definir antes de entrar na arvore.
var sugerido: String = CenarioDoLabirinto.PADRAO

@onready var _cartoes: GridContainer = $Painel/Coluna/Cartoes
@onready var _subtitulo: Label = $Painel/Coluna/Subtitulo
@onready var _voltar: Button = $Painel/Coluna/Rodape/Voltar

## cenario -> Button
var _botoes: Dictionary = {}
var _em_foco: String = ""


func _ready() -> void:
	# Vidro com vinhas, veu e cartoes no tom do fundo escolhido (ADR 0034).
	EnfeiteDaGaleria.enfeitar(self, [$Painel] as Array[Control])
	EnfeiteDaGaleria.veu($Veu)
	sugerido = CenarioDoLabirinto.resolver(sugerido)
	_subtitulo.text = "a fase sugere: %s · só muda o visual, as regras são as mesmas" \
		% CenarioDoLabirinto.nome(sugerido)
	for cenario: String in CenarioDoLabirinto.ORDEM:
		var cartao: Button = _criar_cartao(cenario)
		_cartoes.add_child(cartao)
		_botoes[cenario] = cartao
	_voltar.pressed.connect(_cancelar)
	focar(sugerido)


func _criar_cartao(cenario: String) -> Button:
	var cartao := Button.new()
	cartao.name = "Cartao_%s" % cenario
	cartao.custom_minimum_size = TAMANHO_DO_CARTAO
	cartao.focus_mode = Control.FOCUS_ALL
	cartao.theme_type_variation = &"CartaoDeGato"
	cartao.tooltip_text = CenarioDoLabirinto.nome(cenario)

	var previa := TextureRect.new()
	previa.name = "Previa"
	previa.texture = CenarioDoLabirinto.textura_da_previa(cenario)
	previa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	previa.stretch_mode = TextureRect.STRETCH_KEEP
	previa.position = Vector2(6, 5)
	cartao.add_child(previa)

	var nome := Label.new()
	nome.name = "Nome"
	nome.text = CenarioDoLabirinto.nome(cenario)
	nome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nome.add_theme_font_size_override(&"font_size", 8)
	nome.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	nome.offset_top = -19.0
	nome.offset_bottom = -5.0
	cartao.add_child(nome)

	cartao.focus_entered.connect(_destacar.bind(cenario))
	cartao.mouse_entered.connect(cartao.grab_focus)
	cartao.pressed.connect(func() -> void: escolhido.emit(cenario))
	return cartao


func focar(cenario: String) -> void:
	var alvo: String = CenarioDoLabirinto.resolver(cenario)
	(_botoes[alvo] as Button).grab_focus()
	_destacar(alvo)


func em_foco() -> String:
	return _em_foco


func cartao(cenario: String) -> Button:
	return _botoes.get(cenario) as Button


func _destacar(cenario: String) -> void:
	_em_foco = cenario
	for outro: String in _botoes:
		(_botoes[outro] as Button).modulate.a = 1.0 if outro == cenario else OPACIDADE_FORA_DE_FOCO


func _cancelar() -> void:
	cancelado.emit()


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_cancelar()
