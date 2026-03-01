output "raw_stream_name" { value = aws_kinesis_stream.raw_posts.name }
output "raw_stream_arn" { value = aws_kinesis_stream.raw_posts.arn }
output "analytics_stream_name" { value = aws_kinesis_stream.analytics.name }
output "analytics_stream_arn" { value = aws_kinesis_stream.analytics.arn }
output "firehose_arn" { value = aws_kinesis_firehose_delivery_stream.to_s3.arn }
