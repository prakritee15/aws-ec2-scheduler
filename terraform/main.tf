locals {
  name = var.project_name
}

# --- SNS for notifications ---
resource "aws_sns_topic" "alerts" {
  name = "${local.name}-alerts"
}

# Optional email subscription for quick visibility
resource "aws_sns_topic_subscription" "email" {
  count     = var.sns_email == "" ? 0 : 1
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.sns_email
}

# --- IAM Role for Lambda ---
resource "aws_iam_role" "lambda_role" {
  name = "${local.name}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# Minimal permissions: logs, describe/start/stop EC2, publish SNS
data "aws_iam_policy_document" "lambda_policy" {
  statement {
    sid     = "Logs"
    actions = ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"]
    resources = ["*"]
  }
  statement {
    sid     = "EC2Manage"
    actions = ["ec2:DescribeInstances","ec2:StartInstances","ec2:StopInstances"]
    resources = ["*"]
  }
  statement {
    sid     = "SNSPublish"
    actions = ["sns:Publish"]
    resources = [aws_sns_topic.alerts.arn]
  }
}

resource "aws_iam_policy" "lambda_inline" {
  name   = "${local.name}-lambda-policy"
  policy = data.aws_iam_policy_document.lambda_policy.json
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_inline.arn
}

# --- Zip the Lambda from the repo (simple local zip during CI) ---
# For local 'terraform apply', you can zip manually:
#   cd lambda && zip -r ../lambda.zip app.py
# Then reference filename below. In CI we'll zip automatically.

resource "aws_lambda_function" "start" {
  function_name = "${local.name}-start"
  role          = aws_iam_role.lambda_role.arn
  handler       = "app.start_office_hours"
  runtime       = "python3.11"
  filename      = "${path.module}/../lambda.zip"

  environment {
    variables = {
      SCHEDULE_TAG  = "Schedule"
      SNS_TOPIC_ARN = aws_sns_topic.alerts.arn
    }
  }
}

resource "aws_lambda_function" "stop" {
  function_name = "${local.name}-stop"
  role          = aws_iam_role.lambda_role.arn
  handler       = "app.stop_office_hours"
  runtime       = "python3.11"
  filename      = "${path.module}/../lambda.zip"

  environment {
    variables = {
      SCHEDULE_TAG  = "Schedule"
      SNS_TOPIC_ARN = aws_sns_topic.alerts.arn
    }
  }
}

# --- CloudWatch Event rules (UTC times; adjust if you prefer UTC schedule) ---
# Example: 03:30 UTC (~09:00 IST) weekdays
resource "aws_cloudwatch_event_rule" "start_rule" {
  name                = "${local.name}-start-0930IST"
  schedule_expression = "cron(30 3 ? * MON-FRI *)"
}

# Example: 13:30 UTC (~19:00 IST) weekdays
resource "aws_cloudwatch_event_rule" "stop_rule" {
  name                = "${local.name}-stop-1930IST"
  schedule_expression = "cron(30 13 ? * MON-FRI *)"
}

resource "aws_cloudwatch_event_target" "start_target" {
  rule      = aws_cloudwatch_event_rule.start_rule.name
  target_id = "lambda-start"
  arn       = aws_lambda_function.start.arn
}

resource "aws_cloudwatch_event_target" "stop_target" {
  rule      = aws_cloudwatch_event_rule.stop_rule.name
  target_id = "lambda-stop"
  arn       = aws_lambda_function.stop.arn
}

# Permission for Events to call Lambda
resource "aws_lambda_permission" "allow_events_start" {
  statement_id  = "AllowExecutionFromEventsStart"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.start.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.start_rule.arn
}
resource "aws_lambda_permission" "allow_events_stop" {
  statement_id  = "AllowExecutionFromEventsStop"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.stop.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.stop_rule.arn
}
