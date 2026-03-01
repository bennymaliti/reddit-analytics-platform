output "rule_arn" { value = aws_cloudwatch_event_rule.ingestion_schedule.arn }
output "rule_name" { value = aws_cloudwatch_event_rule.ingestion_schedule.name }
