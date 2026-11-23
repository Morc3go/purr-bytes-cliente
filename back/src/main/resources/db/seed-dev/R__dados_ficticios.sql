-- ===========================================================================
-- Seed de desenvolvimento -- DADOS 100% FICTICIOS (ADR 0019)
--
-- Decisao do projeto: nenhum usuario real e nenhum cliente real participa,
-- em conformidade com a LGPD. Tudo aqui foi inventado: nomes, e-mails,
-- respostas, partidas. So roda no perfil dev (application-dev.yml acrescenta
-- classpath:db/seed-dev ao Flyway); fora dele, este arquivo nao e lido.
--
-- Como reconhecer um dado ficticio no banco:
--   * todo UUID comeca com f1c71c10 ("ficticio");
--   * sujeito.coorte = 'DADOS_FICTICIOS' e codigo = 'FIC-2026-NNNN';
--   * e-mails no dominio reservado exemplo.invalid (RFC 2606), que nao existe.
--
-- Migration REPETIVEL (R__): o Flyway a reaplica sempre que o arquivo mudar,
-- por isso todo INSERT e idempotente (ON CONFLICT DO NOTHING com ids fixos).
-- Para recomecar do zero: docker compose down -v.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- pesquisa.sujeito: 6 sujeitos, alternando os bracos do desenho experimental
-- ---------------------------------------------------------------------------
INSERT INTO pesquisa.sujeito (id_sujeito, codigo, coorte, grupo, criado_em)
SELECT ('f1c71c10-0001-4000-8000-' || lpad(n::text, 12, '0'))::uuid,
       'FIC-2026-' || lpad(n::text, 4, '0'),
       'DADOS_FICTICIOS',
       CASE WHEN n % 2 = 1 THEN 'EXPERIMENTAL' ELSE 'CONTROLE' END,
       TIMESTAMPTZ '2026-09-01 10:00:00+00'
FROM generate_series(1, 6) AS n
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- identidade: o caminho de reidentificacao, so para demonstrar a separacao.
--
-- email_hmac = HMAC-SHA-256('participanteNN@exemplo.invalid') com o pepper
-- de DESENVOLVIMENTO de application-dev.yml. Com outro pepper a busca por
-- e-mail nao casa -- que e justamente o comportamento esperado.
-- ---------------------------------------------------------------------------
INSERT INTO identidade.participante (id_participante, nome_completo, email_hmac, criado_em, atualizado_em)
SELECT ('f1c71c10-0007-4000-8000-' || lpad(p.n::text, 12, '0'))::uuid,
       'Participante Ficticio ' || lpad(p.n::text, 2, '0'),
       p.email_hmac,
       TIMESTAMPTZ '2026-09-01 10:00:00+00',
       TIMESTAMPTZ '2026-09-01 10:00:00+00'
FROM (VALUES
    (1, '8e20b6958b1cf96cb93c0c136749b126615fd56aa1124d65e4577197e0b87ab4'),
    (2, '91f9612962dce1a8a84820915bb9447f4574351f952e9bfea433e9d93bed284b'),
    (3, '778d7fe82ee1410d1cbc4bbf04b69c9ddfaf4c70b4710a9e6f62e5fc1ba6546c'),
    (4, 'b7e5aba8510488e3558d43edf3d4ec62b913a929801233571d106979f439fc35'),
    (5, '8620307dd10bceef2ca65c61c781908ca51d65e0ede2ebd2010dfadd7db07588'),
    (6, '920bdb1e12774a0b1dba476447bd2d5200ef84531a6186263403c88599627449')
) AS p(n, email_hmac)
ON CONFLICT DO NOTHING;

-- Consentimento por finalidade (art. 8 da LGPD). O participante 06 revogou a
-- coleta de telemetria: e o caso que exercita a eliminacao em duas fases.
-- origem_ip_hmac fica NULL: nem um IP ficticio e necessario para a demo.
INSERT INTO identidade.consentimento
    (id_consentimento, id_participante, versao_termo, finalidade, aceito_em, revogado_em)
