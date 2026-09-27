extends SceneTree

## Verifica, de ponta a ponta, se o jogo consegue entregar telemetria a API.
##
##   godot --headless --path . --script res://tools/verificar_backend.gd -- <url> <chave>
##
## Sem argumentos usa url_api e chave_api do config.cfg. Joga uma sessao curta
## da fase de exemplo em modo HTTP (comando errado, cifra certa, captura,
## conclusao), drena a fila e diz se algo foi recusado ou descartado. Serve
## para conferir a API ANTES de uma coleta: e ela que pegou o id_fase vazio
## que fazia o back-end recusar todos os eventos (ver back/.../V8).
##
## O roteiro fica em outro arquivo pelo mesmo motivo de
## sessao_de_demonstracao.gd: um script passado em --script e compilado antes
## de os autoloads existirem.

const ROTEIRO: String = "res://tools/roteiro_verificar_backend.gd"


func _initialize() -> void:
	_executar()


func _executar() -> void:
	await process_frame
	var roteiro: RefCounted = load(ROTEIRO).new()
	var ok: bool = await roteiro.call("executar", self, OS.get_cmdline_user_args())
	quit(0 if ok else 1)
