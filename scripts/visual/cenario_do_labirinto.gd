class_name CenarioDoLabirinto
extends RefCounted

## Os cenarios do labirinto (ADR 0035): a mesma fase com outra roupa.
##
## Cenario e so aparencia. O que e parede continua vindo do TileMapLayer (camada
## de dados "solido"), entao colisao, A* e telemetria nao mudam com ele, e as
## medidas de desempenho de duas turmas em cenarios diferentes continuam
## comparaveis. A fase guarda o nome do cenario no JSON ("cenario"); fase sem o
## campo e o jardim verde de sempre.
##
## A arte sai de tools/arte/montar_cenarios.py, em recursos/arte/cenarios/<nome>/.
## Os enfeites (folhinhas, cogumelos, flores, bonecos de neve, vitorias-regias)
## sao poucos e pequenos, sempre dentro de uma celula: nunca em cima da cerca e
## nunca nas celulas da entrada, da saida, dos pacotes e dos cachorros
## (ArbustosDoLabirinto escolhe onde).

const PADRAO: String = "jardim"

## Ordem do seletor do editor.
const ORDEM: Array[String] = ["jardim", "outono", "cerejeira", "lago", "inverno", "ruinas", "bosque", "lavanda"]

const NOMES: Dictionary = {
	"jardim": "jardim (verde)",
	"outono": "outono",
	"cerejeira": "cerejeira",
	"lago": "lago com passarelas",
	"inverno": "inverno",
	"ruinas": "ruínas de pedra",
	"bosque": "bosque encantado",
	"lavanda": "campo de lavanda",
}

## Por cenario:
##   no_chao / quantos_no_chao: miudezas no meio de celulas de chao;
##   nos_becos / quantos_nos_becos: enfeites maiores, so em becos sem saida
##     (chao com cerca em tres lados), por onde ninguem precisa passar;
##   na_agua / quantos_na_agua: so no lago, dentro das celulas de agua;
##   pontinhos: folhas, petalas, neve ou vaga-lumes de um pixel no chao.
const DADOS: Dictionary = {
	"jardim": {},
	"outono": {
		"no_chao": ["folhas_secas", "cogumelos", "cogumelos_vermelhos"], "quantos_no_chao": 6,
		"pontinhos": ["#e8743a", "#c9482b", "#f2c14e", "#a8432a"], "quantos_pontinhos": 140,
	},
	"cerejeira": {
		"no_chao": ["moita_flor_rosa", "flor_branca"], "quantos_no_chao": 5,
		"pontinhos": ["#e68ab3", "#d4709d", "#ffffff"], "quantos_pontinhos": 120,
	},
	"lago": {
		"muro_de_agua": true,
		"na_agua": ["vitoria_regia", "vitoria_regia_flor", "sapo_na_folha", "vitoria_regia"], "quantos_na_agua": 16,
	},
	"inverno": {
		"nos_becos": ["boneco_de_neve"], "quantos_nos_becos": 2,
		"pontinhos": ["#ffffff", "#cfe8f7"], "quantos_pontinhos": 120,
	},
	"ruinas": {
		"no_chao": ["rocha", "cogumelos", "toco", "seixos"], "quantos_no_chao": 6,
	},
	"bosque": {
		"no_chao": ["flores_azuis", "cogumelos"], "quantos_no_chao": 5,
		"pontinhos": ["#fff27a", "#c8ff8a"], "quantos_pontinhos": 50, "pontinhos_brilham": true,
	},
	"lavanda": {
		"no_chao": ["lavanda", "flor_branca"], "quantos_no_chao": 6,
		"pontinhos": ["#ffffff", "#d8c4f2"], "quantos_pontinhos": 100,
	},
}

const _PASTA: String = "res://recursos/arte/cenarios"
const _GRAMA_DO_JARDIM: String = "res://recursos/arte/grama.png"
const _CERCA_DO_JARDIM: String = "res://recursos/arte/arbusto_pecas.png"


static func conhece(cenario: String) -> bool:
	return DADOS.has(cenario)


static func resolver(cenario: String) -> String:
	return cenario if conhece(cenario) else PADRAO


static func nome(cenario: String) -> String:
	return String(NOMES.get(resolver(cenario), NOMES[PADRAO]))


static func dados(cenario: String) -> Dictionary:
	return DADOS[resolver(cenario)] as Dictionary


## No lago a "cerca" e agua e o chao sao tabuas: a regra e a mesma, so o desenho muda.
static func muro_de_agua(cenario: String) -> bool:
	return bool(dados(cenario).get("muro_de_agua", false))


static func textura_do_chao(cenario: String) -> Texture2D:
	var escolhido: String = resolver(cenario)
	if escolhido == PADRAO:
		return load(_GRAMA_DO_JARDIM) as Texture2D
	return load("%s/%s/chao.png" % [_PASTA, escolhido]) as Texture2D


## Folha de pecas da cerca (mesmo arranjo de arbusto_pecas.png) ou, no lago, o
## ladrilho de agua.
static func textura_do_muro(cenario: String) -> Texture2D:
	var escolhido: String = resolver(cenario)
	if escolhido == PADRAO:
		return load(_CERCA_DO_JARDIM) as Texture2D
	var arquivo: String = "agua" if muro_de_agua(escolhido) else "muro"
	return load("%s/%s/%s.png" % [_PASTA, escolhido, arquivo]) as Texture2D


## Miniatura do labirinto neste cenario, para a escolha antes da fase (ADR 0036).
## Gerada por tools/gerar_previas_de_cenarios.gd, recortada do proprio jogo.
static func textura_da_previa(cenario: String) -> Texture2D:
	return load("%s/%s/previa.png" % [_PASTA, resolver(cenario)]) as Texture2D


static func textura_do_enfeite(cenario: String, enfeite: String) -> Texture2D:
	return load("%s/%s/%s.png" % [_PASTA, resolver(cenario), enfeite]) as Texture2D
