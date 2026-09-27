-- ===========================================================================
-- V8 - Ajustes de integracao com o cliente Godot
--
-- Encontrados rodando o cliente real contra a API (sessao completa em modo
-- HTTP). V1..V7 nao sao alteradas: ja podem estar aplicadas em algum banco, e
-- mudar uma migration aplicada quebra o checksum do Flyway.
-- ===========================================================================

-- 1. Evento de SESSAO nao pertence a fase nenhuma.
--
-- SESSAO_INICIADA, SESSAO_ENCERRADA, SESSAO_ABANDONADA (e AMOSTRA_DESEMPENHO
-- no menu) acontecem fora de fase. A V7 criou id_fase NOT NULL em todo evento,
-- entao a API recusava com 400 o lote que os continha -- e o cliente, que trata
-- 4xx como erro permanente, DESCARTAVA o lote inteiro: nenhum evento da sessao
-- chegava ao banco. Tentativa de comando continua exigindo id_fase (so existe
-- dentro de uma fase).
ALTER TABLE pesquisa.evento_telemetria
    ALTER COLUMN id_fase DROP NOT NULL;

COMMENT ON COLUMN pesquisa.evento_telemetria.id_fase IS
    'Identidade real da fase (UUID v4 estavel da ferramenta de autoria). NULL so em eventos de sessao, que nao pertencem a fase nenhuma.';

-- 2. tentativa_comando.fase e LEGADO desde a V7, mas continuava NOT NULL e
-- presa a 1..4 (V2). So passava porque toda fase de autoria vai com numero 1;
-- a entidade Java ja trata o campo como opcional. O CHECK de faixa continua.
ALTER TABLE pesquisa.tentativa_comando
    ALTER COLUMN fase DROP NOT NULL;

-- 3. vw_desempenho_fase agrupava pelo numero legado: todas as fases de
-- autoria (numero 1) caiam numa linha so, somando fases diferentes. Agora a
-- fase e o id_fase, como no resto do sistema; o titulo vem so como rotulo.
DROP VIEW IF EXISTS pesquisa.vw_desempenho_fase;

CREATE VIEW pesquisa.vw_desempenho_fase AS
SELECT
    t.id_sessao,
    s.id_sujeito,
    t.id_fase,
    MAX(t.titulo_fase)                                       AS titulo_fase,
    COUNT(*)                                                AS total_tentativas,
    COUNT(*) FILTER (WHERE t.resultado = 'SUCESSO')          AS total_acertos,
    COALESCE(ROUND(
        COUNT(*) FILTER (WHERE t.resultado = 'SUCESSO')::numeric
        / NULLIF(COUNT(*), 0), 4), 0)                        AS taxa_acerto,
    COUNT(*) FILTER (WHERE t.resultado = 'ERRO_LEXICO')      AS total_erros_lexicos,
    COUNT(*) FILTER (WHERE t.resultado = 'ERRO_SINTATICO')   AS total_erros_sintaticos,
    COUNT(*) FILTER (WHERE t.resultado = 'ERRO_SEMANTICO')   AS total_erros_semanticos,
    ROUND(AVG(t.tempo_resposta_ms)::numeric, 2)              AS tempo_medio_ms,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY t.tempo_resposta_ms) AS tempo_mediano_ms,
    MIN(t.ocorrido_em)                                       AS primeira_tentativa_em,
    MAX(t.ocorrido_em)                                       AS ultima_tentativa_em
FROM pesquisa.tentativa_comando t
JOIN pesquisa.sessao_jogo s ON s.id_sessao = t.id_sessao
GROUP BY t.id_sessao, s.id_sujeito, t.id_fase;

COMMENT ON VIEW pesquisa.vw_desempenho_fase IS
    'Metricas objetivas de aprendizado por sessao e fase (id_fase). Separa erro lexico de sintatico, respondendo ao apontamento 5 da banca.';
