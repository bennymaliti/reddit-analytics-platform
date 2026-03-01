output "api_gateway_url" { value = aws_api_gateway_stage.main.invoke_url }
output "api_gateway_id" { value = aws_api_gateway_rest_api.main.id }
output "cognito_user_pool_id" { value = aws_cognito_user_pool.main.id }
output "cognito_app_client_id" { value = aws_cognito_user_pool_client.api_client.id }
