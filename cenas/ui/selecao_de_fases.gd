extends Control

## Tela de selecao de fases: lista os .json de user://fases e age sobre a
## escolhida.
##
## A lista e a UNICA porta para as fases de autoria -- por isso ela mostra
## titulo e um resumo (quantos vigias, quantos terminais) em vez do nome do
## arquivo: o professor pensa em "Senhas fortes", nao em
## "exemplo-senhas-fortes.json".
##
## Fase com JSON quebrado nao some da lista: aparece marcada com o erro. Sumir
## seria pior -- o professor procuraria um arquivo que ele sabe que existe.

const CENA_DO_MENU: String = "res://cenas/ui/menu_principal.tscn"
const CENA_DO_EDITOR: String = "res://cenas/ui/editor_de_fase.tscn"
const CENA_DA_ESCOLHA_DE_GATO: String = "res://cenas/ui/escolha_de_gato.tscn"
const CENA_DA_ESCOLHA_DE_CENARIO: String = "res://cenas/ui/escolha_de_cenario.tscn"

@onready var _lista: ItemList = $Raiz/Margem/Coluna/Corpo/Lista
@onready var _detalhe: RichTextLabel = $Raiz/Margem/Coluna/Corpo/Detalhe
@onready var _rodape: Label = $Raiz/Margem/Coluna/Rodape
@onready var _confirmacao: ConfirmationDialog = $ConfirmacaoDeExclusao

var _caminhos: PackedStringArray = PackedStringArray()
## Tela "escolha seu gatinho" aberta por cima da lista (ADR 0030), ou null.
var _escolha_de_gato: EscolhaDeGato = null
## Tela "escolha o cenario", aberta depois do gatinho (ADR 0036), ou null.
var _escolha_de_cenario: EscolhaDeCenario = null


func _ready() -> void:
	# Mesma cara do menu: vidro fosco sobre o wallpaper, vinhas em volta e os
	# baloes no tom do fundo escolhido (ADR 0034).
	EnfeiteDaGaleria.enfeitar(self, [$Raiz] as Array[Control])
	$Raiz/Margem/Coluna/Acoes/Jogar.pressed.connect(_ao_jogar)
	$Raiz/Margem/Coluna/Acoes/Editar.pressed.connect(_ao_editar)
	$Raiz/Margem/Coluna/Acoes/Exportar.pressed.connect(_ao_exportar)
	$Raiz/Margem/Coluna/Acoes/Excluir.pressed.connect(_ao_pedir_exclusao)
	$DialogoDeExportacao.file_selected.connect(_ao_escolher_destino)
	$Raiz/Margem/Coluna/Acoes/Voltar.pressed.connect(_ao_voltar)
	_lista.item_selected.connect(_ao_selecionar)
	_lista.item_activated.connect(func(_indice: int) -> void: _ao_jogar())
	_confirmacao.confirmed.connect(_ao_confirmar_exclusao)

	_recarregar()


func _recarregar() -> void:
	_lista.clear()
	_caminhos = CarregadorFaseJson.listar()

	if _caminhos.is_empty():
		_detalhe.clear()
		_detalhe.append_text("nenhuma fase ainda.\n\nuse [b]criar fase[/b] no menu para montar a primeira.")
		_definir_acoes_habilitadas(false)
		return

	for caminho: String in _caminhos:
		var resultado: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_arquivo(caminho)
		if resultado.ok():
			_lista.add_item(resultado.config.titulo)
		else:
			# Marcada, nao escondida: o professor precisa saber qual arquivo
			# quebrou para poder consertar ou excluir.
			_lista.add_item("%s  (com erro)" % caminho.get_file())

	_lista.select(0)
	_ao_selecionar(0)


