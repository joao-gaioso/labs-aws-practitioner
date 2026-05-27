# provider.tf
# O provider é o "plugin" que ensina o Terraform a falar com a AWS.
# Aqui definimos a região padrão onde os recursos serão criados.

provider "aws" {
  region = "us-east-1"

  # Boa prática: adicione tags padrão em todos os recursos via default_tags.
  # Assim você nunca esquece de taggear um recurso.
  default_tags {
    tags = {
      ManagedBy = "terraform"
      Lab       = "lab-01-primeiro-s3"
    }
  }
}
