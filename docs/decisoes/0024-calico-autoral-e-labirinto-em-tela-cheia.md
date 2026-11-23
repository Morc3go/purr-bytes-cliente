# ADR 0024 — Calico autoral como único gato e labirinto do tamanho da tela

**Data:** 2026-11-11 · **Situação:** aceita (substitui a escolha de aparência da ADR 0021)

## Contexto

A equipe desenhou a própria folha do gato calico e pediu três coisas: usar essa arte,
tirar o gato tuxedo ("frajola") do jogo e deixar o labirinto do tamanho da tela, sem
aproximar tanto a ponto de distorcer os sprites. No menu, o gato deve ficar sentado de
olho aberto entre os dois cachorros.

## Decisões

- **Um gato só** (substituído pela ADR 0030, que trouxe três gatos). `recursos/arte/gato_calico.png` passa a vir da prancha autoral
  (`tools/arte/originais/gato_calico/calico_autoral.jpg`), montada por
  `tools/arte/montar_calico_autoral.py`. A prancha chegou em JPEG, com fundo branco e
  pixels de arte de 8x8: o script lê a cor no miolo de cada bloco, agrupa as cores numa
  paleta de 21, separa o fundo (branco ligado à borda) do branco do pelo (cercado pelo
  contorno) e alinha os pés de cada linha, como `montar_folhas_32.py` faz com os
  cachorros. Quadros de 32x32, iguais aos dos cachorros.
- **Animações.** Andar nas quatro direções (os ciclos de 3 quadros viram 0-1-2-1),
  `parado` (em pé), `sentado` (olho aberto, dois quadros em que o rabo mexe) e
  `descansar` (sentado de olho fechado, usado depois de 10 s sem entrada, ADR 0017).
- **Tuxedo removido.** Saem a folha, os SpriteFrames, os quadros originais,
  `AparenciaGato`, o botão "< gatinho >" do menu e o teste da aparência. A
  preferência gravada por versões anteriores fica sem uso e é ignorada. A folha antiga
  do calico (24x24) e os scripts que a geravam também saem.
- **Menu.** O gato usa o primeiro quadro de `sentado`, sem tocar: fica quieto entre o
  caramelo e o husky, como os cachorros. O cochilo por inatividade continua só dentro da
  fase.
- **Labirinto em tela cheia.** O tamanho padrão passou de 21x15 para **39x19** (624x304
  px), o maior labirinto ímpar que cabe entre a faixa do HUD e a dica de comandos da tela
  base com zoom 1. Valem para o editor, para a fase de exemplo e para as cinco fases de
  demonstração.
- **Zoom sem distorção.** `Enquadramento` calcula o zoom da câmera para o labirinto
  encher a área útil. Pixel art só fica uniforme quando cada pixel de arte vira um número
  inteiro de pixels do monitor, então o zoom preferido é k / escala_da_janela. Ele só é
  usado se perde no máximo 10% do tamanho; numa janela de proporção quebrada vale o zoom
  exato, para o mapa não encolher pela metade. O teto é 2x, para labirintos pequenos não
  virarem pixel gigante. Em 1280x720 e 1920x1080, o labirinto padrão fica em zoom 1. A
  conta é refeita quando a janela muda de tamanho, e o jogo abre maximizado.
- **Instalações antigas.** Quem já tinha a trilha de demonstração ou o exemplo gravados
  em `user://fases` recebe o mapa novo só na cópia com o tamanho padrão antigo e a mesma
  semente. Se o professor redimensionou a fase, o tamanho dele fica, e demo excluída
  continua excluída.

## Consequências

As fases ficam mais longas, com mais corredores para fugir e mais espaço para os
vigias. Mapas bem maiores que a tela (o editor vai até 41x31) continuam com a câmera
seguindo o gato.

Testes: `teste_enquadramento.gd`, `teste_fases_demo.gd` (tamanho e atualização),
`teste_sprites.gd` (animações do calico) e `teste_pelagem_cachorro.gd` (gato sentado no
meio do menu).
