class_name Preferencias
extends RefCounted

## Preferencias de quem joga nesta maquina: o gato escolhido (ADR 0030) e o
## fundo do menu (ADR 0033). Coisas de gosto, que so mudam a aparencia.
##
## Ficam em user://preferencias.cfg, separado do config.cfg: aquele arquivo e
## da pesquisa (id_sujeito, URL, chave) e nao deve receber mais nada
## (restricao 8 do CLAUDE.md). Nada daqui vai para a telemetria.

## Variavel (e nao constante) so para os testes apontarem para um arquivo
## descartavel e nao mexerem nas preferencias de quem roda a suite.
static var caminho: String = "user://preferencias.cfg"


static func ler(secao: String, chave: String, padrao: Variant) -> Variant:
	var arquivo := ConfigFile.new()
	if arquivo.load(caminho) != OK:
		return padrao
	return arquivo.get_value(secao, chave, padrao)


static func gravar(secao: String, chave: String, valor: Variant) -> void:
	var arquivo := ConfigFile.new()
	# Carrega antes para nao apagar as outras preferencias.
	arquivo.load(caminho)
	arquivo.set_value(secao, chave, valor)
	var erro: Error = arquivo.save(caminho)
	if erro != OK:
		Registro.aviso("Preferencias", "nao foi possivel gravar %s/%s (erro %d)" % [secao, chave, erro])
