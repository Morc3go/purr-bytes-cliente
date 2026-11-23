extends CasoDeTeste

## Pelagem dos vigias: toda fase mistura husky e pastor (ADR 0022 e 0042).

var _fase: FaseBase = null


func antes() -> void:
	Telemetria.reiniciar(TransporteMock.new(caminho_temporario("pelagem.jsonl")),
		caminho_temporario("pelagem_fila.json"))
	Sessao.iniciar()


func depois() -> void:
	get_tree().paused = false
	if _fase != null and is_instance_valid(_fase):
		_fase.queue_free()
	_fase = null
	if Sessao.ativa:
		Sessao.encerrar()
	await get_tree().process_frame


func _fase_com(cachorros: Array) -> Dictionary:
	var dados: Dictionary = CarregadorFaseJson._exemplo()
	dados["cachorros"] = cachorros
	return dados


func teste_vigias_alternam_husky_e_pastor() -> void:
	afirmar_igual(PelagemCachorro.ORDEM, [PelagemCachorro.HUSKY, PelagemCachorro.PASTOR] as Array[String],
		"as duas pelagens prontas")
	var esperadas: Array[String] = [PelagemCachorro.HUSKY, PelagemCachorro.PASTOR,
		PelagemCachorro.HUSKY, PelagemCachorro.PASTOR]
	for indice: int in esperadas.size():
		afirmar_igual(PelagemCachorro.do_vigia(indice), esperadas[indice], "vigia %d" % (indice + 1))
	afirmar_igual(PelagemCachorro.resolver("caramelo", 0), PelagemCachorro.CARAMELO,
		"o valor antigo do JSON continua guardado pelo editor")


func teste_cada_pelagem_tem_seu_desenho() -> void:
	afirmar_igual(PelagemCachorro.quadros(PelagemCachorro.PASTOR).resource_path,
		"res://recursos/arte/cachorro_pastor_frames.tres", "pastor com a folha dele")
	afirmar_igual(PelagemCachorro.quadros(PelagemCachorro.CARAMELO), PelagemCachorro.quadros(PelagemCachorro.PASTOR),
		"o caramelo antigo (o marrom que faltava) e desenhado como pastor")
	var husky: SpriteFrames = PelagemCachorro.quadros(PelagemCachorro.HUSKY)
	var pastor: SpriteFrames = PelagemCachorro.quadros(PelagemCachorro.PASTOR)
	afirmar_igual(pastor.get_animation_names(), husky.get_animation_names(), "as mesmas animacoes do husky")
	for nome: StringName in husky.get_animation_names():
		afirmar_igual(pastor.get_frame_count(nome), husky.get_frame_count(nome), "%s: mesmo numero de quadros" % nome)
	afirmar_falso(pastor.get_animation_loop(&"parado"), "o pastor tambem senta e fica sentado")


func teste_json_le_grava_e_tolera_valor_estranho() -> void:
	var lido: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_texto(JSON.stringify(_fase_com([
		{"cor": "#ff6b6b", "comando_para_bloquear": "", "pelagem": "Caramelo"},
		{"cor": "#4da3ff", "comando_para_bloquear": "trocar senha", "pelagem": "dalmata"},
	])))
	if not afirmar_verdadeiro(lido.ok(), "fase carrega: %s" % lido.mensagem()):
		return
	afirmar_igual(lido.config.cachorros[0].pelagem, "caramelo", "maiuscula no arquivo nao atrapalha")
	afirmar_igual(lido.config.cachorros[1].pelagem, "", "pelagem desconhecida vira alternancia, sem recusar a fase")
	var relido: Dictionary = CarregadorFaseJson.para_dicionario(lido.config)
	afirmar_igual(String((relido["cachorros"] as Array)[0]["pelagem"]), "caramelo", "e volta igual ao salvar")


func teste_a_fase_mistura_os_dois_cachorros() -> void:
	# A pelagem gravada no JSON nao decide mais o desenho: a fase alterna sempre.
	var lido: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_texto(JSON.stringify(_fase_com([
		{"cor": "#ff6b6b", "comando_para_bloquear": "", "pelagem": "pastor"},
		{"cor": "#4da3ff", "comando_para_bloquear": "trocar senha", "pelagem": "husky"},
		{"cor": "#ffb44d", "comando_para_bloquear": "ativar 2fa", "pelagem": "caramelo"},
	])))
	_fase = IniciadorDeFase.jogar(get_tree(), lido.config)
	await get_tree().process_frame
	var esperadas: Array[String] = [PelagemCachorro.HUSKY, PelagemCachorro.PASTOR, PelagemCachorro.HUSKY]
	for indice: int in esperadas.size():
		var cachorro: Cachorro = _fase.cachorros[indice]
		afirmar_igual(cachorro.pelagem(), esperadas[indice], "vigia %d" % (indice + 1))
		var sprite: AnimatedSprite2D = cachorro.get_node("Sprite") as AnimatedSprite2D
		afirmar_igual(sprite.sprite_frames, PelagemCachorro.quadros(esperadas[indice]), "vigia %d desenhado certo" % (indice + 1))
