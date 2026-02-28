terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

# IAM Role for Google Ads Lambda Functions
resource "aws_iam_role" "google_ads_lambda_role" {
  name = "${var.project_name}-google-ads-lambda-role"

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
      Name = "${var.project_name}-google-ads-lambda-role"
    }
  )
}

# IAM Policy for Google Ads Lambda
resource "aws_iam_role_policy" "google_ads_lambda_policy" {
  name = "${var.project_name}-google-ads-lambda-policy"
  role = aws_iam_role.google_ads_lambda_role.id

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
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          aws_secretsmanager_secret.google_ads_credentials.arn,
          aws_secretsmanager_secret.google_ads_developer_token.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = [var.kms_key_arn]
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = [var.sns_topic_arn]
      }
    ]
  })
}

# Secrets Manager for Google Ads Credentials
resource "aws_secretsmanager_secret" "google_ads_credentials" {
  name                    = "${var.project_name}/google-ads/credentials"
  description             = "Google Ads API credentials"
  recovery_window_in_days = 0

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-google-ads-credentials"
    }
  )
}

resource "aws_secretsmanager_secret_version" "google_ads_credentials" {
  secret_id = aws_secretsmanager_secret.google_ads_credentials.id
  secret_string = jsonencode({
    client_id     = var.google_ads_client_id
    client_secret = var.google_ads_client_secret
    refresh_token = var.google_ads_refresh_token
    developer_token = var.google_ads_developer_token
  })
}

# Lambda Function for Campaign Performance Monitor
data "archive_file" "campaign_monitor_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../../lambda/campaign-monitor"
  output_path = "${path.module}/../../lambda/campaign-monitor.zip"
}

resource "aws_lambda_function" "campaign_monitor" {
  filename         = data.archive_file.campaign_monitor_lambda.output_path
  function_name    = "${var.project_name}-campaign-monitor"
  role            = aws_iam_role.google_ads_lambda_role.arn
  handler         = "main"
  runtime         = "go1.x"
  timeout         = 300

  environment {
    variables = {
      GOOGLE_ADS_SECRET_ARN = aws_secretsmanager_secret.google_ads_credentials.arn
      SNS_TOPIC_ARN         = var.sns_topic_arn
      ENVIRONMENT           = var.environment
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-campaign-monitor"
    }
  )

  depends_on = [
    aws_iam_role_policy_attachment.google_ads_lambda_policy_attachment
  ]
}

# Lambda Function for Bid Optimization
data "archive_file" "bid_optimizer_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../../lambda/bid-optimizer"
  output_path = "${path.module}/../../lambda/bid-optimizer.zip"
}

resource "aws_lambda_function" "bid_optimizer" {
  filename         = data.archive_file.bid_optimizer_lambda.output_path
  function_name    = "${var.project_name}-bid-optimizer"
  role            = aws_iam_role.google_ads_lambda_role.arn
  handler         = "main"
  runtime         = "go1.x"
  timeout         = 600

  environment {
    variables = {
      GOOGLE_ADS_SECRET_ARN = aws_secretsmanager_secret.google_ads_credentials.arn
      SNS_TOPIC_ARN         = var.sns_topic_arn
      ENVIRONMENT           = var.environment
      OPTIMIZATION_INTERVAL = var.optimization_interval
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-bid-optimizer"
    }
  )

  depends_on = [
    aws_iam_role_policy_attachment.google_ads_lambda_policy_attachment
  ]
}

# Lambda Function for Ad Performance Analytics
data "archive_file" "ad_analytics_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../../lambda/ad-analytics"
  output_path = "${path.module}/../../lambda/ad-analytics.zip"
}

resource "aws_lambda_function" "ad_analytics" {
  filename         = data.archive_file.ad_analytics_lambda.output_path
  function_name    = "${var.project_name}-ad-analytics"
  role            = aws_iam_role.google_ads_lambda_role.arn
  handler         = "main"
  runtime         = "go1.x"
  timeout         = 300

  environment {
    variables = {
      GOOGLE_ADS_SECRET_ARN = aws_secretsmanager_secret.google_ads_credentials.arn
      DYNAMODB_TABLE_ARN     = var.dynamodb_table_arn
      ENVIRONMENT           = var.environment
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-ad-analytics"
    }
  )

  depends_on = [
    aws_iam_role_policy_attachment.google_ads_lambda_policy_attachment
  ]
}

# CloudWatch Events for Scheduled Execution
resource "aws_cloudwatch_event_rule" "campaign_monitor_schedule" {
  name                = "${var.project_name}-campaign-monitor-schedule"
  description         = "Schedule for campaign monitoring"
  schedule_expression = var.campaign_monitor_schedule

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-campaign-monitor-schedule"
    }
  )
}

resource "aws_cloudwatch_event_target" "campaign_monitor_target" {
  rule      = aws_cloudwatch_event_rule.campaign_monitor_schedule.name
  target_id = "CampaignMonitorTarget"
  arn       = aws_lambda_function.campaign_monitor.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_campaign_monitor" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.campaign_monitor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.campaign_monitor_schedule.arn
}

resource "aws_cloudwatch_event_rule" "bid_optimizer_schedule" {
  name                = "${var.project_name}-bid-optimizer-schedule"
  description         = "Schedule for bid optimization"
  schedule_expression = var.bid_optimizer_schedule

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-bid-optimizer-schedule"
    }
  )
}

resource "aws_cloudwatch_event_target" "bid_optimizer_target" {
  rule      = aws_cloudwatch_event_rule.bid_optimizer_schedule.name
  target_id = "BidOptimizerTarget"
  arn       = aws_lambda_function.bid_optimizer.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_bid_optimizer" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.bid_optimizer.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.bid_optimizer_schedule.arn
}

# IAM Role Policy Attachment
resource "aws_iam_role_policy_attachment" "google_ads_lambda_policy_attachment" {
  role       = aws_iam_role.google_ads_lambda_role.name
  policy_arn = aws_iam_role_policy.google_ads_lambda_policy.arn
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "campaign_monitor_logs" {
  name              = "/aws/lambda/${aws_lambda_function.campaign_monitor.function_name}"
  retention_in_days = var.log_retention_days

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-campaign-monitor-logs"
    }
  )
}

resource "aws_cloudwatch_log_group" "bid_optimizer_logs" {
  name              = "/aws/lambda/${aws_lambda_function.bid_optimizer.function_name}"
  retention_in_days = var.log_retention_days

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-bid-optimizer-logs"
    }
  )
}

resource "aws_cloudwatch_log_group" "ad_analytics_logs" {
  name              = "/aws/lambda/${aws_lambda_function.ad_analytics.function_name}"
  retention_in_days = var.log_retention_days

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-ad-analytics-logs"
    }
  )
}
