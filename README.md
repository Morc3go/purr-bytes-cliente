# Purr Bytes — cliente Godot

Jogo educacional 2D de letramento digital e criptografia. Este repositório é o
**cliente**; o back-end de telemetria (Java 21 + Spring Boot + PostgreSQL) vive em
`Morc3go/prototipo`, pasta `Protótipo/backend`.

O contexto completo do projeto — restrições, marcos e critérios de aceite — está em
[`CLAUDE.md`](CLAUDE.md). As decisões tomadas e o porquê de cada uma estão em
[`docs/decisoes/`](docs/decisoes/).

**Godot 4.4+** (testado em 4.6.2 e 4.7.2) · GDScript com tipagem estática ·
renderizador Mobile · 640×360.

---

## Rodando

```powershell
# ajuste para onde o binário do Godot estiver na sua máquina
$godot = "$env:LOCALAPPDATA\Programs\godot\Godot_v4.7.2-stable_win64.exe"

# abrir no editor
& $godot --path .

# importar sem abrir janela (útil depois de git pull)
& $godot --headless --path . --import

# rodar o jogo headless e sair (checagem de importação limpa)
& $godot --headless --quit --path .
```

## Testes

Suíte própria, sem addon (ver [ADR 0005](docs/decisoes/0005-suite-de-testes-nativa.md)):

```powershell
& $godot --headless --path . --script res://tests/runner.gd

# só um arquivo
& $godot --headless --path . --script res://tests/runner.gd -- telemetria
```

Sai com código 0 se verde e 1 se vermelho.

## Sessão de demonstração

Abre e encerra uma sessão em modo MOCK sem abrir janela, e imprime o JSONL resultante.
É o que gera os exemplos de [`docs/contrato-telemetria.md`](docs/contrato-telemetria.md):

```powershell
& $godot --headless --path . --script res://tools/sessao_de_demonstracao.gd
```

## Simulação de queda (demonstração de resiliência)

Dois processos: o primeiro enfileira uma partida com a rede fora e morre sem enviar nada;
o segundo lê a fila do disco e drena.

```powershell
& $godot --headless --path . --script res://tools/simular_queda.gd -- encher
& $godot --headless --path . --script res://tools/simular_queda.gd -- drenar
```

Resultado esperado: zero evento perdido, zero duplicado, sequência contígua, e a sessão
interrompida marcada como `ABANDONADA`.

## Servidor de eco (desenvolvimento do transporte HTTP)

As rotas reais de `Morc3go/prototipo` ainda não existem. `tools/servidor_eco.py`
é um servidor mínimo (biblioteca padrão do Python, sem dependência) que aceita
qualquer `POST` nas quatro rotas do contrato e responde `202`, gravando o corpo
recebido em log — é contra ele que `TransporteHttp` foi desenvolvido e testado
(`tests/teste_transporte_http.gd`, `tests/teste_resiliencia_http.gd`):

```powershell
python tools/servidor_eco.py 8091 caminho\para\log.jsonl
```

Para apontar o jogo para ele, `config.cfg`: `modo_telemetria="HTTP"`,
`url_api="http://127.0.0.1:8091"`.

## Configuração da coleta

O jogo cria `user://config.cfg` no primeiro boot
(`%APPDATA%\Godot\app_userdata\Purr Bytes\config.cfg` no Windows):

```ini
[telemetria]
modo_telemetria="MOCK"        ; MOCK grava em disco, HTTP fala com a API (ver servidor de eco acima)
url_api="http://localhost:8080"
chave_api=""                  ; escopo INGESTAO, só escreve
tamanho_lote=50               ; teto do back-end é 500
intervalo_envio_s=5.0

[pesquisa]
id_sujeito=""                 ; UUID do participante; sem ele a sessão fica órfã na análise

[diagnostico]
nivel_log="INFO"              ; SILENCIO | ERRO | AVISO | INFO | DEPURACAO

[jogo]
modo_treino=false             ; true desliga as mecânicas de jogador humano (ver abaixo)
```

