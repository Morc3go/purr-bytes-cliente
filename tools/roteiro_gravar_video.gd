extends RefCounted

## Roteiro de tools/gravar_video_demo.gd (carregado com os autoloads ja de pe).
##
## Joga sozinho pelo MESMO caminho que uma pessoa usa: botoes sao clicados
## (pressed), o terminal recebe texto digitado letra a letra, F3/F4/T chegam
## como acoes do InputMap e o gato anda com as acoes mover_* -- nada de
## teleporte. Um cursor desenhado e uma legenda por cima explicam cada passo.
##
## A telemetria e a de verdade (MOCK, em user://), entao o painel de telemetria
## mostrado no fim exibe a propria partida gravada.

const _FASE_CESAR: String = "01-cesar-o-primeiro-segredo.json"
const _FASE_VIGENERE: String = "02-vigenere-a-chave-que-muda.json"
const _FASE_SHA: String = "03-sha256-o-pacote-foi-alterado.json"
const _FASE_GOLPES: String = "04-golpes-digitais-nao-morda-a-isca.json"

const _TELA: Vector2 = Vector2(640, 360)
## Alturas da legenda: logo abaixo do HUD no jogo; no editor, sobre o titulo da
## tela, porque embaixo ficam os botoes de salvar.
const _TOPO_DO_JOGO: float = 24.0
const _TOPO_DO_EDITOR: float = 2.0
## Com o painel do F4 aberto (ele ocupa o topo), a legenda desce.
const _BAIXO_DO_JOGO: float = 312.0
const _INTERVALO_DE_DIGITACAO_S: float = 0.06
const _ACOES_DE_MOVIMENTO: Array[StringName] = [
	&"mover_cima", &"mover_baixo", &"mover_esquerda", &"mover_direita"]

var _arvore: SceneTree
var _camada: CanvasLayer
var _faixa: PanelContainer
var _texto_da_faixa: Label
var _cartaz: ColorRect
var _titulo_do_cartaz: Label
var _subtitulo_do_cartaz: Label
var _cursor: Node2D


func executar(arvore: SceneTree) -> void:
	_arvore = arvore
	AparenciaGato.definir(AparenciaGato.TUXEDO)
	_montar_sobreposicao()

	await _abertura()
	await _menu()
	await _criar_fase()
	await _fase_cesar()
	await _fase_vigenere()
	await _fase_sha256()
	await _fase_golpes()
	await _telemetria()
	await _encerramento()


# ---------------------------------------------------------------------------
# Cenas do video
# ---------------------------------------------------------------------------

func _abertura() -> void:
	_arvore.change_scene_to_file("res://cenas/ui/menu_principal.tscn")
	await _mostrar_cartaz("purr bytes", "demonstração das funções do jogo", 4.0)


func _menu() -> void:
	var menu: Node = _arvore.current_scene
	_legenda("menu principal: escolher, criar e subir fases, e ver a telemetria", false)
	await _esperar(3.0)
	_legenda("o gatinho tem duas aparências: tuxedo e calico", false)
	var trocar: Button = menu.get_node("Cartao/Coluna/TrocarGato") as Button
	await _clicar(trocar)
	await _esperar(2.0)
	await _clicar(trocar)
	await _esperar(1.5)


