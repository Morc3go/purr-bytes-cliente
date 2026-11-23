class_name PelagemGato
extends RefCounted

## Pelagem do gato protagonista: amarelo (o gato base), calico ou siames (ADR 0030).
##
## O jogador escolhe ao comecar a fase (cenas/ui/escolha_de_gato.tscn). E so
## cosmetica, como a pelagem dos vigias (ADR 0022): as tres folhas tem as
## mesmas animacoes e a mesma grade, e velocidade, colisao e regra nao mudam.
## Por isso a escolha nao entra na telemetria -- nao e dado de pesquisa.
##
## A ultima escolha fica nas Preferencias (user://preferencias.cfg).

const AMARELO: String = "amarelo"
const CALICO: String = "calico"
const SIAMES: String = "siames"

## O gato base: o que aparece no menu e o que vale enquanto ninguem escolheu.
const PADRAO: String = AMARELO

## Ordem dos cartoes na tela de escolha.
const ORDEM: Array[String] = [AMARELO, CALICO, SIAMES]

const NOMES: Dictionary = {
	AMARELO: "Amarelo",
	CALICO: "Cálico",
	SIAMES: "Siamês",
}

const _QUADROS: Dictionary = {
	AMARELO: "res://recursos/arte/gato_amarelo_frames.tres",
	CALICO: "res://recursos/arte/gato_calico_frames.tres",
	SIAMES: "res://recursos/arte/gato_siames_frames.tres",
}

const _SECAO: String = "gato"
const _CHAVE: String = "pelagem"

static func conhece(pelagem: String) -> bool:
	return _QUADROS.has(pelagem)


static func nome(pelagem: String) -> String:
	return String(NOMES.get(pelagem, NOMES[PADRAO]))


static func quadros(pelagem: String) -> SpriteFrames:
	return load(String(_QUADROS.get(pelagem, _QUADROS[PADRAO]))) as SpriteFrames


## Pelagem pedida, se for conhecida; senao a ultima escolhida; senao o amarelo.
static func resolver(pelagem: String) -> String:
	if conhece(pelagem):
		return pelagem
	return preferida()


static func preferida() -> String:
	var lida: String = String(Preferencias.ler(_SECAO, _CHAVE, PADRAO))
	return lida if conhece(lida) else PADRAO


static func salvar_preferida(pelagem: String) -> void:
	if conhece(pelagem):
		Preferencias.gravar(_SECAO, _CHAVE, pelagem)
