package br.edu.purrbytes.telemetria.erro;

import jakarta.servlet.ServletException;
import java.util.LinkedHashMap;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.TypeMismatchException;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.ErrorResponse;
import org.springframework.web.ErrorResponseException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

/**
 * Um só lugar traduzindo exceção em corpo JSON — nenhum stack trace sai daqui
 * (server.error.include-stacktrace já está "never" em application.yml; isto é
 * a mesma política, aplicada também às respostas que nós mesmos montamos).
 */
@RestControllerAdvice
public class ManipuladorGlobalDeErros {

    private static final Logger log = LoggerFactory.getLogger(ManipuladorGlobalDeErros.class);

    @ExceptionHandler(ErroDeIngestao.class)
    public ResponseEntity<Map<String, Object>> tratarErroDeIngestao(ErroDeIngestao e) {
        return ResponseEntity.status(e.getStatus()).body(corpo("requisicao_invalida", e.getMessage()));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Map<String, Object>> tratarValidacao(MethodArgumentNotValidException e) {
        Map<String, String> campos = new LinkedHashMap<>();
        e.getBindingResult().getFieldErrors().forEach(erro ->
                campos.put(erro.getField(), erro.getDefaultMessage()));
        Map<String, Object> corpo = corpo("validacao", "um ou mais campos nao passaram na validacao");
        corpo.put("campos", campos);
        return ResponseEntity.badRequest().body(corpo);
    }

    @ExceptionHandler(DataIntegrityViolationException.class)
    public ResponseEntity<Map<String, Object>> tratarViolacaoDeIntegridade(DataIntegrityViolationException e) {
        // Cai aqui, por exemplo, tipo_evento fora do catalogo (FK) ou sequencia
        // duplicada dentro do mesmo lote. É sempre dado malformado -> 400.
        log.warn("lote rejeitado por violar restricao do banco: {}", e.getMostSpecificCause().getMessage());
        return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(corpo("dado_invalido", "o lote viola uma restricao do banco (codigo fora do catalogo ou duplicidade)"));
    }

    // Sem estes dois handlers, JSON ilegivel, timestamp sem fuso ou UUID
    // invalido na rota caiam no handler generico abaixo e voltavam 500. O
    // cliente trata 5xx como transitorio e para a drenagem no primeiro lote
    // que falha: um unico lote malformado travava a fila inteira para sempre.
    @ExceptionHandler({HttpMessageNotReadableException.class, TypeMismatchException.class})
    public ResponseEntity<Map<String, Object>> tratarRequisicaoMalformada(Exception e) {
        // So o tipo: a mensagem do Jackson pode trazer trecho do corpo recebido.
        log.warn("requisicao malformada rejeitada: {}", e.getClass().getSimpleName());
        return ResponseEntity.badRequest()
                .body(corpo("requisicao_malformada", "corpo ou parametro fora do formato do contrato"));
    }

    // Erros do proprio Spring MVC (rota inexistente, metodo ou content-type
    // errado) ja sabem o status certo; so faltava respeita-lo. 404 continua
    // transitorio para o cliente (URL errada no config.cfg nao apaga a coleta).
    @ExceptionHandler({ServletException.class, ErrorResponseException.class})
    public ResponseEntity<Map<String, Object>> tratarErroDoMvc(Exception e) {
        HttpStatusCode status = e instanceof ErrorResponse resposta
                ? resposta.getStatusCode()
                : HttpStatus.INTERNAL_SERVER_ERROR;
        if (status.is5xxServerError()) {
            log.error("erro do MVC ao processar ingestao", e);
        }
        return ResponseEntity.status(status).body(corpo("requisicao_invalida", "rota, metodo ou cabecalho fora do contrato"));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, Object>> tratarErroInesperado(Exception e) {
        log.error("erro nao mapeado ao processar ingestao", e);
        return ResponseEntity.internalServerError().body(corpo("erro_interno", "falha inesperada no servidor"));
    }

    private Map<String, Object> corpo(String erro, String detalhe) {
        Map<String, Object> corpo = new LinkedHashMap<>();
        corpo.put("erro", erro);
        corpo.put("detalhe", detalhe);
        return corpo;
    }
}
