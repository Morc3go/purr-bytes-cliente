# ADR 0018 — Integração com o back-end: o que a verificação ponta a ponta encontrou

**Data:** 2026-09-27 · **Situação:** aceita

## Contexto

A API de telemetria (Java 21 + Spring Boot 3.4 + PostgreSQL + Flyway) chegou ao
repositório em `back/`, vinda do trabalho da equipe. Ela implementa as quatro rotas de
`docs/contrato-telemetria.md` e tinha testes unitários, mas nunca tinha recebido uma
sessão do jogo de verdade. A verificação foi feita assim:

1. PostgreSQL 16 local, API no perfil `dev`, migrations aplicadas do zero;
2. o jogo real em modo HTTP, jogando a fase de exemplo (comando errado, cifra certa,
   captura, conclusão), apontado para a API;
3. conferência do que chegou ao banco, tabela por tabela;
4. queda: API derrubada, sessão jogada e o jogo fechado; API de volta, jogo reaberto,
   fila drenada; conferência de perda e duplicidade.

## O que estava quebrado

| # | Problema | Efeito |
|---|---|---|
| 1 | `chave_hash` é `CHAR(64)` na V4, mas a entidade esperava `VARCHAR` | a API **não subia** (`ddl-auto: validate` recusava o schema) |
| 2 | `fase` e `numero_tentativa` são `SMALLINT`, mapeados como `int` | idem |
| 3 | a semente da chave `dev` passava `java.time.Instant` direto ao JDBC | o boot no perfil `dev` abortava |
| 4 | `id_fase` obrigatório em **todo** evento, e o cliente mandava `""` nos eventos de sessão | a API respondia `400` ao lote, e o cliente o **descartava inteiro**: sessão e tentativas chegavam, **nenhum evento** |
| 5 | `vw_desempenho_fase` agrupava pelo número legado `fase` | toda fase de autoria (número 1) caía numa linha só |
| 6 | `tentativa_comando.fase` continuava `NOT NULL` (V2) | só passava porque toda fase de autoria tem número 1 |
| 7 | teste do hash da string vazia com um caractere a menos | `mvn test` vermelho |

## Decisões

- **Entidades casam com as migrations**, e não o contrário: `@JdbcTypeCode(CHAR)` e
  `@JdbcTypeCode(SMALLINT)`. Migrations já aplicadas não se editam (checksum do Flyway).
- **Migration V8** para o contrato: `evento_telemetria.id_fase` opcional (evento de
  sessão não pertence a fase), `tentativa_comando.fase` sem `NOT NULL`, e
  `vw_desempenho_fase` recriada por `id_fase`. Tentativa continua exigindo `id_fase`.
- **O cliente manda `null`, não `""`,** quando não há fase, e normaliza a fila gravada
  por versões anteriores ao recuperá-la.
- **`401`, `403`, `404`, `408`, `425` e `429` não descartam o lote.** São problemas de
  configuração ou de rede, não do dado: com uma chave errada no `config.cfg` da sala, o
  cliente descartava a coleta inteira. Agora o lote espera na fila, com backoff, até a
  chave ser corrigida. `400`, `413`, `422` (dado malformado) continuam permanentes.

## Otimização

Com o id vindo do cliente, o `saveAll` do Spring Data fazia `merge` — um `SELECT` por
registro antes de cada `INSERT`. As entidades de telemetria passaram a implementar
`Persistable` (todo objeto criado ali é novo; os já gravados são filtrados antes), o
driver passou a juntar os `INSERT`s (`reWriteBatchedInserts`), e o `ultimo_uso_em` da
chave de API passou a ser gravado no máximo a cada 5 minutos, e não a cada requisição.

| Lote de 500 eventos | Antes | Depois |
|---|---|---|
| `SELECT`s | 510 | 8 |
| `UPDATE`s | 2 | 0 |
| Tempo | ~245 ms | ~86 ms |

## Resultado

- Sessão completa: 6 eventos com sequência 0..5 sem lacuna, 3 tentativas, sessão
  `ENCERRADA`, visão por `id_fase` correta, 0 descartes.
- Queda: com a API fora, o envio falha em ~15 ms sem travar o jogo, a fila (26 itens)
  sobrevive ao fechamento; com a API de volta, tudo chega, sem perda nem duplicidade.
- Reenvio manual de um lote já gravado: `202` e nenhuma linha nova (idempotência).
- `tools/verificar_backend.gd` repete a verificação da sessão contra qualquer API, para
  ser rodado antes de cada coleta.
