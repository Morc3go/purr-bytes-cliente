package br.edu.purrbytes.telemetria.ingestao;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;

/**
 * O status HTTP é o contrato com o cliente Godot: 4xx de dado descarta o lote,
 * 5xx reenvia para sempre (docs/contrato-telemetria.md, seção 1). Entrada
 * ilegível respondendo 500 travava a fila do jogo atrás de um lote que nunca
 * ia passar -- estes testes fixam o status de cada caso, sem banco.
 */
@WebMvcTest(SessaoIngestaoController.class)
class RespostasHttpDaIngestaoTest {

    private static final String SESSAO = "d74c9f6e-818f-4fd5-bf5a-59427d614f1b";

    @Autowired
    private MockMvc mvc;

    @MockitoBean
    private SessaoIngestaoService sessaoService;

    @MockitoBean
    private EventoIngestaoService eventoService;

    @MockitoBean
    private TentativaIngestaoService tentativaService;

    private ResultActions postar(String caminho, String json) throws Exception {
        return mvc.perform(post(caminho).contentType(MediaType.APPLICATION_JSON).content(json));
    }

    private static String evento(String extra) {
        return "{\"id_evento\":\"" + UUID.randomUUID() + "\",\"id_sessao\":\"" + SESSAO + "\","
                + "\"sequencia\":0,\"tipo_evento\":\"SESSAO_INICIADA\",\"id_fase\":null,"
                + "\"ocorrido_em\":\"2026-08-21T23:04:16.396Z\"" + extra + "}";
    }

    @Test
    void aberturaDoContratoEAceita() throws Exception {
        postar("/v1/sessoes", "{\"id_sessao\":\"" + SESSAO + "\",\"id_sujeito\":\"" + UUID.randomUUID()
                + "\",\"versao_jogo\":\"0.1.0\",\"plataforma\":\"Windows\","
                + "\"iniciada_em\":\"2026-08-21T23:04:16.396Z\"}")
                .andExpect(status().isAccepted());
    }

    @Test
    void jsonTruncadoE400() throws Exception {
        postar("/v1/sessoes/" + SESSAO + "/eventos", "{\"eventos\":[{\"id_evento\":")
                .andExpect(status().isBadRequest());
        verify(eventoService, never()).registrarLote(any(), any());
    }

    @Test
    void nanNoPayloadE400() throws Exception {
        postar("/v1/sessoes/" + SESSAO + "/eventos", "{\"eventos\":[" + evento(",\"payload\":{\"fps\":nan}") + "]}")
                .andExpect(status().isBadRequest());
    }

    @Test
    void dataSemFusoE400() throws Exception {
        // Relogio.agora_utc_iso() existe justamente para nunca mandar isto.
        postar("/v1/sessoes", "{\"id_sessao\":\"" + SESSAO + "\",\"id_sujeito\":\"" + UUID.randomUUID()
                + "\",\"versao_jogo\":\"0.1.0\",\"plataforma\":\"Windows\",\"iniciada_em\":\"2026-08-21T23:04:16\"}")
                .andExpect(status().isBadRequest());
    }

    @Test
    void uuidInvalidoNaRotaE400() throws Exception {
        postar("/v1/sessoes/abc/eventos", "{\"eventos\":[" + evento("") + "]}")
                .andExpect(status().isBadRequest());
    }

    @Test
    void elementoNuloNoLoteE400() throws Exception {
        postar("/v1/sessoes/" + SESSAO + "/eventos", "{\"eventos\":[null]}")
                .andExpect(status().isBadRequest());
        verify(eventoService, never()).registrarLote(any(), any());
    }

    @Test
    void tokenNuloNaTentativaE400() throws Exception {
        postar("/v1/sessoes/" + SESSAO + "/tentativas", "{\"tentativas\":[{\"id_tentativa\":\"" + UUID.randomUUID()
                + "\",\"id_sessao\":\"" + SESSAO + "\",\"id_fase\":\"" + UUID.randomUUID()
                + "\",\"desafio\":\"cesar-01\",\"entrada_normalizada\":\"x\",\"tokens\":[null],"
                + "\"resultado\":\"SUCESSO\",\"tempo_resposta_ms\":1,\"numero_tentativa\":1,"
                + "\"ocorrido_em\":\"2026-08-21T23:04:16.396Z\"}]}")
                .andExpect(status().isBadRequest());
        verify(tentativaService, never()).registrarLote(any(), any());
    }

    @Test
    void encerrarSemStatusE400() throws Exception {
        postar("/v1/sessoes/" + SESSAO + "/encerrar",
                "{\"id_sessao\":\"" + SESSAO + "\",\"encerrada_em\":\"2026-08-21T23:04:16.396Z\"}")
                .andExpect(status().isBadRequest());
        verify(sessaoService, never()).encerrarSessao(any(), any());
    }

    @Test
    void rotaInexistenteE404() throws Exception {
        // 404 o cliente trata como configuracao errada e preserva o lote.
        postar("/v1/sessoes/" + SESSAO + "/xyz", "{}").andExpect(status().isNotFound());
    }

    @Test
    void metodoErradoE405() throws Exception {
        mvc.perform(get("/v1/sessoes")).andExpect(status().isMethodNotAllowed());
    }

    @Test
    void contentTypeErradoE415() throws Exception {
        mvc.perform(post("/v1/sessoes").contentType(MediaType.TEXT_PLAIN).content("x"))
                .andExpect(status().isUnsupportedMediaType());
    }
}
