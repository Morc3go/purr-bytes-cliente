# Contrato de telemetria — o que o cliente Godot envia

Este documento é a referência para quem for implementar as rotas de ingestão no
back-end (`Morc3go/prototipo`, `Protótipo/backend`). Todos os exemplos abaixo
foram **gerados pelo cliente**, não escritos à mão:

```powershell
godot --headless --path . --script res://tools/sessao_de_demonstracao.gd
```

O comando roda uma partida curta da fase 1 em modo MOCK e imprime exatamente os
corpos que iriam para a rede. Reexecute-o sempre que mudar a serialização — se a
saída divergir deste arquivo, este arquivo está desatualizado.

Estado em 2026-08-21: as rotas **ainda não existem** no back-end. O cliente está
em modo MOCK e o transporte HTTP entra no Marco 3.

---

## 1. Rotas

| Método | Rota | Quando |
|---|---|---|
| `POST` | `/v1/sessoes` | Abertura de sessão. Idempotente pelo `id_sessao` do corpo. |
| `POST` | `/v1/sessoes/{id}/eventos` | Lote de eventos. Idempotente pelo `id_evento`. |
| `POST` | `/v1/sessoes/{id}/tentativas` | Lote de tentativas. Idempotente pelo `id_tentativa`. |
| `POST` | `/v1/sessoes/{id}/encerrar` | Encerramento da sessão. |

Header: `Authorization: Bearer <chave_api>`, escopo `INGESTAO`.

**Ordem garantida pelo cliente:** abertura → eventos → tentativas →
encerramento. A fila só passa para a próxima categoria quando a anterior esvazia,
porque `evento_telemetria.id_sessao` tem chave estrangeira para
`sessao_jogo.id_sessao`: evento que chega antes da sessão não tem onde ser
gravado.

### Como o cliente interpreta a resposta

| Faixa | Interpretação | O que o cliente faz |
|---|---|---|
| `2xx` (a API responde `202`) | Aceito para processamento | Remove o lote da fila |
| `4xx` | Erro permanente — o lote está malformado | **Descarta** o lote e registra erro alto |
| `5xx`, timeout, sem rede | Erro transitório | **Preserva** a fila e tenta de novo com backoff exponencial + jitter (teto de 60s) |

Reenvio após queda de conexão é esperado e normal: o cliente não sabe se o lote
chegou, então manda de novo. Os IDs vêm do cliente exatamente para isso — o
servidor deve ignorar duplicatas em silêncio, não devolver erro.

---

## 2. `POST /v1/sessoes`

```json
{
  "id_sessao": "d74c9f6e-818f-4fd5-bf5a-59427d614f1b",
  "id_sujeito": "bea35bec-8177-44c0-853d-2c7a5a04ecbf",
  "versao_jogo": "0.1.0",
  "plataforma": "Windows",
  "iniciada_em": "2026-08-21T23:04:16.396Z"
}
```

Mapeia campo a campo as colunas `NOT NULL` de `pesquisa.sessao_jogo`. O servidor
preenche `recebida_em` com o próprio relógio e `status` com `ABERTA`.

`plataforma` vem de `OS.get_name()` — família de sistema operacional
(`Windows`, `Linux`, `macOS`, `Android`, `iOS`, `Web`), nunca identificador de
máquina.

---

## 3. `POST /v1/sessoes/{id}/eventos`

Corpo: `{"eventos": [ ... ]}`, cada elemento no formato abaixo.

```json
{
  "id_evento": "b27be993-d972-4781-a39a-7c2189cfcb58",
  "id_sessao": "d74c9f6e-818f-4fd5-bf5a-59427d614f1b",
  "sequencia": 1,
  "tipo_evento": "FASE_INICIADA",
  "fase": 1,
  "ocorrido_em": "2026-08-21T23:04:16.397Z",
  "payload": {"algoritmo": "CESAR", "desafios": 1, "vidas_iniciais": 3}
}
```

Evento fora de fase (`SESSAO_INICIADA`, `SESSAO_ENCERRADA`) manda `fase` como
`null` — a coluna é nulável mas tem `CHECK (fase BETWEEN 1 AND 4)`:

