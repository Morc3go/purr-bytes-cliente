extends SceneTree

## Grava o video de demonstracao do jogo (roteiro em roteiro_video_demonstracao.gd).
##
##   godot --path . --write-movie <saida.avi> --fixed-fps 30 --resolution 1280x720 \
##       --script res://tools/video_demonstracao.gd [-- --fundo=piquenique]
##
## --fundo escolhe o wallpaper da galeria que da o tema (menu, telas, legendas e
## cartelas); sem ele, noite.
##
## Com --write-movie a engine avanca um quadro de 1/30 s por vez e grava cada
## um: o video sai igual em qualquer maquina, sem depender da velocidade dela.
## Usa so dados ficticios, numa pasta isolada (user://testes/video).

const ROTEIRO: String = "res://tools/roteiro_video_demonstracao.gd"


func _initialize() -> void:
	_executar()


func _executar() -> void:
	await process_frame
	var roteiro: RefCounted = load(ROTEIRO).new()
	# Tema do video: --fundo=<nome da galeria> depois de "--" (padrao: noite).
	for argumento: String in OS.get_cmdline_user_args():
		if argumento.begins_with("--fundo="):
			var escolhido: String = argumento.trim_prefix("--fundo=")
			if GaleriaDeFundos.ORDEM.has(escolhido):
				roteiro.set("fundo", escolhido)
	await roteiro.call("executar", self)
	quit(0)