func _criar_fase() -> void:
	_legenda("criar fase: o professor monta a fase sem programar", false)
	await _clicar(_arvore.current_scene.get_node("Cartao/Coluna/Botoes/CriarFase") as Button)
	await _esperar(1.0)

	var editor: Node = _arvore.current_scene
	const GERAL: String = "Raiz/Margem/Coluna/Abas/Geral/Margem/Coluna"
	const CACHORROS: String = "Raiz/Margem/Coluna/Abas/Cachorros/Margem/Coluna"
	const PERGUNTAS: String = "Raiz/Margem/Coluna/Abas/Perguntas/Margem/Coluna"
	var abas: TabContainer = editor.get_node("Raiz/Margem/Coluna/Abas") as TabContainer

	_legenda("aba geral: título, vidas, tamanho do labirinto e semente", false, _TOPO_DO_EDITOR)
	var titulo: LineEdit = editor.get_node(GERAL + "/CamposGerais/CampoTitulo") as LineEdit
	await _clicar(titulo)
	await _digitar(titulo, "fase da banca")
	await _esperar(1.5)

	_legenda("aba cachorros: cada vigia exige uma defesa diferente", false, _TOPO_DO_EDITOR)
	await _clicar_aba(abas, 1)
	await _esperar(1.0)
	var botoes: Node = editor.get_node(CACHORROS + "/AdicionarVigias")
	var vigias: Node = editor.get_node(CACHORROS + "/RolagemVigias/Vigias")

	# Ordem dos botoes = ordem de _TIPOS_DE_VIGIA no editor.
	_legenda("vigia de cifra de césar: palavra e chave numérica", false, _TOPO_DO_EDITOR)
	await _clicar(botoes.get_child(1) as Button)
	await _preencher_vigia(vigias.get_child(vigias.get_child_count() - 1), "senha", "3")

	_legenda("vigia de vigenère: a chave é uma palavra", false, _TOPO_DO_EDITOR)
	await _clicar(botoes.get_child(2) as Button)
	await _preencher_vigia(vigias.get_child(vigias.get_child_count() - 1), "pacote", "gato")

	_legenda("vigia de sha-256: o jogador confere a integridade com hash e verificar", false, _TOPO_DO_EDITOR)
	await _clicar(botoes.get_child(3) as Button)
	await _preencher_vigia(vigias.get_child(vigias.get_child_count() - 1), "dados", "")

	# A fase nova ja nasce com um vigia de comando livre vazio e uma pergunta
	# vazia (_preparar_fase_nova): o roteiro preenche essas, como faria quem usa.
	_legenda("vigia de comando livre: uma frase de conduta segura", false, _TOPO_DO_EDITOR)
	var primeiro_vigia: Node = vigias.get_child(0)
	_rolar_ate(editor.get_node(CACHORROS + "/RolagemVigias") as ScrollContainer, primeiro_vigia as Control)
	await _clicar(primeiro_vigia.get_node("Comando") as LineEdit)
	await _digitar(primeiro_vigia.get_node("Comando") as LineEdit, "trocar senha")
	await _esperar(0.8)

	_legenda("e um vigia que só persegue: dele, o jeito é fugir", false, _TOPO_DO_EDITOR)
	await _clicar(botoes.get_child(4) as Button)
	_rolar_ate(editor.get_node(CACHORROS + "/RolagemVigias") as ScrollContainer,
		vigias.get_child(vigias.get_child_count() - 1) as Control)
	await _esperar(1.5)

	_legenda("aba perguntas: cada pacote do labirinto abre uma pergunta", false, _TOPO_DO_EDITOR)
	await _clicar_aba(abas, 2)
	await _esperar(0.8)
	var terminais: Node = editor.get_node(PERGUNTAS + "/RolagemTerminais/Terminais")
	var bloco: Node = terminais.get_child(0)
	var enunciado: LineEdit = bloco.get_node("Enunciado") as LineEdit
	await _clicar(enunciado)
	await _digitar(enunciado, "qual senha é mais forte?")
	var opcoes: Node = bloco.get_node("Opcoes")
	await _digitar(opcoes.get_child(0).get_node("Texto") as LineEdit, "g4t0-azul-pulou")
	await _digitar(opcoes.get_child(1).get_node("Texto") as LineEdit, "123456")
	await _esperar(1.5)

	_legenda("salvar e jogar: o labirinto é gerado na hora, sempre com saída", false, _TOPO_DO_EDITOR)
	await _clicar(editor.get_node("Raiz/Margem/Coluna/Acoes/SalvarEJogar") as Button)
	await _esperar(1.5)

	# O gato nasce em texto claro e um vigia pode estar perto da entrada: o
	# terminal abre logo (e pausa), mostrando os desafios que o editor gerou.
	var fase: FaseBase = _arvore.current_scene as FaseBase
	_legenda("a fase criada: o terminal já lista os desafios montados no editor")
	await _tecla(&"abrir_terminal")
	await _esperar(4.5)
	await _tecla(&"abrir_terminal")

	_legenda("esc: pausa, com continuar, reiniciar e voltar ao menu")
	await _tecla(&"pausar")
	await _esperar(2.0)
	await _clicar(fase.painel_pause.get_node("Raiz/Painel/Coluna/Voltar") as Button)
	await _esperar(1.0)


