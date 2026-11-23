extends CasoDeTeste

## Arte dos personagens: folhas PNG -> SpriteFrames -> AnimatedSprite2D.
##
## O que protege: (a) as 5 animacoes existirem nos dois .tres, com ciclo de
## andar de 4 passos
## (um quadro faltando so apareceria jogando), (b) a regra de direcao do
## AnimadorDirecional e (c) as cenas base usarem a arte nova sem perder o
## tingimento por cor do cachorro, que e mecanica e nao enfeite.

const QUADROS: Dictionary = {
	"gato_amarelo": "res://recursos/arte/gato_amarelo_frames.tres",
	"gato_calico": "res://recursos/arte/gato_calico_frames.tres",
	"gato_siames": "res://recursos/arte/gato_siames_frames.tres",
	"cachorro": "res://recursos/arte/cachorro_frames.tres",
}
## Todas as folhas sao de 32x32 (ADR 0020 e 0024).
const TAMANHO_DO_QUADRO: Dictionary = {
	"gato_amarelo": Vector2(32, 32), "gato_calico": Vector2(32, 32), "gato_siames": Vector2(32, 32),
	"cachorro": Vector2(32, 32),
}
const ANIMACOES: Array[StringName] = [
	AnimadorDirecional.ANDAR_BAIXO, AnimadorDirecional.ANDAR_DIREITA,
	AnimadorDirecional.ANDAR_CIMA, AnimadorDirecional.ANDAR_ESQUERDA,
	AnimadorDirecional.PARADO,
]


func teste_sprite_frames_tem_as_animacoes_completas() -> void:
	for nome: String in QUADROS:
		var quadros: SpriteFrames = load(QUADROS[nome]) as SpriteFrames
		if not afirmar_nao_nulo(quadros, "%s: SpriteFrames carrega" % nome):
			continue
		for animacao: StringName in ANIMACOES:
			if not afirmar_verdadeiro(quadros.has_animation(animacao),
					"%s tem a animacao %s" % [nome, animacao]):
				continue
			# Andar tem ciclo de 4 passos (3 desenhados viram 0-1-2-1, ADR
			# 0020); o parado pode ter 1 quadro (gato) ou 2 (rabo do cachorro).
			if animacao != AnimadorDirecional.PARADO:
				afirmar_igual(quadros.get_frame_count(animacao), 4,
					"%s/%s tem 4 quadros" % [nome, animacao])
			else:
				afirmar_verdadeiro(quadros.get_frame_count(animacao) >= 1,
					"%s/%s tem ao menos um quadro" % [nome, animacao])
			# O parado do cachorro e ele sentando (ADR 0037): toca uma vez e fica
			# sentado. Todo o resto repete em ciclo.
			var senta: bool = nome == "cachorro" and animacao == AnimadorDirecional.PARADO
			afirmar_igual(quadros.get_animation_loop(animacao), not senta,
				"%s/%s %s" % [nome, animacao, "senta e fica" if senta else "repete em ciclo"])
			var primeiro: Texture2D = quadros.get_frame_texture(animacao, 0)
			afirmar_igual(primeiro.get_size(), TAMANHO_DO_QUADRO[nome],
				"%s/%s: tamanho do quadro" % [nome, animacao])

	# Os tres gatos (ADR 0024 e 0030): sentado de olho fechado para dormir e
	# sentado de olho aberto, que e a pose do gato no menu e na escolha.
	for nome: String in ["gato_amarelo", "gato_calico", "gato_siames"]:
		var gato: SpriteFrames = load(QUADROS[nome]) as SpriteFrames
		afirmar_verdadeiro(gato.has_animation(AnimadorDirecional.DESCANSAR),
			"%s tem a animacao de descansar (ADR 0017)" % nome)
		afirmar_igual(gato.get_frame_count(AnimadorDirecional.DESCANSAR), 1, "%s dorme num quadro" % nome)
		afirmar_verdadeiro(gato.has_animation(&"sentado"), "%s tem a pose sentado" % nome)
		afirmar_igual(gato.get_frame_count(&"sentado"), 2, "%s sentado: dois quadros" % nome)


## O .tres foi ajustado a mao pela equipe (ADR 0017). Se o gerador nao
## reproduzir o mesmo resultado, rodar o gerador de novo apagaria o ajuste --
## este teste trava os dois juntos.
func teste_gerador_reproduz_os_sprite_frames_versionados() -> void:
	var gerador: GDScript = load("res://tools/gerar_sprite_frames.gd") as GDScript
	for folha: String in gerador.FOLHAS:
		var opcoes: Dictionary = gerador.FOLHAS[folha]
		var gerado: SpriteFrames = gerador.montar(folha, opcoes) as SpriteFrames
		var versionado: SpriteFrames = load(String(opcoes["destino"])) as SpriteFrames
		var nomes_gerados: Array = Array(gerado.get_animation_names())
		var nomes_versionados: Array = Array(versionado.get_animation_names())
		nomes_gerados.sort()
		nomes_versionados.sort()
		afirmar_igual(nomes_gerados, nomes_versionados, "%s: mesmas animacoes" % folha.get_file())
		for animacao: StringName in versionado.get_animation_names():
			if not gerado.has_animation(animacao):
				continue
			afirmar_igual(gerado.get_frame_count(animacao), versionado.get_frame_count(animacao),
				"%s/%s: mesmo numero de quadros" % [folha.get_file(), animacao])
			afirmar_proximo(gerado.get_animation_speed(animacao),
				versionado.get_animation_speed(animacao), 0.001,
				"%s/%s: mesma velocidade" % [folha.get_file(), animacao])
			for i: int in versionado.get_frame_count(animacao):
				var a: AtlasTexture = gerado.get_frame_texture(animacao, i) as AtlasTexture
				var b: AtlasTexture = versionado.get_frame_texture(animacao, i) as AtlasTexture
				afirmar_igual(a.region, b.region,
					"%s/%s quadro %d: mesma regiao da folha" % [folha.get_file(), animacao, i])


