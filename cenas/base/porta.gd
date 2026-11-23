class_name Porta
extends Area2D

## O ponto de saida da fase, agora com estado: trancado ate o jogador ter todos
## os pacotes, aberto depois.
##
## Antes a saida era invisivel -- o jogador atravessava um pedaco de chao e a
## fase acabava. Uma porta que se ve trancada transforma "ande ate ali" em um
## objetivo: da para olhar do outro lado do labirinto e saber que ainda falta
## coisa, que e o que faz os pacotes valerem a pena procurar.
##
## Arte: arco de pedra com porta de madeira, fechada enquanto falta pacote e
## aberta (a passagem escura) quando o gato resgatou todas as mensagens. O
## desenho tem 18x16, do tamanho de uma celula, proporcional ao gato e aos
## cachorros (ADR 0035; antes era 24x32 e subia pela cerca). Os pes ficam na
## base da celula, e a area de colisao continua sendo a celula.

const TEXTURA_FECHADA: Texture2D = preload("res://recursos/arte/porta_fechada.png")
const TEXTURA_ABERTA: Texture2D = preload("res://recursos/arte/porta_aberta.png")
## Metade da celula: onde fica a base dela em relacao ao centro do no.
const _BASE_DA_CELULA: float = 8.0

var trancada: bool = true


func definir_trancada(valor: bool) -> void:
	if trancada == valor:
		return
	trancada = valor
	queue_redraw()


func textura_atual() -> Texture2D:
	return TEXTURA_FECHADA if trancada else TEXTURA_ABERTA


func _draw() -> void:
	var textura: Texture2D = textura_atual()
	var tamanho: Vector2 = textura.get_size()
	# A aberta tem 2 px a mais embaixo (a folha da porta solta do batente): a
	# base do batente das duas fica na mesma linha.
	var sobra: float = tamanho.y - TEXTURA_FECHADA.get_size().y
	draw_texture(textura, Vector2(-floorf(tamanho.x / 2.0), _BASE_DA_CELULA - tamanho.y + sobra))
