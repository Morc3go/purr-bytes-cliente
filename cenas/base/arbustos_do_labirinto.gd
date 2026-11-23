class_name ArbustosDoLabirinto
extends Node2D

## A roupa do labirinto: chao, cerca e enfeites do cenario da fase (ADR 0025 e 0035).
##
## So desenha. Quem continua decidindo o que e parede e o TileMapLayer, pela
## camada de dados "solido": colisao e A* nao mudam, e o labirinto de 16x16 por
## celula tambem nao. Este no fica como filho do labirinto (mesmas coordenadas),
## le as celulas solidas e pinta por cima; os tiles de placeholder ficam
## invisiveis (self_modulate transparente nao afeta a colisao).
##
## Cada celula de parede e montada em quatro quartos de 8x8. O quarto olha os
## dois vizinhos do seu lado e a diagonal entre eles e escolhe a peca: quina de
## fora, borda horizontal, borda vertical, quina de dentro ou miolo. Assim 20
## pecas cobrem qualquer formato de parede que o gerador de mapas criar. Cada
## cenario tem a sua folha de pecas, com o mesmo arranjo e outra paleta; no lago
## a parede e agua, com espuma na beira e a borda escura das tabuas.
##
## Enfeites (ADR 0035): poucos, pequenos e sempre dentro de uma celula. Nunca em
## cima da cerca, nunca nas celulas da entrada, da saida, dos pacotes e de onde
## nascem gato e cachorros, nem do lado delas. Os maiores (bonecos de neve) so
## vao em becos sem saida, por onde ninguem precisa passar. O sorteio usa a
## semente do mapa: a mesma fase tem sempre os mesmos enfeites nos mesmos lugares.

const GRAMA: Texture2D = preload("res://recursos/arte/grama.png")
const PECAS: Texture2D = preload("res://recursos/arte/arbusto_pecas.png")
const PECA: int = 8

enum Tipo { QUINA_DE_FORA, BORDA_HORIZONTAL, BORDA_VERTICAL, QUINA_DE_DENTRO, MIOLO }

## Quartos da celula, na ordem das colunas da folha de pecas.
const _QUARTOS: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]

## Distancia minima (em celulas, soma das diferencas) entre dois enfeites e
## entre dois bonecos de neve: espalhados, e nao amontoados num canto.
const _ESPACO_ENTRE_ENFEITES: int = 4
const _ESPACO_ENTRE_BECOS: int = 10

## Em volta do labirinto, ate a borda da tela, o desenho continua: a cerca do
## cenario (ou a agua, no lago) se estende para fora, e o labirinto parece
## escavado no proprio cenario. Antes, nessa faixa aparecia o wallpaper da
## galeria, que nao combinava com todos os cenarios (ADR 0038). Doze celulas
## cobrem a tela mesmo num mapa pequeno ampliado. So desenho: fora do mapa nao
## ha colisao nem A*, como sempre.
const MARGEM_EXTERNA: int = 12

## Beira da agua no lago.
const _ESPUMA: Color = Color("cdf3ea")
const _AGUA_FUNDA: Color = Color("3f8f86")
const _BORDA_DAS_TABUAS: Color = Color("6e3a20")

var _labirinto: TileMapLayer = null
var _paredes: Dictionary = {}
var _regiao: Rect2i = Rect2i()
## Celulas da faixa de fora do mapa, desenhadas como cerca (ou agua).
var _fora: Array[Vector2i] = []

var _cenario: String = CenarioDoLabirinto.PADRAO
var _chao: Texture2D = GRAMA
var _muro: Texture2D = PECAS
var _ocupadas: Array[Vector2i] = []
## {"tex": Texture2D, "celula": Vector2i, "base": Vector2}, em ordem de desenho.
var _enfeites: Array[Dictionary] = []
## {"pos": Vector2, "cor": Color}
var _pontinhos: Array[Dictionary] = []


