class_name TemaDaGaleria
extends RefCounted

## Tema das telas e paineis do jogo, montado a partir do fundo escolhido na
## galeria do menu (ADR 0034).
##
## Antes cada tela tinha um tema claro proprio (verde-bebe com texto escuro) e
## so o menu tinha o vidro fosco, as vinhas e os baloes de flor. A equipe pediu
## que todas as telas ficassem como o menu e que tudo combinasse com o
## wallpaper. Por isso o tema nao e um .tres fixo: e gerado em codigo para cada
## fundo, a partir de duas cores da paleta (GaleriaDeFundos.tom e .tinta). Assim
## trocar o fundo na galeria troca, de uma vez, os baloes, as listas, as abas,
## as barras de rolagem e os dialogos de todas as telas, sem seis copias de
## tema para manter.
##
## Regras visuais, iguais as do menu:
## - todo texto e branco e sem contorno (ADR 0032);
## - os botoes sao o balao com flores nos cantos, no tom do fundo (ADR 0033);
## - os paineis sao vidro fosco com uma tinta escura do mesmo tom, para o texto
##   branco ler bem mesmo nos fundos claros (o vidro e a moldura de vinhas sao
##   postos por EnfeiteDaGaleria).

const FONTE: FontFile = preload("res://recursos/fontes/silkscreen_regular.woff")
const TAMANHO_DA_FONTE: int = 10

## Nine-patch do balao: as quinas com flores ficam do tamanho desenhado e so o
## miolo estica (as margens da arte sao as de tema_menu_principal.tres; o texto
## tem um pouco mais de folga em cima e embaixo, para o balao ficar da altura
## dos botoes do menu, que tem 28 pixels).
const MARGEM_DA_ARTE_DO_BALAO: Vector4 = Vector4(13, 12, 13, 12)
const MARGEM_DO_TEXTO_DO_BALAO: Vector4 = Vector4(14, 7, 14, 8)

## Raio dos cantos do vidro: o mesmo que MolduraDeVinhas.RAIO_EM_PIXELS
## (7 pixels de arte = 14 pixels da tela base), para as vinhas abracarem a curva.
const RAIO_DO_VIDRO: int = 14

const BRANCO: Color = Color.WHITE
## Texto secundario (dicas, rodapes): branco um pouco apagado, nunca cinza.
const BRANCO_SUAVE: Color = Color(1.0, 1.0, 1.0, 0.78)
## Mensagens de erro, de sucesso e de destaque, em tons claros que leem sobre
## o vidro escuro (os vermelhos e verdes escuros antigos sumiam nele).
const COR_DE_ERRO: Color = Color("ffb4a8")
const COR_DE_SUCESSO: Color = Color("c8f5b8")
const COR_DE_DESTAQUE: Color = Color("ffe39a")
## Contorno de foco do teclado: o creme do menu.
const COR_DO_FOCO: Color = Color(1.0, 0.96, 0.8, 1.0)

static var _cache: Dictionary = {}


## Tema do fundo pedido (ou do fundo atual da galeria). Um por fundo, guardado:
## as telas abrem e fecham o tempo todo e o tema nao muda entre elas.
static func tema(fundo: String = "") -> Theme:
	var escolhido: String = fundo if GaleriaDeFundos.conhece(fundo) else GaleriaDeFundos.atual()
	if not _cache.has(escolhido):
		_cache[escolhido] = _montar(escolhido)
	return _cache[escolhido] as Theme


## Cores derivadas da paleta, para quem desenha por conta propria (grafico do
## dashboard, tampinhas de tecla do HUD, veus dos paineis do jogo).
static func cor_do_tom(fundo: String = "") -> Color:
	return GaleriaDeFundos.tom(_fundo(fundo))


static func cor_da_tinta(fundo: String = "") -> Color:
	return GaleriaDeFundos.tinta(_fundo(fundo))


