package br.edu.purrbytes.telemetria.ingestao.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import java.util.List;

// @NotNull no elemento: um null dentro da lista passava pela validacao e
// estourava NullPointerException no servico (500 em vez de 400).
public record LoteEventosRequest(@NotEmpty List<@NotNull @Valid EventoRequest> eventos) {
}
