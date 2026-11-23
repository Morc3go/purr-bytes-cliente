class_name PelagemCachorro
extends RefCounted

## Pelagem (aparencia) de um vigia (ADR 0022, 0037 e 0042).
##
## Desde a ADR 0042 sao duas: o husky e o pastor, os dois desenhados pela
## equipe no traco novo. Toda fase MISTURA as duas, alternando pela ordem dos
## vigias (husky, pastor, husky, ...): o mapa fica variado sem ninguem precisar
## escolher nada, nem o professor no editor, nem o jogador.
##
## E so cosmetica, como a aparencia do gato (ADR 0021): as duas folhas tem as
## mesmas animacoes, e regra, velocidade e colisao nao mudam. Quem identifica o
## vigia para o jogador continua sendo o ANEL colorido no chao (MarcadorDeCor),
## nunca a pelagem -- por isso ela nao entra na telemetria.
##
## O campo "pelagem" do JSON continua sendo lido e gravado (fases antigas trazem
## "husky" ou "caramelo"), mas nao decide mais o desenho: o caramelo era o
## cachorro marrom que ainda ia ser desenhado, e o pastor ocupa esse lugar.

const HUSKY: String = "husky"
const PASTOR: String = "pastor"
const CARAMELO: String = "caramelo"

## Pelagens com desenho pronto, na ordem da alternancia.
const ORDEM: Array[String] = [HUSKY, PASTOR]

## Toda pelagem conhecida e o desenho que ela usa. O caramelo (valor antigo)
## e desenhado como o pastor, o cachorro marrom.
const _QUADROS: Dictionary = {
	HUSKY: "res://recursos/arte/cachorro_frames.tres",
	PASTOR: "res://recursos/arte/cachorro_pastor_frames.tres",
	CARAMELO: "res://recursos/arte/cachorro_pastor_frames.tres",
}


## Tem desenho proprio pronto?
static func disponivel(pelagem: String) -> bool:
	return ORDEM.has(pelagem)


static func conhece(pelagem: String) -> bool:
	return _QUADROS.has(pelagem)


## A pelagem do vigia de numero indice na fase: sempre alternada, para toda
## fase ter os dois cachorros.
static func do_vigia(indice: int) -> String:
	return ORDEM[indice % ORDEM.size()]


## O valor que o editor guarda no JSON: o que a fase ja trazia, ou a alternancia.
static func resolver(pelagem: String, indice: int) -> String:
	if conhece(pelagem):
		return pelagem
	return do_vigia(indice)


static func quadros(pelagem: String) -> SpriteFrames:
	return load(String(_QUADROS.get(pelagem, _QUADROS[HUSKY]))) as SpriteFrames
