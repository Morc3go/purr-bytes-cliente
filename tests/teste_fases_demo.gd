extends CasoDeTeste

## Fases de demonstracao que vem com o jogo (ADR 0021).
##
## O que protege: uma fase mostrada para a banca nao pode estar quebrada nem
## ser impossivel. Cada arquivo de recursos/fases_demo precisa (a) passar no
## mesmo validador que o jogo usa, (b) gerar o labirinto pela semente e (c) ter
## TODOS os vigias venciveis pelo terminal -- cifra pelo AFD + parser + cifra
## real, comando livre pela frase de conduta.

var _fase: FaseBase = null
var _tentativas: Array[Dictionary] = []


func antes() -> void:
	Telemetria.reiniciar(TransporteMock.new(caminho_temporario("fases_demo.jsonl")),
		caminho_temporario("fases_demo_fila.json"))
	Sessao.iniciar()
	_tentativas.clear()
	Telemetria.tentativa_registrada.connect(_ao_registrar_tentativa)


func depois() -> void:
	Telemetria.tentativa_registrada.disconnect(_ao_registrar_tentativa)
	get_tree().paused = false
	if _fase != null and is_instance_valid(_fase):
		_fase.queue_free()
	_fase = null
	if Sessao.ativa:
		Sessao.encerrar()
	await get_tree().process_frame


func _ao_registrar_tentativa(tentativa: Dictionary) -> void:
	_tentativas.append(tentativa)


func _arquivos() -> PackedStringArray:
	var caminhos := PackedStringArray()
	for nome: String in DirAccess.get_files_at(CarregadorFaseJson.PASTA_DAS_FASES_DEMO):
		if nome.get_extension() == "json":
			caminhos.append(CarregadorFaseJson.PASTA_DAS_FASES_DEMO.path_join(nome))
	caminhos.sort()
	return caminhos


func teste_ha_uma_trilha_de_cinco_fases() -> void:
	afirmar_tamanho(_arquivos(), 5, "Cesar, Vigenere, SHA-256, golpes e avaliacao final")


func teste_todas_carregam_e_geram_o_labirinto() -> void:
	var ids: Dictionary = {}
	for caminho: String in _arquivos():
		var lido: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_arquivo(caminho)
		if not afirmar_verdadeiro(lido.ok(), "%s carrega: %s" % [caminho.get_file(), lido.mensagem()]):
			continue
		afirmar_nao_nulo(lido.config.mapa, "%s: labirinto gerado" % caminho.get_file())
		afirmar_verdadeiro(lido.config.pacotes.size() >= 3, "%s: ao menos 3 perguntas" % caminho.get_file())
		# id_fase fixo no arquivo: e o que liga a telemetria de maquinas diferentes.
		var bruto: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(caminho)) as Dictionary
		afirmar_igual(lido.config.id_fase, String(bruto["id_fase"]),
			"%s: id_fase do arquivo e respeitado" % caminho.get_file())
		afirmar_falso(ids.has(lido.config.id_fase), "%s: id_fase unico" % caminho.get_file())
		ids[lido.config.id_fase] = true


func teste_a_trilha_cobre_os_tres_algoritmos_e_o_letramento() -> void:
	var algoritmos: Dictionary = {}
	var comandos_livres: int = 0
	var fase_sem_comandos: bool = false
	for caminho: String in _arquivos():
		var config: FaseConfig = CarregadorFaseJson.de_arquivo(caminho).config
		for cachorro: CachorroConfig in config.cachorros:
			if cachorro.bloqueia_por_cifra():
				algoritmos[cachorro.algoritmo_exigido] = true
			elif not cachorro.comando_para_bloquear.is_empty():
				comandos_livres += 1
		if not config.mostrar_comandos:
			fase_sem_comandos = true
	for algoritmo: String in ["CESAR", "VIGENERE", "SHA256"]:
		afirmar_verdadeiro(algoritmos.has(algoritmo), "a trilha exercita %s" % algoritmo)
	afirmar_verdadeiro(comandos_livres >= 3, "ha vigias de conduta (letramento digital)")
	afirmar_verdadeiro(fase_sem_comandos, "ha uma fase de avaliacao sem os comandos na tela")


## O comando que vence cada vigia, como um aluno digitaria.
func _comando_que_vence(cachorro: CachorroConfig) -> String:
	if not cachorro.bloqueia_por_cifra():
		# Maiusculas e espaco a mais de proposito: a conduta vale, nao a digitacao.
		return "  %s " % cachorro.comando_para_bloquear.to_upper()
	if cachorro.algoritmo_exigido == "SHA256":
		return "verificar %s %s" % [cachorro.palavra_da_cifra,
			Sha256.digest_hex(cachorro.palavra_da_cifra).substr(0, 8)]
	return "cifrar %s chave=%s" % [cachorro.palavra_da_cifra, cachorro.chave_da_cifra]


func teste_todo_vigia_com_comando_e_vencivel_pelo_terminal() -> void:
	for caminho: String in _arquivos():
		var lido: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_arquivo(caminho)
		if not lido.ok():
			continue
		_fase = IniciadorDeFase.jogar(get_tree(), lido.config)
		await get_tree().process_frame

		for i: int in _fase.cachorros.size():
			var alvo: Cachorro = _fase.cachorros[i]
			if _fase._apenas_persegue(alvo):
				continue
			_tentativas.clear()
			_fase._ao_submeter_comando(_comando_que_vence(lido.config.cachorros[i]), 1000)
			var rotulo: String = "%s, vigia %d" % [caminho.get_file(), i + 1]
			afirmar_verdadeiro(_fase._protegido_contra(alvo), "%s: o comando certo protege" % rotulo)
			if afirmar_tamanho(_tentativas, 1, "%s: uma tentativa registrada" % rotulo):
				afirmar_igual(_tentativas[0]["resultado"], CatalogoResultados.SUCESSO,
					"%s: resultado SUCESSO" % rotulo)

		_fase.queue_free()
		_fase = null
		await get_tree().process_frame


