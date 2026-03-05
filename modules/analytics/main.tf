terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# DynamoDB Table for Analytics
resource "aws_dynamodb_table" "analytics" {
  name           = "${var.project_name}-analytics-${var.environment}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"
  range_key      = "timestamp"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  attribute {
    name = "metric_type"
    type = "S"
  }

  attribute {
    name = "service"
    type = "S"
  }

  global_secondary_index {
    name     = "MetricTypeIndex"
    hash_key = "metric_type"
    range_key = "timestamp"
    projection_type = "ALL"
  }

  global_secondary_index {
    name     = "ServiceIndex"
    hash_key = "service"
    range_key = "timestamp"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-analytics-dynamodb"
    }
  )
}

# KMS Key for Analytics Encryption
resource "aws_kms_key" "analytics" {
  description             = "KMS key for analytics data encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow DynamoDB Access"
        Effect = "Allow"
        Principal = {
          Service = "dynamodb.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow Lambda Access"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-analytics-kms"
    }
  )
}

resource "aws_kms_alias" "analytics" {
  name          = "alias/${var.project_name}-analytics-${var.environment}"
  target_key_id = aws_kms_key.analytics.key_id
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}

# CloudWatch Log Group for Analytics Lambda
resource "aws_cloudwatch_log_group" "analytics_lambda" {
  name              = "/aws/lambda/${var.project_name}-analytics-processor"
  retention_in_days = var.log_retention_days

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-analytics-logs"
    }
  )
}

# IAM Role for Analytics Lambda
resource "aws_iam_role" "analytics_lambda" {
  name = "${var.project_name}-analytics-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-analytics-lambda-role"
    }
  )
}

# IAM Policy for Analytics Lambda
resource "aws_iam_role_policy" "analytics_lambda" {
  name = "${var.project_name}-analytics-lambda-policy"
  role = aws_iam_role.analytics_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.analytics.arn,
          "${aws_dynamodb_table.analytics.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.analytics.arn
      }
    ]
  })
}

# Lambda Function for Analytics Processing
resource "aws_lambda_function" "analytics_processor" {
  filename         = "analytics_processor.zip"
  function_name    = "${var.project_name}-analytics-processor"
  role            = aws_iam_role.analytics_lambda.arn
  handler         = "main.handler"
  runtime         = "python3.11"
  timeout         = 300

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.analytics.name
      KMS_KEY_ARN   = aws_kms_key.analytics.arn
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-analytics-processor"
    }
  )
}

# Create a placeholder zip file for the Lambda function
resource "null_resource" "create_lambda_zip" {
  provisioner "local-exec" {
    command = "echo 'placeholder' > analytics_processor.zip && zip -u analytics_processor.zip main.py"
  }
}

# EventBridge Rule for Analytics Processing
resource "aws_cloudwatch_event_rule" "analytics_schedule" {
  name                = "${var.project_name}-analytics-schedule"
  description         = "Schedule for analytics processing"
  schedule_expression = var.analytics_schedule

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-analytics-schedule"
    }
  )
}

# EventBridge Target
resource "aws_cloudwatch_event_target" "analytics_lambda" {
  rule      = aws_cloudwatch_event_rule.analytics_schedule.name
  target_id = "AnalyticsLambdaTarget"
  arn       = aws_lambda_function.analytics_processor.arn
}

# Lambda Permission for EventBridge
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.analytics_processor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.analytics_schedule.arn
}