func _fase_cesar() -> void:
	_legenda("escolher fase: a trilha de demonstração já vem instalada", false)
	await _clicar(_arvore.current_scene.get_node("Cartao/Coluna/Botoes/EscolherFase") as Button)
	await _esperar(1.0)
	var selecao: Node = _arvore.current_scene
	var lista: ItemList = selecao.get_node("Raiz/Margem/Coluna/Corpo/Lista") as ItemList
	var indice: int = _indice_na_lista(lista, "1. ")
	await _clicar_item(lista, indice)
	await _esperar(2.5)
	await _clicar(selecao.get_node("Raiz/Margem/Coluna/Acoes/Jogar") as Button)
	await _esperar(0.5)

	var fase: FaseBase = _arvore.current_scene as FaseBase
	_legenda("fase 1, cifra de césar: leve o pacote até a porta sem ser interceptado")
	await _esperar(1.0)

	# O vigia verde nasce perto da entrada: proteger primeiro, como o jogo pede.
	_legenda("T abre o terminal e pausa o jogo")
	await _tecla(&"abrir_terminal")
	await _esperar(2.5)
	_legenda("'cyfrar' não é verbo: o AFD aceita, o parser recusa -> erro sintático (TC-04)")
	await _comando(fase, "cyfrar senha chave=3", 4.0)
	_legenda("gramática certa, chave errada -> erro semântico")
	await _comando(fase, "cifrar senha chave=5", 3.5)
	_legenda("comando certo: a cifra roda de verdade, senha -> vhqkd")
	await _comando(fase, "cifrar senha chave=3", 5.0)
	await _tecla(&"abrir_terminal")

	_legenda("F3: cada linha é a rota que o A* (AStarGrid2D) calculou para um cachorro")
	await _tecla(&"alternar_depuracao")
	await _esperar(3.0)

	var verde: Cachorro = fase.cachorros[0]
	_legenda("protegido com césar: o vigia verde só lê 'vhqkd' e deixa passar")
	await _andar_ate(fase, func() -> Vector2: return verde.global_position, 5.0,
		func() -> bool: return fase.jogador.global_position.distance_to(verde.global_position) < 12.0)
	await _soltar_movimento()
	await _esperar(1.5)

	_legenda("F4: como a cifra de césar desloca cada letra (chave 3)", true, _BAIXO_DO_JOGO)
	await _tecla(&"mostrar_demonstracao")
	await _esperar(4.0)
	await _tecla(&"mostrar_demonstracao")

	_legenda("a proteção dura 12 s: quando acaba, o vigia intercepta e o gato perde uma vida")
	await _esperar_ate(func() -> bool: return fase._em_captura, 8.0)
	await _esperar(2.0)
	await _esperar_ate(func() -> bool: return not fase._em_captura, 5.0)
	await _esperar(0.5)

	_legenda("de volta ao início: proteger de novo e buscar um pacote")
	await _tecla(&"abrir_terminal")
	await _comando(fase, "cifrar senha chave=3", 1.5)
	await _tecla(&"abrir_terminal")
	var pacote: Pacote = _pacote_mais_proximo(fase)
	if pacote != null:
		_legenda("cada pacote é uma pergunta: só com todos coletados a porta abre")
		await _andar_ate(fase, func() -> Vector2: return pacote.global_position, 12.0,
			func() -> bool: return fase.caixa_puzzle.esta_aberta())
		await _soltar_movimento()
		if fase.caixa_puzzle.esta_aberta():
			await _esperar(3.0)
			await _clicar(_botao_da_opcao(fase.caixa_puzzle, pacote.configuracao.resposta_correta))
			await _esperar(2.0)
	await _sair_da_fase(fase)


