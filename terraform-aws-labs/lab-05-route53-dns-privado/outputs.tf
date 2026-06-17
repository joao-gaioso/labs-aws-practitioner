output "ip_publico_ec2" {
  description = "IP público da EC2 — use para conectar via SSH"
  value       = aws_instance.app.public_ip
}

output "ip_privado_ec2" {
  description = "IP privado da EC2 — é para este IP que o DNS aponta"
  value       = aws_instance.app.private_ip
}

output "hosted_zone_id" {
  description = "ID da Hosted Zone privada criada no Route 53"
  value       = aws_route53_zone.privada.zone_id
}

output "dominio_app" {
  description = "Nome DNS completo do servidor de aplicação"
  value       = aws_route53_record.app.fqdn
}

output "comando_ssh" {
  description = "Comando pronto para conectar na EC2 via SSH"
  value       = "ssh -i ${var.nome_projeto}-key.pem ec2-user@${aws_instance.app.public_ip}"
}

output "comando_teste_dns" {
  description = "Comando para testar a resolução DNS de dentro da EC2"
  value       = "curl http://${aws_route53_record.app.fqdn}"
}
