package br.edu.purrbytes.telemetria.ingestao.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;

/**
 * Um elemento de {@code POST /v1/sessoes/{id}/eventos}. {@code idFase} é
 * opcional: eventos de sessão (SESSAO_INICIADA, SESSAO_ENCERRADA...) não
 * pertencem a fase nenhuma. Exigir o campo aqui fazia a API recusar o lote
 * inteiro com 400 -- e o cliente descartava todos os eventos da sessão (ver
 * migration V8). {@code fase} é legado e nulável (o cliente só o preenche
 * entre 1 e 4).
 */
public record EventoRequest(
        @NotNull UUID idEvento,
        @NotNull UUID idSessao,
        @PositiveOrZero long sequencia,
        @NotBlank @Size(max = 40) String tipoEvento,
        UUID idFase,
        @Size(max = 60) String tituloFase,
        @Min(1) @Max(4) Integer fase,
        @NotNull Instant ocorridoEm,
        Map<String, Object> payload
) {
}
