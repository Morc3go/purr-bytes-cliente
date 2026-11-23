class_name MolduraDeVinhas
extends Control

## Moldura de vinhas e flores em volta de um cartao de vidro (ADR 0031 e 0034).
##
## A primeira versao era um PNG gerado em Python para o tamanho exato do cartao
## do menu. Com todas as telas ganhando a moldura (selecao, editor, telemetria,
## escolha do gato, paineis do jogo), cada uma com um cartao de tamanho
## diferente, e alguns que mudam de altura com o texto, a moldura passou a ser
## desenhada aqui, para qualquer tamanho, com o mesmo desenho: uma vinha de um
## pixel que sobe e desce, gavinhas, brotos de folha e as duas flores do logo
## (a vermelha e a azul), com um cacho em cada canto.
##
## O desenho e feito em pixels de arte numa Image e mostrado em 2x, como o
## logo e os wallpapers. O sorteio das folhas tem semente fixa: o mesmo tamanho
## da sempre a mesma moldura, e cada tamanho e desenhado uma vez so (cache).
##
## Uso: irma do cartao, logo depois dele na arvore (para ficar por cima da
## borda do vidro), com `cartao` apontando para ele. EnfeiteDaGaleria faz isso.
##
## A cor da vinha e das folhas acompanha o wallpaper escolhido na galeria
## (ADR 0044): verde no brejo, marrom no piquenique, azul na noite e no ceu,
## verde-agua na estufa e laranja no lago das carpas. As cores ficam em
## GaleriaDeFundos.VINHAS; as flores sao sempre as do logo.

## Pixels da tela base (640x360) por pixel de arte.
const ESCALA: int = 2
## Quanto a moldura passa para fora do cartao, de cada lado, em pixels de arte.
const SOBRA: int = 6
## Raio dos cantos, em pixels de arte: o mesmo do vidro (TemaDaGaleria.RAIO_DO_VIDRO).
const RAIO: int = 7
const SEMENTE: int = 31

## Cores das flores, tiradas do logo da equipe (iguais em todos os fundos).
const CORES_DAS_FLORES: Dictionary = {
	"r": Color8(212, 70, 83),
	"p": Color8(229, 113, 124),
	"y": Color8(246, 200, 48),
	"b": Color8(113, 193, 235),
	"B": Color8(162, 219, 249),
	"o": Color8(251, 203, 119),
}
## As duas flores do logo, como aparecem nele (centro em (1, 1)).
const FLOR_VERMELHA: PackedStringArray = [".p.", "ryr", ".r."]
const FLOR_VERMELHA_DEITADA: PackedStringArray = [".r.", "pyr", ".r."]
const FLOR_AZUL: PackedStringArray = [".bB", "BoB", "Bb."]

@export var cartao: Control
## Fundo da galeria cujas cores a vinha usa. Vazio: o fundo atual da galeria.
@export var fundo: String = ""

static var _cache: Dictionary = {}

var _textura: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if cartao == null:
		return
	cartao.item_rect_changed.connect(_ajustar)
	cartao.visibility_changed.connect(_ajustar)
	_ajustar.call_deferred()


func _ajustar() -> void:
	if cartao == null or not is_instance_valid(cartao):
		return
	visible = cartao.visible
	var arte: Vector2i = tamanho_em_arte(cartao.size)
	if arte.x <= 2 * RAIO or arte.y <= 2 * RAIO:
		_textura = null
		queue_redraw()
		return
	_textura = textura(arte, fundo_em_uso())
	var sobra: Vector2 = Vector2.ONE * SOBRA * ESCALA
	size = Vector2(_textura.get_size()) * ESCALA
	global_position = cartao.global_position - sobra
	queue_redraw()


func _draw() -> void:
	if _textura != null:
		draw_texture_rect(_textura, Rect2(Vector2.ZERO, Vector2(_textura.get_size()) * ESCALA), false)


func textura_atual() -> Texture2D:
	return _textura


## Troca as cores da vinha (o menu chama ao passar para o proximo fundo).
func definir_fundo(novo: String) -> void:
	fundo = novo
	_ajustar()


