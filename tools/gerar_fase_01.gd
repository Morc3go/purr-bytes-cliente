extends SceneTree

## Gera os artefatos de dado da Fase 1: recursos/fases/fase_01.tres (FaseConfig)
## e o labirinto de cenas/fases/fase_01.tscn.
##
## Roda-se UMA VEZ, headless:
##   godot --headless --path . --script res://tools/gerar_fase_01.gd
##
## Por que gerar por script em vez de desenhar so no editor: o labirinto e um
## dado auditavel (a mesma grade que os testes de integracao percorrem), e
## regravar por aqui e reproduzivel -- ajustar o ASCII abaixo e rodar de novo,
## sem depender de clique certo no editor. O editor continua sendo o lugar
## certo pra AJUSTE fino (trocar a arte placeholder, mover um marcador um
## pixel); a topologia do labirinto, essa nasce do dado.
##
## '#' = parede (atlas 1,0, "solido"=true) / '.' = piso (atlas 0,0).
## PontoDeEntrada fica em (1,1) e PontoDeSaida em (7,5) -- coordenadas de
## celula que ja casam com as posicoes default de fase_base.tscn (Vector2(24,24)
## e Vector2(120,88) com tile 16x16), entao fase_01.tscn nao precisa sobrescrever
## os marcadores, so o labirinto e o FaseConfig.
const MAPA: PackedStringArray = [
	"###############",
	"#.............#",
	"#.###########.#",
	"#...........#.#",
	"###########.#.#",
	"#.............#",
	"#.###########.#",
	"#.............#",
	"###############",
]

const CAMINHO_TILESET: String = "res://recursos/tilesets/labirinto.tres"
const CAMINHO_CONFIG: String = "res://recursos/fases/fase_01.tres"
const CAMINHO_CENA: String = "res://cenas/fases/fase_01.tscn"


func _initialize() -> void:
	_gerar_config()
	var tile_map_data: PackedByteArray = _pintar_labirinto()
	_gerar_cena(tile_map_data)
	print("fase_01: config e cena gerados com sucesso.")
	quit(0)


func _gerar_config() -> void:
	var config := FaseConfig.new()
	config.numero = 1
	config.titulo = "o labirinto de Cesar"
	config.algoritmo = "CESAR"
	config.verbos_permitidos = PackedStringArray(["cifrar", "decifrar", "dica", "status"])
	config.vidas_iniciais = 3
	config.velocidade_cachorro = 40.0
	config.intervalo_replanejamento_s = 1.0
	config.alcance_deteccao_cachorro = 90.0
	config.briefing_pedagogico = (
		"o pacote precisa atravessar o labirinto ate a saida.\n"
		+ "em texto claro, o cachorro fareja e intercepta -- use 'cifrar <pacote> chave=<numero>' "
		+ "para proteger, 'dica' se travar, 'status' para reler o desafio atual.")
	config.duracao_cifra_s = 12.0
	config.penalidade_captura = 50
	config.faixa_chave_minima = 1
	config.faixa_chave_maxima = 25

	var desafio1 := DesafioConfig.new()
	desafio1.identificador = "cesar-01"
	desafio1.enunciado = "o pacote 'pacote' precisa de protecao. desloque 3 posicoes: cifrar pacote chave=3"
	desafio1.texto_claro = "pacote"
	desafio1.chave_esperada = "3"
	desafio1.verbo_esperado = "cifrar"
	desafio1.dica = "conte 3 letras a frente de cada letra: 'p'->'s', 'a'->'d' ..."
	desafio1.pontos_acerto = 100
	desafio1.pontos_acerto_de_primeira = 150
	desafio1.custo_da_dica = 25

	var desafio2 := DesafioConfig.new()
	desafio2.identificador = "cesar-02"
	desafio2.enunciado = "novo pacote 'rede' atravessando. desta vez o deslocamento e outro: cifrar rede chave=5"
	desafio2.texto_claro = "rede"
	desafio2.chave_esperada = "5"
	desafio2.verbo_esperado = "cifrar"
	desafio2.dica = "desloque 5 posicoes desta vez, nao 3 -- cada pacote pode usar uma chave diferente."
	desafio2.pontos_acerto = 100
	desafio2.pontos_acerto_de_primeira = 150
	desafio2.custo_da_dica = 25

	config.desafios = [desafio1, desafio2]

	var problemas: PackedStringArray = config.problemas()
	if not problemas.is_empty():
		printerr("fase_01.tres invalido: %s" % ", ".join(problemas))
		quit(1)
		return

	var erro: Error = ResourceSaver.save(config, CAMINHO_CONFIG)
	if erro != OK:
		printerr("falha ao salvar %s (erro %d)" % [CAMINHO_CONFIG, erro])
		quit(1)


## Pinta o MAPA numa TileMapLayer temporaria e devolve os bytes de tile_map_data
## prontos para embutir no override do no Labirinto em fase_01.tscn.
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

	var texto: String = (
		"[gd_scene load_steps=3 format=3]\n\n"
		+ "[ext_resource type=\"PackedScene\" path=\"res://cenas/base/fase_base.tscn\" id=\"1_base\"]\n"
		+ "[ext_resource type=\"Resource\" path=\"%s\" id=\"2_config\"]\n\n" % CAMINHO_CONFIG
		+ "[node name=\"FaseBase\" instance=ExtResource(\"1_base\")]\n"
		+ "configuracao = ExtResource(\"2_config\")\n\n"
		+ "[node name=\"Labirinto\" parent=\".\" index=\"0\"]\n"
		+ "tile_map_data = PackedByteArray(%s)\n" % ",".join(bytes)
	)

	var arquivo: FileAccess = FileAccess.open(CAMINHO_CENA, FileAccess.WRITE)
	if arquivo == null:
		printerr("falha ao escrever %s (erro %d)" % [CAMINHO_CENA, FileAccess.get_open_error()])
		quit(1)
		return
	arquivo.store_string(texto)
	arquivo.close()
