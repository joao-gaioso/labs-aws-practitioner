# Lab 06 — Route 53: Failover com Health Check

## 🎯 Objetivo

Entender na prática como o Route 53 detecta falhas e redireciona o tráfego automaticamente para um servidor de backup — sem nenhuma intervenção manual.

---

## 📖 Contexto

A LojaFácil cresceu e agora precisa de alta disponibilidade. Se o servidor principal cair, o site não pode ficar fora do ar esperando alguém perceber o problema e agir. A solução é configurar um **failover automático**: o Route 53 monitora o servidor principal e, ao detectar falha, passa a direcionar os clientes para o servidor de backup automaticamente.

---

## 🏗️ Arquitetura

```
                    ┌─────────────────────────────────────────┐
Cliente             │           ROUTE 53                      │
  │                 │                                         │
  │  resolve        │  app.lojafacil-lab.com                  │
  └────────────────►│                                         │
                    │   ┌─────────────┐  ┌─────────────────┐  │
                    │   │  PRIMARY    │  │   SECONDARY     │  │
                    │   │  Record A   │  │   Record A      │  │
                    │   │ (ativo)     │  │ (em standby)    │  │
                    │   └──────┬──────┘  └────────┬────────┘  │
                    │          │ health_check_id   │           │
                    │   ┌──────▼──────┐            │           │
                    │   │Health Check │            │           │
                    │   │GET /health  │            │           │
                    │   └──────┬──────┘            │           │
                    └──────────┼────────────────────┼──────────┘
                               │                    │
                         ✅ Healthy            (standby)
                               │
                    ┌──────────▼──────────┐  ┌─────────────────────┐
                    │   EC2 PRIMÁRIA      │  │  EC2 SECUNDÁRIA      │
                    │   AZ: us-east-1a    │  │  AZ: us-east-1b      │
                    │   nginx + /health   │  │  nginx + /health     │
                    └─────────────────────┘  └──────────────────────┘
```

### O que acontece no failover

```
NORMAL:     cliente → DNS resolve PRIMARY  → EC2 Primária   ✅
FALHA:      Health check detecta 3 falhas consecutivas
            cliente → DNS resolve SECONDARY → EC2 Secundária ⚠️
RECUPERAÇÃO: Health check volta a passar
            cliente → DNS resolve PRIMARY  → EC2 Primária   ✅
```

---

## 📁 Estrutura dos arquivos

```
lab-06-route53-failover/
├── versions.tf    → versões fixadas
├── provider.tf    → provider AWS
├── variables.tf   → variáveis (thresholds do health check configuráveis)
├── main.tf        → 2 EC2, security group, health check, hosted zone, registros failover
└── outputs.tf     → IPs, URLs de health check, comandos SSH
```

---

## ⚠️ Diferença importante em relação ao lab anterior

No lab 05 usamos uma **Hosted Zone privada** — o DNS só resolvia dentro da VPC.

Neste lab usamos uma **Hosted Zone pública** porque os health checks do Route 53 são executados por servidores da AWS espalhados pelo mundo, fora da sua VPC. Eles precisam alcançar as EC2 pela internet para verificar se estão respondendo.

| | Lab 05 | Lab 06 |
|---|---|---|
| Tipo de zona | Privada | Pública |
| Resolução DNS | Só dentro da VPC | Na internet (se domínio registrado) |
| Health checks | Não suportado | Suportado |
| Domínio necessário | Não | Para resolver na internet (sim) |

> 💡 Para este lab, a zona pública é criada no Route 53 mas o domínio `lojafacil-lab.com` não está registrado — então você não conseguirá resolver o nome de fora da AWS via `dig`. O que importa aqui é observar o comportamento do health check e do failover no **console do Route 53**.

---

## 🚀 Deploy

```bash
terraform init
terraform plan
terraform apply
```

Aguarde ~2 minutos após o apply para o nginx inicializar nas EC2 antes de começar os testes.

Anote os outputs — você vai precisar deles:

```bash
terraform output ip_publico_primaria
terraform output ip_publico_secundaria
terraform output url_health_primaria
terraform output health_check_id
```

---

## ✅ Verificação inicial

### 1. Confirme que os dois servidores respondem

```bash
# Deve retornar "SERVIDOR PRIMÁRIO" e código 200
curl http://$(terraform output -raw ip_publico_primaria)

# Deve retornar "SERVIDOR SECUNDÁRIO (FAILOVER)" e código 200
curl http://$(terraform output -raw ip_publico_secundaria)
```

### 2. Confirme que o endpoint de health check responde

```bash
# Ambos devem retornar "OK"
curl http://$(terraform output -raw ip_publico_primaria)/health
curl http://$(terraform output -raw ip_publico_secundaria)/health
```

### 3. Observe o health check no console

```
https://console.aws.amazon.com/route53/healthchecks/home#/
```

Aguarde até o status aparecer como **Healthy** (pode levar 1-2 minutos).

### 4. Observe os registros DNS no console

```
Route 53 → Hosted Zones → lojafacil-lab.com
```

Você verá dois registros `app.lojafacil-lab.com` do tipo A:
- Um com `set_identifier = primary` e `failover = PRIMARY`
- Um com `set_identifier = secondary` e `failover = SECONDARY`

---

## 🧪 Simulando o Failover

