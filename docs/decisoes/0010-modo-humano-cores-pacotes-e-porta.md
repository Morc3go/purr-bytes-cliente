# ADR 0010 — Modo humano: cachorros coloridos, pacotes com puzzle e porta

**Marco:** pós-3 (evolução de gameplay) · **Data:** 2026-08-25 · **Situação:** aceita

## Contexto

Depois dos três marcos, o jogo estava correto e instrumentado, mas magro como
experiência: um labirinto de 15×9 com dois corredores espelhados, **um** cachorro,
nenhum objetivo intermediário entre a entrada e a saída, e uma regra de proteção
binária ("cifrou" x "não cifrou") que não distinguia *qual* cifra o jogador aplicou.

O pedido foi redesenhar o laço de jogo para o **jogador humano**, mantendo intacto o
caminho de um futuro agente de aprendizado por reforço.

## Decisões

### 1. O cachorro estava travado por meia célula — `get_id_path`, não `get_point_path`

`AStarGrid2D` posiciona o ponto de uma célula no **canto** dela
(`célula * cell_size + offset`, com `offset` zero por padrão). `TileMapLayer.map_to_local`
devolve o **centro** (`célula * tile_size + tile_size/2`). `Navegacao.calcular_caminho`
convertia os pontos do A\* como se as duas fórmulas fossem a mesma — e o comentário do
arquivo afirmava isso explicitamente.

O efeito: **todo waypoint caía sobre o canto de uma parede**. O corpo do cachorro (10×10
num tile de 16) colidia, `move_and_slide` deslizava, e ele nunca chegava aos 4 px de
`tolerancia_de_chegada`. O cachorro ficava parado no primeiro waypoint — exatamente o
sintoma relatado.

A correção usa `get_id_path` (células) e converte cada célula com `map_to_local`, o que
elimina a classe inteira do problema em vez de acertar o `offset` da grade. Regressão em
`tests/teste_astar.gd::teste_waypoints_caem_no_centro_da_celula`.

Bug secundário no mesmo caminho: `Cachorro._physics_process` dava `return` sem chamar
`move_and_slide()` no quadro em que avançava o índice do caminho — um soluço de física a
cada 16 px percorridos.

### 2. Labirinto 25×19 gerado, não desenhado à mão

O mapa novo saiu de um backtracker recursivo de semente fixa, com câmaras carvadas
(entrada, centro, sala da porta e as duas salas de pacote) e 16 aberturas extras. As
aberturas são o que importa: elas transformam a árvore do backtracker em **grafo com
ciclos**, ou seja, existe mais de um caminho entre dois pontos — fugir vira decisão, não
corredor único. A conectividade foi conferida por inundação antes de o ASCII entrar no
repositório.

O artefato versionado continua sendo o ASCII em `tools/gerar_fase_01.gd`: auditável,
diffável e editável à mão. O gerador foi um andaime, não uma dependência.

### 3. Câmera: fixa quando o mapa cabe na tela

25×19 tiles de 16 = 400×304 px numa viewport de 640×360. O labirinto inteiro cabe, então
`FaseBase._configurar_camera` fixa a câmera no centro do mapa em vez de seguir o jogador.
Num jogo de rota e perseguição, esconder metade do mapa tornaria o cachorro injusto. Se
um mapa futuro passar do tamanho da tela, a câmera volta a seguir o jogador, agora presa
aos limites derivados de `get_used_rect()`.

### 4. Cor do cachorro = algoritmo exigido, e a cor é dado único

`LegendaCores` (`scripts/dominio/legenda_cores.gd`) é a fonte única: cachorro, botão da
caixa de puzzle, HUD e tutorial do menu leem dela. Duas tabelas paralelas divergiriam no
primeiro ajuste de paleta e o jogo passaria a ensinar errado sem nenhum teste quebrar.

`FaseConfig.cachorros: Array[CachorroConfig]` traz posição inicial, rota de patrulha, cor
(via algoritmo) e velocidade. O cachorro que já existia em `fase_base.tscn` vira o número
1 da lista; os demais são instâncias da mesma cena. Fase sem lista continua funcionando
com um cachorro só, exigindo o algoritmo da própria fase.

### 5. Cifra errada não protege — e um cachorro impossível é erro de configuração

`Jogador.algoritmo_protegido` guarda **qual** cifra está ativa;
`FaseBase._protegido_contra` compara com o `algoritmo_exigido` de quem encostou. Cifrar em
César não engana quem lê Vigenère, e a tela de captura explica exatamente isso.

Para que a regra seja justa, `FaseConfig.problemas()` recusa a fase se algum cachorro
exigir uma cifra que **nenhum desafio daquela fase produz**. Um cachorro azul numa fase
que só ensina César seria captura inevitável — erro de configuração, não de habilidade,
e portanto reprova a fase antes de virar frustração no laboratório da escola.

