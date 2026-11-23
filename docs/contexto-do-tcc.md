# Contexto completo do TCC: Purr Bytes / Crypto Cats

> **Para o Claude do chat novo:** este arquivo resume tudo o que foi planejado, construído e
> decidido no TCC até 16/11/2026. Leia-o inteiro antes de responder. Quando houver dúvida
> entre este resumo e os arquivos anexados (projeto `.zip`, monografia), **os arquivos valem
> mais**. A usuária é a Dayane, escreve em português informal e gosta de respostas diretas.

---

## 1. Identificação

| Item | Valor |
|---|---|
| Curso / instituição | Ciência da Computação, Universidade Positivo, Curitiba, 2026 |
| Etapa | TCC II (o TCC I foi no 1º semestre) |
| Orientador | Prof. Me. Leandro Escobar |
| Equipe | Dayane Dias, Letícia Belo Ribeiro, João Antônio de Souza, Matheus Henrique Urban |
| Nome do projeto | **Purr Bytes** |
| Nome do jogo | **Crypto Cats** |
| Título da monografia | *Purr Bytes: jogo educacional para letramento em segurança digital* |
| Monografia "oficial" (viva) | Google Docs: https://docs.google.com/document/d/1DcOwZLTiqNDvk2OtiPWFuakbVW-cbUIz/edit |
| Pasta das figuras (Drive) | https://drive.google.com/drive/folders/1AIHCkAoQ0QzLEMQ1CkoLJ09-28e_7IAs |

**Divisão de tarefas declarada na monografia (seção 2.3, células não exclusivas):**
- Game Design e Front-end: Dayane (liderança).
- Back-end e Segurança (arquitetura, analisador léxico, cifras, API Java): Letícia e Dayane.
- IA e Telemetria (A*, modelagem do banco, rotas da API): Matheus e João.
- Pendente: a equipe ainda precisa confirmar essa divisão (item PB-08 da revisão).

---

## 2. A ideia do jogo

Jogo educacional 2D em pixel art para ensinar **letramento digital, criptografia e
segurança cibernética** a públicos com pouco conhecimento técnico.

- O **labirinto** representa uma rede. O **gato** carrega um **pacote de dados** até a porta de saída.
- **Cachorros vigias** (guiados pelo algoritmo **A\***) representam quem intercepta dados em trânsito.
- Cada vigia tem um **anel colorido** no chão e é parado de um jeito:
  - **Vigia de cifra** (César, Vigenère ou SHA-256): o jogador aplica a cifra no terminal, por exemplo ***cifrar senha chave=3***. A proteção vem da cifra real.
  - **Vigia de comando livre (conduta)**: o jogador digita a frase que o professor definiu, por exemplo ***conferir remetente***, ***desconfiar do link*** ou ***ativar 2fa***. A comparação é exata e acontece antes do analisador.
  - **Vigia que só persegue**: não há comando, a defesa é fugir.
- Encostar num vigia sem proteção causa **captura**: o jogador perde vida e pontos e volta ao início. **Não é game over**, é o custo pedagógico do erro. A tela de captura explica o que teria protegido.
- Há **pacotes com perguntas** espalhados pelo mapa. A porta, um arco de pedra do tamanho de uma célula, só abre depois que todos são coletados.
- **Cenários do labirinto** (ADR 0035 e 0036, 21/11/2026): ao jogar, depois do gatinho, o jogador escolhe o cenário num cartão com a miniatura de cada um. O cenário que a fase sugere (definido no editor como "cenário sugerido") já vem marcado, e Esc volta ao gatinho.
  - As opções são jardim (o verde de antes, padrão), outono, cerejeira, lago com passarelas (deck de tábuas e água com vitórias-régias e sapinhos), inverno (com 2 bonecos de neve), ruínas de pedra, bosque encantado e campo de lavanda.
  - É só aparência: paredes, regras e telemetria são iguais em todos.
  - Os enfeites são poucos, ficam no chão e na cor do cenário, nunca em cima da cerca.
  - Na trilha de demonstração: César no outono, Vigenère na cerejeira, SHA-256 no lago, golpes no bosque e avaliação final no inverno.
