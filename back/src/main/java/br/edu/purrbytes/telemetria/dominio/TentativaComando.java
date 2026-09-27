package br.edu.purrbytes.telemetria.dominio;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.PostLoad;
import jakarta.persistence.PostPersist;
import jakarta.persistence.Table;
import jakarta.persistence.Transient;
import org.springframework.data.domain.Persistable;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

/**
 * pesquisa.tentativa_comando. Não tem coluna de sequência — ordem e detecção
 * de perda de pacote são responsabilidade só de evento_telemetria.
 */
@Entity
@Table(name = "tentativa_comando", schema = "pesquisa")
public class TentativaComando implements Persistable<UUID> {

    @Id
    @Column(name = "id_tentativa")
    private UUID idTentativa;

    @Column(name = "id_sessao", nullable = false)
    private UUID idSessao;

    @Column(name = "id_fase", nullable = false)
    private UUID idFase;

    @Column(name = "titulo_fase", length = 60)
    private String tituloFase;

    // SMALLINT nas migrations; sem o tipo explicito o ddl-auto=validate
    // recusava o schema (esperava INTEGER) e a API nao subia.
    @JdbcTypeCode(SqlTypes.SMALLINT)
    @Column(name = "fase")
    private Integer fase;

    @Column(name = "desafio", nullable = false, length = 60)
    private String desafio;

    @Column(name = "entrada_normalizada", nullable = false, length = 240)
    private String entradaNormalizada;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "tokens", nullable = false)
    private List<Map<String, Object>> tokens;

    @Column(name = "resultado", nullable = false, length = 20)
    private String resultado;

    @Column(name = "codigo_erro", length = 40)
    private String codigoErro;

    @Column(name = "tempo_resposta_ms", nullable = false)
    private int tempoRespostaMs;

    // SMALLINT nas migrations; sem o tipo explicito o ddl-auto=validate
    // recusava o schema (esperava INTEGER) e a API nao subia.
    @JdbcTypeCode(SqlTypes.SMALLINT)
    @Column(name = "numero_tentativa", nullable = false)
    private int numeroTentativa;

    @Column(name = "ocorrido_em", nullable = false)
    private Instant ocorridoEm;

    @Column(name = "recebido_em", nullable = false)
    private Instant recebidoEm;

    protected TentativaComando() {
    }

    public TentativaComando(UUID idTentativa, UUID idSessao, UUID idFase, String tituloFase,
            Integer fase, String desafio, String entradaNormalizada, List<Map<String, Object>> tokens,
            String resultado, String codigoErro, int tempoRespostaMs, int numeroTentativa,
            Instant ocorridoEm, Instant recebidoEm) {
        this.idTentativa = idTentativa;
        this.idSessao = idSessao;
        this.idFase = idFase;
        this.tituloFase = tituloFase;
        this.fase = fase;
        this.desafio = desafio;
        this.entradaNormalizada = entradaNormalizada;
        this.tokens = tokens;
        this.resultado = resultado;
        this.codigoErro = codigoErro;
        this.tempoRespostaMs = tempoRespostaMs;
        this.numeroTentativa = numeroTentativa;
        this.ocorridoEm = ocorridoEm;
        this.recebidoEm = recebidoEm;
    }

    public UUID getIdTentativa() {
        return idTentativa;
    }

    // Persistable: o id vem do cliente (UUID gerado no jogo), entao o Spring
    // Data nao tem como saber se o registro e novo e fazia merge() -- um
    // SELECT por linha antes de cada INSERT (510 SELECTs num lote de 500).
    // O servico ja filtra os ids gravados antes (idempotencia), entao todo
    // objeto criado aqui e novo: persist() direto, e o batch_size do
    // application.yml passa a agrupar os INSERTs de verdade.
    @Transient
    private boolean novo = true;

    @Override
    public UUID getId() {
        return idTentativa;
    }

    @Override
    public boolean isNew() {
        return novo;
    }

    @PostPersist
    @PostLoad
    void marcarComoPersistido() {
        this.novo = false;
    }
}
