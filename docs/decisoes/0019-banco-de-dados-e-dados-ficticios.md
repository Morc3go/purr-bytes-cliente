# ADR 0019 — Banco de dados: PostgreSQL 16 local, somente dados fictícios

**Data:** 2026-10-22 · **Situação:** aceita

## Contexto

A modelagem do banco já existia: o Flyway cria 13 tabelas e 4 visões em três schemas
(`identidade`, `pesquisa`, `operacao`, migrations `V1` a `V8`). Faltavam duas decisões
de negócio: **qual banco** usar de fato e **com que dados** ele seria povoado.

A equipe decidiu, em conformidade com a LGPD (Lei 13.709/2018):

- **nenhum usuário real** é cadastrado;
- **nenhum cliente real** testa o sistema;
- o banco contém **apenas dados fictícios**.

## Decisão

1. **PostgreSQL 16, rodando localmente** por `back/docker-compose.yml`. É o banco para o
   qual o código já foi escrito: `JSONB` com índice GIN, `FILTER`, `PERCENTILE_CONT`,
   schemas e `gen_random_uuid()`. Trocar de banco significaria reescrever migrations e visões
   sem nenhum ganho. Rodar localmente, sem nuvem, garante que nenhum dado sai das máquinas da
   equipe. H2 e SQLite foram descartados porque não suportam `JSONB` nem as visões.
2. **A estrutura fica no repositório, os dados não.** As migrations são versionadas; os
   dados ficam no volume Docker `purrbytes-dados`. Nenhum arquivo de banco vai para o git.
3. **Seed fictício só no perfil `dev`**: `db/seed-dev/R__dados_ficticios.sql`. Ele traz
   6 sujeitos, avaliação pré e pós, 2 partidas e um participante que revogou o consentimento
   (para exercitar a eliminação em duas fases). Todo dado fictício é reconhecível: UUIDs com
   prefixo `f1c71c10`, `coorte = 'DADOS_FICTICIOS'` e e-mails no domínio reservado
   `exemplo.invalid` (RFC 2606).
4. **O schema `identidade` continua existindo**, povoado só pelo seed fictício. Ele demonstra
   a separação entre identidade e pesquisa (privacidade desde a concepção, art. 46) sem
   tratar dado pessoal de ninguém.
5. **Entidades JPA só para tabelas que o código usa.** Com `ddl-auto: validate`, cada
   entidade é conferida contra o banco no boot, e uma divergência impede a API de subir
   (ADR 0018, itens 1 a 3). Entidade sem rota que a use é risco sem benefício. As tabelas de
   avaliação, identidade, auditoria e exportação ganham entidade junto com a rota que precisar
   delas.

## Correções feitas na mesma revisão

| # | Problema | Correção |
|---|---|---|
| 1 | JSON ilegível, timestamp sem fuso, UUID inválido, rota ou método errado: tudo virava **500**. O cliente trata 5xx como transitório e para no primeiro lote que falha, então **um lote malformado travava a fila para sempre** | `400` para requisição malformada; erros do Spring MVC mantêm o próprio status (404, 405, 415) |
| 2 | Caractere NUL (`\u0000`) em texto ou payload: o PostgreSQL o recusa em `TEXT`/`JSONB`, o que também dava 500 | `SanitizadorDeTexto` no servidor, espelho do cliente |
| 3 | O limite de texto livre (`limite-texto-livre`) estava configurado, mas o servidor não o aplicava | O mesmo sanitizador trunca texto e payload e corta aninhamento além de 4 níveis |
| 4 | O mesmo id repetido dentro de um lote estourava a chave primária, e o lote inteiro era descartado | Ids repetidos no lote são removidos antes de gravar |
| 5 | `status` nulo no encerramento passava pela validação | `@NotNull` |
| 6 | `/actuator/metrics` ficava público | Expostos só `health` e `info` |

## Consequências

- **Metodologia.** O desenho original previa participantes reais (pré-teste e pós-teste,
  TCLE, `vw_ganho_aprendizado`). Com dados apenas fictícios, essa parte passa a ser uma
  **demonstração do pipeline com dados sintéticos**, não um resultado experimental. A
  monografia precisa dizer isso explicitamente; alinhar com o orientador.
- **Verificação pendente.** Estas mudanças foram escritas numa máquina sem Java, sem Maven e
  sem Docker. Antes de considerar a revisão concluída, alguém da equipe precisa rodar:
  `docker compose up -d`, `mvn test` e
  `mvn spring-boot:run "-Dspring-boot.run.profiles=dev"`. Depois, conferir que o Flyway
  aplica `V1`..`V8` + `R__dados_ficticios` e que as quatro visões retornam linhas.
- `PB_PRIVACY_PEPPER` e `retencao-telemetria-dias` continuam reservados e ainda sem uso no
  código.
