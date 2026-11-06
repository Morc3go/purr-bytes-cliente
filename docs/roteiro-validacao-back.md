# Roteiro de validação do back-end — Purr Bytes

Este é o roteiro para validar o back. Está tudo na branch
`back/banco-de-dados` (PR #13, **ainda sem merge**: só faço o merge depois do teu ok).

Os comandos são para o **PowerShell**.

---

## 0. Pré-requisitos

Confere se aparecem as versões:

```powershell
java -version      # precisa ser 21
mvn -v
docker --version   # e o Docker Desktop precisa estar aberto
```

---

## 1. Pegar a branch

```powershell
cd <pasta do purr-bytes-cliente>
git fetch origin
git checkout back/banco-de-dados
git pull
```

---

## 2. Subir o banco

```powershell
cd back
docker compose up -d
docker compose ps    # espera o STATUS ficar "healthy"
```

---

## 3. Rodar os testes

```powershell
mvn test
```

✅ **Esperado:** `BUILD SUCCESS`, sem nenhum teste falhando.

---

## 4. Subir a API

Esse comando prende o terminal, então deixa ele aberto:

```powershell
mvn spring-boot:run "-Dspring-boot.run.profiles=dev"
```

✅ **Esperado:** no log aparecem as migrations V1 a V8, depois `R__dados_ficticios`, e a
linha `Started TelemetriaApplication`.

---

## 5. Conferir o banco

Num **segundo** terminal. Não precisa instalar cliente SQL:

```powershell
docker exec purrbytes-postgres psql -U purrbytes -d purrbytes -c "SELECT version, description, success FROM operacao.flyway_schema_history ORDER BY installed_rank;"
docker exec purrbytes-postgres psql -U purrbytes -d purrbytes -c "SELECT codigo_sujeito, status, total_eventos, total_tentativas FROM pesquisa.vw_resumo_sessao;"
docker exec purrbytes-postgres psql -U purrbytes -d purrbytes -c "SELECT codigo, escore_pre, escore_pos, ganho_normalizado FROM pesquisa.vw_ganho_aprendizado;"
```

✅ **Esperado:**

| Consulta | Resultado |
|---|---|
| Histórico do Flyway | Todas as migrations com `success = t` |
| `vw_resumo_sessao` | 2 sessões: `FIC-2026-0001` com 14 eventos e 4 tentativas; `FIC-2026-0002` com 7 eventos e 1 tentativa |
| `vw_ganho_aprendizado` | 6 sujeitos, todos com escore pré e pós |

---

## 6. Testar a API de verdade

Ainda no segundo terminal.

**6.1 Abrir uma sessão:**

```powershell
$h = @{ Authorization = "Bearer pb_ingestao_dev_nao_usar_em_coleta_real" }
$corpo = @{ id_sessao = [guid]::NewGuid(); id_sujeito = [guid]::NewGuid(); versao_jogo = "teste"; plataforma = "Windows"; iniciada_em = (Get-Date).ToUniversalTime().ToString("o") } | ConvertTo-Json
Invoke-WebRequest -Method Post -Uri http://localhost:8080/v1/sessoes -Headers $h -ContentType "application/json" -Body $corpo | Select-Object StatusCode
```

✅ **Esperado:** `202`.

**6.2 Mandar JSON quebrado:**

```powershell
try { Invoke-WebRequest -Method Post -Uri http://localhost:8080/v1/sessoes -Headers $h -ContentType "application/json" -Body "{json quebrado" } catch { $_.Exception.Response.StatusCode.value__ }
```

✅ **Esperado:** `400`. Antes dava 500 e travava a fila do jogo.

---

## 7. Desligar

1. `Ctrl+C` no terminal da API.
2. `docker compose down`
   (com `-v` apaga os dados e começa do zero na próxima vez).

---

## Se der erro

Me manda:

- **o número do passo** em que falhou;
- **o trecho do log** a partir da primeira linha com `ERROR` ou `FAILED`. No `mvn test`, a
  parte de `Tests in error` ou `COMPILATION ERROR`.