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
##
## 25x19 (era 15x9). O mapa anterior era um par de corredores espelhados: duas
## voltas identicas, sem escolha de rota e sem nenhum lugar para se esconder --
## a "sensacao de modelo copiado". Este foi gerado por backtracker recursivo de
## semente fixa e depois teve camaras carvadas a mao (sala de entrada, camara
## central, sala da porta e as duas salas de pacote) mais 16 aberturas extras,
## que sao o que transforma a arvore do backtracker em grafo com ciclos: existe
## mais de um caminho entre dois pontos quaisquer, entao fugir do cachorro e uma
## decisao, nao um corredor unico.
##
## PontoDeEntrada fica em (1,1) -- a mesma Vector2(24,24) default de
## fase_base.tscn. PontoDeSaida (a porta) e CELULA_SAIDA, no canto oposto, e
## por isso fase_01.tscn passa a sobrescrever esse marcador.
const MAPA: PackedStringArray = [
	"#########################",
	"#.........#.....#.......#",
	"#.....###.#.#.###.#....##",
	"#.....#.....#.....#.....#",
	"#.#.#...#.#####.###.###.#",
	"#.#.#...#.............#.#",
	"#.#####.#.#######.#.###.#",
	"#.....#.........#.#...#.#",
	"##.##.#.#.......#.###.#.#",
	"#.....#...............#.#",
	"#.#######......#.######.#",
	"#.......#...#...........#",
	"#######.#...#.#.###.###.#",
	"#.#...#.#.#.........#...#",
	"#.....#...###.#..#......#",
	"#.......#.....#.........#",
	"#....########.###.......#",
	"#.............#.........#",
	"#########################",
]

const TAMANHO_TILE: float = 16.0
const CELULA_SAIDA: Vector2i = Vector2i(22, 16)

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

	# Dois cachorros VERDES: nesta fase o jogador so aprendeu Cesar, entao so
	# existe interceptador de Cesar. Colocar aqui um cachorro azul (Vigenere)
	# seria uma captura impossivel de evitar com o que a fase ensinou -- a cor
	# so entra em jogo quando o jogador ja tem a cifra correspondente na mao
	# (fase 2 ganha o azul, fase 3 o roxo). O que a fase 1 ensina e a leitura da
	# cor; a escolha entre cores comeca na fase 2.
	#
	# As ancoras sao celulas do MAPA acima, escolhidas nos corredores que ligam
	# entrada, pacotes e porta: o jogador cruza com os dois no caminho natural,
	# que e de onde vem a tensao.
	var cachorro_norte := CachorroConfig.new()
	cachorro_norte.identificador = "verde-norte"
	cachorro_norte.algoritmo_exigido = "CESAR"
	cachorro_norte.celula_inicial = Vector2i(13, 5)
	cachorro_norte.ancoras = [Vector2i(9, 5), Vector2i(20, 5), Vector2i(19, 3), Vector2i(11, 3)]

	var cachorro_sul := CachorroConfig.new()
	cachorro_sul.identificador = "verde-sul"
	cachorro_sul.algoritmo_exigido = "CESAR"
	cachorro_sul.celula_inicial = Vector2i(11, 15)
	cachorro_sul.ancoras = [Vector2i(3, 15), Vector2i(11, 17), Vector2i(19, 15), Vector2i(11, 13)]
	cachorro_sul.velocidade = 34.0  # mais lento: patrulha o dobro de distancia

	config.cachorros = [cachorro_norte, cachorro_sul]

	# Tres pacotes em pontas distantes do labirinto: o percurso ate todos eles
	# passa pelas duas rotas de patrulha, que e o que obriga a explorar o mapa
	# novo em vez de correr direto para a porta.
	#
	# As perguntas da fase 1 sao de LEITURA da legenda de cores, nao de teoria:
	# o jogador acabou de ver a tabela no menu e tem cachorros verdes na tela.
	var pacote_nordeste := PacoteConfig.new()
	pacote_nordeste.identificador = "cesar-ne"
	pacote_nordeste.celula = Vector2i(21, 2)
	pacote_nordeste.enunciado = ("este pacote precisa atravessar o corredor onde ronda um "
		+ "cachorro VERDE. qual cifra o protege ali?")
	pacote_nordeste.opcoes = PackedStringArray(["CESAR", "VIGENERE", "SHA256"])
	pacote_nordeste.resposta_correta = "CESAR"
	pacote_nordeste.explicacao_correta = ("isso. verde = Cesar: cada cor de cachorro le uma "
		+ "cifra so, e cifrar na cor errada nao protege.")

	var pacote_centro := PacoteConfig.new()
	pacote_centro.identificador = "cesar-centro"
	pacote_centro.celula = Vector2i(11, 8)
	pacote_centro.enunciado = ("na cifra de Cesar, o que exatamente e a chave que voce "
		+ "digita no terminal?")
	pacote_centro.opcoes = PackedStringArray(["CESAR", "VIGENERE", "SHA256"])
	pacote_centro.resposta_correta = "CESAR"
	pacote_centro.explicacao_correta = ("a chave de Cesar e um NUMERO: quantas casas cada letra "
		+ "anda no alfabeto. as outras cifras usam outra coisa.")

	var pacote_sudoeste := PacoteConfig.new()
	pacote_sudoeste.identificador = "cesar-so"
	pacote_sudoeste.celula = Vector2i(2, 15)
	pacote_sudoeste.enunciado = ("um pacote em texto claro foi interceptado no caminho. "
		+ "que ferramenta teria impedido a leitura do conteudo?")
	pacote_sudoeste.opcoes = PackedStringArray(["CESAR", "SHA256"])
	pacote_sudoeste.resposta_correta = "CESAR"
	pacote_sudoeste.explicacao_correta = ("cifra esconde o conteudo; hash nao esconde nada, "
		+ "so prova que o conteudo nao mudou. voce vai usar hash na fase 3.")

	config.pacotes = [pacote_nordeste, pacote_centro, pacote_sudoeste]

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

	var saida_mundo := Vector2(
		CELULA_SAIDA.x * TAMANHO_TILE + TAMANHO_TILE / 2.0,
		CELULA_SAIDA.y * TAMANHO_TILE + TAMANHO_TILE / 2.0)

	var texto: String = (
		"[gd_scene load_steps=3 format=3]\n\n"
		+ "[ext_resource type=\"PackedScene\" path=\"res://cenas/base/fase_base.tscn\" id=\"1_base\"]\n"
		+ "[ext_resource type=\"Resource\" path=\"%s\" id=\"2_config\"]\n\n" % CAMINHO_CONFIG
		+ "[node name=\"FaseBase\" instance=ExtResource(\"1_base\")]\n"
		+ "configuracao = ExtResource(\"2_config\")\n\n"
		+ "[node name=\"Labirinto\" parent=\".\" index=\"0\"]\n"
		+ "tile_map_data = PackedByteArray(%s)\n\n" % ",".join(bytes)
		+ "[node name=\"PontoDeSaida\" parent=\"Marcadores\" index=\"1\"]\n"
		+ "position = Vector2(%s, %s)\n" % [saida_mundo.x, saida_mundo.y]
	)

	var arquivo: FileAccess = FileAccess.open(CAMINHO_CENA, FileAccess.WRITE)
	if arquivo == null:
		printerr("falha ao escrever %s (erro %d)" % [CAMINHO_CENA, FileAccess.get_open_error()])
		quit(1)
		return
	arquivo.store_string(texto)
	arquivo.close()
