extends CasoDeTeste

## Cenarios do labirinto (ADR 0035): a mesma fase com outra roupa. O que se
## protege aqui:
##   - cenario e so aparencia: parede, colisao e A* nao mudam;
##   - os enfeites nunca ficam em cima da cerca nem perto da entrada, da saida,
##     dos pacotes e dos cachorros, e cabem dentro da propria celula;
##   - o boneco de neve so vai em beco sem saida;
##   - o cenario viaja no JSON da fase, e nome desconhecido e erro claro;
##   - a trilha de demonstracao tem um cenario por fase, e quem ja a instalou
##     ganha os cenarios sem perder o que escolheu.

var _fase: FaseBase = null


func antes() -> void:
	Telemetria.reiniciar(TransporteMock.new(caminho_temporario("cenarios.jsonl")),
		caminho_temporario("cenarios_fila.json"))


func depois() -> void:
	get_tree().paused = false
	if _fase != null and is_instance_valid(_fase):
		_fase.free()
	_fase = null
	if Sessao.ativa:
		Sessao.encerrar()
	await get_tree().process_frame


func _config_demo(cenario: String) -> FaseConfig:
	var caminho: String = CarregadorFaseJson.PASTA_DAS_FASES_DEMO.path_join("01-cesar-o-primeiro-segredo.json")
	var config: FaseConfig = CarregadorFaseJson.de_arquivo(caminho).config
	config.cenario = cenario
	return config


func _montar(cenario: String) -> FaseBase:
	if _fase != null and is_instance_valid(_fase):
		_fase.free()
	Sessao.iniciar()
	_fase = ApoioFaseDeTeste.instanciar(_config_demo(cenario))
	add_child(_fase)
	return _fase


func _arbustos(fase: FaseBase) -> ArbustosDoLabirinto:
	return fase.labirinto.get_node("Arbustos") as ArbustosDoLabirinto


func teste_cada_cenario_tem_sua_arte() -> void:
	afirmar_igual(CenarioDoLabirinto.ORDEM.size(), 8, "jardim e os sete cenarios novos")
	afirmar_igual(CenarioDoLabirinto.ORDEM[0], CenarioDoLabirinto.PADRAO, "o jardim continua sendo o padrao")
	var pecas: Vector2 = CenarioDoLabirinto.textura_do_muro("jardim").get_size()
	for cenario: String in CenarioDoLabirinto.ORDEM:
		afirmar_falso(CenarioDoLabirinto.nome(cenario).is_empty(), "%s: tem nome para o editor" % cenario)
		var chao: Texture2D = CenarioDoLabirinto.textura_do_chao(cenario)
		if afirmar_nao_nulo(chao, "%s: chao" % cenario):
			afirmar_igual(chao.get_size(), Vector2(64, 64), "%s: chao de 64x64, em ladrilho" % cenario)
		var muro: Texture2D = CenarioDoLabirinto.textura_do_muro(cenario)
		if afirmar_nao_nulo(muro, "%s: cerca" % cenario):
			if CenarioDoLabirinto.muro_de_agua(cenario):
				afirmar_igual(muro.get_size(), Vector2(32, 32), "%s: ladrilho de agua" % cenario)
			else:
				afirmar_igual(muro.get_size(), pecas, "%s: mesmo arranjo de pecas do jardim" % cenario)
		var dados: Dictionary = CenarioDoLabirinto.dados(cenario)
		for lista: String in ["no_chao", "nos_becos", "na_agua"]:
			for enfeite: Variant in dados.get(lista, []):
				var textura: Texture2D = CenarioDoLabirinto.textura_do_enfeite(cenario, String(enfeite))
				if afirmar_nao_nulo(textura, "%s: enfeite %s" % [cenario, enfeite]):
					afirmar_verdadeiro(textura.get_width() <= 16 and textura.get_height() <= 16,
						"%s: %s cabe numa celula (%s)" % [cenario, enfeite, textura.get_size()])