func _fase_vigenere() -> void:
	var fase: FaseBase = await _abrir_fase_demo(_FASE_VIGENERE,
		"fase 2", "vigenère: a chave que muda")
	_legenda("o mesmo terminal e a mesma gramática: só a chave virou uma palavra")
	await _esperar(2.5)
	_legenda("chave com número não vale no vigenère -> erro semântico")
	await _comando(fase, "cifrar segredo chave=g4to", 3.5)
	_legenda("chave 'gato': cada letra da chave dá um deslocamento diferente")
	await _comando(fase, "cifrar segredo chave=gato", 5.0)
	# O vigia verde (cesar) nasce perto da entrada: a protecao vale por
	# algoritmo, entao quem quer passar por ele cifra com cesar.
	_legenda("a proteção vale por algoritmo: para o vigia verde, de césar, cifrar com césar")
	await _comando(fase, "cifrar rede chave=7", 3.5)
	await _tecla(&"abrir_terminal")
	_legenda("F4: texto claro, chave repetida e texto cifrado, letra a letra", true, _BAIXO_DO_JOGO)
	await _tecla(&"mostrar_demonstracao")
	await _esperar(5.0)
	await _tecla(&"mostrar_demonstracao")
	await _esperar(0.5)


func _fase_sha256() -> void:
	var fase: FaseBase = await _abrir_fase_demo(_FASE_SHA,
		"fase 3", "sha-256: o pacote foi alterado?")
	_legenda("hash não esconde nada: serve para conferir se o conteúdo mudou")
	await _esperar(2.5)
	_legenda("'hash' calcula o resumo sha-256 da palavra (HashingContext do Godot)")
	await _comando(fase, "hash contrato", 4.5)
	_legenda("um prefixo que não bate: o conteúdo pode ter sido adulterado")
	await _comando(fase, "verificar contrato abcdef12", 4.0)
	var prefixo: String = Sha256.digest_hex("contrato").substr(0, 8)
	_legenda("'verificar' com o prefixo certo: o pacote está íntegro")
	await _comando(fase, "verificar contrato %s" % prefixo, 5.0)
	await _tecla(&"abrir_terminal")
	_legenda("F4: efeito avalanche, uma letra a mais muda o resumo inteiro", true, _BAIXO_DO_JOGO)
	await _tecla(&"mostrar_demonstracao")
	await _esperar(5.0)
	await _tecla(&"mostrar_demonstracao")
	await _esperar(0.5)


func _fase_golpes() -> void:
	var fase: FaseBase = await _abrir_fase_demo(_FASE_GOLPES,
		"fase 4", "golpes digitais: não morda a isca")
	_legenda("vigias de conduta: a defesa é uma atitude segura, não uma cifra")
	await _esperar(2.5)
	_legenda("maiúsculas e espaços não importam: 'Ativar 2FA' vale")
	await _comando(fase, "Ativar 2FA", 4.0)
	_legenda("cada vigia para com a sua conduta: 'conferir remetente' para o azul")
	await _comando(fase, "conferir remetente", 4.0)
	await _tecla(&"abrir_terminal")
	await _esperar(2.0)


func _telemetria() -> void:
	var anterior: FaseBase = _arvore.current_scene as FaseBase
	if anterior != null:
		await _sair_da_fase(anterior)
	_arvore.change_scene_to_file("res://cenas/ui/menu_principal.tscn")
	await _esperar(1.0)
	_legenda("telemetria: tudo o que foi jogado neste vídeo foi registrado", false)
	await _clicar(_arvore.current_scene.get_node("Cartao/Coluna/Botoes/Telemetria") as Button)
	await _esperar(1.0)
	_legenda("acertos x erros e tempo de resposta por fase, sem nenhum dado pessoal", false)
	await _esperar(5.0)
	var painel: Node = _arvore.current_scene
	_legenda("fases jogadas: detalhe e média só das fases escolhidas", false)
	await _clicar(painel.get_node("Raiz/Margem/Coluna/Acoes/FasesJogadas") as Button)
	await _esperar(5.0)


func _encerramento() -> void:
	_legenda("")
	await _mostrar_cartaz("purr bytes", "tcc, universidade positivo, 2026", 4.0)


