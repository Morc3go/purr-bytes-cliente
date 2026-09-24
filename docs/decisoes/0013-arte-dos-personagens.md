# ADR 0013 — Arte dos personagens: folha PNG → SpriteFrames → AnimatedSprite2D

**Data:** 2026-09-24 · **Situação:** aceita

## Contexto

Jogador e cachorro eram quadrados de 16×16 (`*_placeholder.png`) num `Sprite2D`.
Chegou a pixel art do gato: uma folha com 5 linhas × 4 quadros (andar para baixo,
direita, cima, esquerda e sentado), exportada ampliada 10× sobre fundo preto.

## Decisões

### 1. A folha é normalizada fora do Godot, uma vez, por script versionado

`tools/arte/extrair_gato.py` mede o tamanho do pixel de arte pela autocorrelação
das bordas (deu 10 px), amostra a mediana do centro de cada pixel (robusto contra
artefato de compressão), remove o fundo preto e reduz a paleta. Saída:
`recursos/arte/gato.png`, 96×120, quadros de 24×24 com os pés alinhados na base.
Refazer a arte é rodar o script de novo, não retocar à mão.

### 2. O cachorro é desenhado em tons de cinza

Não veio arte de cachorro. `tools/arte/desenhar_cachorro.py` desenha um na mesma
grade do gato, em cinza, porque a cor de cada vigia é **mecânica** (ADR 0010: a
cor diz qual comando o bloqueia) e chega por `modulate`. Uma folha por cor
duplicaria arte a cada cor nova do editor; cinza tingido não duplica nada.

### 3. Ferramentas nativas: `SpriteFrames` + `AtlasTexture` + `AnimatedSprite2D`

`tools/gerar_sprite_frames.gd` monta os `.tres` (`gato_frames.tres`,
`cachorro_frames.tres`) com uma `AtlasTexture` por quadro — um PNG só no disco,
recortes dentro do recurso — e salva com `ResourceSaver`. Depois de gerados, são
recursos comuns, editáveis no painel SpriteFrames do editor.
`AnimatedSprite2D` foi preferido a `AnimationPlayer` porque a animação aqui é só
"qual quadro mostrar"; não há outra propriedade para animar junto.

### 4. Um script de animação para os dois personagens

`AnimadorDirecional` (estende `AnimatedSprite2D`) escolhe a animação pelo eixo
dominante da velocidade real, depois do `move_and_slide()`. Abaixo de
`velocidade_minima` o personagem senta; acima de `velocidade_de_referencia` os
passos aceleram na mesma proporção. Os dois limiares são `@export_range`.

### 5. `y_sort_enabled` na raiz da fase

O quadro de 24 px é maior que o tile de 16 e invade a célula de cima: sem ordenação
por Y, um cachorro logo abaixo do gato apareceria atrás dele. O labirinto fica na
origem, então continua desenhado antes dos personagens.

## Consequências

- Colisão não mudou (caixa 10×10): arte maior não altera jogabilidade nem os
  testes de TC-01 a TC-04.
- `tests/teste_sprites.gd` cobre os recursos (5 animações × 4 quadros, nenhum
  quadro vazio), a regra de direção e as cenas.
