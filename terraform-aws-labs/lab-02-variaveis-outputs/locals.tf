# locals.tf
# Locals são valores calculados dentro do Terraform — não vêm de fora.
# Use locals para evitar repetição e centralizar lógica de nomenclatura.

locals {
  # Prefixo padrão para nomear todos os recursos
  # Resultado: "lab-ana-dev"
  prefixo = "${var.projeto}-${var.environment}"

  # Tags extras que complementam as default_tags do provider
  tags_comuns = {
    Projeto     = var.projeto
    Environment = var.environment
  }

  # ─────────────────────────────────────────────────────────────────────────
  # 🧪 EXPERIMENTO 3 — local calculado com upper()
  # Descomente após ler o Experimento 3 no README.
  # upper() transforma o texto em maiúsculas — uma das funções built-in do Terraform.
  # ─────────────────────────────────────────────────────────────────────────
  prefixo_upper  = upper(local.prefixo)
  ambiente_label = var.environment == "prod" ? "PRODUCAO" : "NAO-PRODUCAO"
}