# ---------------------------------------------------------------------------
# Passos reutilizados
# ---------------------------------------------------------------------------

## Sai da fase sem levar a pausa junto: espera a tela de captura acabar e
## fecha o que estiver aberto, como o proprio jogo faz ao abandonar.
func _sair_da_fase(fase: FaseBase) -> void:
	await _esperar_ate(func() -> bool: return not fase._em_captura, 5.0)
	await _soltar_movimento()
	fase._garantir_jogo_despausado()


func _esperar_ate(condicao: Callable, limite_s: float) -> void:
	var restante_s: float = limite_s
	while restante_s > 0.0 and not bool(condicao.call()):
		await _arvore.process_frame
		restante_s -= _arvore.root.get_process_delta_time()


func _abrir_fase_demo(arquivo: String, titulo: String, subtitulo: String) -> FaseBase:
	var anterior: FaseBase = _arvore.current_scene as FaseBase
	if anterior != null:
		await _sair_da_fase(anterior)
	var caminho: String = CarregadorFaseJson.pasta_das_fases.path_join(arquivo)
	_cartaz_visivel(true, titulo, subtitulo)
	if not Sessao.ativa:
		Sessao.iniciar()
	IniciadorDeFase.jogar_arquivo(_arvore, caminho)
	await _arvore.process_frame
	await _arvore.process_frame
	# Terminal aberto ja embaixo do cartaz: o jogo pausa antes de o vigia mais
	# perto da entrada chegar, e a fase aparece com o briefing na tela.
	await _tecla(&"abrir_terminal")
	await _esperar(2.5)
	_cartaz_visivel(false)
	return _arvore.current_scene as FaseBase


func _preencher_vigia(linha: Node, palavra: String, chave: String) -> void:
	await _digitar(linha.get_node("Palavra") as LineEdit, palavra)
	if chave != "":
		await _digitar(linha.get_node("Chave") as LineEdit, chave)
	await _esperar(0.8)


## Digita no terminal e da Enter, como o jogador.
func _comando(fase: FaseBase, texto: String, segura_s: float) -> void:
	var entrada: LineEdit = fase.terminal.get_node("Painel/Margem/Coluna/Entrada") as LineEdit
	await _digitar(entrada, texto)
	await _esperar(0.4)
	entrada.text_submitted.emit(entrada.text)
	await _esperar(segura_s)


func _pacote_mais_proximo(fase: FaseBase) -> Pacote:
	var melhor: Pacote = null
	for pacote: Pacote in fase.pacotes:
		if pacote.coletado:
			continue
		if melhor == null or fase.jogador.global_position.distance_to(pacote.global_position) \
				< fase.jogador.global_position.distance_to(melhor.global_position):
			melhor = pacote
	return melhor


func _botao_da_opcao(caixa: CaixaPuzzle, opcao: String) -> Button:
	for filho: Node in caixa.get_node("Raiz/Painel/Coluna/Opcoes").get_children():
		var botao: Button = filho as Button
		if botao != null and String(botao.get_meta("opcao", "")) == opcao:
			return botao
	return null


func _indice_na_lista(lista: ItemList, prefixo: String) -> int:
	for i: int in lista.item_count:
		if lista.get_item_text(i).begins_with(prefixo):
			return i
	return 0


