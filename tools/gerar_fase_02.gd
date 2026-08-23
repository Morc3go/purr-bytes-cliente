extends SceneTree

## Gera os artefatos de dado da Fase 2: recursos/fases/fase_02.tres (FaseConfig)
## e cenas/fases/fase_02.tscn (labirinto + 4 regioes para o Diretor).
##
## Roda-se UMA VEZ, headless:
##   godot --headless --path . --script res://tools/gerar_fase_02.gd
##
## Mesma logica de tools/gerar_fase_01.gd (ver o comentario la para o porque de
## gerar por script). A diferenca aqui: alem do labirinto, este gerador tambem
## escreve os 4 marcadores Area2D em Marcadores/Regioes -- sao DADO de cena,
## nao codigo de scripts/ia/diretor.gd, que so consome o que existir ali
## (docs/decisoes/0002-diretor-ia.md).
##
## '#' = parede (atlas 1,0) / '.' = piso (atlas 0,0). PontoDeEntrada reaproveita
## o default de fase_base.tscn (celula 1,1); PontoDeSaida e sobrescrito para o
## canto oposto do labirinto, bem maior que o da fase 1.
const MAPA: PackedStringArray = [
	"###################",
	"#.................#",
	"#.###############.#",
	"#...............#.#",
	"###############.#.#",
	"#.................#",
	"#.###############.#",
	"#...............#.#",
	"###############.#.#",
	"#.................#",
	"#.###############.#",
	"#...............#.#",
	"###################",
]

const TAMANHO_TILE: int = 16
const CAMINHO_TILESET: String = "res://recursos/tilesets/labirinto.tres"
const CAMINHO_CONFIG: String = "res://recursos/fases/fase_02.tres"
const CAMINHO_CENA: String = "res://cenas/fases/fase_02.tscn"

## Celula da saida (canto oposto ao da entrada, que fica em 1,1 -- default de
## fase_base.tscn, reaproveitado sem sobrescrever).
const CELULA_SAIDA: Vector2i = Vector2i(17, 11)


func _initialize() -> void:
	_gerar_config()
	var tile_map_data: PackedByteArray = _pintar_labirinto()
	_gerar_cena(tile_map_data)
	print("fase_02: config e cena gerados com sucesso.")
	quit(0)


func _gerar_config() -> void:
	var config := FaseConfig.new()
	config.numero = 2
	config.titulo = "o labirinto de Vigenere"
	config.algoritmo = "VIGENERE"
	config.verbos_permitidos = PackedStringArray(["cifrar", "decifrar", "dica", "status"])
	config.vidas_iniciais = 3
	config.velocidade_cachorro = 42.0
	config.intervalo_replanejamento_s = 1.0
	config.alcance_deteccao_cachorro = 90.0
	config.briefing_pedagogico = (
		"o pacote precisa atravessar o labirinto ate a saida, do outro lado do mapa.\n"
		+ "a chave desta vez e uma palavra, nao um numero: 'cifrar <pacote> chave=<palavra>'.\n"
		+ "o cachorro nao sabe onde voce esta -- mas errar no terminal ou ser visto de "
		+ "perto entrega pistas de qual regiao do mapa voce esta.")
	config.duracao_cifra_s = 12.0
	config.penalidade_captura = 50
	config.faixa_chave_minima = 3
	config.faixa_chave_maxima = 8
	config.texto_exemplo_demonstracao = "mensagem"
	config.chave_exemplo_demonstracao = "chave"
	# peso_pista_comando_errado, peso_pista_movimento, peso_pista_captura e
	# decaimento_crenca_por_s ficam no default do FaseConfig (ja ajustavel pelo
	# Inspector) -- nao ha razao pedagogica para esta fase divergir do padrao.

	var desafio1 := DesafioConfig.new()
	desafio1.identificador = "vigenere-01"
	desafio1.enunciado = "o pacote 'pacote' precisa de protecao. tente: cifrar pacote chave=gato"
	desafio1.texto_claro = "pacote"
	desafio1.chave_esperada = "gato"
	desafio1.verbo_esperado = "cifrar"
	desafio1.dica = "a chave e um bicho de estimacao comum, 4 letras."
	desafio1.pontos_acerto = 100
	desafio1.pontos_acerto_de_primeira = 150
	desafio1.custo_da_dica = 25

	var desafio2 := DesafioConfig.new()
	desafio2.identificador = "vigenere-02"
	desafio2.enunciado = "novo pacote 'servidor' atravessando, com outra chave: cifrar servidor chave=rede"
	desafio2.texto_claro = "servidor"
	desafio2.chave_esperada = "rede"
	desafio2.verbo_esperado = "cifrar"
	desafio2.dica = "a chave e a propria palavra que representa a topologia que voce esta atravessando."
	desafio2.pontos_acerto = 100
	desafio2.pontos_acerto_de_primeira = 150
	desafio2.custo_da_dica = 25

	config.desafios = [desafio1, desafio2]

	var problemas: PackedStringArray = config.problemas()
	if not problemas.is_empty():
		printerr("fase_02.tres invalido: %s" % ", ".join(problemas))
		quit(1)
		return

	var erro: Error = ResourceSaver.save(config, CAMINHO_CONFIG)
	if erro != OK:
		printerr("falha ao salvar %s (erro %d)" % [CAMINHO_CONFIG, erro])
		quit(1)


