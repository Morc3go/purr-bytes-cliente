class_name Navegacao
extends RefCounted

## Wrapper fino sobre AStarGrid2D -- ferramenta nativa da secao 2 do CLAUDE.md
## para pathfinding em grade, entao nao ha razao para reimplementar busca em
## grafo aqui. A unica reimplementacao deliberada do projeto e
## scripts/ia/astar_referencia.gd, que nao roda em jogo nenhum (docs/decisoes/0001-astar.md).
##
## region vem de TileMapLayer.get_used_rect(), cell_size do TileSet, 4 direcoes
## (DIAGONAL_MODE_NEVER) e heuristica de Manhattan -- exatamente como a secao 6
## do CLAUDE.md pede, e pelo mesmo motivo do oraculo didatico: admissivel e
## consistente aqui, entao o caminho devolvido e sempre de custo minimo.
##
## Quem le "solido" e este wrapper, no TileData da mesma TileMapLayer que a
## colisao fisica usa (recursos/tilesets/labirinto.tres) -- mapa e navegacao
## sao o mesmo dado, nunca uma tabela paralela para desalinhar.

var _grade: AStarGrid2D = AStarGrid2D.new()
var _labirinto: TileMapLayer = null
var _indice_camada_solido: int = -1


func configurar(labirinto: TileMapLayer) -> void:
	_labirinto = labirinto
	var conjunto: TileSet = labirinto.tile_set
	_indice_camada_solido = _indice_da_camada_solido(conjunto)

	var regiao: Rect2i = labirinto.get_used_rect()
	_grade.region = regiao
	_grade.cell_size = Vector2(conjunto.tile_size)
	_grade.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_grade.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_grade.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_grade.update()

	for y: int in range(regiao.position.y, regiao.position.y + regiao.size.y):
		for x: int in range(regiao.position.x, regiao.position.x + regiao.size.x):
			var celula := Vector2i(x, y)
			_grade.set_point_solid(celula, _e_solido(celula))


## Caminho em coordenadas de MUNDO, pronto para Cachorro.definir_caminho().
## Vazio se origem/destino cairem fora da grade, o destino for solido, ou nao
## houver caminho -- Cachorro.parar() ja trata caminho vazio como "ficar parado".
func calcular_caminho(origem_mundo: Vector2, destino_mundo: Vector2) -> PackedVector2Array:
	if _labirinto == null:
		return PackedVector2Array()

	var celula_origem: Vector2i = _labirinto.local_to_map(_labirinto.to_local(origem_mundo))
	var celula_destino: Vector2i = _labirinto.local_to_map(_labirinto.to_local(destino_mundo))

	if not _grade.is_in_boundsv(celula_origem) or not _grade.is_in_boundsv(celula_destino):
		return PackedVector2Array()
	if _grade.is_point_solid(celula_destino):
		return PackedVector2Array()

	var caminho_local: PackedVector2Array = _grade.get_point_path(celula_origem, celula_destino)
	var caminho_mundo := PackedVector2Array()
	for ponto: Vector2 in caminho_local:
		# Os pontos do AStarGrid2D ja estao no espaco local da TileMapLayer
		# (mesma formula de map_to_local para grade ortogonal): so falta o
		# transform da propria fase para virar coordenada de mundo.
		caminho_mundo.append(_labirinto.to_global(ponto))
	return caminho_mundo


func _e_solido(celula: Vector2i) -> bool:
	var dados: TileData = _labirinto.get_cell_tile_data(celula)
	if dados == null:
		# Fora do que foi pintado no labirinto: nao andavel, e nao vazio.
		return true
	if _indice_camada_solido < 0:
		return false
	return bool(dados.get_custom_data_by_layer_id(_indice_camada_solido))


func _indice_da_camada_solido(conjunto: TileSet) -> int:
	for i: int in conjunto.get_custom_data_layers_count():
		if conjunto.get_custom_data_layer_name(i) == "solido":
			return i
	return -1
