# ADR 0025 — Grama e cerca viva provisórias no labirinto

**Data:** 2026-11-11 · **Situação:** aceita (arte provisória, a trocar pela definitiva)

## Contexto

O labirinto ainda usava o atlas de placeholder (piso creme e parede escura). A equipe
mandou, como arte temporária, uma grama em pixel art para o chão e uma prancha de cercas
vivas vistas em 3/4 para as paredes. As duas vieram em JPEG, e a prancha de arbustos
tinha o xadrez de "transparente" gravado como pixel de verdade.

## Decisões

- **Só visual.** O TileMapLayer continua sendo a fonte de parede (camada `solido`), então
  colisão, A*, gerador de mapas e fases salvas não mudam. `ArbustosDoLabirinto`
  (`cenas/base/arbustos_do_labirinto.gd`), filho do labirinto, desenha por cima e deixa
  os tiles de placeholder invisíveis com `self_modulate` transparente, que não desliga a
  colisão.
- **Chão.** `recursos/arte/grama.png` (64x64, emenda nos quatro lados), repetida em
  ladrilho sob o mapa.
- **Paredes em quartos.** Cada célula de parede (16x16) é montada em quatro peças de 8x8.
  Cada quarto olha os dois vizinhos do seu lado e a diagonal e escolhe entre quina de
  fora, borda horizontal, borda vertical, quina de dentro e miolo. São 20 peças
  (`recursos/arte/arbusto_pecas.png`) para qualquer formato que o gerador criar; tiles
  inteiros seriam 47.
- **Extração.** `tools/arte/montar_labirinto_provisorio.py` reduz as pranchas à grade de
  pixel de arte, limpa a paleta do JPEG, apaga o xadrez e recorta as peças do primeiro
  anel de arbusto da prancha. Os originais ficam em
  `tools/arte/originais/labirinto_provisorio/`.
- **Porta legível.** O fundo translúcido da porta virava verde-oliva sobre a grama e
  passou a ser creme quase opaco.

## Consequências

Para trocar pela arte definitiva, basta gerar as duas imagens no mesmo arranjo (ou
trocar só este nó), sem mexer em regra. A cerca da prancha tem uns 12 px de espessura
para 16 px de célula, então os corredores parecem um pouco mais largos que a parede.

Testes: `teste_arbustos_do_labirinto.gd`.