SELECT ('f1c71c10-0008-4000-8000-' || lpad((n * 10 + f.k)::text, 12, '0'))::uuid,
       ('f1c71c10-0007-4000-8000-' || lpad(n::text, 12, '0'))::uuid,
       'FICTICIO-1.0',
       f.finalidade,
       TIMESTAMPTZ '2026-09-01 10:05:00+00',
       CASE WHEN n = 6 AND f.finalidade = 'COLETA_TELEMETRIA'
            THEN TIMESTAMPTZ '2026-09-20 09:00:00+00' END
FROM generate_series(1, 6) AS n
CROSS JOIN (VALUES (1, 'PESQUISA_ACADEMICA'), (2, 'COLETA_TELEMETRIA')) AS f(k, finalidade)
ON CONFLICT DO NOTHING;

INSERT INTO identidade.vinculo_sujeito (id_participante, id_sujeito, criado_em, rompido_em)
SELECT ('f1c71c10-0007-4000-8000-' || lpad(n::text, 12, '0'))::uuid,
       ('f1c71c10-0001-4000-8000-' || lpad(n::text, 12, '0'))::uuid,
       TIMESTAMPTZ '2026-09-01 10:05:00+00',
       CASE WHEN n = 6 THEN TIMESTAMPTZ '2026-09-20 09:00:00+00' END
FROM generate_series(1, 6) AS n
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- Avaliacao pre/pos (alimenta vw_ganho_aprendizado). 10 itens; o acerto de
-- cada sujeito foi escolhido a mao para o ganho normalizado variar, inclusive
-- um sujeito sem ganho (06).
-- ---------------------------------------------------------------------------
INSERT INTO pesquisa.avaliacao
    (id_avaliacao, id_sujeito, momento, versao_instrumento, aplicada_em, total_itens, total_acertos)
SELECT ('f1c71c10-0002-4000-8000-' || lpad((a.n * 10 + m.ordem)::text, 12, '0'))::uuid,
       ('f1c71c10-0001-4000-8000-' || lpad(a.n::text, 12, '0'))::uuid,
       m.momento,
       'FICTICIO-1.0',
       m.aplicada_em + make_interval(mins => a.n),
       10,
       CASE m.momento WHEN 'PRE' THEN a.pre ELSE a.pos END
FROM (VALUES (1, 3, 8), (2, 4, 6), (3, 2, 7), (4, 5, 6), (5, 3, 5), (6, 4, 4)) AS a(n, pre, pos)
CROSS JOIN (VALUES
    (1, 'PRE', TIMESTAMPTZ '2026-09-09 13:00:00+00'),
    (2, 'POS', TIMESTAMPTZ '2026-09-11 13:00:00+00')
) AS m(ordem, momento, aplicada_em)
ON CONFLICT DO NOTHING;

-- Os primeiros total_acertos itens saem certos; o resto, errado.
INSERT INTO pesquisa.resposta_avaliacao (id_avaliacao, numero_item, alternativa, correta, tempo_resposta_ms)
SELECT av.id_avaliacao,
       i,
       CASE WHEN i <= av.total_acertos THEN 'A' ELSE 'C' END,
       i <= av.total_acertos,
       15000 + i * 1000
FROM pesquisa.avaliacao av
CROSS JOIN generate_series(1, av.total_itens::int) AS i
WHERE av.id_avaliacao::text LIKE 'f1c71c10-%'
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- Duas partidas na mesma fase ficticia (alimentam vw_resumo_sessao,
-- vw_desempenho_fase e vw_features_ia):
--   01 -- sujeito 01 erra (lexico, sintatico, semantico), e capturado e conclui;
--   02 -- sujeito 02 pede dica, erra a faixa da chave e abandona.
-- Payloads seguem docs/contrato-telemetria.md.
-- ---------------------------------------------------------------------------
INSERT INTO pesquisa.sessao_jogo
    (id_sessao, id_sujeito, versao_jogo, plataforma, iniciada_em, encerrada_em, status, recebida_em)
SELECT ('f1c71c10-0003-4000-8000-' || lpad(s.n::text, 12, '0'))::uuid,
       ('f1c71c10-0001-4000-8000-' || lpad(s.n::text, 12, '0'))::uuid,
       'ficticio-1.0', 'Windows',
       s.inicio, s.inicio + make_interval(secs => s.duracao), s.status,
       s.inicio + INTERVAL '1 second'