- **Escolha do gatinho** (e em seguida do cenário) antes de cada fase: amarelo (gato base), cálico ou siamês. A arte é autoral da equipe, e o jogo lembra a escolha.
  - Parado, o gato continua virado para onde andava. Depois de 5 s ele senta, e 2 s depois dorme.
  - A pelagem é só cosmética e não muda regras nem métricas.
- Os cachorros são o **husky** e o **pastor**, desenhados pela equipe no traço novo (ADR 0037 e 0042); quando param, sentam. Toda fase alterna husky, pastor, husky... pela ordem dos vigias, sem escolha no editor. O valor antigo "caramelo" é desenhado como o pastor.

**Teclas:**

| Tecla | Função |
|---|---|
| WASD / setas | Mover |
| T | Terminal (pausa o jogo) |
| F4 | Painel que mostra a cifra letra a letra, e o efeito avalanche no SHA-256 |
| F3 | Desenha a rota do A* de cada cachorro (é a demo da IA para a banca) |
| ESC | Pausa |

**Comandos do terminal:** ***cifrar***, ***decifrar***, ***hash***, ***verificar***, ***dica*** e ***status***, além dos comandos livres da fase.

### Trilha de 5 fases de demonstração (Quadro 7 da monografia)

| Fase | Conceito | Ação do jogador |
|---|---|---|
| 1. César: o primeiro segredo | deslocamento fixo; fragilidade diante da força bruta | ***cifrar senha chave=3***, ***cifrar pacote chave=5*** |
| 2. Vigenère: a chave que muda | cifra polialfabética, resistência à análise de frequência | ***cifrar segredo chave=gato*** |
| 3. SHA-256: o pacote foi alterado? | hash de mão única, integridade, avalanche, senhas por hash | ***hash*** e ***verificar***; painel F4 |
| 4. Golpes digitais: não morda a isca | phishing, golpe do Pix, engenharia social, 2FA | ***conferir remetente***, ***desconfiar do link***, ***ativar 2fa*** |
| 5. Avaliação final: sem colinha | transferência, sem comandos na tela, 2 vidas | recuperar os comandos sozinho (***status***, ***dica***) |

### Ferramenta de autoria (professor)

- **Menu → criar fase** abre um editor com três abas:
  - geral: título, briefing, vidas, tamanho do mapa, semente e a opção "mostrar comandos".
  - cachorros: um tipo de vigia por botão.
  - perguntas.
- A fase é um **JSON pequeno**. O mapa viaja como **semente**, e o labirinto gerado é sempre solucionável.
- A fase pode ser exportada, importada ("subir fase"), editada ou excluída. A importação passa pela mesma validação que o jogo usa.
- Cada fase tem um **`id_fase`** (UUID) fixo, para que a telemetria de máquinas diferentes caia na mesma fase.

### Menu principal (estado atual)

- O logo "Crypto Cats" foi desenhado pela Dayane, com letras brancas, vinhas e flores.
- Um siamês deitado abana o rabo em loop, indo e voltando (ADR 0039, 21/11/2026). Ele entrou no lugar do gatinho amarelo, que já tinha substituído os três sprites antigos. A capa da apresentação do TCC II usa o mesmo siamês, sobre o wallpaper do céu.
- O cartão é transparente e com blur, sem contorno preto, emoldurado por vinhas e flores. A cor da vinha segue o wallpaper (verde no brejo, azul na noite e no céu, verde-água na estufa, laranja nas carpas, marrom no piquenique), e as flores não mudam (ADR 0044).
- Todo o texto é **branco, sem contorno**. A linha "letramento digital e criptografia" foi removida.
- O **botão de galeria**, no canto superior direito, troca o wallpaper a cada toque entre 6 fundos: brejo, noite, estufa, carpas, piquenique e céu. A cor dos balões dos botões muda junto. As outras telas acompanham o fundo escolhido.
- Os wallpapers são de terceiros e têm atribuição na legenda da figura. **Pendente: confirmar os créditos e a permissão de uso.**
- **Todas as telas seguem o estilo do menu** (ADR 0034, 20/11/2026): seleção de fases, escolha do gato, editor, telemetria, diálogos e os painéis do jogo (terminal, F4, pergunta, captura e pausa).
  - Cada uma tem o wallpaper escolhido ao fundo com vidro desfocado, a moldura de vinhas com flores, os botões no balãozinho de flores e o texto branco.
  - Tudo acompanha a cor do wallpaper: balões, tinta do vidro, listas e abas.
  - Na fase, o fundo em volta do labirinto é o próprio cenário até a borda da tela (ADR 0038).
  - O contraste do texto branco é de pelo menos 4,5:1 em todos os fundos, conferido por teste.

