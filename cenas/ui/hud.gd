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
@onready var _titulo: Label = $Raiz/Linha/Titulo
@onready var _protecao: Label = $Raiz/Linha/Protecao


func _ready() -> void:
	Sessao.vidas_alteradas.connect(_ao_mudar_vidas)
	Sessao.pontuacao_alterada.connect(_ao_mudar_pontuacao)
	_ao_mudar_vidas(Sessao.vidas)
	_ao_mudar_pontuacao(Sessao.pontuacao)
	mostrar_protecao(false, 0.0)


func definir_titulo(texto: String) -> void:
	_titulo.text = texto


func mostrar_protecao(ativa: bool, restante_s: float) -> void:
	if ativa:
		_protecao.text = "cifra ativa %0.1fs" % restante_s
	else:
		_protecao.text = "texto claro"


func _ao_mudar_vidas(vidas: int) -> void:
	_vidas.text = "vidas %d" % vidas


func _ao_mudar_pontuacao(pontuacao: int) -> void:
	_pontuacao.text = "pontos %d" % pontuacao