func _ao_selecionar(indice: int) -> void:
	if indice < 0 or indice >= _caminhos.size():
		return

	var caminho: String = _caminhos[indice]
	var resultado: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_arquivo(caminho)

	_detalhe.clear()
	if not resultado.ok():
		_detalhe.append_text("[b]%s[/b]\n\n[color=#ffb4a8]esta fase não pode ser jogada:[/color]\n%s"
			% [caminho.get_file(), resultado.mensagem()])
		# Excluir continua valendo: e como o professor se livra de um arquivo ruim.
		$Raiz/Margem/Coluna/Acoes/Jogar.disabled = true
		$Raiz/Margem/Coluna/Acoes/Editar.disabled = true
		$Raiz/Margem/Coluna/Acoes/Excluir.disabled = false
		return

	_definir_acoes_habilitadas(true)
	var config: FaseConfig = resultado.config
	var vigias: int = config.cachorros.size()
	var so_perseguem: int = 0
	for cachorro: CachorroConfig in config.cachorros:
		if cachorro.apenas_persegue():
			so_perseguem += 1

	_detalhe.append_text("\n".join(PackedStringArray([
		"[b]%s[/b]" % config.titulo,
		"",
		config.briefing_pedagogico if not config.briefing_pedagogico.is_empty()
			else "[i]sem briefing[/i]",
		"",
		"vidas: %d" % config.vidas_iniciais,
		"vigias: %d (%d só perseguem)" % [vigias, so_perseguem],
		"terminais: %d" % config.pacotes.size(),
		"mapa: %dx%d" % [config.mapa.largura(), config.mapa.altura()],
		"cenário: %s" % CenarioDoLabirinto.nome(config.cenario),
		"arquivo: %s" % caminho.get_file(),
	])))


func _definir_acoes_habilitadas(habilitadas: bool) -> void:
	$Raiz/Margem/Coluna/Acoes/Jogar.disabled = not habilitadas
	$Raiz/Margem/Coluna/Acoes/Editar.disabled = not habilitadas
	$Raiz/Margem/Coluna/Acoes/Exportar.disabled = not habilitadas
	$Raiz/Margem/Coluna/Acoes/Excluir.disabled = not habilitadas


func _caminho_selecionado() -> String:
	var selecionados: PackedInt32Array = _lista.get_selected_items()
	if selecionados.is_empty():
		return ""
	var indice: int = selecionados[0]
	return _caminhos[indice] if indice < _caminhos.size() else ""


## Jogar primeiro pergunta qual gatinho (ADR 0030); a fase so comeca depois
## da escolha. O arquivo e validado ANTES de perguntar: uma fase quebrada
## mostra o erro na hora, sem fazer o jogador escolher um gato a toa.
func _ao_jogar() -> void:
	var caminho: String = _caminho_selecionado()
	if caminho.is_empty() or _escolha_de_gato != null or _escolha_de_cenario != null:
		return

	var resultado: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_arquivo(caminho)
	if not resultado.ok():
		_rodape.text = "não foi possível jogar: %s" % " | ".join(resultado.erros)
		return

	_abrir_escolha_de_gato(caminho, resultado.config.cenario)


## Primeiro o gatinho (ADR 0030), depois o cenario (ADR 0036), e so entao a fase.
func _abrir_escolha_de_gato(caminho: String, cenario_sugerido: String) -> void:
	_escolha_de_gato = (load(CENA_DA_ESCOLHA_DE_GATO) as PackedScene).instantiate() as EscolhaDeGato
	_escolha_de_gato.escolhido.connect(_ao_escolher_gato.bind(caminho, cenario_sugerido))
	_escolha_de_gato.cancelado.connect(_fechar_escolha_de_gato)
	add_child(_escolha_de_gato)


