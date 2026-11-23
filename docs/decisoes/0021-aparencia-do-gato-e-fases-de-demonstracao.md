# ADR 0021 — Aparência do gato (tuxedo ou calico), fases de demonstração e dois bugs do terminal

**Data:** 2026-11-01 · **Situação:** aceita

## 1. O jogador escolhe a aparência do gato

A equipe quis oferecer duas aparências: o **tuxedo** (arte nova, 32×32, ADR 0020) e o
**calico** (a folha tricolor original, 24×24, ADR 0013). No menu, o botão
`< gatinho: tuxedo >` alterna entre elas; o gato do menu troca na hora e o da fase nasce
com a escolhida.

- `AparenciaGato` (`scripts/visual/aparencia_gato.gd`) guarda a escolha em
  `user://preferencias.cfg`, **não** em `config.cfg`: aquele arquivo é da coleta,
  preparado pelo pesquisador antes da sessão (CLAUDE.md, restrição 8).
- É **só cosmética**: as duas folhas têm as mesmas animações (teste
  `teste_aparencia_gato.gd`), e colisão, velocidade e regras não mudam. Por isso a escolha
  não é variável do experimento e não entra na telemetria.
- A folha calico já traz sombra desenhada; com ela o nó `Sombra` do jogador fica oculto.
- `gato.png`/`gato_frames.tres` viraram `gato_tuxedo.*` e `gato_calico.*`; o gerador de
  `SpriteFrames` aceita tamanho de quadro por folha.

O **cachorro do menu fica sentado e parado** (quadro 1 de `parado`, sem tocar): o gato é
quem se mexe e dorme, e o husky só faz companhia.

## 2. Trilha de fases de demonstração

O jogo continua sendo ferramenta de autoria (ADR 0012), mas agora traz uma trilha pronta
em `recursos/fases_demo/`, instalada em `user://fases` na primeira abertura do menu:

| Arquivo | Conteúdo | O que mostra à banca |
|---|---|---|
| `01-cesar-o-primeiro-segredo` | 2 vigias de César + 1 perseguidor | AFD → parser → semântica; F4 letra a letra |
| `02-vigenere-a-chave-que-muda` | Vigenère + revisão de César | mesma gramática, chave em palavra |
| `03-sha256-o-pacote-foi-alterado` | 2 vigias de SHA-256 (`hash` / `verificar`) | integridade e efeito avalanche |
| `04-golpes-digitais-nao-morda-a-isca` | 3 vigias de conduta (phishing, 2FA) | letramento digital além da criptografia |
| `05-avaliacao-final-sem-colinha` | tudo junto, comandos ocultos, 2 vidas | transferência do que foi aprendido |

- Cada arquivo tem `id_fase` **fixo**: a telemetria de máquinas diferentes cai na mesma
  fase no banco, o que a análise por fase (`vw_desempenho_fase`) precisa.
- A semeadura nunca escreve por cima de um arquivo existente e grava uma marca
  (`user://fases/.fases_demo`): uma fase demo que o professor excluiu não volta sozinha.
- `teste_fases_demo.gd` carrega cada fase pelo mesmo validador do jogo, gera o labirinto e
  **vence todos os vigias pelo terminal**. Foi esse teste que achou o bug da seção 3.1.

## 3. Bugs corrigidos

### 3.1 `verificar` recusava resumos SHA-256 que começam com dígito

O AFD lê `4a4d23dd` como `NUMERO "4"` + `IDENTIFICADOR "a4d23dd"`: cada classe de token é
lida pelo maior casamento, e hexadecimal não é classe da gramática. O `verificar` só olhava
o primeiro pedaço, então **10 de cada 16 palavras** tinham um vigia de SHA-256 impossível.
A fase de exemplo passava por sorte: `sha256("senha")` começa com `b`.

A correção é na etapa **semântica** (`ResolvedorComando._resolver_verificar` junta os
argumentos depois da palavra). A gramática (BNF) e o AFD da monografia não mudam. Teste de
regressão: `teste_verificar_prefixo_que_comeca_com_digito`.

### 3.2 Comando livre exigia digitação exata

`Ativar 2FA` ou `ativar  2fa` eram recusados num vigia de `ativar 2fa`, ao contrário dos
comandos de cifra, que o analisador normaliza (trim + minúsculas). O aluno perdia vida por
digitação, não por não conhecer a conduta — ruído na medida de acerto. Agora
`FaseBase.normalizar_comando_livre` aplica a mesma normalização (e junta espaços).

### 3.3 HUD dizia "fase 1" em toda fase

Toda fase de autoria tem `numero = 1` (legado da constraint do banco). O HUD e o `status`
mostravam "fase 1 -- …" até na quarta fase da trilha; agora mostram só o título.

### 3.4 A rota do A* (F3) nunca aparecia

O caminho era desenhado no `_draw()` da própria `FaseBase`, e o Godot pinta o
`_draw()` de um `Node2D` **antes** dos filhos: o `TileMapLayer` do labirinto cobria o
desenho. A rota passou para uma camada própria (`DepuracaoAStar`, `z_index` 50), e
`teste_rota_do_astar_aparece_por_cima_do_labirinto` trava a correção. Achado ao gerar
as figuras da monografia.

### 3.5 Painel de telemetria lia o registro pela metade

`Telemetria.descarregar()` voltava na hora quando já havia uma descarga em curso (a do
temporizador). O painel, que faz `await descarregar()` antes de ler, mostrava sessão
faltando e fase com 0% de acerto. Agora quem chega no meio espera o sinal
`descarga_concluida`. Teste: `teste_descarregar_durante_descarga_espera_ela_terminar`.

## 4. Figuras da monografia

`tools/figuras_monografia.gd` joga a trilha com dois participantes **fictícios**
(UUIDs `f1c71c10…`, ADR 0019), em pastas isoladas de `user://testes/monografia`, e salva
cada tela usada no capítulo de resultados. Precisa de janela (não roda em `--headless`).