func fundo_em_uso() -> String:
	return fundo if GaleriaDeFundos.conhece(fundo) else GaleriaDeFundos.atual()


## Tamanho do cartao em pixels de arte (o cartao e medido em pixels da tela base).
static func tamanho_em_arte(tamanho: Vector2) -> Vector2i:
	return Vector2i(roundi(tamanho.x / ESCALA), roundi(tamanho.y / ESCALA))


## A moldura de um cartao de `arte` pixels de arte, ja com a sobra dos lados,
## nas cores do fundo pedido. Uma textura por tamanho e por fundo.
static func textura(arte: Vector2i, fundo_da_galeria: String = GaleriaDeFundos.PADRAO) -> Texture2D:
	var chave: String = "%d,%d,%s" % [arte.x, arte.y, fundo_da_galeria]
	if not _cache.has(chave):
		_cache[chave] = ImageTexture.create_from_image(desenhar(arte, fundo_da_galeria))
	return _cache[chave] as Texture2D


static func desenhar(arte: Vector2i, fundo_da_galeria: String = GaleriaDeFundos.PADRAO) -> Image:
	return _Desenho.new(arte, GaleriaDeFundos.cores_das_vinhas(fundo_da_galeria)).imagem


## O desenho em si (port de tools/arte/montar_logo_e_vinhas.py, versao 1).
class _Desenho:
	var imagem: Image
	var largura: int
	var altura: int
	var total: float
	var voltas: int
	var sorteio := RandomNumberGenerator.new()
	var vinha: Color
	var folha_escura: Color
	var folha_clara: Color

	func _init(arte: Vector2i, cores: PackedColorArray) -> void:
		vinha = cores[0]
		folha_escura = cores[1]
		folha_clara = cores[2]
		largura = arte.x
		altura = arte.y
		sorteio.seed = SEMENTE
		imagem = Image.create_empty(largura + 2 * SOBRA, altura + 2 * SOBRA, false, Image.FORMAT_RGBA8)
		total = 2.0 * (largura - 2 * RAIO) + 2.0 * (altura - 2 * RAIO) + 2.0 * PI * RAIO
		# Onda da vinha com periodo que fecha a volta inteira: sem emenda.
		voltas = maxi(1, roundi(total / 14.0))
		_vinha()
		_gavinhas()
		_folhas()
		_flores()

	func _pintar(x: float, y: float, cor: Color) -> void:
		var px: int = roundi(x) + SOBRA
		var py: int = roundi(y) + SOBRA
		if px >= 0 and px < imagem.get_width() and py >= 0 and py < imagem.get_height():
			imagem.set_pixel(px, py, cor)

	## Ponto e normal (para fora) no contorno do cartao, pelo comprimento de arco s.
	func _perimetro(s: float) -> Array[Vector2]:
		var retas := Vector2(largura - 2 * RAIO, altura - 2 * RAIO)
		var arco: float = PI * RAIO / 2.0
		var trechos: Array[float] = [retas.x, arco, retas.y, arco, retas.x, arco, retas.y, arco]
		s = fposmod(s, total)
		var cantos: Array[Vector2] = [Vector2(largura - RAIO, RAIO), Vector2(largura - RAIO, altura - RAIO),
			Vector2(RAIO, altura - RAIO), Vector2(RAIO, RAIO)]
		var indice: int = 0
		for i: int in trechos.size():
			indice = i
			if s <= trechos[i]:
				break
			s -= trechos[i]
		var lado: int = indice / 2
		if indice % 2 == 0:
			match lado:
				0: return [Vector2(RAIO + s, 0.0), Vector2(0, -1)]
				1: return [Vector2(largura, RAIO + s), Vector2(1, 0)]
				2: return [Vector2(largura - RAIO - s, altura), Vector2(0, 1)]
				_: return [Vector2(0.0, altura - RAIO - s), Vector2(-1, 0)]
		var angulo: float = -PI / 2.0 + lado * PI / 2.0 + s / RAIO
		var normal := Vector2(cos(angulo), sin(angulo))
		return [cantos[lado] + normal * RAIO, normal]

	func _onda(s: float) -> float:
		return 1.2 * sin(TAU * voltas * s / total) + 0.4 * sin(TAU * 3 * voltas * s / total + 1.0)

	func _ponto(s: float, afastamento: float = 0.0) -> Vector2:
		var pn: Array[Vector2] = _perimetro(s)
		return pn[0] + pn[1] * (_onda(s) + afastamento)

	# 1) a vinha: uma linha fina de um pixel, que sobe e desce como as do logo
	func _vinha() -> void:
		var s: float = 0.0
		while s < total:
			var p: Vector2 = _ponto(s)
			_pintar(p.x, p.y, vinha)
			s += 0.2

	# 2) gavinhas: raminhos curtos que saem da vinha em diagonal, terminando
	#    numa folha clara
	func _gavinhas() -> void:
		var s: float = 6.0
		var lado: int = 1
		while s < total - 4.0:
			for passo: int in range(1, 4):
				var p: Vector2 = _ponto(s + passo * 0.9, (1.0 + passo) * lado)
				_pintar(p.x, p.y, vinha if passo < 3 else folha_clara)
			lado = -lado
			s += sorteio.randf_range(11.0, 17.0)

	# 3) folhas: brotos de um ou dois pixels, alternando para dentro e para fora
	func _folhas() -> void:
		var s: float = 1.0
		var lado: int = 1
		while s < total:
			var cor: Color = folha_clara if sorteio.randf() < 0.55 else folha_escura
			var p: Vector2 = _ponto(s + 0.6, 1.4 * lado)
			_pintar(p.x, p.y, cor)
			if sorteio.randf() < 0.6:
				p = _ponto(s + 1.5, 2.3 * lado)
				_pintar(p.x, p.y, cor)
			lado = -lado
			s += sorteio.randf_range(2.2, 3.6)

	func _carimbo(s: float, desenho: PackedStringArray, afastamento: float) -> void:
		var centro: Vector2 = _ponto(s, afastamento)
		var cx: int = roundi(centro.x)
		var cy: int = roundi(centro.y)
		for dy: int in desenho.size():
			for dx: int in desenho[dy].length():
				var letra: String = desenho[dy][dx]
				if letra != ".":
					_pintar(cx + dx - 1, cy + dy - 1, CORES_DAS_FLORES[letra] as Color)

	# 4) flores: um cacho em cada canto e outras espalhadas pelas laterais
	func _flores() -> void:
		var retas := Vector2(largura - 2 * RAIO, altura - 2 * RAIO)
		var arco: float = PI * RAIO / 2.0
		var inicio_dos_cantos: Array[float] = [retas.x, retas.x + arco + retas.y,
			2 * retas.x + 2 * arco + retas.y, 2 * retas.x + 3 * arco + 2 * retas.y]
		var flores: Array[PackedStringArray] = [FLOR_VERMELHA, FLOR_AZUL, FLOR_VERMELHA_DEITADA, FLOR_AZUL]
		for numero: int in inicio_dos_cantos.size():
			var meio: float = inicio_dos_cantos[numero] + arco / 2.0
			_carimbo(meio, FLOR_VERMELHA if numero % 2 == 0 else FLOR_VERMELHA_DEITADA, 1.0)
			_carimbo(meio - 6.0, FLOR_AZUL, -1.0)
			_carimbo(meio + 6.0, FLOR_VERMELHA_DEITADA if numero % 2 == 0 else FLOR_AZUL, 2.0)
		# Pelas laterais, uma flor a cada ~22 pixels, fora dos cantos, alternando
		# cores e o lado da vinha (dentro/fora), como no logo.
		var vez: int = 0
		var inicios: Array[float] = [0.0, inicio_dos_cantos[0] + arco, inicio_dos_cantos[1] + arco,
			inicio_dos_cantos[2] + arco]
		for numero: int in inicios.size():
			var comprimento: float = retas.x if numero % 2 == 0 else retas.y
			var quantas: int = maxi(1, roundi(comprimento / 22.0) - 1)
			for k: int in range(1, quantas + 1):
				var pos: float = inicios[numero] + comprimento * k / (quantas + 1) + sorteio.randf_range(-2.0, 2.0)
				_carimbo(pos, flores[vez % flores.size()], 1.5 if vez % 2 == 0 else -1.0)
				vez += 1
