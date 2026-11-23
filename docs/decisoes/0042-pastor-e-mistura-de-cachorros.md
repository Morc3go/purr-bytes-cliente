# ADR 0042 — Pastor e mistura dos cachorros em toda fase

**Data:** 2026-11-22 · **Situação:** aceita (completa a ADR 0037)

## Contexto

Desde a ADR 0037 só o husky tinha desenho no traço novo, e o vigia "caramelo" (o
cachorro marrom que ainda ia ser desenhado) aparecia como husky. A equipe entregou o
**pastor**, no mesmo formato do husky novo: quadros soltos no tamanho do jogo, com as
mesmas vistas. Ela pediu que as fases sempre misturem os dois, sem perguntar nada a
ninguém.

## Decisões

- **Arte.** Os quadros ficam em `tools/arte/originais/cachorro_pastor/`.
  `tools/arte/montar_folhas_32.py` monta `recursos/arte/cachorro_pastor.png` com a mesma
  grade do husky: frente, direita, costas, esquerda e sentado, com os pés na mesma linha.
  Depois, `tools/gerar_sprite_frames.gd` gera `cachorro_pastor_frames.tres` com as mesmas
  animações. Como no husky, o pastor parado senta e fica sentado.
- **Mistura sempre.** `PelagemCachorro.do_vigia(indice)` alterna pela ordem dos vigias:
  husky, pastor, husky, pastor... É isso que a fase usa (`FaseBase`), em toda fase, demo
  ou criada no editor.
- **Sem escolha.** O seletor de pelagem do editor continua escondido. O campo `pelagem`
  do JSON continua sendo lido e gravado, para fases antigas abrirem e salvarem iguais,
  mas não decide mais o desenho.
- **Caramelo.** O valor antigo "caramelo" passa a ser desenhado como o pastor, que ocupa
  o lugar do cachorro marrom.

## Consequências

- A pelagem segue só cosmética: regra, velocidade, colisão e telemetria não mudam, e
  quem identifica o vigia continua sendo o anel colorido no chão.
- Testes em `teste_pelagem_cachorro.gd`:
  - a alternância;
  - a folha do pastor, com as mesmas animações e os mesmos quadros do husky;
  - uma fase com três vigias.

  `teste_sprites.gd` confere que o gerador reproduz o `.tres` versionado.
