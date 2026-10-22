package br.edu.purrbytes.telemetria.privacidade;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Pattern;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * Espelho no servidor de {@code _sanitizar_payload} / {@code _sanitizar_texto}
 * do autoload Telemetria do cliente Godot: troca caracteres de controle por
 * espaco, colapsa espacos, trunca texto livre e corta payload profundo demais.
 *
 * <p>O cliente ja faz isso, mas a API nao pode depender de quem a chama
 * (defesa em profundidade, art. 46 da LGPD): o limite de texto livre de
 * {@code purrbytes.privacidade.limite-texto-livre} so vale de fato se for
 * aplicado aqui. Ha tambem um motivo operacional: o PostgreSQL recusa o
 * caractere NUL em TEXT e em JSONB, e esse erro nao e de integridade -- virava
 * 500, que o cliente trata como transitorio, travando a fila inteira.
 */
@Component
public class SanitizadorDeTexto {

    /** Mesmo PROFUNDIDADE_MAXIMA_PAYLOAD do cliente. */
    static final int PROFUNDIDADE_MAXIMA = 4;

    /** Mesmo limite que o cliente aplica ao nome de cada chave do payload. */
    static final int LIMITE_NOME_CHAVE = 60;

    private static final Pattern CONTROLE = Pattern.compile("\\p{Cntrl}");
    private static final Pattern ESPACOS = Pattern.compile("\\s+");

    private final int limiteTextoLivre;

    public SanitizadorDeTexto(@Value("${purrbytes.privacidade.limite-texto-livre}") int limiteTextoLivre) {
        this.limiteTextoLivre = limiteTextoLivre;
    }

    public int getLimiteTextoLivre() {
        return limiteTextoLivre;
    }

    /** Limpa e trunca; {@code null} continua {@code null} (colunas nulaveis). */
    public String texto(String texto, int limite) {
        if (texto == null) {
            return null;
        }
        String limpo = CONTROLE.matcher(texto).replaceAll(" ");
        limpo = ESPACOS.matcher(limpo).replaceAll(" ").strip();
        return limpo.length() > limite ? limpo.substring(0, limite) : limpo;
    }

    public Map<String, Object> payload(Map<String, Object> payload) {
        return payload == null ? Map.of() : mapa(payload, 0);
    }

    private Map<String, Object> mapa(Map<?, ?> mapa, int profundidade) {
        Map<String, Object> saida = new LinkedHashMap<>();
        if (profundidade > PROFUNDIDADE_MAXIMA) {
            return saida;
        }
        mapa.forEach((chave, valor) ->
                saida.put(texto(String.valueOf(chave), LIMITE_NOME_CHAVE), valor(valor, profundidade)));
        return saida;
    }

    private Object valor(Object valor, int profundidade) {
        if (valor instanceof String texto) {
            return texto(texto, limiteTextoLivre);
        }
        if (valor instanceof Map<?, ?> mapa) {
            return mapa(mapa, profundidade + 1);
        }
        if (valor instanceof List<?> lista) {
            // Stream.toList aceita null, que e um valor JSON legitimo.
            return lista.stream().map(item -> valor(item, profundidade + 1)).toList();
        }
        return valor; // numero, booleano ou null: nao carregam texto livre
    }
}