func _ao_escolher_gato(pelagem: String, caminho: String, cenario_sugerido: String) -> void:
	PelagemGato.salvar_preferida(pelagem)
	_fechar_escolha_de_gato(false)
	_escolha_de_cenario = (load(CENA_DA_ESCOLHA_DE_CENARIO) as PackedScene).instantiate() as EscolhaDeCenario
	_escolha_de_cenario.sugerido = cenario_sugerido
	_escolha_de_cenario.escolhido.connect(_ao_escolher_cenario.bind(caminho, pelagem))
	# Esc no cenario volta para o gatinho, que ja abre no gato escolhido.
	_escolha_de_cenario.cancelado.connect(func() -> void:
		_fechar_escolha_de_cenario()
		_abrir_escolha_de_gato(caminho, cenario_sugerido))
	add_child(_escolha_de_cenario)


func _ao_escolher_cenario(cenario: String, caminho: String, pelagem: String) -> void:
	if not Sessao.ativa:
		Sessao.iniciar()

	var erros: PackedStringArray = IniciadorDeFase.jogar_arquivo(get_tree(), caminho, pelagem, cenario)
	if not erros.is_empty():
		_fechar_escolha_de_cenario()
		_rodape.text = "não foi possível jogar: %s" % " | ".join(erros)


func _fechar_escolha_de_gato(devolver_foco: bool = true) -> void:
	if _escolha_de_gato != null:
		_escolha_de_gato.queue_free()
		_escolha_de_gato = null
	if devolver_foco:
		$Raiz/Margem/Coluna/Acoes/Jogar.grab_focus()


func _fechar_escolha_de_cenario() -> void:
	if _escolha_de_cenario != null:
		_escolha_de_cenario.queue_free()
		_escolha_de_cenario = null
	$Raiz/Margem/Coluna/Acoes/Jogar.grab_focus()


func _ao_editar() -> void:
	var caminho: String = _caminho_selecionado()
	if caminho.is_empty():
		return
	# O editor le o caminho daqui; e a unica informacao que precisa atravessar
	# a troca de tela, e um caminho de arquivo nao justifica um autoload.
	if not ResourceLoader.exists(CENA_DO_EDITOR):
		_rodape.text = "o editor visual entra na próxima etapa da reconstrução."
		return
	EditorDeFaseEstado.caminho_para_editar = caminho
	get_tree().change_scene_to_file(CENA_DO_EDITOR)


## Exportar grava o .json da fase escolhida onde o professor mandar -- e o par
## de "subir": exportar num computador e subir em outro leva a fase inteira,
## porque o arquivo JA e a fase (o mapa viaja como semente, nao desenhado).
func _ao_exportar() -> void:
	var caminho: String = _caminho_selecionado()
	if caminho.is_empty():
		return
	$DialogoDeExportacao.current_file = caminho.get_file()
	$DialogoDeExportacao.popup_centered()


func _ao_escolher_destino(destino: String) -> void:
	var origem: String = _caminho_selecionado()
	if origem.is_empty():
		return

	var resultado: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_arquivo(origem)
	if not resultado.ok():
		_rodape.text = "a fase está inválida e não foi exportada."
		return

	var erros: PackedStringArray = CarregadorFaseJson.salvar(resultado.config, destino)
	if not erros.is_empty():
		_rodape.text = "falha ao exportar: %s" % " | ".join(erros)
		return
	_rodape.text = "exportada para %s" % destino


func _ao_pedir_exclusao() -> void:
	var caminho: String = _caminho_selecionado()
	if caminho.is_empty():
		return
	# Exclusao de arquivo do professor NUNCA e imediata.
	_confirmacao.dialog_text = "excluir a fase '%s'?\nisto apaga o arquivo e não tem volta." \
		% caminho.get_file()
	_confirmacao.popup_centered()


func _ao_confirmar_exclusao() -> void:
	var caminho: String = _caminho_selecionado()
	if caminho.is_empty():
		return

	var erro: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho))
	if erro != OK:
		_rodape.text = "não foi possível excluir %s (erro %d)" % [caminho.get_file(), erro]
		return

	_rodape.text = "fase '%s' excluida." % caminho.get_file()
	_recarregar()


func _ao_voltar() -> void:
	get_tree().change_scene_to_file(CENA_DO_MENU)
