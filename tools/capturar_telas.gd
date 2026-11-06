extends SceneTree

## Tira prints das telas principais para a monografia e para o README.
##
##   godot --path . --script res://tools/capturar_telas.gd -- <pasta_de_saida>
##
## Precisa de janela (nao roda com --headless: sem renderizador nao ha imagem).
## O roteiro fica em outro arquivo pelo mesmo motivo de verificar_backend.gd:
## um script passado em --script e compilado antes de os autoloads existirem.

const ROTEIRO: String = "res://tools/roteiro_capturar_telas.gd"


func _initialize() -> void:
	_executar()


func _executar() -> void:
	await process_frame
	var argumentos: PackedStringArray = OS.get_cmdline_user_args()
	var pasta: String = argumentos[0] if argumentos.size() > 0 else "user://capturas"
	var roteiro: RefCounted = load(ROTEIRO).new()
	await roteiro.call("executar", self, pasta)
	quit(0)
