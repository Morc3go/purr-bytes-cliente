extends SceneTree

## Gera os SpriteFrames (.tres) dos personagens a partir das folhas PNG.
##
##   godot --headless --path . --script res://tools/gerar_sprite_frames.gd
##
## Por que um script e nao o painel SpriteFrames do editor: montar dezenas de
## quadros a mao e onde nasce o erro de quadro trocado. O resultado e um .tres
## comum -- depois de gerado, da para abrir e ajustar no editor normalmente.
##
## Folhas, todas de quadros 32x32:
##   * gatos amarelo (o base), calico e siames: arte autoral da equipe, montada
##     por tools/arte/montar_gatos_autorais.py (ADR 0024 e 0030). As tres folhas
##     tem a mesma grade, por isso usam a mesma tabela LINHAS_GATO;
##   * cachorros husky e pastor: tools/arte/montar_folhas_32.py (ADR 0020, 0037
##     e 0042), uma linha por animacao, na ordem de LINHAS_CACHORRO; as duas
##     folhas tem a mesma grade.

const QUADRO_32: Vector2i = Vector2i(32, 32)

## Ritmo dos passos. O ciclo de andar tem sempre 4 passos (ver _ciclo()).
const QPS_ANDAR: float = 8.0

## Cada entrada: [animacao, quadros desenhados na linha, quadros por segundo]
## e, opcional, a celula (coluna, linha) do primeiro quadro. Sem ela, a linha
## da folha e a posicao na lista e a coluna comeca em 0.
##
## A linha 4 das folhas dos gatos tem quatro poses lado a lado: em pe, sentado de
## olho aberto (dois quadros, o rabo mexe) e sentado de olho fechado.
const LINHAS_GATO: Array = [
	[&"andar_baixo", 4, QPS_ANDAR],
	[&"andar_direita", 3, QPS_ANDAR],
	[&"andar_cima", 4, QPS_ANDAR],
	[&"andar_esquerda", 3, QPS_ANDAR],
	[&"parado", 1, 1.0, Vector2i(0, 4)],
	# Sentado de olho aberto: e o gato do menu, quieto entre os cachorros.
	[&"sentado", 2, 1.5, Vector2i(1, 4)],
	# Gato que cochila depois de um tempo sem entrada (ADR 0028): olho fechado.
	[&"descansar", 1, 1.0, Vector2i(3, 4)],
]
## Husky novo (ADR 0037): frente e costas com 4 passos, lados com 3.
const LINHAS_CACHORRO: Array = [
	[&"andar_baixo", 4, QPS_ANDAR],
	[&"andar_direita", 3, QPS_ANDAR],
	[&"andar_cima", 4, QPS_ANDAR],
	[&"andar_esquerda", 3, QPS_ANDAR],
	# Parado, o cachorro senta (em pe -> sentado) e fica sentado: nao repete.
	[&"parado", 2, 4.0],
]

## Animacoes que tocam uma vez e param no ultimo quadro.
const SEM_REPETIR: Array[StringName] = [&"parado"]

const FOLHAS: Dictionary = {
	"res://recursos/arte/gato_amarelo.png": {
		"destino": "res://recursos/arte/gato_amarelo_frames.tres", "linhas": LINHAS_GATO,
		"quadro": QUADRO_32,
	},
	"res://recursos/arte/gato_calico.png": {
		"destino": "res://recursos/arte/gato_calico_frames.tres", "linhas": LINHAS_GATO,
		"quadro": QUADRO_32,
	},
	"res://recursos/arte/gato_siames.png": {
		"destino": "res://recursos/arte/gato_siames_frames.tres", "linhas": LINHAS_GATO,
		"quadro": QUADRO_32,
	},
	"res://recursos/arte/cachorro.png": {
		"destino": "res://recursos/arte/cachorro_frames.tres", "linhas": LINHAS_CACHORRO,
		"quadro": QUADRO_32,
	},
	"res://recursos/arte/cachorro_pastor.png": {
		"destino": "res://recursos/arte/cachorro_pastor_frames.tres", "linhas": LINHAS_CACHORRO,
		"quadro": QUADRO_32,
	},
}

## Com um argumento (-- <pasta>), grava la em vez de sobrescrever recursos/:
## e assim que a suite confere que este gerador reproduz os .tres versionados.
var _pasta_de_saida: String = ""


func _initialize() -> void:
	var argumentos: PackedStringArray = OS.get_cmdline_user_args()
	if not argumentos.is_empty():
		_pasta_de_saida = argumentos[0]
	var codigo: int = 0
	for origem: String in FOLHAS:
		var destino: String = String(FOLHAS[origem]["destino"])
		if not _pasta_de_saida.is_empty():
			destino = _pasta_de_saida.path_join(destino.get_file())
		if not _salvar(montar(origem, FOLHAS[origem]), destino):
			codigo = 1
	quit(codigo)


static func _recorte(folha: Texture2D, coluna: int, linha: int, quadro: Vector2i) -> AtlasTexture:
	# AtlasTexture recorta a folha sem duplicar pixels: um PNG so no disco,
	# as regioes dentro do .tres.
	var recorte := AtlasTexture.new()
	recorte.atlas = folha
	recorte.region = Rect2(Vector2(coluna * quadro.x, linha * quadro.y), Vector2(quadro))
	return recorte


## Ordem de reproducao das colunas. Um andar de 3 quadros desenhados (passo,
## meio, passo) vira 0-1-2-1: e o vai-e-vem que fecha o ciclo sem a perna
## "teleportar" do ultimo passo para o primeiro.
static func _ciclo(nome: StringName, desenhados: int) -> Array[int]:
	var ordem: Array[int] = []
	for i: int in desenhados:
		ordem.append(i)
	if String(nome).begins_with("andar_") and desenhados == 3:
		ordem.append(1)
	return ordem


static func montar(caminho_folha: String, opcoes: Dictionary) -> SpriteFrames:
	var folha: Texture2D = load(caminho_folha) as Texture2D
	if folha == null:
		push_error("folha nao encontrada: %s (rode --import antes)" % caminho_folha)
		return null

	var quadros := SpriteFrames.new()
	quadros.remove_animation(&"default")
	var linhas: Array = opcoes["linhas"]
	var quadro: Vector2i = opcoes["quadro"]
	for i: int in linhas.size():
		var entrada: Array = linhas[i]
		var nome: StringName = entrada[0]
		var origem: Vector2i = entrada[3] if entrada.size() > 3 else Vector2i(0, i)
		quadros.add_animation(nome)
		# O parado do gato repete (rabo mexendo); o do cachorro, que senta, nao.
		var repete: bool = not (SEM_REPETIR.has(nome) and linhas == LINHAS_CACHORRO)
		quadros.set_animation_loop(nome, repete)
		quadros.set_animation_speed(nome, float(entrada[2]))
		for coluna: int in _ciclo(nome, int(entrada[1])):
			quadros.add_frame(nome, _recorte(folha, origem.x + coluna, origem.y, quadro))
	return quadros


func _salvar(quadros: SpriteFrames, destino: String) -> bool:
	if quadros == null:
		return false
	var erro: Error = ResourceSaver.save(quadros, destino)
	if erro != OK:
		push_error("falha ao salvar %s (erro %d)" % [destino, erro])
		return false
	print("gerado: %s" % destino)
	return true
