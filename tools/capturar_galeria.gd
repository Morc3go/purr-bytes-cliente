extends SceneTree

## Tira prints de todas as telas e paineis em cada fundo da galeria (ADR 0034),
## para conferir de uma vez se tudo combina e se o texto branco le bem.
##
##   godot --path . --script res://tools/capturar_galeria.gd -- <pasta> [fundo ...]
##
## Sem fundos, faz os seis. Gera <pasta>/<fundo>/<tela>.png. Precisa de janela,
## como tools/capturar_telas.gd. As preferencias e a telemetria vao para
## user://testes: nada muda no jogo de quem roda.

const ROTEIRO: String = "res://tools/roteiro_capturar_galeria.gd"


func _initialize() -> void:
	_executar()


func _executar() -> void:
	await process_frame
	var argumentos: PackedStringArray = OS.get_cmdline_user_args()
	var pasta: String = argumentos[0] if argumentos.size() > 0 else "user://capturas_galeria"
	var fundos: PackedStringArray = argumentos.slice(1)
	var roteiro: RefCounted = load(ROTEIRO).new()
	await roteiro.call("executar", self, pasta, fundos)
	quit(0)