**Antes de cada coleta**, preencher `id_sujeito` com o UUID daquele participante. Se o campo
estiver vazio ou fora do formato UUID, o cliente gera um local e avisa alto — a sessão é
gravável, mas não pareia com o pré-teste e o pós-teste.

O menu principal → **telemetria** mostra modo, fila, sequência e descartes na própria tela,
sem ferramenta nenhuma instalada. A chave de API nunca aparece ali.

---

## Como se joga

O labirinto é a topologia da rede e o pacote de dados é o que você transporta.

**Cores.** Cada cachorro farejador lê **uma** cifra, e a cor dele diz qual:
🟢 verde = César · 🔵 azul = Vigenère · 🟣 roxo = SHA-256. Cifrar na cor errada **não
protege** — é o mesmo que atravessar em texto claro. A tabela completa está no menu, em
**tutorial de cores**, e sai de `scripts/dominio/legenda_cores.gd`, que é a fonte única
usada também pelos cachorros, pela HUD e pelos botões do puzzle.

**Terminal** (`T`). É onde a cifra é aplicada: `cifrar <pacote> chave=<valor>`,
`hash <palavra>`, `verificar <palavra> <prefixo>`, mais `dica` e `status`. Resolver um
desafio ativa a proteção **na cifra daquele desafio**, por alguns segundos. Os desafios de
uma fase ciclam, então sempre dá para reaplicar a cifra que a cor exige.

**Pacotes.** Três por fase, espalhados em pontas distantes. Encostar num pacote abre uma
pergunta curta com botões (qual ferramenta serve para aquele caso). Acertar coleta;
errar custa pontos e deixa tentar de novo. `ESC` fecha sem responder.

**Porta.** A saída fica trancada até os três pacotes serem coletados — o cadeado é
visível do outro lado do labirinto. Aberta, ela leva direto à fase seguinte.

**Teclas.** `WASD`/setas movem · `T` terminal · `F3` mostra o caminho do A\* de cada
cachorro, na cor dele · `ESC` sai da fase (ou fecha o terminal/puzzle).

### Modo de treino (agente de RL)

`modo_treino=true` no `config.cfg` desliga as duas mecânicas que pressupõem um humano —
e **só** essas duas:

| | `modo_treino=false` (padrão) | `modo_treino=true` |
|---|---|---|
| Pacote | abre a caixa de puzzle | coletado ao encostar |
| Proteção | só a cifra da cor do cachorro | qualquer cifra ativa |

Labirinto, A\*, Diretor, terminal, porta e telemetria são idênticos nos dois modos.
Detalhe em [ADR 0010](docs/decisoes/0010-modo-humano-cores-pacotes-e-porta.md).

---

## Estado

| Marco | Situação |
|---|---|
| 0 — Fundação | ✅ concluído |
| 1 — Fase 1: César, labirinto e A\* | ✅ concluído |
| 2 — Fase 2: Vigenère e Diretor de IA | ✅ concluído |
| 3 — Fase 3: SHA-256 e telemetria HTTP | ✅ concluído |
| Evolução de gameplay (modo humano) | ✅ concluído — [ADR 0010](docs/decisoes/0010-modo-humano-cores-pacotes-e-porta.md), [relatório](RELATORIO_CLAUDE_CODE.md) |

### Pendências conhecidas da evolução de gameplay

- O labirinto novo (25×19) e o posicionamento de pacotes, cachorros e porta foram
  conferidos por código (conectividade por inundação e testes de integração), mas
  **não** foram vistos em tela: vale abrir `fase_01.tscn` no editor e jogar uma
  partida para avaliar ritmo, distância entre pacotes e agressividade das patrulhas.
- Fases 2 e 3 ganharam cachorros coloridos e pacotes, mas continuam com o traçado de
  labirinto antigo (19×13, e o mesmo nas duas) — o remodelamento equivalente ao da
  fase 1 não foi pedido e não foi feito.
