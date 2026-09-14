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


func _ready() -> void:
	$Coluna/Botoes/Jogar.pressed.connect(_ao_jogar)
	$Coluna/Botoes/Telemetria.pressed.connect(_ao_abrir_telemetria)
	$Coluna/Botoes/Sair.pressed.connect(_ao_sair)
	$Coluna/Botoes/Jogar.grab_focus()


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