## Le o labirinto ja pintado e passa a desenhar por cima dele, no cenario pedido.
## `ocupadas` sao as celulas que nao podem ter enfeite (entrada, saida, pacotes,
## cachorros); `semente` escolhe onde os enfeites caem.
func vestir(labirinto: TileMapLayer, cenario: String = CenarioDoLabirinto.PADRAO,
		ocupadas: Array[Vector2i] = [], semente: int = 0) -> void:
	_labirinto = labirinto
	_regiao = labirinto.get_used_rect()
	_paredes.clear()
	for celula: Vector2i in labirinto.get_used_cells():
		var dado: TileData = labirinto.get_cell_tile_data(celula)
		if dado != null and bool(dado.get_custom_data("solido")):
			_paredes[celula] = true
	labirinto.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
	_cenario = CenarioDoLabirinto.resolver(cenario)
	_chao = CenarioDoLabirinto.textura_do_chao(_cenario)
	_muro = CenarioDoLabirinto.textura_do_muro(_cenario)
	_ocupadas = ocupadas.duplicate()
	_fora.clear()
	var faixa: Rect2i = _regiao.grow(MARGEM_EXTERNA)
	for y: int in range(faixa.position.y, faixa.end.y):
		for x: int in range(faixa.position.x, faixa.end.x):
			if not _regiao.has_point(Vector2i(x, y)):
				_fora.append(Vector2i(x, y))
	# O chao e uma imagem de 64x64 repetida em ladrilho sob o mapa inteiro.
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_espalhar(semente)
	queue_redraw()


func e_parede(celula: Vector2i) -> bool:
	return _paredes.has(celula)


func cenario() -> String:
	return _cenario


## Copia dos enfeites postos, para os testes conferirem onde cairam.
func enfeites() -> Array[Dictionary]:
	return _enfeites.duplicate()


func pontinhos() -> Array[Dictionary]:
	return _pontinhos.duplicate()


## Qual peca vai no quarto (dx, dy) de uma celula de parede. Fora do mapa conta
## como chao: a borda externa do labirinto tambem ganha contorno.
func tipo_do_quarto(celula: Vector2i, quarto: Vector2i) -> Tipo:
	var horizontal: bool = e_parede(celula + Vector2i(quarto.x, 0))
	var vertical: bool = e_parede(celula + Vector2i(0, quarto.y))
	if not horizontal and not vertical:
		return Tipo.QUINA_DE_FORA
	if horizontal and not vertical:
		return Tipo.BORDA_HORIZONTAL
	if vertical and not horizontal:
		return Tipo.BORDA_VERTICAL
	if not e_parede(celula + quarto):
		return Tipo.QUINA_DE_DENTRO
	return Tipo.MIOLO


## Celulas fora do mapa que tambem recebem cerca no desenho (ADR 0038).
func celulas_de_fora() -> Array[Vector2i]:
	return _fora.duplicate()


## Para o DESENHO, fora do mapa e cerca: a borda externa se emenda com a faixa
## de fora, sem contorno. (tipo_do_quarto, que trata fora como chao, continua
## valendo para quem pergunta pela forma do mapa.)
func _parede_no_desenho(celula: Vector2i) -> bool:
	return e_parede(celula) or not _regiao.has_point(celula)


func _tipo_no_desenho(celula: Vector2i, quarto: Vector2i) -> Tipo:
	var horizontal: bool = _parede_no_desenho(celula + Vector2i(quarto.x, 0))
	var vertical: bool = _parede_no_desenho(celula + Vector2i(0, quarto.y))
	if not horizontal and not vertical:
		return Tipo.QUINA_DE_FORA
	if horizontal and not vertical:
		return Tipo.BORDA_HORIZONTAL
	if vertical and not horizontal:
		return Tipo.BORDA_VERTICAL
	if not _parede_no_desenho(celula + quarto):
		return Tipo.QUINA_DE_DENTRO
	return Tipo.MIOLO


## Beco sem saida: chao com cerca em tres lados.
func e_beco(celula: Vector2i) -> bool:
	return not e_parede(celula) and _paredes_em_volta(celula) >= 3


func _paredes_em_volta(celula: Vector2i) -> int:
	var total: int = 0
	for direcao: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if e_parede(celula + direcao):
			total += 1
	return total


func _perto_de_ocupada(celula: Vector2i) -> bool:
	for ocupada: Vector2i in _ocupadas:
		if absi(ocupada.x - celula.x) + absi(ocupada.y - celula.y) <= 1:
			return true
	return false


func _longe_de(celula: Vector2i, outras: Array[Vector2i], distancia: int) -> bool:
	for outra: Vector2i in outras:
		if absi(outra.x - celula.x) + absi(outra.y - celula.y) < distancia:
			return false
	return true


## Embaralha com o sorteio da fase (e nao com o aleatorio global): mesma
## semente, mesmos lugares.
static func _embaralhar(lista: Array, sorteio: RandomNumberGenerator) -> void:
	for i: int in range(lista.size() - 1, 0, -1):
		var j: int = sorteio.randi_range(0, i)
		var troca: Variant = lista[i]
		lista[i] = lista[j]
		lista[j] = troca


