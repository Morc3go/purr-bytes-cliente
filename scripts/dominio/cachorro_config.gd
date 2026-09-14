class_name CachorroConfig
extends Resource

## Um cachorro farejador dentro de uma fase -- dado puro, como DesafioConfig.
##
## Cada cachorro exige UM algoritmo: so a cifra correspondente protege contra
## ele. E dai que sai a licao da mecanica: "cifrei" nao basta, tem que ser a
## cifra certa para aquele interceptador.
##
## A COR e separada disso: e identidade visual do cachorro, escolhida em `cor`,
## e no futuro devera dar lugar a um sprite proprio. Ela nasce com a cor do
## algoritmo so como default conveniente -- quem pinta o cachorro e este
## recurso, nao a tabela de legenda.
##
## Acrescentar cachorro a uma fase e acrescentar um item nesta lista dentro do
## .tres -- nenhuma linha de codigo em cenas/fases/, que continuam sem script.

@export var identificador: String = "cachorro"

## Precisa ser um algoritmo conhecido. Fora disso o cachorro ficaria invencivel
## -- FaseConfig.problemas() recusa a fase.
@export_enum("CESAR", "VIGENERE", "SHA256", "AES") var algoritmo_exigido: String = "CESAR"

## Identidade visual do cachorro. Transparente (alpha 0) significa "use a cor
## do algoritmo como default", que e o caso das fases atuais; qualquer outro
## valor e respeitado como escolhido a mao.
##
## Existe como campo proprio, e nao derivado do algoritmo, porque cor e regra
## sao coisas diferentes: dois cachorros podem exigir a mesma cifra e ter
## aparencias distintas, e a aparencia vai virar sprite um dia sem que a regra
## mude uma linha.
@export var cor: Color = Color(0, 0, 0, 0)

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


## A cor que este cachorro veste: a escolhida, ou a do algoritmo quando nenhuma
## foi escolhida.
func cor_efetiva() -> Color:
	return cor if cor.a > 0.0 else LegendaCores.cor(algoritmo_exigido)


func problemas() -> PackedStringArray:
	var lista := PackedStringArray()
	if identificador.strip_edges().is_empty():
		lista.append("cachorro sem identificador")
	if not LegendaCores.conhece(algoritmo_exigido):
		lista.append("cachorro '%s' exige o algoritmo desconhecido '%s' (sem cor na legenda)"
			% [identificador, algoritmo_exigido])
	return lista