## Veu escuro por tras de um painel que abre por cima de outra tela ou do
## labirinto: a tinta do fundo, um pouco mais leve que a do vidro.
static func cor_do_veu(fundo: String = "") -> Color:
	var tinta: Color = cor_da_tinta(fundo)
	return Color(tinta.r, tinta.g, tinta.b, 0.45)


## Fundo das caixas de texto e das listas sobre o vidro.
static func cor_do_campo(fundo: String = "") -> Color:
	var tinta: Color = cor_da_tinta(fundo).darkened(0.35)
	return Color(tinta.r, tinta.g, tinta.b, 0.5)


## Mesma familia, opaca: dialogos e menus suspensos sao janelas proprias e nao
## tem vidro por tras.
static func cor_opaca(fundo: String = "") -> Color:
	var tinta: Color = cor_da_tinta(fundo)
	return Color(tinta.r, tinta.g, tinta.b, 1.0).lightened(0.06)


## Linhas e contornos finos: o tom do balao, clareado.
static func cor_da_borda(fundo: String = "") -> Color:
	var clara: Color = cor_do_tom(fundo).lightened(0.35)
	return Color(clara.r, clara.g, clara.b, 0.85)


## Item escolhido numa lista ou aba: o tom do balao, um pouco mais escuro para
## o texto branco continuar legivel nos tons claros (o verde do brejo).
static func cor_do_realce(fundo: String = "") -> Color:
	var realce: Color = cor_do_tom(fundo).darkened(0.15)
	return Color(realce.r, realce.g, realce.b, 0.92)


static func esquecer_cache() -> void:
	_cache.clear()


static func _fundo(fundo: String) -> String:
	return fundo if GaleriaDeFundos.conhece(fundo) else GaleriaDeFundos.atual()


static func _montar(fundo: String) -> Theme:
	var t := Theme.new()
	t.default_font = FONTE
	t.default_font_size = TAMANHO_DA_FONTE

	_botoes(t, fundo)
	_textos(t)
	_paineis(t, fundo)
	_campos(t, fundo)
	_listas(t, fundo)
	_abas(t, fundo)
	_rolagem_e_separadores(t, fundo)
	_janelas(t, fundo)
	_variacoes(t, fundo)
	return t


static func _caixa(fundo_da_caixa: Color, raio: int, borda: int = 0, cor_da_borda_da_caixa: Color = Color.TRANSPARENT,
		margens: Vector4 = Vector4(-1, -1, -1, -1)) -> StyleBoxFlat:
	var caixa := StyleBoxFlat.new()
	caixa.bg_color = fundo_da_caixa
	caixa.set_corner_radius_all(raio)
	caixa.set_border_width_all(borda)
	caixa.border_color = cor_da_borda_da_caixa
	caixa.anti_aliasing = false   # pixel art: canto em degrau, nao borrado
	if margens.x >= 0.0:
		caixa.content_margin_left = margens.x
		caixa.content_margin_top = margens.y
		caixa.content_margin_right = margens.z
		caixa.content_margin_bottom = margens.w
	return caixa


static func _balao(fundo: String, realce: Color, deslocamento: float = 0.0) -> StyleBoxTexture:
	var balao := StyleBoxTexture.new()
	balao.texture = GaleriaDeFundos.textura_do_balao(fundo)
	balao.texture_margin_left = MARGEM_DA_ARTE_DO_BALAO.x
	balao.texture_margin_top = MARGEM_DA_ARTE_DO_BALAO.y
	balao.texture_margin_right = MARGEM_DA_ARTE_DO_BALAO.z
	balao.texture_margin_bottom = MARGEM_DA_ARTE_DO_BALAO.w
	balao.content_margin_left = MARGEM_DO_TEXTO_DO_BALAO.x
	balao.content_margin_top = MARGEM_DO_TEXTO_DO_BALAO.y + deslocamento
	balao.content_margin_right = MARGEM_DO_TEXTO_DO_BALAO.z
	balao.content_margin_bottom = MARGEM_DO_TEXTO_DO_BALAO.w - deslocamento
	balao.modulate_color = realce
	return balao


