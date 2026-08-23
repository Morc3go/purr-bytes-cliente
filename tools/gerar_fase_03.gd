extends SceneTree

## Gera os artefatos de dado da Fase 3: recursos/fases/fase_03.tres (FaseConfig)
## e cenas/fases/fase_03.tscn (labirinto + 4 regioes, mesmo padrao da fase_02).
##
## Roda-se UMA VEZ, headless:
##   godot --headless --path . --script res://tools/gerar_fase_03.gd
##
## Os digests dos desafios sao calculados por Sha256.digest_hex() -- o MESMO
## caminho de codigo que roda no jogo -- em vez de transcritos a mao. Isso
## evita exatamente o erro que aconteceu com o vetor de teste de "" em
## tests/teste_sha256.gd (um digito digitado errado a mao): o dado do desafio
## nasce de uma execucao real do algoritmo, nunca de copiar e colar.
##
## O prefixo escolhido para cada desafio tem que COMECAR com uma letra
## hexadecimal (a-f), nao um digito -- documentado em
## docs/decisoes/0009-sha256-http-e-resiliencia.md: o AFD (scripts/lexico/
## analisador_lexico.gd) tokeniza "5d41402a" como NUMERO("5") + IDENTIFICADOR
## ("d41402a") porque NUMERO so aceita digito continuo, e a gramatica trataria
## os dois como argumentos SEPARADOS. Prefixo comecando em letra tokeniza
## inteiro como um IDENTIFICADOR so (IDENTIFICADOR aceita letra seguida de
## letra/digito/underscore). Isso e uma restricao de AUTORIA de dado, nao uma
## mudanca de gramatica -- o parser continua intocado desde o Marco 1.
const TAMANHO_PREFIXO: int = 8

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
const CAMINHO_CONFIG: String = "res://recursos/fases/fase_03.tres"
const CAMINHO_CENA: String = "res://cenas/fases/fase_03.tscn"
const CELULA_SAIDA: Vector2i = Vector2i(17, 11)


func _initialize() -> void:
	var desafios: Array[DesafioConfig] = _gerar_desafios()
	for desafio: DesafioConfig in desafios:
		if desafio.resposta_esperada.is_empty() or _e_digito(desafio.resposta_esperada[0]):
			printerr("desafio '%s': prefixo '%s' comeca com digito -- escolha outro texto_claro"
				% [desafio.identificador, desafio.resposta_esperada])
			quit(1)
			return

	_gerar_config(desafios)
	var tile_map_data: PackedByteArray = _pintar_labirinto()
	_gerar_cena(tile_map_data)
	print("fase_03: config e cena gerados com sucesso.")
	quit(0)


func _e_digito(c: String) -> bool:
	return c >= "0" and c <= "9"


func _gerar_desafios() -> Array[DesafioConfig]:
	var desafio1 := DesafioConfig.new()
	desafio1.identificador = "sha256-01"
	desafio1.enunciado = "o pacote 'pacote' chegou com um digest anexado. confira antes de entregar."
	desafio1.texto_claro = "pacote"
	desafio1.chave_esperada = ""  # hash nao tem chave
	desafio1.resposta_esperada = Sha256.digest_hex("pacote").substr(0, TAMANHO_PREFIXO)
	desafio1.verbo_esperado = "verificar"
	desafio1.dica = "use 'hash pacote' para calcular o digest voce mesmo e comparar."
	desafio1.pontos_acerto = 100
	desafio1.pontos_acerto_de_primeira = 150
	desafio1.custo_da_dica = 25

	var desafio2 := DesafioConfig.new()
	desafio2.identificador = "sha256-02"
	desafio2.enunciado = "novo pacote 'mensagem' atravessando. confira a integridade de novo."
	desafio2.texto_claro = "mensagem"
	desafio2.chave_esperada = ""
	desafio2.resposta_esperada = Sha256.digest_hex("mensagem").substr(0, TAMANHO_PREFIXO)
	desafio2.verbo_esperado = "verificar"
	desafio2.dica = "'hash mensagem' calcula o digest -- compare os primeiros 8 digitos."
	desafio2.pontos_acerto = 100
	desafio2.pontos_acerto_de_primeira = 150
	desafio2.custo_da_dica = 25

	return [desafio1, desafio2]


func _gerar_config(desafios: Array[DesafioConfig]) -> void:
	var config := FaseConfig.new()
	config.numero = 3
	config.titulo = "o labirinto de SHA-256"
	config.algoritmo = "SHA256"
	config.verbos_permitidos = PackedStringArray(["hash", "verificar", "dica", "status"])
	config.vidas_iniciais = 3
	config.velocidade_cachorro = 44.0
	config.intervalo_replanejamento_s = 1.0
	config.alcance_deteccao_cachorro = 90.0
	config.briefing_pedagogico = (
		"o pacote chega com um digest anexado -- um resumo de mao unica do conteudo.\n"
		+ "use 'hash <palavra>' para calcular o digest de verdade, e 'verificar <palavra> "
		+ "<prefixo>' para confirmar que o pacote nao foi adulterado antes de entregar.\n"
		+ "hash nao se desfaz: nao ha 'dehash'. serve para conferir, nao para esconder.")
	config.duracao_cifra_s = 12.0
	config.penalidade_captura = 50
	config.texto_exemplo_demonstracao = "exemplo"
	config.desafios = desafios

	var problemas: PackedStringArray = config.problemas()
	if not problemas.is_empty():
		printerr("fase_03.tres invalido: %s" % ", ".join(problemas))
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
