# ADR 0040 — Cachorro sem meia-volta e sem pisar no gato

**Data:** 2026-11-21 · **Situação:** aceita

## Contexto

No vídeo de demonstração os cachorros pareciam "bugar" de dois jeitos:

1. **Tremida no corredor.** A cada replanejamento do A* (uma vez por segundo), o cachorro
   virava para trás por alguns quadros e depois seguia em frente. A rota que
   `Navegacao.calcular_caminho` devolve começa no centro da célula em que o cachorro está.
   Se ele já tinha saído desse centro rumo à próxima célula, `definir_caminho` o mandava
   voltar até lá antes de seguir. Um diagnóstico de 30 s por fase demo contou de 2 a 14
   meias-voltas por cachorro, sempre aos pares (ida e volta), nos quadros do replanejamento.
2. **Cachorros em cima do gato.** Com o gato piscando depois de uma captura, ou protegido
   pela cifra certa, o vigia não pode pegá-lo, mas a rota continuava até a célula do gato.
   Os sprites ficavam empilhados, e parecia que o gato estava sendo pego sem ser.

## Decisões

- **`Cachorro.definir_caminho` pula o primeiro ponto quando o cachorro já está sobre o
  trecho até o segundo** (`primeiro_ponto_a_frente`: mesma linha, entre um e outro, com a
  folga de `tolerancia_de_chegada`). Se a rota nova sai para outro lado, ele volta ao
  centro antes de virar, como antes, para não cortar a quina da cerca.
- **`FaseBase._sem_pisar_no_gato`**: quando o cachorro não pode pegar o gato naquele
  momento (gato invulnerável ou protegido contra aquele vigia) e a rota termina na célula
  do gato, a rota para uma célula antes.

## Consequências

- O A*, a detecção por linha de visão, a telemetria e as regras de captura não mudam: só
  onde a rota começa e onde termina.
- Depois da correção, o mesmo diagnóstico contou zero meias-voltas nas cinco fases demo.
- Testes: `teste_cachorro_caminho.gd` (ponto da frente) e
  `teste_captura_e_retorno.gd::teste_cachorro_nao_pisa_no_gato_que_ele_nao_pode_pegar`.
