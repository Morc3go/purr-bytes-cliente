class_name CarregadorFaseJson
extends RefCounted

## Le e escreve uma fase como arquivo .json -- o formato de autoria.
##
## O JSON NAO e um segundo modelo de dados: ele e a forma de TRANSPORTE de um
## FaseConfig. Tudo o que entra aqui vira FaseConfig/MapaConfig/CachorroConfig/
## PacoteConfig, e e validado pelas MESMAS funcoes problemas() que o jogo usa ao
## carregar uma fase. Nao ha validacao paralela para divergir.
##
## FORMATO (documentado no README):
##
##   {
##     "titulo": "Fase do professor",
##     "id_fase": "uuid-v4",                  ausente = gerado ao carregar
##     "briefing": "texto mostrado ao entrar",
##     "mapa":   {"largura": 21, "altura": 15, "seed": 12345},
##     "vidas": 3,
##     "cachorros": [
##       {"cor": "#40a9ff", "comando_para_bloquear": "cifrar pacote chave=3"}
##     ],
##     "terminais": [
##       {"enunciado": "...", "opcoes": ["a", "b"], "correta": "a", "explicacao": "..."}
##     ]
##   }
##
## "terminais" vira PacoteConfig porque o campo ja existe com exatamente essa
## forma (enunciado, opcoes, resposta correta, explicacao): sao os desafios que
## o jogador encontra espalhados pelo labirinto.
##
## O MAPA nao viaja desenhado: viajam largura, altura e semente, e o desenho e
## regenerado por GeradorDeMapa. O arquivo fica pequeno e legivel, e a mesma
## semente devolve o mesmo labirinto -- a fase que o professor testou e a fase
## que o aluno joga.

const PASTA_DAS_FASES: String = "user://fases"

## Pasta efetivamente usada. So a suite de testes troca (tests/runner.gd), para
## que nenhuma fase criada por teste apareca na lista de fases do jogador --
## antes, um teste interrompido no meio deixava "Fase de teste" no menu.
static var pasta_das_fases: String = PASTA_DAS_FASES
const _VIDAS_PADRAO: int = 3
const _LARGURA_PADRAO: int = 21
const _ALTURA_PADRAO: int = 15
const _LIMITE_DO_TITULO: int = 60


class Resultado:
	extends RefCounted
	var config: FaseConfig = null
	var erros: PackedStringArray = PackedStringArray()

	func ok() -> bool:
		return config != null and erros.is_empty()

	func mensagem() -> String:
		return "\n".join(erros)


static func garantir_pasta() -> void:
	if not DirAccess.dir_exists_absolute(pasta_das_fases):
		DirAccess.make_dir_recursive_absolute(pasta_das_fases)


## Fase de exemplo gravada no primeiro boot: o jogo nunca abre com a lista
## vazia, e o professor tem um arquivo pronto para abrir no editor e entender o
## formato copiando, em vez de lendo documentacao.
##
## So escreve se a pasta estiver vazia -- nunca por cima do que o professor fez.
static func semear_exemplo() -> void:
	garantir_pasta()
	if not listar().is_empty():
		return

	var caminho: String = "%s/exemplo-senhas-fortes.json" % pasta_das_fases
	var arquivo: FileAccess = FileAccess.open(caminho, FileAccess.WRITE)
	if arquivo == null:
		Registro.aviso("Fases", "nao foi possivel gravar a fase de exemplo (erro %d)"
			% FileAccess.get_open_error())
		return

	arquivo.store_string(JSON.stringify(_exemplo(), "\t"))
	arquivo.close()
	Registro.info("Fases", "fase de exemplo criada em %s" % caminho)


