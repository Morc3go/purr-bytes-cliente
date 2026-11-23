extends CasoDeTeste

## Os pacotes aparecem como os itens que a equipe desenhou -- novelo, peixe e
## rato --, revezando pela ordem dos pacotes na fase (ADR 0043).

var _fase: FaseBase = null


func antes() -> void:
	Telemetria.reiniciar(TransporteMock.new(caminho_temporario("itens.jsonl")),
		caminho_temporario("itens_fila.json"))
	Sessao.iniciar()


func depois() -> void:
	get_tree().paused = false
	if _fase != null and is_instance_valid(_fase):
		_fase.queue_free()
	_fase = null
	if Sessao.ativa:
		Sessao.encerrar()
	await get_tree().process_frame


func teste_os_tres_itens_cabem_na_celula() -> void:
	afirmar_igual(Pacote.ITENS.size(), 3, "novelo, peixe e rato")
	for textura: Texture2D in Pacote.ITENS:
		afirmar_verdadeiro(textura.get_width() <= 17 and textura.get_height() <= 12,
			"%s no tamanho do jogo" % textura.resource_path.get_file())
	afirmar_verdadeiro(Pacote.ITENS[1].resource_path.ends_with("peixe.png"), "o peixe de olho preto")


func teste_a_fase_reveza_os_itens_e_some_ao_coletar() -> void:
	var texto: String = FileAccess.get_file_as_string("res://recursos/fases_demo/05-avaliacao-final-sem-colinha.json")
	var lido: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_texto(texto)
	if not afirmar_verdadeiro(lido.ok(), "fase carrega"):
		return
	_fase = IniciadorDeFase.jogar(get_tree(), lido.config)
	await get_tree().process_frame
	afirmar_verdadeiro(_fase.pacotes.size() >= 4, "fase com pelo menos 4 pacotes")
	for indice: int in _fase.pacotes.size():
		afirmar_igual(_fase.pacotes[indice].item(), Pacote.ITENS[indice % 3], "pacote %d" % (indice + 1))
	var primeiro: Pacote = _fase.pacotes[0]
	primeiro.coletar()
	afirmar_falso((primeiro.get_node("Item") as Sprite2D).visible, "coletado, o item some")
