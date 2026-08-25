class_name CachorroConfig
extends Resource

## Um cachorro farejador dentro de uma fase -- dado puro, como DesafioConfig.
##
## Cada cachorro exige UM algoritmo: so a cifra correspondente protege contra
## ele, e a cor que ele veste na tela e a de LegendaCores.cor(algoritmo_exigido).
## E dai que sai a licao nova da mecanica: "cifrei" nao basta, tem que ser a
## cifra certa para aquele interceptador.
##
## Acrescentar cachorro a uma fase e acrescentar um item nesta lista dentro do
## .tres -- nenhuma linha de codigo em cenas/fases/, que continuam sem script.

@export var identificador: String = "cachorro"

## Precisa ser um algoritmo conhecido por LegendaCores. Fora disso o cachorro
## ficaria cinza e invencivel -- FaseConfig.problemas() recusa a fase.
@export_enum("CESAR", "VIGENERE", "SHA256", "AES") var algoritmo_exigido: String = "CESAR"

## Celula do labirinto (coordenada de TileMapLayer, nao pixel) onde ele nasce.
## Em celula, e nao em pixel, porque e assim que o mapa e escrito e conferido.
@export var celula_inicial: Vector2i = Vector2i(1, 1)

## Rota de patrulha, em celulas, percorrida em ciclo enquanto ele nao tem
## linha de visao nem alvo do Diretor. Vazia = sem patrulha (comportamento
## historico do Marco 1: perseguir a posicao do jogador).
@export var ancoras: Array[Vector2i] = []

## 0 = herda FaseConfig.velocidade_cachorro / alcance_deteccao_cachorro. Existe
## para uma fase poder ter um cachorro lento de patrulha longa e outro rapido
## de area pequena sem duplicar os campos da fase inteira.
@export_range(0.0, 200.0, 1.0) var velocidade: float = 0.0
@export_range(0.0, 400.0, 1.0) var alcance_deteccao: float = 0.0


func problemas() -> PackedStringArray:
	var lista := PackedStringArray()
	if identificador.strip_edges().is_empty():
		lista.append("cachorro sem identificador")
	if not LegendaCores.conhece(algoritmo_exigido):
		lista.append("cachorro '%s' exige o algoritmo desconhecido '%s' (sem cor na legenda)"
			% [identificador, algoritmo_exigido])
	return lista
