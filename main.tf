data "aws_region" "current" {}

######################## lambda function and required permissions #######################
resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda_execution_role"
  #managed_policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"]
  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "sts:AssumeRole"
          ],
          "Principal" : {
            "Service" : [
              "lambda.amazonaws.com"
            ]
          }
        }
      ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_execution_role_policy" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "lambda_function" {
  function_name    = "APIGW_to_Lambda_Backend"
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  architectures    = ["x86_64"]
  filename         = "lambda_python.zip"
  source_code_hash = filebase64sha256("lambda_python.zip")
}

######################## SNS and required permissions ##########################
resource "aws_sns_topic" "API_to_SNS" {
  name = "API_to_SNS"
  policy = jsonencode(
    {
      "Version" : "2008-10-17",
      "Id" : "__default_policy_ID",
      "Statement" : [
        {
          "Sid" : "__default_statement_ID",
          "Effect" : "Allow",
          "Principal" : {
            "AWS" : "*"
          },
          "Action" : [
            "SNS:Publish",
            "SNS:RemovePermission",
            "SNS:SetTopicAttributes",
            "SNS:DeleteTopic",
            "SNS:ListSubscriptionsByTopic",
            "SNS:GetTopicAttributes",
            "SNS:AddPermission",
            "SNS:Subscribe"
          ],
          "Resource" : "arn:aws:sns:ap-southeast-1:112281322679:API_to_SNS",
          "Condition" : {
            "StringEquals" : {
              "AWS:SourceOwner" : "112281322679"
            }
          }
        },
        {
          "Sid" : "__console_pub_0",
          "Effect" : "Allow",
          "Principal" : {
            "AWS" : [
              "112281322679"
            ]
          },
          "Action" : "SNS:Publish",
          "Resource" : "arn:aws:sns:ap-southeast-1:112281322679:API_to_SNS"
        },
        {
          "Sid" : "__console_sub_0",
          "Effect" : "Allow",
          "Principal" : {
            "AWS" : [
              "112281322679"
            ]
          },
          "Action" : [
            "SNS:Subscribe"
          ],
          "Resource" : "arn:aws:sns:ap-southeast-1:112281322679:API_to_SNS"
        }
      ]
    }
  )
  delivery_policy = <<EOF
{
  "http": {
    "defaultHealthyRetryPolicy": {
      "minDelayTarget": 20,
      "maxDelayTarget": 20,
      "numRetries": 3,
      "numMaxDelayRetries": 0,
      "numNoDelayRetries": 0,
      "numMinDelayRetries": 0,
      "backoffFunction": "linear"
    },
    "disableSubscriptionOverrides": false,
    "defaultRequestPolicy": {
      "headerContentType": "text/plain; charset=UTF-8"
    }
  }
}
EOF
}

resource "aws_sns_topic_subscription" "Subscribe_to_API_SNS_topic" {
  topic_arn = aws_sns_topic.API_to_SNS.arn
  protocol  = "email"
  endpoint  = var.email_address
}


resource "aws_iam_role" "API_to_SNS_role" {
  name = "API_to_SNS_role"
  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Sid" : "",
          "Effect" : "Allow",
          "Principal" : {
            "Service" : [
              "apigateway.amazonaws.com"
            ]
          },
          "Action" : [
            "sts:AssumeRole"
          ]
        }
      ]
    }
  )
}

resource "aws_iam_role_policy_attachment" "API_to_SNS_default_role_policy" {
  role       = aws_iam_role.API_to_SNS_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_iam_policy" "API_to_SNS_inlinepolicy" {
  name = "API_to_SNS_inlinepolicy"
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : "sns:Publish",
          "Resource" : "*"
        }
      ]
    }
  )
}

resource "aws_iam_role_policy_attachment" "API_to_SNS_inline_role_policy" {
  role       = aws_iam_role.API_to_SNS_role.name
  policy_arn = aws_iam_policy.API_to_SNS_inlinepolicy.arn
}

