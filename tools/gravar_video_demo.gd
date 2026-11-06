extends SceneTree

## Grava um video de demonstracao das funcoes do jogo, sem ninguem jogando.
##
##   godot --path . --write-movie demo.avi --fixed-fps 30 \
##         --script res://tools/gravar_video_demo.gd
##
## O Movie Maker do Godot (--write-movie) grava cada quadro que a engine
## renderiza, em tempo simulado: o video sai com a mesma duracao em qualquer
## maquina, mesmo que a renderizacao seja lenta. Precisa de janela (no Linux
## sem monitor, rode dentro de xvfb-run).
##
## O roteiro fica em outro arquivo pelo mesmo motivo de capturar_telas.gd: um
## script passado em --script e compilado antes de os autoloads existirem.

const ROTEIRO: String = "res://tools/roteiro_gravar_video.gd"


func _initialize() -> void:
	_executar()


func _executar() -> void:
	await process_frame
	var roteiro: RefCounted = load(ROTEIRO).new()
	await roteiro.call("executar", self)
	quit(0)