static func _foco() -> StyleBoxFlat:
	var foco := _caixa(Color.TRANSPARENT, 4, 1, COR_DO_FOCO)
	foco.draw_center = false
	foco.set_expand_margin_all(1.0)
	return foco


## Botoes: o balao com flores, igual ao do menu. Passar o mouse clareia,
## apertar escurece e "afunda" o texto 1 pixel.
static func _botoes(t: Theme, fundo: String) -> void:
	var normal := _balao(fundo, Color.WHITE)
	var hover := _balao(fundo, Color(1.15, 1.15, 1.1, 1.0))
	var apertado := _balao(fundo, Color(0.8, 0.8, 0.8, 1.0), 1.0)
	var desligado := _balao(fundo, Color(0.75, 0.75, 0.75, 0.55))
	for tipo: StringName in [&"Button", &"OptionButton", &"MenuButton"]:
		t.set_stylebox(&"normal", tipo, normal)
		t.set_stylebox(&"hover", tipo, hover)
		t.set_stylebox(&"pressed", tipo, apertado)
		t.set_stylebox(&"hover_pressed", tipo, apertado)
		t.set_stylebox(&"disabled", tipo, desligado)
		t.set_stylebox(&"focus", tipo, _foco())
		for cor: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color",
				&"font_focus_color", &"font_hover_pressed_color"]:
			t.set_color(cor, tipo, BRANCO)
		t.set_color(&"font_disabled_color", tipo, Color(1, 1, 1, 0.55))
		t.set_constant(&"outline_size", tipo, 0)
	# A seta do OptionButton fica dentro do balao, longe das flores do canto.
	for estado: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		var opcao: StyleBoxTexture = t.get_stylebox(estado, &"OptionButton").duplicate() as StyleBoxTexture
		opcao.content_margin_right = 30.0
		t.set_stylebox(estado, &"OptionButton", opcao)
	t.set_color(&"icon_normal_color", &"OptionButton", BRANCO)
	# A seta fica antes das flores do canto direito (13 pixels de quina).
	t.set_constant(&"arrow_margin", &"OptionButton", 16)

	# CheckBox e CheckButton sao Button para o Godot: sem isto herdariam o balao.
	for tipo: StringName in [&"CheckBox", &"CheckButton"]:
		for estado: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
			t.set_stylebox(estado, tipo, StyleBoxEmpty.new())
		t.set_stylebox(&"focus", tipo, _foco())
		for cor: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color",
				&"font_focus_color", &"font_hover_pressed_color"]:
			t.set_color(cor, tipo, BRANCO)
		t.set_color(&"font_disabled_color", tipo, Color(1, 1, 1, 0.55))


static func _textos(t: Theme) -> void:
	t.set_color(&"font_color", &"Label", BRANCO)
	t.set_constant(&"outline_size", &"Label", 0)
	t.set_color(&"font_shadow_color", &"Label", Color.TRANSPARENT)
	t.set_color(&"default_color", &"RichTextLabel", BRANCO)
	t.set_constant(&"outline_size", &"RichTextLabel", 0)
	t.set_color(&"selection_color", &"RichTextLabel", Color(1, 1, 1, 0.25))


## Paineis: a tinta do vidro (o desfoque vem do material, posto por
## EnfeiteDaGaleria). Sem contorno: a borda e a moldura de vinhas.
static func _paineis(t: Theme, fundo: String) -> void:
	var vidro := _caixa(cor_da_tinta(fundo), RAIO_DO_VIDRO, 0, Color.TRANSPARENT, Vector4(14, 12, 14, 12))
	t.set_stylebox(&"panel", &"PanelContainer", vidro)
	t.set_stylebox(&"panel", &"Panel", vidro)


