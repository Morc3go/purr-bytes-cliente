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
		# So os desafios de 'verificar' tem prefixo de digest; os de revisao
		# (cifrar, Cesar e Vigenere) sao resolvidos por chave e nao por prefixo.
		if desafio.verbo_esperado != "verificar":
			continue
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

	# Revisoes das duas fases anteriores. Nao sao enfeite: sao o que permite a
	# fase final ter os TRES cachorros (verde, azul e roxo) sem nenhum deles ser
	# impossivel de enganar -- e, de quebra, e a unica fase em que o jogador
	# precisa escolher entre tres cifras olhando a cor de quem esta vindo, que e
	# o exercicio final da mecanica.
	var desafio3 := DesafioConfig.new()
	desafio3.identificador = "vigenere-revisao"
	desafio3.enunciado = ("pacote em Vigenere no meio do caminho: cifrar rede chave=gato. "
		+ "e a cifra que engana o cachorro azul.")
	desafio3.texto_claro = "rede"
	desafio3.chave_esperada = "gato"
	desafio3.verbo_esperado = "cifrar"
	desafio3.algoritmo = "VIGENERE"
	desafio3.dica = "Vigenere usa chave-palavra: o deslocamento muda a cada letra."
	desafio3.pontos_acerto = 80
	desafio3.pontos_acerto_de_primeira = 120
	desafio3.custo_da_dica = 25

	var desafio4 := DesafioConfig.new()
	desafio4.identificador = "cesar-revisao"
	desafio4.enunciado = ("pacote antigo em Cesar: cifrar chave chave=7. "
		+ "e a cifra que engana o cachorro verde.")
	desafio4.texto_claro = "chave"
	desafio4.chave_esperada = "7"
	desafio4.verbo_esperado = "cifrar"
	desafio4.algoritmo = "CESAR"
	desafio4.dica = "Cesar e deslocamento fixo: a chave e um numero."
	desafio4.pontos_acerto = 80
	desafio4.pontos_acerto_de_primeira = 120
	desafio4.custo_da_dica = 25

	return [desafio1, desafio2, desafio3, desafio4]


func _gerar_config(desafios: Array[DesafioConfig]) -> void:
	var config := FaseConfig.new()
	config.numero = 3
	config.titulo = "o labirinto de SHA-256"
	config.algoritmo = "SHA256"
	# "cifrar" volta a lista porque a fase final tem cachorro verde e azul, e as
	# revisoes de Cesar e Vigenere sao resolvidas com ele.
	config.verbos_permitidos = PackedStringArray(["hash", "verificar", "cifrar", "dica", "status"])
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

	# Fase final: as tres cores em cena ao mesmo tempo. Cada uma so e enganada
	# pela cifra correspondente, e as tres estao disponiveis nos desafios acima.
	var cachorro_roxo := CachorroConfig.new()
	cachorro_roxo.identificador = "roxo-norte"
	cachorro_roxo.algoritmo_exigido = "SHA256"
	cachorro_roxo.celula_inicial = Vector2i(5, 1)
	cachorro_roxo.ancoras = [Vector2i(1, 1), Vector2i(15, 1), Vector2i(15, 3), Vector2i(3, 3)]

	var cachorro_azul := CachorroConfig.new()
	cachorro_azul.identificador = "azul-centro"
	cachorro_azul.algoritmo_exigido = "VIGENERE"
	cachorro_azul.celula_inicial = Vector2i(9, 5)
	cachorro_azul.ancoras = [Vector2i(1, 5), Vector2i(17, 5), Vector2i(17, 7), Vector2i(3, 7)]

	var cachorro_verde := CachorroConfig.new()
	cachorro_verde.identificador = "verde-sul"
	cachorro_verde.algoritmo_exigido = "CESAR"
	cachorro_verde.celula_inicial = Vector2i(9, 9)
	cachorro_verde.ancoras = [Vector2i(1, 9), Vector2i(15, 9), Vector2i(15, 11), Vector2i(3, 11)]
	cachorro_verde.velocidade = 36.0

	config.cachorros = [cachorro_roxo, cachorro_azul, cachorro_verde]

	# Fase final: as perguntas separam cifra de hash, que e a confusao que a
	# fase 3 existe para desfazer.
	var pacote_norte := PacoteConfig.new()
	pacote_norte.identificador = "sha-norte"
	pacote_norte.celula = Vector2i(15, 1)
	pacote_norte.enunciado = ("o pacote chegou com um resumo anexado e voce precisa saber se o "
		+ "conteudo foi adulterado. que ferramenta responde isso?")
	pacote_norte.opcoes = PackedStringArray(["CESAR", "VIGENERE", "SHA256"])
	pacote_norte.resposta_correta = "SHA256"
	pacote_norte.explicacao_correta = ("SHA-256 e de mao unica: nao esconde o conteudo, prova que "
		+ "ele nao mudou. e integridade, nao sigilo.")

	var pacote_centro := PacoteConfig.new()
	pacote_centro.identificador = "sha-centro"
	pacote_centro.celula = Vector2i(9, 5)
	pacote_centro.enunciado = ("qual destas NAO da para desfazer para recuperar o texto "
		+ "original, nem com a chave certa?")
	pacote_centro.opcoes = PackedStringArray(["CESAR", "VIGENERE", "SHA256"])
	pacote_centro.resposta_correta = "SHA256"
	pacote_centro.explicacao_correta = ("nao existe 'dehash'. cifra se desfaz com a chave; hash, nunca.")

	var pacote_sul := PacoteConfig.new()
	pacote_sul.identificador = "vigenere-sul"
	pacote_sul.celula = Vector2i(3, 11)
	pacote_sul.enunciado = ("um cachorro AZUL apareceu no corredor de baixo. qual das tres "
		+ "protege o pacote dele?")
	pacote_sul.opcoes = PackedStringArray(["CESAR", "VIGENERE", "SHA256"])
	pacote_sul.resposta_correta = "VIGENERE"
	pacote_sul.explicacao_correta = ("azul = Vigenere. e repare: hash nao serve para se esconder "
		+ "de cachorro nenhum, so o roxo se deixa enganar por ele.")

	config.pacotes = [pacote_norte, pacote_centro, pacote_sul]

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
