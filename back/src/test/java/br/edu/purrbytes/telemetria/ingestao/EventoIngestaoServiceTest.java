package br.edu.purrbytes.telemetria.ingestao;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import br.edu.purrbytes.telemetria.dominio.EventoTelemetria;
import br.edu.purrbytes.telemetria.dominio.EventoTelemetriaRepository;
import br.edu.purrbytes.telemetria.dominio.SessaoJogoRepository;
import br.edu.purrbytes.telemetria.ingestao.dto.EventoRequest;
import br.edu.purrbytes.telemetria.ingestao.dto.LoteEventosRequest;
import br.edu.purrbytes.telemetria.privacidade.SanitizadorDeTexto;
import java.time.Instant;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Captor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class EventoIngestaoServiceTest {

    @Mock
    private EventoTelemetriaRepository eventoRepository;

    @Mock
    private SessaoJogoRepository sessaoRepository;

    @Captor
    private ArgumentCaptor<List<EventoTelemetria>> gravados;

    private EventoIngestaoService servico;

    @BeforeEach
    void montar() {
        servico = new EventoIngestaoService(eventoRepository, sessaoRepository,
                new SanitizadorDeTexto(240), 500, 60);
    }

    @Test
    void idRepetidoDentroDoLoteEGravadoUmaVezSo() {
        // Antes, o segundo estourava a chave primaria: 400 e o lote inteiro
        // era descartado pelo cliente.
        UUID idSessao = UUID.randomUUID();
        EventoRequest evento = new EventoRequest(UUID.randomUUID(), idSessao, 0,
                "SESSAO_INICIADA", null, null, null, Instant.now(), null);
        when(sessaoRepository.existsById(idSessao)).thenReturn(true);
        when(eventoRepository.idsExistentes(any())).thenReturn(Set.of());

        int novos = servico.registrarLote(idSessao, new LoteEventosRequest(List.of(evento, evento)));

        assertThat(novos).isEqualTo(1);
        verify(eventoRepository).saveAll(gravados.capture());
        assertThat(gravados.getValue()).extracting(EventoTelemetria::getIdEvento)
                .containsExactly(evento.idEvento());
    }

    @Test
    void eventoJaGravadoNaoEGravadoDeNovo() {
        UUID idSessao = UUID.randomUUID();
        EventoRequest antigo = new EventoRequest(UUID.randomUUID(), idSessao, 0,
                "SESSAO_INICIADA", null, null, null, Instant.now(), null);
        EventoRequest novo = new EventoRequest(UUID.randomUUID(), idSessao, 1,
                "FASE_INICIADA", UUID.randomUUID(), "Cesar", 1, Instant.now(), null);
        when(sessaoRepository.existsById(idSessao)).thenReturn(true);
        when(eventoRepository.idsExistentes(any())).thenReturn(Set.of(antigo.idEvento()));

        int novos = servico.registrarLote(idSessao, new LoteEventosRequest(List.of(antigo, novo)));

        assertThat(novos).isEqualTo(1);
        verify(eventoRepository).saveAll(gravados.capture());
        assertThat(gravados.getValue()).extracting(EventoTelemetria::getIdEvento)
                .containsExactly(novo.idEvento());
    }
}
