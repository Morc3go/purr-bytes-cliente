extends Control

## Menu principal e painel de diagnostico.
##
## O painel de telemetria nao e enfeite: e por ele que se confere, na maquina da
## escola e sem ferramenta nenhuma instalada, se a coleta esta em MOCK ou HTTP,
## se ha evento preso na fila e qual id_sujeito esta configurado. Ele mostra
## ConfigJogo.resumo_seguro(), que por construcao nao inclui a chave de API.
##
## Marco 0 nao tem fase jogavel: "jogar" abre a sessao e diz isso na tela, em vez
## de fingir um botao morto.

const INTERVALO_DE_ATUALIZACAO_S: float = 1.0

@onready var _menu: VBoxContainer = $Coluna
@onready var _mensagem: Label = $Coluna/Mensagem
@onready var _painel: PanelContainer = $PainelTelemetria
@onready var _diagnostico: RichTextLabel = $PainelTelemetria/Margem/Coluna/Diagnostico
@onready var _relogio: Timer = $RelogioDeAtualizacao


func _ready() -> void:
	$Coluna/Botoes/Jogar.pressed.connect(_ao_jogar)
	$Coluna/Botoes/Telemetria.pressed.connect(_ao_abrir_telemetria)
	$Coluna/Botoes/Sair.pressed.connect(_ao_sair)
	$PainelTelemetria/Margem/Coluna/Acoes/Descarregar.pressed.connect(_ao_descarregar)
	$PainelTelemetria/Margem/Coluna/Acoes/Fechar.pressed.connect(_ao_fechar_telemetria)
	_relogio.timeout.connect(_atualizar_diagnostico)

	_painel.visible = false
	_mensagem.text = ""
	$Coluna/Botoes/Jogar.grab_focus()


func _ao_jogar() -> void:
	if not Sessao.ativa:
		Sessao.iniciar()
	_mensagem.text = ("sessao %s aberta.\nas fases jogaveis entram no Marco 1; "
		+ "a telemetria ja esta coletando.") % Sessao.id_sessao.substr(0, 8)


func _ao_abrir_telemetria() -> void:
	_painel.visible = true
	_atualizar_diagnostico()
	_relogio.start(INTERVALO_DE_ATUALIZACAO_S)


func _ao_fechar_telemetria() -> void:
	_painel.visible = false
	_relogio.stop()
	$Coluna/Botoes/Telemetria.grab_focus()


func _ao_descarregar() -> void:
	await Telemetria.descarregar()
	_atualizar_diagnostico()


func _ao_sair() -> void:
	# Encerrar a sessao e drenar antes de sair e o que transforma "o jogador
	# fechou o jogo" em SESSAO_ENCERRADA em vez de sessao pendurada em ABERTA.
	if Sessao.ativa:
		Sessao.encerrar()
	await Telemetria.descarregar()
	get_tree().quit()


func _atualizar_diagnostico() -> void:
	var config: Dictionary = ConfigJogo.resumo_seguro()
	var fila: Dictionary = Telemetria.estatisticas()

	var linhas: PackedStringArray = PackedStringArray([
		"[b]configuracao[/b]",
		"modo: %s" % config["modo_telemetria"],
		"url: %s" % config["url_api"],
		"chave definida: %s" % ("sim" if bool(config["chave_api_definida"]) else "nao"),
		"id_sujeito: %s" % config["id_sujeito"],
		"versao: %s | plataforma: %s" % [config["versao_jogo"], config["plataforma"]],
		"",
		"[b]fila[/b]",
		"transporte: %s" % fila["transporte"],
		"sessao: %s" % ("aberta" if bool(fila["sessao_aberta"]) else "fechada"),
		"proxima sequencia: %d" % int(fila["proxima_sequencia"]),
		"eventos na fila: %d" % int(fila["eventos_na_fila"]),
		"tentativas na fila: %d" % int(fila["tentativas_na_fila"]),
		"falhas consecutivas: %d" % int(fila["falhas_consecutivas"]),
		"itens descartados: %d" % int(fila["itens_descartados"]),
	])

	_diagnostico.clear()
	_diagnostico.append_text("\n".join(linhas))
