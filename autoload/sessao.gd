extends Node

## Autoload Sessao -- estado da partida corrente.
##
## Guarda o que atravessa as fases: id_sessao, fase atual, vidas e pontuacao.
## Nao guarda o contador de sequencia da telemetria (ele mora em Telemetria, com
## a justificativa escrita no cabecalho daquele arquivo).
##
## Nao conhece cena nenhuma: quem entra e sai de fase avisa por chamada, e a UI
## escuta os sinais. E a direcao de comunicacao da secao 9 do CLAUDE.md -- sinal
## de baixo para cima, chamada de cima para baixo.
##
## Nao ha nada de pessoal aqui. id_sessao e um UUID sorteado a cada partida;
## id_sujeito vive em ConfigJogo e e pseudonimo (secao 4, restricao 1).

signal sessao_iniciada(id_sessao: String)
signal sessao_encerrada(id_sessao: String, status: String)
signal vidas_alteradas(vidas: int)
signal pontuacao_alterada(pontuacao: int)
signal fase_alterada(numero: int)
signal vidas_esgotadas()

var id_sessao: String = ""
## 0 = fora de fase (menu). 1..4 = fase jogavel.
var fase_atual: int = 0
var vidas: int = 0
var pontuacao: int = 0
var ativa: bool = false


func iniciar() -> String:
	if ativa:
		Registro.aviso("Sessao", "iniciar() com sessao ativa; encerrando a anterior")
		encerrar(Telemetria.STATUS_ABANDONADA)

	id_sessao = Identificador.uuid_v4()
	fase_atual = 0
	vidas = 0
	pontuacao = 0
	ativa = true

	Telemetria.iniciar_sessao(id_sessao, ConfigJogo.id_sujeito)
	Registro.info("Sessao", "sessao iniciada: %s" % id_sessao)
	sessao_iniciada.emit(id_sessao)
	return id_sessao


func encerrar(status: String = "") -> void:
	if not ativa:
		return
	var status_final: String = status if status != "" else Telemetria.STATUS_ENCERRADA

	Telemetria.encerrar_sessao(status_final)
	ativa = false
	fase_atual = 0
	Registro.info("Sessao", "sessao encerrada (%s): %s" % [status_final, id_sessao])
	sessao_encerrada.emit(id_sessao, status_final)


## Chamado por fase_base.gd ao entrar em uma fase. As vidas iniciais vem do
## FaseConfig, nunca de constante em codigo (secao 9: zero numero magico).
func entrar_na_fase(numero: int, vidas_iniciais: int) -> void:
	fase_atual = clampi(numero, 1, 4)
	vidas = maxi(1, vidas_iniciais)
	fase_alterada.emit(fase_atual)
	vidas_alteradas.emit(vidas)


func sair_da_fase() -> void:
	fase_atual = 0
	fase_alterada.emit(fase_atual)


## Captura custa vida e pontos, mas nao expulsa do jogo: o erro e custo
## pedagogico, nao punicao (secao 6 do CLAUDE.md).
func perder_vida() -> int:
	vidas = maxi(0, vidas - 1)
	vidas_alteradas.emit(vidas)
	if vidas == 0:
		vidas_esgotadas.emit()
	return vidas


func repor_vidas(quantidade: int) -> void:
	vidas = maxi(1, quantidade)
	vidas_alteradas.emit(vidas)


func somar_pontos(delta: int) -> int:
	# Pontuacao pode ficar negativa? Nao: um numero negativo na tela desestimula
	# quem mais precisa continuar tentando, e a metrica de aprendizado vem da
	# tentativa_comando, nao do placar.
	pontuacao = maxi(0, pontuacao + delta)
	pontuacao_alterada.emit(pontuacao)
	return pontuacao


func sem_vidas() -> bool:
	return vidas <= 0
