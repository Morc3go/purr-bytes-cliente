# ADR 0039 — Siamês no menu

**Data:** 2026-11-21 · **Situação:** aceita (troca o gatinho do menu da ADR 0031)

## Contexto

A equipe desenhou um siamês deitado abanando o rabo e pediu que ele ficasse no lugar do
gato amarelo do menu. A arte veio em 4 quadros soltos de 40 × 40, já no tamanho do jogo,
com fundo transparente.

## Decisões

- **O siamês substitui o gato amarelo no menu.** O script
  `tools/arte/montar_logo_e_vinhas.py` lê os quadros de
  `tools/arte/originais/menu/gato_siames_rabo/` e monta a folha
  `recursos/arte/gato_siames_rabo.png` (140 × 29, 4 quadros de 35 × 29).
- **Um recorte só para os quatro quadros.** Cada quadro é cortado pelo menor retângulo
  que cabe o gato em todos eles. Assim o corpo fica parado e só o rabo mexe.
- **Um pouco maior, a pedido da equipe.** O siamês (35 × 29) é menor que o gato
  amarelo (49 × 38), então o menu o mostra ampliado 4/3 (`ESCALA_DO_GATO`): fica com
  47 × 39 e ainda cabe no espaço de 40 de altura do mascote, sem aumentar o cartão. Na
  janela padrão (1920 × 1080, 3x a base) cada pixel de arte vira 4 pixels de tela, sem
  pixel torto.
- **A animação não mudou.** Continua a ida e volta 0 1 2 3 2 1, a 5 quadros por segundo,
  montada em `menu_principal.gd`.
- **A folha antiga saiu.** `gato_rabo.png` foi apagada. O GIF original do gato amarelo
  fica em `tools/arte/originais/menu/` como referência.

## Consequências

- O vídeo de demonstração (`tools/roteiro_video_demonstracao.gd`) também usa o siamês
  na cartela, com o tamanho do quadro lido da folha.
- `teste_logo_e_vinhas.gd` confere a folha nova e que o menu usa o siamês.
