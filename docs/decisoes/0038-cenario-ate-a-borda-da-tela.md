# ADR 0038 — O cenário continua até a borda da tela

**Data:** 2026-11-21 · **Situação:** aceita (substitui, na fase, o wallpaper da galeria
posto atrás do labirinto pela ADR 0034)

## Contexto

Na fase, as bordas da tela em volta do labirinto mostravam o wallpaper escolhido na
galeria do menu. Com os cenários (ADR 0035 e 0036), isso deixou de combinar: um
labirinto de inverno ficava com borda de brejo verde, por exemplo. A equipe pediu que o
fundo combinasse com o labirinto.

## Decisões

- **O próprio cenário é o fundo.** `ArbustosDoLabirinto` desenha, em volta do mapa, uma
  faixa de 12 células (`MARGEM_EXTERNA`) com a cerca do cenário, ou com a água, no lago.
  Ela cobre a tela até a borda, mesmo num mapa pequeno ampliado. A cerca externa do
  labirinto se emenda com essa faixa, sem contorno, e o labirinto parece escavado no
  cenário. No lago, o deck parece flutuar na água.
- **Só desenho.** Fora do mapa continua sem colisão e sem A\*, e `tipo_do_quarto`
  (a forma do mapa) segue tratando fora como chão. A faixa usa um cálculo próprio de
  peça (`_tipo_no_desenho`).
- **O wallpaper saiu da fase.** O nó `Wallpaper` da `fase_base.tscn` foi removido. O
  wallpaper da galeria continua no menu e nas telas, e a faixa de cima, o rodapé e os
  painéis da fase continuam no tom da galeria (ADR 0034).
- **Miniaturas refeitas.** As miniaturas da escolha do cenário foram geradas de novo
  com a borda nova.

## Consequências

- Testes: `teste_cenarios.gd` confere três coisas: que a faixa cerca o mapa inteiro, que
  os cantos da tela caem dentro dela e que fora do mapa continua sem colisão.
  `teste_tema_da_galeria.gd` confere que a fase não tem mais o wallpaper.
