# ADR 0037 — Husky novo e caramelo em espera

**Data:** 2026-11-21 · **Situação:** aceita (troca a arte da ADR 0020; suspende a pelagem
caramelo da ADR 0022 até a arte nova). A espera acabou na ADR 0042: o pastor ocupa o lugar do
cachorro marrom

## Contexto

A equipe redesenhou o cachorro e entregou o husky novo. Ele tem 16 quadros soltos, já
no tamanho do jogo:

| Vista | Quadros | Tamanho |
|---|---|---|
| frente | 4 | 11 × 17 |
| costas | 4 | 11 × 17 |
| direita | 3 | 22 × 18 |
| esquerda | 3 | 22 × 18 |
| senta | 2 | — |

A versão marrom (caramelo) no traço novo ainda vai ser desenhada. Até lá, o jogo fica
sem o marrom.

## Decisões

- **O husky novo substitui o antigo.** O script `tools/arte/montar_folhas_32.py`:
  - lê os quadros de `tools/arte/originais/cachorro_husky_v2/`, sem reduzir, porque
    a arte já tem um pixel de arte por pixel de jogo;
  - põe cada animação na folha de quadros 32 × 32, com os pés na mesma linha
    (`LINHA_DOS_PES`) e o corpo centrado;
  - aplica o mesmo deslocamento a todos os quadros da animação, para o passo não
    perder o balanço.

  Frente e costas têm 4 passos, e os lados têm 3 (que viram 0-1-2-1, como antes).
- **Parado, o cachorro senta.** A animação `parado` são os dois quadros de "senta" (em
  pé e depois sentado). Ela toca uma vez e o cachorro fica sentado. É a única animação
  sem repetição.
- **Caramelo em espera, sem perder a escolha.** A pelagem caramelo saiu do editor (o
  seletor de pelagem some enquanto há uma só) e da alternância automática. Um vigia que
  já estava marcado "caramelo" é desenhado como husky, mas o valor continua no JSON e o
  editor não o troca ao salvar. Quando o desenho marrom chegar, basta:
  1. gerar a folha;
  2. apontar `_QUADROS[CARAMELO]` para ela;
  3. devolver o caramelo à `ORDEM`.

  As fases que já o usavam voltam a ficar marrons sozinhas. A folha antiga do caramelo,
  no traço velho, saiu do jogo.
- **Nada muda nas regras.** A pelagem continua só visual. Quem identifica o vigia é o
  anel colorido no chão (ADR 0022), e a colisão é a mesma.

## Consequências

- Os testes de pelagem passaram a conferir:
  - que só o husky aparece no editor;
  - que o caramelo usa o desenho do husky e continua guardado;
  - que todos os vigias usam o desenho novo.
- O teste de sprites aceita o `parado` do cachorro sem repetição. O teste do editor
  confere que a pelagem guardada sobrevive a reabrir e salvar.
