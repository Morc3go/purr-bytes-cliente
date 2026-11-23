class_name Pacote
extends Area2D

## Um pacote de dados no labirinto. Nao decide nada: avisa que o jogador
## encostou e obedece quando mandam coletar -- quem decide se abre a caixa de
## puzzle ou coleta direto e fase_base.gd (secao 9: sinal de baixo para cima).
##
## Desenho (ADR 0043): um dos tres itens que a equipe desenhou para o gato
## buscar -- novelo, peixe e rato --, no lugar do losango amarelo provisorio.
## Os tres se revezam pela ordem dos pacotes na fase (o primeiro e novelo, o
## segundo peixe, o terceiro rato...). E so aparencia: a pergunta, a coleta e a
## telemetria do pacote nao mudam.

signal alcancado(pacote: Pacote)

const ITENS: Array[Texture2D] = [
	preload("res://recursos/arte/itens/novelo.png"),
	preload("res://recursos/arte/itens/peixe.png"),
	preload("res://recursos/arte/itens/rato.png"),
]

var configuracao: PacoteConfig = null
var coletado: bool = false

@onready var _colisao: CollisionShape2D = $Colisao
@onready var _item: Sprite2D = $Item


func _ready() -> void:
	body_entered.connect(_ao_entrar)


## indice = posicao do pacote na fase; escolhe qual dos tres itens aparece.
func definir(config: PacoteConfig, indice: int = 0) -> void:
	configuracao = config
	_item.texture = ITENS[indice % ITENS.size()]


func item() -> Texture2D:
	return _item.texture


func coletar() -> void:
	if coletado:
		return
	coletado = true
	# Desligar a colisao adiado: o Area2D esta no meio da propria notificacao de
	# overlap quando isto e chamado, e mexer em CollisionShape2D dentro dela e
	# erro de fisica em andamento no Godot.
	_colisao.set_deferred("disabled", true)
	_item.visible = false


func _ao_entrar(corpo: Node2D) -> void:
	if coletado or not (corpo is Jogador):
		return
	alcancado.emit(self)
