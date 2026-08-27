class_name LegendaCores
extends RefCounted

## Cor de cada algoritmo -- FONTE UNICA para o jogo inteiro.
##
## A regra que o jogador tem que aprender e "a cor do cachorro diz qual cifra
## protege contra ele". Isso so funciona se a cor pintada no cachorro
## (cenas/base/fase_base.gd) e a cor mostrada no tutorial do menu
## (cenas/ui/menu_principal.gd) forem literalmente o mesmo dado: duas tabelas
## paralelas divergiriam no primeiro ajuste de paleta, e o jogo estaria
## ensinando errado sem nenhum teste quebrar.
##
## Os codigos de algoritmo sao os mesmos de FaseConfig.algoritmo (que espelha o
## enum do banco) -- nao ha um vocabulario de cores separado para manter.

const ALGORITMOS: PackedStringArray = ["CESAR", "VIGENERE", "SHA256", "AES"]

const _COR_PADRAO: Color = Color(0.85, 0.85, 0.85)

## Cores escolhidas para se distinguirem tambem em monitor ruim de laboratorio
## escolar: matizes bem separados e luminosidade parecida, para nenhuma delas
## sumir no fundo escuro do labirinto.
const _CORES: Dictionary = {
	"CESAR": Color(0.42, 0.85, 0.45),      # verde
	"VIGENERE": Color(0.40, 0.66, 1.0),    # azul
	"SHA256": Color(0.74, 0.50, 0.96),     # roxo
	"AES": Color(1.0, 0.66, 0.30),         # laranja (fase 4, fora de escopo)
}

const _NOMES: Dictionary = {
	"CESAR": "Cesar",
	"VIGENERE": "Vigenere",
	"SHA256": "SHA-256",
	"AES": "AES",
}

const _NOMES_DAS_CORES: Dictionary = {
	"CESAR": "verde",
	"VIGENERE": "azul",
	"SHA256": "roxo",
	"AES": "laranja",
}

## O que cada ferramenta FAZ -- so o mecanismo, no vocabulario do jogador.
##
## A palavra "chave" nao aparece aqui de proposito. O jogo pede duas decisoes
## diferentes e o texto antigo misturava as duas: a COR do cachorro escolhe a
## FERRAMENTA (isto e o que esta neste dicionario), e a CHAVE e o segredo que
## faz a ferramenta escolhida funcionar (isso esta em _CHAVES, separado). Quem
## le "a chave e esse numero" logo abaixo de uma tabela de cores acaba achando
## que a cor e a chave -- foi o que aconteceu.
const _EXPLICACOES: Dictionary = {
	"CESAR": "embaralha o texto deslocando cada letra um numero fixo de casas no alfabeto. "
		+ "da para desfazer e ler de novo.",
	"VIGENERE": "embaralha o texto trocando o deslocamento a cada letra, seguindo uma palavra "
		+ "secreta repetida. tambem da para desfazer.",
	"SHA256": "nao embaralha nem esconde: gera um resumo curto do conteudo, que muda inteiro "
		+ "se alguem mexer numa letra. serve para conferir, nunca para recuperar o texto.",
	"AES": "embaralha o texto em blocos; e a cifra usada de verdade hoje em dia.",
}

## O SEGREDO que faz cada ferramenta funcionar -- a outra metade da confusao.
## Deliberadamente separado de _EXPLICACOES: sao dois campos no tutorial, com
## titulos diferentes, para o jogador nunca ler cor e chave na mesma frase.
const _CHAVES: Dictionary = {
	"CESAR": "um numero (quantas casas andar). ex.: cifrar pacote chave=3",
	"VIGENERE": "uma palavra. ex.: cifrar pacote chave=gato",
	"SHA256": "nenhuma -- o resumo nao esconde nada, entao nao ha o que destrancar. "
		+ "ex.: hash pacote / verificar pacote <resumo>",
	"AES": "uma chave secreta; entra na fase 4.",
}


static func cor(algoritmo: String) -> Color:
	return _CORES.get(algoritmo, _COR_PADRAO)


static func nome(algoritmo: String) -> String:
	return String(_NOMES.get(algoritmo, algoritmo))


static func nome_da_cor(algoritmo: String) -> String:
	return String(_NOMES_DAS_CORES.get(algoritmo, "sem cor"))


static func explicacao(algoritmo: String) -> String:
	return String(_EXPLICACOES.get(algoritmo, ""))


## O segredo que a ferramenta pede -- numero, palavra, ou nenhum.
static func chave(algoritmo: String) -> String:
	return String(_CHAVES.get(algoritmo, ""))


static func conhece(algoritmo: String) -> bool:
	return _CORES.has(algoritmo)


## Usada pelo tutorial do menu para montar a tabela sem repetir a lista.
## Ordem = ordem das fases, que e a ordem em que o jogador conhece cada cor.
static func entradas() -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	for algoritmo: String in ALGORITMOS:
		lista.append({
			"algoritmo": algoritmo,
			"nome": nome(algoritmo),
			"cor": cor(algoritmo),
			"nome_da_cor": nome_da_cor(algoritmo),
			"explicacao": explicacao(algoritmo),
			"chave": chave(algoritmo),
		})
	return lista
