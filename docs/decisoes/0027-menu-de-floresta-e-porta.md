# ADR 0027 — Menu de floresta, botões com moldura de flores e porta de madeira

**Data:** 2026-11-11 · **Situação:** aceita (substitui o wallpaper de neve e os botões
azuis da ADR 0023)

## Contexto

A equipe mandou três artes: uma floresta para o fundo do menu, uma moldura verde com
flores nos cantos para os botões do menu e uma porta de madeira (fechada e aberta) para a
saída do labirinto. As três vieram em JPEG: a moldura sobre fundo preto e a porta sobre
fundo branco, ambos no lugar do transparente.

## Decisões

- **Extração.** `tools/arte/montar_menu_floresta.py` limpa as três imagens: lê a cor no
  meio de cada pixel de arte, agrupa as cores sem perder as raras (rosa e branco das
  flores) e torna transparente só o fundo ligado à borda da imagem. Os originais ficam em
  `tools/arte/originais/menu_floresta/`.
- **Wallpaper.** Grade de 320x180 ampliada 2x, o dobro do detalhe do wallpaper de neve,
  porque a folhagem fina sumiria numa grade de 160x90. O cartão de vidro fosco continua
  por cima. O wallpaper de neve e o de estrelas antigo saíram.
- **Botões.** A moldura (71x41) entra como `StyleBoxTexture` em "nine-patch" no tema do
  menu: as quinas com flores (13x12) ficam do tamanho desenhado e só o miolo verde estica,
  então o texto cabe em qualquer largura. Passar o mouse clareia, apertar escurece, e o
  foco do teclado ganha um contorno creme. Os botões têm 30 px de altura (as quinas
  precisam de 24) e o cartão cresceu de 272 para 304 px para caber os cinco. O texto dos
  botões é branco com contorno verde-escuro, para ler sobre o verde; título e subtítulo
  continuam com o contorno cinza-bebê.
- **Porta.** Fica fechada enquanto falta pacote e aberta quando o gato resgata todas as
  mensagens, a mesma regra que já trancava a saída. O desenho (24x32) é maior que a
  célula de 16 px: a base fica na base da célula e a porta sobe pela cerca. A área de
  saída continua sendo a célula.

Testes: `teste_telas_opacas.gd` (moldura dos botões) e `teste_arte_do_menu_e_porta.gd`.