func _espalhar(semente: int) -> void:
	_enfeites.clear()
	_pontinhos.clear()
	var dados: Dictionary = CenarioDoLabirinto.dados(_cenario)
	if dados.is_empty() or _labirinto.tile_set == null:
		return
	var tamanho := Vector2(_labirinto.tile_set.tile_size)
	var sorteio := RandomNumberGenerator.new()
	sorteio.seed = hash([_cenario, semente])

	var chao: Array[Vector2i] = []
	for y: int in range(_regiao.position.y, _regiao.end.y):
		for x: int in range(_regiao.position.x, _regiao.end.x):
			if not e_parede(Vector2i(x, y)):
				chao.append(Vector2i(x, y))
	var embaralhado: Array = chao.duplicate()
	_embaralhar(embaralhado, sorteio)

	var usadas: Array[Vector2i] = []
	# 1) enfeites maiores, so em becos sem saida
	var nos_becos: Array = dados.get("nos_becos", [])
	var becos: Array[Vector2i] = []
	for item: Variant in embaralhado:
		var celula: Vector2i = item
		if becos.size() >= int(dados.get("quantos_nos_becos", 0)) or nos_becos.is_empty():
			break
		if e_beco(celula) and not _perto_de_ocupada(celula) and _longe_de(celula, becos, _ESPACO_ENTRE_BECOS):
			becos.append(celula)
			_por(String(nos_becos[(becos.size() - 1) % nos_becos.size()]), celula, tamanho, 15.0)
	usadas.append_array(becos)

	# 2) miudezas no meio de celulas de chao
	var no_chao: Array = dados.get("no_chao", [])
	var postas: int = 0
	for item: Variant in embaralhado:
		var celula: Vector2i = item
		if postas >= int(dados.get("quantos_no_chao", 0)) or no_chao.is_empty():
			break
		if usadas.has(celula) or _perto_de_ocupada(celula) \
				or not _longe_de(celula, usadas, _ESPACO_ENTRE_ENFEITES):
			continue
		usadas.append(celula)
		_por(String(no_chao[postas % no_chao.size()]), celula, tamanho, 13.0)
		postas += 1

	# 3) no lago: vitorias-regias e sapinhos dentro da agua (fora da borda externa)
	var na_agua: Array = dados.get("na_agua", [])
	if not na_agua.is_empty():
		var aguas: Array = _paredes.keys()
		aguas.sort()
		_embaralhar(aguas, sorteio)
		var n: int = 0
		for item: Variant in aguas:
			var celula: Vector2i = item
			if n >= int(dados.get("quantos_na_agua", 0)):
				break
			if celula.x <= _regiao.position.x or celula.y <= _regiao.position.y \
					or celula.x >= _regiao.end.x - 1 or celula.y >= _regiao.end.y - 1:
				continue
			_por(String(na_agua[n % na_agua.size()]), celula, tamanho, 12.0)
			n += 1

	# 4) pontinhos de um pixel: folhas, petalas, neve, vaga-lumes
	var cores: Array = dados.get("pontinhos", [])
	if not cores.is_empty() and not chao.is_empty():
		for k: int in int(dados.get("quantos_pontinhos", 0)):
			var celula: Vector2i = chao[sorteio.randi_range(0, chao.size() - 1)]
			var posicao := Vector2(celula) * tamanho + Vector2(sorteio.randi_range(2, 13), sorteio.randi_range(2, 13))
			_pontinhos.append({"pos": posicao, "cor": Color(String(cores[k % cores.size()]))})

	# De cima para baixo: o que esta mais embaixo na tela cobre o de cima.
	_enfeites.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["base"] as Vector2).y < (b["base"] as Vector2).y)


## Enfeite centrado na celula, com o pe `pe` pixels abaixo do topo dela. Um
## desenho mais alto desce o pe ate caber inteiro na celula (o boneco de neve
## tem a altura da celula): nada passa para a cerca de cima.
func _por(nome: String, celula: Vector2i, tamanho: Vector2, pe: float) -> void:
	var textura: Texture2D = CenarioDoLabirinto.textura_do_enfeite(_cenario, nome)
	if textura == null:
		return
	var pe_que_cabe: float = clampf(maxf(pe, float(textura.get_height())), 0.0, tamanho.y)
	_enfeites.append({"tex": textura, "nome": nome, "celula": celula,
		"base": Vector2(celula) * tamanho + Vector2(tamanho.x * 0.5, pe_que_cabe)})


