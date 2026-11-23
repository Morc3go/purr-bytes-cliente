extends SceneTree

## Gera as figuras de resultados da monografia (ADR 0021): joga a trilha de
## demonstracao com participantes ficticios e salva cada tela usada no texto.
##
##   godot --path . --script res://tools/figuras_monografia.gd -- <pasta_de_saida>
##
## Precisa de janela (nao roda com --headless: sem renderizador nao ha imagem).
## O roteiro fica em outro arquivo pelo mesmo motivo de verificar_backend.gd:
## um script passado em --script e compilado antes de os autoloads existirem.

const ROTEIRO: String = "res://tools/roteiro_figuras_monografia.gd"


func _initialize() -> void:
	_executar()


func _executar() -> void:
	await process_frame
	var argumentos: PackedStringArray = OS.get_cmdline_user_args()
	var pasta: String = argumentos[0] if argumentos.size() > 0 else "user://figuras_monografia"
	var roteiro: RefCounted = load(ROTEIRO).new()
	await roteiro.call("executar", self, pasta)
	quit(0)