## Anda pelo labirinto com as acoes mover_*, seguindo a rota do proprio A* do
## jogo ate o destino (que pode se mexer, como um cachorro). O eixo
## perpendicular e centralizado no corredor para o gato nao enroscar nas
## quinas -- a mesma correcao que um jogador faz sem perceber.
func _andar_ate(fase: FaseBase, destino: Callable, limite_s: float, parar: Callable) -> void:
	var jogador: Jogador = fase.jogador
	var passo_s: float = 1.0 / Engine.physics_ticks_per_second
	var caminho := PackedVector2Array()
	var indice: int = 0
	var replanejar_em_s: float = 0.0
	var restante_s: float = limite_s

	while restante_s > 0.0:
		await _arvore.physics_frame
		if _arvore.paused or bool(parar.call()):
			return
		restante_s -= passo_s
		replanejar_em_s -= passo_s
		if replanejar_em_s <= 0.0:
			caminho = fase._navegacao.calcular_caminho(jogador.global_position, destino.call())
			indice = 0
			replanejar_em_s = 0.4

		var posicao: Vector2 = jogador.global_position
		while indice < caminho.size() and posicao.distance_to(caminho[indice]) < 2.0:
			indice += 1
		if indice >= caminho.size():
			_pressionar(Vector2.ZERO)
			continue

		var falta: Vector2 = caminho[indice] - posicao
		if absf(falta.x) >= absf(falta.y):
			_pressionar(Vector2(signf(falta.x), 0.0))
			jogador.global_position.y = move_toward(posicao.y, caminho[indice].y, 1.0)
		else:
			_pressionar(Vector2(0.0, signf(falta.y)))
			jogador.global_position.x = move_toward(posicao.x, caminho[indice].x, 1.0)


func _pressionar(direcao: Vector2) -> void:
	var desejadas: Dictionary = {
		&"mover_direita": direcao.x > 0.0,
		&"mover_esquerda": direcao.x < 0.0,
		&"mover_baixo": direcao.y > 0.0,
		&"mover_cima": direcao.y < 0.0,
	}
	for acao: StringName in _ACOES_DE_MOVIMENTO:
		if desejadas[acao]:
			Input.action_press(acao)
		else:
			Input.action_release(acao)


func _soltar_movimento() -> void:
	_pressionar(Vector2.ZERO)
	await _arvore.physics_frame


## Aperta e solta uma acao do InputMap (F3, F4, T, Esc): chega aos
## _unhandled_input do jogo exatamente como a tecla chegaria.
func _tecla(acao: StringName) -> void:
	var evento := InputEventAction.new()
	evento.action = acao
	evento.pressed = true
	Input.parse_input_event(evento)
	await _arvore.process_frame
	var soltar := InputEventAction.new()
	soltar.action = acao
	soltar.pressed = false
	Input.parse_input_event(soltar)
	await _arvore.process_frame


func _digitar(campo: LineEdit, texto: String) -> void:
	campo.grab_focus()
	for letra: String in texto:
		campo.text += letra
		campo.caret_column = campo.text.length()
		await _esperar(_INTERVALO_DE_DIGITACAO_S)


func _esperar(segundos: float) -> void:
	await _arvore.create_timer(segundos, true).timeout


# ---------------------------------------------------------------------------
# Cursor, legenda e cartaz
# ---------------------------------------------------------------------------

func _clicar(controle: Control) -> void:
	if controle == null:
		return
	await _mover_cursor(controle.get_global_rect().get_center())
	await _pulso_do_clique()
	if controle is BaseButton:
		(controle as BaseButton).pressed.emit()
	elif controle is LineEdit:
		controle.grab_focus()


func _rolar_ate(rolagem: ScrollContainer, controle: Control) -> void:
	rolagem.ensure_control_visible(controle)


func _clicar_aba(abas: TabContainer, indice: int) -> void:
	var barra: TabBar = abas.get_tab_bar()
	await _mover_cursor(barra.get_global_rect().position + barra.get_tab_rect(indice).get_center())
	await _pulso_do_clique()
	abas.current_tab = indice


func _clicar_item(lista: ItemList, indice: int) -> void:
	var retangulo: Rect2 = lista.get_item_rect(indice)
	await _mover_cursor(lista.get_global_rect().position + retangulo.get_center())
	await _pulso_do_clique()
	lista.select(indice)
	lista.item_selected.emit(indice)


func _mover_cursor(alvo: Vector2) -> void:
	_cursor.visible = true
	var duracao: float = clampf(_cursor.position.distance_to(alvo) / 420.0, 0.25, 0.8)
	var tween: Tween = _arvore.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_cursor, "position", alvo, duracao) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


func _pulso_do_clique() -> void:
	var tween: Tween = _arvore.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_cursor, "scale", Vector2(0.75, 0.75), 0.08)
	tween.tween_property(_cursor, "scale", Vector2.ONE, 0.1)
	await tween.finished


