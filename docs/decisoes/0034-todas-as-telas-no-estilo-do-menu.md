# ADR 0034 — Todas as telas no estilo do menu, no tom do wallpaper

**Data:** 2026-11-20 · **Situação:** aceita (estende as ADR 0023, 0027, 0031, 0032 e 0033
a todas as telas; substitui o tema claro de `tema_telas_secundarias.tres`)

## Contexto

Na etapa final do jogo, a equipe pediu que as telas que ainda eram claras (seleção de
fases, escolha do gato, editor, telemetria e os painéis do jogo) ficassem iguais ao menu.
Isso quer dizer o wallpaper escolhido ao fundo, com desfoque, a moldura de vinhas com
flores no lugar do contorno, e os botões no balãozinho de flores. Tudo deve combinar
com a cor do wallpaper escolhido na galeria.

## Decisões

- **Paleta por fundo.** `GaleriaDeFundos` ganhou duas cores por fundo:
  - o **tom**, que é a cor do miolo do balão;
  - a **tinta**, um tom escuro da mesma família que o vidro mistura ao fundo
    desfocado.

  No lago das carpas a tinta é o verde-azulado da água, e o laranja fica só nos
  balões, como os peixes.
- **Um tema gerado, não seis arquivos.** `TemaDaGaleria.tema(fundo)` monta em código,
  uma vez por fundo, o tema completo a partir dessas duas cores:
  - os botões são o balão do fundo, com as mesmas margens do menu;
  - todo o texto é branco e sem contorno, e dicas e rodapés usam um branco um pouco
    apagado;
  - listas, abas, campos, barras de rolagem e separadores ficam no tom do fundo;
  - os diálogos e os menus suspensos são opacos na mesma família de cor, porque
    são janelas e não têm vidro por trás.

  Trocar o fundo na galeria troca tudo de uma vez.
- **Vidro e vinhas com uma chamada.** `EnfeiteDaGaleria.enfeitar(raiz, cartões)` faz
  três coisas:
  1. põe o tema na raiz;
  2. dá o vidro fosco a cada cartão, com o material compartilhado
     `recursos/shaders/vidro_fosco.tres`;
  3. acrescenta a moldura de vinhas como irmã do cartão, por cima da borda.

  Uma `BackBufferCopy` antes de cada cartão faz o segundo vidro desfocar o que está de
  fato atrás dele. É o caso da escolha do gato sobre a seleção e do diagnóstico sobre
  a telemetria. Toda tela nova fica igual às outras com uma linha.
- **Moldura desenhada pelo jogo.** A moldura do menu era um PNG gerado em Python para um
  único tamanho de cartão. Agora cada tela tem um cartão de tamanho diferente, e
  alguns cartões crescem com o texto. Por isso `MolduraDeVinhas` desenha o mesmo
  desenho para qualquer tamanho:
  - a vinha de um pixel, as gavinhas, os brotos e as flores vermelha e azul do
    logo, com semente fixa;
  - o desenho é feito em pixels de arte e mostrado em 2x;
  - cada tamanho é desenhado uma vez só (cache).

  O menu passou a usar a mesma moldura, e `moldura_vinhas.png` saiu.
- **Onde vale.**
  - Telas: seleção, escolha do gato, editor (as três abas), telemetria (visão
    geral, fases jogadas, detalhe e diagnóstico) e diálogos.
  - Painéis do jogo: terminal, painel da cifra (F4), pergunta do pacote, tela de
    captura e pausa.
  - A faixa de cima e o rodapé de teclas do jogo ficam na tinta do fundo, sem vidro,
    para não desfocar o labirinto a partida inteira.
  - Atrás do labirinto, no lugar do verde-claro, aparece o wallpaper escolhido.
- **Botões padronizados.** Todos os botões são o mesmo balão com texto branco, inclusive
  "excluir" e "remover". O que eles fazem é dito pelo texto e pela confirmação. Os
  botões pequenos das linhas do editor usam o balão na altura mínima (24 px), com
  folga lateral maior que as quinas desenhadas, para as flores não cobrirem o texto.
- **Legibilidade medida, não estimada.** A tinta de cada fundo foi ajustada para o
  texto branco ter contraste de pelo menos 4,5:1 (nível AA da WCAG). O cálculo usa as
  partes mais claras de cada wallpaper: blocos de 16 × 16, percentil 90 de
  luminância. Um teste refaz a conta para os seis fundos.

## Consequências

- `tema_telas_secundarias.tres` continua no projeto, mas as telas trocam o tema dele
  pelo da galeria no `_ready`. A cor de cada tela não está mais em arquivos de cena,
  e sim em `TemaDaGaleria`.
- O painel de pergunta do pacote mostra as opções em balões iguais e sem cor própria,
  o que mantém a regra de que a cor não pode entregar a resposta.
- `tools/capturar_galeria.gd` tira um print de cada tela e painel em cada fundo, para
  conferir tudo de uma vez.
- Testes: `teste_tema_da_galeria.gd` cobre o tema de cada fundo, o contraste, o vidro
  com vinhas em todas as telas e painéis, os balões no tom certo, a troca pela galeria
  e o wallpaper atrás do labirinto. Os testes de "tela opaca" passaram a aceitar o
  vidro fosco, cujo shader devolve pixel opaco.
