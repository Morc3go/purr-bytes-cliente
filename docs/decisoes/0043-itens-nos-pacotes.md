# ADR 0043 — Novelo, peixe e rato no lugar dos pacotes

**Data:** 2026-11-22 · **Situação:** aceita

## Contexto

Os pacotes de dados eram desenhados com `_draw()`: um losango amarelo de 10 px,
provisório até existir arte. A equipe desenhou três itens para o gato buscar: um novelo,
um peixe e um rato. Do peixe vieram duas versões, e a escolhida foi a de olho preto.

## Decisões

- **Arte.** Os originais ficam em `tools/arte/originais/itens/`. O peixe de olho amarelo
  fica guardado como `_peixe_olho_amarelo_nao_usado.png`, mas não entra no jogo.
  `tools/arte/montar_itens.py` recorta cada item ao menor retângulo que cabe o desenho,
  para ele ficar centrado na célula, e grava em `recursos/arte/itens/`.
- **Cena.** `pacote.tscn` ganhou um `Sprite2D` (`Item`), que substitui o `_draw()`.
- **Qual item aparece.** Os três se revezam pela posição do pacote na fase: o primeiro é
  novelo, o segundo peixe, o terceiro rato, e o quarto volta ao novelo.
  - A posição é fixa na fase (as perguntas é que são sorteadas entre as posições), então
    o mesmo lugar do mapa mostra sempre o mesmo item.
  - Ao coletar, o item some, como o losango sumia.
- **Prévias.** As miniaturas da escolha de cenário foram geradas de novo, já com os itens
  (`tools/gerar_previas_de_cenarios.gd`).

## Consequências

- É só aparência: pergunta, coleta, porta trancada, HUD e telemetria dos pacotes não
  mudam.
- Testes em `teste_itens_dos_pacotes.gd`: os três itens cabem na célula, a fase os
  reveza na ordem e o item some ao coletar.
