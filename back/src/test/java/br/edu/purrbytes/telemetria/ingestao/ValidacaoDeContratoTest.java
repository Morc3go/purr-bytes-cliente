package br.edu.purrbytes.telemetria.ingestao;

import static org.assertj.core.api.Assertions.assertThat;

import br.edu.purrbytes.telemetria.ingestao.dto.AbrirSessaoRequest;
import br.edu.purrbytes.telemetria.ingestao.dto.EventoRequest;
import br.edu.purrbytes.telemetria.ingestao.dto.TentativaRequest;
import jakarta.validation.ConstraintViolation;
import jakarta.validation.Validation;
import jakarta.validation.Validator;
import jakarta.validation.ValidatorFactory;
import java.time.Instant;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

/**
 * Bean Validation puro, sem contexto Spring nem banco -- roda em milissegundos
 * e cobre exatamente as garantias que docs/contrato-telemetria.md promete ao
 * time do jogo (ex.: "resultado" so aceita o vocabulario fechado).
 */
class ValidacaoDeContratoTest {

    private static ValidatorFactory factory;
    private static Validator validator;

    @BeforeAll
    static void configurar() {
        factory = Validation.buildDefaultValidatorFactory();
        validator = factory.getValidator();
    }

    @AfterAll
    static void encerrar() {
        factory.close();
    }

    @Test
    void abrirSessaoValidaNaoGeraViolacao() {
        AbrirSessaoRequest req = new AbrirSessaoRequest(
                UUID.randomUUID(), UUID.randomUUID(), "0.1.0", "Windows", Instant.now());
        assertThat(validator.validate(req)).isEmpty();
    }

    @Test
    void abrirSessaoSemPlataformaFalha() {
        AbrirSessaoRequest req = new AbrirSessaoRequest(
                UUID.randomUUID(), UUID.randomUUID(), "0.1.0", "", Instant.now());
        assertThat(validator.validate(req)).isNotEmpty();
    }

    @Test
    void eventoDeSessaoSemIdFaseEAceito() {
        // SESSAO_INICIADA nao pertence a fase nenhuma: o cliente manda id_fase
        // nulo. Exigir o campo fazia a API recusar o lote inteiro (ver V8).
        EventoRequest req = new EventoRequest(UUID.randomUUID(), UUID.randomUUID(), 0,
                "SESSAO_INICIADA", null, null, null, Instant.now(), null);
        assertThat(validator.validate(req)).isEmpty();
    }

    @Test
    void tentativaSemIdFaseFalha() {
        // Tentativa de comando so existe dentro de uma fase.
        TentativaRequest req = new TentativaRequest(UUID.randomUUID(), UUID.randomUUID(),
                null, "Cesar", 1, "cesar-01", "cifrar pacote chave=3", null,
                "SUCESSO", null, 100, 1, Instant.now());
        Set<ConstraintViolation<TentativaRequest>> violacoes = validator.validate(req);
        assertThat(violacoes).anyMatch(v -> v.getPropertyPath().toString().equals("idFase"));
    }

    @Test
    void eventoComFaseForaDeUmAQuatroFalha() {
        EventoRequest req = new EventoRequest(UUID.randomUUID(), UUID.randomUUID(), 0,
                "FASE_INICIADA", UUID.randomUUID(), "Cesar", 7, Instant.now(), null);
        assertThat(validator.validate(req)).isNotEmpty();
    }

    @Test
    void tentativaComResultadoForaDoVocabularioFalha() {
        TentativaRequest req = new TentativaRequest(UUID.randomUUID(), UUID.randomUUID(),
                UUID.randomUUID(), "Cesar", 1, "cesar-01", "cifrar pacote chave=3", null,
                "QUASE_SUCESSO", null, 100, 1, Instant.now());
        assertThat(validator.validate(req)).isNotEmpty();
    }

    @Test
    void tentativaValidaComResultadoDoVocabularioNaoGeraViolacao() {
        TentativaRequest req = new TentativaRequest(UUID.randomUUID(), UUID.randomUUID(),
                UUID.randomUUID(), "Cesar", 1, "cesar-01", "cifrar pacote chave=3", null,
                "SUCESSO", null, 100, 1, Instant.now());
        assertThat(validator.validate(req)).isEmpty();
    }
}
