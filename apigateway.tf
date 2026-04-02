# ==================== API Gateway ====================

resource "aws_apigatewayv2_api" "vault_api" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins = ["*"]   # Change to your frontend domain later
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["content-type", "authorization"]
  }
}

# Cognito Authorizer (for protected routes)
resource "aws_apigatewayv2_authorizer" "cognito_auth" {
  api_id           = aws_apigatewayv2_api.vault_api.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "cognito-authorizer"

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.vault_client.id]
    issuer   = "https://${aws_cognito_user_pool.vault_users.endpoint}"
  }
}

# ==================== Routes & Integrations ====================

# 1. Upload Route (Protected)
resource "aws_apigatewayv2_integration" "upload_integration" {
  api_id             = aws_apigatewayv2_api.vault_api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.upload.invoke_arn
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "upload_route" {
  api_id    = aws_apigatewayv2_api.vault_api.id
  route_key = "POST /upload"
  target    = "integrations/${aws_apigatewayv2_integration.upload_integration.id}"
  authorizer_id = aws_apigatewayv2_authorizer.cognito_auth.id
  authorization_type = "JWT"
}

# 2. Generate Share Link Route (Protected)
resource "aws_apigatewayv2_integration" "share_integration" {
  api_id             = aws_apigatewayv2_api.vault_api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.share.invoke_arn
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "share_route" {
  api_id    = aws_apigatewayv2_api.vault_api.id
  route_key = "POST /share"
  target    = "integrations/${aws_apigatewayv2_integration.share_integration.id}"
  authorizer_id = aws_apigatewayv2_authorizer.cognito_auth.id
  authorization_type = "JWT"
}

# 3. Download Route (Public - no auth required)
resource "aws_apigatewayv2_integration" "download_integration" {
  api_id             = aws_apigatewayv2_api.vault_api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.download.invoke_arn
  integration_method = "POST"        # ← This must be POST even for GET route
}

resource "aws_apigatewayv2_route" "download_route" {
  api_id    = aws_apigatewayv2_api.vault_api.id
  route_key = "GET /share/{shortCode}"     # The actual HTTP method the client will use
  target    = "integrations/${aws_apigatewayv2_integration.download_integration.id}"
}

# ==================== Lambda Permissions for API Gateway ====================

resource "aws_lambda_permission" "allow_upload" {
  statement_id  = "AllowAPIGatewayInvokeUpload"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.upload.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.vault_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "allow_share" {
  statement_id  = "AllowAPIGatewayInvokeShare"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.share.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.vault_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "allow_download" {
  statement_id  = "AllowAPIGatewayInvokeDownload"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.download.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.vault_api.execution_arn}/*/*"
}

# ==================== Outputs ====================
output "api_endpoint" {
  value = aws_apigatewayv2_api.vault_api.api_endpoint
}

output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.vault_users.id
}

output "cognito_client_id" {
  value = aws_cognito_user_pool_client.vault_client.id
}