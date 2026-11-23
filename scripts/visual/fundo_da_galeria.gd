class_name FundoDaGaleria
extends TextureRect

## Fundo das telas secundarias: o mesmo que o jogador escolheu na galeria do
## menu (ADR 0033), para a troca de tela nao mudar a paisagem.

func _ready() -> void:
	texture = GaleriaDeFundos.textura_do_fundo(GaleriaDeFundos.atual())