## Legenda no topo durante o jogo (abaixo do HUD) e embaixo nas telas de menu,
## onde o topo e o titulo da tela.
func _legenda(texto: String, no_topo: bool = true, altura: float = -1.0) -> void:
	_faixa.visible = texto != ""
	_texto_da_faixa.text = texto
	if altura < 0.0:
		altura = _TOPO_DO_JOGO if no_topo else _TELA.y - 46.0
	_faixa.position = Vector2(16, altura)
	_cursor.visible = not no_topo


func _mostrar_cartaz(titulo: String, subtitulo: String, segundos: float) -> void:
	_cartaz_visivel(true, titulo, subtitulo)
	await _esperar(segundos)
	_cartaz_visivel(false)


func _cartaz_visivel(visivel: bool, titulo: String = "", subtitulo: String = "") -> void:
	_cartaz.visible = visivel
	_titulo_do_cartaz.text = titulo
	_subtitulo_do_cartaz.text = subtitulo
	if visivel:
		_faixa.visible = false
		_cursor.visible = false


func _montar_sobreposicao() -> void:
	_camada = CanvasLayer.new()
	_camada.layer = 100
	_camada.process_mode = Node.PROCESS_MODE_ALWAYS
	_arvore.root.add_child.call_deferred(_camada)

	var tema: Theme = load("res://recursos/temas/tema_purrbytes.tres") as Theme

	_faixa = PanelContainer.new()
	_faixa.theme = tema
	_faixa.size = Vector2(_TELA.x - 32, 0)
	_faixa.custom_minimum_size = Vector2(_TELA.x - 32, 22)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.11, 0.1, 0.16, 0.9)
	estilo.border_color = Color(1.0, 0.82, 0.3)
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(4)
	estilo.content_margin_left = 8
	estilo.content_margin_right = 8
	estilo.content_margin_top = 4
	estilo.content_margin_bottom = 4
	_faixa.add_theme_stylebox_override("panel", estilo)
	_texto_da_faixa = Label.new()
	_texto_da_faixa.add_theme_color_override("font_color", Color.WHITE)
	_texto_da_faixa.add_theme_font_size_override("font_size", 8)
	_texto_da_faixa.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texto_da_faixa.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_faixa.add_child(_texto_da_faixa)
	_faixa.visible = false
	_camada.add_child(_faixa)

	_cursor = Node2D.new()
	var seta := Polygon2D.new()
	var pontos := PackedVector2Array([Vector2(0, 0), Vector2(0, 12), Vector2(3, 9),
		Vector2(5, 14), Vector2(7, 13), Vector2(5, 8), Vector2(9, 8)])
	seta.polygon = pontos
	seta.color = Color.WHITE
	_cursor.add_child(seta)
	var contorno := Line2D.new()
	contorno.points = pontos
	contorno.closed = true
	contorno.width = 1.0
	contorno.default_color = Color.BLACK
	_cursor.add_child(contorno)
	_cursor.position = _TELA / 2.0
	_cursor.visible = false
	_camada.add_child(_cursor)

	_cartaz = ColorRect.new()
	_cartaz.color = Color(0.145, 0.129, 0.106)
	_cartaz.size = _TELA
	var coluna := VBoxContainer.new()
	coluna.theme = tema
	coluna.size = _TELA
	coluna.alignment = BoxContainer.ALIGNMENT_CENTER
	_titulo_do_cartaz = Label.new()
	_titulo_do_cartaz.add_theme_font_size_override("font_size", 32)
	_titulo_do_cartaz.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3))
	_titulo_do_cartaz.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(_titulo_do_cartaz)
	_subtitulo_do_cartaz = Label.new()
	_subtitulo_do_cartaz.add_theme_font_size_override("font_size", 8)
	_subtitulo_do_cartaz.add_theme_color_override("font_color", Color.WHITE)
	_subtitulo_do_cartaz.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(_subtitulo_do_cartaz)
	_cartaz.add_child(coluna)
	_cartaz.visible = false
	_camada.add_child(_cartaz)
