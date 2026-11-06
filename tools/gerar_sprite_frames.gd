extends SceneTree

## Gera os SpriteFrames (.tres) dos personagens a partir das folhas PNG.
##
##   godot --headless --path . --script res://tools/gerar_sprite_frames.gd
##
## Por que um script e nao o painel SpriteFrames do editor: montar dezenas de
## quadros a mao e onde nasce o erro de quadro trocado. O resultado e um .tres
## comum -- depois de gerado, da para abrir e ajustar no editor normalmente.
##
## Folhas (ADR 0020):
##   * gato tuxedo e cachorro husky: tools/arte/montar_folhas_32.py, quadros de
##     32x32, uma linha por animacao, na ordem de LINHAS de cada personagem;
##   * gato calico: a folha original de 24x24 (ADR 0013), mantida como segunda
##     aparencia do gato que o jogador escolhe no menu (ADR 0021).

const QUADRO_32: Vector2i = Vector2i(32, 32)
const QUADRO_24: Vector2i = Vector2i(24, 24)

## Ritmo dos passos. O ciclo de andar tem sempre 4 passos (ver _ciclo()).
const QPS_ANDAR: float = 8.0

## Cada entrada: [animacao, quadros desenhados na linha, quadros por segundo]
## e, opcional, a celula (coluna, linha) do primeiro quadro. Sem ela, a linha
## da folha e a posicao na lista e a coluna comeca em 0.
const LINHAS_GATO_TUXEDO: Array = [
	[&"andar_baixo", 4, QPS_ANDAR],
	[&"andar_direita", 3, QPS_ANDAR],
	[&"andar_cima", 4, QPS_ANDAR],
	[&"andar_esquerda", 3, QPS_ANDAR],
	[&"parado", 1, 1.0],
	# Gato que dorme apos 10 s sem entrada (ADR 0017): respiracao lenta.
	[&"descansar", 2, 1.5],
]
## A folha calico segue a grade antiga: 5 linhas de 4 quadros, sendo a linha 4
## o gato sentado ("descansar"); o "parado" e o primeiro quadro de frente.
const LINHAS_GATO_CALICO: Array = [
	[&"andar_baixo", 4, QPS_ANDAR],
	[&"andar_direita", 4, QPS_ANDAR],
	[&"andar_cima", 4, QPS_ANDAR],
	[&"andar_esquerda", 4, QPS_ANDAR],
	[&"descansar", 4, 1.5],
	[&"parado", 1, 1.0, Vector2i(0, 0)],
]
const LINHAS_CACHORRO: Array = [
	[&"andar_baixo", 3, QPS_ANDAR],
	[&"andar_direita", 3, QPS_ANDAR],
	[&"andar_cima", 4, QPS_ANDAR],
	[&"andar_esquerda", 3, QPS_ANDAR],
	# O cachorro nao descansa: o parado dele e o rabinho abanando.
	[&"parado", 2, 3.0],
]

const FOLHAS: Dictionary = {
	"res://recursos/arte/gato_tuxedo.png": {
		"destino": "res://recursos/arte/gato_tuxedo_frames.tres", "linhas": LINHAS_GATO_TUXEDO,
		"quadro": QUADRO_32,
	},
	"res://recursos/arte/gato_calico.png": {
		"destino": "res://recursos/arte/gato_calico_frames.tres", "linhas": LINHAS_GATO_CALICO,
		"quadro": QUADRO_24,
	},
	"res://recursos/arte/cachorro.png": {
		"destino": "res://recursos/arte/cachorro_frames.tres", "linhas": LINHAS_CACHORRO,
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
		quadros.set_animation_loop(nome, true)
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
