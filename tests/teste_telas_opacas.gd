extends CasoDeTeste

## Nenhum PAINEL de conteudo pode ser transparente -- foi um bug historico
## deste projeto (ver docs/conformidade-monografia.md) e o jeito de garantir
## que ele nao volta e testar, nao so olhar a cena no editor.
##
## Varre cada cena instanciada por inteiro (e nao caminhos fixos de no): assim
## o teste continua valendo mesmo que a arvore interna de uma tela mude, o que
## e exatamente o que acabou de acontecer no editor com as abas.

## Vidro fosco (ADR 0023): o unico jeito aceito de um painel deixar o fundo
## aparecer. O shader desfoca o que esta atras e devolve pixel opaco, entao o
## texto fica sobre uma superficie lisa, sem estrela nem arvore nitida passando
## por tras das letras. A equipe pediu o vidro literalmente transparente (sem
## tinta); o texto solto nele e branco e sem contorno (ADR 0032).
const SHADER_VIDRO: String = "res://recursos/shaders/vidro_fosco.gdshader"

## Telas de pagina inteira: o ColorRect de fundo E a tela, tem que ser opaco.
const TELAS_DE_PAGINA: PackedStringArray = [
	"res://cenas/ui/menu_principal.tscn",
	"res://cenas/ui/selecao_de_fases.tscn",
	"res://cenas/ui/editor_de_fase.tscn",
	"res://cenas/ui/dashboard_telemetria.tscn",
]

## Overlays de jogo: aparecem por cima do labirinto ainda rodando. O ColorRect
## de fundo E UM VEU translucido de proposito (o jogador continua vendo o
## labirinto atras, so mais escuro) -- so o painel de conteudo, esse sim, tem
## que ser opaco para o texto ficar legivel.
const OVERLAYS_DE_JOGO: PackedStringArray = [
	"res://cenas/ui/tela_captura.tscn",
	"res://cenas/base/caixa_puzzle.tscn",
	"res://cenas/base/painel_cifra.tscn",
	"res://cenas/base/terminal.tscn",
]


func teste_paineis_de_pagina_inteira_sao_opacos() -> void:
	await _conferir_paineis(TELAS_DE_PAGINA, true)


func teste_paineis_de_overlay_sao_opacos_com_veu_translucido() -> void:
	await _conferir_paineis(OVERLAYS_DE_JOGO, false)


func _conferir_paineis(cenas: PackedStringArray, exigir_fundo_opaco: bool) -> void:
	for caminho: String in cenas:
		var raiz: Node = load(caminho).instantiate()
		add_child(raiz)
		await get_tree().process_frame

		for no: Node in _descendentes(raiz):
			if no is ColorRect and exigir_fundo_opaco:
				afirmar_igual((no as ColorRect).color.a, 1.0,
					"%s: ColorRect '%s' opaco" % [caminho, no.name])
			elif no is PanelContainer:
				var estilo: StyleBox = (no as PanelContainer).get_theme_stylebox("panel")
				if not estilo is StyleBoxFlat:
					continue
				var alfa: float = (estilo as StyleBoxFlat).bg_color.a
				if _e_vidro_fosco(no as CanvasItem):
					_conferir_textos_brancos(caminho, no)
				else:
					afirmar_igual(alfa, 1.0, "%s: painel '%s' opaco" % [caminho, no.name])

		raiz.queue_free()
		await get_tree().process_frame


func _e_vidro_fosco(no: CanvasItem) -> bool:
	var material: ShaderMaterial = no.material as ShaderMaterial
	return material != null and material.shader != null and material.shader.resource_path == SHADER_VIDRO


func teste_cartao_do_menu_e_vidro_fosco() -> void:
	var menu: Node = (load("res://cenas/ui/menu_principal.tscn") as PackedScene).instantiate()
	add_child(menu)
	await get_tree().process_frame
	var cartao: PanelContainer = menu.get_node("Cartao") as PanelContainer
	afirmar_verdadeiro(_e_vidro_fosco(cartao), "cartao do menu usa o vidro fosco")
	var alfa: float = (cartao.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a
	afirmar_igual(alfa, 0.0, "vidro sem tinta: so o desfoque")
	var estilo: StyleBoxFlat = cartao.get_theme_stylebox("panel") as StyleBoxFlat
	afirmar_igual(estilo.border_width_top + estilo.border_width_left + estilo.border_width_right
		+ estilo.border_width_bottom, 0, "sem contorno: a borda e a moldura de vinhas (ADR 0031)")
	# Botoes do menu na moldura verde com flores, esticavel (ADR 0027).
	var botao: Button = menu.get_node("Cartao/Coluna/Botoes/EscolherFase") as Button
	var moldura: StyleBoxTexture = botao.get_theme_stylebox("normal") as StyleBoxTexture
	if afirmar_nao_nulo(moldura, "botao usa a moldura desenhada"):
		afirmar_verdadeiro(moldura.texture.resource_path.begins_with("res://recursos/arte/balao_botao"),
			"a moldura de flores (no tom do fundo escolhido, ADR 0033)")
		var margens: float = moldura.texture_margin_top + moldura.texture_margin_bottom
		afirmar_verdadeiro(botao.get_combined_minimum_size().y >= margens,
			"o botao e alto o bastante para as flores dos cantos nao se sobreporem")
	# Texto do menu branco e sem contorno (ADR 0032).
	afirmar_igual(botao.get_theme_color("font_color"), Color.WHITE, "texto do botao branco")
	afirmar_igual(botao.get_theme_constant("outline_size"), 0, "texto do botao sem contorno")
	menu.queue_free()
	await get_tree().process_frame


## Texto direto sobre o vidro (Label, ou Button sem fundo): branco e sem
## contorno, como a equipe pediu (ADR 0032). Dicas e rodapes usam o branco
## suave (ADR 0034): o mesmo branco, so um pouco apagado, nunca cinza ou verde.
func _conferir_textos_brancos(caminho: String, vidro: Node) -> void:
	for no: Node in _descendentes(vidro):
		var solto: bool = no is Label or (no is Button and (no as Button).flat)
		if solto and (no as Control).is_visible_in_tree():
			var cor: Color = (no as Control).get_theme_color("font_color")
			afirmar_verdadeiro(cor.r == 1.0 and cor.g == 1.0 and cor.b == 1.0 and cor.a >= 0.75,
				"%s: texto '%s' sobre o vidro e branco (%s)" % [caminho, no.name, cor])
			afirmar_igual((no as Control).get_theme_constant("outline_size"), 0,
				"%s: texto '%s' sobre o vidro nao tem contorno" % [caminho, no.name])


func _descendentes(no: Node) -> Array[Node]:
	var lista: Array[Node] = []
	for filho: Node in no.get_children():
		lista.append(filho)
		lista.append_array(_descendentes(filho))
	return lista
