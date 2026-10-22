package br.edu.purrbytes.telemetria.privacidade;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

class SanitizadorDeTextoTest {

    private final SanitizadorDeTexto sanitizador = new SanitizadorDeTexto(240);

    @Test
    void caractereNulETrocadoPorEspaco() {
        // O PostgreSQL recusa NUL em TEXT/JSONB; antes isto virava 500 e
        // travava a fila do cliente.
        assertThat(sanitizador.texto("cifrar\u0000pacote", 240)).isEqualTo("cifrar pacote");
    }

    @Test
    void controleEEspacosSaoColapsados() {
        assertThat(sanitizador.texto("  cifrar\t\n  pacote  ", 240)).isEqualTo("cifrar pacote");
    }

    @Test
    void textoLongoETruncadoNoLimite() {
        assertThat(sanitizador.texto("a".repeat(500), 240)).hasSize(240);
    }

    @Test
    void textoNuloContinuaNulo() {
        assertThat(sanitizador.texto(null, 40)).isNull();
    }

    @Test
    void payloadNuloViraMapaVazio() {
        assertThat(sanitizador.payload(null)).isEmpty();
    }

    @Test
    void stringDentroDeListaEMapaAninhadoTambemETruncada() {
        Map<String, Object> payload = Map.of(
                "lista", List.of("b".repeat(300)),
                "mapa", Map.of("texto", "c".repeat(300)));

        Map<String, Object> saida = sanitizador.payload(payload);

        assertThat((List<?>) saida.get("lista")).containsExactly("b".repeat(240));
        assertThat(((Map<?, ?>) saida.get("mapa")).get("texto")).isEqualTo("c".repeat(240));
    }

    @Test
    void numerosEBooleanosPassamIntactos() {
        Map<String, Object> saida = sanitizador.payload(Map.of("fps", 60, "protecao_ativa", true));
        assertThat(saida).containsEntry("fps", 60).containsEntry("protecao_ativa", true);
    }

    @Test
    void ramoMaisProfundoQueOLimiteECortado() {
        // Raiz na profundidade 0; o mapa na profundidade 5 passa do limite (4).
        Map<String, Object> fundo = Map.of("segredo", "x");
        for (int i = 0; i < 5; i++) {
            fundo = Map.<String, Object>of("n", fundo);
        }

        Object atual = sanitizador.payload(fundo);
        for (int i = 0; i < 5; i++) {
            atual = ((Map<?, ?>) atual).get("n");
        }

        assertThat((Map<?, ?>) atual).isEmpty();
    }
}
