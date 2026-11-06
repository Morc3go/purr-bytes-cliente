class_name AparenciaGato
extends RefCounted

## Aparencia do gatinho que o jogador escolhe no menu: tuxedo ou calico (ADR 0021).
##
## E so cosmetica: as duas aparencias tem as mesmas animacoes, a mesma colisao
## e a mesma velocidade -- nada muda na regra do jogo, entao a escolha nao e
## variavel do experimento e nao vai para a telemetria.
##
## A escolha fica em user://preferencias.cfg, e NAO em config.cfg: aquele
## arquivo e da coleta (modo, URL, chave, id_sujeito), preparado pelo
## pesquisador antes da sessao; preferencia do jogador nao se mistura com ele.

const TUXEDO: StringName = &"tuxedo"
const CALICO: StringName = &"calico"
const PADRAO: StringName = TUXEDO

## Ordem em que o botao do menu alterna.
const ORDEM: Array[StringName] = [TUXEDO, CALICO]

## sombra: a folha calico ja traz a sombra desenhada; a tuxedo nao, e ganha a
## sombra do no Sombra (MarcadorDeCor) do jogador.
const OPCOES: Dictionary = {
	TUXEDO: {"quadros": "res://recursos/arte/gato_tuxedo_frames.tres", "nome": "tuxedo",
		"sombra": true},
	CALICO: {"quadros": "res://recursos/arte/gato_calico_frames.tres", "nome": "calico",
		"sombra": false},
}

const CAMINHO_PADRAO: String = "user://preferencias.cfg"
const _SECAO: String = "jogador"
const _CHAVE: String = "aparencia_gato"

## So a suite de testes troca, para nao mexer na escolha de quem joga.
static var caminho: String = CAMINHO_PADRAO


static func atual() -> StringName:
	var arquivo := ConfigFile.new()
	if arquivo.load(caminho) != OK:
		return PADRAO
	var lida: StringName = StringName(String(arquivo.get_value(_SECAO, _CHAVE, String(PADRAO))))
	# Arquivo editado a mao com valor desconhecido: volta ao padrao, sem quebrar.
	return lida if OPCOES.has(lida) else PADRAO


static func definir(aparencia: StringName) -> void:
	if not OPCOES.has(aparencia):
		Registro.aviso("AparenciaGato", "aparencia desconhecida: %s" % aparencia)
		return
	var arquivo := ConfigFile.new()
	arquivo.load(caminho)  # pode nao existir ainda; ai comeca vazio
	arquivo.set_value(_SECAO, _CHAVE, String(aparencia))
	var erro: Error = arquivo.save(caminho)
	if erro != OK:
		Registro.aviso("AparenciaGato", "nao foi possivel salvar a preferencia (erro %d)" % erro)


static func proxima(aparencia: StringName) -> StringName:
	var indice: int = ORDEM.find(aparencia)
	return ORDEM[(indice + 1) % ORDEM.size()]


static func nome(aparencia: StringName) -> String:
	return String((OPCOES.get(aparencia, OPCOES[PADRAO]) as Dictionary)["nome"])


static func quadros(aparencia: StringName) -> SpriteFrames:
	var opcao: Dictionary = OPCOES.get(aparencia, OPCOES[PADRAO]) as Dictionary
	return load(String(opcao["quadros"])) as SpriteFrames


static func tem_sombra_propria(aparencia: StringName) -> bool:
	var opcao: Dictionary = OPCOES.get(aparencia, OPCOES[PADRAO]) as Dictionary
	return not bool(opcao["sombra"])


## Troca a arte de um AnimatedSprite2D mantendo a animacao que ele tocava.
static func aplicar(sprite: AnimatedSprite2D, aparencia: StringName) -> void:
	var animacao: StringName = sprite.animation
	var tocando: bool = sprite.is_playing()
	sprite.sprite_frames = quadros(aparencia)
	if sprite.sprite_frames.has_animation(animacao):
		sprite.animation = animacao
		if tocando:
			sprite.play(animacao)
