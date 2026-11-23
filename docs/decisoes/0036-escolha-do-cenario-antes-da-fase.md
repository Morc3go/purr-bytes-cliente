# ADR 0036 — O jogador escolhe o cenário antes da fase

**Data:** 2026-11-21 · **Situação:** aceita (complementa a ADR 0035)

## Contexto

Na ADR 0035 o cenário do labirinto era escolhido pelo professor, no editor. A equipe
pediu que o jogador escolha o cenário na hora de abrir a fase, do mesmo jeito que
escolhe o gatinho (ADR 0030).

## Decisões

- **Gatinho, depois cenário, depois fase.** Em "escolher fase", o botão "jogar" abre a
  escolha do gatinho. Ao confirmar o gato, abre a escolha do cenário, e só então a fase
  começa. Esc na escolha do cenário volta para a do gatinho, já no gato escolhido.
- **Mesma tela da escolha do gato.** A tela tem um cartão por cenário, com a miniatura do
  labirinto naquele cenário e o nome embaixo. Ela usa o mesmo cartão de vidro e o
  contorno de foco da escolha do gatinho, e o cartão fora de foco fica apagadinho. Mouse
  e teclado fazem a mesma coisa.
- **O cenário da fase vira sugestão.** O campo do editor passou a se chamar "cenário
  sugerido". O cartão que começa em foco é esse, e o subtítulo diz "a fase sugere: …".
  Quem só aperta Enter joga como o professor montou, e as fases da trilha continuam com
  o seu cenário de demonstração.
- **A escolha vale para a partida.** O arquivo da fase não muda. Reiniciar a fase
  mantém o cenário escolhido, porque a configuração da partida é a mesma.
- **Miniaturas tiradas do jogo.** `tools/gerar_previas_de_cenarios.gd` abre a fase 1
  em cada cenário e recorta 112 × 64 pixels, centrados num enfeite (o boneco de neve, o
  sapinho) ou, no jardim, no gatinho na entrada. O recorte é gravado em
  `recursos/arte/cenarios/<cenário>/previa.png`, sem HUD e na escala do pixel do jogo.
- **Continua sendo só aparência.** A escolha não gera evento novo, e as regras e a
  telemetria são as mesmas em todos os cenários.

## Consequências

- "Salvar e jogar", no editor, continua abrindo direto no cenário sugerido, para o
  professor testar a fase como a montou.
- Testes: `teste_escolha_de_cenario.gd` cobre:
  - um cartão com miniatura por cenário;
  - o foco no sugerido;
  - clique e Esc;
  - o fluxo gato → cenário → fase;
  - a volta ao gatinho;
  - a fase no cenário escolhido, sem alterar o arquivo.

  `teste_escolha_de_gato.gd` passou a esperar a escolha do cenário depois do gato.
