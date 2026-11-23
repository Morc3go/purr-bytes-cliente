extends CasoDeTeste

## Arte provisoria do labirinto: grama e cerca viva (ADR 0025).
##
## O que protege: (a) a escolha da peca de cada quarto da parede, que e onde um
## erro aparece como buraco ou quina errada na cerca, e (b) que vestir o
## labirinto e SO visual: as celulas solidas, que colisao e A* usam, nao mudam.


func _labirinto_de(texto: PackedStringArray) -> TileMapLayer:
	var labirinto := TileMapLayer.new()
	labirinto.tile_set = load("res://recursos/tilesets/labirinto.tres") as TileSet
	for y: int in texto.size():
		for x: int in texto[y].length():
			# Atlas do placeholder: (1, 0) e parede (solido), (0, 0) e chao.
			labirinto.set_cell(Vector2i(x, y), 0, Vector2i(1, 0) if texto[y][x] == "#" else Vector2i(0, 0))
	add_child(labirinto)
	return labirinto


func teste_pecas_de_cada_quarto() -> void:
	# Um T: barra horizontal em cima, haste descendo do meio.
	var labirinto: TileMapLayer = _labirinto_de(PackedStringArray([
		".....",
		".###.",
		"..#..",
		"..#..",
		".....",
	]))
	var arbustos := ArbustosDoLabirinto.new()
	labirinto.add_child(arbustos)
	arbustos.vestir(labirinto)
	var T := ArbustosDoLabirinto.Tipo
	afirmar_igual(arbustos.tipo_do_quarto(Vector2i(1, 1), Vector2i(-1, -1)), T.QUINA_DE_FORA, "ponta esquerda, canto de cima")
	afirmar_igual(arbustos.tipo_do_quarto(Vector2i(1, 1), Vector2i(1, -1)), T.BORDA_HORIZONTAL, "ponta esquerda segue para a direita")
	afirmar_igual(arbustos.tipo_do_quarto(Vector2i(2, 1), Vector2i(-1, 1)), T.QUINA_DE_DENTRO, "encontro da barra com a haste")
	afirmar_igual(arbustos.tipo_do_quarto(Vector2i(2, 2), Vector2i(-1, -1)), T.BORDA_VERTICAL, "haste tem borda dos lados")
	afirmar_igual(arbustos.tipo_do_quarto(Vector2i(2, 3), Vector2i(1, 1)), T.QUINA_DE_FORA, "fim da haste")
	labirinto.free()


func teste_miolo_quando_cercado() -> void:
	var labirinto: TileMapLayer = _labirinto_de(PackedStringArray(["###", "###", "###"]))
	var arbustos := ArbustosDoLabirinto.new()
	labirinto.add_child(arbustos)
	arbustos.vestir(labirinto)
	for quarto: Vector2i in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		afirmar_igual(arbustos.tipo_do_quarto(Vector2i(1, 1), quarto), ArbustosDoLabirinto.Tipo.MIOLO,
			"celula do meio, quarto %s" % quarto)
	# Fora do mapa conta como chao: a borda de fora ganha contorno.
	afirmar_igual(arbustos.tipo_do_quarto(Vector2i(0, 0), Vector2i(-1, -1)),
		ArbustosDoLabirinto.Tipo.QUINA_DE_FORA, "canto do mapa")
	labirinto.free()


func teste_fase_veste_o_labirinto_sem_mudar_as_paredes() -> void:
	Telemetria.reiniciar(TransporteMock.new(caminho_temporario("arbustos.jsonl")),
		caminho_temporario("arbustos_fila.json"))
	Sessao.iniciar()
	var lido: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_texto(
		JSON.stringify(CarregadorFaseJson._exemplo()))
	var fase: FaseBase = IniciadorDeFase.jogar(get_tree(), lido.config)
	await get_tree().process_frame
	var arbustos: ArbustosDoLabirinto = fase.labirinto.get_node_or_null("Arbustos") as ArbustosDoLabirinto
	if afirmar_nao_nulo(arbustos, "a fase ganha a camada de grama e arbustos"):
		var solidas: int = 0
		for celula: Vector2i in fase.labirinto.get_used_cells():
			var dado: TileData = fase.labirinto.get_cell_tile_data(celula)
			var solida: bool = dado != null and bool(dado.get_custom_data("solido"))
			if solida:
				solidas += 1
			if solida != arbustos.e_parede(celula):
				falhar("celula %s: arbusto e parede divergem" % celula)
				break
		afirmar_verdadeiro(solidas > 0, "o labirinto tem paredes")
		afirmar_igual(fase.labirinto.self_modulate.a, 0.0, "tile de placeholder escondido")
		afirmar_verdadeiro(fase.labirinto.collision_enabled, "colisao continua ligada")
	fase.queue_free()
	Sessao.encerrar()
	await get_tree().process_frame
