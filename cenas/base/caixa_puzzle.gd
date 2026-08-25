class_name CaixaPuzzle
extends CanvasLayer

## A caixinha que abre ao chegar num pacote: um enunciado curto e um botao por
## opcao, na cor do algoritmo.
##
## Botao em vez de campo de texto de proposito. O terminal ja mede digitacao
## (tempo_resposta_ms, erro lexico, erro sintatico); aqui o que se mede e
## ESCOLHA -- e um erro de digitacao no meio disso viraria ruido no dado, nao
## informacao sobre o que o jogador entendeu.
##
## Erro nao fecha a caixa: mostra o porque e deixa tentar de novo, custando
## pontos. Fechar e reabrir a cada erro so acrescentaria caminhada, nao licao
## (secao 7 do CLAUDE.md: o erro e custo pedagogico, nao punicao).

signal respondido(correto: bool, opcao: String, tempo_resposta_ms: int)
## Fechar sem responder. O pacote continua onde estava: sair da caixa e uma
## saida legitima ("nao sei ainda, volto depois"), nao uma forma de burlar o
## desafio -- sem o pacote a porta continua trancada.
signal cancelada()

@onready var _enunciado: Label = $Raiz/Painel/Coluna/Enunciado
@onready var _opcoes: HBoxContainer = $Raiz/Painel/Coluna/Opcoes
@onready var _retorno: Label = $Raiz/Painel/Coluna/Retorno

var _configuracao: PacoteConfig = null
var _marca_de_abertura: int = 0


func _ready() -> void:
	visible = false


## A arvore fica pausada enquanto a caixa esta aberta, e no pausada nao recebe
## entrada -- por isso a tecla de sair e tratada AQUI (a caixa tem process_mode
## ALWAYS) e nao em fase_base.gd, que ficaria surdo.
func _unhandled_input(evento: InputEvent) -> void:
	if not visible:
		return
	if evento.is_action_pressed("pausar"):
		get_viewport().set_input_as_handled()
		cancelada.emit()


func abrir(config: PacoteConfig) -> void:
	_configuracao = config
	_enunciado.text = config.enunciado
	_retorno.text = "qual ferramenta resolve este caso?"
	_retorno.modulate = Color.WHITE

	for antigo: Node in _opcoes.get_children():
		antigo.queue_free()

	for opcao: String in config.opcoes:
		var botao := Button.new()
		botao.text = LegendaCores.nome(opcao)
		botao.add_theme_font_size_override("font_size", 10)
		# A cor do botao e a mesma do cachorro que exige aquela cifra: e assim
		# que a caixa cobra a legenda do menu em vez de ser um quiz avulso.
		botao.add_theme_color_override("font_color", LegendaCores.cor(opcao))
		botao.pressed.connect(_ao_escolher.bind(opcao))
		_opcoes.add_child(botao)

	visible = true
	_marca_de_abertura = Relogio.marca_ms()
	if _opcoes.get_child_count() > 0:
		(_opcoes.get_child(0) as Button).grab_focus()


func fechar() -> void:
	visible = false
	_configuracao = null


func esta_aberta() -> bool:
	return visible


## Usada pelos testes e pelo teclado: responde como se o botao tivesse sido
## clicado, sem depender de simular evento de mouse.
func escolher(opcao: String) -> void:
	_ao_escolher(opcao)


func _ao_escolher(opcao: String) -> void:
	if _configuracao == null:
		return

	var correto: bool = opcao == _configuracao.resposta_correta
	var decorrido: int = Relogio.decorrido_ms(_marca_de_abertura)

	if correto:
		_retorno.text = _configuracao.explicacao_correta
		_retorno.modulate = LegendaCores.cor(opcao)
	else:
		_retorno.text = "%s nao resolve este caso. leia de novo e tente outra." \
			% LegendaCores.nome(opcao)
		_retorno.modulate = Color(1.0, 0.55, 0.5)
		# O cronometro reinicia a cada tentativa, como no terminal: cada
		# tentativa_comando mede o tempo DAQUELA decisao, nao o acumulado.
		_marca_de_abertura = Relogio.marca_ms()

	respondido.emit(correto, opcao, decorrido)
