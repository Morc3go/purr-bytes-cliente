extends CasoDeTeste

## Porta no labirinto: arco de pedra do tamanho de uma celula (ADR 0035). Os fundos do menu estao em
## teste_galeria_de_fundos.gd (ADR 0033).


func teste_porta_fechada_ate_coletar_tudo_e_aberta_depois() -> void:
	var porta: Porta = (load("res://cenas/base/porta.tscn") as PackedScene).instantiate() as Porta \
		if ResourceLoader.exists("res://cenas/base/porta.tscn") else Porta.new()
	add_child(porta)
	afirmar_igual(porta.textura_atual(), Porta.TEXTURA_FECHADA, "comeca fechada")
	porta.definir_trancada(false)
	afirmar_igual(porta.textura_atual(), Porta.TEXTURA_ABERTA, "abre quando os pacotes acabam")
	afirmar_igual(Porta.TEXTURA_FECHADA.get_size(), Vector2(18, 16), "arco de 18x16: uma celula, proporcional")
	afirmar_igual(Porta.TEXTURA_ABERTA.get_size(), Porta.TEXTURA_FECHADA.get_size(),
		"aberta e fechada do mesmo tamanho: o arco nao pula ao abrir")
	# A aberta e o mesmo arco com a passagem escura no lugar da madeira.
	var fechada: Image = Porta.TEXTURA_FECHADA.get_image()
	var aberta: Image = Porta.TEXTURA_ABERTA.get_image()
	afirmar_igual(aberta.get_pixel(0, 15), fechada.get_pixel(0, 15), "o pe do arco e igual nas duas")
	var meio: Color = aberta.get_pixel(9, 12)
	afirmar_verdadeiro(meio.v < 0.25, "a aberta mostra a passagem escura (%s)" % meio)
	porta.queue_free()
	await get_tree().process_frame
