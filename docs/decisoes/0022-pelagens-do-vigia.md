# ADR 0022 — Duas pelagens para o vigia: husky e caramelo

**Data:** 2026-11-09 · **Situação:** aceita; a arte mudou nas ADR 0037 e 0042 (hoje as pelagens são husky e pastor, alternadas em toda fase, e o caramelo é desenhado como o pastor)

## Contexto

A artista entregou o cachorro em duas cores: o husky branco (já no jogo, ADR 0020) e um
cachorro caramelo, com os mesmos 15 quadros na mesma ordem.

## Decisões

- Cada vigia tem uma **pelagem** (`husky` ou `caramelo`), campo `pelagem` do JSON da fase
  e de `CachorroConfig`. É **só cosmética**: as duas folhas têm as mesmas animações
  (testado), e regra, velocidade e colisão não mudam. Quem identifica o vigia continua
  sendo o **anel colorido** no chão; por isso a pelagem não vai para a telemetria.
- **Fase sem pelagem** (todas as anteriores a esta versão) alterna husky/caramelo pela
  ordem dos vigias (`PelagemCachorro.resolver`). O mapa fica variado sem ninguém editar
  nada, e o editor mostra exatamente essa alternância ao abrir uma fase antiga, então
  abrir e salvar não muda a aparência de ninguém.
- Valor desconhecido no arquivo (ex.: `"dalmata"`) vira alternância em vez de recusar a
  fase: um erro cosmético não deve impedir uma aula.
- O editor ganhou um seletor de pelagem em cada linha de vigia; vigia novo alterna pela
  posição.
- No menu, o caramelo senta do outro lado do gato, parado como o husky.
- Arte: `tools/arte/originais/cachorro_caramelo/` → `montar_folhas_32.py` →
  `recursos/arte/cachorro_caramelo.png` → `cachorro_caramelo_frames.tres`.

Testes: `teste_pelagem_cachorro.gd` (alternância, JSON, fase, menu), round-trip no
`teste_editor_de_fase.gd` e a folha nova em `teste_sprites.gd`.
