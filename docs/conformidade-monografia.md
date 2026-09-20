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

**Consequência que ficava em aberto:** com o tutorial fora, o único lugar onde o jogador
descobre qual cifra engana qual interceptador é a **tela de captura** (ela nomeia o
algoritmo exigido) — ou seja, ele precisa ser pego uma vez para aprender. Até
2026-09-20, quatro textos das fases 1 a 3 ainda pressupunham a legenda removida: duas
perguntas de pacote identificavam o interceptador pela cor (`"um cachorro VERDE
ronda..."`, opção `"a cor do cachorro que está perseguindo"`) e dois desafios de revisão
citavam a cor como flavor text (`"...engana o cachorro verde/azul"`). **Resolvido**
(pendência 5): os quatro foram reescritos para serem respondíveis só com o que a fase já
ensinou até aquele ponto — a pergunta de aplicação descreve a AMEAÇA (interceptador que
fareja texto legível, ou que resiste a uma cifra já tentada) em vez do interceptador por
cor. `tests/teste_perguntas_sem_cor.gd` varre os três `.tres` publicados e falha se algum
campo de texto voltado ao jogador citar nome de cor.

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
   `teste_resiliencia_http.gd`) sobem `tools/servidor_eco.py` como subprocesso `python`
   real; com `python` no PATH os dois passam (confirmado em 2026-09-20). Numa máquina sem
   `python`, eles **falham** (não são pulados) — `ApoioServidorEco.aguardar_pronto()`
   nunca fica pronto e a asserção correspondente marca a suíte como vermelha.
3. **Travessia completa menu → fase 1 → 2 → 3 → menu** sem teste automatizado
   (`change_scene_to_file` dentro do processo compartilhado da suíte). Precisa de uma
   partida manual antes da coleta.
4. **Pré/pós-teste e TCLE** acontecem fora do jogo, por decisão de escopo.
5. ~~**Legenda cor → cifra** (ver desvio 1): decidir o destino antes de rodar o
   experimento.~~ **Resolvido em 2026-09-20** — ver desvio 1: os textos que dependiam da
   legenda removida foram reescritos para serem autocontidos, e um teste impede a
   regressão.
6. **Suspeita de descompasso de versão do Godot** — rodando a suíte nesta máquina (Godot
   4.6.2.stable, a primeira vez que o projeto é importado nela — sem `.godot/` prévio)
   aparecem falhas que **não existem no commit-base anterior a esta tarefa** (confirmado
   rodando a mesma suíte, sem nenhuma mudança, no commit `88e8605`):
   - `teste_astar`: 55 dos 100 mapas aleatórios têm custo de caminho divergente entre
     `AStarGrid2D` e `astar_referencia.gd`, e dois outros casos não encontram caminho que
     deveriam encontrar.
   - `teste_cenas::teste_tileset_tem_a_camada_solido` — `recursos/tilesets/labirinto.tres`
     não carrega como `TileSet` (`nao deveria ser null` falha).
   - `teste_fase_01_integracao`, `teste_fase_02_integracao`, `teste_modo_humano` — falhas de
     replanejamento de A\*, detecção de captura e pausa do terminal.
   `RELATORIO_CLAUDE_CODE.md` registra "254 testes, 1347 verificações, 0 falhas" numa sessão
   anterior (2026-09-16); nenhuma dessas falhas é nova desta tarefa (o editor em abas, o
   passe de estilo e a correção das perguntas não tocam `scripts/ia/` nem os `.tres` de
   tileset), e a hipótese mais provável é o `TileSet`/`AStarGrid2D` se comportando diferente
   entre a versão de Godot usada então e o 4.6.2 usado agora. **Não investigado nem corrigido
   por estar fora do escopo desta tarefa** — registrado aqui para quem for rodar a suíte
   antes da coleta confirmar a versão do Godot primeiro.