```json
{
  "id_evento": "331f4524-0edd-4aba-b1f9-5c888e986435",
  "id_sessao": "d74c9f6e-818f-4fd5-bf5a-59427d614f1b",
  "sequencia": 0,
  "tipo_evento": "SESSAO_INICIADA",
  "fase": null,
  "ocorrido_em": "2026-08-21T23:04:16.396Z",
  "payload": {"modo_telemetria": "MOCK"}
}
```

### `sequencia`

Contador monotônico por sessão, começando em **0**, sem lacunas, atribuído por um
escritor único no cliente. Lacuna na série significa perda de pacote — é para
isso que o campo existe. O cliente garante:

- código de evento fora do catálogo é descartado **antes** de consumir número;
- a sequência é persistida junto com a fila, então sobrevive a queda do processo.

`UNIQUE (id_sessao, sequencia)` no banco fecha o contrato do outro lado.

### `payload`

JSONB livre por tipo de evento, com três garantias do cliente:

1. nenhum dado pessoal (restrição 1 da seção 4 do `CLAUDE.md`);
2. toda string é sanitizada (sem caractere de controle, espaços colapsados) e
   truncada em **240** caracteres, inclusive dentro de objetos e listas aninhados;
3. `Vector2` vira `{"x": …, "y": …}`, nunca a string `"(3, 4)"`.

Payloads por tipo de evento usados até aqui:

| `tipo_evento` | `payload` |
|---|---|
| `SESSAO_INICIADA` | `{"modo_telemetria": "MOCK"\|"HTTP"}` |
| `SESSAO_ENCERRADA` / `SESSAO_ABANDONADA` | `{"status": "ENCERRADA"\|"ABANDONADA"}` (+ `motivo` no abandono) |
| `FASE_INICIADA` | `{"algoritmo", "desafios", "vidas_iniciais"}` |
| `FASE_CONCLUIDA` | `{"capturas", "pontuacao", "vidas_restantes"}` |
| `FASE_ABANDONADA` | `{"capturas", "pontuacao"}` |
| `COMANDO_SUBMETIDO` | `{"tamanho", "tempo_resposta_ms"}` |
| `ERRO_LEXICO` | `{"lexema", "posicao"}` |
| `JOGADOR_CAPTURADO` | `{"protecao_ativa", "captura_numero"}` |
| `CACHORRO_DETECTOU` | `{"distancia_celulas"}` |

Marcos 1 a 3 acrescentam `ERRO_SINTATICO`, `CACHORRO_PERDEU`, `DICA_SOLICITADA`,
`CIFRA_DEMONSTRADA` e `AMOSTRA_DESEMPENHO`. **A lista de códigos é fechada** e
espelha `V5__catalogo_de_eventos.sql`; `tests/teste_catalogos.gd` compara as duas
e falha se divergirem.

---

## 4. `POST /v1/sessoes/{id}/tentativas`

Corpo: `{"tentativas": [ ... ]}`.

Erro léxico (caso TC-04 da monografia — `cyfrar` não é reconhecido como `VERBO`):

```json
{
  "id_tentativa": "36199e51-934e-4e92-8b2b-1b3c34e6945e",
  "id_sessao": "d74c9f6e-818f-4fd5-bf5a-59427d614f1b",
  "fase": 1,
  "desafio": "cesar-01",
  "entrada_normalizada": "cyfrar pacote chave=3",
  "tokens": [
    {"tipo": "IDENTIFICADOR", "lexema": "cyfrar", "posicao": 0},
    {"tipo": "IDENTIFICADOR", "lexema": "pacote", "posicao": 7},
    {"tipo": "IDENTIFICADOR", "lexema": "chave", "posicao": 14},
    {"tipo": "ATRIBUICAO", "lexema": "=", "posicao": 19},
    {"tipo": "NUMERO", "lexema": "3", "posicao": 20}
  ],
  "resultado": "ERRO_LEXICO",
  "codigo_erro": "VERBO_NAO_RECONHECIDO",
  "tempo_resposta_ms": 4310,
  "numero_tentativa": 1,
  "ocorrido_em": "2026-08-21T23:04:16.397Z"
}
```

Acerto na segunda tentativa do mesmo desafio:

