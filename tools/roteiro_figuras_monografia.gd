extends RefCounted

## Roteiro de tools/figuras_monografia.gd: joga a trilha de demonstracao com
## dois participantes FICTICIOS (UUIDs f1c71c10..., ADR 0019) e salva as telas
## usadas como figuras na monografia.
##
## Nada aqui toca os dados de quem joga nesta maquina: telemetria, fases e
## preferencia vivem em user://testes/monografia/.

const PASTA_DADOS: String = "user://testes/monografia"
const SUJEITO_A: String = "f1c71c10-0001-4000-8000-0000000000a1"
const SUJEITO_B: String = "f1c71c10-0001-4000-8000-0000000000b2"

var _arvore: SceneTree
var _pasta: String
var _fases: Dictionary = {}


func _salvar(nome: String) -> void:
	for i: int in 4:
		await _arvore.process_frame
	await RenderingServer.frame_post_draw
	_arvore.root.get_texture().get_image().save_png(_pasta.path_join(nome + ".png"))
	print("figura: %s" % nome)


func _esperar_fisica(quadros: int) -> void:
	for i: int in quadros:
		await _arvore.physics_frame


func _jogar(arquivo: String) -> FaseBase:
	var fase: FaseBase = IniciadorDeFase.jogar(_arvore, _fases[arquivo])
	await _esperar_fisica(30)
	return fase


func _comando(fase: FaseBase, texto: String, tempo_ms: int) -> void:
	fase._ao_submeter_comando(texto, tempo_ms)


## Responde as perguntas dos pacotes; `erros` = quantas erram antes de acertar.
func _responder_pacotes(fase: FaseBase, erros: int) -> void:
	var errou: int = 0
	for pacote: Pacote in fase.pacotes:
		if pacote.coletado:
			continue
		fase._ao_alcancar_pacote(pacote)
		var config: PacoteConfig = pacote.configuracao
		if errou < erros:
			for opcao: String in config.opcoes:
				if opcao != config.resposta_correta:
					fase.caixa_puzzle.escolher(opcao)
					break
			errou += 1
		fase.caixa_puzzle.escolher(config.resposta_correta)
		await _arvore.process_frame


func _vigia_que_so_persegue(fase: FaseBase) -> Cachorro:
	for alvo: Cachorro in fase.cachorros:
		if fase._apenas_persegue(alvo):
			return alvo
	return null


func _capturar(fase: FaseBase) -> void:
	var cachorro: Cachorro = _vigia_que_so_persegue(fase)
	fase._ao_encostar_no_jogador(fase.jogador, cachorro)
	fase.tela_captura.encerrar_agora()
	await _esperar_fisica(5)


