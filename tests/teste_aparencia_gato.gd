extends CasoDeTeste

## Escolha da aparencia do gatinho no menu: tuxedo ou calico (ADR 0021).


func antes() -> void:
	if FileAccess.file_exists(AparenciaGato.caminho):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(AparenciaGato.caminho))


func depois() -> void:
	antes()


func teste_padrao_e_tuxedo_e_a_escolha_persiste() -> void:
	afirmar_igual(AparenciaGato.atual(), AparenciaGato.TUXEDO, "sem preferencia salva, tuxedo")
	AparenciaGato.definir(AparenciaGato.CALICO)
	afirmar_igual(AparenciaGato.atual(), AparenciaGato.CALICO, "a escolha fica salva")
	afirmar_igual(AparenciaGato.proxima(AparenciaGato.CALICO), AparenciaGato.TUXEDO,
		"o botao alterna e volta ao comeco")


func teste_valor_desconhecido_volta_ao_padrao() -> void:
	var arquivo := ConfigFile.new()
	arquivo.set_value("jogador", "aparencia_gato", "dragao")
	arquivo.save(AparenciaGato.caminho)
	afirmar_igual(AparenciaGato.atual(), AparenciaGato.PADRAO, "arquivo mexido a mao nao quebra")


func teste_as_duas_aparencias_tem_as_mesmas_animacoes() -> void:
	# Cosmetica de verdade: trocar a aparencia nao pode tirar animacao nenhuma.
	var tuxedo: SpriteFrames = AparenciaGato.quadros(AparenciaGato.TUXEDO)
	var calico: SpriteFrames = AparenciaGato.quadros(AparenciaGato.CALICO)
	var a: Array = Array(tuxedo.get_animation_names())
	var b: Array = Array(calico.get_animation_names())
	a.sort()
	b.sort()
	afirmar_igual(a, b, "mesmo conjunto de animacoes")


func teste_jogador_nasce_com_a_aparencia_escolhida() -> void:
	AparenciaGato.definir(AparenciaGato.CALICO)
	var jogador: Jogador = (load("res://cenas/base/jogador.tscn") as PackedScene).instantiate() as Jogador
	get_tree().root.add_child(jogador)
	var sprite: AnimatedSprite2D = jogador.get_node("Sprite") as AnimatedSprite2D
	afirmar_igual(sprite.sprite_frames.resource_path, "res://recursos/arte/gato_calico_frames.tres",
		"o gato da fase usa a folha calico")
	afirmar_falso((jogador.get_node("Sombra") as CanvasItem).visible,
		"a calico ja tem sombra desenhada: a do no fica escondida")

	jogador.aplicar_aparencia(AparenciaGato.TUXEDO)
	afirmar_verdadeiro((jogador.get_node("Sombra") as CanvasItem).visible, "tuxedo ganha a sombra")
	jogador.free()


func teste_menu_troca_o_gato_e_o_cachorro_fica_sentado_parado() -> void:
	var menu: Control = (load("res://cenas/ui/menu_principal.tscn") as PackedScene).instantiate() as Control
	get_tree().root.add_child(menu)
	await get_tree().process_frame

	var cachorro: AnimatedSprite2D = menu.get_node("Cartao/Coluna/Mascote/Cachorro") as AnimatedSprite2D
	afirmar_falso(cachorro.is_playing(), "o cachorro do menu nao se mexe")
	afirmar_igual(cachorro.frame, 1, "e fica no quadro sentado")

	var botao: Button = menu.get_node("Cartao/Coluna/TrocarGato") as Button
	afirmar_contem(botao.text, "tuxedo", "o botao mostra a aparencia atual")
	botao.pressed.emit()
	afirmar_contem(botao.text, "calico", "clicar troca para calico")
	afirmar_igual(AparenciaGato.atual(), AparenciaGato.CALICO, "e a troca vale para as fases")
	var gato: AnimatedSprite2D = menu.get_node("Cartao/Coluna/Mascote/Gato") as AnimatedSprite2D
	afirmar_igual(gato.sprite_frames.resource_path, "res://recursos/arte/gato_calico_frames.tres",
		"o gato do menu troca na hora")
	menu.free()