FROM (VALUES
    (1, TIMESTAMPTZ '2026-09-10 13:00:00+00', 720, 'ENCERRADA'),
    (2, TIMESTAMPTZ '2026-09-10 14:00:00+00', 360, 'ABANDONADA')
) AS s(n, inicio, duracao, status)
ON CONFLICT DO NOTHING;

-- Eventos de sessao (na_fase = false) vao sem id_fase, como o cliente manda (V8).
INSERT INTO pesquisa.evento_telemetria
    (id_evento, id_sessao, sequencia, tipo_evento, fase, id_fase, titulo_fase, ocorrido_em, recebido_em, payload)
SELECT ('f1c71c10-0005-4000-8000-' || lpad((e.n * 100 + e.seq)::text, 12, '0'))::uuid,
       s.id_sessao,
       e.seq,
       e.tipo,
       CASE WHEN e.na_fase THEN 1 END,
       CASE WHEN e.na_fase THEN 'f1c71c10-0004-4000-8000-000000000001'::uuid END,
       CASE WHEN e.na_fase THEN 'Fase ficticia - Cesar' END,
       s.iniciada_em + make_interval(secs => e.segundos),
       s.iniciada_em + make_interval(secs => e.segundos + 2),
       e.payload::jsonb
FROM (VALUES
    (1,  0, 'SESSAO_INICIADA',    false,   0, '{"modo_telemetria": "HTTP"}'),
    (1,  1, 'FASE_INICIADA',      true,    5, '{"algoritmo": "CESAR", "desafios": 1, "vidas_iniciais": 3}'),
    (1,  2, 'COMANDO_SUBMETIDO',  true,   60, '{"tamanho": 14, "tempo_resposta_ms": 9200}'),
    (1,  3, 'ERRO_LEXICO',        true,   60, '{}'),
    (1,  4, 'COMANDO_SUBMETIDO',  true,  120, '{"tamanho": 21, "tempo_resposta_ms": 11800}'),
    (1,  5, 'ERRO_SINTATICO',     true,  120, '{}'),
    (1,  6, 'CACHORRO_DETECTOU',  true,  150, '{"posicao": {"x": 12, "y": 7}}'),
    (1,  7, 'JOGADOR_CAPTURADO',  true,  160, '{"protecao_ativa": false, "captura_numero": 1}'),
    (1,  8, 'CACHORRO_PERDEU',    true,  175, '{}'),
    (1,  9, 'COMANDO_SUBMETIDO',  true,  200, '{"tamanho": 21, "tempo_resposta_ms": 7400}'),
    (1, 10, 'COMANDO_SUBMETIDO',  true,  300, '{"tamanho": 21, "tempo_resposta_ms": 5100}'),
    (1, 11, 'FASE_CONCLUIDA',     true,  600, '{"capturas": 1, "pontuacao": 850, "vidas_restantes": 2}'),
    (1, 12, 'AMOSTRA_DESEMPENHO', false, 650, '{"fps": 60, "memoria_estatica_bytes": 50331648, "objetos_desenhados": 214, "replanejamento_medio_ms": 0.42}'),
    (1, 13, 'SESSAO_ENCERRADA',   false, 720, '{"status": "ENCERRADA"}'),
    (2,  0, 'SESSAO_INICIADA',    false,   0, '{"modo_telemetria": "HTTP"}'),
    (2,  1, 'FASE_INICIADA',      true,    4, '{"algoritmo": "CESAR", "desafios": 1, "vidas_iniciais": 3}'),
    (2,  2, 'DICA_SOLICITADA',    true,   90, '{"desafio": "cesar-01"}'),
    (2,  3, 'CIFRA_DEMONSTRADA',  true,  120, '{"algoritmo": "CESAR"}'),
    (2,  4, 'COMANDO_SUBMETIDO',  true,  200, '{"tamanho": 22, "tempo_resposta_ms": 15600}'),
    (2,  5, 'FASE_ABANDONADA',    true,  340, '{"capturas": 0, "pontuacao": 0}'),
    (2,  6, 'SESSAO_ABANDONADA',  false, 360, '{"status": "ABANDONADA", "motivo": "inatividade"}')
) AS e(n, seq, tipo, na_fase, segundos, payload),
     pesquisa.sessao_jogo s
WHERE s.id_sessao = ('f1c71c10-0003-4000-8000-' || lpad(e.n::text, 12, '0'))::uuid
ON CONFLICT DO NOTHING;

