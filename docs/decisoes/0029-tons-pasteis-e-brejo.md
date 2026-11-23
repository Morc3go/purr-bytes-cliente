# ADR 0029 — Tons pastéis (branco e verde-bebê) e brejo no menu

**Data:** 2026-11-11 · **Situação:** aceita (substitui a paleta verde da ADR 0028 e o
wallpaper de floresta da ADR 0027)

## Contexto

A equipe achou a paleta verde da ADR 0028 verde demais e pediu tons de branco e
verde-bebê. Mandou também uma nova imagem para o fundo do menu: um brejo com
vitórias-régias e sapinhos.

## Decisões

- **Paleta pastel**, a mesma nos dois temas (`tema_purrbytes.tres` e
  `tema_telas_secundarias.tres`) e nos painéis das fases:
  - painéis em branco-névoa `#f7fbf4` e campos de digitar em branco;
  - botões em verde-bebê `#cfe9c4`, mais claro (`#e3f3dd`) com o mouse por cima e mais
    escuro (`#b5dca8`) ao apertar;
  - bordas em `#a8d5a0` e destaque e foco em `#7fbf7a`;
  - texto em verde-acinzentado `#2f4a35`, com contraste alto sobre o branco.
  - O fundo fora do labirinto fica verde-bebê claro, e o escurecimento por trás das
    janelas (pausa, captura) ficou mais suave.
- **Telas secundárias.** Seleção, editor e telemetria deixaram de ser escuras e usam a
  mesma paleta clara. O teste de painel opaco continua valendo, porque os painéis são
  brancos sem transparência.
- **Destaques.** A chave no painel F4 ficou em verde, as diferenças da avalanche seguem
  em vermelho-escuro e, no dashboard, os acertos estão em verde `#7fbf7a` e os erros em
  coral.
- **Menu.** O wallpaper passou a ser o brejo, salvo como `recursos/arte/wallpaper_menu.png`
  pelo script `tools/arte/montar_arte_do_menu.py` (que antes se chamava
  `montar_menu_floresta.py`). As telas secundárias usam o mesmo fundo. O título e o
  subtítulo ficaram verde-acinzentados com contorno branco. A moldura de flores dos
  botões do menu continua a mesma, porque é arte da equipe.
