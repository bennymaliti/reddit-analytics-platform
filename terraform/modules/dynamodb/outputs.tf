output "table_names" {
  value = {
    raw_posts  = aws_dynamodb_table.raw_posts.name
    sentiment  = aws_dynamodb_table.sentiment.name
    trending   = aws_dynamodb_table.trending.name
    engagement = aws_dynamodb_table.engagement.name
    authors    = aws_dynamodb_table.authors.name
  }
}
output "table_arns" {
  value = [
    aws_dynamodb_table.raw_posts.arn,
    aws_dynamodb_table.sentiment.arn,
    aws_dynamodb_table.trending.arn,
    aws_dynamodb_table.engagement.arn,
    aws_dynamodb_table.authors.arn,
  ]
}