---

## 3. Tecnologia e arquitetura

| Parte | Tecnologia |
|---|---|
| Cliente (jogo) | Godot 4.6 (testado também no 4.7.2), GDScript com tipagem estática, renderizador Mobile, 640×360, sem addons |
| API de telemetria | Java 21, Spring Boot 3.4, pasta `back/` |
| Banco | PostgreSQL 16 (Docker Compose), migrations Flyway até V8 |

**Cliente:**
- `fase_base.tscn` é a única cena de fase, e a fase é dado (`FaseConfig`, vindo do JSON).
- O A* usa `AStarGrid2D` (heurística de Manhattan, 4 direções, admissível e ótima). Há também `astar_referencia.gd`, uma versão didática que serve de oráculo nos testes.
- O SHA-256 usa `HashingContext`. Mapa e colisão usam `TileMapLayer` com a custom data `solido`.
- O **analisador do terminal** funciona como um compilador: normaliza o texto, o **AFD** gera os tokens, o **parser recursivo descendente** monta a AST e, por fim, vem a **validação semântica**.
  - Resultados possíveis: SUCESSO, ERRO_LEXICO, ERRO_SINTATICO, ERRO_SEMANTICO, TIMEOUT e ABANDONO.
  - O caso TC-04, ***cyfrar senha chave=3***, vira IDENTIFICADOR no lugar do VERBO e resulta em **ERRO_SINTATICO** (decisão documentada).
- **Diretor de IA** (informação imperfeita, inspirado em *Alien: Isolation*): ele só liga quando a fase declara regiões, e as fases de autoria não declaram. Nelas o cachorro persegue por linha de visão e patrulha.
  - Não é dificuldade adaptativa: as regras são fixas para todos os jogadores.

**Telemetria:**
- É anônima: o jogador é identificado só por `id_sujeito` (UUID), e o texto livre é truncado em 240 caracteres.
- Os eventos são assíncronos e ficam numa fila em disco, com lote, backoff com jitter e ingestão idempotente. O jogo **nunca trava** por causa do servidor.
- Modos: **MOCK** grava em disco e é o padrão; **HTTP** envia para a API.
- Rotas, todas com `Authorization: Bearer <chave>` de escopo INGESTAO e resposta 202:
  - `POST /v1/sessoes`
  - `POST /v1/sessoes/{id}/eventos` (até 500 por lote)
  - `POST /v1/sessoes/{id}/tentativas`
  - `POST /v1/sessoes/{id}/encerrar`
- Eventos: SESSAO_INICIADA, SESSAO_ENCERRADA, SESSAO_ABANDONADA, FASE_INICIADA, FASE_CONCLUIDA, FASE_ABANDONADA, DICA_SOLICITADA, CIFRA_DEMONSTRADA, COMANDO_SUBMETIDO, ERRO_LEXICO, ERRO_SINTATICO, CACHORRO_DETECTOU, CACHORRO_PERDEU, JOGADOR_CAPTURADO e AMOSTRA_DESEMPENHO (a cada 30 s).
- O banco tem três schemas:
  - `identidade`: dados pessoais, isolados.
  - `pesquisa`: sessões, eventos e tentativas, com as visões `vw_resumo_sessao`, `vw_desempenho_fase`, `vw_features_ia` e `vw_ganho_aprendizado`.
  - `operacao`: chaves de API, guardadas só como hash SHA-256 via JCA/`MessageDigest`.
- O **painel de telemetria** no jogo tem visão geral, fases jogadas (com seleção múltipla) e detalhe da fase, e exporta em JSON.

