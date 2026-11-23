extends CasoDeTeste

## O gato nunca nasce num beco de uma saida so (ADR 0041): a entrada esta sempre
## num ciclo, entao da para dar a volta no cachorro que vem pelo corredor.

const MEDIDAS: Array[Vector2i] = [Vector2i(9, 9), Vector2i(21, 15), Vector2i(39, 19), Vector2i(41, 31)]


func _grade(mapa: MapaConfig) -> Array:
	var grade: Array = []
	for linha: String in mapa.linhas:
		var celulas: Array = []
		for letra: String in linha:
			celulas.append(letra)
		grade.append(celulas)
	return grade


func _entrada(grade: Array) -> Vector2i:
	for y: int in grade.size():
		for x: int in (grade[y] as Array).size():
			if grade[y][x] == MapaConfig.JOGADOR:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func teste_toda_entrada_gerada_tem_rota_de_fuga() -> void:
	var presas: Array[String] = []
	for medida: Vector2i in MEDIDAS:
		for semente: int in range(1, 151):
			var gerado: GeradorDeMapa.Resultado = GeradorDeMapa.gerar(medida.x, medida.y, semente, 3, 2)
			if not gerado.ok():
				continue
			var grade: Array = _grade(gerado.mapa)
			if not GeradorDeMapa.entrada_tem_fuga(grade, _entrada(grade)):
				presas.append("%dx%d semente %d" % [medida.x, medida.y, semente])
	afirmar_igual(presas, [] as Array[String], "nenhum mapa com o gato preso na entrada")


func teste_fases_demo_tem_rota_de_fuga() -> void:
	for arquivo: String in DirAccess.get_files_at("res://recursos/fases_demo"):
		if not arquivo.ends_with(".json"):
			continue
		var texto: String = FileAccess.get_file_as_string("res://recursos/fases_demo".path_join(arquivo))
		var lido: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_texto(texto)
		if not afirmar_verdadeiro(lido.ok(), "%s carrega" % arquivo):
			continue
		var grade: Array = _grade(lido.config.mapa)
		afirmar_verdadeiro(GeradorDeMapa.entrada_tem_fuga(grade, _entrada(grade)), "%s: entrada com rota de fuga" % arquivo)


func teste_reconhece_beco_e_ciclo() -> void:
	# Beco: a entrada so sai para a direita, num corredor sem volta.
	var beco: Array = _grade_de(["#####", "#P..#", "#####"])
	afirmar_falso(GeradorDeMapa.entrada_tem_fuga(beco, Vector2i(1, 1)), "corredor de uma saida so")
	# Ciclo: da para dar a volta no bloco do meio.
	var ciclo: Array = _grade_de(["#####", "#P..#", "#.#.#", "#...#", "#####"])
	afirmar_verdadeiro(GeradorDeMapa.entrada_tem_fuga(ciclo, Vector2i(1, 1)), "volta em torno do bloco")


func _grade_de(linhas: Array[String]) -> Array:
	var grade: Array = []
	for linha: String in linhas:
		var celulas: Array = []
		for letra: String in linha:
			celulas.append(letra)
		grade.append(celulas)
	return grade