static func _exemplo() -> Dictionary:
	return {
		"titulo": "Senhas fortes",
		"id_fase": Identificador.uuid_v4(),
		"briefing": ("o pacote precisa atravessar a rede ate a porta.\n"
			+ "dois vigias patrulham o caminho: digite no terminal (tecla T) o comando "
			+ "que desliga cada um. o terceiro so persegue -- desse voce foge."),
		"algoritmo": "CESAR",
		"vidas": 3,
		"mapa": {"largura": 21, "altura": 15, "seed": 20260914},
		"cachorros": [
			{"cor": "#4da3ff", "comando_para_bloquear": "trocar senha", "algoritmo_exigido": "CESAR"},
			{"cor": "#ffb44d", "comando_para_bloquear": "ativar 2fa", "algoritmo_exigido": "CESAR"},
			{"cor": "#ff6b6b", "comando_para_bloquear": "", "algoritmo_exigido": "CESAR"},
		],
		"terminais": [
			{
				"enunciado": "qual destas e a senha mais dificil de descobrir?",
				"opcoes": ["uma frase longa que so voce lembra", "seu nome com o ano de nascimento",
					"a palavra 'senha' com um numero no fim"],
				"correta": "uma frase longa que so voce lembra",
				"explicacao": "tamanho vale mais que simbolo: frase longa demora seculos para ser testada.",
			},
			{
				"enunciado": "um site que voce usa vazou as senhas. o que fazer primeiro?",
				"opcoes": ["trocar a senha desse site e de onde ela se repetia",
					"esperar o site avisar por e-mail", "so trocar se perceber algo estranho"],
				"correta": "trocar a senha desse site e de onde ela se repetia",
				"explicacao": "senha repetida transforma um vazamento em varios: o risco viaja junto.",
			},
			{
				"enunciado": "para que serve a verificacao em duas etapas?",
				"opcoes": ["pedir algo alem da senha, que o invasor nao tem",
					"deixar a senha mais comprida", "esconder a senha do proprio site"],
				"correta": "pedir algo alem da senha, que o invasor nao tem",
				"explicacao": "mesmo com a senha certa, falta o segundo fator -- e por isso ela ainda protege.",
			},
		],
	}


## Todos os .json da pasta de fases, em ordem alfabetica (estavel entre
## aberturas da tela, que e o que evita a lista "dancar" a cada visita).
static func listar() -> PackedStringArray:
	garantir_pasta()
	var caminhos := PackedStringArray()
	var dir: DirAccess = DirAccess.open(pasta_das_fases)
	if dir == null:
		return caminhos
	for nome: String in dir.get_files():
		if nome.get_extension().to_lower() == "json":
			caminhos.append("%s/%s" % [pasta_das_fases, nome])
	caminhos.sort()
	return caminhos


## id_fase -> titulo de cada fase da pasta, lendo so o cabecalho do JSON (sem
## gerar labirinto): o painel de telemetria mostra o titulo ATUAL, mesmo que o
## professor tenha renomeado a fase depois de jogar -- o id_fase nao muda.
static func titulos_por_id() -> Dictionary:
	var titulos: Dictionary = {}
	for caminho: String in listar():
		var lido: Variant = JSON.parse_string(FileAccess.get_file_as_string(caminho))
		if typeof(lido) != TYPE_DICTIONARY:
			continue
		var dados: Dictionary = lido as Dictionary
		var id_fase: Variant = dados.get("id_fase")
		var titulo: Variant = dados.get("titulo")
		# Arquivo editado a mao pode trazer null ou numero: pula, nao quebra.
		if typeof(id_fase) == TYPE_STRING and Identificador.e_uuid(id_fase):
			titulos[id_fase] = (titulo as String).strip_edges() if typeof(titulo) == TYPE_STRING else ""
	return titulos


static func de_arquivo(caminho: String) -> Resultado:
	var resultado := Resultado.new()
	if not FileAccess.file_exists(caminho):
		resultado.erros.append("arquivo nao encontrado: %s" % caminho)
		return resultado

	var arquivo: FileAccess = FileAccess.open(caminho, FileAccess.READ)
	if arquivo == null:
		resultado.erros.append("nao foi possivel abrir %s (erro %d)"
			% [caminho, FileAccess.get_open_error()])
		return resultado

	var texto: String = arquivo.get_as_text()
	arquivo.close()
	return de_texto(texto)


