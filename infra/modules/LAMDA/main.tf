resource "aws_cognito_user_pool" "oidc" {
  name = "oidc-user-pool"

  username_attributes = ["email"]
  auto_verified_attributes = ["email"]
}
#Creates an Amazon Cognito User Pool (oidc-user-pool) for user authentication.
#Allows users to sign in with their email (username_attributes = ["email"]).
#Automatically verifies email addresses upon sign-up (auto_verified_attributes = ["email"])


resource "aws_cognito_user_pool_client" "oidc_client" {
  name         = "oidc-client"
  user_pool_id = aws_cognito_user_pool.oidc.id

  allowed_oauth_flows                 = ["code", "implicit"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["openid", "email"]

  supported_identity_providers = ["COGNITO"]  # Must be set

  callback_urls = ["http://localhost:3000/callback"]
  logout_urls   = ["https://localhost.com/logout"]

  explicit_auth_flows = [
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_ADMIN_USER_PASSWORD_AUTH",
     "ALLOW_USER_PASSWORD_AUTH"
  ]
}
#ALLOW_REFRESH_TOKEN_AUTH: Enables session persistence.
#ALLOW_USER_SRP_AUTH: Uses Secure Remote Password (SRP) for authentication.
#ALLOW_ADMIN_USER_PASSWORD_AUTH: Allows admins to authenticate users.
#ALLOW_USER_PASSWORD_AUTH: Allows password-based authentication.


# Lambda Function
resource "aws_lambda_function" "my_lambda" {
  function_name = "hello-world-function"
  role          = var.lambda_role_arn
  image_uri     = var.image_name
  package_type  = "Image"
  # depends_on    = [var.attach_basic_execution]
  environment {
    variables = {
      NODE_ENV = "production"
    }
  }
}


# Create API Gateway
resource "aws_apigatewayv2_api" "lambda_api" {
  name          = "lambda-container-api"
  protocol_type = "HTTP"
  
  cors_configuration {
    allow_origins = ["*"]  # Restrict to your domain in production
    allow_methods = ["GET", "POST", "PUT", "DELETE"]
    allow_headers = ["Content-Type", "Authorization"]
    max_age       = 300
  }
}

#allow_origins = ["*"]: Allows requests from any domain (should be restricted in production).
#allow_methods = ["GET", "POST", "PUT", "DELETE"]: Defines allowed HTTP methods.
#allow_headers = ["Content-Type", "Authorization"]: Allows specific headers.
#max_age = 300: Specifies how long CORS results should be cached



resource "aws_apigatewayv2_authorizer" "oidc_auth" {
  api_id          = aws_apigatewayv2_api.lambda_api.id
  authorizer_type = "JWT"
  identity_sources = ["$request.header.Authorization"]

  jwt_configuration {
    issuer   = "https://cognito-idp.us-west-2.amazonaws.com/${aws_cognito_user_pool.oidc.id}"
    audience = [aws_cognito_user_pool_client.oidc_client.id]
  }

  name = "oidc-authorizer"
}

#Creates an API Gateway JWT Authorizer to validate Cognito authentication.
#Extracts the JWT token from the Authorization header in API requests.
#Issuer: Uses Cognito User Pool’s endpoint as the trusted identity provider.
#Audience: Restricts tokens to be issued only for this specific User Pool Client.



# Create API stage
resource "aws_apigatewayv2_stage" "lambda_stage" {
  api_id = aws_apigatewayv2_api.lambda_api.id
  name   = "prod"
  auto_deploy = true
}

# Create API integration with Lambda
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id = aws_apigatewayv2_api.lambda_api.id

  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.my_lambda.invoke_arn
}
# Connects API Gateway to AWS Lambda using the AWS_PROXY integration.
# All requests are forwarded to Lambda as-is.


# Create API route
resource "aws_apigatewayv2_route" "lambda_route" {
  api_id = aws_apigatewayv2_api.lambda_api.id
  route_key = "ANY /{proxy+}"  # Catches all paths
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
  authorizer_id = aws_apigatewayv2_authorizer.oidc_auth.id
}


# Allow API Gateway to invoke Lambda
resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.my_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda_api.execution_arn}/*/*"
}

#	Grants API Gateway permission to invoke the Lambda function.
#	Uses the apigateway.amazonaws.com principal to restrict access.
