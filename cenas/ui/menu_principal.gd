extends Control

## Menu principal.
##
## "Telemetria" abre o Dashboard (cenas/ui/dashboard_telemetria.tscn), que
## responde "o que a coleta diz" -- acertos x erros e tempo por fase. O painel
## de diagnostico tecnico ("a coleta esta funcionando?": modo, fila, sequencia,
## id_sujeito) continua existindo e abre por um botao la dentro; ele nao foi
## removido, so deixou de ser a primeira tela.
##
## "Jogar" sempre comeca pela fase 1 -- fase_base.gd e quem encadeia fase 2 e
## fase 3 automaticamente ao concluir cada uma (ver FaseBase.concluir()).

const CENA_DA_FASE_1: String = "res://cenas/fases/fase_01.tscn"
const CENA_DO_DASHBOARD: String = "res://cenas/ui/dashboard_telemetria.tscn"
const CENA_DA_SELECAO: String = "res://cenas/ui/selecao_de_fases.tscn"
const CENA_DO_EDITOR: String = "res://cenas/ui/editor_de_fase.tscn"


func _ready() -> void:
	# A fase de exemplo e semeada aqui, e nao no autoload: o jogo so precisa
	# dela quando alguem abre o menu, e escrever em user:// durante um teste
	# headless seria efeito colateral escondido.
	CarregadorFaseJson.semear_exemplo()

	$Coluna/Botoes/Jogar.pressed.connect(_ao_jogar)
	$Coluna/Botoes/EscolherFase.pressed.connect(_ao_escolher_fase)
	$Coluna/Botoes/CriarFase.pressed.connect(_ao_criar_fase)
	$Coluna/Botoes/SubirFase.pressed.connect(_ao_subir_fase)
	$DialogoDeImportacao.file_selected.connect(_ao_escolher_arquivo_para_subir)
	$Coluna/Botoes/Telemetria.pressed.connect(_ao_abrir_telemetria)
	$Coluna/Botoes/Sair.pressed.connect(_ao_sair)
	$Coluna/Botoes/Jogar.grab_focus()


## As fases criadas pelo professor: lista, joga, edita, exclui e exporta.
func _ao_escolher_fase() -> void:
	get_tree().change_scene_to_file(CENA_DA_SELECAO)


func _ao_criar_fase() -> void:
	if not ResourceLoader.exists(CENA_DO_EDITOR):
		return
	# Caminho vazio = editor em branco; preenchido = editar fase existente.
	EditorDeFaseEstado.caminho_para_editar = ""
	get_tree().change_scene_to_file(CENA_DO_EDITOR)



func _ao_subir_fase() -> void:
	$DialogoDeImportacao.popup_centered()


## Subir = VALIDAR e so entao copiar para user://fases. Um .json quebrado que
## entrasse na pasta viraria uma linha "(com erro)" na lista da qual o professor
## teria de se livrar depois -- e melhor recusar na porta, dizendo o porque.
func _ao_escolher_arquivo_para_subir(caminho: String) -> void:
	var resultado: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_arquivo(caminho)
	if not resultado.ok():
		_avisar("este arquivo nao e uma fase valida:\n\n%s" % resultado.mensagem())
		return

	var destino: String = CarregadorFaseJson.nome_de_arquivo(resultado.config.titulo)
	if FileAccess.file_exists(destino):
		# Nao sobrescrever calado: o professor pode ter uma fase com o mesmo
		# titulo e perder o trabalho dela sem perceber.
		destino = "%s/%s-%s.json" % [CarregadorFaseJson.PASTA_DAS_FASES,
			destino.get_file().get_basename(), resultado.config.id_fase.substr(0, 8)]

	var erros: PackedStringArray = CarregadorFaseJson.salvar(resultado.config, destino)
	if not erros.is_empty():
		_avisar("nao foi possivel copiar a fase:\n\n%s" % "\n".join(erros))
		return

	_avisar("fase '%s' adicionada.\nela ja aparece em 'escolher fase'." % resultado.config.titulo)


func _avisar(mensagem: String) -> void:
	$Aviso.dialog_text = mensagem
	$Aviso.popup_centered()


func _ao_jogar() -> void:
	if not Sessao.ativa:
		Sessao.iniciar()
	get_tree().change_scene_to_file(CENA_DA_FASE_1)


func _ao_abrir_telemetria() -> void:
	get_tree().change_scene_to_file(CENA_DO_DASHBOARD)


func _ao_sair() -> void:
	# Encerrar a sessao e drenar antes de sair e o que transforma "o jogador
	# fechou o jogo" em SESSAO_ENCERRADA em vez de sessao pendurada em ABERTA.
	if Sessao.ativa:
		Sessao.encerrar()
	await Telemetria.descarregar()
	get_tree().quit()


