package br.edu.purrbytes.telemetria.ingestao.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import java.util.List;

// Ver o comentario equivalente em LoteEventosRequest.
public record LoteTentativasRequest(@NotEmpty List<@NotNull @Valid TentativaRequest> tentativas) {
}
