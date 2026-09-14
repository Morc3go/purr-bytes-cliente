extends Control

## Dashboard de Telemetria -- a tela da Figura 7 da monografia.
##
## Mostra o que foi COLETADO, no vocabulario de quem vai analisar: quantos
## acertos contra quantos erros, e quanto tempo cada fase levou para ser
## resolvida. Nao e o painel de diagnostico tecnico (fila, transporte, sequencia)
## -- esse continua existindo e abre por um botao daqui, porque serve a outra
## pergunta: "a coleta esta funcionando?" em vez de "o que a coleta diz?".
##
## As fases sao rotuladas por titulo/id_fase, nunca "Nivel 1" e "Nivel 2" fixos:
## como as fases sao criadas livremente, rotulo fixo mentiria na primeira fase
## nova. A figura da monografia e um esboco de baixa fidelidade; adaptar o
## rotulo mantendo a informacao e o esperado.
##
## FONTE DOS DADOS: o JSONL do modo MOCK, que e o registro local da coleta. Em
## modo HTTP o historico vive no servidor e o cliente nao guarda copia -- a tela
## diz isso em vez de mostrar um grafico vazio como se nao houvesse dado.

const CENA_DO_MENU: String = "res://cenas/ui/menu_principal.tscn"
const CAMINHO_DA_EXPORTACAO: String = "user://resumo_telemetria.json"

@onready var _grafico: Control = $Raiz/Margem/Coluna/Corpo/Grafico
@onready var _tabela: RichTextLabel = $Raiz/Margem/Coluna/Corpo/Tabela
@onready var _cabecalho: Label = $Raiz/Margem/Coluna/Cabecalho
@onready var _rodape: Label = $Raiz/Margem/Coluna/Rodape
@onready var _painel_diagnostico: PanelContainer = $PainelDiagnostico
@onready var _diagnostico: RichTextLabel = $PainelDiagnostico/Margem/Coluna/Diagnostico

var _resumo: ResumoTelemetria = ResumoTelemetria.new()


func _ready() -> void:
	$Raiz/Margem/Coluna/Acoes/Atualizar.pressed.connect(_carregar)
	$Raiz/Margem/Coluna/Acoes/Exportar.pressed.connect(_ao_exportar)
	$Raiz/Margem/Coluna/Acoes/Diagnostico.pressed.connect(_ao_abrir_diagnostico)
	$Raiz/Margem/Coluna/Acoes/Voltar.pressed.connect(_ao_voltar)
	$PainelDiagnostico/Margem/Coluna/Fechar.pressed.connect(_ao_fechar_diagnostico)
	_grafico.draw.connect(_desenhar_grafico)

	_painel_diagnostico.visible = false
	_carregar()
	$Raiz/Margem/Coluna/Acoes/Voltar.grab_focus()


func _carregar() -> void:
	var caminho: String = Telemetria.caminho_do_registro_local()
	_resumo = ResumoTelemetria.de_registros(ResumoTelemetria.ler_jsonl(caminho))

	if caminho.is_empty():
		_cabecalho.text = "modo HTTP: o historico esta no servidor, nao no cliente."
	elif _resumo.vazio():
		_cabecalho.text = "nenhuma partida registrada ainda -- jogue uma fase e volte aqui."
	else:
		_cabecalho.text = "%d sessao(oes) - %d tentativa(s) - %.0f%% de acerto" % [
			_resumo.sessoes, _resumo.tentativas(), _resumo.taxa_de_acerto() * 100.0]

	_montar_tabela()
	_grafico.queue_redraw()


