extends SceneTree

## Gera os SpriteFrames (.tres) dos personagens a partir das folhas PNG.
##
##   godot --headless --path . --script res://tools/gerar_sprite_frames.gd
##
## Por que um script e nao o painel SpriteFrames do editor: as duas folhas
## seguem a mesma grade (5 linhas x 4 quadros de 24x24), e montar 40 quadros a
## mao e onde nasce o erro de quadro trocado. O resultado e um .tres comum --
## depois de gerado, da para abrir e ajustar no editor normalmente.
##
## Grade da folha (linha -> animacao), a mesma da arte original do gato:
##   0 andar_baixo | 1 andar_direita | 2 andar_cima | 3 andar_esquerda
##   4 descansar (gato) / parado (cachorro) -- ver FOLHAS

const TAMANHO_QUADRO: Vector2i = Vector2i(24, 24)
const QUADROS_POR_LINHA: int = 4
## Linhas 0..3 da folha: andar nas quatro direcoes, iguais para os dois.
const ANIMACOES_DE_ANDAR: Array[StringName] = [
	&"andar_baixo", &"andar_direita", &"andar_cima", &"andar_esquerda",
]
const QPS_ANDAR: float = 8.0

## O que cada folha faz com a linha 4 e com o "parado". O gato ganhou em ADR
## 0017 (pedido da equipe) um "parado" de um quadro so, de olho aberto, e a
## linha 4 (sentado) virou "descansar" -- o gato que dorme apos 10 s sem
## entrada. O cachorro nao descansa: a linha 4 dele continua sendo o parado.
const FOLHAS: Dictionary = {
	"res://recursos/arte/gato.png": {
		"destino": "res://recursos/arte/gato_frames.tres",
		"linha_4": &"descansar", "qps_linha_4": 1.5,
		"parado_de_um_quadro": Vector2i(0, 0), "qps_parado": 1.0,
	},
	"res://recursos/arte/cachorro.png": {
		"destino": "res://recursos/arte/cachorro_frames.tres",
		"linha_4": &"parado", "qps_linha_4": 3.0,
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


static func _recorte(folha: Texture2D, coluna: int, linha: int) -> AtlasTexture:
	# AtlasTexture recorta a folha sem duplicar pixels: um PNG so no disco,
	# as regioes dentro do .tres.
	var recorte := AtlasTexture.new()
	recorte.atlas = folha
	recorte.region = Rect2(Vector2(coluna * TAMANHO_QUADRO.x, linha * TAMANHO_QUADRO.y),
		Vector2(TAMANHO_QUADRO))
	return recorte


static func montar(caminho_folha: String, opcoes: Dictionary) -> SpriteFrames:
	var folha: Texture2D = load(caminho_folha) as Texture2D
	if folha == null:
		push_error("folha nao encontrada: %s (rode --import antes)" % caminho_folha)
		return null

	var quadros := SpriteFrames.new()
	quadros.remove_animation(&"default")
	var linhas: Array[StringName] = ANIMACOES_DE_ANDAR.duplicate()
	linhas.append(opcoes["linha_4"] as StringName)
	for linha: int in linhas.size():
		var nome: StringName = linhas[linha]
		quadros.add_animation(nome)
		quadros.set_animation_loop(nome, true)
		quadros.set_animation_speed(nome, QPS_ANDAR if linha < 4 else float(opcoes["qps_linha_4"]))
		for coluna: int in QUADROS_POR_LINHA:
			quadros.add_frame(nome, _recorte(folha, coluna, linha))

	if opcoes.has("parado_de_um_quadro"):
		var celula: Vector2i = opcoes["parado_de_um_quadro"]
		quadros.add_animation(&"parado")
		quadros.set_animation_loop(&"parado", true)
		quadros.set_animation_speed(&"parado", float(opcoes["qps_parado"]))
		quadros.add_frame(&"parado", _recorte(folha, celula.x, celula.y))
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
