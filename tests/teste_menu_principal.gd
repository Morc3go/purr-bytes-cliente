extends CasoDeTeste

## Regressao de um bug real: "Jogar" no menu principal ficava preso num
## placeholder do Marco 0 (so escrevia uma mensagem na tela) e NUNCA
## carregava fase_01.tscn -- o jogo "nao iniciava" porque nenhum teste
## exercitava o botao de verdade, so a logica das fases isoladamente.
##
## Este arquivo instancia cenas/ui/menu_principal.tscn de verdade, aciona o
## MESMO caminho que um clique no botao aciona (a funcao conectada ao sinal
## `pressed`), e confere que a cena ativa da SceneTree realmente vira a fase
## -- nao só que uma função interna "não lançou erro".


func depois() -> void:
	if Sessao.ativa:
		Sessao.encerrar()


func teste_botao_jogar_carrega_a_fase_1() -> void:
	var cena: PackedScene = load("res://cenas/ui/menu_principal.tscn") as PackedScene
	var menu: Control = cena.instantiate()
	get_tree().root.add_child(menu)
	await get_tree().process_frame

	menu._ao_jogar()
	# change_scene_to_file() e adiado para o proximo idle frame.
	await get_tree().process_frame
	await get_tree().process_frame

	var cena_atual: Node = get_tree().current_scene
	afirmar_nao_nulo(cena_atual, "current_scene passou a existir depois de 'jogar'")
	afirmar_verdadeiro(cena_atual is FaseBase, "a cena carregada e uma fase, nao o menu preso")
	if cena_atual is FaseBase:
		afirmar_igual((cena_atual as FaseBase).configuracao.numero, 1,
			"'jogar' sempre comeca pela fase 1")

	afirmar_verdadeiro(Sessao.ativa, "'jogar' abre uma sessao se nenhuma estiver ativa")

	# change_scene_to_file() nao gerencia `menu` (adicionada por fora, via
	# root.add_child) -- sem liberar os dois, `menu` fica orfa sob root,
	# processando para sempre. Ver o comentario equivalente em
	# tests/teste_encadeamento_de_fases.gd::_limpar().
	if is_instance_valid(menu) and menu != cena_atual:
		menu.queue_free()
	if is_instance_valid(cena_atual):
		cena_atual.queue_free()
	await get_tree().process_frame