func teste_quadros_nao_sao_transparentes() -> void:
	# Quadro todo transparente = recorte fora da folha (grade errada no gerador).
	for nome: String in QUADROS:
		var quadros: SpriteFrames = load(QUADROS[nome]) as SpriteFrames
		for animacao: StringName in ANIMACOES:
			for i: int in quadros.get_frame_count(animacao):
				var imagem: Image = quadros.get_frame_texture(animacao, i).get_image()
				afirmar_verdadeiro(not imagem.is_invisible(),
					"%s/%s quadro %d tem desenho" % [nome, animacao, i])


func teste_direcao_escolhe_a_animacao_pelo_eixo_dominante() -> void:
	var animador := AnimadorDirecional.new()
	animador.velocidade_minima = 6.0
	afirmar_igual(animador.animacao_para(Vector2.ZERO), AnimadorDirecional.PARADO, "parado")
	afirmar_igual(animador.animacao_para(Vector2(3, 3)), AnimadorDirecional.PARADO,
		"abaixo do limiar conta como parado (lerp soltando a tecla)")
	afirmar_igual(animador.animacao_para(Vector2(70, 0)), AnimadorDirecional.ANDAR_DIREITA, "direita")
	afirmar_igual(animador.animacao_para(Vector2(-70, 0)), AnimadorDirecional.ANDAR_ESQUERDA, "esquerda")
	afirmar_igual(animador.animacao_para(Vector2(0, 70)), AnimadorDirecional.ANDAR_BAIXO,
		"y cresce para baixo no Godot")
	afirmar_igual(animador.animacao_para(Vector2(0, -70)), AnimadorDirecional.ANDAR_CIMA, "cima")
	afirmar_igual(animador.animacao_para(Vector2(50, -40)), AnimadorDirecional.ANDAR_DIREITA,
		"diagonal: eixo dominante decide")
	afirmar_igual(animador.animacao_para(Vector2(-30, 40)), AnimadorDirecional.ANDAR_BAIXO,
		"diagonal: eixo dominante decide (vertical)")
	animador.free()


func teste_cenas_base_usam_a_arte_animada() -> void:
	for caminho: String in ["res://cenas/base/jogador.tscn", "res://cenas/base/cachorro.tscn"]:
		var no: Node = (load(caminho) as PackedScene).instantiate()
		var sprite: Node = no.get_node_or_null("Sprite")
		afirmar_verdadeiro(sprite is AnimadorDirecional, "%s: Sprite e AnimadorDirecional" % caminho)
		if sprite is AnimatedSprite2D:
			afirmar_nao_nulo((sprite as AnimatedSprite2D).sprite_frames, "%s tem SpriteFrames" % caminho)
		no.free()


func teste_jogador_anima_ao_andar_e_senta_ao_parar() -> void:
	var jogador: Jogador = (load("res://cenas/base/jogador.tscn") as PackedScene).instantiate() as Jogador
	get_tree().root.add_child(jogador)
	var sprite: AnimadorDirecional = jogador.get_node("Sprite") as AnimadorDirecional
	afirmar_igual(sprite.animation, AnimadorDirecional.PARADO, "nasce parado")

	sprite.atualizar(Vector2(0, -jogador.velocidade))
	afirmar_igual(sprite.animation, AnimadorDirecional.ANDAR_CIMA, "andando para cima")
	afirmar_verdadeiro(sprite.is_playing(), "a animacao roda")
	sprite.atualizar(Vector2.ZERO)
	# Pedido da equipe: parado, o gato continua virado para onde andava.
	afirmar_igual(sprite.animation, AnimadorDirecional.ANDAR_CIMA, "soltou a tecla: fica de costas")
	afirmar_falso(sprite.is_playing(), "e parado, sem andar no lugar")
	afirmar_igual(sprite.frame, AnimadorDirecional.QUADRO_PARADO_NA_DIRECAO, "no quadro de pose")
	sprite.atualizar(Vector2(jogador.velocidade, 0))
	sprite.atualizar(Vector2.ZERO)
	afirmar_igual(sprite.animation, AnimadorDirecional.ANDAR_DIREITA, "e de lado, se andava de lado")
	jogador.free()


