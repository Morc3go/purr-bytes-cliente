extends CasoDeTeste

## Labirinto do tamanho da tela sem distorcer a pixel art (ADR 0024).
##
## O que protege: (a) o zoom escolhido sempre cabe na area util, (b) nas
## janelas comuns (1280x720, 1920x1080) cada pixel de arte vira um numero
## INTEIRO de pixels do monitor e (c) a fase de fato aplica isso na camera.

const AREA: Vector2 = Vector2(640, 320)  # tela base menos HUD e dica
const LABIRINTO_PADRAO: Vector2 = Vector2(39 * 16, 19 * 16)


func teste_labirinto_padrao_fica_em_zoom_1_e_nitido() -> void:
	for escala: float in [2.0, 3.0, 4.0]:
		var zoom: float = Enquadramento.zoom_para_caber(AREA, LABIRINTO_PADRAO, escala, 2.0)
		afirmar_proximo(zoom, 1.0, 0.0001, "39x19 numa janela %sx: zoom 1" % escala)


func teste_labirinto_pequeno_aproxima_com_pixel_inteiro() -> void:
	var pequeno: Vector2 = Vector2(21 * 16, 15 * 16)  # 336x240
	var zoom: float = Enquadramento.zoom_para_caber(AREA, pequeno, 3.0, 2.0)
	afirmar_proximo(zoom, 4.0 / 3.0, 0.0001, "1920x1080: 4 pixels do monitor por pixel de arte")
	afirmar_verdadeiro(pequeno.y * zoom <= AREA.y + 0.01, "e cabe na altura")
	# Em 1280x720 o pixel inteiro mais perto (zoom 1) perderia 25% do tamanho:
	# a regra prefere encher a tela.
	var em_720: float = Enquadramento.zoom_para_caber(AREA, pequeno, 2.0, 2.0)
	afirmar_proximo(pequeno.y * em_720, AREA.y, 0.01, "1280x720: enche a altura")


func teste_zoom_nunca_passa_do_teto_nem_da_area() -> void:
	for escala: float in [1.0, 1.5, 2.0, 2.13, 2.8, 3.0]:
		for tiles: Vector2i in [Vector2i(9, 9), Vector2i(21, 15), Vector2i(31, 17), Vector2i(39, 19)]:
			var mundo: Vector2 = Vector2(tiles * 16)
			var zoom: float = Enquadramento.zoom_para_caber(AREA, mundo, escala, 2.0)
			afirmar_verdadeiro(zoom <= 2.0 + 0.0001, "teto de zoom (%s, %s)" % [tiles, escala])
			afirmar_verdadeiro(mundo.x * zoom <= AREA.x + 0.01 and mundo.y * zoom <= AREA.y + 0.01,
				"%s cabe na janela %sx" % [tiles, escala])


func teste_janela_quebrada_nao_encolhe_pela_metade() -> void:
	# Janela maximizada com barra de tarefas (~2.8x): o pixel inteiro mais
	# perto seria 2, que encolheria o labirinto para 71%. Fica o zoom exato.
	var zoom: float = Enquadramento.zoom_para_caber(AREA, LABIRINTO_PADRAO, 2.8, 2.0)
	afirmar_verdadeiro(zoom > 0.95, "labirinto continua enchendo a tela (%.3f)" % zoom)


func teste_mapa_grande_demais_faz_a_camera_seguir() -> void:
	afirmar_verdadeiro(Enquadramento.cabe(AREA, LABIRINTO_PADRAO), "39x19 aparece inteiro")
	afirmar_falso(Enquadramento.cabe(AREA, Vector2(41 * 16, 31 * 16)), "41x31 nao cabe: camera segue o gato")


func teste_fase_aplica_o_zoom_e_centraliza() -> void:
	Telemetria.reiniciar(TransporteMock.new(caminho_temporario("enquadramento.jsonl")),
		caminho_temporario("enquadramento_fila.json"))
	Sessao.iniciar()
	var dados: Dictionary = CarregadorFaseJson._exemplo()
	var lido: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_texto(JSON.stringify(dados))
	var fase: FaseBase = IniciadorDeFase.jogar(get_tree(), lido.config)
	await get_tree().process_frame
	var regiao: Rect2i = fase.labirinto.get_used_rect()
	afirmar_igual(regiao.size, Vector2i(39, 19), "exemplo novo ja nasce do tamanho da tela")
	var camera: Camera2D = fase.camera
	afirmar_verdadeiro(camera.zoom.x >= 0.9, "camera nao afasta o mapa padrao")
	var centro: Vector2 = fase.labirinto.to_global(Vector2((regiao.position + regiao.size / 2) * 16))
	afirmar_verdadeiro(camera.global_position.distance_to(centro) <= 16.0, "camera no meio do labirinto")
	fase.queue_free()
	Sessao.encerrar()
	await get_tree().process_frame
