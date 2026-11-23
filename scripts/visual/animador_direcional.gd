class_name AnimadorDirecional
extends AnimatedSprite2D

## Escolhe a animacao de andar pela direcao da velocidade do corpo.
##
## AnimatedSprite2D + SpriteFrames (e nao AnimationPlayer mexendo em
## Sprite2D.frame) porque aqui a animacao e so "qual quadro da folha mostrar":
## SpriteFrames guarda isso como dado, editavel no painel SpriteFrames do
## editor, e o no ja cuida do tempo de cada quadro.
##
## Gato e cachorro usam este mesmo script (regra de ouro da secao 3: a mesma
## linha em dois personagens pertence a um lugar so). A folha dos dois segue a
## mesma grade -- ver tools/gerar_sprite_frames.gd.

const ANDAR_BAIXO: StringName = &"andar_baixo"
const ANDAR_CIMA: StringName = &"andar_cima"
const ANDAR_DIREITA: StringName = &"andar_direita"
const ANDAR_ESQUERDA: StringName = &"andar_esquerda"
const PARADO: StringName = &"parado"
const DESCANSAR: StringName = &"descansar"
const SENTADO: StringName = &"sentado"

## Quadro do ciclo de andar usado como pose parada naquela direcao.
const QUADRO_PARADO_NA_DIRECAO: int = 0

## Abaixo disto o corpo esta "parado": o lerp do jogador leva alguns quadros
## para zerar, e sem limiar o gato ficaria andando no lugar ao soltar a tecla.
@export_range(0.0, 50.0, 0.5) var velocidade_minima: float = 6.0

## Velocidade em que a animacao roda no ritmo gravado no SpriteFrames. Mais
## rapido que isso acelera os passos na mesma proporcao, para o pe nao
## "patinar" no chao quando o cachorro corre.
@export_range(1.0, 300.0, 1.0) var velocidade_de_referencia: float = 60.0

## Para folhas sem vista de costas (a do cachorro): andando na vertical, o
## personagem continua na ultima lateral em vez de mostrar a frente -- de
## frente, sentado, ele pareceria deslizar pelo corredor.
@export var lateral_no_eixo_vertical: bool = false

## Ao parar, fica virado para onde andava (primeiro quadro do andar daquela
## direcao, congelado) em vez de voltar a olhar para a frente. Ligado no gato
## (pedido da equipe); o cachorro continua com o "parado" dele, que abana o rabo.
@export var parar_olhando_para_onde_andava: bool = false

var _ultima_lateral: StringName = ANDAR_DIREITA
var _ultima_andanca: StringName = &""


func _ready() -> void:
	if sprite_frames != null and sprite_frames.has_animation(PARADO):
		play(PARADO)


## Chamado pelo dono depois do move_and_slide(), com a velocidade real.
func atualizar(velocidade: Vector2) -> void:
	var nome: StringName = animacao_para(velocidade)
	if nome == ANDAR_DIREITA or nome == ANDAR_ESQUERDA:
		_ultima_lateral = nome
	if nome != PARADO:
		_ultima_andanca = nome
	elif _pode_parar_na_direcao():
		_parar_na_direcao()
		return
	if nome == PARADO:
		speed_scale = 1.0
	else:
		speed_scale = maxf(1.0, velocidade.length() / velocidade_de_referencia)
	if animation != nome or not is_playing():
		play(nome)


func _pode_parar_na_direcao() -> bool:
	return parar_olhando_para_onde_andava and _ultima_andanca != &"" \
		and sprite_frames != null and sprite_frames.has_animation(_ultima_andanca)


func _parar_na_direcao() -> void:
	speed_scale = 1.0
	if animation != _ultima_andanca:
		animation = _ultima_andanca
	if is_playing():
		pause()
	frame = QUADRO_PARADO_NA_DIRECAO


## Parado e virado para a direcao em que andava (so com
## parar_olhando_para_onde_andava). Para os testes.
func parado_na_direcao() -> bool:
	return not is_playing() and animation == _ultima_andanca and _ultima_andanca != &""


## Primeiro passo do cochilo: senta de olho aberto (o rabo mexe devagar).
func sentar() -> void:
	if sprite_frames != null and sprite_frames.has_animation(SENTADO) and animation != SENTADO:
		speed_scale = 1.0
		play(SENTADO)


## Chamado pelo Jogador apos alguns segundos sem entrada (ver
## tempo_para_sentar_s em jogador.gd). So troca de fato se a
## SpriteFrames tiver a animacao "descansar" -- e por isso que o Cachorro, que
## usa este MESMO script (regra de ouro da secao 3), nunca entra nesse estado:
## ninguem chama descansar() nele, e cachorro_frames.tres nem precisa da
## animacao para o resto do script continuar funcionando normalmente.
func descansar() -> void:
	if sprite_frames != null and sprite_frames.has_animation(DESCANSAR) and animation != DESCANSAR:
		speed_scale = 1.0
		play(DESCANSAR)


## Separada de atualizar() para ser testavel sem SceneTree: e a regra inteira
## (eixo dominante decide; empate fica no horizontal). Nao muda estado -- a
## ultima lateral so e lembrada por atualizar().
func animacao_para(velocidade: Vector2) -> StringName:
	if velocidade.length() < velocidade_minima:
		return PARADO
	if absf(velocidade.x) >= absf(velocidade.y):
		return ANDAR_DIREITA if velocidade.x > 0.0 else ANDAR_ESQUERDA
	if lateral_no_eixo_vertical:
		return _ultima_lateral
	return ANDAR_BAIXO if velocidade.y > 0.0 else ANDAR_CIMA