static func _campos(t: Theme, fundo: String) -> void:
	var campo := _caixa(cor_do_campo(fundo), 6, 1, cor_da_borda(fundo), Vector4(6, 3, 6, 3))
	var foco := _caixa(cor_do_campo(fundo), 6, 2, COR_DO_FOCO, Vector4(6, 3, 6, 3))
	var selecao: Color = cor_do_realce(fundo)
	for tipo: StringName in [&"LineEdit", &"TextEdit"]:
		t.set_stylebox(&"normal", tipo, campo)
		t.set_stylebox(&"focus", tipo, foco)
		t.set_stylebox(&"read_only", tipo, campo)
		t.set_color(&"font_color", tipo, BRANCO)
		t.set_color(&"font_readonly_color", tipo, BRANCO_SUAVE)
		t.set_color(&"font_placeholder_color", tipo, Color(1, 1, 1, 0.5))
		t.set_color(&"font_selected_color", tipo, BRANCO)
		t.set_color(&"caret_color", tipo, BRANCO)
		t.set_color(&"selection_color", tipo, selecao)
		t.set_constant(&"outline_size", tipo, 0)
	t.set_color(&"background_color", &"TextEdit", Color.TRANSPARENT)
	t.set_color(&"current_line_color", &"TextEdit", Color(1, 1, 1, 0.06))
	t.set_color(&"clear_button_color", &"LineEdit", BRANCO_SUAVE)


static func _listas(t: Theme, fundo: String) -> void:
	var painel := _caixa(cor_do_campo(fundo), 10, 1, cor_da_borda(fundo), Vector4(4, 4, 4, 4))
	var escolhido := _caixa(cor_do_realce(fundo), 4)
	var tom: Color = cor_do_tom(fundo)
	var sob_o_mouse := _caixa(Color(tom.r, tom.g, tom.b, 0.35), 4)
	var cursor := _caixa(Color.TRANSPARENT, 4, 1, COR_DO_FOCO)
	cursor.draw_center = false
	for tipo: StringName in [&"ItemList", &"Tree"]:
		t.set_stylebox(&"panel", tipo, painel)
		t.set_stylebox(&"focus", tipo, StyleBoxEmpty.new())
		t.set_stylebox(&"selected", tipo, escolhido)
		t.set_stylebox(&"selected_focus", tipo, escolhido)
		t.set_stylebox(&"hovered", tipo, sob_o_mouse)
		t.set_stylebox(&"cursor", tipo, cursor)
		t.set_stylebox(&"cursor_unfocused", tipo, cursor)
		t.set_color(&"font_color", tipo, BRANCO)
		t.set_color(&"font_hovered_color", tipo, BRANCO)
		t.set_color(&"font_selected_color", tipo, BRANCO)
		t.set_color(&"guide_color", tipo, Color(1, 1, 1, 0.12))
		t.set_constant(&"outline_size", tipo, 0)
	t.set_color(&"title_button_color", &"Tree", BRANCO)


