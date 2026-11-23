class_name EnfeiteDaGaleria
extends RefCounted

## Deixa uma tela ou um painel do jogo com a cara do menu (ADR 0034): tema no
## tom do wallpaper escolhido, cartoes de vidro fosco e moldura de vinhas em
## volta de cada um.
##
## Cada tela chama `enfeitar` no proprio _ready, passando a raiz (que recebe o
## tema e o repassa a todos os filhos, dialogos inclusive) e os cartoes. Fazer
## isso em codigo, e nao a mao em cada .tscn, garante que toda tela nova fica
## igual as outras com uma linha so.

const MATERIAL_DO_VIDRO: ShaderMaterial = preload("res://recursos/shaders/vidro_fosco.tres")

## Grupo dos nos criados aqui, para os testes os acharem sem depender do nome.
const GRUPO_DAS_MOLDURAS: StringName = &"moldura_de_vinhas"


static func enfeitar(raiz: Control, cartoes: Array[Control], fundo: String = "") -> void:
	raiz.theme = TemaDaGaleria.tema(fundo)
	for cartao: Control in cartoes:
		vidro(cartao, fundo)


## Vidro fosco + moldura de vinhas num cartao. O cartao continua sendo o mesmo
## no: so ganha o material, perde o estilo fixo que tinha na cena (o painel
## passa a vir do tema, com a tinta do fundo) e ganha a moldura como irma, com
## a vinha nas cores do mesmo fundo (ADR 0044).
static func vidro(cartao: Control, fundo: String = "") -> MolduraDeVinhas:
	cartao.material = MATERIAL_DO_VIDRO
	cartao.remove_theme_stylebox_override(&"panel")
	var pai: Node = cartao.get_parent()

	# Copia da tela logo antes do cartao: sem ela, um segundo vidro na mesma
	# tela (a escolha do gato por cima da selecao, o diagnostico por cima do
	# dashboard) desfocaria a imagem de antes do primeiro, e nao o que esta
	# de fato atras dele.
	var copia := BackBufferCopy.new()
	copia.name = "%sCopiaDaTela" % cartao.name
	copia.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	pai.add_child(copia)
	pai.move_child(copia, cartao.get_index())

	var moldura := MolduraDeVinhas.new()
	moldura.name = "%sMoldura" % cartao.name
	moldura.cartao = cartao
	moldura.fundo = fundo
	moldura.add_to_group(GRUPO_DAS_MOLDURAS)
	pai.add_child(moldura)
	pai.move_child(moldura, cartao.get_index() + 1)
	return moldura


## Veu translucido por tras de um painel que abre por cima de outra coisa.
static func veu(fundo_do_painel: ColorRect, fundo: String = "") -> void:
	fundo_do_painel.color = TemaDaGaleria.cor_do_veu(fundo)


## Achar a moldura de um cartao (para os testes e para quem precisa esconde-la).
static func moldura_de(cartao: Control) -> MolduraDeVinhas:
	var pai: Node = cartao.get_parent()
	if pai == null:
		return null
	return pai.get_node_or_null(NodePath("%sMoldura" % cartao.name)) as MolduraDeVinhas
