# ADR 0035 — Cenários do labirinto e porta em arco

**Data:** 2026-11-21 · **Situação:** aceita (estende a ADR 0025; troca a porta da ADR 0027).
O cenário do editor virou sugestão: quem escolhe na hora de jogar é o jogador (ADR 0036).

## Contexto

O labirinto tinha um único visual: grama verde e cerca viva. A equipe achou simples
demais. Ela mandou texturas e sprites (água, madeira, pedras, árvores, miudezas, portas
em arco e um boneco de neve) e aprovou, por simulação, sete cenários novos. Pedidos
feitos durante a aprovação:

- sem árvores no meio do labirinto;
- poucos enfeites, só no chão e nunca em cima da cerca;
- sem grama verde nos cenários que não são verdes;
- dois bonecos de neve no inverno;
- grama rosa na cerejeira;
- a porta em arco de pedra, proporcional à célula.

## Decisões

- **Cenário é dado da fase, e só aparência.** Cada fase pode ter um destes cenários:

  | Cenário | Chão | Cerca | Enfeites |
  |---|---|---|---|
  | `jardim` (padrão) | grama verde | cerca viva | nenhum |
  | `outono` | grama dourada | arbusto laranja | folhas e cogumelos |
  | `cerejeira` | grama rosa | arbusto rosa | moitas e flores rosa |
  | `lago` | deck de tábuas | água | vitórias-régias e sapinhos |
  | `inverno` | neve | arbusto nevado | dois bonecos de neve |
  | `ruinas` | terra | pedra cinza | pedras, tocos e cogumelos |
  | `bosque` | verde escuro | arbusto azul | flores azuis e vaga-lumes |
  | `lavanda` | verde-claro | arbusto lilás | lavanda |

  O que é parede continua vindo do `TileMapLayer` (camada `solido`). Colisão, A\*,
  regras e telemetria são idênticos em todos, e as medidas de turmas que jogaram a mesma
  fase em cenários diferentes continuam comparáveis. O cenário não gera evento.
- **No JSON da fase.** O campo é `"cenario"`. Sem o campo, a fase fica no jardim, então
  as fases antigas não mudam. Um nome desconhecido é erro de validação, com a lista dos
  válidos. O editor tem o seletor "cenário do labirinto" na aba geral, e a seleção de
  fases mostra o cenário de cada uma.
- **Trilha de demonstração com um cenário por fase:**
  1. César: outono.
  2. Vigenère: cerejeira.
  3. SHA-256: lago.
  4. Golpes digitais: bosque encantado.
  5. Avaliação final: inverno.

  A versão da trilha subiu para 3. Quem já a tinha instalada recebe o cenário só nas
  fases que ainda não têm um, e a escolha do professor fica.
- **Enfeites contidos.** Os enfeites seguem estas regras:
  - são poucos (até 6) e menores que a célula, sempre desenhados dentro dela;
  - ficam longe das células da entrada, da saída, dos pacotes e de onde nascem os
    cachorros;
  - os bonecos de neve só vão em becos sem saída;
  - as vitórias-régias só vão na água.

  O sorteio usa a semente do mapa e um embaralhamento próprio, e não o aleatório
  global: a mesma fase tem sempre os mesmos enfeites nos mesmos lugares. A roupa do
  labirinto é vestida depois de pacotes e cachorros estarem no lugar.
- **Mesma arte, outra paleta.** Os chãos e as cercas são a grama e a folha de peças do
  jardim recoloridas cor a cor, com o mesmo arranjo de 20 peças. No lago, a parede é o
  ladrilho de água da equipe, com espuma na beira e a borda escura das tábuas. As
  miudezas vêm da folha de enfeites:
  - são reduzidas;
  - perdem o tufo de grama da base;
  - têm o verde trocado pela cor do cenário.

  O boneco de neve foi redesenhado em 13 × 16 pixels, porque reduzido virava borrão.
- **Porta em arco.** A porta virou o arco de pedra com porta de madeira, em 18 × 16
  pixels, proporcional ao gato e aos cachorros. A antiga tinha 24 × 32 e subia pela
  cerca. A porta aberta é o mesmo arco com a passagem escura. A colisão continua sendo
  a célula.
- **Reprodutível.** `tools/arte/montar_cenarios.py` gera tudo a partir de
  `tools/arte/originais/cenarios/`, de forma determinística. O resultado foi conferido
  pixel a pixel contra a simulação aprovada pela equipe.

## Consequências

- Um cenário novo custa uma entrada em `CenarioDoLabirinto.DADOS` e a arte no script.
  Nenhuma linha de regra muda.
- As imagens de origem dos enfeites e das portas são de terceiros, como os wallpapers da
  ADR 0033. Antes de publicar, confirmar créditos e permissão de uso.
- Testes: `teste_cenarios.gd` cobre:
  - a arte de cada cenário;
  - a ausência de verde nos enfeites dos cenários não verdes;
  - as paredes iguais em todos os cenários;
  - os enfeites fora da cerca, dentro da célula e longe do que importa;
  - o boneco de neve só em beco sem saída;
  - o determinismo;
  - o JSON;
  - a trilha e a migração da trilha instalada;
  - o seletor do editor.

  O teste da porta confere o arco de 18 × 16.
