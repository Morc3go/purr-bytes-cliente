class_name ResumoTelemetria
extends RefCounted

## Agrega os registros de telemetria nos numeros que o Dashboard mostra
## (Figura 7 da monografia): acertos x erros e tempo de resolucao por fase.
##
## Logica pura, sem no nenhum -- e o que torna a agregacao testavel sem abrir a
## tela, do mesmo jeito que DemonstracaoCifra e testavel sem abrir o painel da
## cifra. A tela so desenha o que este arquivo calcula.
##
## As fases sao agrupadas por `id_fase`, nunca pelo numero: numa ferramenta em
## que o professor cria fases livremente, o numero nao identifica nada (duas
## fases podem nascer "5"). O titulo entra so como rotulo legivel.

class ResumoDeFase:
	extends RefCounted
	var id_fase: String = ""
	var titulo: String = ""
	var acertos: int = 0
	var erros: int = 0
	var soma_tempo_ms: int = 0

	func tentativas() -> int:
		return acertos + erros

	func tempo_medio_ms() -> float:
		return float(soma_tempo_ms) / float(tentativas()) if tentativas() > 0 else 0.0

	func taxa_de_acerto() -> float:
		return float(acertos) / float(tentativas()) if tentativas() > 0 else 0.0

	## Como a fase aparece na tela: o titulo quando ha um, senao o id abreviado.
	## Nunca "Nivel 1/2" fixo -- as fases sao livres.
	func rotulo() -> String:
		if not titulo.strip_edges().is_empty():
			return titulo
		if not id_fase.is_empty():
			return "fase %s" % id_fase.substr(0, 8)
		return "(sem fase)"


var acertos: int = 0
var erros: int = 0
var sessoes: int = 0
var por_fase: Array[ResumoDeFase] = []


func tentativas() -> int:
	return acertos + erros


func taxa_de_acerto() -> float:
	return float(acertos) / float(tentativas()) if tentativas() > 0 else 0.0


func vazio() -> bool:
	return tentativas() == 0 and sessoes == 0


## Monta o resumo a partir das linhas do JSONL do modo MOCK, no formato
## {"tipo_registro": ..., "dados": {...}} -- o mesmo que iria para a rede.
static func de_registros(registros: Array[Dictionary]) -> ResumoTelemetria:
	var resumo := ResumoTelemetria.new()
	var indice: Dictionary = {}          # chave da fase -> ResumoDeFase
	var sessoes_vistas: Dictionary = {}

	for registro: Dictionary in registros:
		var tipo: String = String(registro.get("tipo_registro", ""))
		var dados: Dictionary = registro.get("dados", {}) as Dictionary
		if dados.is_empty():
			continue

		var id_sessao: String = String(dados.get("id_sessao", ""))
		if not id_sessao.is_empty():
			sessoes_vistas[id_sessao] = true

		if tipo != "tentativa":
			continue

		var resultado: String = String(dados.get("resultado", ""))
		# ABANDONO e TIMEOUT nao sao nem acerto nem erro de conhecimento: o
		# jogador nao respondeu. Conta-los como erro inflaria a taxa de erro
		# com desistencia, que e outro fenomeno.
		if resultado != CatalogoResultados.SUCESSO \
				and not resultado.begins_with("ERRO_"):
			continue

		var chave: String = String(dados.get("id_fase", ""))
		if chave.is_empty():
			chave = String(dados.get("titulo_fase", ""))
		if chave.is_empty():
			chave = "(sem fase)"

		if not indice.has(chave):
			var nova := ResumoDeFase.new()
			nova.id_fase = String(dados.get("id_fase", ""))
			nova.titulo = String(dados.get("titulo_fase", ""))
			indice[chave] = nova
			resumo.por_fase.append(nova)

		var fase: ResumoDeFase = indice[chave]
		if fase.titulo.is_empty():
			fase.titulo = String(dados.get("titulo_fase", ""))

		if resultado == CatalogoResultados.SUCESSO:
			fase.acertos += 1
			resumo.acertos += 1
		else:
			fase.erros += 1
			resumo.erros += 1
		fase.soma_tempo_ms += maxi(0, int(dados.get("tempo_resposta_ms", 0)))

	resumo.sessoes = sessoes_vistas.size()
	# Mais tentativas primeiro: a fase mais exercitada e a que mais interessa
	# olhar, e a ordem fica estavel entre aberturas da tela.
	resumo.por_fase.sort_custom(func(a: ResumoDeFase, b: ResumoDeFase) -> bool:
		return a.tentativas() > b.tentativas())
	return resumo


## Le um arquivo JSONL (uma linha por registro). Linha corrompida e pulada, nao
## derruba a leitura: o arquivo pode ter sido cortado por um processo morto no
## meio da escrita, e o resto continua valendo.
static func ler_jsonl(caminho: String) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	if caminho.is_empty() or not FileAccess.file_exists(caminho):
		return saida

	var arquivo: FileAccess = FileAccess.open(caminho, FileAccess.READ)
	if arquivo == null:
		return saida

	while not arquivo.eof_reached():
		var linha: String = arquivo.get_line().strip_edges()
		if linha.is_empty():
			continue
		var lido: Variant = JSON.parse_string(linha)
		if typeof(lido) == TYPE_DICTIONARY:
			saida.append(lido as Dictionary)
	arquivo.close()
	return saida


## O corpo do "Exportar JSON": os mesmos numeros da tela, em formato que abre em
## qualquer planilha ou script de analise.
func para_dicionario() -> Dictionary:
	var fases: Array[Dictionary] = []
	for fase: ResumoDeFase in por_fase:
		fases.append({
			"id_fase": fase.id_fase,
			"titulo_fase": fase.titulo,
			"tentativas": fase.tentativas(),
			"acertos": fase.acertos,
			"erros": fase.erros,
			"taxa_de_acerto": fase.taxa_de_acerto(),
			"tempo_medio_ms": fase.tempo_medio_ms(),
		})

	return {
		"gerado_em": Relogio.agora_utc_iso(),
		"sessoes": sessoes,
		"tentativas": tentativas(),
		"acertos": acertos,
		"erros": erros,
		"taxa_de_acerto": taxa_de_acerto(),
		"por_fase": fases,
	}
