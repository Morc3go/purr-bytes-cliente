class_name Enquadramento
extends RefCounted

## Quanto a camera aproxima o labirinto para ele ocupar a tela (ADR 0024).
##
## Funcao pura, separada de fase_base.gd, para os testes conferirem a conta sem
## abrir janela.
##
## O problema: pixel art so fica com todos os pixels do MESMO tamanho quando
## cada pixel de arte vira um numero inteiro de pixels do monitor. A tela base
## do jogo e 640x360 e a janela estica isso por um fator "escala_da_janela"
## (2 numa janela 1280x720, 3 em 1920x1080). O pixel de arte ocupa
## escala_da_janela * zoom pixels do monitor, entao o zoom "limpo" e k / escala
## para k inteiro.
##
## A regra: preencher a area util o maximo possivel; se o zoom limpo mais
## proximo (para baixo) perde no maximo PERDA_ACEITAVEL do tamanho, usa o
## limpo; senao usa o zoom exato. Assim, em 1280x720 e 1920x1080 o labirinto
## padrao fica nitido, e numa janela de tamanho quebrado ele ainda enche a tela
## em vez de encolher pela metade so para ficar com pixel inteiro.

## Abaixo de 90% do tamanho que caberia, encolher para ficar nitido nao compensa.
const PERDA_ACEITAVEL: float = 0.9
## Labirinto um pouco maior que a tela ainda e mostrado inteiro, afastando a
## camera; so abaixo disto (tudo pequeno demais para enxergar) ela passa a
## seguir o gato.
const ZOOM_MINIMO_PARA_VER_TUDO: float = 0.75


## Zoom para mostrar o labirinto INTEIRO na area util (camera parada no meio).
static func zoom_para_caber(area_util: Vector2, mundo: Vector2, escala_da_janela: float,
		zoom_maximo: float) -> float:
	if mundo.x <= 0.0 or mundo.y <= 0.0:
		return 1.0
	var exato: float = minf(minf(area_util.x / mundo.x, area_util.y / mundo.y), zoom_maximo)
	return _limpo_ou_exato(exato, escala_da_janela)


## Zoom para um labirinto MAIOR que a tela: a camera segue o gato e o zoom fica
## perto de 1, so ajustado para o pixel inteiro quando isso custa pouco.
static func zoom_para_seguir(escala_da_janela: float) -> float:
	return _limpo_ou_exato(1.0, escala_da_janela)


## Da para mostrar o labirinto inteiro sem afastar demais?
static func cabe(area_util: Vector2, mundo: Vector2) -> bool:
	if mundo.x <= 0.0 or mundo.y <= 0.0:
		return true
	return minf(area_util.x / mundo.x, area_util.y / mundo.y) >= ZOOM_MINIMO_PARA_VER_TUDO


static func _limpo_ou_exato(exato: float, escala_da_janela: float) -> float:
	if escala_da_janela <= 0.0:
		return exato
	var pixels_inteiros: float = floorf(escala_da_janela * exato + 0.0001)
	var limpo: float = pixels_inteiros / escala_da_janela
	if pixels_inteiros >= 1.0 and limpo >= exato * PERDA_ACEITAVEL:
		return limpo
	return exato
