package br.edu.purrbytes.telemetria.ingestao;

import br.edu.purrbytes.telemetria.dominio.SessaoJogoRepository;
import br.edu.purrbytes.telemetria.dominio.TentativaComando;
import br.edu.purrbytes.telemetria.dominio.TentativaComandoRepository;
import br.edu.purrbytes.telemetria.erro.ErroDeIngestao;
import br.edu.purrbytes.telemetria.ingestao.dto.LoteTentativasRequest;
import br.edu.purrbytes.telemetria.ingestao.dto.TentativaRequest;
import br.edu.purrbytes.telemetria.ingestao.dto.TokenRequest;
import br.edu.purrbytes.telemetria.privacidade.SanitizadorDeTexto;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class TentativaIngestaoService {

    // Larguras das colunas de pesquisa.tentativa_comando (V2, V7) e do lexema
    // no cliente (LIMITE_LEXEMA). entrada_normalizada usa o limite de texto
    // livre configurado, que e o que a politica de privacidade promete.
    static final int LIMITE_DESAFIO = 60;
    static final int LIMITE_TITULO_FASE = 60;
    static final int LIMITE_CODIGO_ERRO = 40;
    static final int LIMITE_TIPO_TOKEN = 40;
    static final int LIMITE_LEXEMA = 60;

    private final TentativaComandoRepository tentativaRepository;
    private final SessaoJogoRepository sessaoRepository;
    private final SanitizadorDeTexto sanitizador;
    private final int maxEventosPorLote;

    public TentativaIngestaoService(
            TentativaComandoRepository tentativaRepository,
            SessaoJogoRepository sessaoRepository,
            SanitizadorDeTexto sanitizador,
            @Value("${purrbytes.ingestao.max-eventos-por-lote}") int maxEventosPorLote) {
        this.tentativaRepository = tentativaRepository;
        this.sessaoRepository = sessaoRepository;
        this.sanitizador = sanitizador;
        this.maxEventosPorLote = maxEventosPorLote;
    }

    @Transactional
    public int registrarLote(UUID idSessaoNaRota, LoteTentativasRequest req) {
        List<TentativaRequest> tentativas = req.tentativas();
        if (tentativas.size() > maxEventosPorLote) {
            throw new ErroDeIngestao("lote com " + tentativas.size()
                    + " tentativas, acima do teto de " + maxEventosPorLote);
        }
        for (TentativaRequest tentativa : tentativas) {
            if (!idSessaoNaRota.equals(tentativa.idSessao())) {
                throw new ErroDeIngestao("id_sessao da rota nao bate com o de uma tentativa do lote");
            }
        }
        if (!sessaoRepository.existsById(idSessaoNaRota)) {
            throw new ErroDeIngestao("sessao inexistente; abra a sessao antes de enviar tentativas");
        }

        // Mesmo motivo de EventoIngestaoService: id repetido dentro do lote.
        Map<UUID, TentativaRequest> porId = new LinkedHashMap<>();
        tentativas.forEach(t -> porId.putIfAbsent(t.idTentativa(), t));

        Set<UUID> idsJaGravados = tentativaRepository.idsExistentes(porId.keySet());
        List<TentativaComando> novas = porId.values().stream()
                .filter(t -> !idsJaGravados.contains(t.idTentativa()))
                .map(this::paraEntidade)
                .toList();

        tentativaRepository.saveAll(novas);
        return novas.size();
    }

    private TentativaComando paraEntidade(TentativaRequest t) {
        List<Map<String, Object>> tokens = (t.tokens() == null ? List.<TokenRequest>of() : t.tokens())
                .stream()
                .map(token -> Map.<String, Object>of(
                        "tipo", sanitizador.texto(token.tipo(), LIMITE_TIPO_TOKEN),
                        "lexema", token.lexema() == null ? "" : sanitizador.texto(token.lexema(), LIMITE_LEXEMA),
                        "posicao", token.posicao()))
                .toList();

        return new TentativaComando(t.idTentativa(), t.idSessao(), t.idFase(),
                sanitizador.texto(t.tituloFase(), LIMITE_TITULO_FASE), t.fase(),
                sanitizador.texto(t.desafio(), LIMITE_DESAFIO),
                sanitizador.texto(t.entradaNormalizada(), sanitizador.getLimiteTextoLivre()),
                tokens, t.resultado(), sanitizador.texto(t.codigoErro(), LIMITE_CODIGO_ERRO),
                t.tempoRespostaMs(), t.numeroTentativa(), t.ocorridoEm(), Instant.now());
    }
}
