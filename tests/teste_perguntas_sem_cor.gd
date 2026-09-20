extends CasoDeTeste

## A "cor do cachorro diz qual cifra usar" saiu da interface (ver
## docs/conformidade-monografia.md, desvio 1): a cor virou identidade visual
## livre do cachorro (CachorroConfig.cor), sem nenhuma legenda que a associe a
## um algoritmo. Nenhum TEXTO LIDO PELO JOGADOR pode mais depender de ele ter
## decorado essa associacao -- nem para identificar o interceptador de uma
## pergunta, nem como pista narrativa em um desafio.
##
## So os campos de texto que o jogador realmente le (enunciado, opcoes,
## explicacao_correta, dica) sao verificados -- e nao o arquivo inteiro, que
## tambem guarda identificadores internos como "verde-norte" (CachorroConfig
## .identificador): esses sao rotulo de dado, nunca aparecem na tela.

const FASES: PackedStringArray = [
	"res://recursos/fases/fase_01.tres",
	"res://recursos/fases/fase_02.tres",
	"res://recursos/fases/fase_03.tres",
]

const CORES: PackedStringArray = [
	"verde", "azul", "roxo", "vermelho", "amarelo", "laranja", "rosa", "preto", "branco", "cinza",
]

## Campos de texto voltados ao jogador, como aparecem no .tres ("campo = ...").
const CAMPOS_DE_TEXTO: PackedStringArray = [
	"enunciado", "opcoes", "explicacao_correta", "dica", "briefing_pedagogico",
]


func teste_nenhum_campo_de_texto_cita_cor_de_cachorro() -> void:
	for caminho: String in FASES:
		var conteudo: String = FileAccess.get_file_as_string(caminho)
		if not afirmar_falso(conteudo.is_empty(), "%s: arquivo le" % caminho):
			continue

		for linha: String in conteudo.split("\n"):
			var campo: String = _campo_de_texto_da_linha(linha)
			if campo.is_empty():
				continue
			var minuscula: String = linha.to_lower()
			for cor: String in CORES:
				afirmar_falso(minuscula.contains(cor),
					"%s: campo '%s' nao deveria citar a cor '%s' -- %s"
						% [caminho, campo, cor, linha.strip_edges()])


func _campo_de_texto_da_linha(linha: String) -> String:
	for campo: String in CAMPOS_DE_TEXTO:
		if linha.begins_with(campo + " ="):
			return campo
	return ""
