package br.edu.purrbytes.telemetria.seguranca;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Duration;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class SegurancaConfig {

    @Bean
    public FilterRegistrationBean<AutenticacaoChaveApiFiltro> filtroDeAutenticacaoIngestao(
            ChaveApiRepository chaveApiRepository, ObjectMapper objectMapper,
            @Value("${purrbytes.seguranca.intervalo-registro-uso-minutos:5}") long intervaloRegistroUsoMinutos) {

        FilterRegistrationBean<AutenticacaoChaveApiFiltro> registro = new FilterRegistrationBean<>(
                new AutenticacaoChaveApiFiltro(chaveApiRepository, objectMapper,
                        Duration.ofMinutes(intervaloRegistroUsoMinutos)));
        // "/*" no padrao de Filter (nao de @RequestMapping) casa com qualquer
        // sub-caminho, entao cobre as quatro rotas de /v1/sessoes de uma vez.
        registro.addUrlPatterns("/v1/sessoes/*");
        registro.setName("filtroDeAutenticacaoIngestao");
        return registro;
    }
}
