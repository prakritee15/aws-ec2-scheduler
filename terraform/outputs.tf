output "lambda_arn_start" { value = aws_lambda_function.start.arn }
output "lambda_arn_stop"  { value = aws_lambda_function.stop.arn }
output "sns_topic_arn"    { value = aws_sns_topic.alerts.arn }
