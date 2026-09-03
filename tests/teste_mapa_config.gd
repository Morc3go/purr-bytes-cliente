extends CasoDeTeste

## O validador de mapa (scripts/dominio/mapa_config.gd).
##
## Cada teste aqui e um bug que ANTES passava silencioso: celula esquecida no
## desenho virava parede invisivel, pacote ilhado so aparecia em playtest, e
## cachorro em area separada nunca encontrava ninguem. O objetivo do arquivo e
## que criar mapa novo seja seguro: se o desenho estiver incoerente, a fase se
## recusa a rodar e diz por que.

const _MAPA_BOM: PackedStringArray = [
	"#########",
	"#P..o...#",
	"#.###.#.#",
	"#...#..D#",
	"#.#.###.#",
	"#......S#",
	"#########",
]


func _mapa(linhas: PackedStringArray) -> MapaConfig:
	var mapa := MapaConfig.new()
	mapa.linhas = linhas
	return mapa


func teste_mapa_bem_formado_nao_tem_problema() -> void:
	afirmar_igual(_mapa(_MAPA_BOM).problemas().size(), 0,
		"mapa fechado, com P, S, pacote e cachorro alcancaveis, e valido")


func teste_recusa_caractere_desconhecido() -> void:
	var linhas := PackedStringArray(_MAPA_BOM)
	linhas[1] = "#P..X...#"
	var problemas: PackedStringArray = _mapa(linhas).problemas()
	afirmar_verdadeiro(problemas.size() >= 1, "caractere fora da legenda reprova o mapa")
	afirmar_contem(" ".join(problemas), "desconhecido", "a mensagem diz o que esta errado")


func teste_recusa_linhas_de_tamanhos_diferentes() -> void:
	var linhas := PackedStringArray(_MAPA_BOM)
	# Uma coluna a menos: era exatamente isto que virava "parede invisivel",
	# porque celula nao pintada conta como solida na navegacao.
	linhas[3] = "#...#..D"
	var problemas: PackedStringArray = _mapa(linhas).problemas()
	afirmar_verdadeiro(problemas.size() >= 1, "linha mais curta reprova o mapa")
	afirmar_contem(" ".join(problemas), "caracteres", "a mensagem aponta a linha e o tamanho")


func teste_recusa_borda_aberta() -> void:
	var linhas := PackedStringArray(_MAPA_BOM)
	linhas[0] = "####.####"
	afirmar_verdadeiro(_mapa(linhas).problemas().size() >= 1,
		"buraco na parede externa reprova o mapa: o jogador sairia para fora do labirinto")


func teste_recusa_pacote_ilhado() -> void:
	# Pacote fechado numa camara sem ligacao com o resto: a porta nunca abriria,
	# porque a fase exige todos os pacotes coletados.
	var linhas := PackedStringArray([
		"#########",
		"#P......#",
		"#.#####.#",
		"#.#.o#..#",
		"#.#####.#",
		"#......S#",
		"#########",
	])
	var problemas: PackedStringArray = _mapa(linhas).problemas()
	afirmar_verdadeiro(problemas.size() >= 1, "pacote inalcancavel reprova o mapa")
	afirmar_contem(" ".join(problemas), "inalcancavel",
		"a mensagem diz que o pacote nao tem caminho ate ele")


func teste_recusa_porta_inalcancavel() -> void:
	# Dois corredores sem ligacao nenhuma: o de baixo tem o pacote e a porta, e
	# o jogador esta no de cima.
	var linhas := PackedStringArray([
		"#########",
		"#P......#",
		"#########",
		"#...o..S#",
		"#########",
	])
	var problemas: PackedStringArray = _mapa(linhas).problemas()
	afirmar_verdadeiro(problemas.size() >= 2,
		"porta e pacote sem caminho reprovam o mapa")
	afirmar_contem(" ".join(problemas), "porta", "a mensagem cita a porta")


func teste_recusa_cachorro_preso_e_conta_errada() -> void:
	var config := FaseConfig.new()
	config.numero = 1
	config.titulo = "teste"
	config.algoritmo = "CESAR"

	var linhas := PackedStringArray(_MAPA_BOM)
	var problemas: PackedStringArray = _mapa(linhas).problemas(config)
	# O mapa tem 1 'o' e 1 'D'; o FaseConfig acima nao declara nenhum dos dois.
	afirmar_verdadeiro(problemas.size() >= 2,
		"o validador cobra que o desenho e a lista da fase tenham a mesma contagem")
	afirmar_contem(" ".join(problemas), "pacotes", "diz quantos pacotes o mapa tem")
	afirmar_contem(" ".join(problemas), "cachorros", "e quantos cachorros")


func teste_exige_um_jogador_e_uma_porta() -> void:
	var sem_jogador := PackedStringArray(_MAPA_BOM)
	sem_jogador[1] = "#...o...#"
	afirmar_verdadeiro(_mapa(sem_jogador).problemas().size() >= 1, "mapa sem 'P' reprova")

	var duas_portas := PackedStringArray(_MAPA_BOM)
	duas_portas[1] = "#P..o..S#"
	afirmar_verdadeiro(_mapa(duas_portas).problemas().size() >= 1, "mapa com dois 'S' reprova")


func teste_marcadores_sao_andaveis_e_saem_em_ordem_de_leitura() -> void:
	var mapa: MapaConfig = _mapa(_MAPA_BOM)
	afirmar_igual(mapa.celula_unica(MapaConfig.JOGADOR), Vector2i(1, 1), "P encontrado")
	afirmar_igual(mapa.celula_unica(MapaConfig.SAIDA), Vector2i(7, 5), "S encontrado")
	afirmar_verdadeiro(mapa.e_andavel(Vector2i(1, 1)),
		"a celula do jogador e andavel: os marcadores ficam POR CIMA do piso")
	afirmar_verdadeiro(mapa.e_andavel(mapa.celulas_de(MapaConfig.PACOTE)[0]),
		"a celula do pacote tambem")
	afirmar_falso(mapa.e_andavel(Vector2i(0, 0)), "parede nao e andavel")


func teste_as_tres_fases_reais_passam_no_validador() -> void:
	for numero: int in [1, 2, 3]:
		var config: FaseConfig = load("res://recursos/fases/fase_0%d.tres" % numero) as FaseConfig
		if not afirmar_nao_nulo(config, "fase %d carrega" % numero):
			continue
		if not afirmar_nao_nulo(config.mapa, "fase %d tem MapaConfig" % numero):
			continue

		var problemas: PackedStringArray = config.mapa.problemas(config)
		afirmar_igual(problemas.size(), 0,
			"mapa da fase %d valido: %s" % [numero, " | ".join(problemas)])

		# A regiao do Diretor manda o cachorro para o CENTRO dela; centro em
		# parede era o que travava as fases 2 e 3 antes da correcao.
		afirmar_igual(config.mapa.celulas_de(MapaConfig.CACHORRO).size(), config.cachorros.size(),
			"fase %d: um 'D' no desenho por cachorro declarado" % numero)
		afirmar_igual(config.mapa.celulas_de(MapaConfig.PACOTE).size(), config.pacotes.size(),
			"fase %d: um 'o' no desenho por pacote declarado" % numero)