static func _abas(t: Theme, fundo: String) -> void:
	var tinta: Color = cor_da_tinta(fundo)
	var tom: Color = cor_do_tom(fundo)
	var margens := Vector4(8, 3, 8, 3)
	var escolhida := _caixa(cor_do_realce(fundo), 0, 0, Color.TRANSPARENT, margens)
	escolhida.corner_radius_top_left = 6
	escolhida.corner_radius_top_right = 6
	var outra := _caixa(Color(tinta.r, tinta.g, tinta.b, 0.6), 0, 0, Color.TRANSPARENT, margens)
	outra.corner_radius_top_left = 6
	outra.corner_radius_top_right = 6
	var sob_o_mouse := _caixa(Color(tom.r, tom.g, tom.b, 0.55), 0, 0, Color.TRANSPARENT, margens)
	sob_o_mouse.corner_radius_top_left = 6
	sob_o_mouse.corner_radius_top_right = 6
	var painel := _caixa(cor_do_campo(fundo), 0, 1, cor_da_borda(fundo), Vector4(4, 4, 4, 4))
	painel.corner_radius_bottom_left = 8
	painel.corner_radius_bottom_right = 8
	painel.corner_radius_top_right = 8
	for tipo: StringName in [&"TabContainer", &"TabBar"]:
		t.set_stylebox(&"tab_selected", tipo, escolhida)
		t.set_stylebox(&"tab_unselected", tipo, outra)
		t.set_stylebox(&"tab_hovered", tipo, sob_o_mouse)
		t.set_stylebox(&"tab_disabled", tipo, outra)
		t.set_stylebox(&"tab_focus", tipo, _foco())
		t.set_color(&"font_selected_color", tipo, BRANCO)
		t.set_color(&"font_unselected_color", tipo, BRANCO_SUAVE)
		t.set_color(&"font_hovered_color", tipo, BRANCO)
		t.set_constant(&"outline_size", tipo, 0)
	t.set_stylebox(&"panel", &"TabContainer", painel)
	t.set_stylebox(&"tabbar_background", &"TabContainer", StyleBoxEmpty.new())


static func _rolagem_e_separadores(t: Theme, fundo: String) -> void:
	var tom: Color = cor_do_tom(fundo)
	var trilho := _caixa(Color(1, 1, 1, 0.12), 3, 0, Color.TRANSPARENT, Vector4(3, 3, 3, 3))
	var pegador := _caixa(tom, 3, 0, Color.TRANSPARENT, Vector4(3, 3, 3, 3))
	var pegador_claro := _caixa(tom.lightened(0.2), 3, 0, Color.TRANSPARENT, Vector4(3, 3, 3, 3))
	var pegador_apertado := _caixa(tom.darkened(0.2), 3, 0, Color.TRANSPARENT, Vector4(3, 3, 3, 3))
	for tipo: StringName in [&"VScrollBar", &"HScrollBar"]:
		t.set_stylebox(&"scroll", tipo, trilho)
		t.set_stylebox(&"scroll_focus", tipo, trilho)
		t.set_stylebox(&"grabber", tipo, pegador)
		t.set_stylebox(&"grabber_highlight", tipo, pegador_claro)
		t.set_stylebox(&"grabber_pressed", tipo, pegador_apertado)

	var linha := StyleBoxLine.new()
	linha.color = Color(1, 1, 1, 0.35)
	linha.thickness = 1
	t.set_stylebox(&"separator", &"HSeparator", linha)
	var linha_vertical: StyleBoxLine = linha.duplicate() as StyleBoxLine
	linha_vertical.vertical = true
	t.set_stylebox(&"separator", &"VSeparator", linha_vertical)


## Dialogos (subir, exportar, confirmar exclusao) e menus suspensos: sao janelas
## e nao enxergam o vidro, entao usam a mesma familia de cor, opaca.
static func _janelas(t: Theme, fundo: String) -> void:
	var opaca: Color = cor_opaca(fundo)
	var borda: Color = cor_do_tom(fundo)
	var moldura := _caixa(opaca, 8, 2, borda)
	moldura.expand_margin_left = 4.0
	moldura.expand_margin_right = 4.0
	moldura.expand_margin_bottom = 4.0
	moldura.expand_margin_top = 22.0
	t.set_stylebox(&"embedded_border", &"Window", moldura)
	t.set_stylebox(&"embedded_unfocused_border", &"Window", moldura)
	t.set_color(&"title_color", &"Window", BRANCO)
	t.set_constant(&"title_height", &"Window", 20)
	t.set_constant(&"title_outline_size", &"Window", 0)
	t.set_font_size(&"title_font_size", &"Window", TAMANHO_DA_FONTE)
	t.set_stylebox(&"panel", &"AcceptDialog", _caixa(opaca, 0, 0, Color.TRANSPARENT, Vector4(8, 8, 8, 8)))

	var suspenso := _caixa(opaca, 6, 1, borda, Vector4(4, 4, 4, 4))
	t.set_stylebox(&"panel", &"PopupMenu", suspenso)
	t.set_stylebox(&"panel", &"PopupPanel", suspenso)
	t.set_stylebox(&"hover", &"PopupMenu", _caixa(cor_do_realce(fundo), 4))
	t.set_color(&"font_color", &"PopupMenu", BRANCO)
	t.set_color(&"font_hover_color", &"PopupMenu", BRANCO)
	t.set_color(&"font_disabled_color", &"PopupMenu", Color(1, 1, 1, 0.5))
	t.set_stylebox(&"panel", &"TooltipPanel", suspenso)
	t.set_color(&"font_color", &"TooltipLabel", BRANCO)


