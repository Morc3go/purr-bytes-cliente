extends Control

## Menu principal e painel de diagnostico.
##
## O painel de telemetria nao e enfeite: e por ele que se confere, na maquina da
## escola e sem ferramenta nenhuma instalada, se a coleta esta em MOCK ou HTTP,
## se ha evento preso na fila e qual id_sujeito esta configurado. Ele mostra
## ConfigJogo.resumo_seguro(), que por construcao nao inclui a chave de API.
##
## "Jogar" sempre comeca pela fase 1 -- fase_base.gd e quem encadeia fase 2 e
## fase 3 automaticamente ao concluir cada uma (ver FaseBase.concluir()).

const INTERVALO_DE_ATUALIZACAO_S: float = 1.0
const CENA_DA_FASE_1: String = "res://cenas/fases/fase_01.tscn"

@onready var _menu: VBoxContainer = $Coluna
@onready var _painel: PanelContainer = $PainelTelemetria
@onready var _diagnostico: RichTextLabel = $PainelTelemetria/Margem/Coluna/Diagnostico
@onready var _painel_tutorial: PanelContainer = $PainelTutorial
@onready var _legenda: RichTextLabel = $PainelTutorial/Margem/Coluna/Legenda
@onready var _relogio: Timer = $RelogioDeAtualizacao


func _ready() -> void:
	$Coluna/Botoes/Jogar.pressed.connect(_ao_jogar)
	$Coluna/Botoes/Telemetria.pressed.connect(_ao_abrir_telemetria)
	$Coluna/Botoes/Tutorial.pressed.connect(_ao_abrir_tutorial)
	$Coluna/Botoes/Sair.pressed.connect(_ao_sair)
	$PainelTelemetria/Margem/Coluna/Acoes/Descarregar.pressed.connect(_ao_descarregar)
	$PainelTelemetria/Margem/Coluna/Acoes/Fechar.pressed.connect(_ao_fechar_telemetria)
	$PainelTutorial/Margem/Coluna/Fechar.pressed.connect(_ao_fechar_tutorial)
	_relogio.timeout.connect(_atualizar_diagnostico)

	_painel.visible = false
	_painel_tutorial.visible = false
	_montar_tutorial()
	$Coluna/Botoes/Jogar.grab_focus()


func _ao_jogar() -> void:
	if not Sessao.ativa:
		Sessao.iniciar()
	get_tree().change_scene_to_file(CENA_DA_FASE_1)


func _ao_abrir_telemetria() -> void:
	_painel.visible = true
	_atualizar_diagnostico()
	_relogio.start(INTERVALO_DE_ATUALIZACAO_S)


func _ao_fechar_telemetria() -> void:
	_painel.visible = false
	_relogio.stop()
	$Coluna/Botoes/Telemetria.grab_focus()


func _ao_abrir_tutorial() -> void:
	_painel_tutorial.visible = true
	$PainelTutorial/Margem/Coluna/Fechar.grab_focus()


func _ao_fechar_tutorial() -> void:
	_painel_tutorial.visible = false
	$Coluna/Botoes/Tutorial.grab_focus()


## A tabela e montada de LegendaCores, nunca escrita a mao aqui: o tutorial e a
## "cola" que o jogador consulta antes de encarar os cachorros, e uma cola que
## discorda do jogo e pior do que nenhuma. Mudar uma cor em LegendaCores muda o
## cachorro, o botao da caixa de puzzle, a HUD e esta tela de uma vez so.
##
## AES aparece marcado como fase 4 porque a fase existe no vocabulario do banco
## e ja tem cor reservada, mas nao esta implementada (secao 11 do CLAUDE.md).
func _montar_tutorial() -> void:
	var linhas := PackedStringArray()

	# BLOCO 1 -- a cor escolhe a FERRAMENTA.
	linhas.append("[b]1. a COR do cachorro escolhe a FERRAMENTA[/b]")
	linhas.append("cada cor pede sempre a mesma ferramenta, em qualquer fase:")
	linhas.append("um cachorro verde na fase 3 continua pedindo Cesar.")
	linhas.append("usar a ferramenta errada nao protege -- e o mesmo que atravessar")
	linhas.append("em texto claro.")
	linhas.append("")

	for entrada: Dictionary in LegendaCores.entradas():
		var cor: Color = entrada["cor"]
		var rotulo: String = "%s = %s" % [String(entrada["nome_da_cor"]), String(entrada["nome"])]
		if String(entrada["algoritmo"]) == "AES":
			rotulo += "  (fase 4, ainda nao jogavel)"
		linhas.append("[color=#%s][b]%s[/b][/color]" % [cor.to_html(false), rotulo])
		linhas.append("    %s" % String(entrada["explicacao"]))

	# BLOCO 2 -- a chave e outra coisa, e por isso vem em outro bloco.
	linhas.append("")
	linhas.append("[b]2. a CHAVE e o segredo que faz a ferramenta funcionar[/b]")
	linhas.append("a cor nao e a chave. escolhida a ferramenta pela cor, a chave e o")
	linhas.append("que voce digita no terminal para ela funcionar -- e cada pacote tem")
	linhas.append("a sua (o terminal diz qual, e 'dica' ajuda).")
	linhas.append("")

	for entrada: Dictionary in LegendaCores.entradas():
		var cor: Color = entrada["cor"]
		linhas.append("[color=#%s]%s[/color] pede: %s"
			% [cor.to_html(false), String(entrada["nome"]), String(entrada["chave"])])

	linhas.append("")
	linhas.append("[b]no labirinto[/b]")
	linhas.append("T abre o terminal - F3 mostra o caminho da IA - ESC sai da fase")
	linhas.append("pacotes trancam a porta de saida: colete os tres para ela abrir.")

	_legenda.clear()
	_legenda.append_text("\n".join(linhas))


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
