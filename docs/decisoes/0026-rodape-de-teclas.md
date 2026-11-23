# ADR 0026 — Rodapé de teclas no lugar da legenda de cores

**Data:** 2026-11-11 · **Situação:** aceita

## Contexto

Jogando, a equipe percebeu que o jogo não deixava claro **como** cifrar. O rodapé
listava o comando de cada cor de vigia ("cifrar senha chave=3"), mas não dizia que os
comandos se digitam no terminal, nem qual tecla abre o terminal. No alto, o aviso fixo
"texto claro" ocupava a barra o tempo todo sem dizer o que fazer.

## Decisões

- **Rodapé de teclas.** O HUD mostra, sempre, o que cada tecla faz: **T** abre o terminal
  e digita o comando que cifra, **F4** mostra como a cifra funciona, **Esc** pausa e as
  **setas** andam. Cada tecla aparece numa "tampinha" de teclado. O F3 (rotas do A*) fica
  de fora por ser recurso de demonstração para a banca, não de jogo.
- **Comandos de cada vigia.** Saem do rodapé e continuam no texto de abertura do terminal,
  nos verbos `status` e `dica` e na tela de captura. Com isso, `mostrar_comandos`
  continua valendo onde já valia: numa fase de avaliação, a tela de captura não entrega o
  comando.
- **Aviso de proteção.** Só aparece quando há uma cifra (ou comando) ativa, com o nome e o
  tempo restante. Sem proteção, o canto fica vazio.

Teste: `teste_reiniciar_e_comandos.gd`.