func executar(arvore: SceneTree, pasta: String) -> void:
	_arvore = arvore
	_pasta = pasta
	DirAccess.make_dir_recursive_absolute(pasta)
	DirAccess.make_dir_recursive_absolute(PASTA_DADOS)
	for nome: String in DirAccess.get_files_at(PASTA_DADOS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PASTA_DADOS.path_join(nome)))
	var pasta_fases: String = PASTA_DADOS.path_join("fases")
	DirAccess.make_dir_recursive_absolute(pasta_fases)
	for nome: String in DirAccess.get_files_at(pasta_fases):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(pasta_fases.path_join(nome)))
	# A marca da semeadura e arquivo oculto: get_files_at nao a lista.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(pasta_fases.path_join(".fases_demo")))

	CarregadorFaseJson.pasta_das_fases = pasta_fases
	# Gato e fundo do menu (ADR 0030 e 0033) tambem ficam na pasta isolada,
	# comecando do padrao: amarelo e brejo.
	Preferencias.caminho = PASTA_DADOS.path_join("preferencias.cfg")
	var telemetria: Node = arvore.root.get_node("Telemetria")
	telemetria.call("reiniciar", TransporteMock.new(PASTA_DADOS.path_join("telemetria.jsonl")),
		PASTA_DADOS.path_join("fila.json"))
	var config: Node = arvore.root.get_node("ConfigJogo")
	var sessao: Node = arvore.root.get_node("Sessao")

	# Menu (semeia a trilha na pasta isolada) e telas de autoria.
	arvore.change_scene_to_file("res://cenas/ui/menu_principal.tscn")
	await _salvar("menu")
	# Uma figura por fundo da galeria: o botao do canto passa para o seguinte.
	for indice: int in GaleriaDeFundos.ORDEM.size():
		var fundo: String = arvore.current_scene.call("fundo_atual")
		await _salvar("menu_%s" % fundo)
		(arvore.current_scene.get_node("Galeria") as Button).pressed.emit()
	for caminho: String in CarregadorFaseJson.listar():
		var lido: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_arquivo(caminho)
		if lido.ok():
			_fases[caminho.get_file()] = lido.config
	arvore.change_scene_to_file("res://cenas/ui/selecao_de_fases.tscn")
	await _salvar("selecao_de_fases")
	# "jogar" pergunta o gatinho antes de abrir a fase (ADR 0030).
	arvore.current_scene.call("_ao_jogar")
	await _salvar("escolha_de_gato")
	arvore.current_scene.call("_fechar_escolha_de_gato")
	EditorDeFaseEstado.caminho_para_editar = pasta_fases.path_join("05-avaliacao-final-sem-colinha.json")
	arvore.change_scene_to_file("res://cenas/ui/editor_de_fase.tscn")
	await _salvar("editor_geral")
	(arvore.current_scene.get_node("Raiz/Margem/Coluna/Abas") as TabContainer).current_tab = 1
	await _salvar("editor_vigias")
	(arvore.current_scene.get_node("Raiz/Margem/Coluna/Abas") as TabContainer).current_tab = 2
	await _salvar("editor_perguntas")
	EditorDeFaseEstado.caminho_para_editar = ""

	# ------------------------------------------------ participante ficticio A
	config.set("id_sujeito", SUJEITO_A)
	sessao.call("iniciar")

	var f: FaseBase = await _jogar("01-cesar-o-primeiro-segredo.json")
	await _salvar("fase_cesar")
	f.alternar_rotas_astar()
	f._replanejar_caminho_do_cachorro()
	await _esperar_fisica(8)
	await _salvar("astar_f3")
	f.alternar_rotas_astar()
	_comando(f, "cyfrar senha chave=3", 6400)
	_comando(f, "cifrar senha chave=3", 4100)
	f.terminal.abrir()
	await _salvar("terminal_cesar")
	f.terminal.fechar()
	f._alternar_painel_de_demonstracao()
	await _salvar("painel_cesar")
	f._alternar_painel_de_demonstracao()
	var primeiro: Pacote = f.pacotes[0]
	f._ao_alcancar_pacote(primeiro)
	for opcao: String in primeiro.configuracao.opcoes:
		if opcao != primeiro.configuracao.resposta_correta:
			f.caixa_puzzle.escolher(opcao)
			break
	await _salvar("pergunta")
	f.caixa_puzzle.escolher(primeiro.configuracao.resposta_correta)
	await _esperar_fisica(5)
	var cachorro: Cachorro = _vigia_que_so_persegue(f)
	f._ao_encostar_no_jogador(f.jogador, cachorro)
	await _salvar("captura")
	f.tela_captura.encerrar_agora()
	await _esperar_fisica(5)
	_comando(f, "cifrar pacote chave=5", 5200)
	await _responder_pacotes(f, 0)
	f.concluir()
	await _esperar_fisica(5)

	f = await _jogar("02-vigenere-a-chave-que-muda.json")
	f._alternar_painel_de_demonstracao()
	await _salvar("painel_vigenere")
	f._alternar_painel_de_demonstracao()
	_comando(f, "cifrar segredo chave=gata", 9800)
	_comando(f, "dica", 3000)
	_comando(f, "cifrar segredo chave=gato", 7300)
	f.terminal.abrir()
	await _salvar("terminal_vigenere")
	f.terminal.fechar()
	_comando(f, "cifrar rede chave=7", 3900)
	await _responder_pacotes(f, 1)
	f.concluir()
	await _esperar_fisica(5)

	f = await _jogar("03-sha256-o-pacote-foi-alterado.json")
	_comando(f, "hash contrato", 5100)
	_comando(f, "verificar contrato %s" % Sha256.digest_hex("contrato").substr(0, 8), 8800)
	f.terminal.abrir()
	await _salvar("terminal_sha256")
	f.terminal.fechar()
	f._alternar_painel_de_demonstracao()
	await _salvar("painel_avalanche")
	f._alternar_painel_de_demonstracao()
	_comando(f, "verificar boleto 00000000", 6000)
	_comando(f, "verificar boleto %s" % Sha256.digest_hex("boleto").substr(0, 8), 7600)
	await _responder_pacotes(f, 1)
	f.concluir()
	await _esperar_fisica(5)

	f = await _jogar("04-golpes-digitais-nao-morda-a-isca.json")
	await _salvar("fase_golpes")
	_comando(f, "Conferir Remetente", 4300)
	_comando(f, "clicar no link", 3500)
	_comando(f, "desconfiar do link", 4800)
	_comando(f, "ativar 2fa", 2900)
	await _responder_pacotes(f, 1)
	f.concluir()
	await _esperar_fisica(5)

	f = await _jogar("05-avaliacao-final-sem-colinha.json")
	await _salvar("fase_avaliacao")
	_comando(f, "status", 2500)
	_comando(f, "cifrar cofre chave=4", 6900)
	_comando(f, "cifrar senha chave=lua", 8200)
	_comando(f, "verificar recibo %s" % Sha256.digest_hex("recibo").substr(0, 8), 9400)
	_comando(f, "conferir remetente", 5600)
	await _capturar(f)
	await _responder_pacotes(f, 1)
	f.concluir()
	await _esperar_fisica(5)
	sessao.call("encerrar")

	# ------------------------------------------------ participante ficticio B
	config.set("id_sujeito", SUJEITO_B)
	sessao.call("iniciar")
	f = await _jogar("01-cesar-o-primeiro-segredo.json")
	_comando(f, "cyfrar senha chave=3", 11200)
	_comando(f, "cifrar senha chave=4", 9300)
	_comando(f, "dica", 2500)
	_comando(f, "cifrar senha chave=3", 6100)
	await _capturar(f)
	_comando(f, "cifrar pacote chave=5", 7000)
	await _responder_pacotes(f, 2)
	f.concluir()
	await _esperar_fisica(5)

	f = await _jogar("02-vigenere-a-chave-que-muda.json")
	_comando(f, "cifrar segredo chave=7", 12500)
	_comando(f, "dica", 2800)
	_comando(f, "cifrar segredo chave=gato", 10100)
	await _capturar(f)
	await _capturar(f)
	_comando(f, "cifrar rede chave=7", 6600)
	await _responder_pacotes(f, 2)
	f.concluir()
	await _esperar_fisica(5)

	f = await _jogar("03-sha256-o-pacote-foi-alterado.json")
	_comando(f, "decifrar contrato", 9000)
	_comando(f, "hash contrato", 4200)
	await _capturar(f)
	f.abandonar()
	await _esperar_fisica(5)
	sessao.call("encerrar")

	# ------------------------------------------------ painel de telemetria
	await telemetria.call("descarregar")
	arvore.change_scene_to_file("res://cenas/ui/dashboard_telemetria.tscn")
	await _esperar_fisica(20)
	await _salvar("dashboard_visao_geral")
	var painel: Node = arvore.current_scene
	painel.call("_ao_abrir_fases")
	await _salvar("dashboard_fases")
	painel.call("_abrir_detalhe", (_fases["01-cesar-o-primeiro-segredo.json"] as FaseConfig).id_fase)
	await _salvar("dashboard_detalhe")

	CarregadorFaseJson.pasta_das_fases = CarregadorFaseJson.PASTA_DAS_FASES