**Testes:**
- Suíte nativa, sem addon: **345 testes, 3.429 verificações, 52 arquivos, tudo verde** (a monografia ainda cita 311 testes e 2.304 verificações, os números da época da revisão).
- Os casos TC-01 a TC-04 da monografia estão em `tests/teste_casos_monografia.gd`.
- A API tem testes próprios (`mvn test`). **Pendente: a equipe rodar `mvn test` na máquina.**

**Decisões registradas:**
- São 44 ADRs em `docs/decisoes/` (0001 A* até 0044 vinhas no tom do wallpaper).
- Outros documentos: `docs/conformidade-monografia.md`, `docs/contrato-telemetria.md`, `docs/gramatica.md` e `docs/historico-de-desenvolvimento.md`.

---

### Apresentação do TCC II (21/11/2026)

- 30 minutos no total: cerca de 10 de slides e 20 de jogo ao vivo.
- Deck de 15 slides no tema do jogo (moldura de vinhas, siamês abanando a cauda na capa, paleta no azul clarinho dos botões do céu, wallpaper do céu na capa e nos slides finais, prints e prévias dos cenários), com notas do apresentador e tempo de cada slide.
- Estrutura baseada no deck do TCC I: capa, contexto/problema/solução, objetivos, metodologia, como o jogo ensina, trilha de 5 fases, terminal, A*, arquitetura, autoria e telemetria, correlatos, verificação, conclusão, roteiro da demonstração (20 min) e agradecimento.
- Existem duas versões do deck com o mesmo conteúdo: a do **céu** (paleta azul clarinha dos botões) e a do **piquenique** (paleta marrom dos botões, wallpaper do piquenique na capa e nos slides finais).
- O slide de verificação usa os números da época dos slides (333 testes, 3.231 verificações); a suíte hoje tem 345 testes e 3.429 verificações, e a monografia ainda cita 311.

---

## 4. Regras que valem sempre (não quebrar)

1. **Somente dados fictícios (LGPD, ADR 0019).** Nenhum usuário real é cadastrado e ninguém real testa o sistema.
   - Os dados de exemplo usam UUIDs começando com `f1c71c10`, a coorte `DADOS_FICTICIOS` e e-mails `@exemplo.invalid`.
2. **Nunca exibir nem logar a chave de API.**
3. O e-mail pessoal da usuária é privado e não deve ir para nenhum lugar.
4. **Não inventar referências bibliográficas.** Toda referência precisa ser verificável.
5. Estilo de texto da monografia:
   - Nada com "cara de IA": **sem travessão (—)** no meio das frases.
   - Comandos do jogo em ***negrito + itálico***.
   - Termos estrangeiros em itálico.
6. **Não mencionar comitê de ética** (CEP/Conep/TCLE) na monografia. A equipe não passou e não vai passar pelo comitê. A validação é feita **pela telemetria**: a evolução do jogador ao longo das fases mostra se o jogo funciona.
7. **Não escrever na monografia problemas, limitações ou "arte provisória"**, nada que a banca possa questionar como "por que não fizeram?". Trabalhos futuros só como recomendação neutra.
   - Ficam as frases honestas exigidas pelo professor: a eficácia pedagógica ainda não foi medida com estudantes, e os dados são fictícios.
8. O arquivo `back/local-dev.env.ps1` tem senhas e **não pode ir em entregas**. Recomendação: trocar as senhas e tirar o arquivo do repositório.

---

## 5. A monografia (estado atual)

**Normas aplicadas:**
- NBR 14724:2024: A4, margens **3 cm (sup./esq.) e 2 cm (inf./dir.)**, Arial 12 (10 nas legendas e citações longas), entrelinha 1,5, recuo de 1,25 cm.
- NBR 6024: título secundário em CAIXA ALTA negrito e terciário em caixa mista negrito.
- NBR 6023: referências com o destaque em **itálico**, sem negrito.
- NBR 6028: palavras-chave separadas por ponto.

**Elementos pré-textuais:** capa, folha de rosto, folha de aprovação, resumo, abstract, lista de figuras (26), lista de quadros (10), siglas e sumário. Total de 65 páginas.

