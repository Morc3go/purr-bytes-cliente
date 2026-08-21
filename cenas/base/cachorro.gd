class_name Cachorro
extends CharacterBody2D

## O cachorro farejador representa o interceptador na rede.
##
## Marco 0 entrega so o corpo: seguir um caminho ja calculado e avisar contato.
## Quem calcula o caminho e scripts/ia/navegacao.gd (AStarGrid2D, Marco 1), e
## quem decide para onde ir e o Diretor (Marco 2). A separacao e proposital: o
## cachorro nunca recebe a posicao do jogador de presente -- ele recebe um
## caminho ate um ponto, e esse ponto vem de crenca, nao de conhecimento.

signal contato_com_jogador(jogador: Node2D)
signal destino_alcancado()

@export_range(10.0, 200.0, 1.0) var velocidade: float = 45.0

## Distancia para considerar um ponto do caminho como alcancado. Menor que meia
## celula (8 px) faria o corpo orbitar o ponto sem nunca chegar.
@export_range(1.0, 16.0, 0.5) var tolerancia_de_chegada: float = 4.0

var _caminho: PackedVector2Array = PackedVector2Array()
var _indice: int = 0

@onready var _area_de_contato: Area2D = $AreaDeContato


func _ready() -> void:
	_area_de_contato.body_entered.connect(_ao_encostar)


func _physics_process(_delta: float) -> void:
	if _indice >= _caminho.size():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var alvo: Vector2 = _caminho[_indice]
	if global_position.distance_to(alvo) <= tolerancia_de_chegada:
		_indice += 1
		if _indice >= _caminho.size():
			destino_alcancado.emit()
		return

	velocity = global_position.direction_to(alvo) * velocidade
	move_and_slide()


## Caminho em coordenadas de mundo, ja convertido de celulas pelo chamador.
func definir_caminho(pontos: PackedVector2Array) -> void:
	_caminho = pontos
	_indice = 0


func parar() -> void:
	_caminho = PackedVector2Array()
	_indice = 0
	velocity = Vector2.ZERO


func caminho_atual() -> PackedVector2Array:
	return _caminho


func indice_atual() -> int:
	return _indice


func _ao_encostar(corpo: Node2D) -> void:
	if corpo is Jogador:
		contato_com_jogador.emit(corpo)
