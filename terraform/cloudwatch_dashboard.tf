resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Lambda Invocations and Errors"
          region  = var.aws_region
          period  = 300
          stat    = "Sum"
          view    = "timeSeries"
          stacked = false
          annotations = {
            horizontal = []
          }
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", "${var.project_name}-${var.environment}-data_ingestion"],
            ["AWS/Lambda", "Errors", "FunctionName", "${var.project_name}-${var.environment}-data_ingestion"],
            ["AWS/Lambda", "Invocations", "FunctionName", "${var.project_name}-${var.environment}-sentiment_analysis"],
            ["AWS/Lambda", "Errors", "FunctionName", "${var.project_name}-${var.environment}-sentiment_analysis"]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Kinesis Iterator Age"
          region  = var.aws_region
          period  = 60
          stat    = "Maximum"
          view    = "timeSeries"
          stacked = false
          annotations = {
            horizontal = []
          }
          metrics = [
            ["AWS/Kinesis", "GetRecords.IteratorAgeMilliseconds", "StreamName", "${var.project_name}-${var.environment}-raw-posts"]
          ]
        }
      }
    ]
  })
}
