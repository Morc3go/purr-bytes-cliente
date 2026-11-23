# ADR 0023 — Nome Crypto Cats, menu de neve com vidro fosco e calico sem sombra

**Data:** 2026-11-09 · **Situação:** aceita

## Contexto

A equipe definiu os nomes: **Purr Bytes** é o nome do projeto (TCC, repositório, API,
banco); **Crypto Cats** é o nome do jogo que o jogador vê. Junto veio um novo papel de
parede para o menu (paisagem de neve em pixel art), o pedido de deixar o cartão do menu
transparente e levemente embaçado, e o de tirar a sombra do gato calico.

## Decisões

- **Nome.** `application/config/name` passou a `Crypto Cats` (título da janela e do
  executável) e o título do menu também. Pacotes, `class_name`, rotas e banco continuam
  com o nome do projeto. Trocar o nome do aplicativo mudaria a pasta `user://` e o
  professor perderia as fases criadas e a fila de telemetria; por isso
  `use_custom_user_dir` aponta para `Godot/app_userdata/Purr Bytes`, que no Windows é
  exatamente a pasta de antes (`%APPDATA%\Godot\app_userdata\Purr Bytes`).
- **Wallpaper.** O original veio em JPEG, com os pixels borrados pela compressão.
  `tools/arte/montar_wallpaper_neve.py` reduz para uma grade de 160x90, limita a paleta
  e amplia 4x com vizinho mais próximo: `recursos/arte/wallpaper_menu_neve.png`, na
  mesma escala de pixel do resto da arte. As outras telas mantêm o wallpaper de estrelas.
- **Vidro fosco.** `recursos/shaders/vidro_fosco.gdshader` vai no próprio
  `PanelContainer` do cartão: desfoca a tela atrás (25 amostras com peso gaussiano) e
  mistura com a cor do StyleBox, cujo alfa é a "tinta" do vidro. A primeira versão tinha tinta azul escura (0,42); a equipe achou escuro e pediu o vidro literalmente transparente, então a tinta é 0 e o cartão é só desfoque. O StyleBox faz
  de máscara (cantos arredondados) e os filhos não herdam o material, então texto e
  botões ficam nítidos. `teste_telas_opacas.gd` continua proibindo painel translúcido
  em geral; a única exceção é o vidro fosco, e todo texto solto sobre ele precisa de
  contorno (cinza bebê) para o branco não sumir na neve.
- **Botões e letras do menu mais claros.** O azul escuro do tema das telas secundárias
  pesava sobre a neve. `recursos/temas/tema_menu_principal.tres`, aplicado só à coluna
  do cartão do menu, troca os estilos do `Button` por um azul-acinzentado claro e põe o
  contorno de todos os textos em cinza bebê, no lugar do quase-preto; o resto (fonte, foco, outras telas) continua vindo do tema
  compartilhado, porque o Godot sobe a árvore procurando cada item que o tema mais
  próximo não define.
- **Calico sem sombra.** A elipse cinza vinha desenhada na folha.
  `tools/arte/remover_sombra_calico.py` a apaga (uma cor só, na faixa de baixo de cada
  quadro; pixels do mesmo cinza mais acima são pelagem e ficam). O nó `Sombra` do
  jogador continua escondido para a calico, então ela anda sem sombra nenhuma; a tuxedo
  não mudou.

Testes: `teste_telas_opacas.gd` (vidro do menu e título) e
`teste_aparencia_gato.gd` (nenhum pixel de sombra sob as patas da calico).