func teste_semeia_uma_vez_e_nao_ressuscita_fase_excluida() -> void:
	var pasta: String = CarregadorFaseJson.pasta_das_fases
	for nome: String in DirAccess.get_files_at(pasta):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(pasta.path_join(nome)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(pasta.path_join(".fases_demo")))

	CarregadorFaseJson.semear_fases_demo()
	afirmar_tamanho(CarregadorFaseJson.listar(), 5, "as cinco fases sao instaladas")

	var primeira: String = CarregadorFaseJson.listar()[0]
	DirAccess.remove_absolute(ProjectSettings.globalize_path(primeira))
	CarregadorFaseJson.semear_fases_demo()
	afirmar_tamanho(CarregadorFaseJson.listar(), 4,
		"fase demo excluida pelo professor nao volta sozinha")


## ADR 0024: as demos cresceram para o tamanho da tela. Quem ja tinha a trilha
## v1 instalada recebe o mapa novo SO na copia que ninguem redimensionou; a
## fase que o professor mudou de tamanho e a excluida ficam como estao.
func teste_atualizacao_amplia_so_o_mapa_intocado() -> void:
	var pasta: String = CarregadorFaseJson.pasta_das_fases
	for nome: String in DirAccess.get_files_at(pasta):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(pasta.path_join(nome)))
	var originais: PackedStringArray = _arquivos()
	var antigos: Array[Vector2i] = [Vector2i(21, 15), Vector2i(21, 15), Vector2i(21, 15),
		Vector2i(21, 15), Vector2i(25, 17)]
	for i: int in originais.size():
		if i == 0:
			continue  # excluida pelo professor
		var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(originais[i])) as Dictionary
		var mapa: Dictionary = dados["mapa"] as Dictionary
		mapa["largura"] = antigos[i].x
		mapa["altura"] = antigos[i].y
		if i == 1:
			mapa["largura"] = 15  # redimensionada pelo professor
			mapa["altura"] = 11
		dados["briefing"] = "texto do professor %d" % i
		var arquivo: FileAccess = FileAccess.open(pasta.path_join(originais[i].get_file()), FileAccess.WRITE)
		arquivo.store_string(JSON.stringify(dados))
		arquivo.close()
	var marca: FileAccess = FileAccess.open(pasta.path_join(".fases_demo"), FileAccess.WRITE)
	marca.store_string("1")
	marca.close()

	CarregadorFaseJson.semear_fases_demo()

	afirmar_falso(FileAccess.file_exists(pasta.path_join(originais[0].get_file())),
		"a demo excluida continua excluida")
	for i: int in range(1, originais.size()):
		var instalada: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string(pasta.path_join(originais[i].get_file()))) as Dictionary
		var mapa: Dictionary = instalada["mapa"] as Dictionary
		var tamanho := Vector2i(int(mapa["largura"]), int(mapa["altura"]))
		if i == 1:
			afirmar_igual(tamanho, Vector2i(15, 11), "tamanho escolhido pelo professor fica")
		else:
			afirmar_igual(tamanho, Vector2i(CarregadorFaseJson.LARGURA_PADRAO, CarregadorFaseJson.ALTURA_PADRAO),
				"%s cresce para o tamanho da tela" % originais[i].get_file())
		afirmar_igual(String(instalada["briefing"]), "texto do professor %d" % i,
			"o resto do que o professor escreveu nao muda")


func teste_demos_enchem_a_tela_base() -> void:
	# 39x19 tiles de 16 px = 624x304: cabe entre o HUD (20 px) e a dica (20 px)
	# da tela de 640x360 com zoom 1 (ADR 0024).
	for caminho: String in _arquivos():
		var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(caminho)) as Dictionary
		var mapa: Dictionary = dados["mapa"] as Dictionary
		afirmar_igual(Vector2i(int(mapa["largura"]), int(mapa["altura"])), Vector2i(39, 19),
			"%s do tamanho da tela" % caminho.get_file())


## Regressao: a rota do A* (F3) era desenhada no _draw() da propria FaseBase,
## que o Godot pinta ANTES dos filhos -- ficava escondida sob o labirinto.
func teste_rota_do_astar_aparece_por_cima_do_labirinto() -> void:
	var lido: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_arquivo(_arquivos()[0])
	_fase = IniciadorDeFase.jogar(get_tree(), lido.config)
	await get_tree().process_frame
	var camada: Node2D = _fase.get_node_or_null("DepuracaoAStar") as Node2D
	if not afirmar_nao_nulo(camada, "a fase tem a camada da rota do A*"):
		return
	var labirinto: CanvasItem = _fase.get_node("Labirinto") as CanvasItem
	afirmar_verdadeiro(camada.z_index > labirinto.z_index, "a camada fica acima do labirinto")
	afirmar_falso(_fase.rotas_astar_visiveis(), "comeca escondida")
	_fase.alternar_rotas_astar()
	afirmar_verdadeiro(_fase.rotas_astar_visiveis(), "F3 mostra")
	_fase._replanejar_caminho_do_cachorro()
	var com_rota: int = 0
	for alvo: Cachorro in _fase.cachorros:
		if alvo.caminho_atual().size() >= 2:
			com_rota += 1
	afirmar_verdadeiro(com_rota > 0, "e ha rota calculada para desenhar")
