output "instance_id" {
  description = "ID da instância EC2"
  value       = aws_instance.lab.id
}

output "ip_publico" {
  description = "IP público da instância EC2"
  value       = aws_instance.lab.public_ip
}

output "ami_utilizada" {
  description = "ID da AMI usada para criar a instância"
  value       = data.aws_ami.amazon_linux.id
}

output "comando_ssh" {
  description = "Comando pronto para conectar via SSH"
  value       = "ssh -i ${var.nome_projeto}-key.pem ec2-user@${aws_instance.lab.public_ip}"
}

output "chave_privada_path" {
  description = "Caminho do arquivo da chave privada gerada"
  value       = local_sensitive_file.chave_privada.filename
}