```json
{
  "id_tentativa": "d5fe1463-fb3f-4d8a-be9a-cef6c3e1c319",
  "id_sessao": "d74c9f6e-818f-4fd5-bf5a-59427d614f1b",
  "fase": 1,
  "desafio": "cesar-01",
  "entrada_normalizada": "cifrar pacote chave=3",
  "tokens": [
    {"tipo": "VERBO", "lexema": "cifrar", "posicao": 0},
    {"tipo": "IDENTIFICADOR", "lexema": "pacote", "posicao": 7},
    {"tipo": "IDENTIFICADOR", "lexema": "chave", "posicao": 14},
    {"tipo": "ATRIBUICAO", "lexema": "=", "posicao": 19},
    {"tipo": "NUMERO", "lexema": "3", "posicao": 20}
  ],
  "resultado": "SUCESSO",
  "codigo_erro": null,
  "tempo_resposta_ms": 2180,
  "numero_tentativa": 2,
  "ocorrido_em": "2026-08-21T23:04:16.397Z"
}
```

Garantias do cliente, todas cobertas por teste:

| Campo | Garantia |
|---|---|
| `desafio` | ≤ 60 caracteres (`VARCHAR(60)`) |
| `entrada_normalizada` | sanitizada e ≤ 240 (`VARCHAR(240)` e `limite-texto-livre`) |
| `resultado` | um de `SUCESSO`, `ERRO_LEXICO`, `ERRO_SINTATICO`, `ERRO_SEMANTICO`, `TIMEOUT`, `ABANDONO` |
| `codigo_erro` | `null` em caso de sucesso; ≤ 40 caracteres |
| `tempo_resposta_ms` | ≥ 0, medido com relógio monotônico do foco no terminal até o Enter |
| `numero_tentativa` | ≥ 1, contado por desafio |

Nota: `tentativa_comando` **não tem** coluna `sequencia`. Ordem e detecção de
perda vivem em `evento_telemetria`.

---

## 5. `POST /v1/sessoes/{id}/encerrar`

```json
{
  "id_sessao": "d74c9f6e-818f-4fd5-bf5a-59427d614f1b",
  "status": "ENCERRADA",
  "encerrada_em": "2026-08-21T23:04:16.397Z"
}
```

`status` é `ENCERRADA` (saiu pelo menu) ou `ABANDONADA`. O cliente marca
`ABANDONADA` sozinho quando encontra, no boot seguinte, uma sessão que ficou
aberta no disco — travamento, queda de energia, fim de aula. Nesse caso ele
também envia um evento `SESSAO_ABANDONADA` continuando a sequência de onde
parou, sem lacuna.

---

## 6. Carimbos de tempo

Formato: **ISO-8601 UTC com milissegundos e `Z` explícito** —
`2026-08-21T23:04:16.397Z`.

Cuidado documentado em `scripts/nucleo/relogio.gd`: a chamada
`Time.get_datetime_string_from_system(true, true)` do Godot produz
`2026-08-21 23:04:16` — separador de espaço e **sem designador de fuso**. Um
`TIMESTAMPTZ` recebendo string sem fuso assume o fuso da sessão do banco, o que
deslocaria silenciosamente todo `ocorrido_em`. O cliente monta o carimbo à mão
por isso.

O servidor grava o próprio relógio em `recebido_em`. A diferença entre os dois é
a defasagem (`max-defasagem-relogio-minutos`); lote fora da tolerância deve ser
aceito e marcado, nunca recusado — o dado ainda vale, só o horário é suspeito.

---

## 7. Lote

- Tamanho de descarga: `tamanho_lote` do `config.cfg`, padrão **50**.
- Teto absoluto: **500** (`purrbytes.ingestao.max-eventos-por-lote`). O cliente
  limita o próprio lote a esse valor mesmo que o `config.cfg` peça mais.
- Cadência: a cada `intervalo_envio_s` (padrão 5s) ou assim que a fila atinge
  `tamanho_lote`.
- A fila é persistida em `user://fila_telemetria.json` **antes** de cada
  tentativa de envio (escrita adiantada) e no fechamento da janela.

---

## 8. Formato do modo MOCK

Em `modo_telemetria = "MOCK"` o cliente grava `user://telemetria_mock.jsonl`, uma
linha JSON por registro:

```json
{"rota": "eventos", "tipo_registro": "evento", "escrito_em": "…", "dados": { … }}
```

`dados` é **exatamente** o objeto que iria no corpo da requisição — é isso que
torna o arquivo do modo MOCK utilizável como dado de pesquisa caso a API esteja
fora no dia da coleta. `tipo_registro` é `sessao`, `evento` ou `tentativa`.
