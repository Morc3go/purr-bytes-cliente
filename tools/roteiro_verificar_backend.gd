extends RefCounted

## Roteiro de tools/verificar_backend.gd (carregado quando os autoloads ja
## existem). Nao grava nada em user://fases nem na fila real: usa
## user://testes/verificacao_backend.json.

const FILA: String = "user://testes/verificacao_backend.json"
const TENTATIVAS_DE_DRENAR: int = 10

var _falhas: PackedStringArray = PackedStringArray()


func _ao_falhar(rota: String, detalhe: String, permanente: bool) -> void:
	_falhas.append("%s em %s: %s" % ["recusa (4xx)" if permanente else "falha transitoria",
		rota, detalhe])


func executar(arvore: SceneTree, argumentos: PackedStringArray) -> bool:
	var config: Node = arvore.root.get_node("ConfigJogo")
	var telemetria: Node = arvore.root.get_node("Telemetria")
	var sessao: Node = arvore.root.get_node("Sessao")

	var url: String = argumentos[0] if argumentos.size() > 0 else String(config.get("url_api"))
	var chave: String = argumentos[1] if argumentos.size() > 1 else String(config.get("chave_api"))
	print("verificando %s (chave %s)" % [url, "definida" if not chave.is_empty() else "AUSENTE"])

	DirAccess.make_dir_recursive_absolute("user://testes")
	if FileAccess.file_exists(FILA):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FILA))
	telemetria.call("reiniciar", TransporteHttp.new(url, chave), FILA)
	telemetria.falha_de_envio.connect(_ao_falhar)

	sessao.call("iniciar")
	var lido: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_texto(
		JSON.stringify(CarregadorFaseJson._exemplo()))
	var fase: FaseBase = IniciadorDeFase.jogar(arvore, lido.config)
	for i: int in 5:
		await arvore.process_frame
	fase._ao_submeter_comando("cyfrar senha chave=3", 2000)
	fase._ao_submeter_comando("cifrar senha chave=3", 1500)
	fase._ao_encostar_no_jogador(fase.jogador, fase.cachorros[fase.cachorros.size() - 1])
	fase.tela_captura.encerrar_agora()
	for i: int in 3:
		await arvore.process_frame
	fase.concluir()
	for i: int in 3:
		await arvore.process_frame
	sessao.call("encerrar")

	for i: int in TENTATIVAS_DE_DRENAR:
		await telemetria.call("descarregar")
		if telemetria.call("fila_vazia") or not _falhas.is_empty():
			break
		await arvore.create_timer(0.5).timeout

	var estado: Dictionary = telemetria.call("estatisticas")
	var ok: bool = _falhas.is_empty() and bool(telemetria.call("fila_vazia")) \
		and int(estado["itens_descartados"]) == 0
	print("sessao %s: %d evento(s) gerado(s), %d descartado(s), fila %s" % [
		estado["id_sessao"], int(estado["proxima_sequencia"]), int(estado["itens_descartados"]),
		"vazia" if telemetria.call("fila_vazia") else "COM PENDENCIAS"])
	for falha: String in _falhas:
		print("  - ", falha)
	print("RESULTADO: %s" % ("OK -- a API recebeu a sessao inteira" if ok else "FALHOU"))
	return ok
