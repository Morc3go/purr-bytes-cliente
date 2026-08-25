# Relatório — evolução de gameplay (modo humano)

**Data:** 2026-08-25 · **Escopo:** redesenho do laço de jogo para o jogador humano,
preservando o caminho de um futuro agente de aprendizado por reforço.
**Decisões e justificativas completas:** [ADR 0010](docs/decisoes/0010-modo-humano-cores-pacotes-e-porta.md).

---

## Observação inicial: o brief descrevia outro código

O pedido citava `main.gd`, `game_map.gd`, `ai_controller.gd`, `cat_sprites.png`, `Lexer`,
`Telemetria.log_event`, `rl_mode`, `MAP` 15×15, `PACKETS` e `SERVER_POS`. **Nada disso
existe** neste repositório nem em `prototipo-main` — é o protótipo anterior que o próprio
`CLAUDE.md` (seção 1) classifica como descartável. Este repositório é a arquitetura do
`CLAUDE.md`: `FaseBase` + `TileMapLayer` + `FaseConfig` + `Telemetria.registrar_evento`.

As seis partes do pedido foram traduzidas para o código que existe de fato. Onde a
tradução mudou a forma da solução, está anotado abaixo.

---

## O que foi feito

### 1. Cachorro travado — causa raiz encontrada e corrigida

Não era o `_process` nem a velocidade. `Navegacao.calcular_caminho` usava
`AStarGrid2D.get_point_path`, que devolve o ponto no **canto** da célula
(`célula * cell_size`), enquanto `TileMapLayer.map_to_local` devolve o **centro**
(`célula * tile_size + tile_size/2`). Meia célula de diferença em cada eixo colocava
**todo waypoint sobre o canto de uma parede**: o corpo do cachorro (10×10 num tile de 16)
colidia, `move_and_slide` deslizava, e ele nunca alcançava a `tolerancia_de_chegada` de
4 px. Resultado: parado no primeiro waypoint, para sempre.

Corrigido com `get_id_path` + `map_to_local`, célula a célula
([navegacao.gd](scripts/ia/navegacao.gd)). Regressão travada em
`tests/teste_astar.gd::teste_waypoints_caem_no_centro_da_celula`.

Bug secundário no mesmo caminho: `Cachorro._physics_process` retornava sem chamar
`move_and_slide()` no quadro em que avançava o índice — um soluço a cada 16 px.

Também entrou **patrulha**: sem linha de visão e sem Diretor, o cachorro percorre em ciclo
as âncoras do `CachorroConfig` em vez de perseguir a posição real do jogador.

### 2. Labirinto 25×19

Era 15×9 (não 15×15) e consistia em dois corredores espelhados — daí a repetição. O novo
saiu de um backtracker recursivo de semente fixa, com câmaras carvadas e **16 aberturas
extras** que criam ciclos: existe mais de um caminho entre dois pontos, então fugir é
decisão e não corredor único. Conectividade verificada por inundação antes de o ASCII
entrar no repositório; o artefato versionado continua sendo o ASCII legível em
`tools/gerar_fase_01.gd`.

**Câmera:** 400×304 px numa viewport de 640×360 — o mapa inteiro cabe, então a câmera fica
fixa no centro. Se um mapa futuro passar do tamanho da tela, ela volta a seguir o jogador,
presa aos limites de `get_used_rect()`.

### 3. Cachorros coloridos, cada cor = uma criptografia

`FaseConfig.cachorros: Array[CachorroConfig]` (posição, âncoras, algoritmo, velocidade).
O cachorro da cena pai vira o nº 1; os demais são instâncias da mesma cena. As cores saem
de `LegendaCores`, **fonte única** compartilhada por cachorro, HUD, botões do puzzle e
tutorial — mudar uma cor lá muda tudo de uma vez.

`Jogador.algoritmo_protegido` guarda qual cifra está ativa, e `_protegido_contra()` compara
com o `algoritmo_exigido` de quem encostou: **cifrar em César não engana quem lê Vigenère**,
e a tela de captura diz exatamente isso.

**Desvio deliberado do pedido:** o brief pedia 2–3 cores já na fase 1, com `sha`/`aes`/`rsa`.
Duas mudanças:

- **AES/RSA viraram César/Vigenère/SHA-256.** `aes` e `rsa` não são verbos do AFD e não
  têm implementação; usar os três algoritmos que o jogo realmente ensina mantém a mecânica
  ligada ao conteúdo do TCC.
- **A fase 1 tem dois cachorros, ambos verdes.** Um cachorro azul na fase 1 seria captura
  inevitável, porque o jogador ainda não tem como produzir Vigenère ali. A progressão é
  fase 1 = verde · fase 2 = verde + azul · fase 3 = as três. A fase 1 ensina a **ler** a
  cor; a escolha entre cores começa na fase 2, quando ela é justa.

Para que "justo" não dependa de disciplina, `FaseConfig.problemas()` **recusa a fase** se
algum cachorro exigir uma cifra que nenhum desafio daquela fase produz.

Duas consequências de projeto: `DesafioConfig.algoritmo` (vazio = herda o da fase), o que
permitiu desafios de revisão nas fases 2 e 3; e os **desafios agora ciclam**, para o jogador
sempre conseguir reaplicar a cifra que a cor exige — resolver de novo não pontua.

### 4. Caixa de puzzle no pacote

