# ADR 0031 — Logo, gatinho mexendo o rabo e moldura de vinhas no menu

**Data:** 2026-11-15 · **Situação:** aceita (no menu, substitui o título em texto e os
três bichinhos parados das ADR 0024 e 0030, e o contorno do cartão da ADR 0023). O gatinho
do menu passou a ser o siamês na ADR 0039

## Contexto

A equipe desenhou o logo do jogo ("crypto cats" com vinhas e flores) e um GIF do gato
amarelo sentado mexendo o rabo. Ela pediu três coisas: o logo no menu, o GIF em loop
indo e voltando no lugar dos três bichinhos, e as vinhas com flores do logo em volta
do cartão do menu, sem o contorno, só com o desfoque.

## Decisões

- **Logo.** Substitui o título em texto. O original vem com cada pixel de arte ampliado
  30 vezes. `tools/arte/montar_logo_e_vinhas.py` reduz o logo ao pixel de arte, corta as
  sobras e salva em 2x (182 × 50), na mesma escala do wallpaper. O nome continua
  disponível como dica do mouse.
- **Gatinho.** O GIF tem 6 quadros, mas só 4 diferentes. A folha guarda os 4, com o fundo
  branco trocado por transparência (só o branco ligado à borda, para o peito branco do
  gato ficar). O menu monta a sequência 0 1 2 3 2 1 em loop, a 5 quadros por segundo
  (os 200 ms do GIF). Assim o rabo vai e volta sem pular do último quadro para o
  primeiro. O gato é desenhado em tamanho real, porque a arte já é detalhada.
- **Moldura de vinhas.** Ela é gerada pelo mesmo script, com os motivos do logo nas
  mesmas cores: a vinha de um pixel que sobe e desce, brotos de folha, gavinhas e as duas
  flores (vermelha com miolo amarelo e azul com miolo laranja). Tem um cacho em cada
  canto e flores espalhadas pelas laterais. A vinha acompanha o retângulo de cantos
  arredondados do cartão e passa 6 pixels de arte para fora. O sorteio tem semente fixa
  e sempre gera a mesma imagem. A moldura fica por cima do cartão e não recebe clique.
- **Cartão.** Sem o contorno, continua só o vidro fosco (ADR 0023). Passou a 300 × 312
  na tela base, para caber o logo e o gatinho. Os botões ficaram com 28 de altura.

## Consequências

- A moldura é gerada para o tamanho exato do cartão. Se o cartão mudar, ajuste `CARTAO`
  no script e rode de novo. Um teste confere que a imagem e o cartão batem e que o
  conteúdo não fez o cartão crescer.
- Os cachorros continuam no jogo como vigias; só saíram do menu.