-- Uma tentativa por COMANDO_SUBMETIDO acima, no mesmo instante. Os casos
-- seguem docs/gramatica.md: 'cifrar pacote!' e lexico (tokens vazio) e
-- 'cyfrar pacote chave=3' e sintatico (TC-04).
INSERT INTO pesquisa.tentativa_comando
    (id_tentativa, id_sessao, fase, id_fase, titulo_fase, desafio, entrada_normalizada, tokens,
     resultado, codigo_erro, tempo_resposta_ms, numero_tentativa, ocorrido_em, recebido_em)
SELECT ('f1c71c10-0006-4000-8000-' || lpad((t.n * 100 + t.numero)::text, 12, '0'))::uuid,
       s.id_sessao,
       1,
       'f1c71c10-0004-4000-8000-000000000001'::uuid,
       'Fase ficticia - Cesar',
       'cesar-01',
       t.entrada,
       t.tokens::jsonb,
       t.resultado,
       t.codigo_erro,
       t.tempo_ms,
       t.numero,
       s.iniciada_em + make_interval(secs => t.segundos),
       s.iniciada_em + make_interval(secs => t.segundos + 2)
FROM (VALUES
    (1, 1, 60, 'cifrar pacote!', '[]',
     'ERRO_LEXICO', 'caractere_invalido', 9200),
    (1, 2, 120, 'cyfrar pacote chave=3',
     '[{"tipo": "IDENTIFICADOR", "lexema": "cyfrar", "posicao": 0}, {"tipo": "IDENTIFICADOR", "lexema": "pacote", "posicao": 7}, {"tipo": "IDENTIFICADOR", "lexema": "chave", "posicao": 14}, {"tipo": "ATRIBUICAO", "lexema": "=", "posicao": 19}, {"tipo": "NUMERO", "lexema": "3", "posicao": 20}, {"tipo": "EOF", "lexema": "", "posicao": 21}]',
     'ERRO_SINTATICO', 'token_inesperado', 11800),
    (1, 3, 200, 'cifrar pacote chave=5',
     '[{"tipo": "VERBO", "lexema": "cifrar", "posicao": 0}, {"tipo": "IDENTIFICADOR", "lexema": "pacote", "posicao": 7}, {"tipo": "IDENTIFICADOR", "lexema": "chave", "posicao": 14}, {"tipo": "ATRIBUICAO", "lexema": "=", "posicao": 19}, {"tipo": "NUMERO", "lexema": "5", "posicao": 20}, {"tipo": "EOF", "lexema": "", "posicao": 21}]',
     'ERRO_SEMANTICO', 'chave_incorreta', 7400),
    (1, 4, 300, 'cifrar pacote chave=3',
     '[{"tipo": "VERBO", "lexema": "cifrar", "posicao": 0}, {"tipo": "IDENTIFICADOR", "lexema": "pacote", "posicao": 7}, {"tipo": "IDENTIFICADOR", "lexema": "chave", "posicao": 14}, {"tipo": "ATRIBUICAO", "lexema": "=", "posicao": 19}, {"tipo": "NUMERO", "lexema": "3", "posicao": 20}, {"tipo": "EOF", "lexema": "", "posicao": 21}]',
     'SUCESSO', NULL, 5100),
    (2, 1, 200, 'cifrar pacote chave=30',
     '[{"tipo": "VERBO", "lexema": "cifrar", "posicao": 0}, {"tipo": "IDENTIFICADOR", "lexema": "pacote", "posicao": 7}, {"tipo": "IDENTIFICADOR", "lexema": "chave", "posicao": 14}, {"tipo": "ATRIBUICAO", "lexema": "=", "posicao": 19}, {"tipo": "NUMERO", "lexema": "30", "posicao": 20}, {"tipo": "EOF", "lexema": "", "posicao": 22}]',
     'ERRO_SEMANTICO', 'chave_fora_da_faixa', 15600)
) AS t(n, numero, segundos, entrada, tokens, resultado, codigo_erro, tempo_ms),
     pesquisa.sessao_jogo s
WHERE s.id_sessao = ('f1c71c10-0003-4000-8000-' || lpad(t.n::text, 12, '0'))::uuid
ON CONFLICT DO NOTHING;
