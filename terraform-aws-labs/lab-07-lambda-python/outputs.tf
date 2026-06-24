output "function_name" {
  description = "Nome da função Lambda criada"
  value       = aws_lambda_function.hello_world.function_name
}

output "function_arn" {
  description = "ARN da função Lambda"
  value       = aws_lambda_function.hello_world.arn
}

output "function_url" {
  description = "URL HTTPS para invocar a Lambda diretamente via browser ou curl"
  value       = aws_lambda_function_url.hello_world.function_url
}

output "log_group" {
  description = "Nome do log group no CloudWatch Logs"
  value       = aws_cloudwatch_log_group.lambda.name
}

output "role_arn" {
  description = "ARN da IAM Role criada para a Lambda"
  value       = aws_iam_role.lambda.arn
}

output "runtime" {
  description = "Runtime Python utilizado"
  value       = aws_lambda_function.hello_world.runtime
}

output "comando_invoke_cli" {
  description = "Comando AWS CLI para invocar a Lambda e ver a resposta"
  value       = "aws lambda invoke --function-name ${aws_lambda_function.hello_world.function_name} --payload '{\"nome\":\"Ana\"}' --cli-binary-format raw-in-base64-out resposta.json && cat resposta.json"
}

output "comando_logs" {
  description = "Comando para acompanhar os logs em tempo real no CloudWatch"
  value       = "aws logs tail ${aws_cloudwatch_log_group.lambda.name} --follow --region ${var.aws_region}"
}

output "comando_curl" {
  description = "Comando curl para invocar a Lambda via Function URL"
  value       = "curl -s -X POST ${aws_lambda_function_url.hello_world.function_url} -H 'Content-Type: application/json' -d '{\"nome\":\"Ana\"}'"
}