######################## API Gateway ###########################
resource "aws_api_gateway_rest_api" "rest_apigw" {
  name = "rest_apigw"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

############################ Mock API Resource ###############################
resource "aws_api_gateway_resource" "mock_http_enp_resource" {
  rest_api_id = aws_api_gateway_rest_api.rest_apigw.id
  parent_id   = aws_api_gateway_rest_api.rest_apigw.root_resource_id
  path_part   = "mock"
}

resource "aws_api_gateway_method" "Mock_Method" {
  rest_api_id   = aws_api_gateway_rest_api.rest_apigw.id
  resource_id   = aws_api_gateway_resource.mock_http_enp_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "mock_integration" {
  rest_api_id = aws_api_gateway_rest_api.rest_apigw.id
  resource_id = aws_api_gateway_resource.mock_http_enp_resource.id
  http_method = aws_api_gateway_method.Mock_Method.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = <<EOF
{
   "statusCode": 200
}
EOF
  }
}

resource "aws_api_gateway_method_response" "mock_response_200" {
  rest_api_id = aws_api_gateway_rest_api.rest_apigw.id
  resource_id = aws_api_gateway_resource.mock_http_enp_resource.id
  http_method = aws_api_gateway_method.Mock_Method.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "mock_intergration_respone" {
  rest_api_id = aws_api_gateway_rest_api.rest_apigw.id
  resource_id = aws_api_gateway_resource.mock_http_enp_resource.id
  http_method = aws_api_gateway_method.Mock_Method.http_method
  status_code = aws_api_gateway_method_response.mock_response_200.status_code
  response_templates = {
    "application/json" = <<EOF
{
    "statusCode": 200,
    "message": "APIs are awesome",
    "details": {
        "Name": "REST API GW",
        "id": 1,
        "status": true
    }
}
EOF
  }
  depends_on = [aws_api_gateway_integration.mock_integration]
}

##################### Lambda API Resource ############################
resource "aws_api_gateway_resource" "lambda_resource" {
  rest_api_id = aws_api_gateway_rest_api.rest_apigw.id
  parent_id   = aws_api_gateway_rest_api.rest_apigw.root_resource_id
  path_part   = "lambda"
}

resource "aws_api_gateway_method" "Lambda_Method" {
  rest_api_id   = aws_api_gateway_rest_api.rest_apigw.id
  resource_id   = aws_api_gateway_resource.lambda_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.rest_apigw.id
  resource_id             = aws_api_gateway_resource.lambda_resource.id
  http_method             = aws_api_gateway_method.Lambda_Method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_function.invoke_arn
}

resource "aws_api_gateway_method_response" "lambda_response_200" {
  rest_api_id = aws_api_gateway_rest_api.rest_apigw.id
  resource_id = aws_api_gateway_resource.lambda_resource.id
  http_method = aws_api_gateway_method.Lambda_Method.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
}

#Gives an external source (like an EventBridge Rule, SNS, or S3 or API GW) permission to access the Lambda function.
resource "aws_lambda_permission" "lambda_permission_to_APIGW" {
  statement_id  = "AllowRestAPIInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.function_name
  principal     = "apigateway.amazonaws.com"

  # The /* part allows invocation from any stage, method and resource path
  # within API Gateway.
  source_arn = "${aws_api_gateway_rest_api.rest_apigw.execution_arn}/*"
  depends_on = [
    aws_api_gateway_rest_api.rest_apigw
  ]
}

############# SNS API Resource ##############
resource "aws_api_gateway_resource" "sns_resource" {
  rest_api_id = aws_api_gateway_rest_api.rest_apigw.id
  parent_id   = aws_api_gateway_rest_api.rest_apigw.root_resource_id
  path_part   = "sns"
}

resource "aws_api_gateway_method" "SNS_Method" {
  rest_api_id   = aws_api_gateway_rest_api.rest_apigw.id
  resource_id   = aws_api_gateway_resource.sns_resource.id
  http_method   = "POST"
  authorization = "NONE"
  request_parameters = {
    "method.request.querystring.TopicArn" = true
    "method.request.querystring.Message"  = true
  }
}

resource "aws_api_gateway_integration" "sns_integration" {
  rest_api_id             = aws_api_gateway_rest_api.rest_apigw.id
  resource_id             = aws_api_gateway_resource.sns_resource.id
  http_method             = aws_api_gateway_method.SNS_Method.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:sns:action/Publish"
  credentials             = aws_iam_role.API_to_SNS_role.arn
  timeout_milliseconds    = 29000
  request_parameters = {
    "integration.request.querystring.TopicArn" = "method.request.querystring.TopicArn"
    "integration.request.querystring.Message"  = "method.request.querystring.Message"
  }
}

resource "aws_api_gateway_method_response" "sns_response_200" {
  rest_api_id = aws_api_gateway_rest_api.rest_apigw.id
  resource_id = aws_api_gateway_resource.sns_resource.id
  http_method = aws_api_gateway_method.SNS_Method.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "sns_intergration_respone" {
  rest_api_id = aws_api_gateway_rest_api.rest_apigw.id
  resource_id = aws_api_gateway_resource.sns_resource.id
  http_method = aws_api_gateway_method.SNS_Method.http_method
  status_code = aws_api_gateway_method_response.sns_response_200.status_code
  response_templates = {
    "application/json" = ""
  }
  depends_on = [aws_api_gateway_integration.sns_integration]
}

############################ API GW Deployment ###############################
resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.rest_apigw.id
  depends_on = [
    aws_api_gateway_integration.mock_integration,
    aws_api_gateway_integration.lambda_integration,
    aws_api_gateway_integration.sns_integration
  ]
}

resource "aws_api_gateway_stage" "api_stage_deployment" {
  rest_api_id   = aws_api_gateway_rest_api.rest_apigw.id
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  stage_name    = var.stage_name
}
