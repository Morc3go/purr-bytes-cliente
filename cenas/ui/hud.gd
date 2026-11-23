class_name Hud
extends CanvasLayer

## Placar de vidas, pontuacao e fase.
##
## Escuta os sinais do autoload Sessao em vez de ser atualizado pela fase. Assim
## a fase nao precisa saber que a HUD existe, e uma segunda tela que mostre o
## mesmo estado (a tela de captura, por exemplo) escuta os mesmos sinais sem
## nenhum acoplamento novo.

@onready var _vidas: Label = $Raiz/Linha/Vidas
@onready var _pontuacao: Label = $Raiz/Linha/Pontuacao
@onready var _pacotes: Label = $Raiz/Linha/Pacotes
@onready var _titulo: Label = $Raiz/Linha/Titulo
@onready var _protecao: Label = $Raiz/Linha/Protecao
@onready var _painel_comandos: PanelContainer = $Raiz/Comandos
@onready var _lista_comandos: HBoxContainer = $Raiz/Comandos/Margem/Lista

## Rodape de teclas: o que cada tecla faz, sempre a vista (pedido da equipe).
## Antes o rodape listava o comando de cada cor de vigia; o jogador nao sabia
## nem como abrir o terminal para digitar. Os comandos continuam no terminal
## (texto de abertura, "status" e "dica") e na tela de captura.
const TECLAS: Array[Array] = [
	["T", "abrir o terminal e digitar o comando que cifra"],
	["F4", "ver como a cifra funciona"],
	["Esc", "pausar"],
	["setas", "andar"],
]


func _ready() -> void:
	_vestir_no_tom_do_fundo()
	Sessao.vidas_alteradas.connect(_ao_mudar_vidas)
	Sessao.pontuacao_alterada.connect(_ao_mudar_pontuacao)
	_ao_mudar_vidas(Sessao.vidas)
	_ao_mudar_pontuacao(Sessao.pontuacao)
	mostrar_protecao(false, 0.0, "")
	mostrar_pacotes(0, 0)
	_montar_teclas()


func definir_titulo(texto: String) -> void:
	_titulo.text = texto


## Progresso da coleta. Fica em verde quando completa porque e o momento em que
## a porta destranca -- o jogador precisa perceber isso sem reler o terminal.
func mostrar_pacotes(coletados: int, total: int) -> void:
	_pacotes.visible = total > 0
	_pacotes.text = "pacotes %d/%d" % [coletados, total]
	_pacotes.modulate = Color(0.40, 0.88, 0.52) if coletados >= total and total > 0 else Color.WHITE


## Mostra QUAL cifra esta ativa e por quanto tempo -- "cifra ativa" sozinho nao
## diria ao jogador se ele esta protegido do interceptador que esta vindo.
##
## Em cor neutra, de proposito: a cor e identidade visual do cachorro, nao um
## codigo que diga qual cifra usar. Pintar o aviso com a cor de um algoritmo
## sugeriria uma associacao que o jogo nao promete.
##
## Sem protecao, o aviso some: o "texto claro" fixo no canto poluia a barra e
## a equipe pediu para tirar. O aviso aparece so quando ha algo a dizer.
func mostrar_protecao(ativa: bool, restante_s: float, algoritmo: String = "") -> void:
	_protecao.modulate = Color.WHITE
	_protecao.visible = ativa
	if ativa and algoritmo.is_empty():
		# Protecao por comando livre (fases de autoria): nao ha cifra a nomear.
		_protecao.text = "comando ativo %0.1fs" % restante_s
	elif ativa:
		_protecao.text = "%s ativa %0.1fs" % [LegendaCores.nome(algoritmo), restante_s]
	else:
		_protecao.text = ""


func _ao_mudar_vidas(vidas: int) -> void:
	_vidas.text = "vidas %d" % vidas


func _ao_mudar_pontuacao(pontuacao: int) -> void:
	_pontuacao.text = "pontos %d" % pontuacao


func _montar_teclas() -> void:
	for filho: Node in _lista_comandos.get_children():
		_lista_comandos.remove_child(filho)
		filho.queue_free()
	_painel_comandos.visible = true
	for par: Array in TECLAS:
		var tecla := Label.new()
		tecla.text = String(par[0])
		tecla.add_theme_font_size_override("font_size", 8)
		tecla.add_theme_stylebox_override("normal", _estilo_de_tecla())
		tecla.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_lista_comandos.add_child(tecla)
		var acao := Label.new()
		acao.text = String(par[1])
		acao.add_theme_font_size_override("font_size", 8)
		_lista_comandos.add_child(acao)


## Faixa de cima e rodape de teclas no tom do fundo escolhido na galeria, com
## texto branco, como os paineis (ADR 0034). Aqui nao ha vidro fosco: a faixa
## fica a partida inteira por cima do labirinto e precisa so de uma tinta mais
## firme, sem desfocar o mapa a toda hora.
func _vestir_no_tom_do_fundo() -> void:
	$Raiz.theme = TemaDaGaleria.tema()
	var tinta: Color = TemaDaGaleria.cor_da_tinta()
	var firme := Color(tinta.r, tinta.g, tinta.b, 0.82)
	var faixa := StyleBoxFlat.new()
	faixa.bg_color = firme
	faixa.corner_radius_bottom_left = 6
	faixa.corner_radius_bottom_right = 6
	$Raiz/Faixa.add_theme_stylebox_override(&"panel", faixa)
	var rodape := StyleBoxFlat.new()
	rodape.bg_color = firme
	rodape.set_corner_radius_all(6)
	_painel_comandos.add_theme_stylebox_override(&"panel", rodape)


## A tecla aparece numa "tampinha" de teclado, para ler de relance que aquilo
## e uma tecla e nao parte da frase. A tampinha e a variacao "Tecla" do tema:
## o tom do balao com um contorno branco (ADR 0034).
func _estilo_de_tecla() -> StyleBox:
	return TemaDaGaleria.tema().get_stylebox(&"normal", &"Tecla")


## As teclas do rodape, na ordem: [tecla, acao, tecla, acao, ...]. Para os testes.
func teclas_visiveis() -> PackedStringArray:
	var textos := PackedStringArray()
	if not _painel_comandos.visible:
		return textos
	for filho: Node in _lista_comandos.get_children():
		if filho is Label:
			textos.append((filho as Label).text)
	return textos