## Barras desenhadas a mao (e nao um addon de grafico) porque sao duas: o custo
## de uma dependencia nova nao se paga, e _draw da controle total sobre o
## contraste, que e o ponto fraco historico das telas deste projeto.
func _desenhar_grafico() -> void:
	const COR_ACERTO: Color = Color(0.40, 0.82, 0.52)
	const COR_ERRO: Color = Color(0.90, 0.45, 0.45)
	const COR_EIXO: Color = Color(0.55, 0.58, 0.66)
	const COR_TEXTO: Color = Color(0.92, 0.93, 0.96)

	var area: Vector2 = _grafico.size
	var fonte: Font = ThemeDB.fallback_font
	var altura_util: float = area.y - 24.0

	# Linha de base: sem ela, barra zerada e area vazia ficam iguais.
	_grafico.draw_line(Vector2(0, altura_util), Vector2(area.x, altura_util), COR_EIXO, 1.0)

	var total: int = maxi(1, maxi(_resumo.acertos, _resumo.erros))
	var largura_barra: float = minf(64.0, area.x / 4.0)
	var dados: Array[Dictionary] = [
		{"rotulo": "acertos", "valor": _resumo.acertos, "cor": COR_ACERTO},
		{"rotulo": "erros", "valor": _resumo.erros, "cor": COR_ERRO},
	]

	for i: int in dados.size():
		var valor: int = int(dados[i]["valor"])
		var altura: float = (float(valor) / float(total)) * (altura_util - 14.0)
		var x: float = area.x * 0.25 + float(i) * (area.x * 0.3) - largura_barra / 2.0
		var topo: float = altura_util - altura

		_grafico.draw_rect(Rect2(x, topo, largura_barra, altura), dados[i]["cor"])
		_grafico.draw_string(fonte, Vector2(x, topo - 3.0), str(valor),
			HORIZONTAL_ALIGNMENT_LEFT, largura_barra, 10, COR_TEXTO)
		_grafico.draw_string(fonte, Vector2(x, altura_util + 12.0), String(dados[i]["rotulo"]),
			HORIZONTAL_ALIGNMENT_LEFT, largura_barra + 20.0, 9, COR_TEXTO)


func _montar_tabela() -> void:
	var linhas: PackedStringArray = PackedStringArray([
		"[b]tempo de resolucao por fase[/b]",
		"",
	])

	if _resumo.por_fase.is_empty():
		linhas.append("sem tentativas registradas.")
	else:
		linhas.append("[b]%-22s %6s %7s %10s[/b]" % ["fase", "tent.", "acerto", "tempo med."])
		for fase: ResumoTelemetria.ResumoDeFase in _resumo.por_fase:
			linhas.append("%-22s %6d %6.0f%% %8.1fs" % [
				fase.rotulo().substr(0, 22),
				fase.tentativas(),
				fase.taxa_de_acerto() * 100.0,
				fase.tempo_medio_ms() / 1000.0,
			])

	_tabela.clear()
	_tabela.append_text("\n".join(linhas))


func _ao_exportar() -> void:
	# Drena a fila antes de exportar: o que ainda esta em memoria tambem e dado
	# da partida, e exportar sem isso daria um retrato incompleto.
	await Telemetria.descarregar()
	_carregar()

	var arquivo: FileAccess = FileAccess.open(CAMINHO_DA_EXPORTACAO, FileAccess.WRITE)
	if arquivo == null:
		_rodape.text = "falha ao escrever %s (erro %d)" % [
			CAMINHO_DA_EXPORTACAO, FileAccess.get_open_error()]
		return

	arquivo.store_string(JSON.stringify(_resumo.para_dicionario(), "\t"))
	arquivo.close()
	_rodape.text = "exportado para %s" % ProjectSettings.globalize_path(CAMINHO_DA_EXPORTACAO)


func _ao_abrir_diagnostico() -> void:
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
	_painel_diagnostico.visible = true
	$PainelDiagnostico/Margem/Coluna/Fechar.grab_focus()


func _ao_fechar_diagnostico() -> void:
	_painel_diagnostico.visible = false
	$Raiz/Margem/Coluna/Acoes/Diagnostico.grab_focus()


func _ao_voltar() -> void:
	get_tree().change_scene_to_file(CENA_DO_MENU)