## Variacoes usadas por algumas telas (theme_type_variation).
static func _variacoes(t: Theme, fundo: String) -> void:
	# Texto secundario: dicas, rodapes, subtitulos.
	t.add_type(&"TextoSuave")
	t.set_type_variation(&"TextoSuave", &"Label")
	t.set_color(&"font_color", &"TextoSuave", BRANCO_SUAVE)

	# Cartao de escolha do gatinho: um vidrinho mais escuro; o escolhido fica
	# no tom do balao, com o contorno creme do foco.
	var tom: Color = cor_do_tom(fundo)
	t.add_type(&"CartaoDeGato")
	t.set_type_variation(&"CartaoDeGato", &"Button")
	var parado := _caixa(cor_do_campo(fundo), 10, 1, cor_da_borda(fundo))
	var em_foco := _caixa(Color(tom.r, tom.g, tom.b, 0.6), 10, 2, COR_DO_FOCO)
	t.set_stylebox(&"normal", &"CartaoDeGato", parado)
	t.set_stylebox(&"hover", &"CartaoDeGato", em_foco)
	t.set_stylebox(&"pressed", &"CartaoDeGato", em_foco)
	t.set_stylebox(&"hover_pressed", &"CartaoDeGato", em_foco)
	var contorno := _caixa(Color.TRANSPARENT, 10, 2, COR_DO_FOCO)
	contorno.draw_center = false
	t.set_stylebox(&"focus", &"CartaoDeGato", contorno)

	# Botoes pequenos das linhas do editor (remover, + opcao, tipo do vigia):
	# o mesmo balao, na altura minima que as flores dos cantos permitem (24 px),
	# para as linhas nao ficarem mais altas que os campos de texto.
	# A folga dos lados (14) passa das quinas desenhadas (13): o texto nunca
	# fica embaixo das flores; no OptionButton sobra espaco para a seta tambem.
	var compactos: Dictionary = {&"BotaoCompacto": [&"Button", 14.0], &"OpcaoCompacta": [&"OptionButton", 30.0]}
	for variacao: StringName in compactos:
		var base: StringName = compactos[variacao][0]
		var direita: float = compactos[variacao][1]
		t.add_type(variacao)
		t.set_type_variation(variacao, base)
		for estado: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
			var balao: StyleBoxTexture = t.get_stylebox(estado, &"Button").duplicate() as StyleBoxTexture
			var afunda: float = 1.0 if estado in [&"pressed", &"hover_pressed"] else 0.0
			balao.content_margin_top = 4.0 + afunda
			balao.content_margin_bottom = 5.0 - afunda
			balao.content_margin_left = 14.0
			balao.content_margin_right = direita
			t.set_stylebox(estado, variacao, balao)

	# Tampinha de tecla do rodape do jogo (T, F4, ESC...).
	t.add_type(&"Tecla")
	t.set_type_variation(&"Tecla", &"Label")
	t.set_stylebox(&"normal", &"Tecla", _caixa(cor_do_realce(fundo), 2, 1, Color(1, 1, 1, 0.75),
		Vector4(3, 0, 3, 0)))