**Estrutura:**
1. **INTRODUÇÃO**: 1.1 Contexto; 1.2 Problema; 1.3 Solução proposta; 1.4 Justificativa; 1.5 Contribuições; 1.6 Objetivos (geral e específicos); 1.7 Organização.
2. **METODOLOGIA**: pesquisa aplicada, de desenvolvimento tecnológico, em 3 fases (concepção, desenvolvimento e validação) com ciclos incrementais.
   - 2.1 Front-end (Godot); 2.2 Back-end (Java; o Kotlin foi abandonado); 2.3 Divisão de tarefas.
   - 2.4 Coleta de dados e validação, **pela telemetria e Learning Analytics**.
   - 2.5 Atividades não previstas no TCC I: autoria, fases públicas, telemetria por fase, integração com o back-end, dados fictícios, testes e ADRs, identidade visual.
   - 2.6 Cronograma (Quadro 1).
3. **REVISÃO DA LITERATURA**: cibersegurança e criptografia; gamificação; pensamento computacional; letramento digital; telemetria. 3.6 Síntese e lacuna (Quadro 2).
4. **PLANEJAMENTO DO JOGO**:
   - 4.1 Requisitos (RF e RNF com ID, prioridade e critério; casos de uso); 4.2 Arquitetura.
   - 4.3 Modelo de dados (agora com texto introdutório; ER e dicionário).
   - 4.4 Diagrama de classes; 4.5 Protótipos.
5. **RESULTADOS**:
   - 5.1 Arquitetura final (as cifras ficaram no cliente); 5.2 Classes; 5.3 Banco implementado.
   - 5.4 Telas: menu e galeria, seleção e escolha do gato, editor, jogo e captura.
   - 5.5 Criptografia no jogo; 5.6 IA (A* e Diretor); 5.7 Educação do usuário (trilha, retorno ao erro, instrumento de medição).
   - 5.8 Verificação (TC-01 a TC-04 e a suíte de 311 testes); 5.9 Discussão com os correlatos (Quadro 10).
6. **CONCLUSÃO**: 6.1 Objetivos; 6.2 Contribuição; 6.3 Facilidades e desafios; 6.4 Trabalhos futuros (só rotas administrativas da API, Diretor nas fases de autoria, rotas do A* na telemetria e novos algoritmos, como AES).

**Objetivo geral:** desenvolver um jogo educacional para o ensino prático de letramento
digital, criptografia e segurança cibernética.

**Objetivos específicos:**
- Levantar os requisitos.
- Fazer o design de nível 0 (cliente-servidor).
- Implementar a interface 2D e as mecânicas.
- Desenvolver o back-end com criptografia e a API REST de telemetria.
- Estruturar o analisador léxico.

**Correlatos comparados:**
- Phishing Quiz (Coqui, Maia e Castro, 2025)
- Cyber Defender (Santos et al., 2025)
- Cyber Resistance (Souza et al., 2025, também em Godot)
- Códigos de Resgate (França et al., 2025)

O Crypto Cats se diferencia deles em três pontos:
1. O jogador **formula o comando**, e o erro é classificado por etapa.
2. A telemetria registra cada tentativa **durante** a partida.
3. O **professor cria as fases**.

**Referências usadas:** Aho et al. (2007); Azevedo, Maltempi e Powell (2022); Bispo (2024); Brasil (2018, LGPD); Campano Junior et al. (2024); Coqui, Maia e Castro (2025); Cornélio et al.; Cruz e Freitas (Ctrl+E 2023); Deterding et al.; França et al. (2025); Hart, Nilsson e Raphael (A*); Lévy (2010); Lopes e Cunha (CIAED 2025); NIST FIPS 180-4; Pessoa e Melo (WEI 2024); Sales e Silva (SBIE 2020); Santos, Souza e Varandas (SBC-EB 2025); Santos et al. (SBSeg, Cyber Defender); Seif El-Nasr, Drachen e Canossa (Game Analytics); Siemens (2013); Soares (2002); Souza et al. (SBSeg 2025, Cyber Resistance); Stallings; Wing (2006).