Três pacotes por fase. Encostar abre um painel com um botão por opção, na cor do algoritmo;
acertar coleta, errar custa pontos e deixa tentar de novo; `ESC` fecha sem responder. A
caixa pausa a árvore e roda com `process_mode = ALWAYS` — a pausa é o que impede uma captura
enquanto o jogador lê.

Botão em vez de campo de texto porque o terminal **já** mede digitação; o pacote mede
**escolha**, e erro de digitação aí viraria ruído no dado.

**Telemetria:** vai como `tentativa_comando` com `desafio` prefixado de `pacote-`,
`SUCESSO`/`ERRO_SEMANTICO` e `codigo_erro = "opcao_incorreta"`. Nenhum código de evento novo
foi inventado — o catálogo é fechado pelo banco (restrição 7 da seção 4 do `CLAUDE.md`), e um
código inventado viraria `INSERT` rejeitado, ou seja, dado de pesquisa perdido. Exemplo real
documentado em [docs/contrato-telemetria.md](docs/contrato-telemetria.md).

### 5. Porta

`Marcadores/PontoDeSaida` ganhou o script `porta.gd`: cadeado vermelho enquanto faltar
pacote, vão verde depois. Chegar trancado escreve no terminal quantos faltam, sem punição.
Aberta, ela leva direto à fase seguinte — o encadeamento já existia em
`FaseBase._PROXIMA_CENA_POR_FASE`, e **é ali que a fase 4 entra, com uma linha**.

### 6. Tutorial de cores no menu

Botão **tutorial de cores** e painel no estilo do painel de telemetria, montado a partir de
`LegendaCores.entradas()` — a "cola" não pode discordar do jogo, então ela lê o mesmo dado.
Traz a legenda cor → cifra, uma frase explicando cada algoritmo (hash × cifra simétrica ×
chave-palavra) e as teclas.

---

## O modo RL continua intacto

Não existe `rl_mode` neste repositório. A chave foi criada como
`ConfigJogo.modo_treino` (`config.cfg`, seção `[jogo]`, padrão `false`), e **só** as duas
mecânicas que pressupõem um humano ficam atrás dela:

| | `modo_treino = false` | `modo_treino = true` |
|---|---|---|
| Pacote | abre a caixa de puzzle | coletado ao encostar |
| Proteção | só a cifra da cor do cachorro | qualquer cifra ativa |

Labirinto, A\*, patrulha, Diretor, terminal, porta, vidas, pontuação e telemetria são
idênticos nos dois modos. Coberto por
`tests/teste_modo_humano.gd::teste_modo_treino_coleta_direto_e_aceita_qualquer_cifra`.

---

## Testes

Arquivo novo `tests/teste_modo_humano.gd` (10 testes, 50 verificações): cores vindas da
legenda, patrulha sem perseguição, cifra certa × errada, captura com cifra errada e o que
ela registra, caixa de puzzle (erro → acerto, telemetria, pausa), cancelamento, porta
trancada/aberta, modo de treino e a recusa de cachorro impossível.

Suíte completa, exceto os dois arquivos de HTTP:

```
analisador 23 · astar 4 · catalogos 4 · cenas 6 · cesar 7 · config_jogo 7
demonstracao 7 · diretor 7 · encadeamento 2 · entrada 5 · fase 23
identificador 4 · menu 1 · modo_humano 10 · relogio 4 · resolvedor 21
sha256 5 · telemetria 14 · vigenere 7
```

**161 testes, 941 verificações, 0 falhas.**

`teste_transporte_http.gd` e `teste_resiliencia_http.gd` **não foram executados**: eles
sobem `tools/servidor_eco.py` como processo real e não há `python` instalado nesta máquina.
Nada nesta entrega toca o transporte HTTP, mas isso precisa rodar numa máquina com Python
antes de fechar a validação.

---

## O que precisa ser validado à mão (não dá para fazer por código)

1. **Jogar a fase 1 inteira no editor.** Ritmo, distância entre pacotes, agressividade das
   patrulhas e legibilidade das cores só se avaliam em tela. O traçado foi conferido por
   conectividade e integração, nunca visto.
2. **Clicar nos botões da caixa de puzzle com o jogo pausado.** Os testes chamam
   `escolher()` diretamente; o caminho de mouse/teclado com `process_mode = ALWAYS` é
   sólido por construção, mas merece um clique de verdade.
3. **Travessia menu → fase 1 → fase 2 → fase 3 → menu**, agora com a porta no meio. Continua
   sem teste automatizado pelo mesmo motivo do Marco 3 (`change_scene_to_file` dentro do
   processo compartilhado da suíte).
4. **Contraste das cores** no projetor/monitor da escola — verde, azul e roxo foram
   escolhidos com luminosidade parecida, mas isso se confirma olhando.

## O que ficou de fora, e por quê

- **Fases 2 e 3 continuam com o labirinto antigo** (19×13, idêntico entre as duas).
  Ganharam cachorros coloridos, pacotes e porta, mas o remodelamento do traçado não foi
  pedido.
- **Uma crença do Diretor por cachorro.** Nas fases 2 e 3 todos perseguem a mesma região
  suspeita — eles se espalham na varredura, mas andam em matilha. Separar as crenças mexeria
  no ADR 0002 e não estava no escopo.
- **Tela de "fase concluída"** entre fases: as três fases existem e encadeiam direto, então
  a tela de "fase 2 em breve" prevista no pedido não tem quando aparecer.
