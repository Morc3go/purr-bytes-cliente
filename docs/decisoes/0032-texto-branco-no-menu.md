# ADR 0032 — Texto do menu branco e sem contorno

**Data:** 2026-11-15 · **Situação:** aceita (substitui o contorno dos textos das ADR 0023,
0027 e 0029, só no menu principal)

## Contexto

A equipe pediu que todas as escritas do menu fossem brancas, sem contorno nenhum, e que
as letras do logo fossem brancas em vez de pretas.

## Decisões

- No `tema_menu_principal.tres`, botões e rótulos usam texto branco em todos os estados
  (normal, mouse por cima, apertado e em foco), com `outline_size = 0`.
- O logo continua igual ao desenho da equipe. Só as letras, pretas no original, viram
  brancas, em `tools/arte/montar_logo_e_vinhas.py`. Vinhas e flores mantêm as cores.
- A linha "letramento digital e criptografia", abaixo do logo, saiu do menu, também a
  pedido da equipe. O conteúdo do cartão ficou centralizado na vertical.
- O teste que exigia contorno nos textos sobre o vidro fosco agora confere o contrário:
  texto branco e sem contorno.

## Consequências

- Sem contorno, a leitura depende do fundo: o verde da moldura dos botões e o vidro
  fosco do cartão. As outras telas não mudam.
