class_name Jogador
extends CharacterBody2D

## O jogador transporta o pacote de dados pelo labirinto -- que representa a
## topologia da rede. Em texto claro ele e interceptavel; com a cifra ativa, nao.
##
## Movimento com CharacterBody2D + move_and_slide(): a colisao com as paredes sai
## do TileSet, entao o labirinto desenhado no editor ja e o labirinto jogavel,
## sem nenhuma tabela de colisao paralela para manter sincronizada.
##
## Este no nao conhece a fase. Ele emite sinais e expoe estado; quem decide
## consequencia e fase_base.gd (secao 9: sinal de baixo para cima).

signal protecao_alterada(ativa: bool, restante_s: float)
signal protecao_expirou()

@export_range(10.0, 200.0, 1.0) var velocidade: float = 70.0

## Aceleracao alta de proposito: labirinto com corredor estreito fica
## intoleravel com inercia. Nao e realismo, e legibilidade de controle.
@export_range(1.0, 60.0, 0.5) var resposta: float = 20.0

var protecao_ativa: bool = false

var _restante_de_protecao_s: float = 0.0
var _entrada_habilitada: bool = true


func _physics_process(delta: float) -> void:
	if _restante_de_protecao_s > 0.0:
		_restante_de_protecao_s = maxf(0.0, _restante_de_protecao_s - delta)
		protecao_alterada.emit(true, _restante_de_protecao_s)
		if is_zero_approx(_restante_de_protecao_s):
			protecao_ativa = false
			protecao_alterada.emit(false, 0.0)
			protecao_expirou.emit()

	var direcao: Vector2 = Vector2.ZERO
	if _entrada_habilitada:
		# Input.get_vector ja normaliza e ja resolve teclas opostas apertadas
		# juntas -- nao ha motivo para reimplementar isso.
		direcao = Input.get_vector("mover_esquerda", "mover_direita", "mover_cima", "mover_baixo")

	velocity = velocity.lerp(direcao * velocidade, clampf(resposta * delta, 0.0, 1.0))
	move_and_slide()


## Chamado pela fase quando um comando de cifra e aceito. A duracao vem do
## FaseConfig: e ela que forca o jogador a reaplicar a cifra, e a repeticao com
## intencao e o ponto pedagogico da mecanica.
func ativar_protecao(duracao_s: float) -> void:
	protecao_ativa = duracao_s > 0.0
	_restante_de_protecao_s = maxf(0.0, duracao_s)
	protecao_alterada.emit(protecao_ativa, _restante_de_protecao_s)


func cancelar_protecao() -> void:
	protecao_ativa = false
	_restante_de_protecao_s = 0.0
	protecao_alterada.emit(false, 0.0)


## Usado enquanto o terminal esta aberto e na tela de captura: o jogador nao
## deve andar as cegas atras da janela de comando.
func definir_entrada_habilitada(habilitada: bool) -> void:
	_entrada_habilitada = habilitada
	if not habilitada:
		velocity = Vector2.ZERO


func reposicionar(destino: Vector2) -> void:
	global_position = destino
	velocity = Vector2.ZERO
