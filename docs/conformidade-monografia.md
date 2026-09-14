# Conformidade com a monografia — estado do cliente

**Atualizado em:** 2026-09-14 · Este documento existe para a defesa: para cada requisito
declarado na monografia, o que o cliente **tem hoje**, onde isso vive no código, e o que
ainda falta. Requisito que mudou de forma está marcado com o porquê.

---

## Requisitos funcionais

| Requisito | Estado | Onde |
|---|---|---|
| Quatro fases, uma por algoritmo (César, Vigenère, SHA-256, AES) | **Parcial** — três jogáveis; AES fora de escopo por decisão (seção 11 do `CLAUDE.md`) | `cenas/fases/fase_0{1,2,3}.tscn` |
| Labirinto como topologia de rede, com pacote a transportar | ✅ | `cenas/base/fase_base.gd`, `scripts/dominio/mapa_config.gd` |
| Interceptador (cachorro) com IA de perseguição | ✅ A\* real, patrulha, linha de visão | `scripts/ia/navegacao.gd`, `cenas/base/cachorro.gd` |
| Informação imperfeita (Diretor, dois cérebros) | ✅ fases 2 e 3 | `scripts/ia/diretor.gd`, ADR 0002 |
| Terminal com analisador léxico-sintático (AFD + parser) | ✅ com as duas etapas separadas e observáveis | `scripts/lexico/`, ADR 0006 |
| Cifra de César, Vigenère e SHA-256 funcionando de verdade | ✅ testadas contra vetores conhecidos | `scripts/cripto/`, `tests/teste_{cesar,vigenere,sha256}.gd` |
| Economia de erro (vidas, pontuação, captura não expulsa) | ✅ | `autoload/sessao.gd`, `cenas/ui/tela_captura.tscn` |
| Telemetria assíncrona, tolerante a falha | ✅ fila em disco, lote, backoff, retomada | `autoload/telemetria.gd`, ADR 0003/0009 |
| **Dashboard de Telemetria (Figura 7)** | ✅ **novo** — acertos × erros, tempo por fase, exportar JSON | `cenas/ui/dashboard_telemetria.tscn`, `scripts/telemetria/resumo_telemetria.gd` |
| Demonstração visual da cifra (`CIFRA_DEMONSTRADA`) | ✅ painel + explicação passo a passo no terminal ao acertar | `cenas/base/painel_cifra.tscn`, `FaseBase._explicar_no_terminal` |

## Requisitos não funcionais

| Requisito | Estado | Observação |
|---|---|---|
| Arquitetura modular; fase nova = dado, não código | ✅ | `FaseConfig` + `MapaConfig` + `.tres`; as cenas de fase não têm script |
| Rodar em hardware escolar padrão | ✅ por construção | renderizador Mobile, 640×360, `AMOSTRA_DESEMPENHO` a cada 30 s |
| Nenhum dado pessoal sai do cliente | ✅ | só `id_sujeito` (UUID), `id_sessao`, `id_fase`; texto livre truncado em 240 |
| Evento perdido = dado de pesquisa perdido | ✅ reforçado | o descarte por número de fase **acabou** (ver abaixo) |
| Comportamento auditável na tela | ✅ | `F3` desenha o A\*, dashboard mostra a coleta, painel de diagnóstico mostra a fila |

---

## Desvios conscientes (e por quê)

### 1. A regra "a cor do cachorro diz qual cifra usar" saiu da interface

**O que era:** um tutorial no menu ensinava a legenda cor → cifra, a HUD pintava a proteção
ativa com a cor do algoritmo, e a tela de captura dizia "o cachorro verde lê César".

**O que é agora:** a cor virou **identidade visual** do cachorro (`CachorroConfig.cor`,
livre, destinada a virar sprite). O tutorial, a HUD colorida e as frases por cor foram
removidos a pedido, na preparação para a ferramenta de autoria em que o professor escolhe
cor e comando livremente.

**O que permanece:** a mecânica em si. Cada cachorro ainda exige **um** algoritmo
(`algoritmo_exigido`), e cifrar com outro não protege — `FaseBase._protegido_contra`. A
validação de justiça também continua: `FaseConfig.problemas()` recusa a fase cujo cachorro
exija uma cifra que ela não ensina.

**Consequência a resolver antes da coleta:** com o tutorial fora, o único lugar onde o
jogador descobre qual cifra engana qual interceptador é a **tela de captura** (ela nomeia
o algoritmo exigido) — ou seja, ele precisa ser pego uma vez para aprender. Três perguntas
de pacote ainda identificam o interceptador pela cor (`"um cachorro VERDE ronda..."`) e
pressupõem a legenda que saiu. **Recomendação:** ou a ferramenta de autoria traz a legenda
de volta como dado da fase, ou essas três perguntas passam a identificar o interceptador
por outro traço. Está listado, não corrigido em silêncio.

### 2. `id_fase` substitui o número da fase como identidade

O esquema do banco nasceu com `CHECK (fase BETWEEN 1 AND 4)`, e o cliente **descartava**
telemetria fora dessa faixa. Numa ferramenta de fases livres isso perderia o dado da
maioria das fases. Agora todo evento e tentativa carrega `id_fase` (UUID estável, gravado
no recurso da fase) e nada é descartado por número. Contrato para o time do banco em
`docs/contrato-telemetria.md`, seção 0.

### 3. O mapa é texto validado, não desenho

`MapaConfig` (grid ASCII) é a fonte única do labirinto; o `TileMapLayer` e o `AStarGrid2D`
derivam dele. Um mapa incoerente (pacote ilhado, porta inalcançável, cachorro preso)
**reprova a fase** com mensagem clara em vez de virar bug silencioso. Ver ADR 0010.

---

## O que falta para a monografia fechar

1. **Fase 4 (AES)** — fora de escopo declarado; entra por configuração quando for a hora.
2. **Rotas REST do back-end** — não existem em produção; o cliente está validado contra
   `tools/servidor_eco.py`. Os dois testes de HTTP (`teste_transporte_http.gd`,
   `teste_resiliencia_http.gd`) precisam de `python` instalado e **não rodam** na máquina
   de desenvolvimento atual.
3. **Travessia completa menu → fase 1 → 2 → 3 → menu** sem teste automatizado
   (`change_scene_to_file` dentro do processo compartilhado da suíte). Precisa de uma
   partida manual antes da coleta.
4. **Pré/pós-teste e TCLE** acontecem fora do jogo, por decisão de escopo.
5. **Legenda cor → cifra** (ver desvio 1): decidir o destino antes de rodar o experimento.
