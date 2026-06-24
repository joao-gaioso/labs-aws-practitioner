# main.tf
#
# Este lab cria uma função Lambda Python seguindo boas práticas:
#   - IAM Role com least privilege (só o necessário para executar)
#   - CloudWatch Log Group explícito com retenção configurada
#   - Empacotamento do código com archive_file + source_code_hash
#   - Rastreamento X-Ray para observabilidade
#   - Function URL para invocação HTTP direta (sem precisar de API Gateway)
#
# Fluxo de invocação:
#
#   Você (curl / AWS CLI)
#         │
#         ▼
#   Function URL (HTTPS)
#         │
#         ▼
#   Lambda (hello_world.lambda_handler)
#         │
#         ├──► CloudWatch Logs  (logs de execução)
#         └──► X-Ray            (rastreamento de latência)

# ─── Data source: conta AWS atual ────────────────────────────────────────────
# Usado para compor nomes únicos de recursos quando necessário.
data "aws_caller_identity" "atual" {}

# ─── IAM Role para a Lambda ───────────────────────────────────────────────────
# Toda Lambda precisa de uma IAM Role para assumir permissões na AWS.
# O "trust policy" define quem pode assumir esta role — aqui, o serviço Lambda.
resource "aws_iam_role" "lambda" {
  name        = "${var.nome_projeto}-role"
  description = "Role de execucao da Lambda - ${var.nome_projeto}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "LambdaAssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# ─── Política gerenciada: permissões básicas ──────────────────────────────────
# AWSLambdaBasicExecutionRole concede apenas o mínimo necessário:
#   logs:CreateLogGroup, logs:CreateLogStream, logs:PutLogEvents
#
# Princípio do menor privilégio: não usar AdministratorAccess ou PowerUserAccess.
# Se a Lambda precisar acessar outros serviços (S3, DynamoDB...), crie
# políticas específicas e as anexe separadamente.
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ─── CloudWatch Log Group ─────────────────────────────────────────────────────
# Boa prática: criar o log group explicitamente em vez de deixar a Lambda
# criá-lo automaticamente no primeiro uso. Vantagens:
#   - O Terraform gerencia o ciclo de vida (terraform destroy apaga os logs)
#   - A retenção é definida desde o início (evita logs acumulando para sempre)
#   - O nome segue a convenção obrigatória: /aws/lambda/<nome-da-função>
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.nome_projeto}-function"
  retention_in_days = var.log_retention_days
}

# ─── Empacotamento do código Python ───────────────────────────────────────────
# A Lambda precisa receber o código em formato .zip.
# O data source archive_file faz isso automaticamente dentro do Terraform.
#
# source_code_hash: hash do .zip calculado pelo Terraform.
# Quando o código muda → hash muda → Terraform detecta e faz novo deploy.
# Sem isso, mudanças no .py não triggerariam um novo deploy.
data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/src/hello_world.py"
  output_path = "${path.module}/.build/hello_world.zip"
}

# ─── Função Lambda ────────────────────────────────────────────────────────────
resource "aws_lambda_function" "hello_world" {
  function_name = "${var.nome_projeto}-function"
  description   = "Função de exemplo — lab Lambda com Terraform"

  # IAM: qual role a Lambda assume para executar
  role = aws_iam_role.lambda.arn

  # Código: arquivo .zip gerado pelo archive_file
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  # Runtime e handler: "hello_world" = nome do arquivo .py, "lambda_handler" = nome da função
  runtime = var.runtime
  handler = "hello_world.lambda_handler"

  timeout     = var.timeout
  memory_size = var.memory_size

  # X-Ray: registra latência e dependências de cada invocação.
  # "Active" faz sampling automático — útil para debugging e análise de performance.
  tracing_config {
    mode = "Active"
  }

  # Variáveis de ambiente: valores injetados no código sem precisar alterar o .py.
  #     Nunca coloque segredos aqui (senhas, tokens, chaves de API).
  #     Para segredos, use AWS Secrets Manager ou SSM Parameter Store.
  environment {
    variables = {
      NOME_PADRAO = var.nome_padrao
      APP_VERSION = "1.0.0"
    }
  }

  # depends_on explícito: garante que a policy esteja anexada e o log group
  # exista antes de a Lambda ser criada. Sem isso pode haver race condition
  # onde a Lambda tenta escrever logs antes de ter permissão.
  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_cloudwatch_log_group.lambda,
  ]
}

# ─── Function URL ─────────────────────────────────────────────────────────────
# A Function URL cria um endpoint HTTPS dedicado para a Lambda.
# Vantagem sobre API Gateway: mais simples, sem custo adicional por requisição.
# Desvantagem: sem roteamento, autenticação avançada ou throttling granular.
#
#   s  authorization_type = "NONE" permite que qualquer pessoa com a URL invoque
#     a Lambda. Ideal para labs. Em produção use "AWS_IAM" para exigir
#     autenticação com credenciais AWS.
resource "aws_lambda_function_url" "hello_world" {
  function_name      = aws_lambda_function.hello_world.function_name
  authorization_type = "NONE"

  cors {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST"]
    allow_headers = ["content-type"]
    max_age       = 300
  }
}
