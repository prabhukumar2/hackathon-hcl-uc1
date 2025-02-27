
output "api_gateway_url" {
  value = aws_apigatewayv2_stage.lambda_stage.invoke_url
}