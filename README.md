# Purr Bytes — cliente Godot

Jogo educacional 2D de letramento digital e criptografia. Este repositório é o
**cliente**; o back-end de telemetria (Java 21 + Spring Boot + PostgreSQL) vive em
`Morc3go/prototipo`, pasta `Protótipo/backend`.

O contexto completo do projeto — restrições, marcos e critérios de aceite — está em
[`CLAUDE.md`](CLAUDE.md). As decisões tomadas e o porquê de cada uma estão em
[`docs/decisoes/`](docs/decisoes/).

**Godot 4.4+** (testado em 4.6.2 e 4.7.2) · GDScript com tipagem estática ·
renderizador Mobile · 640×360.

---

## Rodando

```powershell
# ajuste para onde o binário do Godot estiver na sua máquina
$godot = "$env:LOCALAPPDATA\Programs\godot\Godot_v4.7.2-stable_win64.exe"

# abrir no editor
& $godot --path .

# importar sem abrir janela (útil depois de git pull)
& $godot --headless --path . --import

# rodar o jogo headless e sair (checagem de importação limpa)
& $godot --headless --quit --path .
```

## Testes

Suíte própria, sem addon (ver [ADR 0005](docs/decisoes/0005-suite-de-testes-nativa.md)):

```powershell
& $godot --headless --path . --script res://tests/runner.gd

# só um arquivo
& $godot --headless --path . --script res://tests/runner.gd -- telemetria
```

Sai com código 0 se verde e 1 se vermelho.

## Sessão de demonstração

Abre e encerra uma sessão em modo MOCK sem abrir janela, e imprime o JSONL resultante.
É o que gera os exemplos de [`docs/contrato-telemetria.md`](docs/contrato-telemetria.md):

```powershell
& $godot --headless --path . --script res://tools/sessao_de_demonstracao.gd
```

## Simulação de queda (demonstração de resiliência)

Dois processos: o primeiro enfileira uma partida com a rede fora e morre sem enviar nada;
o segundo lê a fila do disco e drena.

```powershell
& $godot --headless --path . --script res://tools/simular_queda.gd -- encher
& $godot --headless --path . --script res://tools/simular_queda.gd -- drenar
```

Resultado esperado: zero evento perdido, zero duplicado, sequência contígua, e a sessão
interrompida marcada como `ABANDONADA`.

## Configuração da coleta

O jogo cria `user://config.cfg` no primeiro boot
(`%APPDATA%\Godot\app_userdata\Purr Bytes\config.cfg` no Windows):

```ini
[telemetria]
modo_telemetria="MOCK"        ; MOCK grava em disco, HTTP fala com a API (Marco 3)
url_api="http://localhost:8080"
chave_api=""                  ; escopo INGESTAO, só escreve
tamanho_lote=50               ; teto do back-end é 500
intervalo_envio_s=5.0

[pesquisa]
id_sujeito=""                 ; UUID do participante; sem ele a sessão fica órfã na análise

[diagnostico]
nivel_log="INFO"              ; SILENCIO | ERRO | AVISO | INFO | DEPURACAO
```

**Antes de cada coleta**, preencher `id_sujeito` com o UUID daquele participante. Se o campo
estiver vazio ou fora do formato UUID, o cliente gera um local e avisa alto — a sessão é
gravável, mas não pareia com o pré-teste e o pós-teste.

O menu principal → **telemetria** mostra modo, fila, sequência e descartes na própria tela,
sem ferramenta nenhuma instalada. A chave de API nunca aparece ali.

---

## Estado

| Marco | Situação |
|---|---|
| 0 — Fundação | ✅ concluído |
| 1 — Fase 1: César, labirinto e A\* | ✅ concluído |
| 2 — Fase 2: Vigenère e Diretor de IA | ✅ concluído |
| 3 — Fase 3: SHA-256 e telemetria HTTP | ⏳ próximo |

### Pendências conhecidas do Marco 2

- O labirinto de `fase_02.tscn` foi pintado por código
  (`tools/gerar_fase_02.gd`), mesma técnica da fase 1 -- vale abrir no editor
  para conferir visualmente e trocar a arte placeholder quando ela existir.
- As 4 regiões do Diretor (`Marcadores/Regioes` em `fase_02.tscn`) cobrem os
  quadrantes do mapa por retângulo, sem alinhar pixel a pixel com as paredes
  do labirinto -- funcional (é só o que decide "o jogador está nesta região"
  para o Diretor, não um limite físico), mas pode valer a pena ajustar no
  editor depois que a arte definitiva mostrar a topologia real do mapa.
- Detalhe completo das decisões do Diretor e de Vigenère em
  [ADR 0002](docs/decisoes/0002-diretor-ia.md) e
  [ADR 0008](docs/decisoes/0008-vigenere-e-painel-de-demonstracao.md).

### Pendências conhecidas do Marco 1

- O labirinto de `fase_01.tscn` foi pintado por código
  (`tools/gerar_fase_01.gd`), não desenhado no editor -- funcional e testado,
  mas vale abrir uma vez no editor para conferir visualmente o traçado e
  trocar a arte placeholder pela definitiva quando ela existir.
- A depuração visual do A\* (F3) desenha o caminho final, não os "nós
  expandidos": `AStarGrid2D` não expõe o conjunto fechado pela API pública, e
  a implementação didática que expõe (`scripts/ia/astar_referencia.gd`) é
  vetada para uso em runtime pelo próprio `CLAUDE.md`. Detalhe em
  [ADR 0007](docs/decisoes/0007-marco1-cachorro-e-desafios.md#7-depuração-visual-do-a-f3-só-o-caminho-final-não-os-nós-expandidos).
- `CatalogoResultados.TIMEOUT` não tem gatilho de jogo no Marco 1: não há
  campo de prazo por desafio especificado no briefing. `ABANDONO` tem gatilho
  real (abandonar a fase com desafio ativo). Detalhe na
  [ADR 0007](docs/decisoes/0007-marco1-cachorro-e-desafios.md).
- Arte é placeholder gerado (`recursos/arte/*_placeholder.png`), esperando a pixel art.
- `TransporteHttp` é esqueleto; `disponivel()` devolve `false` e o modo HTTP cai para MOCK
  com erro no log até o Marco 3.
