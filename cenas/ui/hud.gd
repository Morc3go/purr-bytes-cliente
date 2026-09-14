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


func _ready() -> void:
	Sessao.vidas_alteradas.connect(_ao_mudar_vidas)
	Sessao.pontuacao_alterada.connect(_ao_mudar_pontuacao)
	_ao_mudar_vidas(Sessao.vidas)
	_ao_mudar_pontuacao(Sessao.pontuacao)
	mostrar_protecao(false, 0.0, "")
	mostrar_pacotes(0, 0)


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
func mostrar_protecao(ativa: bool, restante_s: float, algoritmo: String = "") -> void:
	_protecao.modulate = Color.WHITE
	if ativa:
		_protecao.text = "%s ativa %0.1fs" % [LegendaCores.nome(algoritmo), restante_s]
	else:
		_protecao.text = "texto claro"


func _ao_mudar_vidas(vidas: int) -> void:
	_vidas.text = "vidas %d" % vidas


func _ao_mudar_pontuacao(pontuacao: int) -> void:
	_pontuacao.text = "pontos %d" % pontuacao
