# ADR 0033 — Galeria de fundos do menu, com botões no tom de cada fundo

**Data:** 2026-11-15 · **Situação:** aceita (amplia o fundo único das ADR 0027 e 0029)

## Contexto

A equipe trouxe cinco paisagens em *pixel art* para o menu: céu com montanhas, noite
estrelada, estufa, lago das carpas e piquenique. Ela pediu um botão com ícone de
galeria, no canto superior direito do menu, que troque o fundo a cada toque, com os
balõezinhos dos botões em cores que combinem com cada fundo.

## Decisões

- **Seis fundos, em ordem fixa:** brejo (o de antes, que continua sendo o padrão),
  noite, estufa, carpas, piquenique e céu. O último toque volta ao brejo.
- **Mesmo tratamento para todos.** `tools/arte/montar_arte_do_menu.py` recorta cada
  imagem em 16:9, reduz a 320 × 180 com paleta limitada e amplia 2x, em
  `recursos/arte/fundos/<nome>.png`. As carpas usam 96 cores; com 40, o laranja dos
  peixes virava amarelo-pálido. O piquenique é recortado antes, para deixar de fora a
  marca-d'água do canto. O `wallpaper_menu.png` saiu e o brejo virou `fundos/brejo.png`.
- **Botões no tom do fundo.** O script gera `balao_botao_<nome>.png` trocando só o verde
  da moldura por um tom tirado da paisagem: azul-acinzentado (céu), azul (noite),
  verde-água (estufa), laranja das carpas e madeira (piquenique). Flores, contorno e
  sombreado ficam iguais. O menu aplica a textura numa cópia do estilo de cada botão, e
  o tema compartilhado não muda.
- **Ícone.** Quadrinho com montanha e sol, 13 × 11 pixels de arte em 2x, gerado pelo
  mesmo script. O botão é pequeno e claro, com dica "trocar o fundo (agora: …)".
- **Lembrar a escolha.** O fundo fica em `user://preferencias.cfg`, ao lado do gato
  escolhido. As duas preferências passaram a usar `Preferencias`
  (`scripts/nucleo/preferencias.gd`), que nunca toca o `config.cfg` da pesquisa.
- **Telas secundárias.** Seleção, editor e telemetria usam o mesmo fundo
  (`FundoDaGaleria`), para a paisagem não mudar ao trocar de tela. Os painéis delas
  continuam na paleta pastel. *(Atualizado pela ADR 0034: hoje todas as telas usam o
  vidro, as vinhas e os balões no tom do fundo.)*
- **Fora da telemetria.** O fundo é só aparência e não gera evento.

## Consequências

- Para acrescentar um fundo, inclua uma linha em `FUNDOS` no script e o nome em
  `GaleriaDeFundos.ORDEM` e `NOMES`.
- Cinco dos seis fundos são imagens de terceiros, uma delas feita com IA. Antes de
  publicar o jogo, a equipe precisa confirmar os créditos e a permissão de uso, ou trocar
  as imagens por arte própria.
