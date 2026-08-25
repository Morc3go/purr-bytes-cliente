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

## Uma frase por algoritmo, no vocabulario do jogador e nao no do criptografo.
## E o texto que o tutorial do menu exibe antes da partida.
const _EXPLICACOES: Dictionary = {
	"CESAR": "cifra de deslocamento: cada letra anda um numero fixo de casas no alfabeto. "
		+ "a chave e esse numero. comando: cifrar <pacote> chave=<numero>",
	"VIGENERE": "cifra de substituicao com chave-palavra: o deslocamento muda a cada letra, "
		+ "seguindo a palavra-chave repetida. comando: cifrar <pacote> chave=<palavra>",
	"SHA256": "funcao de hash, de mao unica: nao esconde para depois recuperar, "
		+ "prova que o conteudo nao foi adulterado. comandos: hash <palavra>, verificar <palavra> <prefixo>",
	"AES": "cifra simetrica moderna, em blocos. entra na fase 4.",
}


static func cor(algoritmo: String) -> Color:
	return _CORES.get(algoritmo, _COR_PADRAO)


static func nome(algoritmo: String) -> String:
	return String(_NOMES.get(algoritmo, algoritmo))


static func nome_da_cor(algoritmo: String) -> String:
	return String(_NOMES_DAS_CORES.get(algoritmo, "sem cor"))


static func explicacao(algoritmo: String) -> String:
	return String(_EXPLICACOES.get(algoritmo, ""))


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
		})
	return lista
