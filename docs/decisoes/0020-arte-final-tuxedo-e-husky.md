# ADR 0020 — Arte final dos personagens (gato tuxedo e cachorro husky) e polimento visual

**Data:** 2026-11-01 · **Situação:** aceita · **Substitui:** a seção 1 e 2 da ADR 0013 no que diz respeito às folhas

## Contexto

A artista da equipe entregou a arte definitiva dos dois personagens: um **gato tuxedo**
(17 quadros) e um **cachorro husky** (15 quadros), cada quadro um PNG de 1024×1024 com
fundo transparente. As folhas anteriores (gato tricolor e cachorro marrom, 24×24) tinham
sido extraídas de imagens comprimidas com amostragem por mediana (ADR 0013); a arte nova
é limpa.

## Decisões

### 1. Redução exata 1024 → 32, conferida pelo script

Cada pixel de arte é um bloco de 32×32 px de cor única (conferido em todos os 32 quadros).
`tools/arte/montar_folhas_32.py` reduz pegando um pixel por bloco e **falha** se algum bloco
não for uniforme — se a próxima entrega vier reamostrada, o problema aparece na hora, em vez
de virar um borrão no jogo. O quadro do jogo passou de 24×24 para **32×32**, o tamanho em
que a arte foi desenhada. O corpo dos personagens continua com ~22 px de largura de lado
(como antes), então a escala relativa ao corredor de 16 px não mudou.

Os originais ficam em `tools/arte/originais/` (pasta ignorada pelo Godot); refazer a folha
é rodar o script de novo, sem retoque à mão.

### 2. Pés na mesma linha entre animações

As vistas foram desenhadas em alturas diferentes do quadro (a costas do husky ficava 3 px
abaixo da frente). Sem correção, o cachorro "pulava" ao trocar de direção. O script desloca
cada animação **inteira** para a última linha opaca cair na linha 27 do quadro e centraliza
na horizontal. O deslocamento é o mesmo para todos os quadros de uma animação, então o
balanço que a artista desenhou dentro do ciclo fica intacto.

Um pixel opaco isolado (sem vizinho) no quadro 10 do gato foi tratado como sujeira de
exportação e removido; o script avisa sempre que encontrar um.

### 3. Mapeamento quadro → animação

| Animação | Gato tuxedo | Cachorro husky |
|---|---|---|
| `andar_baixo` | 00–03 | 00–02 |
| `andar_direita` | 04–06 | 03–05 |
| `andar_cima` | 07–10 | 06–09 |
| `andar_esquerda` | 11–13 | 10–12 |
| `parado` | 14 | 13–14 (rabo abanando) |
| `descansar` | 15–16 (respiração) | — |

Ciclos de andar com 3 quadros desenhados tocam em vai-e-vem **0-1-2-1** (`_ciclo()` em
`tools/gerar_sprite_frames.gd`): todo andar tem 4 passos, e a perna não "teleporta" do
último passo para o primeiro. O gerador agora aceita número variável de quadros por linha.

O `descansar` ganhou dois quadros de verdade, resolvendo o compromisso da ADR 0017 §4
(antes era um quadro só, sem respiração).

### 4. Polimento visual que acompanhou a troca

- **Fundo da fase:** `default_clear_color` era o cinza padrão do Godot (`#4D4D4D`), nunca
  escolhido por ninguém, e o HUD (texto `#25211B`) ficava quase ilegível sobre ele. Virou
  lavanda pastel `#D9DEEE`, complementar ao amarelo da paleta da ADR 0017.
- **Faixa do HUD:** painel branco translúcido com borda amarela atrás de vidas/pontos/pacotes.
- **Sombra do gato:** a arte nova não traz sombra desenhada; um `MarcadorDeCor` sem contorno
  e com 22 % de opacidade faz a sombra (mesmo nó que já desenha o anel dos vigias).
- **Menu:** o husky entrou ao lado do gato no cartão, sentado e parado (ADR 0021); o gato continua dormindo após 10 s.
- **Abas do editor:** sem margem interna, os nomes das abas encostavam ("GERALCACHORROS").
- **Gráfico do painel de telemetria:** usava `ThemeDB.fallback_font`; agora usa a fonte do
  tema (Silkscreen), como o resto da tela.

### 5. Ferramenta de captura

`tools/capturar_telas.gd` abre o menu, as telas secundárias e a fase de exemplo e salva
PNGs — é como as imagens de `docs/imagens/` foram geradas, e serve para as figuras da
monografia. Precisa de janela (não roda em `--headless`).

## Consequências

- `tests/teste_sprites.gd` passou a exigir quadros de 32×32 e `descansar` com ≥ 2 quadros.
- A arte dos **tiles** do labirinto continua placeholder (pendência 4 da conformidade).
