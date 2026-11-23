extends SceneTree

## Gera a miniatura de cada cenario (recursos/arte/cenarios/<nome>/previa.png)
## usada na escolha do cenario (ADR 0036), recortada do proprio jogo.
##
##   godot --path . --resolution 640x360 --script res://tools/gerar_previas_de_cenarios.gd
##
## Precisa de janela (nao roda com --headless). Rode de novo se a arte de um
## cenario mudar (tools/arte/montar_cenarios.py).

const ROTEIRO: String = "res://tools/roteiro_previas_de_cenarios.gd"


func _initialize() -> void:
	_executar()


func _executar() -> void:
	await process_frame
	var roteiro: RefCounted = load(ROTEIRO).new()
	await roteiro.call("executar", self)
	quit(0)
