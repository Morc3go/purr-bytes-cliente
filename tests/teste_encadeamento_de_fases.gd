extends CasoDeTeste

## Regressao do mesmo bug que tests/teste_menu_principal.gd cobre pelo lado do
## menu: FaseBase.concluir() tambem precisa realmente TROCAR de cena para a
## proxima fase (fase_01 -> fase_02 -> fase_03), nao so emitir o sinal
## fase_concluida e voltar ao menu toda vez -- senao "as tres fases jogaveis
## em sequencia" (criterio de aceite do Marco 3) nunca acontece na pratica.


func depois() -> void:
	if Sessao.ativa:
		Sessao.encerrar()


func _montar(caminho_cena: String) -> FaseBase:
	if not Sessao.ativa:
		Sessao.iniciar()
	var fase: FaseBase = (load(caminho_cena) as PackedScene).instantiate() as FaseBase
	get_tree().root.add_child(fase)
	await get_tree().process_frame
	return fase


func teste_concluir_fase_1_carrega_fase_2() -> void:
	var fase: FaseBase = await _montar("res://cenas/fases/fase_01.tscn")

	fase.concluir()
	await get_tree().process_frame
	await get_tree().process_frame

	var cena_atual: Node = get_tree().current_scene
	afirmar_verdadeiro(cena_atual is FaseBase, "concluir a fase 1 carrega outra fase, nao o menu")
	if cena_atual is FaseBase:
		afirmar_igual((cena_atual as FaseBase).configuracao.numero, 2, "a proxima fase e a 2")

	await _limpar(fase, cena_atual)


func teste_concluir_fase_3_volta_ao_menu() -> void:
	var fase: FaseBase = await _montar("res://cenas/fases/fase_03.tscn")

	fase.concluir()
	await get_tree().process_frame
	await get_tree().process_frame

	var cena_atual: Node = get_tree().current_scene
	afirmar_falso(cena_atual is FaseBase, "nao ha fase 4 -- concluir a ultima fase volta ao menu")

	await _limpar(fase, cena_atual)


## change_scene_to_file() so gerencia o no que ELE proprio rastreia como
## current_scene. `fase` foi adicionada por fora (root.add_child, nao por
## change_scene_to_*), entao trocar de cena a deixa orfa sob root -- viva,
## processando fisica e temporizadores para sempre, se ninguem a liberar. Foi
## exatamente esse vazamento (descoberto rodando a suite inteira, nao so este
## arquivo) que fez tests/teste_fase_0{1,2}_integracao.gd falharem por
## interferencia de um cachorro de outro teste ainda ativo em segundo plano.
func _limpar(fase_original: FaseBase, cena_atual: Node) -> void:
	if is_instance_valid(fase_original):
		fase_original.queue_free()
	if is_instance_valid(cena_atual) and cena_atual != fase_original:
		cena_atual.queue_free()
	await get_tree().process_frame
