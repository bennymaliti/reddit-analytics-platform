output "lambda_role_arns" {
  value = {
    ingestion        = aws_iam_role.ingestion.arn
    sentiment        = aws_iam_role.sentiment.arn
    trending         = aws_iam_role.trending.arn
    engagement       = aws_iam_role.consumer["engagement"].arn
    classification   = aws_iam_role.consumer["classification"].arn
    author_profiling = aws_iam_role.consumer["author-profiling"].arn
    analytics_api    = aws_iam_role.analytics_api.arn
  }
}
