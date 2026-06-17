output "ip_publico_primaria" {
  description = "IP público da EC2 primária"
  value       = aws_instance.primaria.public_ip
}

output "ip_publico_secundaria" {
  description = "IP público da EC2 secundária (failover)"
  value       = aws_instance.secundaria.public_ip
}

output "health_check_id" {
  description = "ID do health check do Route 53"
  value       = aws_route53_health_check.primaria.id
}

output "hosted_zone_id" {
  description = "ID da Hosted Zone pública"
  value       = aws_route53_zone.publica.zone_id
}

output "nameservers" {
  description = "Nameservers do Route 53 para esta zona (use para configurar seu registrador)"
  value       = aws_route53_zone.publica.name_servers
}

output "dns_app" {
  description = "Nome DNS do endpoint de aplicação"
  value       = aws_route53_record.app_primary.fqdn
}

output "comando_ssh_primaria" {
  description = "SSH para a EC2 primária"
  value       = "ssh -i ${var.nome_projeto}-key.pem ec2-user@${aws_instance.primaria.public_ip}"
}

output "comando_ssh_secundaria" {
  description = "SSH para a EC2 secundária"
  value       = "ssh -i ${var.nome_projeto}-key.pem ec2-user@${aws_instance.secundaria.public_ip}"
}

output "url_health_primaria" {
  description = "URL do endpoint de health check da primária"
  value       = "http://${aws_instance.primaria.public_ip}${var.health_check_path}"
}

output "url_health_secundaria" {
  description = "URL do endpoint de health check da secundária"
  value       = "http://${aws_instance.secundaria.public_ip}${var.health_check_path}"
}

output "console_health_check" {
  description = "Link direto para o health check no console AWS"
  value       = "https://console.aws.amazon.com/route53/healthchecks/home#/"
}
