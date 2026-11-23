extends CasoDeTeste

## O cachorro nao da meia-volta quando o A* replaneja (a cada segundo): a rota
## nova comeca no centro da celula em que ele esta, e se ele ja saiu desse
## centro rumo ao proximo ponto, segue em frente.

const CENTRO: Vector2 = Vector2(24, 24)
const PROXIMO: Vector2 = Vector2(40, 24)


func teste_ja_a_caminho_do_proximo_ponto_segue_em_frente() -> void:
	var rota := PackedVector2Array([CENTRO, PROXIMO, Vector2(40, 40)])
	afirmar_igual(Cachorro.primeiro_ponto_a_frente(rota, Vector2(30, 24), 4.0), 1,
		"no meio do trecho: vai direto ao segundo ponto")
	afirmar_igual(Cachorro.primeiro_ponto_a_frente(rota, Vector2(30, 25), 4.0), 1,
		"um pixel fora da linha ainda conta como no trecho")


func teste_rota_que_sai_para_outro_lado_volta_ao_centro() -> void:
	# Vinha da esquerda (x = 18) e a rota nova sobe: precisa voltar ao centro
	# para virar, senao cortaria a quina da cerca.
	var sobe := PackedVector2Array([CENTRO, Vector2(24, 8)])
	afirmar_igual(Cachorro.primeiro_ponto_a_frente(sobe, Vector2(18, 24), 4.0), 0, "rota para cima")
	var volta := PackedVector2Array([CENTRO, PROXIMO])
	afirmar_igual(Cachorro.primeiro_ponto_a_frente(volta, Vector2(18, 24), 4.0), 0,
		"atras do centro: ainda nao passou por ele")
	afirmar_igual(Cachorro.primeiro_ponto_a_frente(volta, Vector2(30, 32), 4.0), 0,
		"longe da linha do trecho")


func teste_rota_curta_comeca_no_primeiro_ponto() -> void:
	afirmar_igual(Cachorro.primeiro_ponto_a_frente(PackedVector2Array([CENTRO]), Vector2(30, 24), 4.0), 0, "um ponto so")
	afirmar_igual(Cachorro.primeiro_ponto_a_frente(PackedVector2Array(), Vector2(30, 24), 4.0), 0, "rota vazia")


func teste_cachorro_na_cena_nao_volta_atras() -> void:
	var cao: Cachorro = (load("res://cenas/base/cachorro.tscn") as PackedScene).instantiate() as Cachorro
	get_tree().root.add_child(cao)
	cao.global_position = Vector2(30, 24)
	cao.definir_caminho(PackedVector2Array([CENTRO, PROXIMO]))
	afirmar_igual(cao.indice_atual(), 1, "comeca pelo ponto da frente")
	for i: int in 3:
		await get_tree().physics_frame
	afirmar_verdadeiro(cao.global_position.x > 30.0 and cao.velocity.x > 0.0, "anda para a direita, sem meia-volta")
	cao.free()