## Nada verde nos cenarios que nao sao verdes (pedido da equipe): os enfeites
## do inverno, da cerejeira, das ruinas, do bosque e da lavanda nao tem pixel
## de grama.
func teste_enfeites_na_cor_do_cenario() -> void:
	for cenario: String in ["cerejeira", "inverno", "ruinas", "bosque", "lavanda", "outono"]:
		for enfeite: Variant in CenarioDoLabirinto.dados(cenario).get("no_chao", []) \
				+ CenarioDoLabirinto.dados(cenario).get("nos_becos", []):
			var imagem: Image = CenarioDoLabirinto.textura_do_enfeite(cenario, String(enfeite)).get_image()
			var verdes: int = 0
			for y: int in imagem.get_height():
				for x: int in imagem.get_width():
					var cor: Color = imagem.get_pixel(x, y)
					if cor.a > 0.5 and cor.s > 0.15 and cor.h * 360.0 > 55.0 and cor.h * 360.0 < 175.0:
						verdes += 1
			afirmar_igual(verdes, 0, "%s: %s sem verde" % [cenario, enfeite])


func teste_cenario_nao_muda_parede_nem_caminho() -> void:
	var jardim: FaseBase = _montar("jardim")
	await get_tree().process_frame
	var paredes: Array[Vector2i] = []
	for celula: Vector2i in jardim.labirinto.get_used_cells():
		if bool(jardim.labirinto.get_cell_tile_data(celula).get_custom_data("solido")):
			paredes.append(celula)
	paredes.sort()
	for cenario: String in CenarioDoLabirinto.ORDEM:
		var fase: FaseBase = _montar(cenario)
		await get_tree().process_frame
		var outras: Array[Vector2i] = []
		for celula: Vector2i in fase.labirinto.get_used_cells():
			if bool(fase.labirinto.get_cell_tile_data(celula).get_custom_data("solido")):
				outras.append(celula)
		outras.sort()
		afirmar_igual(outras, paredes, "%s: as mesmas paredes (colisao e A* iguais)" % cenario)
		afirmar_igual(_arbustos(fase).cenario(), cenario, "%s: a roupa e a do cenario pedido" % cenario)


func teste_enfeites_fora_da_cerca_e_longe_do_que_importa() -> void:
	for cenario: String in CenarioDoLabirinto.ORDEM:
		var fase: FaseBase = _montar(cenario)
		await get_tree().process_frame
		var arbustos: ArbustosDoLabirinto = _arbustos(fase)
		var ocupadas: Array[Vector2i] = fase.celulas_ocupadas()
		var tamanho := Vector2(fase.labirinto.tile_set.tile_size)
		var dados: Dictionary = CenarioDoLabirinto.dados(cenario)
		var na_agua: Array = dados.get("na_agua", [])
		var nos_becos: Array = dados.get("nos_becos", [])
		var enfeites: Array[Dictionary] = arbustos.enfeites()
		if cenario == "jardim":
			afirmar_tamanho(enfeites, 0, "o jardim fica como sempre foi, sem enfeite")
			afirmar_tamanho(arbustos.pontinhos(), 0, "e sem pontinhos")
			continue
		afirmar_verdadeiro(enfeites.size() > 0, "%s: tem enfeites" % cenario)
		var limite: int = int(dados.get("quantos_no_chao", 0)) + int(dados.get("quantos_nos_becos", 0)) \
			+ int(dados.get("quantos_na_agua", 0))
		afirmar_verdadeiro(enfeites.size() <= limite, "%s: poucos enfeites (%d)" % [cenario, enfeites.size()])
		for enfeite: Dictionary in enfeites:
			var celula: Vector2i = enfeite["celula"]
			var nome: String = enfeite["nome"]
			var celula_rect := Rect2(Vector2(celula) * tamanho, tamanho)
			afirmar_verdadeiro(celula_rect.encloses(ArbustosDoLabirinto.area_do_enfeite(enfeite)),
				"%s: %s cabe dentro da propria celula" % [cenario, nome])
			if na_agua.has(nome):
				afirmar_verdadeiro(arbustos.e_parede(celula), "%s: %s fica na agua" % [cenario, nome])
				continue
			afirmar_falso(arbustos.e_parede(celula), "%s: %s nao fica em cima da cerca" % [cenario, nome])
			for ocupada: Vector2i in ocupadas:
				afirmar_verdadeiro(absi(ocupada.x - celula.x) + absi(ocupada.y - celula.y) > 1,
					"%s: %s longe da entrada, da saida, dos pacotes e dos cachorros" % [cenario, nome])
			if nos_becos.has(nome):
				afirmar_verdadeiro(arbustos.e_beco(celula), "%s: %s so em beco sem saida" % [cenario, nome])