Consequência de projeto: `DesafioConfig.algoritmo` (vazio = herda o da fase) e desafios
de revisão nas fases 2 e 3. A fase 1 tem só cachorros verdes de propósito — a cor que o
jogador ainda não sabe produzir não entra em cena.

### 6. Os desafios ciclam

A proteção dura poucos segundos e cada desafio concede a cifra *dele*. Sem ciclo, um
jogador que já resolveu tudo atravessaria o resto do labirinto em texto claro, sem
nenhum comando disponível para se defender. Com ciclo, o terminal continua sendo
ferramenta até o fim da fase — e como resolver de novo **não pontua**, o placar continua
medindo aprendizado, não repetição.

### 7. Pacote com puzzle: botão, não campo de texto

Encostar num pacote abre uma pergunta curta com um botão por opção, na cor do algoritmo.
Botão porque o terminal **já** mede digitação (tempo de resposta, erro léxico, erro
sintático); o que o pacote mede é **escolha**, e um erro de digitação aí viraria ruído no
dado, não informação. Errar não fecha a caixa: mostra o porquê e deixa tentar de novo,
custando pontos.

A caixa pausa a árvore (`get_tree().paused`) e tem `process_mode = ALWAYS`, então
responde pausada — a pausa é o que impede uma captura enquanto o jogador lê o enunciado.
Efeito colateral aceito: o temporizador de descarga da telemetria também para enquanto a
caixa está aberta; a fila continua acumulando em memória e drena ao despausar.

### 8. O puzzle vira `tentativa_comando`, nunca um evento novo

O catálogo de eventos é fechado pelo banco (restrição 7 da seção 4 do `CLAUDE.md`: FK para
`pesquisa.tipo_evento`). Um código inventado no cliente viraria `INSERT` rejeitado lá —
dado de pesquisa perdido. A forma também é honesta: é uma tentativa, com resultado,
tempo de resposta e número da tentativa, igual a uma linha de terminal.

O `desafio` vai prefixado com `pacote-`, que é o que permite a análise separar
**"escolheu a ferramenta certa"** (pacote) de **"operou a cifra certa"** (terminal) — são
competências diferentes e o pré/pós-teste mede as duas. Resultado `SUCESSO` no acerto e
`ERRO_SEMANTICO` no erro (estrutura válida, significado inválido), com
`codigo_erro = "opcao_incorreta"`.

### 9. A saída virou porta com estado

`Marcadores/PontoDeSaida` ganhou o script `cenas/base/porta.gd`: trancada com cadeado
enquanto faltar pacote, aberta depois. Antes, a saída era um pedaço de chão invisível;
uma porta que se vê trancada do outro lado do labirinto transforma "ande até ali" em
objetivo e é o que faz os pacotes valerem a pena. O encadeamento para a fase seguinte já
existia em `FaseBase._PROXIMA_CENA_POR_FASE` — a fase 4 entra ali, com uma linha.

### 10. `ConfigJogo.modo_treino` preserva o caminho do agente de RL

Não existe modo RL neste repositório (o `rl_mode` citado no pedido é de um protótipo
anterior, fora deste código). A chave foi criada assim mesmo, em `config.cfg`, seção
`[jogo]`, e as duas mecânicas que pressupõem um humano ficam atrás dela:

| | `modo_treino = false` (padrão) | `modo_treino = true` |
|---|---|---|
| Pacote | abre a caixa de puzzle | coletado ao encostar |
| Proteção | só a cifra da cor do cachorro | qualquer cifra ativa |

Ler enunciado e clicar botão é tarefa de humano; travar o episódio numa tela modal
quebraria o treino sem ensinar nada a ninguém. Coberto por
`tests/teste_modo_humano.gd::teste_modo_treino_coleta_direto_e_aceita_qualquer_cifra`.

## Consequências

- `FaseBase` cresceu: além da fase, agora orquestra N cachorros, N pacotes e a porta.
  Continua sendo o único lugar com lógica — as três cenas de fase seguem sem script.
- `Jogador.protecao_alterada` mudou de assinatura (ganhou o algoritmo). Nenhum consumidor
  fora da HUD.
- `FaseBase._alvo_de_perseguicao` passou a receber o cachorro como parâmetro.
- Com Diretor (fases 2 e 3), **todos** os cachorros recebem o mesmo alvo de crença. Eles
  se espalham pela tabela de varredura (deslocamento por índice), mas continuam sendo uma
  matilha atrás da mesma suspeita — o que não viola a informação imperfeita do ADR 0002,
  já que a crença segue sendo a única fonte.