- Com Diretor (fases 2 e 3), todos os cachorros perseguem a mesma região de crença.
  Eles se espalham na varredura, mas andam em matilha; se isso ficar pesado em tela,
  o caminho é dar uma crença por cachorro (não foi feito para não mexer no ADR 0002).

### Pendências conhecidas do Marco 3

- `tests/teste_resiliencia_http.gd` e `tests/teste_transporte_http.gd` sobem
  um processo Python real (`tools/servidor_eco.py`) -- rodam bem mais devagar
  que o resto da suíte (conexão recusada contra uma porta fechada não falha
  instantaneamente no Windows). Rode a suíte inteira com folga de tempo; para
  iterar rápido, filtre por outro nome de arquivo.
- **"As três fases jogáveis em sequência com progressão de vidas e
  pontuação"** (critério de aceite do Marco 3) está validado fase a fase por
  integração automatizada (`tests/teste_fase_0{1,2,3}_integracao.gd`), mas a
  travessia completa **menu → fase 1 → fase 2 → fase 3 → menu**, pela
  navegação de cena de verdade, não tem teste automatizado -- o Marco 1 já
  havia identificado `get_tree().change_scene_to_file()` como arriscado de
  exercitar dentro do processo compartilhado da suíte de testes. Isso precisa
  de uma partida manual no editor antes de considerar o critério
  100% fechado.
- O labirinto de `fase_03.tscn` reaproveita o MESMO traçado de `fase_02.tscn`
  (gerado por `tools/gerar_fase_03.gd`) -- funcional, mas repetitivo
  visualmente; candidato a variar quando a arte definitiva entrar.
- Decisões completas em
  [ADR 0009](docs/decisoes/0009-sha256-http-e-resiliencia.md).

### Pendências conhecidas do Marco 2

- O labirinto de `fase_02.tscn` foi pintado por código
  (`tools/gerar_fase_02.gd`), mesma técnica da fase 1 -- vale abrir no editor
  para conferir visualmente e trocar a arte placeholder quando ela existir.
- As 4 regiões do Diretor (`Marcadores/Regioes` em `fase_02.tscn`) cobrem os
  quadrantes do mapa por retângulo, sem alinhar pixel a pixel com as paredes
  do labirinto -- funcional (é só o que decide "o jogador está nesta região"
  para o Diretor, não um limite físico), mas pode valer a pena ajustar no
  editor depois que a arte definitiva mostrar a topologia real do mapa.
- Detalhe completo das decisões do Diretor e de Vigenère em
  [ADR 0002](docs/decisoes/0002-diretor-ia.md) e
  [ADR 0008](docs/decisoes/0008-vigenere-e-painel-de-demonstracao.md).

### Pendências conhecidas do Marco 1

- O labirinto de `fase_01.tscn` foi pintado por código
  (`tools/gerar_fase_01.gd`), não desenhado no editor -- funcional e testado,
  mas vale abrir uma vez no editor para conferir visualmente o traçado e
  trocar a arte placeholder pela definitiva quando ela existir.
- A depuração visual do A\* (F3) desenha o caminho final, não os "nós
  expandidos": `AStarGrid2D` não expõe o conjunto fechado pela API pública, e
  a implementação didática que expõe (`scripts/ia/astar_referencia.gd`) é
  vetada para uso em runtime pelo próprio `CLAUDE.md`. Detalhe em
  [ADR 0007](docs/decisoes/0007-marco1-cachorro-e-desafios.md#7-depuração-visual-do-a-f3-só-o-caminho-final-não-os-nós-expandidos).
- `CatalogoResultados.TIMEOUT` não tem gatilho de jogo no Marco 1: não há
  campo de prazo por desafio especificado no briefing. `ABANDONO` tem gatilho
  real (abandonar a fase com desafio ativo). Detalhe na
  [ADR 0007](docs/decisoes/0007-marco1-cachorro-e-desafios.md).
- Arte é placeholder gerado (`recursos/arte/*_placeholder.png`), esperando a pixel art.