func teste_mesma_fase_mesmos_enfeites() -> void:
	var primeira: Array[Dictionary] = _arbustos(_montar("outono")).enfeites()
	await get_tree().process_frame
	var segunda: Array[Dictionary] = _arbustos(_montar("outono")).enfeites()
	var celulas_a: Array = primeira.map(func(e: Dictionary) -> Vector2i: return e["celula"])
	var celulas_b: Array = segunda.map(func(e: Dictionary) -> Vector2i: return e["celula"])
	afirmar_igual(celulas_a, celulas_b, "a semente do mapa decide onde os enfeites caem")


func teste_inverno_tem_dois_bonecos_de_neve() -> void:
	var fase: FaseBase = _montar("inverno")
	await get_tree().process_frame
	var bonecos: int = 0
	for enfeite: Dictionary in _arbustos(fase).enfeites():
		if String(enfeite["nome"]) == "boneco_de_neve":
			bonecos += 1
	afirmar_igual(bonecos, 2, "dois bonequinhos de neve, no lugar das arvores")


func teste_cenario_no_json() -> void:
	for cenario: String in CenarioDoLabirinto.ORDEM:
		var config: FaseConfig = _config_demo(cenario)
		var relido: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_texto(
			JSON.stringify(CarregadorFaseJson.para_dicionario(config)))
		if afirmar_verdadeiro(relido.ok(), "%s: ida e volta pelo JSON" % cenario):
			afirmar_igual(relido.config.cenario, cenario, "%s: o cenario volta igual" % cenario)

	var dados: Dictionary = CarregadorFaseJson.para_dicionario(_config_demo("outono"))
	dados.erase("cenario")
	var sem_campo: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_texto(JSON.stringify(dados))
	afirmar_igual(sem_campo.config.cenario, "jardim", "fase antiga, sem o campo: o jardim de sempre")

	dados["cenario"] = "Lago"
	afirmar_igual(CarregadorFaseJson.de_texto(JSON.stringify(dados)).config.cenario, "lago",
		"maiusculas nao atrapalham")

	dados["cenario"] = "vulcao"
	var errado: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_texto(JSON.stringify(dados))
	afirmar_falso(errado.ok(), "cenario que o jogo nao tem e recusado")
	afirmar_verdadeiro(errado.mensagem().contains("vulcao"), "e o erro diz qual: %s" % errado.mensagem())


func teste_trilha_de_demonstracao_com_um_cenario_por_fase() -> void:
	var vistos: Dictionary = {}
	for nome: String in DirAccess.get_files_at(CarregadorFaseJson.PASTA_DAS_FASES_DEMO):
		if nome.get_extension() != "json":
			continue
		var config: FaseConfig = CarregadorFaseJson.de_arquivo(
			CarregadorFaseJson.PASTA_DAS_FASES_DEMO.path_join(nome)).config
		afirmar_diferente(config.cenario, "jardim", "%s: ganhou um cenario" % nome)
		afirmar_falso(vistos.has(config.cenario), "%s: cenario diferente das outras" % nome)
		vistos[config.cenario] = true
	afirmar_igual(vistos.size(), 5, "cinco fases, cinco cenarios")


