class_name TelaCaptura
extends CanvasLayer

## Tela de interceptacao.
##
## Enquadramento pedagogico, nao punitivo: ser pego custa vida e pontos e devolve
## o pacote ao inicio, mas nao encerra o jogo. O texto explica o porque -- que o
## pacote viajava em texto claro -- porque a tela de erro e o momento em que o
## jogador esta mais disposto a ler a explicacao.

signal encerrada()

@export_range(0.5, 10.0, 0.1) var duracao_s: float = 2.5

@onready var _mensagem: Label = $Raiz/Painel/Coluna/Mensagem
@onready var _explicacao: Label = $Raiz/Painel/Coluna/Explicacao
@onready var _temporizador: Timer = $Temporizador


func _ready() -> void:
	visible = false
	_temporizador.timeout.connect(_ao_terminar)


func mostrar(mensagem: String, explicacao: String) -> void:
	_mensagem.text = mensagem
	_explicacao.text = explicacao
	visible = true
	_temporizador.start(duracao_s)


func _ao_terminar() -> void:
	visible = false
	encerrada.emit()
