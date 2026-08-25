class_name PacoteConfig
extends Resource

## Um pacote de dados espalhado pelo labirinto -- dado puro.
##
## Encostar no pacote nao coleta: abre uma pergunta curta sobre qual ferramenta
## criptografica serve para aquele caso (cenas/base/caixa_puzzle.tscn). E a
## unica parte do jogo em que o conhecimento e cobrado FORA do terminal, e de
## proposito: o terminal mede se o jogador sabe operar a cifra, o pacote mede se
## ele sabe ESCOLHER a cifra -- que e a competencia que a monografia mede no
## pre/pos-teste.
##
## No modo de treino (ConfigJogo.modo_treino) a caixa nao abre e o pacote e
## coletado ao encostar: ler enunciado e clicar botao e tarefa de humano.

@export var identificador: String = "pacote"

## Celula do labirinto (coordenada de TileMapLayer), como em CachorroConfig.
@export var celula: Vector2i = Vector2i(1, 1)

@export_multiline var enunciado: String = ""

## Opcoes oferecidas, em codigos de algoritmo (os mesmos de LegendaCores) --
## assim cada botao sai na cor do cachorro correspondente, e a caixa de puzzle
## reforca a mesma associacao cor/cifra do resto do jogo em vez de inventar um
## vocabulario proprio.
@export var opcoes: PackedStringArray = ["CESAR", "VIGENERE", "SHA256"]

@export var resposta_correta: String = "CESAR"

## Frase curta mostrada ao acertar. E onde a licao fica explicita -- errar e
## acertar sem entender o porque nao ensina nada.
@export_multiline var explicacao_correta: String = ""

@export_range(0, 1000, 5) var pontos_acerto: int = 60
@export_range(0, 1000, 5) var penalidade_erro: int = 20


func problemas() -> PackedStringArray:
	var lista := PackedStringArray()
	if identificador.strip_edges().is_empty():
		lista.append("pacote sem identificador")
	if identificador.length() > 60:
		lista.append("identificador de pacote '%s' excede 60 caracteres (tentativa_comando.desafio)"
			% identificador)
	if enunciado.strip_edges().is_empty():
		lista.append("pacote '%s' sem enunciado" % identificador)
	if opcoes.size() < 2:
		lista.append("pacote '%s' precisa de ao menos duas opcoes" % identificador)
	if not opcoes.has(resposta_correta):
		lista.append("pacote '%s': a resposta correta '%s' nao esta entre as opcoes"
			% [identificador, resposta_correta])
	for opcao: String in opcoes:
		if not LegendaCores.conhece(opcao):
			lista.append("pacote '%s' oferece a opcao desconhecida '%s'" % [identificador, opcao])
	return lista
