class_name GaleriaDeFundos
extends RefCounted

## Fundos do menu e a cor dos botoes que combina com cada um (ADR 0033).
##
## O botao de galeria, no canto do menu, passa para o proximo fundo da lista a
## cada toque; a escolha fica nas Preferencias e vale tambem para as telas
## secundarias (selecao, editor e telemetria), que usam o mesmo fundo. A arte
## sai de tools/arte/montar_arte_do_menu.py.

const PADRAO: String = "brejo"

## Ordem em que o botao percorre os fundos.
const ORDEM: Array[String] = ["brejo", "noite", "estufa", "carpas", "piquenique", "ceu"]

const NOMES: Dictionary = {
	"brejo": "brejo",
	"noite": "noite estrelada",
	"estufa": "estufa",
	"carpas": "lago das carpas",
	"piquenique": "piquenique",
	"ceu": "céu e montanhas",
}

## Paleta de cada fundo (ADR 0034). O "tom" e a cor do miolo do balao dos
## botoes (o mesmo de tools/arte/montar_arte_do_menu.py). A "tinta" e a cor
## que o vidro fosco mistura ao fundo desfocado: um tom escuro da mesma
## familia, para o texto branco ler bem. O alfa da tinta sobe nos fundos
## claros (ceu, piquenique) e desce no lago das carpas, que ja e escuro; ali a
## tinta e o verde-azulado da agua, e o laranja fica so nos baloes, como as
## carpas.
const TONS: Dictionary = {
	"brejo": Color("8ab523"),
	"noite": Color("4074a5"),
	"estufa": Color("61a78c"),
	"carpas": Color("e38b3b"),
	"piquenique": Color("aa7640"),
	"ceu": Color("71a1bb"),
}

const TINTAS: Dictionary = {
	"brejo": Color(0.15, 0.27, 0.12, 0.55),
	"noite": Color(0.09, 0.19, 0.31, 0.52),
	"estufa": Color(0.10, 0.27, 0.23, 0.62),
	"carpas": Color(0.04, 0.17, 0.17, 0.45),
	"piquenique": Color(0.29, 0.18, 0.09, 0.66),
	"ceu": Color(0.13, 0.26, 0.35, 0.68),
}

## Cores da moldura de vinhas de cada fundo (ADR 0044): vinha, folha escura e
## folha clara, nessa ordem. O brejo fica com o verde do logo; nos outros a
## vinha acompanha o wallpaper, como na apresentacao do piquenique, em que as
## folhas viraram marrons para combinar com a toalha. A vinha e sempre o tom
## mais escuro (o contorno que desenha a moldura) e as folhas clareiam a partir
## dele. As flores (vermelha e azul, do logo) nao mudam.
const VINHAS: Dictionary = {
	"brejo": [Color8(79, 137, 65), Color8(115, 164, 41), Color8(139, 181, 24)],
	"noite": [Color8(52, 84, 130), Color8(86, 126, 178), Color8(140, 180, 226)],
	"estufa": [Color8(38, 110, 88), Color8(72, 150, 118), Color8(128, 196, 160)],
	"carpas": [Color8(176, 88, 36), Color8(227, 139, 59), Color8(246, 184, 110)],
	"piquenique": [Color8(122, 82, 50), Color8(156, 116, 77), Color8(190, 146, 96)],
	"ceu": [Color8(70, 120, 150), Color8(113, 161, 187), Color8(170, 208, 228)],
}

const _SECAO: String = "menu"
const _CHAVE: String = "fundo"


static func conhece(fundo: String) -> bool:
	return ORDEM.has(fundo)


static func nome(fundo: String) -> String:
	return String(NOMES.get(fundo, NOMES[PADRAO]))


static func textura_do_fundo(fundo: String) -> Texture2D:
	var valido: String = fundo if conhece(fundo) else PADRAO
	return load("res://recursos/arte/fundos/%s.png" % valido) as Texture2D


## A moldura dos botoes no tom do fundo. O brejo usa o verde original.
static func textura_do_balao(fundo: String) -> Texture2D:
	if not conhece(fundo) or fundo == PADRAO:
		return load("res://recursos/arte/balao_botao.png") as Texture2D
	return load("res://recursos/arte/balao_botao_%s.png" % fundo) as Texture2D


## Cor do balao deste fundo: as listas, abas e barras usam a mesma, para tudo
## combinar com os botoes.
static func tom(fundo: String) -> Color:
	return TONS.get(fundo, TONS[PADRAO]) as Color


## Cor (com alfa) que o vidro fosco mistura ao fundo desfocado.
static func tinta(fundo: String) -> Color:
	return TINTAS.get(fundo, TINTAS[PADRAO]) as Color


## Vinha, folha escura e folha clara da moldura deste fundo.
static func cores_das_vinhas(fundo: String) -> PackedColorArray:
	return PackedColorArray(VINHAS.get(fundo, VINHAS[PADRAO]) as Array)


static func seguinte(fundo: String) -> String:
	var indice: int = ORDEM.find(fundo)
	return ORDEM[(indice + 1) % ORDEM.size()]


static func atual() -> String:
	var lido: String = String(Preferencias.ler(_SECAO, _CHAVE, PADRAO))
	return lido if conhece(lido) else PADRAO


static func salvar(fundo: String) -> void:
	if conhece(fundo):
		Preferencias.gravar(_SECAO, _CHAVE, fundo)