## Retangulo que o enfeite ocupa, no espaco do labirinto.
static func area_do_enfeite(enfeite: Dictionary) -> Rect2:
	var textura: Texture2D = enfeite["tex"]
	var tamanho := Vector2(textura.get_size())
	var base: Vector2 = enfeite["base"]
	return Rect2((base - Vector2(tamanho.x * 0.5, tamanho.y)).round(), tamanho)


func _draw() -> void:
	if _labirinto == null or _labirinto.tile_set == null:
		return
	var tamanho: Vector2 = Vector2(_labirinto.tile_set.tile_size)
	draw_texture_rect(_chao, Rect2(Vector2(_regiao.position) * tamanho, Vector2(_regiao.size) * tamanho), true)
	if CenarioDoLabirinto.muro_de_agua(_cenario):
		_desenhar_agua(tamanho)
	else:
		var cercas: Array = _paredes.keys()
		cercas.append_array(_fora)
		for celula: Vector2i in cercas:
			var canto: Vector2 = Vector2(celula) * tamanho
			for coluna: int in _QUARTOS.size():
				var quarto: Vector2i = _QUARTOS[coluna]
				var linha: int = _tipo_no_desenho(celula, quarto)
				var destino := Rect2(canto + Vector2(0.0 if quarto.x < 0 else PECA, 0.0 if quarto.y < 0 else PECA),
					Vector2(PECA, PECA))
				draw_texture_rect_region(_muro, destino, Rect2(coluna * PECA, linha * PECA, PECA, PECA))
	var brilham: bool = bool(CenarioDoLabirinto.dados(_cenario).get("pontinhos_brilham", false))
	for pontinho: Dictionary in _pontinhos:
		var cor: Color = pontinho["cor"]
		var posicao: Vector2 = pontinho["pos"]
		draw_rect(Rect2(posicao, Vector2.ONE), cor)
		if brilham:
			var halo := Color(cor.r, cor.g, cor.b, 0.35)
			for direcao: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				draw_rect(Rect2(posicao + direcao, Vector2.ONE), halo)
	for enfeite: Dictionary in _enfeites:
		draw_texture(enfeite["tex"], area_do_enfeite(enfeite).position)


## Lago: o ladrilho de agua corrido por baixo das celulas de parede, com espuma
## na beira e a borda escura das tabuas do lado do deck.
func _desenhar_agua(tamanho: Vector2) -> void:
	var lado: Vector2 = Vector2(_muro.get_size())
	var aguas: Array = _paredes.keys()
	aguas.append_array(_fora)
	for celula: Vector2i in aguas:
		var canto: Vector2 = Vector2(celula) * tamanho
		var origem := Rect2(Vector2(fposmod(canto.x, lado.x), fposmod(canto.y, lado.y)), tamanho)
		draw_texture_rect_region(_muro, Rect2(canto, tamanho), origem)
	for celula: Vector2i in _paredes:
		if not _regiao.has_point(celula):
			continue
		var canto: Vector2 = Vector2(celula) * tamanho
		if _deck_ao_lado(celula, Vector2i.UP):
			draw_rect(Rect2(canto, Vector2(tamanho.x, 1)), _ESPUMA)
			draw_rect(Rect2(canto + Vector2(0, 1), Vector2(tamanho.x, 1)), _AGUA_FUNDA)
			draw_rect(Rect2(canto + Vector2(0, -1), Vector2(tamanho.x, 1)), _BORDA_DAS_TABUAS)
		if _deck_ao_lado(celula, Vector2i.DOWN):
			draw_rect(Rect2(canto + Vector2(0, tamanho.y - 1), Vector2(tamanho.x, 1)), _ESPUMA)
			draw_rect(Rect2(canto + Vector2(0, tamanho.y), Vector2(tamanho.x, 2)), _BORDA_DAS_TABUAS)
		if _deck_ao_lado(celula, Vector2i.LEFT):
			draw_rect(Rect2(canto, Vector2(1, tamanho.y)), _ESPUMA)
			draw_rect(Rect2(canto + Vector2(-1, 0), Vector2(1, tamanho.y)), _BORDA_DAS_TABUAS)
		if _deck_ao_lado(celula, Vector2i.RIGHT):
			draw_rect(Rect2(canto + Vector2(tamanho.x - 1, 0), Vector2(1, tamanho.y)), _ESPUMA)
			draw_rect(Rect2(canto + Vector2(tamanho.x, 0), Vector2(1, tamanho.y)), _BORDA_DAS_TABUAS)


func _deck_ao_lado(celula: Vector2i, direcao: Vector2i) -> bool:
	var vizinha: Vector2i = celula + direcao
	return not e_parede(vizinha) and _regiao.has_point(vizinha)