func _pintar_labirinto() -> PackedByteArray:
	var tileset: TileSet = load(CAMINHO_TILESET) as TileSet
	var labirinto := TileMapLayer.new()
	labirinto.tile_set = tileset

	for y: int in MAPA.size():
		var linha: String = MAPA[y]
		for x: int in linha.length():
			var solido: bool = linha[x] == "#"
			var atlas: Vector2i = Vector2i(1, 0) if solido else Vector2i(0, 0)
			labirinto.set_cell(Vector2i(x, y), 0, atlas)

	var dados: Variant = labirinto.get("tile_map_data")
	if typeof(dados) != TYPE_PACKED_BYTE_ARRAY:
		printerr("propriedade tile_map_data ausente ou de tipo inesperado (%s)" % type_string(typeof(dados)))
		quit(1)
		return PackedByteArray()

	labirinto.free()
	return dados as PackedByteArray


func _gerar_cena(tile_map_data: PackedByteArray) -> void:
	var bytes: PackedStringArray = PackedStringArray()
	for b: int in tile_map_data:
		bytes.append(str(b))

	var largura_mundo: float = float(MAPA[0].length()) * TAMANHO_TILE
	var altura_mundo: float = float(MAPA.size()) * TAMANHO_TILE
	var meio_x: float = largura_mundo / 2.0
	var meio_y: float = altura_mundo / 2.0

	var saida_mundo: Vector2 = Vector2(
		CELULA_SAIDA.x * TAMANHO_TILE + TAMANHO_TILE / 2.0,
		CELULA_SAIDA.y * TAMANHO_TILE + TAMANHO_TILE / 2.0)

	# 4 regioes cobrindo os quadrantes do mapa -- dado de cena para o Diretor
	# (scripts/ia/diretor.gd) consumir via Marcadores/Regioes.get_children().
	# O retangulo de cada regiao nao precisa alinhar pixel a pixel com as
	# paredes do labirinto: e so o que decide "o jogador esta nesta regiao"
	# para fins de crenca, nao um limite fisico.
	var regioes: Array[Dictionary] = [
		{"nome": "RegiaoNoroeste", "centro": Vector2(meio_x / 2.0, meio_y / 2.0)},
		{"nome": "RegiaoNordeste", "centro": Vector2(meio_x + meio_x / 2.0, meio_y / 2.0)},
		{"nome": "RegiaoSudoeste", "centro": Vector2(meio_x / 2.0, meio_y + meio_y / 2.0)},
		{"nome": "RegiaoSudeste", "centro": Vector2(meio_x + meio_x / 2.0, meio_y + meio_y / 2.0)},
	]
	var tamanho_regiao: Vector2 = Vector2(meio_x, meio_y)

	var texto: String = (
		"[gd_scene load_steps=3 format=3]\n\n"
		+ "[ext_resource type=\"PackedScene\" path=\"res://cenas/base/fase_base.tscn\" id=\"1_base\"]\n"
		+ "[ext_resource type=\"Resource\" path=\"%s\" id=\"2_config\"]\n\n" % CAMINHO_CONFIG
		+ "[sub_resource type=\"RectangleShape2D\" id=\"RectangleShape2D_regiao\"]\n"
		+ "size = Vector2(%s, %s)\n\n" % [tamanho_regiao.x, tamanho_regiao.y]
		+ "[node name=\"FaseBase\" instance=ExtResource(\"1_base\")]\n"
		+ "configuracao = ExtResource(\"2_config\")\n\n"
		+ "[node name=\"Labirinto\" parent=\".\" index=\"0\"]\n"
		+ "tile_map_data = PackedByteArray(%s)\n\n" % ",".join(bytes)
		+ "[node name=\"PontoDeSaida\" parent=\"Marcadores\" index=\"1\"]\n"
		+ "position = Vector2(%s, %s)\n" % [saida_mundo.x, saida_mundo.y]
	)

	for i: int in regioes.size():
		var regiao: Dictionary = regioes[i]
		var centro: Vector2 = regiao["centro"]
		texto += (
			"\n[node name=\"%s\" type=\"Area2D\" parent=\"Marcadores/Regioes\"]\n" % regiao["nome"]
			+ "position = Vector2(%s, %s)\n" % [centro.x, centro.y]
			+ "collision_layer = 0\n"
			+ "collision_mask = 2\n\n"
			+ "[node name=\"Colisao\" type=\"CollisionShape2D\" parent=\"Marcadores/Regioes/%s\"]\n"
				% regiao["nome"]
			+ "shape = SubResource(\"RectangleShape2D_regiao\")\n"
		)

	var arquivo: FileAccess = FileAccess.open(CAMINHO_CENA, FileAccess.WRITE)
	if arquivo == null:
		printerr("falha ao escrever %s (erro %d)" % [CAMINHO_CENA, FileAccess.get_open_error()])
		quit(1)
		return
	arquivo.store_string(texto)
	arquivo.close()