### Passo 1 — Derrube o nginx na EC2 primária

Conecte via SSH na primária e pare o nginx:

```bash
ssh -i lab-failover-key.pem ec2-user@$(terraform output -raw ip_publico_primaria)

# Dentro da EC2 primária:
sudo systemctl stop nginx

# Confirme que parou — deve retornar "connection refused"
curl http://localhost/health
```

### Passo 2 — Observe o health check mudar para Unhealthy

Abra o console do Route 53 e fique observando o health check:

```
https://console.aws.amazon.com/route53/healthchecks/home#/
```

O Route 53 tenta `GET /health` a cada 30 segundos (configurado em `health_check_intervalo`).
Após **3 falhas consecutivas** (`health_check_threshold_falha = 3`), o status muda para **Unhealthy**.

Tempo estimado para detectar a falha: `30s × 3 = ~90 segundos`.

### Passo 3 — Confirme que o failover aconteceu

Enquanto o health check estiver Unhealthy, o Route 53 para de responder com o IP da primária e começa a responder com o IP da secundária.

Primeiro pegue um dos nameservers da zona:

```bash
# Exibe todos os nameservers em JSON — copie um deles
terraform output -json nameservers
```

Depois consulte o DNS diretamente nesse nameserver.

**Bash (Linux/macOS/WSL/Git Bash):**
```bash
# Extrai o primeiro nameserver sem dependência de python3
NS=$(terraform output -json nameservers | tr -d '[]"' | cut -d',' -f1)
nslookup app.lojafacil-lab.com $NS

O IP retornado deve ser o da **SECUNDÁRIA**:
```bash
terraform output ip_publico_secundaria
```

Ou acesse diretamente pelo IP da secundária para confirmar que ela está servindo:

```bash
curl http://$(terraform output -raw ip_publico_secundaria)
# Deve mostrar "⚠️ SERVIDOR SECUNDÁRIO (FAILOVER)"
```

**Windows (PowerShell):**
```powershell
$ip = terraform output -raw ip_publico_secundaria
Invoke-WebRequest -Uri "http://$ip" -UseBasicParsing | Select-Object -ExpandProperty Content
```

### Passo 4 — Simule a recuperação

Volte para a EC2 primária e reinicie o nginx:

```bash
# Dentro da EC2 primária:
sudo systemctl start nginx
curl http://localhost/health
# Deve retornar "OK"
```

Observe o health check no console voltar para **Healthy**. Após `2 checks consecutivos OK` (`health_check_threshold_saudavel = 2`), o Route 53 volta a usar o registro PRIMARY.

---

## 🔍 Entendendo os parâmetros do health check

Os valores estão em `variables.tf` — altere e aplique para ver o efeito:

| Variável | Padrão | O que controla |
|---|---|---|
| `health_check_intervalo` | 30s | Com que frequência o Route 53 testa o endpoint |
| `health_check_threshold_falha` | 3 | Quantas falhas consecutivas para marcar como Unhealthy |
| `health_check_threshold_saudavel` | 2 | Quantos sucessos consecutivos para voltar a Healthy |

### Experimento — acelerar o failover

Altere o `variables.tf` para detectar falhas mais rápido:

```hcl
health_check_intervalo         = 10   # mínimo permitido pelo Route 53
health_check_threshold_falha   = 2    # falha após 2 checks (20 segundos)
health_check_threshold_saudavel = 1   # recupera após 1 check (10 segundos)
```

Aplique:

```bash
terraform apply
```

Repita a simulação de failover e compare o tempo até o status mudar.

> 💡 O intervalo de 10 segundos gera mais custo que 30 segundos — cada health check tem um preço por check realizado. Em produção, escolha o intervalo com base no SLA do serviço.

---

## 💡 Conceitos deste lab

**Failover routing policy** — política do Route 53 que define um registro PRIMARY e um SECONDARY. O SECONDARY só entra em ação quando o PRIMARY está Unhealthy.

**Health Check** — sonda periódica que o Route 53 envia para verificar se um endpoint está respondendo. Pode monitorar HTTP, HTTPS ou TCP.

**`set_identifier`** — campo obrigatório quando há múltiplos registros com o mesmo nome e tipo. Diferencia os registros dentro do Terraform e no estado do Route 53.

**`health_check_id`** — vincula um registro DNS a um health check. Sem esse vínculo, o Route 53 não sabe que deve remover o registro quando o servidor falhar.

**TTL baixo no failover** — usamos TTL de 60 segundos para que clientes que já fizeram cache do IP antigo sejam atualizados rapidamente após o failover. Em produção, 60s é um valor comum para registros críticos.

**AZs diferentes** — as duas EC2 ficam em Availability Zones diferentes propositalmente. Se uma AZ inteira cair, o servidor de backup em outra AZ continua disponível.

---

## ❓ Por que não usar zona privada aqui?

Os health checks do Route 53 são realizados por servidores AWS em múltiplas regiões do mundo. Esses servidores estão **fora da sua VPC** e precisam alcançar o endpoint pela internet pública. Uma zona privada só resolve nomes dentro da VPC — os health checkers não têm acesso a ela.

---

## 🧹 Destruindo os recursos

```bash
terraform destroy
```

> O arquivo `.pem` gerado localmente não é removido pelo `destroy`. Delete manualmente se necessário.
