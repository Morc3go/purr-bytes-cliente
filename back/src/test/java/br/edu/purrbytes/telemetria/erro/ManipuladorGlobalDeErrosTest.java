package br.edu.purrbytes.telemetria.erro;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.beans.TypeMismatchException;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.mock.http.MockHttpInputMessage;
import org.springframework.web.HttpMediaTypeNotSupportedException;
import org.springframework.web.HttpRequestMethodNotSupportedException;

/**
 * O que importa aqui e o status: o cliente decide por ele se reenvia (5xx,
 * 401, 404...) ou descarta (400). Requisicao malformada nunca pode sair 5xx,
 * senao trava a fila do jogo.
 */
class ManipuladorGlobalDeErrosTest {

    private final ManipuladorGlobalDeErros manipulador = new ManipuladorGlobalDeErros();

    @Test
    void jsonIlegivelE400() {
        var erro = new HttpMessageNotReadableException("timestamp sem fuso", new MockHttpInputMessage(new byte[0]));
        assertThat(manipulador.tratarRequisicaoMalformada(erro).getStatusCode().value()).isEqualTo(400);
    }

    @Test
    void uuidInvalidoNaRotaE400() {
        var erro = new TypeMismatchException("nao-e-uuid", java.util.UUID.class);
        assertThat(manipulador.tratarRequisicaoMalformada(erro).getStatusCode().value()).isEqualTo(400);
    }

    @Test
    void metodoErradoRespeitaO405DoSpring() {
        var erro = new HttpRequestMethodNotSupportedException("DELETE");
        assertThat(manipulador.tratarErroDoMvc(erro).getStatusCode().value()).isEqualTo(405);
    }

    @Test
    void contentTypeErradoRespeitaO415DoSpring() {
        var erro = new HttpMediaTypeNotSupportedException("text/plain nao suportado");
        assertThat(manipulador.tratarErroDoMvc(erro).getStatusCode().value()).isEqualTo(415);
    }
}