## Arquivo malformado nunca derruba o jogo: volta em `erros`, para a tela
## mostrar. E por isso que nada aqui usa assert nem push_error fatal.
static func de_texto(texto: String) -> Resultado:
	var resultado := Resultado.new()

	var lido: Variant = JSON.parse_string(texto)
	if typeof(lido) != TYPE_DICTIONARY:
		resultado.erros.append("o arquivo nao e um JSON de objeto valido")
		return resultado

	var dados: Dictionary = lido as Dictionary
	var config := FaseConfig.new()

	config.titulo = String(dados.get("titulo", "")).strip_edges().substr(0, _LIMITE_DO_TITULO)
	if config.titulo.is_empty():
		resultado.erros.append("campo 'titulo' vazio ou ausente")

	# id_fase e a ligacao fase <-> telemetria: se o arquivo ja tem um, ele manda;
	# se nao tem, geramos aqui e quem salvar grava de volta.
	var id_lido: String = String(dados.get("id_fase", ""))
	config.id_fase = id_lido if Identificador.e_uuid(id_lido) else Identificador.uuid_v4()

	config.briefing_pedagogico = String(dados.get("briefing", ""))
	config.vidas_iniciais = clampi(int(dados.get("vidas", _VIDAS_PADRAO)), 1, 10)

	# Numero so ordena a lista; a identidade e o id_fase. Fase de autoria nao
	# disputa os numeros 1..3 das fases fixas do TCC.
	config.numero = 1
	config.algoritmo = String(dados.get("algoritmo", "CESAR"))
	if not LegendaCores.conhece(config.algoritmo):
		config.algoritmo = "CESAR"
	config.verbos_permitidos = PackedStringArray(["cifrar", "decifrar", "hash", "verificar",
		"dica", "status"])

	config.cachorros = _ler_cachorros(dados.get("cachorros", []), resultado)
	config.pacotes = _ler_terminais(dados.get("terminais", []), resultado)

	var mapa_pedido: Dictionary = dados.get("mapa", {}) as Dictionary
	var largura: int = int(mapa_pedido.get("largura", _LARGURA_PADRAO))
	var altura: int = int(mapa_pedido.get("altura", _ALTURA_PADRAO))
	var semente: int = int(mapa_pedido.get("seed", 0))

	var gerado: GeradorDeMapa.Resultado = GeradorDeMapa.gerar(
		largura, altura, semente, config.pacotes.size(), config.cachorros.size())
	if not gerado.ok():
		for erro: String in gerado.erros:
			resultado.erros.append("mapa: %s" % erro)
	else:
		config.mapa = gerado.mapa
		config.semente_do_mapa = gerado.semente

	if not resultado.erros.is_empty():
		return resultado

	# A palavra final e do validador do jogo, nao deste arquivo.
	for problema: String in config.problemas():
		resultado.erros.append(problema)
	if resultado.erros.is_empty():
		resultado.config = config
	return resultado


static func _ler_cachorros(bruto: Variant, resultado: Resultado) -> Array[CachorroConfig]:
	var lista: Array[CachorroConfig] = []
	if typeof(bruto) != TYPE_ARRAY:
		resultado.erros.append("campo 'cachorros' precisa ser uma lista")
		return lista

	var indice: int = 0
	for item: Variant in bruto as Array:
		indice += 1
		if typeof(item) != TYPE_DICTIONARY:
			resultado.erros.append("cachorro %d nao e um objeto" % indice)
			continue

		var dados: Dictionary = item as Dictionary
		var cachorro := CachorroConfig.new()
		cachorro.identificador = "cachorro-%d" % indice
		cachorro.cor = _cor_de(String(dados.get("cor", "")))
		cachorro.comando_para_bloquear = String(dados.get("comando_para_bloquear", "")).strip_edges()
		# Comando em branco no arquivo do professor significa "so persegue".
		var modo_lido: String = String(dados.get("modo_de_bloqueio", ""))
		if modo_lido == "CIFRA" or modo_lido == "COMANDO" or modo_lido == "NENHUM":
			cachorro.modo_de_bloqueio = modo_lido
		else:
			cachorro.modo_de_bloqueio = "COMANDO" if not cachorro.comando_para_bloquear.is_empty() else "NENHUM"
		# Fase de autoria bloqueia por COMANDO; o algoritmo so fica de default
		# para o caso de alguem escrever um JSON sem comando nenhum.
		cachorro.algoritmo_exigido = String(dados.get("algoritmo_exigido", "CESAR"))
		if not LegendaCores.conhece(cachorro.algoritmo_exigido):
			cachorro.algoritmo_exigido = "CESAR"
		lista.append(cachorro)

	return lista


