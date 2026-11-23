# ADR 0030 — Três gatos (amarelo, cálico e siamês) e escolha antes da fase

**Data:** 2026-11-14 · **Situação:** aceita (substitui o "um gato só" da ADR 0024)

## Contexto

A equipe terminou as pranchas autorais de mais dois gatos, com as mesmas 18 poses do
cálico: o **amarelo**, que passa a ser o gato base, e o **siamês**. O pedido foi que o
jogador escolha o gatinho ao começar a fase, vendo o desenho de cada um.

## Decisões

- **Uma ferramenta para as três pranchas.** `tools/arte/montar_calico_autoral.py` virou
  `tools/arte/montar_gatos_autorais.py`, com uma entrada por pelagem em `GATOS`. As
  pranchas não são iguais: a do amarelo foi redimensionada (cada pixel de arte mede
  7,8 px, e não 8) e a do siamês tem fundo cinza, e não branco. A ampliação e o início
  da grade foram medidos pela periodicidade das bordas da imagem (pico da transformada
  de Fourier). A leitura passou a usar o centro de cada bloco em ponto flutuante e o
  fundo passou a ser a cor do canto. A folha do cálico gerada por esse caminho saiu
  idêntica, bit a bit, à anterior.
- **Mesma grade, mesma tabela.** As três folhas têm 4 × 5 quadros de 32 × 32, com os pés
  na mesma linha. O gerador de `SpriteFrames` usa uma tabela só (`LINHAS_GATO`) para as
  três, e os testes conferem que elas têm as mesmas animações e o mesmo número de quadros.
- **Só cosmética.** Velocidade, colisão e regras não mudam com o gato, como a pelagem dos
  vigias (ADR 0022). Por isso a escolha não entra na telemetria e não mexe no catálogo
  de eventos, que é fechado.
- **Onde a escolha acontece.** Na seleção de fases, o botão "jogar" valida o arquivo e
  abre `cenas/ui/escolha_de_gato.tscn` por cima da lista. A fase só começa depois da
  escolha, e "voltar" (ou Esc) fecha a janela sem jogar. Cada cartão mostra o desenho
  do jogo ampliado 3×. O gato em foco senta de olho aberto, os outros cochilam e ficam
  um pouco apagados. O mouse leva o foco, e clicar ou apertar Enter confirma.
- **Lembrar a escolha.** A última escolha fica em `user://preferencias.cfg`, e a janela
  já abre nesse gato. O arquivo é separado do `config.cfg`, que é da pesquisa e não deve
  guardar mais nada (restrição 8 do CLAUDE.md). Reiniciar a fase mantém o gato. O
  "testar" do editor usa o gato lembrado, sem perguntar, porque quem usa é o professor.
- **O amarelo é o gato base.** Ele vale quando ninguém escolheu ainda, em
  `jogador.tscn`, e é o gato do menu (desde a ADR 0031, mexendo o rabo).

## Consequências

- `IniciadorDeFase.jogar()` e `jogar_arquivo()` aceitam a pelagem como parâmetro
  opcional. Vazio significa "a lembrada, ou o amarelo".
- Novo `PelagemGato` (`scripts/visual/pelagem_gato.gd`), no mesmo formato do
  `PelagemCachorro`.
- Para trocar ou acrescentar um gato, basta pôr a prancha em `tools/arte/originais/`,
  incluir uma linha em `GATOS` e em `PelagemGato`, e rodar os dois geradores.