**Figuras:**
- Há 26 figuras. Cada imagem tem um link que abre o arquivo correspondente na pasta do Drive.
- Os arquivos se chamam "Figura NN - nome simples.png".
- Os links já foram colocados também no Google Docs oficial.

**Revisão do professor:**
- A planilha *Revisao_Monografia_PurrBytes.xlsx* tem 31 apontamentos, PB-01 a PB-31. Todos foram corrigidos, e a resposta está em *Revisao_Monografia_PurrBytes_respondida.xlsx*. Os principais:
  - Citações sem referência.
  - Eficácia pedagógica não demonstrada (o texto foi reescrito como "instrumento preparado").
  - Faltavam a justificativa e a folha de aprovação.
  - A metodologia não é "experimental".
  - Requisitos com ID, prioridade e critério.
  - Discussão à luz da literatura.
  - Seção de facilidades e desafios.
  - Referências completas.
  - Negrito nos títulos.
  - Legendas centralizadas.
  - Itálico em termos estrangeiros.

**Pendências de formatação oferecidas (ainda não aprovadas pela usuária):**
- Fazer a contagem de páginas começar na folha de rosto. Hoje começa na capa, e a Introdução aparece na página 12 em vez de 11.
- Trocar "Capítulo N" por "seção N" (a NBR 14724:2024 usa "seções").
- Decidir se o título "REFERÊNCIAS" fica em negrito.

---

## 6. Entregas já feitas

- `Monografia_ABNT_TCC2_revisada.docx` / `.pdf` (65 páginas).
- `Revisao_Monografia_PurrBytes_respondida.xlsx`.
- `purr-bytes-atualizado.zip`: o projeto inteiro (jogo, API e documentação), sem `.godot`, `back/target` nem o arquivo de senhas.
- `Crypto Cats - video de demonstracao.mp4`: 2:42, 1280×720, sem som, gravado do jogo real. Mostra:
  - menu e galeria;
  - escolha do gato;
  - fase de César (F3, erro sintático, F4, pergunta, cochilo, captura e porta);
  - SHA-256;
  - golpes com o siamês;
  - painel de telemetria;
  - editor;
  - créditos.
- O roteiro do vídeo é `tools/roteiro_video_demonstracao.gd`, e dá para regravar.
- As 26 figuras estão no Drive.

## 7. Pendências da equipe

- Confirmar a divisão das células (PB-08) e os meses do cronograma.
- Rodar `mvn test` na API.
- Confirmar os créditos e a permissão dos wallpapers e das imagens de enfeites e portas usadas nos cenários (de terceiros).
- Conferir se a pasta do Drive está como "Qualquer pessoa com o link pode ver".
- Trocar as senhas de `back/local-dev.env.ps1` e tirar esse arquivo do repositório.
- Próximo passo da pesquisa (fora da monografia atual): aplicar o jogo com estudantes e analisar a telemetria.

## 8. Como rodar

```powershell
$godot = "$env:LOCALAPPDATA\Programs\godot\Godot_v4.7.2-stable_win64.exe"
& $godot --path .                                              # abrir no editor
& $godot --headless --path . --script res://tests/runner.gd    # testes do jogo
cd back; docker compose up -d; mvn spring-boot:run "-Dspring-boot.run.profiles=dev"   # API + banco
```

Para o jogo falar com a API, configure o `config.cfg` com `modo_telemetria="HTTP"`,
`url_api="http://localhost:8080"` e a chave de desenvolvimento que a API imprime no log do
perfil `dev`.


### Cachorros (atualizado em 22/11/2026)

- Dois cachorros no traço novo: husky e pastor (ADR 0042). Toda fase alterna husky, pastor, husky... pela ordem dos vigias, sem escolha no editor. O valor antigo "caramelo" é desenhado como o pastor.
- Os cachorros não dão meia-volta no corredor e não sobem no gato quando não podem pegá-lo (ADR 0040).
- A entrada do labirinto está sempre num ciclo, para o gato poder fugir (ADR 0041).
- Pacotes: novelo, peixe (olho preto) e rato, revezando pela ordem dos pacotes (ADR 0043).
- Vinhas da moldura no tom do wallpaper (ADR 0044).
- Suíte: 345 testes, 3.429 verificações, 0 falhas.
