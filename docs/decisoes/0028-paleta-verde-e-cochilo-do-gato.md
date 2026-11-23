# ADR 0028 — Paleta verde no jogo inteiro e cochilo do gato em duas etapas

**Data:** 2026-11-11 · **Situação:** aceita (muda as cores das ADR 0012 e 0023 e o tempo
da ADR 0017)

## Contexto

Com o menu de floresta (ADR 0027), o resto do jogo destoava: as fases usavam painéis
brancos com borda amarela, e as telas de seleção, editor e telemetria usavam azul-escuro.
A equipe pediu os tons de verde da moldura dos botões do menu. Pediu também que o gato,
ao parar, continue virado para onde andava, e que o cochilo fique mais rápido e em duas
etapas.

## Decisões

- **Paleta.** As cores saem da própria moldura (`balao_botao.png`):
  - miolo `#87b321`, claro `#9dc22d`, brilho `#c3d93f`;
  - médios `#6e9a1f`, `#5c881b` e `#4b741a`;
  - escuros `#395c0e`, `#274810` e `#1b390a`;
  - creme `#f8f4e7`, o branco da flor.
- **Tema do jogo** (`tema_purrbytes.tres`, HUD, terminal, painéis, captura, pausa): os
  painéis ficam no miolo verde, com borda e texto verde-escuros. Os botões ficam em verde
  médio com texto creme, e os campos de digitar num verde mais claro.
- **Telas secundárias** (`tema_telas_secundarias.tres`, seleção, editor, telemetria):
  versão escura da mesma paleta, com texto creme. O fundo delas passou a ser a floresta
  do menu, e o wallpaper de estrelas azul saiu. A cor de fundo fora do labirinto também
  ficou verde-escura.
- **Parar virado.** `AnimadorDirecional.parar_olhando_para_onde_andava` (ligado só no
  gato): ao parar, fica o primeiro quadro do andar daquela direção, congelado. O cachorro
  mantém o "parado" dele, que abana o rabo.
- **Cochilo.** Depois de 5 s sem tecla de movimento o gato senta de olho aberto e, 2 s
  depois, fecha os olhos e dorme com o "zzz". Antes eram 10 s direto para o sono. Os dois
  tempos são `@export` em `jogador.gd`, e o primeiro input acorda.

Testes: `teste_sprites.gd` (pose parada na direção e as duas etapas do cochilo).
