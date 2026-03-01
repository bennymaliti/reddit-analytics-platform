resource "aws_cloudwatch_event_rule" "ingestion_schedule" {
  name                = "${var.name_prefix}-ingestion-schedule"
  description         = "Triggers Reddit ingestion Lambda every ${var.rate_minutes} minutes"
  schedule_expression = "rate(${var.rate_minutes} minutes)"
  state               = "ENABLED"
}

resource "aws_cloudwatch_event_target" "ingestion_lambda" {
  rule      = aws_cloudwatch_event_rule.ingestion_schedule.name
  target_id = "ingestion-lambda"
  arn       = var.ingestion_lambda_arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.ingestion_lambda_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ingestion_schedule.arn
}
