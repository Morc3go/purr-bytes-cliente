# ADR 0041 — Entrada sempre com rota de fuga

**Data:** 2026-11-21 · **Situação:** aceita (complementa o braiding do gerador, ADR 0024)

## Contexto

A equipe notou, jogando, que em algumas fases o gato nascia num corredor com uma saída
só. Quando o cachorro vinha por essa saída, não havia para onde correr: o gato era pego
sem o jogador ter errado nada, e podia ficar preso nesse ciclo. É uma falha de game
design: a regra do jogo é que a captura é consequência de uma decisão (não cifrar,
escolher o caminho errado), e não do lugar onde se nasce.

O gerador faz um labirinto perfeito e depois abre 75% dos becos (braiding). Os 25% que
sobram caem em qualquer lugar, inclusive na entrada, que é sempre a célula (1, 1). Num
levantamento de 300 sementes (39 × 19, 3 pacotes, 3 cachorros), **78 mapas (26%)
nasciam com a entrada fora de qualquer ciclo**. Entre as fases demo, a de Vigenère era
uma delas.

## Decisão

- **A entrada tem de estar num ciclo.** Com duas direções para sair, sempre dá para dar a
  volta no perseguidor. `GeradorDeMapa.entrada_tem_fuga` confere: sai por um vizinho da
  entrada e tenta voltar a ela sem repetir o mesmo passo.
- **Correção mínima e sem sorteio**, em `_garantir_fuga_na_entrada`, logo depois do
  braiding:
  1. mapa que já nasce com fuga não muda (a mesma semente continua dando o mesmo
     labirinto);
  2. senão, abre a outra parede da própria entrada; como o mapa é conexo, a passagem
     nova fecha um ciclo que passa por ela;
  3. se ainda não bastar, abre a parede mais perto da entrada (andando) que a ponha num
     ciclo.
- Nada disso usa o gerador de números aleatórios: a correção é a mesma para a mesma
  semente, então a fase que o professor testou continua igual para os alunos.

## Consequências

- No mesmo levantamento, 0 de 300 mapas ficam com a entrada presa.
- Das fases demo, só a de Vigenère mudou: uma parede ao lado da entrada foi aberta. As
  outras quatro já nasciam com fuga e ficaram idênticas.
- Fases criadas no editor também ficam protegidas, porque o mapa é gerado pela semente ao
  carregar a fase.
- Testes em `teste_fuga_na_entrada.gd`:
  - 600 mapas gerados em quatro tamanhos;
  - as cinco fases demo;
  - um beco e um ciclo desenhados à mão.