## Quem instalou a trilha antes dos cenarios (versao 2) ganha o cenario de cada
## fase; se o professor ja escolheu outro, o dele fica.
func teste_trilha_antiga_ganha_cenario_sem_perder_escolha() -> void:
	var pasta_original: String = CarregadorFaseJson.pasta_das_fases
	CarregadorFaseJson.pasta_das_fases = caminho_temporario("fases_cenarios")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CarregadorFaseJson.pasta_das_fases))
	for nome: String in DirAccess.get_files_at(CarregadorFaseJson.pasta_das_fases):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CarregadorFaseJson.pasta_das_fases.path_join(nome)))

	var origem: String = CarregadorFaseJson.PASTA_DAS_FASES_DEMO
	var antiga: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		origem.path_join("01-cesar-o-primeiro-segredo.json"))) as Dictionary
	antiga.erase("cenario")
	var escolhida: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		origem.path_join("02-vigenere-a-chave-que-muda.json"))) as Dictionary
	escolhida["cenario"] = "ruinas"
	_gravar("01-cesar-o-primeiro-segredo.json", antiga)
	_gravar("02-vigenere-a-chave-que-muda.json", escolhida)
	var marca: FileAccess = FileAccess.open(CarregadorFaseJson.pasta_das_fases.path_join(".fases_demo"), FileAccess.WRITE)
	marca.store_string("2")
	marca.close()

	CarregadorFaseJson.semear_fases_demo()

	var cesar: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		CarregadorFaseJson.pasta_das_fases.path_join("01-cesar-o-primeiro-segredo.json"))) as Dictionary
	var vigenere: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		CarregadorFaseJson.pasta_das_fases.path_join("02-vigenere-a-chave-que-muda.json"))) as Dictionary
	afirmar_igual(String(cesar.get("cenario", "")), "outono", "a fase antiga ganhou o cenario da trilha")
	afirmar_igual(String(vigenere.get("cenario", "")), "ruinas", "a escolha do professor ficou")
	afirmar_falso(FileAccess.file_exists(CarregadorFaseJson.pasta_das_fases.path_join(
		"03-sha256-o-pacote-foi-alterado.json")), "demo excluida pelo professor nao volta")
	CarregadorFaseJson.pasta_das_fases = pasta_original


func _gravar(nome: String, dados: Dictionary) -> void:
	var arquivo: FileAccess = FileAccess.open(CarregadorFaseJson.pasta_das_fases.path_join(nome), FileAccess.WRITE)
	arquivo.store_string(JSON.stringify(dados, "\t"))
	arquivo.close()


func teste_editor_escolhe_o_cenario() -> void:
	var editor: Control = (load("res://cenas/ui/editor_de_fase.tscn") as PackedScene).instantiate() as Control
	add_child(editor)
	await get_tree().process_frame
	afirmar_igual(editor.call("cenario_escolhido"), "jardim", "fase nova comeca no jardim")
	editor.call("selecionar_cenario", "lavanda")
	var dados: Dictionary = editor.call("montar_dicionario")
	afirmar_igual(String(dados.get("cenario", "")), "lavanda", "o cenario escolhido vai para o arquivo")
	editor.free()
	await get_tree().process_frame


## Em volta do labirinto o cenario continua (ADR 0038): a faixa de fora vira
## cerca (ou agua no lago) ate a borda da tela, sem tocar na colisao.
func teste_cenario_continua_ate_a_borda_da_tela() -> void:
	for cenario: String in ["jardim", "inverno", "lago"]:
		var fase: FaseBase = _montar(cenario)
		await get_tree().process_frame
		var arbustos: ArbustosDoLabirinto = _arbustos(fase)
		var regiao: Rect2i = fase.labirinto.get_used_rect()
		var fora: Array[Vector2i] = arbustos.celulas_de_fora()
		var faixa: Rect2i = regiao.grow(ArbustosDoLabirinto.MARGEM_EXTERNA)
		afirmar_igual(fora.size(), faixa.get_area() - regiao.get_area(), "%s: a faixa inteira em volta do mapa" % cenario)
		for celula: Vector2i in [faixa.position, faixa.end - Vector2i.ONE, regiao.position - Vector2i.ONE]:
			afirmar_verdadeiro(fora.has(celula), "%s: %s e cenario, nao fundo" % [cenario, celula])
		afirmar_falso(arbustos.e_parede(regiao.position - Vector2i.ONE),
			"%s: fora do mapa continua sem colisao" % cenario)
		# A tela inteira fica coberta: os cantos da tela caem dentro da faixa.
		var tela: Rect2 = fase.get_viewport().get_visible_rect()
		var mundo: Transform2D = fase.get_viewport().get_canvas_transform().affine_inverse()
		for canto: Vector2 in [tela.position, tela.end]:
			var celula: Vector2i = fase.labirinto.local_to_map(fase.labirinto.to_local(mundo * canto))
			afirmar_verdadeiro(faixa.has_point(celula), "%s: canto da tela %s coberto" % [cenario, canto])