func teste_gato_senta_aos_5_s_e_dorme_2_s_depois() -> void:
	var jogador: Jogador = (load("res://cenas/base/jogador.tscn") as PackedScene).instantiate() as Jogador
	get_tree().root.add_child(jogador)
	var sprite: AnimadorDirecional = jogador.get_node("Sprite") as AnimadorDirecional
	var zzz: CanvasItem = jogador.get_node("Zzz") as CanvasItem
	afirmar_igual(jogador.tempo_para_sentar_s, 5.0, "senta depois de 5 s parado")
	afirmar_igual(jogador.tempo_sentado_antes_de_dormir_s, 2.0, "e dorme 2 s depois")
	jogador._atualizar_descanso(Vector2.ZERO, 4.9)
	afirmar_igual(jogador.repouso(), Jogador.Repouso.ACORDADO, "4,9 s: ainda acordado")
	jogador._atualizar_descanso(Vector2.ZERO, 0.2)
	afirmar_igual(jogador.repouso(), Jogador.Repouso.SENTADO, "5 s: sentado")
	afirmar_igual(sprite.animation, AnimadorDirecional.SENTADO, "pose sentado de olho aberto")
	afirmar_falso(zzz.visible, "sentado ainda nao tem zzz")
	jogador._atualizar_descanso(Vector2.ZERO, 1.8)
	afirmar_igual(jogador.repouso(), Jogador.Repouso.SENTADO, "6,9 s: ainda sentado")
	jogador._atualizar_descanso(Vector2.ZERO, 0.2)
	afirmar_igual(jogador.repouso(), Jogador.Repouso.DORMINDO, "7 s: dormindo")
	afirmar_igual(sprite.animation, AnimadorDirecional.DESCANSAR, "olho fechado")
	afirmar_verdadeiro(zzz.visible, "com zzz")
	jogador._atualizar_descanso(Vector2.RIGHT, 0.016)
	afirmar_igual(jogador.repouso(), Jogador.Repouso.ACORDADO, "uma tecla acorda")
	afirmar_falso(zzz.visible, "e o zzz some")
	jogador.free()


func teste_cor_do_cachorro_vai_para_o_anel_e_nao_tinge_a_arte() -> void:
	var cachorro: Cachorro = (load("res://cenas/base/cachorro.tscn") as PackedScene).instantiate() as Cachorro
	get_tree().root.add_child(cachorro)
	var cor := Color(0.3, 0.6, 1.0)
	cachorro.definir_cor(cor)
	afirmar_igual((cachorro.get_node("Marcador") as MarcadorDeCor).cor, cor,
		"a cor do vigia aparece no anel do chao")
	afirmar_igual((cachorro.get_node("Sprite") as CanvasItem).modulate, Color.WHITE,
		"a arte colorida do cachorro nao e tingida")
	cachorro.free()


func teste_cachorro_anda_nas_quatro_direcoes() -> void:
	# A folha atual do cachorro tem costas e frente: subindo ele mostra as
	# costas, em vez de andar de lado como a folha anterior obrigava.
	var cachorro: Cachorro = (load("res://cenas/base/cachorro.tscn") as PackedScene).instantiate() as Cachorro
	get_tree().root.add_child(cachorro)
	var sprite: AnimadorDirecional = cachorro.get_node("Sprite") as AnimadorDirecional
	afirmar_falso(sprite.lateral_no_eixo_vertical, "folha com costas: nada de lateral na vertical")
	sprite.atualizar(Vector2(0, -60))
	afirmar_igual(sprite.animation, AnimadorDirecional.ANDAR_CIMA, "subindo: costas")
	sprite.atualizar(Vector2(0, 60))
	afirmar_igual(sprite.animation, AnimadorDirecional.ANDAR_BAIXO, "descendo: frente")
	cachorro.free()


func teste_folha_sem_costas_pode_ficar_na_lateral() -> void:
	# Recurso do AnimadorDirecional para folhas sem vista de costas.
	var animador := AnimadorDirecional.new()
	animador.lateral_no_eixo_vertical = true
	animador.sprite_frames = load("res://recursos/arte/cachorro_frames.tres") as SpriteFrames
	animador.atualizar(Vector2(-60, 0))
	animador.atualizar(Vector2(0, -60))
	afirmar_igual(animador.animation, AnimadorDirecional.ANDAR_ESQUERDA,
		"subindo depois de ir para a esquerda: continua de lado")
	animador.free()

func teste_fase_ordena_personagens_por_altura() -> void:
	# Sprite de 24px sobre tile de 16 invade a celula de cima: sem y-sort, um
	# cachorro abaixo do gato apareceria atras dele. O labirinto fica na origem
	# (y = 0), entao continua sendo desenhado antes de todos.
	var fase: Node2D = (load("res://cenas/base/fase_base.tscn") as PackedScene).instantiate() as Node2D
	afirmar_verdadeiro(fase.y_sort_enabled, "FaseBase ordena os filhos por y")
	afirmar_igual((fase.get_node("Labirinto") as Node2D).position, Vector2.ZERO,
		"labirinto na origem, atras dos personagens")
	fase.free()
