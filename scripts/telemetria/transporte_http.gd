class_name TransporteHttp
extends TransporteTelemetria

## Transporte HTTP -- ESQUELETO. Corpo real no Marco 3.
##
## Nao esta implementado de proposito: as rotas de ingestao ainda nao existem no
## back-end (docs/arquitetura/visao-geral.md, secao 5: "Entidades JPA e rotas
## REST -- proxima etapa"). Implementar contra um contrato que ninguem pode
## responder produziria codigo nao testavel, e o Marco 3 comeca justamente pelo
## servidor de eco para ter contra o que testar.
##
## O que este arquivo garante hoje: a fronteira existe e tem a forma final, logo
## habilitar HTTP no Marco 3 e preencher enviar() -- nao mexer em Telemetria.
##
## Marco 3, quando for implementado aqui:
##   - HTTPRequest como filho deste no, um por requisicao em voo
##   - header Authorization: Bearer <chave_api> (nunca logar a chave)
##   - 2xx sucesso (a API responde 202: aceito para processar, nao gravado)
##   - 4xx ResultadoEnvio.falha_permanente  -> descarta o lote e loga
##   - 5xx / rede ResultadoEnvio.falha_transitoria -> preserva a fila
##   - flip de disponivel() para true

var url_base: String = ""
var chave_api: String = ""


func _init(url_base_: String = "", chave_api_: String = "") -> void:
	url_base = url_base_
	chave_api = chave_api_


## Telemetria consulta isto antes de escolher o transporte. Enquanto for false,
## configurar modo_telemetria = "HTTP" cai para MOCK com erro visivel, em vez de
## deixar a fila crescer sem destino ate estourar a memoria.
static func disponivel() -> bool:
	return false


func rotulo() -> String:
	return "HTTP(%s)" % url_base


func enviar(_pacote: Dictionary) -> ResultadoEnvio:
	await _ceder_quadro()
	return ResultadoEnvio.falha_transitoria("transporte HTTP chega no Marco 3")


## A rota concreta de cada pacote, ja definida para o Marco 3 nao ter que
## reinventar o mapeamento.
func caminho_da_rota(rota: String, id_sessao: String) -> String:
	match rota:
		ROTA_ABRIR_SESSAO:
			return "/v1/sessoes"
		ROTA_EVENTOS:
			return "/v1/sessoes/%s/eventos" % id_sessao
		ROTA_TENTATIVAS:
			return "/v1/sessoes/%s/tentativas" % id_sessao
		ROTA_ENCERRAR_SESSAO:
			return "/v1/sessoes/%s/encerrar" % id_sessao
		_:
			Registro.erro("TransporteHttp", "rota desconhecida: %s" % rota)
			return ""