static func _ler_terminais(bruto: Variant, resultado: Resultado) -> Array[PacoteConfig]:
	var lista: Array[PacoteConfig] = []
	if typeof(bruto) != TYPE_ARRAY:
		resultado.erros.append("campo 'terminais' precisa ser uma lista")
		return lista

	var indice: int = 0
	for item: Variant in bruto as Array:
		indice += 1
		if typeof(item) != TYPE_DICTIONARY:
			resultado.erros.append("terminal %d nao e um objeto" % indice)
			continue

		var dados: Dictionary = item as Dictionary
		var pacote := PacoteConfig.new()
		pacote.identificador = "terminal-%d" % indice
		pacote.enunciado = String(dados.get("enunciado", ""))
		pacote.explicacao_correta = String(dados.get("explicacao", ""))
		# Perguntas de autoria sao de CONTEUDO, com opcoes em texto livre --
		# nunca nomes de algoritmo coloridos.
		pacote.tipo = "CONCEITO"

		var opcoes := PackedStringArray()
		var bruto_opcoes: Variant = dados.get("opcoes", [])
		if typeof(bruto_opcoes) == TYPE_ARRAY:
			for opcao: Variant in bruto_opcoes as Array:
				var texto: String = String(opcao).strip_edges()
				if not texto.is_empty():
					opcoes.append(texto)
		pacote.opcoes = opcoes
		pacote.resposta_correta = String(dados.get("correta", "")).strip_edges()

		lista.append(pacote)

	return lista


## Aceita "#rrggbb" e nomes do Godot; vazio ou invalido devolve transparente,
## que CachorroConfig le como "use a cor padrao do algoritmo".
static func _cor_de(texto: String) -> Color:
	var limpo: String = texto.strip_edges()
	if limpo.is_empty():
		return Color(0, 0, 0, 0)
	if Color.html_is_valid(limpo):
		return Color.html(limpo)
	return Color(0, 0, 0, 0)


# ---------------------------------------------------------------------------
# Escrita
# ---------------------------------------------------------------------------

## O inverso exato de de_texto(): o que sai daqui, relido, produz a mesma fase.
## E o round-trip que o editor depende para "editar e salvar por cima" nao
## perder cachorro nem pergunta.
static func para_dicionario(config: FaseConfig) -> Dictionary:
	var cachorros: Array[Dictionary] = []
	for cachorro: CachorroConfig in config.cachorros:
		cachorros.append({
			"cor": cachorro.cor.to_html(false) if cachorro.cor.a > 0.0 else "",
			"comando_para_bloquear": cachorro.comando_para_bloquear,
			"algoritmo_exigido": cachorro.algoritmo_exigido,
			"modo_de_bloqueio": cachorro.modo_de_bloqueio,
		})

	var terminais: Array[Dictionary] = []
	for pacote: PacoteConfig in config.pacotes:
		terminais.append({
			"enunciado": pacote.enunciado,
			"opcoes": Array(pacote.opcoes),
			"correta": pacote.resposta_correta,
			"explicacao": pacote.explicacao_correta,
		})

	return {
		"titulo": config.titulo,
		"id_fase": config.id_fase,
		"briefing": config.briefing_pedagogico,
		"algoritmo": config.algoritmo,
		"vidas": config.vidas_iniciais,
		"mapa": {
			"largura": config.mapa.largura() if config.mapa != null else _LARGURA_PADRAO,
			"altura": config.mapa.altura() if config.mapa != null else _ALTURA_PADRAO,
			# A semente e o que torna o round-trip fiel: sem ela, reabrir a fase
			# geraria OUTRO labirinto com as mesmas medidas.
			"seed": config.semente_do_mapa,
		},
		"cachorros": cachorros,
		"terminais": terminais,
	}


static func salvar(config: FaseConfig, caminho: String) -> PackedStringArray:
	var erros := PackedStringArray()
	garantir_pasta()

	var arquivo: FileAccess = FileAccess.open(caminho, FileAccess.WRITE)
	if arquivo == null:
		erros.append("nao foi possivel escrever %s (erro %d)"
			% [caminho, FileAccess.get_open_error()])
		return erros

	arquivo.store_string(JSON.stringify(para_dicionario(config), "\t"))
	arquivo.close()
	return erros


## Nome de arquivo derivado do titulo: minusculas, sem acento nem simbolo. Dois
## titulos iguais gerariam o mesmo arquivo -- por isso o editor passa o caminho
## que ja existe quando esta EDITANDO, e so chama isto ao criar.
static func nome_de_arquivo(titulo: String) -> String:
	var limpo: String = titulo.strip_edges().to_lower()
	var saida := ""
	for i: int in limpo.length():
		var c: String = limpo[i]
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			saida += c
		elif c == " " or c == "-" or c == "_":
			saida += "-"
	while saida.contains("--"):
		saida = saida.replace("--", "-")
	saida = saida.strip_edges().trim_prefix("-").trim_suffix("-")
	if saida.is_empty():
		saida = "fase"
	return "%s/%s.json" % [pasta_das_fases, saida]
